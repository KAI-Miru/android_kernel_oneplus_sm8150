/* SPDX-License-Identifier: GPL-2.0 */
#ifndef _SDE_KCAL_CTRL_H_
#define _SDE_KCAL_CTRL_H_

#include <linux/types.h>

struct drm_device;

struct sde_kcal_config {
	u16 red;
	u16 green;
	u16 blue;
	u16 minimum;
	bool enabled;
	u32 generation;
};

#ifdef CONFIG_DRM_MSM_KCAL_CTRL
int sde_kcal_ctrl_init(void);
void sde_kcal_ctrl_exit(void);

void sde_kcal_drm_register(struct drm_device *ddev);
void sde_kcal_drm_unregister(struct drm_device *ddev);

void sde_kcal_get_config(struct sde_kcal_config *config);
u32 sde_kcal_get_generation(void);
void sde_kcal_apply_pcc(u32 *data);
#else
static inline int sde_kcal_ctrl_init(void)
{
	return 0;
}

static inline void sde_kcal_ctrl_exit(void)
{
}

static inline void sde_kcal_drm_register(struct drm_device *ddev)
{
}

static inline void sde_kcal_drm_unregister(struct drm_device *ddev)
{
}

static inline void sde_kcal_get_config(struct sde_kcal_config *config)
{
}

static inline u32 sde_kcal_get_generation(void)
{
	return 0;
}

static inline void sde_kcal_apply_pcc(u32 *data)
{
}
#endif

#endif /* _SDE_KCAL_CTRL_H_ */
