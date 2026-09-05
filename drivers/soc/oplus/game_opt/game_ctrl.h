/* SPDX-License-Identifier: GPL-2.0-only */
#ifndef _OPLUS_GAME_CTRL_H
#define _OPLUS_GAME_CTRL_H

#include <linux/proc_fs.h>

extern struct proc_dir_entry *game_opt_dir;

int cpu_load_init(void);
void cpu_load_exit(void);
int cpufreq_limits_init(void);
void cpufreq_limits_exit(void);
int task_util_init(void);
int rt_info_init(void);

#endif /* _OPLUS_GAME_CTRL_H */
