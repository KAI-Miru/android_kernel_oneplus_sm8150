/*
 * Copyright (c) 2015-2018, The Linux Foundation. All rights reserved.
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License version 2 and
 * only version 2 as published by the Free Software Foundation.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 */
#include <linux/module.h>
#include <linux/kernel.h>
#include <linux/mm.h>
#include <linux/mm_inline.h>
#include <linux/swap.h>
#include <linux/sort.h>
#include <linux/oom.h>
#include <linux/rmap.h>
#include <linux/sched.h>
#include <linux/sched/mm.h>
#include <linux/rcupdate.h>
#include <linux/notifier.h>
#include <linux/vmpressure.h>

#if defined(OPLUS_FEATURE_PROCESS_RECLAIM) && defined(CONFIG_PROCESS_RECLAIM_ENHANCE)
#include <linux/huge_mm.h>
#include <linux/hugetlb.h>
#include <linux/process_mm_reclaim.h>
#include <asm/tlbflush.h>
#endif

#define CREATE_TRACE_POINTS
#include <trace/events/process_reclaim.h>

#define MAX_SWAP_TASKS SWAP_CLUSTER_MAX
#define STAGE3A_RECLAIM_PAGES 256

static void swap_fn(struct work_struct *work);
DECLARE_WORK(swap_work, swap_fn);

/* User knob to enable/disable process reclaim feature */
static int enable_process_reclaim;
module_param_named(enable_process_reclaim, enable_process_reclaim, int, 0644);

/* Legacy generic-anon budget. Ignored while the Stage 3A pass is active. */
int per_swap_size = SWAP_CLUSTER_MAX * 32;
module_param_named(per_swap_size, per_swap_size, int, 0644);

/*
 * Stage 3A per-task quota. Keep the tested module-parameter name for
 * compatibility with validation tooling; 256 pages is the validated value.
 */
int tsk_nomap_swap_sz = STAGE3A_RECLAIM_PAGES;
module_param_named(tsk_nomap_swap_sz, tsk_nomap_swap_sz, int, 0644);

int reclaim_avg_efficiency;
module_param_named(reclaim_avg_efficiency, reclaim_avg_efficiency, int, 0444);

/* Cumulative pages reclaimed by the legacy generic-anon worker. */
static unsigned long reclaimed_anon;
module_param_named(reclaimed_anon, reclaimed_anon, ulong, 0444);

/* Cumulative Stage 3A inactive-anon pages; legacy telemetry name retained. */
static unsigned long reclaimed_nomap;
module_param_named(reclaimed_nomap, reclaimed_nomap, ulong, 0444);

/* The vmpressure region where process reclaim operates */
static unsigned long pressure_min = 50;
static unsigned long pressure_max = 90;
module_param_named(pressure_min, pressure_min, ulong, 0644);
module_param_named(pressure_max, pressure_max, ulong, 0644);

static short min_score_adj = 360;
module_param_named(min_score_adj, min_score_adj, short, 0644);

/*
 * Scheduling process reclaim workqueue unecessarily
 * when the reclaim efficiency is low does not make
 * sense. We try to detect a drop in efficiency and
 * disable reclaim for a time period. This period and the
 * period for which we monitor a drop in efficiency is
 * defined by swap_eff_win. swap_opt_eff is the optimal
 * efficincy used as theshold for this.
 */
static int swap_eff_win = 2;
module_param_named(swap_eff_win, swap_eff_win, int, 0644);

static int swap_opt_eff = 50;
module_param_named(swap_opt_eff, swap_opt_eff, int, 0644);

static atomic_t skip_reclaim = ATOMIC_INIT(0);
/* Not atomic since only a single instance of swap_fn run at a time */
static int monitor_eff;

struct selected_task {
	struct task_struct *p;
	int tasksize;
	short oom_score_adj;
};

int selected_cmp(const void *a, const void *b)
{
	const struct selected_task *x = a;
	const struct selected_task *y = b;
	int ret;

	ret = x->tasksize < y->tasksize ? -1 : 1;

	return ret;
}

static int test_task_flag(struct task_struct *p, int flag)
{
	struct task_struct *t = p;

	rcu_read_lock();
	for_each_thread(p, t) {
		task_lock(t);
		if (test_tsk_thread_flag(t, flag)) {
			task_unlock(t);
			rcu_read_unlock();
			return 1;
		}
		task_unlock(t);
	}
	rcu_read_unlock();

	return 0;
}

#if defined(OPLUS_FEATURE_PROCESS_RECLAIM) && defined(CONFIG_PROCESS_RECLAIM_ENHANCE)
/*
 * Automatic process reclaim should be conservative: reclaim inactive
 * anonymous pages and stop promptly if OPlus userspace makes the target
 * runnable/foreground or the bounded reclaim window expires.
 */
static int reclaim_inactive_anon_pte_range(pmd_t *pmd, unsigned long addr,
					   unsigned long end,
					   struct mm_walk *walk)
{
	struct reclaim_param *rp = walk->private;
	struct vm_area_struct *vma = rp->vma;
	pte_t *pte, *orig_pte, ptent;
	spinlock_t *ptl;
	struct page *page;
	LIST_HEAD(page_list);
	int isolated;
	int reclaimed;
	int ret = 0;

	split_huge_pmd(vma, addr, pmd);
	if (pmd_trans_unstable(pmd) || !rp->nr_to_reclaim)
		return 0;
cont:
	isolated = 0;
	orig_pte = pte = pte_offset_map_lock(vma->vm_mm, pmd, addr, &ptl);
	for (; addr != end; pte++, addr += PAGE_SIZE) {
		if (rp->reclaimed_task &&
				(ret = is_reclaim_should_cancel(walk))) {
			ret = -ret;
			break;
		}

		ptent = *pte;
		if (!pte_present(ptent))
			continue;

		page = vm_normal_page(vma, addr, ptent);
		if (!page)
			continue;

		/* Preserve the target's active working set. */
		if (PageActive(page) || PageUnevictable(page))
			continue;

		if (isolate_lru_page(page))
			continue;

		/*
		 * MADV_FREE clears SwapBacked. If the page was touched again,
		 * reclaim can put it back as SwapBacked and skip it; avoid the
		 * isolated-page accounting mismatch in that case.
		 */
		if (PageAnon(page) && !PageSwapBacked(page)) {
			putback_lru_page(page);
			continue;
		}

		list_add(&page->lru, &page_list);
		inc_node_page_state(page, NR_ISOLATED_ANON +
				page_is_file_cache(page));
		isolated++;
		rp->nr_scanned++;
		if ((isolated >= SWAP_CLUSTER_MAX) || !rp->nr_to_reclaim)
			break;
	}
	pte_unmap_unlock(orig_pte, ptl);

	reclaimed = reclaim_pages_from_list(&page_list, vma, walk);
	rp->nr_reclaimed += reclaimed;
	rp->nr_to_reclaim -= reclaimed;
	if (rp->nr_to_reclaim < 0)
		rp->nr_to_reclaim = 0;

	if (ret < 0)
		return ret;
	if (!rp->nr_to_reclaim)
		return -PR_FULL;
	if (addr != end)
		goto cont;

	cond_resched();
	return 0;
}

/*
 * Stage 3A ordinary process reclaim. Keep reclaim_task_nomap() free for
 * the Qualcomm KGSL notifier semantics that belong to Stage 3B.
 */
static struct reclaim_param reclaim_task_inactive_anon(struct task_struct *task,
							int nr_to_reclaim)
{
	struct mm_struct *mm;
	struct vm_area_struct *vma;
	struct mm_walk reclaim_walk = {};
	struct reclaim_param rp = {
		.nr_to_reclaim = nr_to_reclaim,
		.inactive_lru = true,
		.reclaimed_task = task,
	};
	bool set_reclaimer = !current_is_reclaimer();
	int ret = 0;

	get_task_struct(task);
	mm = get_task_mm(task);
	if (!mm)
		goto out;

	reclaim_walk.mm = mm;
	reclaim_walk.pmd_entry = reclaim_inactive_anon_pte_range;
	reclaim_walk.private = &rp;

	if (set_reclaimer)
		current->flags |= PF_RECLAIM_SHRINK;
	current->reclaim.stop_jiffies = jiffies + RECLAIM_TIMEOUT_JIFFIES;

	down_read(&mm->mmap_sem);
	for (vma = mm->mmap; vma; vma = vma->vm_next) {
		if (is_vm_hugetlb_page(vma))
			continue;
		if (vma->vm_file)
			continue;
		if (!rp.nr_to_reclaim)
			break;
		if (is_reclaim_should_cancel(&reclaim_walk))
			break;

		rp.vma = vma;
		ret = walk_page_range(vma->vm_start, vma->vm_end,
					      &reclaim_walk);
		if (ret < 0)
			break;
	}

	flush_tlb_mm(mm);
	up_read(&mm->mmap_sem);

	if (set_reclaimer)
		current->flags &= ~PF_RECLAIM_SHRINK;
	mmput(mm);
out:
	put_task_struct(task);
	return rp;
}
#endif

static void swap_fn(struct work_struct *work)
{
	struct task_struct *tsk;
	struct reclaim_param rp;

	/* Pick the best MAX_SWAP_TASKS tasks in terms of anon size */
	struct selected_task selected[MAX_SWAP_TASKS] = {{0, 0, 0},};
	int si = 0;
	int i;
	int min_idx = -1;
	int tasksize;
	int total_sz = 0;
	int total_scan = 0;
	int total_reclaimed = 0;
	int nr_to_reclaim;
	int efficiency;
	bool use_inactive_anon = false;

#if defined(OPLUS_FEATURE_PROCESS_RECLAIM) && defined(CONFIG_PROCESS_RECLAIM_ENHANCE)
	use_inactive_anon = tsk_nomap_swap_sz > 0;
#endif

	/* Both reclaim modes disabled: leave process reclaim dormant. */
	if (per_swap_size <= 0 && !use_inactive_anon)
		return;

	rcu_read_lock();
	for_each_process(tsk) {
		struct task_struct *p;
		short oom_score_adj;

		if (tsk->flags & PF_KTHREAD)
			continue;

		if (test_task_flag(tsk, TIF_MEMDIE))
			continue;

		p = find_lock_task_mm(tsk);
		if (!p)
			continue;

		oom_score_adj = p->signal->oom_score_adj;
		if (oom_score_adj < min_score_adj) {
			task_unlock(p);
			continue;
		}

		/* Stage 3A ranks by RSS; the legacy path keeps anon-only ranking. */
		if (use_inactive_anon)
			tasksize = get_mm_rss(p->mm);
		else
			tasksize = get_mm_counter(p->mm, MM_ANONPAGES);
		task_unlock(p);

		if (tasksize <= 0)
			continue;

		if (si == MAX_SWAP_TASKS) {
			/*
			 * Preserve the exact top-MAX_SWAP_TASKS selection without
			 * sorting the whole array for every later eligible process.
			 * Recompute the minimum only after replacing it.
			 */
			if (min_idx < 0) {
				min_idx = 0;
				for (i = 1; i < MAX_SWAP_TASKS; i++)
					if (selected[i].tasksize <
							selected[min_idx].tasksize)
						min_idx = i;
			}

			if (tasksize < selected[min_idx].tasksize)
				continue;

			selected[min_idx].p = p;
			selected[min_idx].oom_score_adj = oom_score_adj;
			selected[min_idx].tasksize = tasksize;

			min_idx = 0;
			for (i = 1; i < MAX_SWAP_TASKS; i++)
				if (selected[i].tasksize < selected[min_idx].tasksize)
					min_idx = i;
		} else {
			selected[si].p = p;
			selected[si].oom_score_adj = oom_score_adj;
			selected[si].tasksize = tasksize;
			si++;
		}
	}

	/*
	 * The legacy implementation sorted on every candidate after the array
	 * filled. One final sort preserves its largest-first reclaim ordering
	 * without the repeated pressure-time sort cost. Leave <= 32-task events
	 * in their historical enumeration order.
	 */
	if (min_idx >= 0)
		sort(&selected[0], MAX_SWAP_TASKS,
			sizeof(struct selected_task), &selected_cmp, NULL);

	for (i = 0; i < si; i++)
		total_sz += selected[i].tasksize;

	/* Skip reclaim if total size is too less */
	if (total_sz < SWAP_CLUSTER_MAX) {
		rcu_read_unlock();
		return;
	}

	for (i = 0; i < si; i++)
		get_task_struct(selected[i].p);

	rcu_read_unlock();

	while (si--) {
		if (!use_inactive_anon && per_swap_size > 0) {
			nr_to_reclaim =
				(selected[si].tasksize * per_swap_size) / total_sz;
			/* scan atleast a page */
			if (!nr_to_reclaim)
				nr_to_reclaim = 1;

			rp = reclaim_task_anon(selected[si].p, nr_to_reclaim);

			trace_process_reclaim(selected[si].tasksize,
					selected[si].oom_score_adj, rp.nr_scanned,
					rp.nr_reclaimed, per_swap_size, total_sz,
					nr_to_reclaim);
			total_scan += rp.nr_scanned;
			total_reclaimed += rp.nr_reclaimed;
			reclaimed_anon += rp.nr_reclaimed;
		}

#if defined(OPLUS_FEATURE_PROCESS_RECLAIM) && defined(CONFIG_PROCESS_RECLAIM_ENHANCE)
		if (use_inactive_anon) {
			rp = reclaim_task_inactive_anon(selected[si].p,
						       tsk_nomap_swap_sz);
			total_scan += rp.nr_scanned;
			total_reclaimed += rp.nr_reclaimed;
			reclaimed_nomap += rp.nr_reclaimed;
		}
#endif
		put_task_struct(selected[si].p);
	}

	if (total_scan) {
		efficiency = (total_reclaimed * 100) / total_scan;

		if (efficiency < swap_opt_eff) {
			if (++monitor_eff == swap_eff_win) {
				atomic_set(&skip_reclaim, swap_eff_win);
				monitor_eff = 0;
			}
		} else {
			monitor_eff = 0;
		}

		reclaim_avg_efficiency =
			(efficiency + reclaim_avg_efficiency) / 2;
		trace_process_reclaim_eff(efficiency, reclaim_avg_efficiency);
	}
}

static int vmpressure_notifier(struct notifier_block *nb,
			unsigned long action, void *data)
{
	unsigned long pressure = action;

	if (!enable_process_reclaim)
		return 0;

	if (!current_is_kswapd())
		return 0;

	if (atomic_dec_if_positive(&skip_reclaim) >= 0)
		return 0;

	if ((pressure >= pressure_min) && (pressure < pressure_max))
		if (!work_pending(&swap_work))
			queue_work(system_unbound_wq, &swap_work);
	return 0;
}

static struct notifier_block vmpr_nb = {
	.notifier_call = vmpressure_notifier,
};

static int __init process_reclaim_init(void)
{
	vmpressure_notifier_register(&vmpr_nb);
	return 0;
}

static void __exit process_reclaim_exit(void)
{
	vmpressure_notifier_unregister(&vmpr_nb);
}

module_init(process_reclaim_init);
module_exit(process_reclaim_exit);