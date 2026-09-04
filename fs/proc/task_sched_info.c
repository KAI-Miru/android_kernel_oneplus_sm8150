// SPDX-License-Identifier: GPL-2.0-only
/*
 * Copyright (C) 2021 Oplus. All rights reserved.
 *
 * Android 14 task-scheduler telemetry adapted to the Qualcomm 4.14
 * scheduler used by the OnePlus 7 Pro H.40 kernel.  The proc wire format is
 * compatible with the OP9R donor while the producer and reader paths avoid
 * the donor's global-snapshot and reset races.
 */

#include <linux/atomic.h>
#include <linux/cpufreq.h>
#include <linux/cred.h>
#include <linux/init.h>
#include <linux/irq_work.h>
#include <linux/jiffies.h>
#include <linux/kernel.h>
#include <linux/kobject.h>
#include <linux/module.h>
#include <linux/moduleparam.h>
#include <linux/mutex.h>
#include <linux/proc_fs.h>
#include <linux/sched.h>
#include <linux/sched/clock.h>
#include <linux/sched/signal.h>
#include <linux/sched/stat.h>
#include <linux/sched/task.h>
#include <linux/seqlock.h>
#include <linux/seq_file.h>
#include <linux/slab.h>
#include <linux/spinlock.h>
#include <linux/string.h>
#include <linux/task_sched_info.h>
#include <linux/time.h>
#include <linux/uaccess.h>
#include <linux/vmalloc.h>
#include <linux/workqueue.h>

#include <asm/processor.h>

#include "internal.h"

#define TASK_SCHED_MAX_PIDS		10
#define TASK_SCHED_BUFFER_WORDS		3840
#define TASK_SCHED_NOTIFY_WORDS		2560
#define TASK_SCHED_NOTIFY_MIN_MS	1000
#define TASK_SCHED_CPU_COUNT		8
#define TASK_SCHED_MAX_THRESHOLDS	5
#define TASK_SCHED_THRESHOLD_MIN_NS	4000000ULL
#define TASK_SCHED_DURATION_MAX		0x00ffffffULL
#define TASK_SCHED_INPUT_LEN		(TASK_SCHED_MAX_PIDS * 21)

struct task_sched_record {
	u64 one;
	u64 two;
};

struct task_sched_snapshot {
	u64 *words;
	unsigned int count;
};

static unsigned int task_sched_info_enable;
static bool sched_info_ctrl = true;

static DEFINE_MUTEX(task_sched_control_lock);
static DEFINE_MUTEX(task_sched_snapshot_lock);
static DEFINE_RAW_SPINLOCK(task_sched_state_lock);
static DEFINE_RAW_SPINLOCK(task_sched_ring_lock);
static DEFINE_RAW_SPINLOCK(task_sched_backtrace_lock);
static DEFINE_SEQLOCK(task_sched_targets_lock);

static u64 task_sched_ring[2][TASK_SCHED_BUFFER_WORDS];
static unsigned int task_sched_active_bank;
static unsigned int task_sched_read;
static unsigned int task_sched_write;
static unsigned int task_sched_notify_count;

static pid_t systemserver_pid = -1;
static pid_t surfaceflinger_pid = -1;
static pid_t target_pids[TASK_SCHED_MAX_PIDS] = {
	[0 ... TASK_SCHED_MAX_PIDS - 1] = -1,
};

static unsigned int target_pids_num;
static u64 write_pid_time;

static u64 time_threshold[TASK_SCHED_MAX_THRESHOLDS] = {
	4000000ULL, 4000000ULL, 4000000ULL, 4000000ULL, 4000000ULL,
};

static unsigned long d_convert_info;
static u64 enable_sched_clock[NR_CPUS];
static unsigned int prev_freq[TASK_SCHED_CPU_COUNT] = {
	[0 ... TASK_SCHED_CPU_COUNT - 1] = ~0U,
};
static unsigned int prev_freq_min[TASK_SCHED_CPU_COUNT] = {
	[0 ... TASK_SCHED_CPU_COUNT - 1] = ~0U,
};
static unsigned int prev_freq_max[TASK_SCHED_CPU_COUNT] = {
	[0 ... TASK_SCHED_CPU_COUNT - 1] = ~0U,
};

static atomic_t notify_pending = ATOMIC_INIT(0);
static atomic_t uevent_id = ATOMIC_INIT(0);
static atomic_t last_producer_type = ATOMIC_INIT(-1);
static atomic_t last_producer_cpu = ATOMIC_INIT(-1);
static atomic64_t record_count = ATOMIC64_INIT(0);
static atomic64_t ring_overrun_count = ATOMIC64_INIT(0);
static atomic64_t notify_request_count = ATOMIC64_INIT(0);
static atomic64_t notify_coalesced_count = ATOMIC64_INIT(0);
static atomic64_t notify_suppressed_count = ATOMIC64_INIT(0);
static atomic64_t uevent_count = ATOMIC64_INIT(0);
static atomic64_t backtrace_queued_count = ATOMIC64_INIT(0);
static atomic64_t backtrace_dropped_count = ATOMIC64_INIT(0);
static struct irq_work sched_notify_irq_work;
static struct delayed_work sched_detect_work;
static unsigned long sched_last_notify_jiffies;
static struct irq_work task_sched_backtrace_irq_work;
static struct work_struct task_sched_backtrace_work;
static struct task_struct *task_sched_backtrace_task;
static struct kobject *sched_kobj;

static struct proc_dir_entry *task_info_dir;
static bool task_info_dir_owned;

static unsigned int task_sched_next_index(unsigned int index)
{
	index += 2;
	return index < TASK_SCHED_BUFFER_WORDS ? index : 0;
}

static u64 task_sched_record_header(unsigned int type, unsigned int cpu,
				    u64 clock)
{
	return (u64)(type & 0x1f) | ((u64)(cpu & 0x7) << 5) |
	       ((clock & 0x00ffffffffffffffULL) << 8);
}

static void task_sched_reset_freq_state(void)
{
	unsigned long flags;
	unsigned int cpu;

	raw_spin_lock_irqsave(&task_sched_state_lock, flags);
	for (cpu = 0; cpu < TASK_SCHED_CPU_COUNT; cpu++) {
		prev_freq[cpu] = ~0U;
		prev_freq_min[cpu] = ~0U;
		prev_freq_max[cpu] = ~0U;
	}
	raw_spin_unlock_irqrestore(&task_sched_state_lock, flags);
}

static int task_sched_target_index(pid_t tgid)
{
	unsigned int sequence;
	unsigned int count;
	unsigned int i;
	int target;

	do {
		sequence = read_seqbegin(&task_sched_targets_lock);
		count = min_t(unsigned int, target_pids_num,
			      TASK_SCHED_MAX_PIDS);
		target = -ENOENT;
		for (i = 0; i < count; i++) {
			if (target_pids[i] == tgid) {
				target = i;
				break;
			}
		}
	} while (read_seqretry(&task_sched_targets_lock, sequence));

	return target;
}

static void task_sched_reset_ring(void)
{
	unsigned long flags;

	mutex_lock(&task_sched_snapshot_lock);
	raw_spin_lock_irqsave(&task_sched_ring_lock, flags);
	task_sched_active_bank = 0;
	task_sched_read = 0;
	task_sched_write = 0;
	task_sched_notify_count = 0;
	raw_spin_unlock_irqrestore(&task_sched_ring_lock, flags);
	atomic_set(&notify_pending, 0);
	WRITE_ONCE(sched_last_notify_jiffies, 0);
	mutex_unlock(&task_sched_snapshot_lock);
}

static void task_sched_put_record(const struct task_sched_record *record)
{
	unsigned long flags;
	unsigned int next;
	bool notify = false;

	raw_spin_lock_irqsave(&task_sched_ring_lock, flags);
	if (!READ_ONCE(task_sched_info_enable))
		goto out;

	task_sched_ring[task_sched_active_bank][task_sched_write] = record->one;
	task_sched_ring[task_sched_active_bank][task_sched_write + 1] = record->two;

	next = task_sched_next_index(task_sched_write);
	task_sched_write = next;
	if (task_sched_read == next) {
		task_sched_read = task_sched_next_index(task_sched_read);
		atomic64_inc(&ring_overrun_count);
	}
	atomic64_inc(&record_count);
	atomic_set(&last_producer_type, record->one & 0x1f);
	atomic_set(&last_producer_cpu, (record->one >> 5) & 0x7);

	task_sched_notify_count += 2;
	if (task_sched_notify_count >= TASK_SCHED_NOTIFY_WORDS) {
		task_sched_notify_count -= TASK_SCHED_NOTIFY_WORDS;
		notify = true;
	}
out:
	raw_spin_unlock_irqrestore(&task_sched_ring_lock, flags);
	if (notify)
		sched_action_trig();
}

static void task_sched_notify_irq_workfn(struct irq_work *work)
{
	unsigned long earliest;
	unsigned long delay = 0;

	earliest = READ_ONCE(sched_last_notify_jiffies) +
		msecs_to_jiffies(TASK_SCHED_NOTIFY_MIN_MS);
	if (time_before(jiffies, earliest))
		delay = earliest - jiffies;
	schedule_delayed_work(&sched_detect_work, delay);
}

static void task_sched_detect_workfn(struct work_struct *work)
{
	char schednum[32];
	char *envp[] = {
		"SCHEDACTION=uevent",
		schednum,
		NULL,
	};
	unsigned int id;

	if (!atomic_xchg(&notify_pending, 0))
		return;
	if (!READ_ONCE(task_sched_info_enable) ||
	    !READ_ONCE(sched_info_ctrl) || !sched_kobj) {
		atomic64_inc(&notify_suppressed_count);
		return;
	}

	id = atomic_inc_return(&uevent_id) - 1;
	snprintf(schednum, sizeof(schednum), "SCHEDNUM=%u", id);
	kobject_uevent_env(sched_kobj, KOBJ_CHANGE, envp);
	WRITE_ONCE(sched_last_notify_jiffies, jiffies);
	atomic64_inc(&uevent_count);
}

void sched_action_trig(void)
{
	if (!READ_ONCE(task_sched_info_enable) ||
	    !READ_ONCE(sched_info_ctrl) || !sched_kobj) {
		atomic64_inc(&notify_suppressed_count);
		return;
	}

	atomic64_inc(&notify_request_count);
	if (atomic_cmpxchg(&notify_pending, 0, 1)) {
		atomic64_inc(&notify_coalesced_count);
		return;
	}
	irq_work_queue(&sched_notify_irq_work);
}

void get_target_thread_pid(struct task_struct *task)
{
	struct task_struct *leader;
	unsigned long flags;

	if (!task || task_uid(task).val != 1000)
		return;

	if (strnstr(task->comm, "android.anim", TASK_COMM_LEN)) {
		WRITE_ONCE(systemserver_pid, task->tgid);
		if (READ_ONCE(task_sched_info_enable)) {
			write_seqlock_irqsave(&task_sched_targets_lock, flags);
			target_pids[0] = task->tgid;
			write_sequnlock_irqrestore(&task_sched_targets_lock,
						   flags);
		}
		return;
	}

	leader = task->group_leader;
	if (leader && strnstr(leader->comm, "surfaceflinger", TASK_COMM_LEN)) {
		WRITE_ONCE(surfaceflinger_pid, leader->pid);
		if (READ_ONCE(task_sched_info_enable)) {
			write_seqlock_irqsave(&task_sched_targets_lock, flags);
			target_pids[1] = leader->pid;
			write_sequnlock_irqrestore(&task_sched_targets_lock,
						   flags);
		}
	}
}

static void task_sched_refresh_system_pids(void)
{
	struct task_struct *group;
	struct task_struct *task;
	char comm[TASK_COMM_LEN];
	pid_t system = -1;
	pid_t surfaceflinger = -1;

	rcu_read_lock();
	for_each_process_thread(group, task) {
		if (task_uid(task).val != 1000)
			continue;

		get_task_comm(comm, task);
		if (system < 0 &&
		    strnstr(comm, "android.anim", TASK_COMM_LEN))
			system = task->tgid;

		if (surfaceflinger < 0 && task->group_leader) {
			get_task_comm(comm, task->group_leader);
			if (strnstr(comm, "surfaceflinger", TASK_COMM_LEN))
				surfaceflinger = task->group_leader->pid;
		}

		if (system >= 0 && surfaceflinger >= 0)
			goto found;
	}
found:
	rcu_read_unlock();

	if (system >= 0)
		WRITE_ONCE(systemserver_pid, system);
	if (surfaceflinger >= 0)
		WRITE_ONCE(surfaceflinger_pid, surfaceflinger);
}

void update_wake_tid(struct task_struct *p, struct task_struct *current_task,
		     unsigned int type)
{
	u64 wake;

	if (!READ_ONCE(task_sched_info_enable) || !p || !current_task)
		return;

	wake = ((u64)(u16)current_task->pid) | ((u64)(type & 0x3) << 16);
	WRITE_ONCE(p->wake_tid, wake);
}

static void task_sched_backtrace_workfn(struct work_struct *work)
{
	struct task_sched_record record;
	struct task_struct *p;
	unsigned long flags;
	unsigned long address;

	raw_spin_lock_irqsave(&task_sched_backtrace_lock, flags);
	p = task_sched_backtrace_task;
	task_sched_backtrace_task = NULL;
	raw_spin_unlock_irqrestore(&task_sched_backtrace_lock, flags);
	if (!p)
		return;
	if (!READ_ONCE(task_sched_info_enable))
		goto put_task;

	address = get_wchan(p);
	record.one = (u64)task_sched_info_backtrace |
		     ((u64)(u16)p->pid << 8);
	record.two = (u64)address;

	if (address && !READ_ONCE(d_convert_info))
		cmpxchg(&d_convert_info, 0UL, address);

	task_sched_put_record(&record);
put_task:
	put_task_struct(p);
}

static void task_sched_backtrace_irq_workfn(struct irq_work *work)
{
	schedule_work(&task_sched_backtrace_work);
}

static void task_sched_queue_backtrace(struct task_struct *p)
{
	unsigned long flags;
	bool queued = false;

	get_task_struct(p);
	raw_spin_lock_irqsave(&task_sched_backtrace_lock, flags);
	if (READ_ONCE(task_sched_info_enable) &&
	    !task_sched_backtrace_task) {
		task_sched_backtrace_task = p;
		queued = true;
	}
	raw_spin_unlock_irqrestore(&task_sched_backtrace_lock, flags);

	if (!queued) {
		put_task_struct(p);
		atomic64_inc(&backtrace_dropped_count);
		return;
	}

	atomic64_inc(&backtrace_queued_count);
	irq_work_queue(&task_sched_backtrace_irq_work);
}

static void task_sched_cancel_backtrace(void)
{
	struct task_struct *p;
	unsigned long flags;

	irq_work_sync(&task_sched_backtrace_irq_work);
	cancel_work_sync(&task_sched_backtrace_work);
	raw_spin_lock_irqsave(&task_sched_backtrace_lock, flags);
	p = task_sched_backtrace_task;
	task_sched_backtrace_task = NULL;
	raw_spin_unlock_irqrestore(&task_sched_backtrace_lock, flags);
	if (p)
		put_task_struct(p);
}

void update_task_sched_info(struct task_struct *p, u64 delay, int type,
			    int cpu)
{
	struct task_sched_record record;
	u64 wake_tid;
	u64 clock;
	u64 epoch;
	int target;

	if (!READ_ONCE(task_sched_info_enable) || !p)
		return;
	if (type < task_sched_info_running || type > task_sched_info_S)
		return;
	if (cpu < 0 || cpu >= nr_cpu_ids)
		return;
	if (delay < READ_ONCE(time_threshold[type]))
		return;

	target = task_sched_target_index(p->tgid);
	if (target < 0)
		return;

	clock = sched_clock_cpu(cpu);
	epoch = READ_ONCE(enable_sched_clock[cpu]);
	if (!epoch || clock < epoch || delay > clock - epoch)
		return;
	delay >>= 20;
	if (delay > TASK_SCHED_DURATION_MAX)
		delay = TASK_SCHED_DURATION_MAX;
	wake_tid = READ_ONCE(p->wake_tid) & 0x0003ffffULL;

	record.one = (u64)(type & 0x1f) | ((u64)(cpu & 0x7) << 5) |
		     ((clock & 0x00ffffffffffffffULL) << 8);
	record.two = delay | ((u64)(u16)p->pid << 24) |
		     ((u64)(target & 0xf) << 58);

	switch (type) {
	case task_sched_info_running:
		break;
	case task_sched_info_runnable:
		record.two |= wake_tid << 40;
		break;
	case task_sched_info_D:
		task_sched_queue_backtrace(p);
		/* fall through */
	case task_sched_info_IO:
	case task_sched_info_S:
		wake_tid &= ~BIT_ULL(16);
		record.two |= wake_tid << 40;
		break;
	default:
		return;
	}

	task_sched_put_record(&record);
}

void update_running_start_time(struct task_struct *prev,
			       struct task_struct *next)
{
	u64 clock;
	u64 epoch;
	u64 start;
	int cpu;

	if (!READ_ONCE(task_sched_info_enable) || !prev || !next)
		return;

	cpu = task_cpu(prev);
	if (cpu < 0 || cpu >= nr_cpu_ids)
		return;
	clock = sched_clock_cpu(cpu);
	epoch = READ_ONCE(enable_sched_clock[cpu]);

	start = READ_ONCE(prev->running_start_time);
	if (epoch && start >= epoch && clock > start)
		update_task_sched_info(prev, clock - start,
				       task_sched_info_running, cpu);
	WRITE_ONCE(prev->running_start_time, 0);
	WRITE_ONCE(next->running_start_time, clock);
}

void update_freq_info(struct cpufreq_policy *policy)
{
	struct task_sched_record record;
	unsigned long flags;
	unsigned int cpu;
	unsigned int cur;
	u64 clock;
	u64 epoch;
	bool changed = false;

	if (!READ_ONCE(task_sched_info_enable) || !policy)
		return;
	cpu = READ_ONCE(policy->cpu);
	if (cpu >= TASK_SCHED_CPU_COUNT || cpu >= nr_cpu_ids)
		return;
	clock = sched_clock_cpu(cpu);
	epoch = READ_ONCE(enable_sched_clock[cpu]);
	if (!epoch || clock < epoch)
		return;
	cur = READ_ONCE(policy->cur);

	raw_spin_lock_irqsave(&task_sched_state_lock, flags);
	if (READ_ONCE(task_sched_info_enable) &&
	    epoch == READ_ONCE(enable_sched_clock[cpu]) &&
	    prev_freq[cpu] != cur) {
		prev_freq[cpu] = cur;
		changed = true;
	}
	raw_spin_unlock_irqrestore(&task_sched_state_lock, flags);
	if (!changed)
		return;

	record.one = task_sched_record_header(task_sched_info_freq, cpu, clock);
	record.two = (u64)cur;
	task_sched_put_record(&record);
}

void update_freq_limit_info(struct cpufreq_policy *policy)
{
	struct task_sched_record record;
	unsigned long flags;
	unsigned int cpu;
	unsigned int min;
	unsigned int max;
	u64 clock;
	u64 epoch;
	bool changed = false;

	if (!READ_ONCE(task_sched_info_enable) || !policy)
		return;
	cpu = READ_ONCE(policy->cpu);
	if (cpu >= TASK_SCHED_CPU_COUNT || cpu >= nr_cpu_ids)
		return;
	clock = sched_clock_cpu(cpu);
	epoch = READ_ONCE(enable_sched_clock[cpu]);
	if (!epoch || clock < epoch)
		return;
	min = READ_ONCE(policy->min);
	max = READ_ONCE(policy->max);

	raw_spin_lock_irqsave(&task_sched_state_lock, flags);
	if (READ_ONCE(task_sched_info_enable) &&
	    epoch == READ_ONCE(enable_sched_clock[cpu]) &&
	    (prev_freq_min[cpu] != min || prev_freq_max[cpu] != max)) {
		prev_freq_min[cpu] = min;
		prev_freq_max[cpu] = max;
		changed = true;
	}
	raw_spin_unlock_irqrestore(&task_sched_state_lock, flags);
	if (!changed)
		return;

	record.one = task_sched_record_header(task_sched_info_freq_limit, cpu,
					      clock);
	record.two = ((u64)min & 0x00ffffffULL) |
		     (((u64)max & 0x00ffffffULL) << 24) |
		     ((u64)(u16)current->pid << 48);
	task_sched_put_record(&record);
}

void update_cpu_isolate_info(int cpu, u64 type)
{
	struct task_sched_record record;
	u64 clock;
	u64 epoch;

	if (!READ_ONCE(task_sched_info_enable))
		return;
	if (cpu < 0 || cpu >= TASK_SCHED_CPU_COUNT || cpu >= nr_cpu_ids)
		return;
	if (type > cpu_isolate)
		return;
	clock = sched_clock_cpu(cpu);
	epoch = READ_ONCE(enable_sched_clock[cpu]);
	if (!epoch || clock < epoch ||
	    !READ_ONCE(task_sched_info_enable))
		return;

	record.one = task_sched_record_header(task_sched_info_isolate, cpu,
					      clock);
	record.two = (type & 0xffULL) | ((u64)(u16)current->pid << 8);
	task_sched_put_record(&record);
}

static u64 task_sched_realtime_us(void)
{
	struct timespec ts;

	getnstimeofday(&ts);
	return (u64)ts.tv_sec * 1000000ULL + ts.tv_nsec / 1000;
}

static int pids_set_show(struct seq_file *m, void *v)
{
	pid_t pids[TASK_SCHED_MAX_PIDS];
	u64 timestamp;
	unsigned int sequence;
	unsigned int count;
	unsigned int i;

	if (!READ_ONCE(task_sched_info_enable))
		return -EFAULT;

	do {
		sequence = read_seqbegin(&task_sched_targets_lock);
		timestamp = write_pid_time;
		count = min_t(unsigned int, target_pids_num,
			      TASK_SCHED_MAX_PIDS);
		for (i = 0; i < count; i++)
			pids[i] = target_pids[i];
	} while (read_seqretry(&task_sched_targets_lock, sequence));

	seq_printf(m, "%llu ", (unsigned long long)timestamp);
	for (i = 0; i < count; i++)
		seq_printf(m, "%d ", pids[i]);
	seq_putc(m, '\n');
	return 0;
}

static int pids_set_open(struct inode *inode, struct file *file)
{
	return single_open(file, pids_set_show, NULL);
}

static ssize_t pids_set_write(struct file *file, const char __user *buf,
			      size_t count, loff_t *ppos)
{
	char input[TASK_SCHED_INPUT_LEN];
	char *cursor;
	char *token;
	pid_t new_pids[TASK_SCHED_MAX_PIDS];
	unsigned int nr = 2;
	unsigned int i;
	unsigned long flags;
	int pid;

	if (!READ_ONCE(task_sched_info_enable))
		return -EFAULT;
	if (!count)
		return 0;
	if (count >= sizeof(input))
		return -E2BIG;
	if (copy_from_user(input, buf, count))
		return -EFAULT;
	input[count] = '\0';
	task_sched_refresh_system_pids();

	for (i = 0; i < TASK_SCHED_MAX_PIDS; i++)
		new_pids[i] = -1;
	new_pids[0] = READ_ONCE(systemserver_pid);
	new_pids[1] = READ_ONCE(surfaceflinger_pid);

	cursor = input;
	while ((token = strsep(&cursor, " \t\r\n")) != NULL &&
	       nr < TASK_SCHED_MAX_PIDS) {
		if (!*token)
			continue;
		if (kstrtoint(token, 0, &pid) || pid <= 0)
			continue;
		new_pids[nr++] = pid;
	}

	mutex_lock(&task_sched_control_lock);
	if (!READ_ONCE(task_sched_info_enable)) {
		mutex_unlock(&task_sched_control_lock);
		return -EFAULT;
	}
	write_seqlock_irqsave(&task_sched_targets_lock, flags);
	target_pids_num = 0;
	for (i = 0; i < TASK_SCHED_MAX_PIDS; i++)
		target_pids[i] = new_pids[i];
	target_pids_num = nr;
	write_pid_time = task_sched_realtime_us();
	write_sequnlock_irqrestore(&task_sched_targets_lock, flags);
	mutex_unlock(&task_sched_control_lock);

	return count;
}

static const struct file_operations pids_set_fops = {
	.open		= pids_set_open,
	.read		= seq_read,
	.write		= pids_set_write,
	.llseek		= seq_lseek,
	.release	= single_release,
};

static int sched_buffer_show(struct seq_file *m, void *v)
{
	struct task_sched_snapshot *snapshot = m->private;
	unsigned int i;

	for (i = 0; i + 1 < snapshot->count; i += 2)
		seq_printf(m, "%llu %llu\n",
			   (unsigned long long)snapshot->words[i],
			   (unsigned long long)snapshot->words[i + 1]);
	return 0;
}

static int sched_buffer_open(struct inode *inode, struct file *file)
{
	struct task_sched_snapshot *snapshot;
	unsigned long flags;
	unsigned int read;
	unsigned int write;
	unsigned int first;
	unsigned int drain_bank;
	int ret;

	if (!READ_ONCE(task_sched_info_enable))
		return -ENOMEM;

	snapshot = kzalloc(sizeof(*snapshot), GFP_KERNEL);
	if (!snapshot)
		return -ENOMEM;
	snapshot->words = vzalloc(TASK_SCHED_BUFFER_WORDS *
				 sizeof(*snapshot->words));
	if (!snapshot->words) {
		kfree(snapshot);
		return -ENOMEM;
	}

	mutex_lock(&task_sched_snapshot_lock);
	raw_spin_lock_irqsave(&task_sched_ring_lock, flags);
	if (!READ_ONCE(task_sched_info_enable)) {
		raw_spin_unlock_irqrestore(&task_sched_ring_lock, flags);
		mutex_unlock(&task_sched_snapshot_lock);
		vfree(snapshot->words);
		kfree(snapshot);
		return -ENOMEM;
	}
	drain_bank = task_sched_active_bank;
	read = task_sched_read;
	write = task_sched_write;
	task_sched_active_bank ^= 1;
	task_sched_read = 0;
	task_sched_write = 0;
	task_sched_notify_count = 0;
	atomic_set(&notify_pending, 0);
	raw_spin_unlock_irqrestore(&task_sched_ring_lock, flags);

	snapshot->count = write >= read ? write - read :
		TASK_SCHED_BUFFER_WORDS - read + write;
	first = min_t(unsigned int, snapshot->count,
		      TASK_SCHED_BUFFER_WORDS - read);
	memcpy(snapshot->words, &task_sched_ring[drain_bank][read],
	       first * sizeof(u64));
	if (snapshot->count > first)
		memcpy(snapshot->words + first, task_sched_ring[drain_bank],
		       (snapshot->count - first) * sizeof(u64));
	mutex_unlock(&task_sched_snapshot_lock);

	ret = single_open(file, sched_buffer_show, snapshot);
	if (ret) {
		vfree(snapshot->words);
		kfree(snapshot);
	}
	return ret;
}

static int sched_buffer_release(struct inode *inode, struct file *file)
{
	struct seq_file *m = file->private_data;
	struct task_sched_snapshot *snapshot = m->private;

	vfree(snapshot->words);
	kfree(snapshot);
	return single_release(inode, file);
}

static const struct file_operations sched_buffer_fops = {
	.open		= sched_buffer_open,
	.read		= seq_read,
	.llseek		= seq_lseek,
	.release	= sched_buffer_release,
};

static int task_sched_info_enable_show(struct seq_file *m, void *v)
{
	unsigned int cpu;

	if (!READ_ONCE(task_sched_info_enable))
		return -EFAULT;

	seq_printf(m, "%llu ", (unsigned long long)task_sched_realtime_us());
	for (cpu = 0; cpu < nr_cpu_ids; cpu++)
		seq_printf(m, "%llu ",
			   (unsigned long long)sched_clock_cpu(cpu));
	seq_putc(m, '\n');
	return 0;
}

static int task_sched_info_enable_open(struct inode *inode, struct file *file)
{
	return single_open(file, task_sched_info_enable_show, NULL);
}

static ssize_t task_sched_info_enable_write(struct file *file,
					    const char __user *buf,
					    size_t count, loff_t *ppos)
{
	char input[PROC_NUMBUF];
	unsigned int enable;
	unsigned int i;
	unsigned long flags;
	int ret;

	if (!count)
		return 0;
	if (count >= sizeof(input))
		return -E2BIG;
	if (copy_from_user(input, buf, count))
		return -EFAULT;
	input[count] = '\0';
	ret = kstrtouint(strstrip(input), 0, &enable);
	if (ret)
		return ret;

	mutex_lock(&task_sched_control_lock);
	if (enable) {
		force_schedstat_enabled();
		if (!READ_ONCE(task_sched_info_enable)) {
			task_sched_refresh_system_pids();
			task_sched_reset_ring();
			task_sched_reset_freq_state();
			WRITE_ONCE(d_convert_info, 0);
			write_seqlock_irqsave(&task_sched_targets_lock, flags);
			write_pid_time = 0;
			target_pids_num = 0;
			for (i = 0; i < TASK_SCHED_MAX_PIDS; i++)
				target_pids[i] = -1;
			target_pids[0] = READ_ONCE(systemserver_pid);
			target_pids[1] = READ_ONCE(surfaceflinger_pid);
			target_pids_num = 2;
			write_sequnlock_irqrestore(&task_sched_targets_lock,
						   flags);
			for (i = 0; i < nr_cpu_ids; i++)
				WRITE_ONCE(enable_sched_clock[i],
					   sched_clock_cpu(i));
			/* Publish target and clock epochs before enabling hot paths. */
			smp_wmb();
			WRITE_ONCE(task_sched_info_enable, enable);
		} else {
			WRITE_ONCE(task_sched_info_enable, enable);
		}
	} else {
		WRITE_ONCE(task_sched_info_enable, 0);
		write_seqlock_irqsave(&task_sched_targets_lock, flags);
		target_pids_num = 0;
		write_pid_time = 0;
		for (i = 0; i < TASK_SCHED_MAX_PIDS; i++)
			target_pids[i] = -1;
		write_sequnlock_irqrestore(&task_sched_targets_lock, flags);
		task_sched_reset_ring();
		WRITE_ONCE(d_convert_info, 0);
		for (i = 0; i < nr_cpu_ids; i++)
			WRITE_ONCE(enable_sched_clock[i], 0);
		irq_work_sync(&sched_notify_irq_work);
		cancel_delayed_work_sync(&sched_detect_work);
		task_sched_cancel_backtrace();
	}
	mutex_unlock(&task_sched_control_lock);
	return count;
}

static const struct file_operations task_sched_info_enable_fops = {
	.open		= task_sched_info_enable_open,
	.read		= seq_read,
	.write		= task_sched_info_enable_write,
	.llseek		= seq_lseek,
	.release	= single_release,
};

static int sched_info_threshold_show(struct seq_file *m, void *v)
{
	if (!READ_ONCE(task_sched_info_enable))
		return -EFAULT;

	seq_printf(m,
		   "running:%llu\trunnable:%llu\tblock/IO:%llu\tD:%llu\tS:%llu\n",
		   (unsigned long long)READ_ONCE(time_threshold[0]),
		   (unsigned long long)READ_ONCE(time_threshold[1]),
		   (unsigned long long)READ_ONCE(time_threshold[2]),
		   (unsigned long long)READ_ONCE(time_threshold[3]),
		   (unsigned long long)READ_ONCE(time_threshold[4]));
	return 0;
}

static int sched_info_threshold_open(struct inode *inode, struct file *file)
{
	return single_open(file, sched_info_threshold_show, NULL);
}

static ssize_t sched_info_threshold_write(struct file *file,
					  const char __user *buf,
					  size_t count, loff_t *ppos)
{
	char input[TASK_SCHED_MAX_THRESHOLDS * 21];
	char *cursor;
	char *token;
	u64 values[TASK_SCHED_MAX_THRESHOLDS];
	unsigned int nr = 0;
	unsigned int i;

	if (!READ_ONCE(task_sched_info_enable))
		return -EFAULT;
	if (!count)
		return 0;
	if (count >= sizeof(input))
		return -E2BIG;
	if (copy_from_user(input, buf, count))
		return -EFAULT;
	input[count] = '\0';

	for (i = 0; i < TASK_SCHED_MAX_THRESHOLDS; i++)
		values[i] = READ_ONCE(time_threshold[i]);
	cursor = input;
	while ((token = strsep(&cursor, " \t\r\n")) != NULL &&
	       nr < TASK_SCHED_MAX_THRESHOLDS) {
		if (!*token)
			continue;
		if (kstrtou64(token, 0, &values[nr]))
			continue;
		nr++;
	}
	if (!nr)
		return -EINVAL;
	for (i = 0; i < nr; i++) {
		if (values[i] < TASK_SCHED_THRESHOLD_MIN_NS)
			return -ERANGE;
	}

	mutex_lock(&task_sched_control_lock);
	if (!READ_ONCE(task_sched_info_enable)) {
		mutex_unlock(&task_sched_control_lock);
		return -EFAULT;
	}
	for (i = 0; i < nr; i++)
		WRITE_ONCE(time_threshold[i], values[i]);
	mutex_unlock(&task_sched_control_lock);
	return count;
}

static const struct file_operations sched_info_threshold_fops = {
	.open		= sched_info_threshold_open,
	.read		= seq_read,
	.write		= sched_info_threshold_write,
	.llseek		= seq_lseek,
	.release	= single_release,
};

static int d_convert_show(struct seq_file *m, void *v)
{
	unsigned long address;

	if (!READ_ONCE(task_sched_info_enable))
		return -EFAULT;
	address = READ_ONCE(d_convert_info);
	if (address)
		seq_printf(m, "%pS %pK\n", (void *)address, (void *)address);
	else
		seq_putc(m, '\n');
	return 0;
}

static int d_convert_open(struct inode *inode, struct file *file)
{
	return single_open(file, d_convert_show, NULL);
}

static const struct file_operations d_convert_fops = {
	.open		= d_convert_open,
	.read		= seq_read,
	.llseek		= seq_lseek,
	.release	= single_release,
};

static int sched_stats_show(struct seq_file *m, void *v)
{
	seq_printf(m, "enabled %u\n", READ_ONCE(task_sched_info_enable));
	seq_printf(m, "notify_enabled %u\n", READ_ONCE(sched_info_ctrl));
	seq_printf(m, "notify_pending %d\n", atomic_read(&notify_pending));
	seq_printf(m, "records %lld\n",
		   (long long)atomic64_read(&record_count));
	seq_printf(m, "ring_overruns %lld\n",
		   (long long)atomic64_read(&ring_overrun_count));
	seq_printf(m, "notify_requests %lld\n",
		   (long long)atomic64_read(&notify_request_count));
	seq_printf(m, "notify_coalesced %lld\n",
		   (long long)atomic64_read(&notify_coalesced_count));
	seq_printf(m, "notify_suppressed %lld\n",
		   (long long)atomic64_read(&notify_suppressed_count));
	seq_printf(m, "uevents %lld\n",
		   (long long)atomic64_read(&uevent_count));
	seq_printf(m, "backtraces_queued %lld\n",
		   (long long)atomic64_read(&backtrace_queued_count));
	seq_printf(m, "backtraces_dropped %lld\n",
		   (long long)atomic64_read(&backtrace_dropped_count));
	seq_printf(m, "last_producer_type %d\n",
		   atomic_read(&last_producer_type));
	seq_printf(m, "last_producer_cpu %d\n",
		   atomic_read(&last_producer_cpu));
	seq_printf(m, "last_uevent_jiffies %lu\n",
		   READ_ONCE(sched_last_notify_jiffies));
	return 0;
}

static int sched_stats_open(struct inode *inode, struct file *file)
{
	return single_open(file, sched_stats_show, NULL);
}

static const struct file_operations sched_stats_fops = {
	.open		= sched_stats_open,
	.read		= seq_read,
	.llseek		= seq_lseek,
	.release	= single_release,
};

static int __init task_sched_info_init(void)
{
	struct proc_dir_entry *sched_dir;

	init_irq_work(&sched_notify_irq_work, task_sched_notify_irq_workfn);
	INIT_DELAYED_WORK(&sched_detect_work, task_sched_detect_workfn);
	init_irq_work(&task_sched_backtrace_irq_work,
		      task_sched_backtrace_irq_workfn);
	INIT_WORK(&task_sched_backtrace_work, task_sched_backtrace_workfn);
	sched_kobj = kset_find_obj(module_kset, KBUILD_MODNAME);
	if (!sched_kobj)
		pr_warn("task_sched_info: module kobject unavailable; uevents disabled\n");

	task_info_dir = proc_mkdir("task_info", NULL);
	if (task_info_dir) {
		task_info_dir_owned = true;
		sched_dir = proc_mkdir("task_sched_info", task_info_dir);
	} else {
		sched_dir = proc_mkdir("task_info/task_sched_info", NULL);
	}
	if (!sched_dir) {
		if (task_info_dir_owned)
			remove_proc_entry("task_info", NULL);
		if (sched_kobj) {
			kobject_put(sched_kobj);
			sched_kobj = NULL;
		}
		return -ENOMEM;
	}

	if (!proc_create("pids_set", 0666, sched_dir, &pids_set_fops) ||
	    !proc_create("sched_buffer", 0666, sched_dir,
			 &sched_buffer_fops) ||
	    !proc_create("task_sched_info_enable", 0666, sched_dir,
			 &task_sched_info_enable_fops) ||
	    !proc_create("sched_info_threshold", 0666, sched_dir,
			 &sched_info_threshold_fops) ||
	    !proc_create("d_convert", 0666, sched_dir, &d_convert_fops) ||
	    !proc_create("sched_stats", 0444, sched_dir, &sched_stats_fops)) {
		remove_proc_subtree("task_info/task_sched_info", NULL);
		if (task_info_dir_owned)
			remove_proc_entry("task_info", NULL);
		if (sched_kobj) {
			kobject_put(sched_kobj);
			sched_kobj = NULL;
		}
		return -ENOMEM;
	}

	return 0;
}
module_init(task_sched_info_init);

module_param_named(sched_info_ctrl, sched_info_ctrl, bool, 0644);
MODULE_PARM_DESC(sched_info_ctrl,
		 "Enable rate-limited task scheduler telemetry uevents");
MODULE_DESCRIPTION("Oplus task scheduler telemetry");
MODULE_LICENSE("GPL v2");
