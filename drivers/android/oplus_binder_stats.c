// SPDX-License-Identifier: GPL-2.0-only
/*
 * Build the source-owned OPlus MIDAS BinderStats driver into the kernel.
 *
 * The official OnePlus Android layout places the companion repository at
 * android/vendor beside android/kernel. Keeping the implementation in that
 * repository avoids a divergent in-kernel copy while restoring the donor's
 * CONFIG_OPLUS_FEATURE_BINDER_STATS_ENABLE=y linkage.
 */
#include "../../../../vendor/oplus/kernel/power/midas/binder_stats_dev.c"
