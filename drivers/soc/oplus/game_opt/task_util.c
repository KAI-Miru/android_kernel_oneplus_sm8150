// SPDX-License-Identifier: GPL-2.0-only
/*
 * Copyright (C) 2022 Oplus. All rights reserved.
 */

#include <linux/atomic.h>
#include <linux/cpufreq.h>
#include <linux/fs.h>
#include <linux/kernel.h>
#include <linux/ktime.h>
#include <linux/list.h>
#include <linux/math64.h>
#include <linux/mutex.h>
#include <linux/proc_fs.h>
#include <linux/rcupdate.h>
#include <linux/sched.h>
#include <linux/sched/signal.h>
#include <linux/sched/topology.h>
#include <linux/seq_file.h>
#include <linux/slab.h>
#include <linux/sort.h>
#include <linux/spinlock.h>
#include <linux/string.h>
#include <linux/uaccess.h>

#include "game_ctrl.h"

#define MAX_TASK_NR 10
#define MAX_TID_COUNT 256
#define MAX_TASK_INACTIVE_TIME NSEC_PER_SEC

struct task_runtime_info {
	struct list_head node;
	pid_t tid;
	u64 sum_exec_scale;
	u64 last_update_ts;
};

struct task_util_result {
	pid_t tid;
	u16 util;
};

static LIST_HEAD(running_task_list);
static LIST_HEAD(free_task_list);
static DEFINE_MUTEX(game_task_mutex);
static DEFINE_RAW_SPINLOCK(game_task_lock);
static atomic_t need_stat_runtime = ATOMIC_INIT(0);
static struct task_struct *game_leader;
static struct task_runtime_info *task_pool;
static u64 window_start;

static void init_task_pool_locked(struct task_runtime_info *pool)
{
	int i;

	INIT_LIST_HEAD(&running_task_list);
	INIT_LIST_HEAD(&free_task_list);
	for (i = 0; i < MAX_TID_COUNT; i++)
		list_add_tail(&pool[i].node, &free_task_list);
}

static struct task_runtime_info *alloc_task_info_locked(void)
{
	struct task_runtime_info *info;

	if (list_empty(&free_task_list))
		return NULL;

	info = list_first_entry(&free_task_list, struct task_runtime_info, node);
	list_del_init(&info->node);
	return info;
}

static void free_task_info_locked(struct task_runtime_info *info)
{
	list_del_init(&info->node);
	list_add_tail(&info->node, &free_task_list);
}

static struct task_struct *get_process_leader(pid_t pid)
{
	struct task_struct *leader;

	rcu_read_lock();
	leader = find_task_by_vpid(pid);
	if (leader && leader->pid == leader->tgid)
		get_task_struct(leader);
	else
		leader = NULL;
	rcu_read_unlock();

	return leader;
}

static void replace_game_process(struct task_struct *new_leader,
				 struct task_runtime_info *new_pool)
{
	struct task_runtime_info *old_pool;
	struct task_struct *old_leader;
	unsigned long flags;

	atomic_set(&need_stat_runtime, 0);
	raw_spin_lock_irqsave(&game_task_lock, flags);
	old_leader = game_leader;
	old_pool = task_pool;
	game_leader = new_leader;
	task_pool = new_pool;
	if (new_pool) {
		init_task_pool_locked(new_pool);
		window_start = ktime_get_ns();
		atomic_set(&need_stat_runtime, 1);
	} else {
		INIT_LIST_HEAD(&running_task_list);
		INIT_LIST_HEAD(&free_task_list);
		window_start = 0;
	}
	raw_spin_unlock_irqrestore(&game_task_lock, flags);

	if (old_leader)
		put_task_struct(old_leader);
	kfree(old_pool);
}

static ssize_t game_pid_proc_write(struct file *file, const char __user *buf,
				   size_t count, loff_t *ppos)
{
	struct task_runtime_info *new_pool = NULL;
	struct task_struct *new_leader = NULL;
	char page[32] = { 0 };
	int pid, ret;

	if (!count || count >= sizeof(page))
		return -EINVAL;
	if (copy_from_user(page, buf, count))
		return -EFAULT;

	ret = kstrtoint(strim(page), 10, &pid);
	if (ret)
		return ret;

	mutex_lock(&game_task_mutex);
	if (pid > 0) {
		new_leader = get_process_leader(pid);
		if (!new_leader) {
			ret = -EINVAL;
			goto out_unlock;
		}

		new_pool = kcalloc(MAX_TID_COUNT, sizeof(*new_pool), GFP_KERNEL);
		if (!new_pool) {
			put_task_struct(new_leader);
			ret = -ENOMEM;
			goto out_unlock;
		}
	}

	replace_game_process(new_leader, new_pool);
	ret = count;

out_unlock:
	mutex_unlock(&game_task_mutex);
	return ret;
}

static ssize_t game_pid_proc_read(struct file *file, char __user *buf,
				  size_t count, loff_t *ppos)
{
	char page[32];
	int len, pid;

	mutex_lock(&game_task_mutex);
	pid = game_leader ? game_leader->pid : -1;
	len = scnprintf(page, sizeof(page), "%d\n", pid);
	mutex_unlock(&game_task_mutex);

	return simple_read_from_buffer(buf, count, ppos, page, len);
}

static const struct file_operations game_pid_proc_ops = {
	.write = game_pid_proc_write,
	.read = game_pid_proc_read,
};

static int cmp_task_util(const void *a, const void *b)
{
	const struct task_util_result *left = a;
	const struct task_util_result *right = b;

	return right->util - left->util;
}

static u16 calc_util(u64 sum_exec_scale, u64 window_size)
{
	u64 denominator = window_size >> 10;
	u64 util;

	if (!denominator)
		return 0;

	util = div64_u64(sum_exec_scale, denominator);
	return min_t(u64, util, 1024);
}

static bool get_task_name(pid_t tid, char *name)
{
	struct task_struct *task;
	bool found = false;

	rcu_read_lock();
	task = find_task_by_vpid(tid);
	if (task) {
		get_task_comm(name, task);
		found = true;
	}
	rcu_read_unlock();

	return found;
}

static int heavy_task_info_show(struct seq_file *m, void *v)
{
	struct task_util_result *results;
	struct task_runtime_info *info, *next;
	char task_name[TASK_COMM_LEN];
	unsigned long flags;
	u64 now, window_size;
	int i, num = 0;

	mutex_lock(&game_task_mutex);
	if (!game_leader) {
		mutex_unlock(&game_task_mutex);
		return -ESRCH;
	}

	results = kcalloc(MAX_TID_COUNT, sizeof(*results), GFP_KERNEL);
	if (!results) {
		mutex_unlock(&game_task_mutex);
		return -ENOMEM;
	}

	atomic_set(&need_stat_runtime, 0);
	raw_spin_lock_irqsave(&game_task_lock, flags);
	now = ktime_get_ns();
	window_size = now - window_start;
	list_for_each_entry_safe(info, next, &running_task_list, node) {
		if (now - info->last_update_ts < MAX_TASK_INACTIVE_TIME) {
			results[num].tid = info->tid;
			results[num].util = calc_util(info->sum_exec_scale,
						      window_size);
			info->sum_exec_scale = 0;
			num++;
		} else {
			free_task_info_locked(info);
		}
	}
	window_start = now;
	raw_spin_unlock_irqrestore(&game_task_lock, flags);
	atomic_set(&need_stat_runtime, 1);

	sort(results, num, sizeof(*results), cmp_task_util, NULL);
	num = min(num, MAX_TASK_NR);
	for (i = 0; i < num; i++) {
		if (!results[i].util)
			break;
		if (get_task_name(results[i].tid, task_name))
			seq_printf(m, "%d;%s;%u\n", results[i].tid,
				   task_name, results[i].util);
	}

	kfree(results);
	mutex_unlock(&game_task_mutex);
	return 0;
}

static int heavy_task_info_proc_open(struct inode *inode, struct file *file)
{
	return single_open(file, heavy_task_info_show, inode);
}

static const struct file_operations heavy_task_info_proc_ops = {
	.open = heavy_task_info_proc_open,
	.read = seq_read,
	.llseek = seq_lseek,
	.release = single_release,
};

static u64 scale_exec_time(u64 delta, struct task_struct *task)
{
	struct cpufreq_policy *policy;
	unsigned int cur_freq, max_freq;
	u64 task_exec_scale;
	int cpu = task_cpu(task);

	policy = cpufreq_cpu_get_raw(cpu);
	if (!policy)
		return delta;
	cur_freq = READ_ONCE(policy->cur);
	max_freq = policy->cpuinfo.max_freq;
	if (!cur_freq || !max_freq || cur_freq > max_freq)
		return delta;

	task_exec_scale = div64_u64((u64)cur_freq *
					 arch_scale_cpu_capacity(NULL, cpu) +
					 max_freq - 1, max_freq);
	return (delta * task_exec_scale) >> 10;
}

void g_update_task_runtime(struct task_struct *task, u64 runtime)
{
	struct task_runtime_info *info, *new_info;
	unsigned long flags;
	u64 now, exec_scale;

	if (!atomic_read(&need_stat_runtime))
		return;
	if (!raw_spin_trylock_irqsave(&game_task_lock, flags))
		return;
	if (!game_leader || task->tgid != game_leader->tgid)
		goto out_unlock;

	now = ktime_get_ns();
	exec_scale = scale_exec_time(runtime, task);
	list_for_each_entry(info, &running_task_list, node) {
		if (info->tid == task->pid) {
			info->sum_exec_scale += exec_scale;
			info->last_update_ts = now;
			goto out_unlock;
		}
	}

	new_info = alloc_task_info_locked();
	if (new_info) {
		new_info->tid = task->pid;
		new_info->sum_exec_scale = exec_scale;
		new_info->last_update_ts = now;
		list_add_tail(&new_info->node, &running_task_list);
	}

out_unlock:
	raw_spin_unlock_irqrestore(&game_task_lock, flags);
}

void g_rt_task_dead(struct task_struct *task)
{
	struct task_runtime_info *info, *next;
	unsigned long flags;

	if (!atomic_read(&need_stat_runtime))
		return;
	if (!raw_spin_trylock_irqsave(&game_task_lock, flags))
		return;
	if (!game_leader || task->tgid != game_leader->tgid)
		goto out_unlock;

	list_for_each_entry_safe(info, next, &running_task_list, node) {
		if (info->tid == task->pid) {
			free_task_info_locked(info);
			break;
		}
	}

out_unlock:
	raw_spin_unlock_irqrestore(&game_task_lock, flags);
}

int task_util_init(void)
{
	struct proc_dir_entry *game_pid_entry;

	if (unlikely(!game_opt_dir))
		return -ENOTDIR;

	game_pid_entry = proc_create_data("game_pid", 0664, game_opt_dir,
					  &game_pid_proc_ops, NULL);
	if (!game_pid_entry)
		return -ENOMEM;

	if (!proc_create_data("heavy_task_info", 0444, game_opt_dir,
			      &heavy_task_info_proc_ops, NULL)) {
		remove_proc_entry("game_pid", game_opt_dir);
		return -ENOMEM;
	}

	return 0;
}
