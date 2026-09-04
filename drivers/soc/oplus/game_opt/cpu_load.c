// SPDX-License-Identifier: GPL-2.0-only
/*
 * Copyright (C) 2022 Oplus. All rights reserved.
 */

#include <linux/cpu.h>
#include <linux/cpufreq.h>
#include <linux/cpumask.h>
#include <linux/ktime.h>
#include <linux/math64.h>
#include <linux/percpu-defs.h>
#include <linux/proc_fs.h>
#include <linux/seq_file.h>
#include <linux/slab.h>
#include <linux/spinlock.h>
#include <linux/string.h>
#include <linux/types.h>

#include "game_ctrl.h"

#define KHZ_PER_MHZ 1000

struct time_in_state {
	spinlock_t lock;
	u64 last_read;
	u64 last_update;
	unsigned int *freq_table; /* MHz */
	u64 *time;
	unsigned int time_byte_size;
	unsigned int max_freq; /* MHz */
	unsigned int max_freq_state;
	unsigned int max_idle_state;
	unsigned int cur_idle_idx; /* 0=active, 1=idle */
	unsigned int cur_freq_idx;
};

static DEFINE_PER_CPU(struct time_in_state, stats_info);
static bool initialized;

/* Called with icpu->lock held. */
static inline void update_cur_state(struct time_in_state *icpu, u64 now)
{
	u64 delta_time = now - icpu->last_update;
	unsigned int pos;

	pos = icpu->cur_idle_idx * icpu->max_freq_state +
		icpu->cur_freq_idx;
	icpu->time[pos] += delta_time;
	icpu->last_update = now;
}

/* Called with icpu->lock held. */
static inline void reset_cur_state_after_read(struct time_in_state *icpu,
					      u64 now)
{
	memset(icpu->time, 0, icpu->time_byte_size);
	icpu->last_read = now;
	icpu->last_update = now;
}

static int cpufreq_table_get_index(struct time_in_state *stats,
				   unsigned int freq)
{
	int index;

	freq /= KHZ_PER_MHZ;
	for (index = 0; index < stats->max_freq_state; index++)
		if (stats->freq_table[index] == freq)
			return index;

	return -1;
}

static void get_cpu_load(int cpu, int *util_pct, int *busy_pct)
{
	struct time_in_state *icpu = per_cpu_ptr(&stats_info, cpu);
	u64 now, delta_time, delta_idle = 0, timeadjfreq = 0;
	unsigned long flags;
	unsigned int i;

	*util_pct = 0;
	*busy_pct = 0;
	if (!READ_ONCE(initialized))
		return;

	now = ktime_to_us(ktime_get());
	spin_lock_irqsave(&icpu->lock, flags);

	update_cur_state(icpu, now);
	delta_time = now - icpu->last_read;
	for (i = 0; i < icpu->max_freq_state; i++)
		timeadjfreq += icpu->freq_table[i] * icpu->time[i];
	for (i = 0; i < icpu->max_freq_state; i++)
		delta_idle += icpu->time[icpu->max_freq_state + i];

	if (delta_time && icpu->max_freq)
		*util_pct = div64_u64(100 * timeadjfreq,
					 delta_time * icpu->max_freq);
	if (delta_time > delta_idle)
		*busy_pct = div64_u64(100 * (delta_time - delta_idle),
					 delta_time);

	reset_cur_state_after_read(icpu, now);
	spin_unlock_irqrestore(&icpu->lock, flags);
}

void g_time_in_state_update_idle(int cpu, unsigned int new_idle_index)
{
	struct time_in_state *icpu;
	unsigned long flags;

	if (!READ_ONCE(initialized) || cpu < 0 || cpu >= nr_cpu_ids)
		return;

	icpu = per_cpu_ptr(&stats_info, cpu);
	if (new_idle_index >= icpu->max_idle_state)
		return;

	spin_lock_irqsave(&icpu->lock, flags);
	update_cur_state(icpu, ktime_to_us(ktime_get()));
	icpu->cur_idle_idx = new_idle_index;
	spin_unlock_irqrestore(&icpu->lock, flags);
}

static int time_in_state_update_freq(struct notifier_block *nb,
				     unsigned long event, void *data)
{
	struct cpufreq_freqs *freqs = data;
	const struct cpumask *cpus = cpumask_of(freqs->cpu);
	struct time_in_state *icpu;
	unsigned long flags;
	int cpu, new_freq_index;
	u64 now;

	if (event != CPUFREQ_POSTCHANGE || !READ_ONCE(initialized) ||
	    !cpus || cpumask_empty(cpus))
		return 0;

	icpu = per_cpu_ptr(&stats_info, cpumask_first(cpus));
	new_freq_index = cpufreq_table_get_index(icpu, freqs->new);
	if (new_freq_index < 0 || new_freq_index >= icpu->max_freq_state)
		return 0;

	now = ktime_to_us(ktime_get());
	for_each_cpu(cpu, cpus) {
		icpu = per_cpu_ptr(&stats_info, cpu);
		spin_lock_irqsave(&icpu->lock, flags);
		update_cur_state(icpu, now);
		icpu->cur_freq_idx = new_freq_index;
		spin_unlock_irqrestore(&icpu->lock, flags);
	}

	return 0;
}

static struct notifier_block cpufreq_transition_notifier = {
	.notifier_call = time_in_state_update_freq,
};

static void time_in_state_free(void)
{
	struct time_in_state *icpu;
	int cpu;

	for_each_present_cpu(cpu) {
		icpu = per_cpu_ptr(&stats_info, cpu);
		kfree(icpu->freq_table);
		icpu->freq_table = NULL;
		icpu->time = NULL;
	}
}

static int time_in_state_init(void)
{
	struct cpufreq_frequency_table *pos;
	struct time_in_state *icpu;
	struct cpufreq_policy policy;
	unsigned int alloc_size, count, i;
	int cpu, ret, freq_index;

	for_each_present_cpu(cpu) {
		icpu = per_cpu_ptr(&stats_info, cpu);
		icpu->max_idle_state = 2;
		icpu->cur_idle_idx = 0;

		ret = cpufreq_get_policy(&policy, cpu);
		if (ret)
			goto err_free;

		icpu->max_freq = policy.cpuinfo.max_freq / KHZ_PER_MHZ;
		count = cpufreq_table_count_valid_entries(&policy);
		if (!count) {
			ret = -ENODEV;
			goto err_free;
		}

		icpu->max_freq_state = count;
		icpu->time_byte_size = icpu->max_idle_state * count * sizeof(u64);
		alloc_size = count * sizeof(*icpu->freq_table) +
			icpu->time_byte_size;
		icpu->freq_table = kzalloc(alloc_size, GFP_KERNEL);
		if (!icpu->freq_table) {
			ret = -ENOMEM;
			goto err_free;
		}
		icpu->time = (u64 *)(icpu->freq_table + count);

		i = 0;
		cpufreq_for_each_valid_entry(pos, policy.freq_table)
			icpu->freq_table[i++] = pos->frequency / KHZ_PER_MHZ;

		freq_index = cpufreq_table_get_index(icpu, policy.cur);
		if (freq_index < 0) {
			ret = -EINVAL;
			goto err_free;
		}
		icpu->cur_freq_idx = freq_index;

		spin_lock_init(&icpu->lock);
		icpu->last_read = ktime_to_us(ktime_get());
		icpu->last_update = icpu->last_read;
	}

	ret = cpufreq_register_notifier(&cpufreq_transition_notifier,
					CPUFREQ_TRANSITION_NOTIFIER);
	if (ret)
		goto err_free;

	WRITE_ONCE(initialized, true);
	return 0;

err_free:
	time_in_state_free();
	return ret;
}

static int cpu_load_show(struct seq_file *m, void *v)
{
	int cpu, util_pct, busy_pct;

	for_each_possible_cpu(cpu) {
		get_cpu_load(cpu, &util_pct, &busy_pct);
		seq_printf(m, "CPU:%d busy_pct:%d util_pct:%d\n",
			   cpu, busy_pct, util_pct);
	}

	return 0;
}

static int cpu_load_proc_open(struct inode *inode, struct file *file)
{
	return single_open(file, cpu_load_show, inode);
}

static const struct file_operations cpu_load_proc_ops = {
	.open = cpu_load_proc_open,
	.read = seq_read,
	.llseek = seq_lseek,
	.release = single_release,
};

int cpu_load_init(void)
{
	int ret;

	if (unlikely(!game_opt_dir))
		return -ENOTDIR;

	ret = time_in_state_init();
	if (ret)
		return ret;

	if (!proc_create_data("cpu_load", 0444, game_opt_dir,
			      &cpu_load_proc_ops, NULL)) {
		WRITE_ONCE(initialized, false);
		cpufreq_unregister_notifier(&cpufreq_transition_notifier,
					    CPUFREQ_TRANSITION_NOTIFIER);
		time_in_state_free();
		return -ENOMEM;
	}

	return 0;
}

void cpu_load_exit(void)
{
	if (!READ_ONCE(initialized))
		return;

	WRITE_ONCE(initialized, false);
	cpufreq_unregister_notifier(&cpufreq_transition_notifier,
				    CPUFREQ_TRANSITION_NOTIFIER);
	remove_proc_entry("cpu_load", game_opt_dir);
	time_in_state_free();
}
