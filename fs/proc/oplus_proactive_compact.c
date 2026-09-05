// SPDX-License-Identifier: GPL-2.0-only
/*
 * Android 14 OnePlus 9R proactive-compaction ABI, adapted for Linux 4.14.
 *
 * Donor: OnePlusOSS/android_kernel_modules_and_devicetree_oneplus_sm8250
 *        oneplus/sm8250_u_14.0.0_op9r
 *        vendor/oplus/kernel/oplus_performance/oplus_mm/
 *        proactive_compact/proactive_compact.c
 */

#define pr_fmt(fmt) "oplus_proactive_compact: " fmt

#include <linux/mm.h>
#include <linux/init.h>
#include <linux/math64.h>
#include <linux/module.h>
#include <linux/proc_fs.h>
#include <linux/swap.h>
#include <linux/uaccess.h>

#define OPLUS_COMPACT_INPUT_LEN	128

static unsigned int oplus_compaction_hpage_order = 4;
static unsigned int oplus_compaction_proactiveness = 20;

static int oplus_compaction_hpage_order_set(const char *value,
		const struct kernel_param *kp)
{
	unsigned int parsed;
	int ret;

	ret = kstrtouint(value, 0, &parsed);
	if (ret)
		return ret;
	if (parsed >= MAX_ORDER)
		return -ERANGE;

	WRITE_ONCE(*(unsigned int *)kp->arg, parsed);
	return 0;
}

static int oplus_compaction_proactiveness_set(const char *value,
		const struct kernel_param *kp)
{
	unsigned int parsed;
	int ret;

	ret = kstrtouint(value, 0, &parsed);
	if (ret)
		return ret;
	if (parsed > 100)
		return -ERANGE;

	WRITE_ONCE(*(unsigned int *)kp->arg, parsed);
	return 0;
}

static const struct kernel_param_ops oplus_compaction_hpage_order_ops = {
	.set = oplus_compaction_hpage_order_set,
	.get = param_get_uint,
};

static const struct kernel_param_ops oplus_compaction_proactiveness_ops = {
	.set = oplus_compaction_proactiveness_set,
	.get = param_get_uint,
};

module_param_cb(compaction_hpage_order,
		&oplus_compaction_hpage_order_ops,
		&oplus_compaction_hpage_order, 0644);
module_param_cb(compaction_proactiveness,
		&oplus_compaction_proactiveness_ops,
		&oplus_compaction_proactiveness, 0644);

struct oplus_contig_page_info {
	unsigned long free_pages;
	unsigned long free_blocks_suitable;
};

static void oplus_fill_contig_page_info(struct zone *zone,
					unsigned int suitable_order,
					struct oplus_contig_page_info *info)
{
	unsigned int order;
#if defined(OPLUS_FEATURE_MULTI_FREEAREA) && \
	defined(CONFIG_PHYSICAL_ANTI_FRAGMENTATION)
	int flc;
#endif

	info->free_pages = 0;
	info->free_blocks_suitable = 0;
#if defined(OPLUS_FEATURE_MULTI_FREEAREA) && \
	defined(CONFIG_PHYSICAL_ANTI_FRAGMENTATION)
	for (flc = 0; flc < FREE_AREA_COUNTS; flc++) {
#endif
	for (order = 0; order < MAX_ORDER; order++) {
		unsigned long blocks;

#if defined(OPLUS_FEATURE_MULTI_FREEAREA) && \
	defined(CONFIG_PHYSICAL_ANTI_FRAGMENTATION)
		blocks = zone->free_area[flc][order].nr_free;
#else
		blocks = zone->free_area[order].nr_free;
#endif

		info->free_pages += blocks << order;
		if (order >= suitable_order)
			info->free_blocks_suitable +=
				blocks << (order - suitable_order);
	}
#if defined(OPLUS_FEATURE_MULTI_FREEAREA) && \
	defined(CONFIG_PHYSICAL_ANTI_FRAGMENTATION)
	}
#endif
}

static unsigned int oplus_fragmentation_for_order(struct zone *zone,
						  unsigned int order)
{
	struct oplus_contig_page_info info;

	oplus_fill_contig_page_info(zone, order, &info);
	if (!info.free_pages)
		return 0;

	return div_u64((info.free_pages -
			(info.free_blocks_suitable << order)) * 100,
			info.free_pages);
}

static unsigned int oplus_fragmentation_score_node(pg_data_t *pgdat)
{
	unsigned long score = 0;
	int zoneid;

	for (zoneid = 0; zoneid < MAX_NR_ZONES; zoneid++) {
		struct zone *zone = &pgdat->node_zones[zoneid];

		if (!zone->present_pages)
			continue;
		score += zone->present_pages *
			oplus_fragmentation_for_order(zone,
				READ_ONCE(oplus_compaction_hpage_order));
	}

	return div64_ul(score, pgdat->node_present_pages + 1);
}

static bool oplus_should_proactive_compact(pg_data_t *pgdat)
{
	unsigned int proactiveness;
	unsigned int low;

	proactiveness = READ_ONCE(oplus_compaction_proactiveness);
	low = max(100U - proactiveness, 5U);
	return oplus_fragmentation_score_node(pgdat) > min(low + 10, 100U);
}

static int oplus_parse_tunable(char *input, const char *name,
			       unsigned int maximum, unsigned int *target)
{
	char *value = strstr(input, name);
	unsigned int parsed;
	int ret;

	if (!value)
		return -ENOENT;
	ret = kstrtouint(value + strlen(name), 0, &parsed);
	if (ret)
		return ret;
	if (parsed > maximum)
		return -ERANGE;

	WRITE_ONCE(*target, parsed);
	return 0;
}

static ssize_t oplus_fragmentation_index_write(struct file *file,
		const char __user *buffer, size_t count, loff_t *ppos)
{
	char input[OPLUS_COMPACT_INPUT_LEN];
	char *value;
	int ret;

	if (!count || count >= sizeof(input))
		return -EINVAL;
	if (copy_from_user(input, buffer, count))
		return -EFAULT;
	input[count] = '\0';
	value = strstrip(input);

	ret = oplus_parse_tunable(value, "compaction_hpage_order=",
				  MAX_ORDER - 1,
				  &oplus_compaction_hpage_order);
	if (ret == -ENOENT)
		ret = oplus_parse_tunable(value, "compaction_proactiveness=",
					  100,
					  &oplus_compaction_proactiveness);

	return ret ? ret : count;
}

static ssize_t oplus_fragmentation_index_read(struct file *file,
		char __user *buffer, size_t count, loff_t *ppos)
{
	char output[64];
	int length;

	length = scnprintf(output, sizeof(output), "%u %u %u\n",
			oplus_should_proactive_compact(NODE_DATA(0)) ? 1 : 0,
			READ_ONCE(oplus_compaction_hpage_order),
			READ_ONCE(oplus_compaction_proactiveness));
	return simple_read_from_buffer(buffer, count, ppos, output, length);
}

static const struct file_operations oplus_fragmentation_index_fops = {
	.owner	= THIS_MODULE,
	.read	= oplus_fragmentation_index_read,
	.write	= oplus_fragmentation_index_write,
	.llseek	= default_llseek,
};

static int __init oplus_proactive_compact_init(void)
{
	struct proc_dir_entry *directory;

	directory = proc_mkdir("oplus_mem", NULL);
	if (!directory)
		return -ENOMEM;
	if (!proc_create("fragmentation_index", 0666, directory,
			 &oplus_fragmentation_index_fops))
		return -ENOMEM;

	pr_info("registered /proc/oplus_mem/fragmentation_index\n");
	return 0;
}
module_init(oplus_proactive_compact_init);

MODULE_DESCRIPTION("Oplus proactive-compaction telemetry ABI");
MODULE_LICENSE("GPL v2");
