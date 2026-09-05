// SPDX-License-Identifier: GPL-2.0-only
/*
 * Copyright (C) 2022 Oplus. All rights reserved.
 */

#include <linux/atomic.h>
#include <linux/fs.h>
#include <linux/kernel.h>
#include <linux/ktime.h>
#include <linux/list.h>
#include <linux/mutex.h>
#include <linux/proc_fs.h>
#include <linux/rcupdate.h>
#include <linux/sched.h>
#include <linux/sched/signal.h>
#include <linux/seq_file.h>
#include <linux/slab.h>
#include <linux/sort.h>
#include <linux/spinlock.h>
#include <linux/string.h>
#include <linux/uaccess.h>

#include "game_ctrl.h"

#define MAX_WAKER_COUNT 256
#define MAX_REPORT_TASKS 10
#define MAX_TASK_INACTIVE_TIME NSEC_PER_SEC

struct render_thread_info {
	pid_t tid;
	pid_t tgid;
	struct task_struct *task;
	struct list_head wakers;
};

struct rt_waker_info {
	struct list_head node;
	pid_t tid;
	u64 total;
	u32 increment;
	u64 last_wake_ts;
};

struct rt_waker_snapshot {
	pid_t tid;
	pid_t wakee_tid;
	u64 total;
	u32 increment;
};

static struct render_thread_info render_threads[MAX_RT_NUM];
static struct rt_waker_info waker_pool[MAX_WAKER_COUNT];
static LIST_HEAD(free_wakers);
static DEFINE_MUTEX(rt_config_lock);
static DEFINE_RAW_SPINLOCK(rt_info_lock);
static atomic_t need_stat_wake = ATOMIC_INIT(0);
static unsigned int rt_num;
static unsigned int free_waker_count;

static void reset_waker_pool_locked(void)
{
	int i;

	INIT_LIST_HEAD(&free_wakers);
	for (i = 0; i < MAX_WAKER_COUNT; i++) {
		INIT_LIST_HEAD(&waker_pool[i].node);
		list_add_tail(&waker_pool[i].node, &free_wakers);
	}
	free_waker_count = MAX_WAKER_COUNT;
}

static struct rt_waker_info *alloc_waker_locked(void)
{
	struct rt_waker_info *waker;

	if (list_empty(&free_wakers))
		return NULL;

	waker = list_first_entry(&free_wakers, struct rt_waker_info, node);
	list_del_init(&waker->node);
	free_waker_count--;
	return waker;
}

static void free_waker_locked(struct rt_waker_info *waker)
{
	list_del_init(&waker->node);
	waker->tid = 0;
	waker->total = 0;
	waker->increment = 0;
	waker->last_wake_ts = 0;
	list_add_tail(&waker->node, &free_wakers);
	free_waker_count++;
}

static void clear_render_wakers_locked(struct render_thread_info *render)
{
	struct rt_waker_info *waker, *next;

	list_for_each_entry_safe(waker, next, &render->wakers, node)
		free_waker_locked(waker);
}

static void add_rt_waker_stat_locked(struct render_thread_info *render)
{
	struct rt_waker_info *waker;
	pid_t waker_tid = current->pid;
	u64 now = ktime_get_ns();

	list_for_each_entry(waker, &render->wakers, node) {
		if (waker->tid == waker_tid) {
			waker->total++;
			waker->increment++;
			waker->last_wake_ts = now;
			return;
		}
	}

	waker = alloc_waker_locked();
	if (!waker)
		return;

	waker->tid = waker_tid;
	waker->total = 1;
	waker->increment = 1;
	waker->last_wake_ts = now;
	list_add_tail(&waker->node, &render->wakers);
}

void g_rt_try_to_wake_up(struct task_struct *task)
{
	unsigned long flags;
	int i;

	if (!atomic_read(&need_stat_wake))
		return;
	if (!raw_spin_trylock_irqsave(&rt_info_lock, flags))
		return;

	for (i = 0; i < MAX_RT_NUM; i++) {
		if (task->pid != render_threads[i].tid)
			continue;
		if (!render_threads[i].task ||
		    !pid_alive(render_threads[i].task))
			break;
		if (current->tgid == render_threads[i].tgid)
			add_rt_waker_stat_locked(&render_threads[i]);
		break;
	}

	raw_spin_unlock_irqrestore(&rt_info_lock, flags);
}

void g_rt_waker_task_dead(struct task_struct *task)
{
	struct task_struct *old_tasks[MAX_RT_NUM] = { NULL };
	struct rt_waker_info *waker, *next;
	unsigned long flags;
	int i, old_count = 0;

	if (!atomic_read(&need_stat_wake))
		return;
	if (!raw_spin_trylock_irqsave(&rt_info_lock, flags))
		return;

	for (i = 0; i < MAX_RT_NUM; i++) {
		list_for_each_entry_safe(waker, next,
					 &render_threads[i].wakers, node) {
			if (waker->tid == task->pid)
				free_waker_locked(waker);
		}

		if (render_threads[i].tid != task->pid)
			continue;

		clear_render_wakers_locked(&render_threads[i]);
		old_tasks[old_count++] = render_threads[i].task;
		render_threads[i].task = NULL;
		render_threads[i].tid = 0;
		render_threads[i].tgid = 0;
		if (rt_num)
			rt_num--;
	}
	if (!rt_num)
		atomic_set(&need_stat_wake, 0);

	raw_spin_unlock_irqrestore(&rt_info_lock, flags);

	for (i = 0; i < old_count; i++)
		put_task_struct(old_tasks[i]);
}

static bool get_task_name(pid_t tid, char name[TASK_COMM_LEN])
{
	struct task_struct *task;
	char comm[TASK_COMM_LEN];

	rcu_read_lock();
	task = find_task_by_vpid(tid);
	if (task)
		get_task_struct(task);
	rcu_read_unlock();
	if (!task)
		return false;

	get_task_comm(comm, task);
	memcpy(name, comm, sizeof(comm));
	put_task_struct(task);
	return true;
}

static int cmp_waker_increment(const void *a, const void *b)
{
	const struct rt_waker_snapshot *left = a;
	const struct rt_waker_snapshot *right = b;

	if (left->increment < right->increment)
		return 1;
	if (left->increment > right->increment)
		return -1;
	return 0;
}

static int rt_info_show(struct seq_file *m, void *v)
{
	struct rt_waker_snapshot *results;
	struct rt_waker_info *waker, *next;
	unsigned int start[MAX_RT_NUM], count[MAX_RT_NUM] = { 0 };
	unsigned long flags;
	char name[TASK_COMM_LEN];
	u64 now = ktime_get_ns();
	unsigned int nr = 0;
	int i, j;

	results = kcalloc(MAX_WAKER_COUNT, sizeof(*results), GFP_KERNEL);
	if (!results)
		return -ENOMEM;

	raw_spin_lock_irqsave(&rt_info_lock, flags);
	for (i = 0; i < MAX_RT_NUM; i++) {
		start[i] = nr;
		list_for_each_entry_safe(waker, next,
					 &render_threads[i].wakers, node) {
			if (waker->increment && nr < MAX_WAKER_COUNT) {
				results[nr].tid = waker->tid;
				results[nr].wakee_tid = render_threads[i].tid;
				results[nr].total = waker->total;
				results[nr].increment = waker->increment;
				waker->increment = 0;
				nr++;
				count[i]++;
			} else if (!waker->increment &&
				   now - waker->last_wake_ts >
				   MAX_TASK_INACTIVE_TIME) {
				free_waker_locked(waker);
			}
		}
	}
	raw_spin_unlock_irqrestore(&rt_info_lock, flags);

	for (i = 0; i < MAX_RT_NUM; i++) {
		sort(&results[start[i]], count[i], sizeof(*results),
		     cmp_waker_increment, NULL);
		for (j = 0; j < min_t(unsigned int, count[i],
					MAX_REPORT_TASKS); j++) {
			struct rt_waker_snapshot *result = &results[start[i] + j];

			if (get_task_name(result->tid, name))
				seq_printf(m, "%d;%s;%d;%llu;%u\n",
					   result->tid, name, result->wakee_tid,
					   (unsigned long long)result->total,
					   result->increment);
		}
	}

	kfree(results);
	return 0;
}

static int rt_info_proc_open(struct inode *inode, struct file *file)
{
	return single_open(file, rt_info_show, inode);
}

static struct task_struct *get_task_ref(pid_t tid)
{
	struct task_struct *task;

	rcu_read_lock();
	task = find_task_by_vpid(tid);
	if (task)
		get_task_struct(task);
	rcu_read_unlock();
	return task;
}

static ssize_t rt_info_proc_write(struct file *file, const char __user *buf,
				  size_t count, loff_t *ppos)
{
	struct task_struct *new_tasks[MAX_RT_NUM] = { NULL };
	struct task_struct *old_tasks[MAX_RT_NUM] = { NULL };
	pid_t dstate_tids[MAX_RT_NUM] = { 0 };
	char page[128], *cursor, *token;
	unsigned long flags;
	unsigned int num = 0;
	int i, tid;

	if (count >= sizeof(page))
		return -E2BIG;
	if (copy_from_user(page, buf, count))
		return -EFAULT;
	page[count] = '\0';

	cursor = page;
	while ((token = strsep(&cursor, " \t\n")) != NULL) {
		if (!*token)
			continue;
		if (kstrtoint(token, 10, &tid))
			break;
		if (tid <= 0)
			continue;
		if (num >= MAX_RT_NUM)
			break;
		if (num && new_tasks[0]->pid == tid)
			continue;
		new_tasks[num] = get_task_ref(tid);
		if (new_tasks[num])
			num++;
	}

	mutex_lock(&rt_config_lock);
	atomic_set(&need_stat_wake, 0);
	raw_spin_lock_irqsave(&rt_info_lock, flags);
	for (i = 0; i < MAX_RT_NUM; i++) {
		old_tasks[i] = render_threads[i].task;
		render_threads[i].task = NULL;
		render_threads[i].tid = 0;
		render_threads[i].tgid = 0;
		INIT_LIST_HEAD(&render_threads[i].wakers);
	}
	reset_waker_pool_locked();
	for (i = 0; i < num; i++) {
		dstate_tids[i] = new_tasks[i]->pid;
		render_threads[i].task = new_tasks[i];
		render_threads[i].tid = new_tasks[i]->pid;
		render_threads[i].tgid = new_tasks[i]->tgid;
		new_tasks[i] = NULL;
	}
	rt_num = num;
	if (rt_num)
		atomic_set(&need_stat_wake, 1);
	raw_spin_unlock_irqrestore(&rt_info_lock, flags);
	mutex_unlock(&rt_config_lock);
	rt_set_dstate_interested_threads(dstate_tids, num);

	for (i = 0; i < MAX_RT_NUM; i++) {
		if (old_tasks[i])
			put_task_struct(old_tasks[i]);
		if (new_tasks[i])
			put_task_struct(new_tasks[i]);
	}

	return count;
}

static const struct file_operations rt_info_proc_ops = {
	.open = rt_info_proc_open,
	.write = rt_info_proc_write,
	.read = seq_read,
	.llseek = seq_lseek,
	.release = single_release,
};

static int rt_num_show(struct seq_file *m, void *v)
{
	struct task_struct *tasks[MAX_RT_NUM] = { NULL };
	unsigned int num, available;
	unsigned long flags;
	char name[TASK_COMM_LEN];
	int i;

	raw_spin_lock_irqsave(&rt_info_lock, flags);
	num = rt_num;
	available = free_waker_count;
	for (i = 0; i < MAX_RT_NUM; i++) {
		if (!render_threads[i].task)
			continue;
		tasks[i] = render_threads[i].task;
		get_task_struct(tasks[i]);
	}
	raw_spin_unlock_irqrestore(&rt_info_lock, flags);

	seq_printf(m, "rt_num %u\n", num);
	for (i = 0; i < MAX_RT_NUM; i++) {
		if (!tasks[i])
			continue;
		get_task_comm(name, tasks[i]);
		seq_printf(m, "pid:%d tid:%d comm:%s\n", tasks[i]->tgid,
			   tasks[i]->pid, name);
		put_task_struct(tasks[i]);
	}
	if (num)
		seq_printf(m, "waker_mempool total:%u available:%u\n",
			   MAX_WAKER_COUNT, available);

	return 0;
}

static int rt_num_proc_open(struct inode *inode, struct file *file)
{
	return single_open(file, rt_num_show, inode);
}

static const struct file_operations rt_num_proc_ops = {
	.open = rt_num_proc_open,
	.read = seq_read,
	.llseek = seq_lseek,
	.release = single_release,
};

int rt_info_init(void)
{
	struct proc_dir_entry *render_entry;
	unsigned long flags;
	int i;

	if (unlikely(!game_opt_dir))
		return -ENOTDIR;

	raw_spin_lock_irqsave(&rt_info_lock, flags);
	for (i = 0; i < MAX_RT_NUM; i++)
		INIT_LIST_HEAD(&render_threads[i].wakers);
	reset_waker_pool_locked();
	raw_spin_unlock_irqrestore(&rt_info_lock, flags);

	render_entry = proc_create_data("render_thread_info", 0664,
					game_opt_dir, &rt_info_proc_ops, NULL);
	if (!render_entry)
		return -ENOMEM;
	if (!proc_create_data("rt_num", 0444, game_opt_dir,
			      &rt_num_proc_ops, NULL)) {
		remove_proc_entry("render_thread_info", game_opt_dir);
		return -ENOMEM;
	}

	return 0;
}
