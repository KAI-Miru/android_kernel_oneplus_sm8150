// SPDX-License-Identifier: GPL-2.0
/*
 * Kernel-level RGB calibration for the SDE DSPP PCC pipeline.
 */

#include <linux/device.h>
#include <linux/kernel.h>
#include <linux/math64.h>
#include <linux/mutex.h>
#include <linux/platform_device.h>
#include <linux/spinlock.h>
#include <linux/workqueue.h>

#include <drm/drm_atomic.h>
#include <drm/drm_crtc.h>
#include <drm/drm_drv.h>
#include <drm/drm_modeset_lock.h>

#include "sde_color_processing.h"
#include "sde_kcal_ctrl.h"

#define KCAL_CTRL_NAME			"kcal_ctrl"
#define KCAL_NEUTRAL			256
#define KCAL_MIN_VALUE			1
#define KCAL_MAX_VALUE			256
#define KCAL_MODESET_RETRIES		5

#define PCC_RED_DIAGONAL_INDEX		3
#define PCC_GREEN_DIAGONAL_INDEX	7
#define PCC_BLUE_DIAGONAL_INDEX		11

static DEFINE_SPINLOCK(kcal_config_lock);
static struct sde_kcal_config kcal_config = {
	.red = KCAL_NEUTRAL,
	.green = KCAL_NEUTRAL,
	.blue = KCAL_NEUTRAL,
	.minimum = KCAL_MIN_VALUE,
	.enabled = true,
	.generation = 0,
};

static DEFINE_MUTEX(kcal_drm_lock);
static struct drm_device *kcal_drm;
static struct platform_device *kcal_pdev;

static void sde_kcal_update_worker(struct work_struct *work);
static DECLARE_WORK(kcal_update_work, sde_kcal_update_worker);

void sde_kcal_get_config(struct sde_kcal_config *config)
{
	unsigned long flags;

	if (!config)
		return;

	spin_lock_irqsave(&kcal_config_lock, flags);
	*config = kcal_config;
	spin_unlock_irqrestore(&kcal_config_lock, flags);
}

u32 sde_kcal_get_generation(void)
{
	struct sde_kcal_config config;

	sde_kcal_get_config(&config);
	return config.generation;
}

static void sde_kcal_next_generation(void)
{
	kcal_config.generation++;
	if (!kcal_config.generation)
		kcal_config.generation++;
}

static void sde_kcal_schedule_update(void)
{
	schedule_work(&kcal_update_work);
}

static u32 sde_kcal_scale_coefficient(u32 coefficient, u16 multiplier)
{
	return (u32)div_u64((u64)coefficient * multiplier, KCAL_NEUTRAL);
}

void sde_kcal_apply_pcc(u32 *data)
{
	struct sde_kcal_config config;

	if (!data)
		return;

	sde_kcal_get_config(&config);
	if (!config.enabled)
		return;

	data[PCC_RED_DIAGONAL_INDEX] =
		sde_kcal_scale_coefficient(data[PCC_RED_DIAGONAL_INDEX],
					   config.red);
	data[PCC_GREEN_DIAGONAL_INDEX] =
		sde_kcal_scale_coefficient(data[PCC_GREEN_DIAGONAL_INDEX],
					   config.green);
	data[PCC_BLUE_DIAGONAL_INDEX] =
		sde_kcal_scale_coefficient(data[PCC_BLUE_DIAGONAL_INDEX],
					   config.blue);
}

static int sde_kcal_commit_update(struct drm_device *ddev)
{
	struct drm_modeset_acquire_ctx ctx;
	struct drm_atomic_state *state = NULL;
	struct drm_crtc_state *crtc_state;
	struct drm_crtc *crtc;
	bool update = false;
	int retries = 0;
	int ret;

	if (drm_dev_is_unplugged(ddev))
		return -ENODEV;

	drm_modeset_acquire_init(&ctx, 0);

retry:
	ret = drm_modeset_lock_all_ctx(ddev, &ctx);
	if (ret == -EDEADLK && retries++ < KCAL_MODESET_RETRIES) {
		drm_modeset_backoff(&ctx);
		goto retry;
	}
	if (ret)
		goto out;

	state = drm_atomic_state_alloc(ddev);
	if (!state) {
		ret = -ENOMEM;
		goto out;
	}
	state->acquire_ctx = &ctx;

	drm_for_each_crtc(crtc, ddev) {
		if (!crtc->state || !crtc->state->active)
			continue;

		if (!sde_cp_crtc_kcal_update(crtc))
			continue;

		crtc_state = drm_atomic_get_crtc_state(state, crtc);
		if (IS_ERR(crtc_state)) {
			ret = PTR_ERR(crtc_state);
			goto put_state;
		}

		update = true;
	}

	if (!update) {
		ret = 0;
		goto put_state;
	}

	ret = drm_atomic_commit(state);

put_state:
	drm_atomic_state_put(state);
	state = NULL;

	if (ret == -EDEADLK && retries++ < KCAL_MODESET_RETRIES) {
		drm_modeset_backoff(&ctx);
		update = false;
		goto retry;
	}
out:
	drm_modeset_drop_locks(&ctx);
	drm_modeset_acquire_fini(&ctx);

	return ret;
}

static void sde_kcal_update_worker(struct work_struct *work)
{
	struct drm_device *ddev = NULL;
	int ret;

	mutex_lock(&kcal_drm_lock);
	if (kcal_drm) {
		ddev = kcal_drm;
		drm_dev_ref(ddev);
	}
	mutex_unlock(&kcal_drm_lock);

	if (!ddev)
		return;

	ret = sde_kcal_commit_update(ddev);
	if (ret && ret != -ENODEV)
		pr_warn_ratelimited("KCAL display update failed: %d\n", ret);

	drm_dev_unref(ddev);
}

void sde_kcal_drm_register(struct drm_device *ddev)
{
	bool registered = false;

	if (!ddev)
		return;

	mutex_lock(&kcal_drm_lock);
	if (!kcal_drm) {
		drm_dev_ref(ddev);
		kcal_drm = ddev;
		registered = true;
	}
	mutex_unlock(&kcal_drm_lock);

	if (registered)
		sde_kcal_schedule_update();
}

void sde_kcal_drm_unregister(struct drm_device *ddev)
{
	bool registered = false;

	mutex_lock(&kcal_drm_lock);
	if (kcal_drm == ddev) {
		kcal_drm = NULL;
		registered = true;
	}
	mutex_unlock(&kcal_drm_lock);

	if (!registered)
		return;

	cancel_work_sync(&kcal_update_work);
	drm_dev_unref(ddev);
}

static ssize_t kcal_show(struct device *dev,
			 struct device_attribute *attr, char *buf)
{
	struct sde_kcal_config config;

	sde_kcal_get_config(&config);
	return scnprintf(buf, PAGE_SIZE, "%u %u %u\n",
			 config.red, config.green, config.blue);
}

static ssize_t kcal_store(struct device *dev,
			  struct device_attribute *attr,
			  const char *buf, size_t count)
{
	unsigned long flags;
	u32 red, green, blue;
	bool changed;

	if (sscanf(buf, "%u %u %u", &red, &green, &blue) != 3)
		return -EINVAL;

	if (red < KCAL_MIN_VALUE || red > KCAL_MAX_VALUE ||
	    green < KCAL_MIN_VALUE || green > KCAL_MAX_VALUE ||
	    blue < KCAL_MIN_VALUE || blue > KCAL_MAX_VALUE)
		return -EINVAL;

	spin_lock_irqsave(&kcal_config_lock, flags);
	red = max_t(u32, red, kcal_config.minimum);
	green = max_t(u32, green, kcal_config.minimum);
	blue = max_t(u32, blue, kcal_config.minimum);
	changed = kcal_config.red != red ||
		  kcal_config.green != green ||
		  kcal_config.blue != blue;
	if (changed) {
		kcal_config.red = red;
		kcal_config.green = green;
		kcal_config.blue = blue;
		sde_kcal_next_generation();
	}
	spin_unlock_irqrestore(&kcal_config_lock, flags);

	if (changed)
		sde_kcal_schedule_update();

	return count;
}
static DEVICE_ATTR_RW(kcal);

static ssize_t kcal_enable_show(struct device *dev,
				struct device_attribute *attr, char *buf)
{
	struct sde_kcal_config config;

	sde_kcal_get_config(&config);
	return scnprintf(buf, PAGE_SIZE, "%u\n", config.enabled);
}

static ssize_t kcal_enable_store(struct device *dev,
				 struct device_attribute *attr,
				 const char *buf, size_t count)
{
	unsigned long flags;
	unsigned int value;
	bool changed;
	int ret;

	ret = kstrtouint(buf, 10, &value);
	if (ret || value > 1)
		return -EINVAL;

	spin_lock_irqsave(&kcal_config_lock, flags);
	changed = kcal_config.enabled != value;
	if (changed) {
		kcal_config.enabled = value;
		sde_kcal_next_generation();
	}
	spin_unlock_irqrestore(&kcal_config_lock, flags);

	if (changed)
		sde_kcal_schedule_update();

	return count;
}
static DEVICE_ATTR_RW(kcal_enable);

static ssize_t kcal_min_show(struct device *dev,
			     struct device_attribute *attr, char *buf)
{
	struct sde_kcal_config config;

	sde_kcal_get_config(&config);
	return scnprintf(buf, PAGE_SIZE, "%u\n", config.minimum);
}

static ssize_t kcal_min_store(struct device *dev,
			      struct device_attribute *attr,
			      const char *buf, size_t count)
{
	unsigned long flags;
	unsigned int value;
	bool changed;
	int ret;

	ret = kstrtouint(buf, 10, &value);
	if (ret || value < KCAL_MIN_VALUE || value > KCAL_MAX_VALUE)
		return -EINVAL;

	spin_lock_irqsave(&kcal_config_lock, flags);
	changed = kcal_config.minimum != value;
	if (changed) {
		kcal_config.minimum = value;
		kcal_config.red = max_t(u16, kcal_config.red, value);
		kcal_config.green = max_t(u16, kcal_config.green, value);
		kcal_config.blue = max_t(u16, kcal_config.blue, value);
		sde_kcal_next_generation();
	}
	spin_unlock_irqrestore(&kcal_config_lock, flags);

	if (changed)
		sde_kcal_schedule_update();

	return count;
}
static DEVICE_ATTR_RW(kcal_min);

static struct attribute *kcal_attrs[] = {
	&dev_attr_kcal.attr,
	&dev_attr_kcal_enable.attr,
	&dev_attr_kcal_min.attr,
	NULL,
};

static const struct attribute_group kcal_attr_group = {
	.attrs = kcal_attrs,
};

int sde_kcal_ctrl_init(void)
{
	int ret;

	kcal_pdev = platform_device_register_simple(KCAL_CTRL_NAME, 0,
						    NULL, 0);
	if (IS_ERR(kcal_pdev)) {
		ret = PTR_ERR(kcal_pdev);
		kcal_pdev = NULL;
		return ret;
	}

	ret = sysfs_create_group(&kcal_pdev->dev.kobj, &kcal_attr_group);
	if (ret) {
		platform_device_unregister(kcal_pdev);
		kcal_pdev = NULL;
	}

	return ret;
}

void sde_kcal_ctrl_exit(void)
{
	if (!kcal_pdev)
		return;

	sysfs_remove_group(&kcal_pdev->dev.kobj, &kcal_attr_group);
	cancel_work_sync(&kcal_update_work);
	platform_device_unregister(kcal_pdev);
	kcal_pdev = NULL;
}
