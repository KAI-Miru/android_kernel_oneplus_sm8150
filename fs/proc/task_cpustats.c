// SPDX-License-Identifier: GPL-2.0-only
/*
 * Copyright (C) 2020 Oplus. All rights reserved.
 *
 * Android 14 task CPU accounting adapted to the Qualcomm 4.14 scheduler
 * energy model used by the OnePlus 7 Pro H.40 kernel.
 */

#include <linux/cpufreq.h>
#include <linux/init.h>
#include <linux/jiffies.h>
#include <linux/kernel.h>
#include <linux/kernel_stat.h>
#include <linux/percpu.h>
#include <linux/proc_fs.h>
#include <linux/sched.h>
#include <linux/sched/energy.h>
#include <linux/sched/topology.h>
#include <linux/semaphore.h>
#include <linux/seq_file.h>
#include <linux/string.h>
#include <linux/task_cpustats.h>

/* Keep the userspace ABI compatible with the Android 14 Oplus producer. */
#define MAX_PID		32768
#define CTP_WINDOW_SZ	5
#define CTP_READ_RETRIES	4

unsigned int sysctl_task_cpustats_enable;
DEFINE_PER_CPU(struct kernel_task_cpustat, ktask_cpustat);
static unsigned long cputime_one_jiffy;

/*
 * Each scheduler tick has one writer on its local CPU.  A sequence value per
 * ring slot lets proc readers reject a record being replaced without putting
 * a lock or allocation in the tick path.
 */
struct task_cpustat_guard {
	unsigned int seq[MAX_CTP_WINDOW];
};

static DEFINE_PER_CPU(struct task_cpustat_guard, ktask_cpustat_guard);

struct acct_cpustat {
	pid_t tgid;
	unsigned int pwr;
	char comm[TASK_COMM_LEN];
};

/*
 * The donor exposes a single 32-bit aggregate table.  Serialize proc readers
 * around it so polling does not allocate a megabyte-sized snapshot each time
 * and concurrent opens cannot overwrite one another's report.
 */
static struct acct_cpustat cpustats[MAX_PID];
static DEFINE_SEMAPHORE(task_cpustats_snapshot_sem);

void account_task_time(struct task_struct *p, unsigned int ticks,
		       enum cpu_usage_stat type)
{
	struct kernel_task_cpustat *kstat;
	struct task_cpustat_guard *guard;
	struct task_cpustat *stat;
	struct cpufreq_policy *policy;
	unsigned long tick_jiffies;
	unsigned int seq;
	int cpu, idx;

	if (!READ_ONCE(sysctl_task_cpustats_enable))
		return;

	cpu = raw_smp_processor_id();
	kstat = &per_cpu(ktask_cpustat, cpu);
	guard = &per_cpu(ktask_cpustat_guard, cpu);
	policy = cpufreq_cpu_get_raw(cpu);
	tick_jiffies = READ_ONCE(cputime_one_jiffy);
	if (unlikely(!tick_jiffies)) {
		tick_jiffies = nsecs_to_jiffies(TICK_NSEC);
		if (!tick_jiffies)
			tick_jiffies = 1;
		WRITE_ONCE(cputime_one_jiffy, tick_jiffies);
	}
	idx = READ_ONCE(kstat->idx) % MAX_CTP_WINDOW;
	stat = &kstat->cpustat[idx];

	seq = READ_ONCE(guard->seq[idx]);
	if (unlikely(seq & 1))
		seq++;
	WRITE_ONCE(guard->seq[idx], seq + 1);
	smp_wmb();

	stat->pid = p->pid;
	stat->tgid = p->tgid;
	stat->type = type;
	stat->freq = policy ? READ_ONCE(policy->cur) : 0;
	stat->end = jiffies;
	stat->begin = stat->end - tick_jiffies * ticks;
	memcpy(stat->comm, p->comm, TASK_COMM_LEN);
	stat->comm[TASK_COMM_LEN - 1] = '\0';

	smp_wmb();
	WRITE_ONCE(guard->seq[idx], seq + 2);
	WRITE_ONCE(kstat->idx, idx + 1);
}

static bool task_cpustat_read_record(int cpu, int idx,
				     struct task_cpustat *record)
{
	struct kernel_task_cpustat *kstat = &per_cpu(ktask_cpustat, cpu);
	struct task_cpustat_guard *guard =
		&per_cpu(ktask_cpustat_guard, cpu);
	unsigned int before, after;
	int retries = CTP_READ_RETRIES;

	do {
		before = READ_ONCE(guard->seq[idx]);
		if (before & 1) {
			cpu_relax();
			continue;
		}

		smp_rmb();
		memcpy(record, &kstat->cpustat[idx], sizeof(*record));
		smp_rmb();
		after = READ_ONCE(guard->seq[idx]);
		if (before == after && !(after & 1)) {
			record->comm[TASK_COMM_LEN - 1] = '\0';
			return true;
		}
	} while (--retries);

	return false;
}

static unsigned long task_cpustats_get_power(int cpu, unsigned int freq)
{
	struct sched_group_energy *sge = sge_array[cpu][SD_LEVEL0];
	int i;

	if (!freq || !sge || !sge->cap_states || !sge->nr_cap_states)
		return 0;

	for (i = 0; i < sge->nr_cap_states; i++) {
		struct capacity_state *state = &sge->cap_states[i];

		if (state->frequency == freq)
			return state->power;
	}

	return 0;
}

static int task_cpustats_show(struct seq_file *m, void *v)
{
	int idx = *(int *)v;
	struct acct_cpustat *stat = &cpustats[idx];

	seq_printf(m, "%d\t%d\t%u\t%s\n", idx, stat->tgid,
		   stat->pwr, stat->comm);
	return 0;
}

static void *task_cpustats_start(struct seq_file *m, loff_t *ppos)
{
	int *idx = m->private;

	if (!READ_ONCE(sysctl_task_cpustats_enable) || *ppos >= MAX_PID)
		return NULL;

	*idx = *ppos;
	for (; *idx < MAX_PID; (*idx)++, (*ppos)++) {
		if (cpustats[*idx].pwr)
			return idx;
	}

	return NULL;
}

static void *task_cpustats_next(struct seq_file *m, void *v, loff_t *ppos)
{
	int *idx = v;

	(*idx)++;
	(*ppos)++;
	for (; *idx < MAX_PID; (*idx)++, (*ppos)++) {
		if (cpustats[*idx].pwr)
			return idx;
	}

	return NULL;
}

static void task_cpustats_stop(struct seq_file *m, void *v)
{
}

static const struct seq_operations task_cpustats_seq_ops = {
	.start	= task_cpustats_start,
	.next	= task_cpustats_next,
	.stop	= task_cpustats_stop,
	.show	= task_cpustats_show,
};

static int sge_show(struct seq_file *m, void *v)
{
	int cpu, i;

	for_each_possible_cpu(cpu) {
		struct sched_group_energy *sge = sge_array[cpu][SD_LEVEL0];
		struct cpufreq_policy *policy;
		unsigned int max_freq, min_freq;

		if (!sge || !sge->cap_states || !sge->nr_cap_states)
			continue;

		policy = cpufreq_cpu_get(cpu);
		if (!policy)
			continue;

		down_read(&policy->rwsem);
		max_freq = policy->cpuinfo.max_freq;
		min_freq = policy->cpuinfo.min_freq;
		seq_printf(m, "cpu %d\n", cpu);
		for (i = sge->nr_cap_states - 1; i >= 0; i--) {
			struct capacity_state *state = &sge->cap_states[i];

			if (state->frequency >= min_freq &&
			    state->frequency <= max_freq)
				seq_printf(m, "freq %lu pwr %lu\n",
					   state->frequency, state->power);
		}
		up_read(&policy->rwsem);
		cpufreq_cpu_put(policy);
	}

	return 0;
}

static int sge_proc_open(struct inode *inode, struct file *file)
{
	return single_open(file, sge_show, NULL);
}

static int sgefreq_show(struct seq_file *m, void *v)
{
	int cpu;

	for_each_possible_cpu(cpu) {
		struct cpufreq_policy *policy = cpufreq_cpu_get(cpu);
		struct cpufreq_frequency_table *pos, *table;

		if (!policy)
			continue;

		down_read(&policy->rwsem);
		table = policy->freq_table;
		if (table) {
			seq_printf(m, "cpu %d\n", cpu);
			cpufreq_for_each_valid_entry(pos, table) {
				if (pos->flags & CPUFREQ_BOOST_FREQ)
					continue;
				seq_printf(m, "%u\n", pos->frequency);
			}
		}
		up_read(&policy->rwsem);
		cpufreq_cpu_put(policy);
	}

	return 0;
}

static int sgefreq_proc_open(struct inode *inode, struct file *file)
{
	return single_open(file, sgefreq_show, NULL);
}

static int task_cpustats_open(struct inode *inode, struct file *file)
{
	int *offset;
	unsigned long begin, end;
	int cpu, idx;

	if (!READ_ONCE(sysctl_task_cpustats_enable))
		return -ENOMEM;

	if (down_interruptible(&task_cpustats_snapshot_sem))
		return -ERESTARTSYS;

	if (!READ_ONCE(sysctl_task_cpustats_enable))
		goto err_disabled;

	offset = __seq_open_private(file, &task_cpustats_seq_ops,
				    sizeof(*offset));
	if (!offset)
		goto err_nomem;

	memset(cpustats, 0, sizeof(cpustats));
	end = jiffies;
	begin = end - CTP_WINDOW_SZ * HZ;
	for_each_possible_cpu(cpu) {
		for (idx = 0; idx < MAX_CTP_WINDOW; idx++) {
			struct task_cpustat record;
			struct acct_cpustat *acct;
			unsigned long runtime, power;
			u64 charge;

			if (!task_cpustat_read_record(cpu, idx, &record))
				continue;
			if (record.pid <= 0 || record.pid >= MAX_PID)
				continue;
			if (time_before(record.begin, begin) ||
			    time_after(record.end, end))
				continue;

			runtime = record.end - record.begin;
			if (!runtime)
				continue;
			power = task_cpustats_get_power(cpu, record.freq);
			if (!power)
				continue;

			acct = &cpustats[record.pid];
			if (!acct->pwr)
				memcpy(acct->comm, record.comm, TASK_COMM_LEN);
			charge = (u64)power * jiffies_to_msecs(runtime);
			if (charge > (u64)INT_MAX - acct->pwr)
				acct->pwr = INT_MAX;
			else
				acct->pwr += (unsigned int)charge;
			acct->tgid = record.tgid;
		}
	}

	return 0;

err_nomem:
	up(&task_cpustats_snapshot_sem);
	return -ENOMEM;
err_disabled:
	up(&task_cpustats_snapshot_sem);
	return -ENOMEM;
}

static int task_cpustats_release(struct inode *inode, struct file *file)
{
	int ret = seq_release_private(inode, file);

	up(&task_cpustats_snapshot_sem);
	return ret;
}

static const struct file_operations sge_proc_fops = {
	.open		= sge_proc_open,
	.read		= seq_read,
	.llseek		= seq_lseek,
	.release	= single_release,
};

static const struct file_operations sgefreq_proc_fops = {
	.open		= sgefreq_proc_open,
	.read		= seq_read,
	.llseek		= seq_lseek,
	.release	= single_release,
};

static const struct file_operations task_cpustats_proc_fops = {
	.open		= task_cpustats_open,
	.read		= seq_read,
	.llseek		= seq_lseek,
	.release	= task_cpustats_release,
};

static int __init proc_task_cpustat_init(void)
{
	if (!proc_create("sgeinfo", 0, NULL, &sge_proc_fops))
		return -ENOMEM;

	if (!proc_create("sgefreqinfo", 0, NULL, &sgefreq_proc_fops)) {
		remove_proc_entry("sgeinfo", NULL);
		return -ENOMEM;
	}

	if (!proc_create("task_cpustats", 0, NULL,
			 &task_cpustats_proc_fops)) {
		remove_proc_entry("sgefreqinfo", NULL);
		remove_proc_entry("sgeinfo", NULL);
		return -ENOMEM;
	}

	return 0;
}
fs_initcall(proc_task_cpustat_init);
