#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0
#
# Source-level Android 14 ColorOS proc-ABI audit for Miru H.40 Stage 5.
#
# Run from the kernel source root after the matching external vendor tree has
# been fetched.  This intentionally validates registrations and task-state
# wiring, not just path names, so a compatibility stub cannot pass unnoticed.

set -Eeuo pipefail

if [[ $# -ne 2 ]]; then
  echo "usage: $0 <vendor-root> <resolved-kernel-config>" >&2
  exit 2
fi

vendor_root="$1"
config="$2"
sched_assist_dir="${vendor_root}/oplus/kernel/oplus_performance/sched_assist"
sched_info_dir="${vendor_root}/oplus/kernel/oplus_performance/sched_info"
sched_assist_c="${sched_assist_dir}/sched_assist_common.c"
sched_info_c="${sched_info_dir}/oplus_sched_info.c"

check() {
  local label="$1"
  shift
  if ! "$@"; then
    echo "FAIL: ${label}" >&2
    exit 1
  fi
  echo "PASS: ${label}"
}

check kernel-root test -f Makefile
check kernel-config test -f "${config}"
check vendor-root test -d "${vendor_root}"
check sched-assist-source test -f "${sched_assist_c}"
check sched-info-source test -f "${sched_info_c}"

# Native 4.14 resource procfs: this must remain core infrastructure, not an
# Oplus compatibility replacement.
check proc-iomem-registration \
  grep -Fq 'proc_create("iomem", 0400, NULL, &proc_iomem_operations);' kernel/resource.c
check procfs-enabled grep -Fxq 'CONFIG_PROC_FS=y' "${config}"

# Scheduler-assist wiring: per-task state, fork reset and linked build path.
check sched-assist-feature-macro \
  grep -Fq -- '-DOPLUS_FEATURE_SCHED_ASSIST' Makefile
check sched-assist-build \
  grep -Fq 'obj-y += sched_assist/' kernel/Makefile
check sched-assist-companion-build \
  grep -Fq 'obj-y += special_opt/' kernel/Makefile
check task-im-flag-field \
  grep -Fq 'int ux_im_flag;' include/linux/sched.h
check task-im-flag-fork-reset \
  grep -Fq 'p->ux_im_flag = 0;' "${sched_assist_dir}/sched_assist_fork.h"
check task-ux-init-call \
  grep -Fq 'init_task_ux_info(p);' kernel/fork.c
check im-flag-enum \
  grep -Fq 'enum IM_FLAG_TYPE {' "${sched_assist_dir}/sched_assist_common.h"
check im-flag-storage \
  grep -Fq 'task->ux_im_flag = im_flag;' "${sched_assist_c}"
check im-flag-launcher-effect \
  grep -Fq 'task->ux_state |= SA_TYPE_HEAVY;' "${sched_assist_c}"
check sched-assist-proc-init \
  grep -Fq 'device_initcall(oplus_sched_assist_proc_init);' "${sched_assist_c}"

for node in debug_enabled sched_impt_task im_flag im_flag_app; do
  check "sched-assist-node-${node}" \
    grep -Fq "proc_create(\"${node}\", 0666" "${sched_assist_c}"
done

# CPU-jank control plane: preserve the reference hierarchy and mux command
# semantics while making unsupported SM8250 telemetry explicit in code.
check cpu-jank-kconfig \
  grep -Fq 'config OPLUS_FEATURE_CPU_JANKINFO' "${sched_info_dir}/Kconfig"
check cpu-jank-config-enabled \
  grep -Fxq 'CONFIG_OPLUS_FEATURE_CPU_JANKINFO=y' "${config}"
check cpu-jank-kbuild-link \
  grep -Fq 'obj-$(CONFIG_OPLUS_FEATURE_CPU_JANKINFO) += sched_info/' kernel/Makefile
check cpu-jank-kconfig-link \
  grep -Fq 'source "kernel/sched_info/Kconfig"' init/Kconfig
check cpu-jank-symlink test -L kernel/sched_info
check cpu-jank-parent \
  grep -Fq 'proc_mkdir(JANK_INFO_DIR, NULL)' "${sched_info_c}"
check cpu-jank-child \
  grep -Fq 'proc_mkdir(JANK_INFO_PROC_NODE, jank_dir)' "${sched_info_c}"
check cpu-jank-mux-work \
  grep -Fq 'schedule_delayed_work(&grab_hotthread_work' "${sched_info_c}"
check cpu-jank-mux-cancel \
  grep -Fq 'cancel_delayed_work_sync(&grab_hotthread_work)' "${sched_info_c}"

for node in \
  clm_enable \
  fg_freqs_threshold \
  clm_highload_all \
  clm_highload_grp \
  clm_report_threshold \
  clm_lowload_grp \
  bg_dstat_percent \
  clm_mux_switch; do
  check "cpu-jank-node-${node}" \
    grep -Fq "proc_create(\"${node}\", 0666" "${sched_info_c}"
done

cat <<EOF
result=PASS
proc_iomem=core-4.14
sched_assist_im_flag=task-backed
cpu_jank_control_plane=registered
EOF
