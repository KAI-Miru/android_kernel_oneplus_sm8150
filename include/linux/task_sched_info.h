/* SPDX-License-Identifier: GPL-2.0-only */
/*
 * Android 14 Oplus task-scheduler telemetry ABI.
 *
 * The userspace wire format is implemented in fs/proc/task_sched_info.c.
 * Keep this header limited to the scheduler-facing producer contract.
 */

#ifndef _LINUX_TASK_SCHED_INFO_H
#define _LINUX_TASK_SCHED_INFO_H

#include <linux/types.h>

struct task_struct;

enum task_sched_info_type {
	task_sched_info_running = 0,
	task_sched_info_runnable,
	task_sched_info_IO,
	task_sched_info_D,
	task_sched_info_S,
	task_sched_info_freq,
	task_sched_info_freq_limit,
	task_sched_info_isolate,
	task_sched_info_backtrace,
};

enum task_sched_info_wake_type {
	other_runnable = 1,
	running_runnable,
};

enum task_sched_info_isolate_type {
	cpu_unisolate = 0,
	cpu_isolate,
};

void update_task_sched_info(struct task_struct *p, u64 delay, int type,
			    int cpu);
void update_wake_tid(struct task_struct *p, struct task_struct *current_task,
		     unsigned int type);
void update_running_start_time(struct task_struct *prev,
			       struct task_struct *next);
void get_target_thread_pid(struct task_struct *task);

void sched_action_trig(void);

#endif /* _LINUX_TASK_SCHED_INFO_H */
