// SPDX-License-Identifier: GPL-2.0-only
/*
 * Copyright (C) 2022 Oplus. All rights reserved.
 */

#include <linux/cpu.h>
#include <linux/cpufreq.h>
#include <linux/cpumask.h>
#include <linux/errno.h>
#include <linux/kernel.h>
#include <linux/mutex.h>
#include <linux/proc_fs.h>
#include <linux/seq_file.h>
#include <linux/string.h>
#include <linux/uaccess.h>

#include "game_ctrl.h"

#define GAMEOPT_FREQ_INPUT_SIZE 256

struct game_cpu_freq_status {
	unsigned int min;
	unsigned int max;
};

static DEFINE_PER_CPU(struct game_cpu_freq_status, game_cpu_freq_status);
static DEFINE_MUTEX(game_cpu_freq_lock);
static cpumask_var_t game_freq_request_mask;
static cpumask_var_t game_freq_pending_mask;

static int game_freq_parse_request(char *buf, unsigned int *values)
{
	char *cursor = buf;
	char *token;

	cpumask_clear(game_freq_request_mask);

	while ((token = strsep(&cursor, " \t\r\n")) != NULL) {
		char *separator;
		size_t token_len;
		unsigned int cpu;
		unsigned int value;
		int ret;

		if (!*token)
			continue;

		token_len = strlen(token);
		separator = strnchr(token, token_len, ':');
		if (!separator)
			return -EINVAL;
		if (strnchr(separator + 1, strlen(separator + 1), ':'))
			return -EINVAL;

		*separator = '\0';
		ret = kstrtouint(token, 10, &cpu);
		if (ret)
			return ret;
		ret = kstrtouint(separator + 1, 10, &value);
		if (ret)
			return ret;
		if (cpu >= nr_cpu_ids || !cpu_present(cpu))
			return -EINVAL;
		if (cpumask_test_cpu(cpu, game_freq_request_mask))
			return -EINVAL;

		values[cpu] = value;
		cpumask_set_cpu(cpu, game_freq_request_mask);
	}

	return cpumask_empty(game_freq_request_mask) ? -EINVAL : 0;
}

static void game_freq_store(unsigned int cpu, unsigned int value, bool minimum)
{
	struct game_cpu_freq_status *status;

	status = &per_cpu(game_cpu_freq_status, cpu);
	if (minimum)
		WRITE_ONCE(status->min, value);
	else
		WRITE_ONCE(status->max, value);
}

static void game_freq_apply_request(const unsigned int *values, bool minimum)
{
	struct cpufreq_policy *policy;
	unsigned int policy_cpu;
	unsigned int value;
	int cpu;
	int related_cpu;

	cpumask_copy(game_freq_pending_mask, game_freq_request_mask);

	get_online_cpus();
	for_each_cpu(cpu, game_freq_pending_mask) {
		value = values[cpu];
		policy = cpufreq_cpu_get(cpu);
		if (!policy) {
			game_freq_store(cpu, value, minimum);
			cpumask_clear_cpu(cpu, game_freq_pending_mask);
			continue;
		}

		policy_cpu = policy->cpu;
		for_each_cpu(related_cpu, policy->related_cpus) {
			game_freq_store(related_cpu, value, minimum);
			cpumask_clear_cpu(related_cpu, game_freq_pending_mask);
		}
		cpufreq_cpu_put(policy);

		cpufreq_update_policy(policy_cpu);
	}
	put_online_cpus();
}

static ssize_t game_freq_write(const char __user *buf, size_t count,
			       loff_t *ppos, bool minimum)
{
	unsigned int values[NR_CPUS] = { 0 };
	char page[GAMEOPT_FREQ_INPUT_SIZE];
	int ret;

	if (*ppos != 0)
		return -EINVAL;
	if (!count)
		return -EINVAL;
	if (count >= sizeof(page))
		return -E2BIG;
	if (copy_from_user(page, buf, count))
		return -EFAULT;
	page[count] = '\0';

	mutex_lock(&game_cpu_freq_lock);
	ret = game_freq_parse_request(page, values);
	if (!ret)
		game_freq_apply_request(values, minimum);
	mutex_unlock(&game_cpu_freq_lock);

	if (ret)
		return ret;

	*ppos += count;
	return count;
}

static ssize_t cpu_min_freq_proc_write(struct file *file,
				       const char __user *buf, size_t count,
				       loff_t *ppos)
{
	return game_freq_write(buf, count, ppos, true);
}

static int cpu_min_freq_show(struct seq_file *m, void *v)
{
	int cpu;

	for_each_present_cpu(cpu)
		seq_printf(m, "%d:%u ", cpu,
			   READ_ONCE(per_cpu(game_cpu_freq_status, cpu).min));
	seq_putc(m, '\n');

	return 0;
}

static int cpu_min_freq_proc_open(struct inode *inode, struct file *file)
{
	return single_open(file, cpu_min_freq_show, NULL);
}

static const struct file_operations cpu_min_freq_proc_ops = {
	.open = cpu_min_freq_proc_open,
	.write = cpu_min_freq_proc_write,
	.read = seq_read,
	.llseek = seq_lseek,
	.release = single_release,
};

static ssize_t cpu_max_freq_proc_write(struct file *file,
				       const char __user *buf, size_t count,
				       loff_t *ppos)
{
	return game_freq_write(buf, count, ppos, false);
}

static int cpu_max_freq_show(struct seq_file *m, void *v)
{
	int cpu;

	for_each_present_cpu(cpu)
		seq_printf(m, "%d:%u ", cpu,
			   READ_ONCE(per_cpu(game_cpu_freq_status, cpu).max));
	seq_putc(m, '\n');

	return 0;
}

static int cpu_max_freq_proc_open(struct inode *inode, struct file *file)
{
	return single_open(file, cpu_max_freq_show, NULL);
}

static const struct file_operations cpu_max_freq_proc_ops = {
	.open = cpu_max_freq_proc_open,
	.write = cpu_max_freq_proc_write,
	.read = seq_read,
	.llseek = seq_lseek,
	.release = single_release,
};

static int game_freq_policy_adjust(struct notifier_block *nb,
				   unsigned long event, void *data)
{
	struct cpufreq_policy *policy = data;
	struct game_cpu_freq_status *status;
	unsigned int min;
	unsigned int max;

	if (event != CPUFREQ_ADJUST || !policy)
		return NOTIFY_OK;

	status = &per_cpu(game_cpu_freq_status, policy->cpu);
	min = READ_ONCE(status->min);
	max = READ_ONCE(status->max);
	cpufreq_verify_within_limits(policy, min, max);

	return NOTIFY_OK;
}

static struct notifier_block game_freq_policy_nb = {
	.notifier_call = game_freq_policy_adjust,
};

int cpufreq_limits_init(void)
{
	unsigned int cpu;
	int ret;

	if (unlikely(!game_opt_dir))
		return -ENOTDIR;

	if (!alloc_cpumask_var(&game_freq_request_mask, GFP_KERNEL))
		return -ENOMEM;
	if (!alloc_cpumask_var(&game_freq_pending_mask, GFP_KERNEL)) {
		ret = -ENOMEM;
		goto free_request_mask;
	}

	for_each_possible_cpu(cpu) {
		per_cpu(game_cpu_freq_status, cpu).min = 0;
		per_cpu(game_cpu_freq_status, cpu).max = UINT_MAX;
	}

	ret = cpufreq_register_notifier(&game_freq_policy_nb,
					CPUFREQ_POLICY_NOTIFIER);
	if (ret)
		goto free_pending_mask;

	if (!proc_create_data("cpu_min_freq", 0664, game_opt_dir,
			      &cpu_min_freq_proc_ops, NULL)) {
		ret = -ENOMEM;
		goto unregister_notifier;
	}
	if (!proc_create_data("cpu_max_freq", 0664, game_opt_dir,
			      &cpu_max_freq_proc_ops, NULL)) {
		ret = -ENOMEM;
		goto remove_min_node;
	}

	return 0;

remove_min_node:
	remove_proc_entry("cpu_min_freq", game_opt_dir);
unregister_notifier:
	cpufreq_unregister_notifier(&game_freq_policy_nb,
				    CPUFREQ_POLICY_NOTIFIER);
free_pending_mask:
	free_cpumask_var(game_freq_pending_mask);
free_request_mask:
	free_cpumask_var(game_freq_request_mask);
	return ret;
}

void cpufreq_limits_exit(void)
{
	remove_proc_entry("cpu_max_freq", game_opt_dir);
	remove_proc_entry("cpu_min_freq", game_opt_dir);
	cpufreq_unregister_notifier(&game_freq_policy_nb,
				    CPUFREQ_POLICY_NOTIFIER);
	free_cpumask_var(game_freq_pending_mask);
	free_cpumask_var(game_freq_request_mask);
}
