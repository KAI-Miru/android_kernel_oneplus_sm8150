// SPDX-License-Identifier: GPL-2.0-only
/*
 * Copyright (C) 2022 Oplus. All rights reserved.
 */

#include <linux/atomic.h>
#include <linux/errno.h>
#include <linux/irq_work.h>
#include <linux/kernel.h>
#include <linux/ktime.h>
#include <linux/proc_fs.h>
#include <linux/sched.h>
#include <linux/sched/stat.h>
#include <linux/sched/task.h>
#include <linux/stacktrace.h>
#include <linux/string.h>
#include <linux/uaccess.h>
#include <linux/workqueue.h>
#include <trace/events/sched.h>

#include "game_ctrl.h"

#define DSTATE_INTERESTED_THREAD_COUNT 10
#define DSTATE_STACK_DEPTH 16
#define DSTATE_INPUT_SIZE 256
#define DSTATE_DURATION_DEFAULT_MS 5
#define DSTATE_DURATION_MAX_MS 60000
#define DSTATE_REPORT_INTERVAL_NS (250ULL * NSEC_PER_MSEC)

struct gameopt_dstate_event {
	struct task_struct *task;
	u64 delay_ns;
	pid_t waker_pid;
	pid_t waker_tgid;
	char waker_comm[TASK_COMM_LEN];
};

static DEFINE_RAW_SPINLOCK(dstate_config_lock);
static DEFINE_RAW_SPINLOCK(dstate_event_lock);
static atomic_t dstate_dump_enable = ATOMIC_INIT(1);
static atomic_t dstate_duration_ms =
	ATOMIC_INIT(DSTATE_DURATION_DEFAULT_MS);
static atomic_t dstate_targets_enabled = ATOMIC_INIT(0);
static atomic64_t dstate_last_report_ns = ATOMIC64_INIT(0);
static atomic_t dstate_report_queued = ATOMIC_INIT(0);
static pid_t dstate_render_tids[MAX_RT_NUM];
static unsigned int dstate_render_tid_count;
static pid_t dstate_interested_tids[DSTATE_INTERESTED_THREAD_COUNT];
static unsigned int dstate_interested_tid_count;
static struct gameopt_dstate_event dstate_pending_event;
static struct proc_dir_entry *dstate_dir;
static struct irq_work dstate_report_irq_work;
static struct work_struct dstate_report_work;

void rt_set_dstate_interested_threads(const pid_t *tids, unsigned int count)
{
	unsigned long flags;
	unsigned int i;

	count = min_t(unsigned int, count, MAX_RT_NUM);
	raw_spin_lock_irqsave(&dstate_config_lock, flags);
	for (i = 0; i < count; i++)
		dstate_render_tids[i] = tids[i];
	for (; i < MAX_RT_NUM; i++)
		dstate_render_tids[i] = 0;
	dstate_render_tid_count = count;
	atomic_set(&dstate_targets_enabled,
		   count || dstate_interested_tid_count);
	raw_spin_unlock_irqrestore(&dstate_config_lock, flags);
	if (count && atomic_read(&dstate_dump_enable))
		force_schedstat_enabled();
}

static bool dstate_tid_interested(pid_t tid)
{
	unsigned long flags;
	unsigned int i;
	bool interested = false;

	if (!raw_spin_trylock_irqsave(&dstate_config_lock, flags))
		return false;
	for (i = 0; i < dstate_render_tid_count; i++) {
		if (tid == dstate_render_tids[i]) {
			interested = true;
			goto unlock;
		}
	}
	for (i = 0; i < dstate_interested_tid_count; i++) {
		if (tid == dstate_interested_tids[i]) {
			interested = true;
			break;
		}
	}

unlock:
	raw_spin_unlock_irqrestore(&dstate_config_lock, flags);
	return interested;
}

static bool dstate_has_interested_threads(void)
{
	return atomic_read(&dstate_targets_enabled);
}

static void dstate_report_workfn(struct work_struct *work)
{
	for (;;) {
		struct gameopt_dstate_event event;
		unsigned long entries[DSTATE_STACK_DEPTH];
		struct stack_trace trace = {
			.nr_entries = 0,
			.max_entries = ARRAY_SIZE(entries),
			.entries = entries,
			.skip = 0,
		};
		unsigned long flags;
		unsigned long blocked_function;
		char wakee_comm[TASK_COMM_LEN];

		raw_spin_lock_irqsave(&dstate_event_lock, flags);
		event = dstate_pending_event;
		dstate_pending_event.task = NULL;
		if (!event.task)
			atomic_set(&dstate_report_queued, 0);
		raw_spin_unlock_irqrestore(&dstate_event_lock, flags);
		if (!event.task)
			return;

		get_task_comm(wakee_comm, event.task);
		blocked_function = get_wchan(event.task);
		save_stack_trace_tsk(event.task, &trace);

		pr_info("game_opt_dstate delay_ms=%llu waker=%s tid=%d pid=%d wakee=%s tid=%d pid=%d blocked=%pS\n",
			(unsigned long long)(event.delay_ns >> 20),
			event.waker_comm, event.waker_pid, event.waker_tgid,
			wakee_comm, event.task->pid, event.task->tgid,
			(void *)blocked_function);
		print_stack_trace(&trace, 0);

		put_task_struct(event.task);
	}
}

static void dstate_report_irq_workfn(struct irq_work *work)
{
	schedule_work(&dstate_report_work);
}

static void gameopt_sched_stat_blocked(void *unused, struct task_struct *task,
				       u64 delay_ns)
{
	unsigned long flags;
	u64 interval_start;
	u64 now;
	bool queued = false;

	if (!task || !atomic_read(&dstate_dump_enable) ||
	    !atomic_read(&dstate_targets_enabled) || task->in_iowait)
		return;
	if (delay_ns < (u64)atomic_read(&dstate_duration_ms) * NSEC_PER_MSEC)
		return;
	if (!dstate_tid_interested(task->pid))
		return;

	now = ktime_get_ns();
	interval_start = atomic64_read(&dstate_last_report_ns);
	if (now - interval_start < DSTATE_REPORT_INTERVAL_NS)
		return;
	if (atomic64_cmpxchg(&dstate_last_report_ns, interval_start, now) !=
	    interval_start)
		return;

	get_task_struct(task);
	if (!raw_spin_trylock_irqsave(&dstate_event_lock, flags)) {
		put_task_struct(task);
		return;
	}
	if (!dstate_pending_event.task) {
		dstate_pending_event.task = task;
		dstate_pending_event.delay_ns = delay_ns;
		dstate_pending_event.waker_pid = current->pid;
		dstate_pending_event.waker_tgid = current->tgid;
		memcpy(dstate_pending_event.waker_comm, current->comm,
		       TASK_COMM_LEN);
		queued = true;
	}
	raw_spin_unlock_irqrestore(&dstate_event_lock, flags);

	if (queued && atomic_cmpxchg(&dstate_report_queued, 0, 1) == 0)
		irq_work_queue(&dstate_report_irq_work);
	else
		put_task_struct(task);
}

static int dstate_copy_int(const char __user *buf, size_t count, loff_t *ppos,
			   int *value)
{
	char page[32];

	if (*ppos != 0 || !count)
		return -EINVAL;
	if (count >= sizeof(page))
		return -E2BIG;
	if (copy_from_user(page, buf, count))
		return -EFAULT;
	page[count] = '\0';

	return kstrtoint(strim(page), 0, value);
}

static ssize_t dump_enable_proc_write(struct file *file,
				      const char __user *buf, size_t count,
				      loff_t *ppos)
{
	int enable;
	int ret;

	ret = dstate_copy_int(buf, count, ppos, &enable);
	if (ret)
		return ret;
	atomic_set(&dstate_dump_enable, !!enable);
	if (enable && dstate_has_interested_threads())
		force_schedstat_enabled();
	*ppos += count;
	return count;
}

static ssize_t dump_enable_proc_read(struct file *file, char __user *buf,
				     size_t count, loff_t *ppos)
{
	char page[32];
	int len;

	len = scnprintf(page, sizeof(page), "%d\n",
			atomic_read(&dstate_dump_enable));
	return simple_read_from_buffer(buf, count, ppos, page, len);
}

static const struct file_operations dump_enable_proc_ops = {
	.write = dump_enable_proc_write,
	.read = dump_enable_proc_read,
	.llseek = default_llseek,
};

static ssize_t duration_proc_write(struct file *file, const char __user *buf,
				   size_t count, loff_t *ppos)
{
	int duration;
	int ret;

	ret = dstate_copy_int(buf, count, ppos, &duration);
	if (ret)
		return ret;
	if (duration < 0 || duration > DSTATE_DURATION_MAX_MS)
		return -ERANGE;
	atomic_set(&dstate_duration_ms, duration);
	*ppos += count;
	return count;
}

static ssize_t duration_proc_read(struct file *file, char __user *buf,
				  size_t count, loff_t *ppos)
{
	char page[32];
	int len;

	len = scnprintf(page, sizeof(page), "%d\n",
			atomic_read(&dstate_duration_ms));
	return simple_read_from_buffer(buf, count, ppos, page, len);
}

static const struct file_operations duration_proc_ops = {
	.write = duration_proc_write,
	.read = duration_proc_read,
	.llseek = default_llseek,
};

static ssize_t interested_tids_proc_write(struct file *file,
					  const char __user *buf,
					  size_t count, loff_t *ppos)
{
	pid_t tids[DSTATE_INTERESTED_THREAD_COUNT] = { 0 };
	char page[DSTATE_INPUT_SIZE];
	char *cursor;
	char *token;
	unsigned long flags;
	unsigned int num = 0;
	unsigned int i;
	int tid;

	if (*ppos != 0)
		return -EINVAL;
	if (count >= sizeof(page))
		return -E2BIG;
	if (copy_from_user(page, buf, count))
		return -EFAULT;
	page[count] = '\0';

	cursor = page;
	while ((token = strsep(&cursor, " \t\r\n")) != NULL) {
		if (!*token)
			continue;
		if (kstrtoint(token, 10, &tid))
			return -EINVAL;
		if (tid <= 0) {
			if (tid == 0 && !num)
				break;
			return -EINVAL;
		}
		if (num >= ARRAY_SIZE(tids))
			return -E2BIG;
		for (i = 0; i < num; i++) {
			if (tids[i] == tid)
				return -EINVAL;
		}
		tids[num++] = tid;
	}

	raw_spin_lock_irqsave(&dstate_config_lock, flags);
	for (i = 0; i < num; i++)
		dstate_interested_tids[i] = tids[i];
	for (; i < ARRAY_SIZE(dstate_interested_tids); i++)
		dstate_interested_tids[i] = 0;
	dstate_interested_tid_count = num;
	atomic_set(&dstate_targets_enabled, num || dstate_render_tid_count);
	raw_spin_unlock_irqrestore(&dstate_config_lock, flags);
	if (num && atomic_read(&dstate_dump_enable))
		force_schedstat_enabled();

	*ppos += count;
	return count;
}

static ssize_t interested_tids_proc_read(struct file *file, char __user *buf,
					 size_t count, loff_t *ppos)
{
	pid_t tids[DSTATE_INTERESTED_THREAD_COUNT];
	char page[DSTATE_INPUT_SIZE];
	unsigned long flags;
	unsigned int num;
	unsigned int i;
	int len = 0;

	raw_spin_lock_irqsave(&dstate_config_lock, flags);
	num = dstate_interested_tid_count;
	memcpy(tids, dstate_interested_tids, sizeof(tids));
	raw_spin_unlock_irqrestore(&dstate_config_lock, flags);

	if (!num)
		len = scnprintf(page, sizeof(page), "0\n");
	else
		for (i = 0; i < num; i++)
			len += scnprintf(page + len, sizeof(page) - len,
					 "%d%c", tids[i],
					 i + 1 == num ? '\n' : ' ');

	return simple_read_from_buffer(buf, count, ppos, page, len);
}

static const struct file_operations interested_tids_proc_ops = {
	.write = interested_tids_proc_write,
	.read = interested_tids_proc_read,
	.llseek = default_llseek,
};

int dstate_dump_init(void)
{
	int ret;

	if (unlikely(!game_opt_dir))
		return -ENOTDIR;

	INIT_WORK(&dstate_report_work, dstate_report_workfn);
	init_irq_work(&dstate_report_irq_work, dstate_report_irq_workfn);

	dstate_dir = proc_mkdir("dstate", game_opt_dir);
	if (!dstate_dir)
		return -ENOMEM;
	if (!proc_create_data("dump_enable", 0664, dstate_dir,
			      &dump_enable_proc_ops, NULL)) {
		ret = -ENOMEM;
		goto remove_dir;
	}
	if (!proc_create_data("duration", 0664, dstate_dir,
			      &duration_proc_ops, NULL)) {
		ret = -ENOMEM;
		goto remove_dir;
	}
	if (!proc_create_data("interested_tids", 0664, dstate_dir,
			      &interested_tids_proc_ops, NULL)) {
		ret = -ENOMEM;
		goto remove_dir;
	}

	ret = register_trace_sched_stat_blocked(gameopt_sched_stat_blocked, NULL);
	if (ret)
		goto remove_dir;

	return 0;

remove_dir:
	remove_proc_subtree("dstate", game_opt_dir);
	dstate_dir = NULL;
	return ret;
}

void dstate_dump_exit(void)
{
	struct task_struct *task;
	unsigned long flags;

	unregister_trace_sched_stat_blocked(gameopt_sched_stat_blocked, NULL);
	irq_work_sync(&dstate_report_irq_work);
	cancel_work_sync(&dstate_report_work);

	raw_spin_lock_irqsave(&dstate_event_lock, flags);
	task = dstate_pending_event.task;
	dstate_pending_event.task = NULL;
	raw_spin_unlock_irqrestore(&dstate_event_lock, flags);
	if (task)
		put_task_struct(task);
	atomic_set(&dstate_report_queued, 0);

	remove_proc_subtree("dstate", game_opt_dir);
	dstate_dir = NULL;
}
