/* SPDX-License-Identifier: GPL-2.0-only */
#ifndef _LINUX_HYBRIDSWAP_H
#define _LINUX_HYBRIDSWAP_H

#include <linux/gfp.h>

struct cgroup_subsys_state;
struct mem_cgroup;
struct zone;

#ifdef CONFIG_HYBRIDSWAP
void hybridswap_mem_cgroup_alloc(struct mem_cgroup *memcg);
void hybridswap_mem_cgroup_free(struct mem_cgroup *memcg);
void hybridswap_mem_cgroup_online(struct cgroup_subsys_state *css,
		struct mem_cgroup *memcg);
void hybridswap_mem_cgroup_offline(struct cgroup_subsys_state *css,
		struct mem_cgroup *memcg);
#else
static inline void hybridswap_mem_cgroup_alloc(struct mem_cgroup *memcg) { }
static inline void hybridswap_mem_cgroup_free(struct mem_cgroup *memcg) { }
static inline void hybridswap_mem_cgroup_online(
		struct cgroup_subsys_state *css, struct mem_cgroup *memcg) { }
static inline void hybridswap_mem_cgroup_offline(
		struct cgroup_subsys_state *css, struct mem_cgroup *memcg) { }
#endif

#ifdef CONFIG_HYBRIDSWAP_SWAPD
void hybridswap_tune_scan_type(char *scan_balance);
bool free_swap_is_low(void);
void alloc_pages_slowpath_hook(void *data, gfp_t gfp_mask,
		unsigned int order, unsigned long delta);
void rmqueue_hook(void *data, struct zone *preferred_zone,
		struct zone *zone, unsigned int order, gfp_t gfp_flags,
		unsigned int alloc_flags, int migratetype);
#else
static inline void hybridswap_tune_scan_type(char *scan_balance) { }
static inline bool free_swap_is_low(void) { return false; }
static inline void alloc_pages_slowpath_hook(void *data, gfp_t gfp_mask,
		unsigned int order, unsigned long delta) { }
static inline void rmqueue_hook(void *data, struct zone *preferred_zone,
		struct zone *zone, unsigned int order, gfp_t gfp_flags,
		unsigned int alloc_flags, int migratetype) { }
#endif

#ifdef CONFIG_HYBRIDSWAP_CORE
void mem_cgroup_id_remove_hook(void *data, struct mem_cgroup *memcg);
#else
static inline void mem_cgroup_id_remove_hook(void *data,
		struct mem_cgroup *memcg) { }
#endif

#endif /* _LINUX_HYBRIDSWAP_H */
