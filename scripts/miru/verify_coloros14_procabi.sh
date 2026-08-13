#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0
#
# Source-level Android 14 ColorOS proc-ABI audit for Miru H.40 Stage 6.
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
frame_boost_dir="${vendor_root}/oplus/kernel/oplus_performance/frame_boost"
frame_boost_c="${frame_boost_dir}/frame_boost.c"
frame_group_c="${frame_boost_dir}/frame_group.c"
frame_ioctl_c="${frame_boost_dir}/frame_ioctl.c"
frame_sysctl_c="${frame_boost_dir}/frame_sysctl.c"

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
check frame-boost-source test -f "${frame_boost_c}"
check frame-boost-group-source test -f "${frame_group_c}"
check frame-boost-ioctl-source test -f "${frame_ioctl_c}"
check frame-boost-sysctl-source test -f "${frame_sysctl_c}"

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
check sched-assist-audio-build \
  grep -Fq 'obj-y += sched_assist_audio.o' "${sched_assist_dir}/Makefile"
check sched-assist-audio-im-hook \
  grep -Fq 'oplus_sched_assist_audio_perf_addIm(task, im_flag);' "${sched_assist_c}"
check sched-assist-audio-enqueue-hook \
  grep -Fq 'oplus_sched_assist_audio_enqueue_hook(p);' kernel/sched/fair.c
check sched-assist-proc-init \
  grep -Fq 'device_initcall(oplus_sched_assist_proc_init);' "${sched_assist_c}"
check task-ux-state-proc-declaration \
  grep -Fq 'extern const struct file_operations proc_ux_state_operations;' fs/proc/base.c
check task-ux-state-proc-entry \
  grep -Fq 'REG("ux_state", S_IRUGO | S_IWUGO, proc_ux_state_operations)' fs/proc/base.c
check task-ux-state-system-owner \
  grep -Fq 'inode->i_uid = GLOBAL_SYSTEM_UID;' fs/proc/base.c

for node in debug_enabled sched_impt_task im_flag im_flag_app; do
  check "sched-assist-node-${node}" \
    grep -Fq "proc_create(\"${node}\", 0666" "${sched_assist_c}"
done

for node in enable debug status; do
  check "sched-assist-audio-node-${node}" \
    grep -Fq "proc_create(\"${node}\", 0666" "${sched_assist_dir}/sched_assist_audio.c"
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
check cpu-jank-mux-function-bits \
  grep -Fq '#define FUNCTION_BITS                   8' "${sched_info_c}"
check cpu-jank-mux-periodic-selector \
  grep -Fq '#define PEROID_GRAB_BIT                 1' "${sched_info_c}"
check cpu-jank-live-sampling \
  grep -Fq 'get_cpu_idle_time_us' "${sched_info_c}"
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

# Frame Boost is a scheduler control plane, not a collection of no-op proc
# files.  Validate the task state, core hooks, WALT handoff, syscall ABI, and
# the H.40-specific cpufreq flag allocation.
check frame-boost-kconfig \
  grep -Fq 'config OPLUS_FEATURE_FRAME_BOOST' "${frame_boost_dir}/Kconfig"
check frame-boost-config-enabled \
  grep -Fxq 'CONFIG_OPLUS_FEATURE_FRAME_BOOST=y' "${config}"
check frame-boost-kbuild-link \
  grep -Fq 'obj-$(CONFIG_OPLUS_FEATURE_FRAME_BOOST) += tuning/' kernel/Makefile
check frame-boost-kconfig-link \
  grep -Fq 'source "kernel/tuning/Kconfig"' init/Kconfig
check frame-boost-kernel-symlink test -L kernel/tuning
check frame-boost-kernel-symlink-target \
  test "$(readlink kernel/tuning)" = '../../../vendor/oplus/kernel/oplus_performance/frame_boost'
check frame-boost-header-symlink test -L include/linux/tuning
check frame-boost-header-symlink-target \
  test "$(readlink include/linux/tuning)" = '../../../../vendor/oplus/kernel/oplus_performance/frame_boost'

for field in fbg_list fbg_state fbg_depth fbg_running preferred_cluster_id; do
  check "frame-boost-task-field-${field}" \
    grep -Fq "${field};" include/linux/sched.h
done

check frame-boost-fork-hook \
  grep -Fq 'fbg_sched_fork_hook(NULL, p);' kernel/sched/core.c
check frame-boost-exit-hook \
  grep -Fq 'fbg_flush_task_hook(NULL, prev);' kernel/sched/core.c
check frame-boost-switch-hook \
  grep -Fq 'fbg_android_rvh_schedule_handler(prev, next, rq);' kernel/sched/core.c
check frame-boost-runtime-hook \
  grep -Fq 'fbg_update_cfs_util_hook(NULL, curtask, delta_exec, curr->vruntime);' kernel/sched/fair.c
check frame-boost-placement-hook \
  grep -Fq 'set_frame_group_task_to_perfer_cpu(p, &target_cpu)' kernel/sched/fair.c
check frame-boost-migration-hook \
  grep -Fq 'fbg_skip_migration(p, env->src_cpu, env->dst_cpu)' kernel/sched/fair.c
check frame-boost-upmigration-hook \
  grep -Fq 'fbg_need_up_migration(p, rq)' kernel/sched/fair.c
check frame-boost-governor-util-hook \
  grep -Fq 'fbg_freq_policy_util(sg_policy->flags, policy->cpus, &util);' kernel/sched/cpufreq_schedutil.c
check frame-boost-governor-callback \
  grep -Fq 'fbg_add_update_freq_hook(cpufreq_update_util);' kernel/sched/cpufreq_schedutil.c
check frame-boost-binder-wake \
  grep -Fq 'fbg_binder_wakeup_hook(NULL, current, proc->tsk,' drivers/android/binder.c
check frame-boost-binder-restore \
  grep -Fq 'fbg_binder_restore_priority_hook(NULL, in_reply_to, current);' drivers/android/binder.c
check frame-boost-binder-wait \
  grep -Fq 'fbg_binder_wait_for_work_hook(NULL, do_proc_work, thread, proc);' drivers/android/binder.c
check frame-boost-binder-sync \
  grep -Fq 'fbg_sync_txn_recvd_hook(NULL, thread->task, t_from->task);' drivers/android/binder.c

for object in frame_info.o cluster_boost.o frame_boost.o frame_debug.o frame_group.o frame_ioctl.o frame_sysctl.o; do
  check "frame-boost-object-${object}" \
    grep -Fq "obj-y += ${object}" "${frame_boost_dir}/Makefile"
done

check frame-boost-init-sysctl \
  grep -Fq 'fbg_sysctl_init();' "${frame_boost_c}"
check frame-boost-init-ioctl \
  grep -Fq 'frame_ioctl_init();' "${frame_boost_c}"
check frame-boost-proc-parent \
  grep -Fq 'proc_mkdir(FRAMEBOOST_PROC_NODE, NULL)' "${frame_ioctl_c}"
check frame-boost-proc-ctrl \
  grep -Fq 'proc_create("ctrl", S_IRWXUGO' "${frame_ioctl_c}"
check frame-boost-proc-sysctrl \
  grep -Fq 'proc_create("sys_ctrl", (S_IRWXU|S_IRWXG)' "${frame_ioctl_c}"
check frame-boost-proc-info \
  grep -Fq 'proc_create("info", S_IRUGO' "${frame_ioctl_c}"
check frame-boost-cluster-ioctl-decode \
  grep -Fq 'static long fbg_set_task_preferred_cluster(void __user *uarg)' "${frame_ioctl_c}"
check frame-boost-cluster-ioctl-apply \
  grep -Fq 'return __fbg_set_task_preferred_cluster(info.tid, info.cluster_id);' "${frame_ioctl_c}"
check frame-boost-sysctl-enabled \
  grep -Fq '.procname	= "frame_boost_enabled"' "${frame_sysctl_c}"
check frame-boost-sysctl-debug \
  grep -Fq '.procname	= "frame_boost_debug"' "${frame_sysctl_c}"
check frame-boost-h40-frequency-bits \
  grep -Fq '#define SCHED_CPUFREQ_DEF_FRAMEBOOST    (1U << 10)' "${frame_boost_dir}/frame_group.h"
check frame-boost-h40-walt-handoff \
  grep -Fq '#define FBG_CPUFREQ_UPDATE_FLAGS(flags) ((flags) | SCHED_CPUFREQ_WALT)' "${frame_group_c}"
check frame-boost-h40-topology \
  grep -Fq 'cpuid_topo->cluster_id' "${frame_group_c}"

cat <<EOF
result=PASS
proc_iomem=core-4.14
sched_assist_im_flag=task-backed
task_ux_state=per-thread-registered
audio_sched_assist=task-boost-and-enqueue-hook
cpu_jank_control_plane=h40-live-sampling
frame_boost_control_plane=task-group-walt-ioctl-sysctl
EOF
