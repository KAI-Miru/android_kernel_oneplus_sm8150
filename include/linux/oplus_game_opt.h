/* SPDX-License-Identifier: GPL-2.0-only */
#ifndef _LINUX_OPLUS_GAME_OPT_H
#define _LINUX_OPLUS_GAME_OPT_H

#include <linux/types.h>

struct task_struct;

#ifdef CONFIG_OPLUS_FEATURE_GAME_OPT
void g_time_in_state_update_idle(int cpu, unsigned int new_idle_index);
void g_update_task_runtime(struct task_struct *task, u64 runtime);
void g_rt_task_dead(struct task_struct *task);
void g_rt_try_to_wake_up(struct task_struct *task);
void g_rt_waker_task_dead(struct task_struct *task);
#else
static inline void g_time_in_state_update_idle(int cpu,
					       unsigned int new_idle_index)
{
}

static inline void g_update_task_runtime(struct task_struct *task, u64 runtime)
{
}

static inline void g_rt_task_dead(struct task_struct *task)
{
}

static inline void g_rt_try_to_wake_up(struct task_struct *task)
{
}

static inline void g_rt_waker_task_dead(struct task_struct *task)
{
}
#endif

#endif /* _LINUX_OPLUS_GAME_OPT_H */
