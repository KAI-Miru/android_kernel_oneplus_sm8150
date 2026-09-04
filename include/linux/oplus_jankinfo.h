/* SPDX-License-Identifier: GPL-2.0-only */
#ifndef _LINUX_OPLUS_JANKINFO_H
#define _LINUX_OPLUS_JANKINFO_H

#include <linux/types.h>

struct rq;
struct task_struct;
struct cpufreq_policy;

#define OPLUS_JANKINFO_FREQ_CLAMP	(1U << 0)
#define OPLUS_JANKINFO_FREQ_INCREASE	(1U << 1)

#if defined(OPLUS_FEATURE_SCHED_ASSIST) && \
	defined(CONFIG_OPLUS_FEATURE_CPU_JANKINFO)
void jankinfo_update_time_info(struct rq *rq, struct task_struct *p, u64 time);
void jankinfo_update_freq_reach_limit_count(struct cpufreq_policy *policy,
		u32 old_target_freq, u32 new_target_freq, u32 flags);
#else
static inline void jankinfo_update_time_info(struct rq *rq,
		struct task_struct *p, u64 time)
{
}

static inline void jankinfo_update_freq_reach_limit_count(
		struct cpufreq_policy *policy, u32 old_target_freq,
		u32 new_target_freq, u32 flags)
{
}
#endif

#endif /* _LINUX_OPLUS_JANKINFO_H */
