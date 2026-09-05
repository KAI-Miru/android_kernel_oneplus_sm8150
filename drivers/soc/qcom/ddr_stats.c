// SPDX-License-Identifier: GPL-2.0-only
/*
 * Copyright (c) 2019, The Linux Foundation. All rights reserved.
 */

#define pr_fmt(fmt) "%s: " fmt, __func__

#include <linux/errno.h>
#include <linux/init.h>
#include <linux/io.h>
#include <linux/kernel.h>
#include <linux/kobject.h>
#include <linux/mm.h>
#include <linux/module.h>
#include <linux/of.h>
#include <linux/platform_device.h>
#include <linux/slab.h>
#include <linux/types.h>

#include <clocksource/arm_arch_timer.h>

#define DDR_STATS_MAGIC		0xA1157A75
#define MAX_NUM_MODES		0x14

#define GET_PDATA_OF_ATTR(attr) \
	(container_of(attr, struct ddr_stats_kobj_attr, ka)->pdata)

struct ddr_stats_platform_data {
	phys_addr_t phys_addr_base;
	u32 phys_size;
};

struct stats_entry {
	u32 name;
	u32 count;
	u64 duration;
};

struct ddr_stats_data {
	u32 key;
	u32 entry_count;
	struct stats_entry entry[MAX_NUM_MODES];
};

struct ddr_stats_kobj_attr {
	struct kobject *kobj;
	struct kobj_attribute ka;
	struct ddr_stats_platform_data *pdata;
};

static u64 get_time_in_msec(u64 counter)
{
	do_div(counter, arch_timer_get_rate() / MSEC_PER_SEC);
	return counter;
}

static ssize_t ddr_stats_append_data_to_buf(char *buf, int length,
		int *lpm_count, struct stats_entry *data,
		u64 accumulated_duration)
{
	u32 cp_idx = 0;
	u32 name;
	u32 duration = 0;

	if (accumulated_duration)
		duration = (data->duration * 100) / accumulated_duration;

	name = (data->name >> 8) & 0xff;
	if (name == 0) {
		name = data->name & 0xff;
		(*lpm_count)++;
		return scnprintf(buf, length,
			"LPM %d:\tName:0x%x\tcount:%u\tTime(msec):%llu (~%u%%)\n",
			*lpm_count, name, data->count, data->duration,
			duration);
	}

	if (name == 1) {
		cp_idx = data->name & 0x1f;
		name = data->name >> 16;
		if (!name || !data->count)
			return 0;

		return scnprintf(buf, length,
			"Freq %dMhz:\tCP IDX:%u\tcount:%u\tTime(msec):%llu (~%u%%)\n",
			name, cp_idx, data->count, data->duration,
			duration);
	}

	return 0;
}

static ssize_t ddr_stats_copy_stats(char *buf, int size, void __iomem *reg,
		u32 entry_count)
{
	struct stats_entry data[MAX_NUM_MODES];
	u64 accumulated_duration = 0;
	int lpm_count = 0;
	ssize_t length = 0;
	ssize_t op_length;
	int i;

	reg += offsetof(struct ddr_stats_data, entry_count) + sizeof(u32);
	for (i = 0; i < entry_count; i++) {
		data[i].name = readl_relaxed(reg +
				offsetof(struct stats_entry, name));
		data[i].count = readl_relaxed(reg +
				offsetof(struct stats_entry, count));
		data[i].duration = readq_relaxed(reg +
				offsetof(struct stats_entry, duration));
		data[i].duration = get_time_in_msec(data[i].duration);
		accumulated_duration += data[i].duration;
		reg += sizeof(struct stats_entry);
	}

	for (i = 0; i < entry_count; i++) {
		op_length = ddr_stats_append_data_to_buf(buf + length,
				size - length, &lpm_count, &data[i],
				accumulated_duration);
		if (op_length >= size - length)
			break;
		length += op_length;
	}

	return length;
}

static ssize_t ddr_stats_show(struct kobject *kobj,
		struct kobj_attribute *attr, char *buf)
{
	struct ddr_stats_platform_data *pdata = GET_PDATA_OF_ATTR(attr);
	void __iomem *reg;
	ssize_t length = 0;
	u32 key;
	u32 entry_count;

	reg = ioremap_nocache(pdata->phys_addr_base, pdata->phys_size);
	if (!reg) {
		pr_err("could not ioremap start=%pa, len=%u\n",
		       &pdata->phys_addr_base, pdata->phys_size);
		return 0;
	}

	key = readl_relaxed(reg + offsetof(struct ddr_stats_data, key));
	if (key != DDR_STATS_MAGIC) {
		pr_err_ratelimited("invalid key %#x\n", key);
		goto out;
	}

	entry_count = readl_relaxed(reg +
			offsetof(struct ddr_stats_data, entry_count));
	if (entry_count > MAX_NUM_MODES) {
		pr_err_ratelimited("invalid entry count %u\n", entry_count);
		goto out;
	}

	length = ddr_stats_copy_stats(buf, PAGE_SIZE, reg, entry_count);
out:
	iounmap(reg);
	return length;
}

static int ddr_stats_create_sysfs(struct platform_device *pdev,
		struct ddr_stats_platform_data *pdata)
{
	struct ddr_stats_kobj_attr *attr;
	struct kobject *kobj;
	int ret;

	kobj = kobject_create_and_add("ddr", power_kobj);
	if (!kobj)
		return -ENODEV;

	attr = devm_kzalloc(&pdev->dev, sizeof(*attr), GFP_KERNEL);
	if (!attr) {
		kobject_put(kobj);
		return -ENOMEM;
	}

	attr->kobj = kobj;
	attr->pdata = pdata;
	sysfs_attr_init(&attr->ka.attr);
	attr->ka.attr.mode = 0444;
	attr->ka.attr.name = "residency";
	attr->ka.show = ddr_stats_show;
	platform_set_drvdata(pdev, attr);

	ret = sysfs_create_file(kobj, &attr->ka.attr);
	if (ret) {
		platform_set_drvdata(pdev, NULL);
		kobject_put(kobj);
	}
	return ret;
}

static int ddr_stats_probe(struct platform_device *pdev)
{
	struct ddr_stats_platform_data *pdata;
	struct resource *base;
	struct resource *offset;
	void __iomem *phys_ptr;
	resource_size_t base_size;
	u32 offset_addr;

	pdata = devm_kzalloc(&pdev->dev, sizeof(*pdata), GFP_KERNEL);
	if (!pdata)
		return -ENOMEM;

	base = platform_get_resource_byname(pdev, IORESOURCE_MEM,
					    "phys_addr_base");
	if (!base)
		return -ENODEV;

	offset = platform_get_resource_byname(pdev, IORESOURCE_MEM,
					      "offset_addr");
	if (!offset)
		return -ENODEV;

	phys_ptr = ioremap_nocache(offset->start, SZ_4);
	if (!phys_ptr)
		return -ENODEV;
	offset_addr = readl_relaxed(phys_ptr);
	iounmap(phys_ptr);

	base_size = resource_size(base);
	if (!offset_addr || offset_addr >= base_size ||
	    base_size - offset_addr < sizeof(struct ddr_stats_data)) {
		dev_info(&pdev->dev,
			 "DDR stats are not exported by this AOP firmware\n");
		return -ENODEV;
	}

	pdata->phys_addr_base = base->start + offset_addr;
	pdata->phys_size = base_size - offset_addr;

	return ddr_stats_create_sysfs(pdev, pdata);
}

static int ddr_stats_remove(struct platform_device *pdev)
{
	struct ddr_stats_kobj_attr *attr = platform_get_drvdata(pdev);

	if (!attr)
		return 0;
	sysfs_remove_file(attr->kobj, &attr->ka.attr);
	kobject_put(attr->kobj);
	platform_set_drvdata(pdev, NULL);
	return 0;
}

static const struct of_device_id ddr_stats_table[] = {
	{ .compatible = "qcom,ddr-stats" },
	{ }
};
MODULE_DEVICE_TABLE(of, ddr_stats_table);

static struct platform_driver ddr_stats_driver = {
	.probe = ddr_stats_probe,
	.remove = ddr_stats_remove,
	.driver = {
		.name = "ddr_stats",
		.of_match_table = ddr_stats_table,
	},
};
module_platform_driver(ddr_stats_driver);

MODULE_LICENSE("GPL v2");
MODULE_DESCRIPTION("MSM DDR Statistics driver");
MODULE_ALIAS("platform:msm_ddr_stats_log");
