// SPDX-License-Identifier: GPL-2.0-only
/*
 * Copyright (C) 2022 Oplus. All rights reserved.
 */

#include <linux/kernel.h>
#include <linux/module.h>
#include <linux/proc_fs.h>

#include "game_ctrl.h"

struct proc_dir_entry *game_opt_dir;

static int __init game_ctrl_init(void)
{
	int ret;

	game_opt_dir = proc_mkdir("game_opt", NULL);
	if (!game_opt_dir) {
		pr_err("game_opt: failed to create /proc/game_opt\n");
		return -ENOMEM;
	}

	ret = cpu_load_init();
	if (ret) {
		remove_proc_entry("game_opt", NULL);
		game_opt_dir = NULL;
		return ret;
	}

	ret = task_util_init();
	if (ret) {
		cpu_load_exit();
		remove_proc_entry("game_opt", NULL);
		game_opt_dir = NULL;
		return ret;
	}

	return 0;
}

module_init(game_ctrl_init);
MODULE_LICENSE("GPL v2");
MODULE_DESCRIPTION("Oplus GameOpt CPU-load telemetry");
