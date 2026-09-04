/* SPDX-License-Identifier: GPL-2.0-only */
#ifndef _LINUX_OPLUS_GAME_OPT_H
#define _LINUX_OPLUS_GAME_OPT_H

#ifdef CONFIG_OPLUS_FEATURE_GAME_OPT
void g_time_in_state_update_idle(int cpu, unsigned int new_idle_index);
#else
static inline void g_time_in_state_update_idle(int cpu,
					       unsigned int new_idle_index)
{
}
#endif

#endif /* _LINUX_OPLUS_GAME_OPT_H */
