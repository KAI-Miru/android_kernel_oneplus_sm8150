#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0
#
# Source-level Android 14 ColorOS proc-ABI audit for Miru H.40 Stage 9.
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
sched_assist_slide_c="${sched_assist_dir}/sched_assist_slide.c"
sched_info_c="${sched_info_dir}/oplus_sched_info.c"
tasktrack_c="${sched_info_dir}/tasktrack.c"
cpu_jank_base_c="${sched_info_dir}/osi_base.c"
cpu_jank_cpuload_c="${sched_info_dir}/osi_cpuload.c"
cpu_jank_freq_c="${sched_info_dir}/osi_freq.c"
cpu_jank_loadindicator_c="${sched_info_dir}/osi_loadindicator.c"
cpu_jank_onlinecpu_c="${sched_info_dir}/osi_onlinecpu.c"
cpu_jank_topology_c="${sched_info_dir}/osi_topology.c"
cpu_jank_version_c="${sched_info_dir}/osi_version.c"
frame_boost_dir="${vendor_root}/oplus/kernel/oplus_performance/frame_boost"
frame_boost_c="${frame_boost_dir}/frame_boost.c"
frame_group_c="${frame_boost_dir}/frame_group.c"
frame_ioctl_c="${frame_boost_dir}/frame_ioctl.c"
frame_sysctl_c="${frame_boost_dir}/frame_sysctl.c"
task_cpustats_c="fs/proc/task_cpustats.c"
task_cpustats_h="${vendor_root}/oplus/kernel/oplus_performance/task_cpustats/task_cpustats.h"
task_sched_info_c="fs/proc/task_sched_info.c"
task_sched_info_h="include/linux/task_sched_info.h"
proactive_compact_c="fs/proc/oplus_proactive_compact.c"
storage_log_c="fs/proc/oplus_storage_log.c"

check() {
  local label="$1"
  shift
  if ! "$@"; then
    echo "FAIL: ${label}" >&2
    exit 1
  fi
  echo "PASS: ${label}"
}

check_absent() {
  local label="$1"
  shift
  if "$@"; then
    echo "FAIL: ${label}" >&2
    exit 1
  fi
  echo "PASS: ${label}"
}

check kernel-root test -f Makefile
check kernel-config test -f "${config}"
check vendor-root test -d "${vendor_root}"
check sched-assist-source test -f "${sched_assist_c}"
check sched-assist-slide-source test -f "${sched_assist_slide_c}"
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

# Task CPU statistics: this is the functional ColorOS 14 tick producer and
# five-second reporter, not merely the userspace-visible enable node.
check task-cpustats-source test -f "${task_cpustats_c}"
check task-cpustats-header test -f "${task_cpustats_h}"
check task-cpustats-feature-macro \
  grep -Fq -- '-DOPLUS_FEATURE_TASK_CPUSTATS' Makefile
check task-cpustats-kconfig \
  grep -Fq 'config OPLUS_CTP' fs/proc/Kconfig
check task-cpustats-config-enabled \
  grep -Fxq 'CONFIG_OPLUS_CTP=y' "${config}"
check task-cpustats-kbuild \
  grep -Fq 'proc-$(CONFIG_OPLUS_CTP) += task_cpustats.o' fs/proc/Makefile
check task-cpustats-header-symlink test -L include/linux/task_cpustats.h
check task-cpustats-header-target \
  test "$(readlink include/linux/task_cpustats.h)" = '../../../../vendor/oplus/kernel/oplus_performance/task_cpustats/task_cpustats.h'
check task-cpustats-producer-declaration \
  grep -Fq 'extern void account_task_time(struct task_struct *p, unsigned int ticks,' "${task_cpustats_h}"
check task-cpustats-sysctl-include \
  grep -Fq '#include <linux/task_cpustats.h>' kernel/sysctl.c
check task-cpustats-sysctl-node \
  grep -Fq '.procname	= "task_cpustats_enable"' kernel/sysctl.c
check task-cpustats-sysctl-storage \
  grep -Fq '.data		= &sysctl_task_cpustats_enable' kernel/sysctl.c
check task-cpustats-sysctl-mode \
  grep -Fq '.mode		= 0666' kernel/sysctl.c
check task-cpustats-sysctl-range-min \
  grep -Fq '.extra1		= &zero' kernel/sysctl.c
check task-cpustats-sysctl-range-max \
  grep -Fq '.extra2		= &one' kernel/sysctl.c
check task-cpustats-four-tick-hooks \
  test "$(grep -Fc 'account_task_time(p, ticks,' kernel/sched/cputime.c)" -eq 4
check task-cpustats-disabled-fastpath \
  grep -Fq 'if (!READ_ONCE(sysctl_task_cpustats_enable))' "${task_cpustats_c}"
check task-cpustats-percpu-ring \
  grep -Fq 'DEFINE_PER_CPU(struct kernel_task_cpustat, ktask_cpustat);' "${task_cpustats_c}"
check task-cpustats-ring-window \
  grep -Fq 'MAX_CTP_WINDOW' "${task_cpustats_h}"
check task-cpustats-five-second-report \
  grep -Fq '#define CTP_WINDOW_SZ	5' "${task_cpustats_c}"
check task-cpustats-race-safe-record \
  grep -Fq 'guard->seq[idx]' "${task_cpustats_c}"
check task-cpustats-serialized-snapshot \
  grep -Fq 'DEFINE_SEMAPHORE(task_cpustats_snapshot_sem)' "${task_cpustats_c}"
check task-cpustats-static-aggregate \
  grep -Fq 'static struct acct_cpustat cpustats[MAX_PID];' "${task_cpustats_c}"
check task-cpustats-donor-width-output \
  grep -Fq 'unsigned int pwr;' "${task_cpustats_c}"
check_absent task-cpustats-no-vmalloc-churn \
  grep -Fq 'vzalloc' "${task_cpustats_c}"
check task-cpustats-h40-energy-header \
  grep -Fq '#include <linux/sched/energy.h>' "${task_cpustats_c}"
check task-cpustats-h40-energy-table \
  grep -Fq 'sge_array[cpu][SD_LEVEL0]' "${task_cpustats_c}"
check task-cpustats-exact-frequency \
  grep -Fq 'if (state->frequency == freq)' "${task_cpustats_c}"
check_absent task-cpustats-no-nearest-frequency-fabrication \
  grep -Fq 'best_delta' "${task_cpustats_c}"
check task-cpustats-lockless-tick-frequency \
  grep -Fq 'policy ? READ_ONCE(policy->cur) : 0' "${task_cpustats_c}"
check task-cpustats-donor-jiffy-conversion \
  grep -Fq 'nsecs_to_jiffies(TICK_NSEC)' "${task_cpustats_c}"
check task-cpustats-frequency-table \
  grep -Fq 'cpufreq_for_each_valid_entry' "${task_cpustats_c}"
check_absent task-cpustats-no-generic-energy-model \
  grep -Fq '#include <linux/energy_model.h>' "${task_cpustats_c}"
check_absent task-cpustats-no-em-cpu-get \
  grep -Fq 'em_cpu_get' "${task_cpustats_c}"
check task-cpustats-policy-lifetime \
  grep -Fq 'cpufreq_cpu_put(policy);' "${task_cpustats_c}"
check task-cpustats-proc-create-unwind \
  grep -Fq 'remove_proc_entry("sgefreqinfo", NULL);' "${task_cpustats_c}"
check_absent task-cpustats-no-log-spam \
  grep -Fq 'pr_err' "${task_cpustats_c}"
check_absent task-cpustats-no-trace-printk \
  grep -Fq 'trace_printk' "${task_cpustats_c}"

for node in task_cpustats sgeinfo sgefreqinfo; do
  check "task-cpustats-node-${node}" \
    grep -Fq "proc_create(\"${node}\", 0" "${task_cpustats_c}"
done

# Task scheduler telemetry is the complete ColorOS control plane and event
# producer.  Stage 9A intentionally excludes only the frequency and CPU
# isolation producer hooks added by Stage 9B.
check task-sched-info-source test -f "${task_sched_info_c}"
check task-sched-info-header test -f "${task_sched_info_h}"
check task-sched-info-kconfig grep -Fq 'config OPLUS_SCHED' fs/proc/Kconfig
check task-sched-info-config-enabled \
  grep -Fxq 'CONFIG_OPLUS_SCHED=y' "${config}"
check_absent task-sched-info-no-utils-monitor \
  grep -Eq '^CONFIG_UTILS_MONITOR=[ym]$' "${config}"
check task-sched-info-kbuild \
  grep -Fq 'obj-$(CONFIG_OPLUS_SCHED) += task_sched_info.o' fs/proc/Makefile
check task-sched-info-enable-default-off \
  grep -Fq 'static unsigned int task_sched_info_enable;' "${task_sched_info_c}"
check task-sched-info-ring-lock \
  grep -Fq 'DEFINE_RAW_SPINLOCK(task_sched_ring_lock)' "${task_sched_info_c}"
check task-sched-info-ring-enable-recheck \
  grep -Fq 'if (!READ_ONCE(task_sched_info_enable))' "${task_sched_info_c}"
check task-sched-info-private-snapshot \
  grep -Fq 'struct task_sched_snapshot' "${task_sched_info_c}"
check task-sched-info-notify-atomic \
  grep -Fq 'atomic_t notify_pending' "${task_sched_info_c}"
check task-sched-info-uevent-action \
  grep -Fq '"SCHEDACTION=uevent"' "${task_sched_info_c}"
check task-sched-info-uevent-sequence \
  grep -Fq '"SCHEDNUM=%u"' "${task_sched_info_c}"
check task-sched-info-module-control \
  grep -Fq 'module_param_named(sched_info_ctrl, sched_info_ctrl, bool, 0644);' "${task_sched_info_c}"
check task-sched-info-task-wake-field \
  grep -Fq 'wake_tid;' include/linux/sched.h
check task-sched-info-task-runtime-field \
  grep -Fq 'running_start_time;' include/linux/sched.h
check task-sched-info-fork-wake-reset \
  grep -Fq 'p->wake_tid = 0;' kernel/fork.c
check task-sched-info-fork-runtime-reset \
  grep -Fq 'p->running_start_time = 0;' kernel/fork.c
check task-sched-info-target-discovery \
  grep -Fq 'get_target_thread_pid(tsk);' fs/exec.c
check task-sched-info-enable-pid-scan \
  grep -Fq 'for_each_process_thread(group, task)' "${task_sched_info_c}"
check task-sched-info-forces-schedstats \
  grep -Fq 'force_schedstat_enabled();' "${task_sched_info_c}"
check task-sched-info-wake-hooks \
  test "$(grep -Fc 'update_wake_tid(' kernel/sched/core.c)" -eq 3
check task-sched-info-switch-runtime-hook \
  test "$(grep -Fc 'update_running_start_time(prev, next);' kernel/sched/core.c)" -eq 1
check task-sched-info-runnable-hook \
  test "$(grep -Fc 'task_sched_info_runnable' kernel/sched/fair.c)" -eq 1
check task-sched-info-sleep-hook \
  test "$(grep -Fc 'task_sched_info_S' kernel/sched/fair.c)" -eq 1
check task-sched-info-io-hook \
  test "$(grep -Fc 'task_sched_info_IO' kernel/sched/fair.c)" -eq 1
check task-sched-info-dstate-hook \
  test "$(grep -Fc 'task_sched_info_D' kernel/sched/fair.c)" -eq 1
check task-sched-info-direct-notify \
  grep -Fq 'sched_action_trig();' "${task_sched_info_c}"
check task-sched-info-notify-irq-work \
  grep -Fq 'irq_work_queue(&sched_notify_irq_work);' "${task_sched_info_c}"
check task-sched-info-notify-rate-limit \
  grep -Fq '#define TASK_SCHED_NOTIFY_MIN_MS' "${task_sched_info_c}"
check task-sched-info-notify-delayed-work \
  grep -Fq 'INIT_DELAYED_WORK(&sched_detect_work' "${task_sched_info_c}"
check_absent task-sched-info-no-direct-notify-work \
  grep -Fq 'schedule_work(&sched_detect_work);' "${task_sched_info_c}"
check_absent task-sched-info-no-unbounded-uevent-loop \
  grep -Fq 'while (atomic_xchg(&notify_pending' "${task_sched_info_c}"
check task-sched-info-deferred-backtrace \
  grep -Fq 'task_sched_queue_backtrace(p);' "${task_sched_info_c}"
check task-sched-info-backtrace-work \
  grep -Fq 'INIT_WORK(&task_sched_backtrace_work' "${task_sched_info_c}"
check task-sched-info-threshold-floor \
  grep -Fq 'TASK_SCHED_THRESHOLD_MIN_NS' "${task_sched_info_c}"
check task-sched-info-diagnostic-counters \
  grep -Fq 'proc_create("sched_stats", 0444' "${task_sched_info_c}"
check task-sched-info-frequency-declaration \
  grep -Fq 'void update_freq_info(struct cpufreq_policy *policy);' "${task_sched_info_h}"
check task-sched-info-limit-declaration \
  grep -Fq 'void update_freq_limit_info(struct cpufreq_policy *policy);' "${task_sched_info_h}"
check task-sched-info-isolate-declaration \
  grep -Fq 'void update_cpu_isolate_info(int cpu, u64 type);' "${task_sched_info_h}"
check task-sched-info-frequency-definition \
  grep -Fq 'void update_freq_info(struct cpufreq_policy *policy)' "${task_sched_info_c}"
check task-sched-info-limit-definition \
  grep -Fq 'void update_freq_limit_info(struct cpufreq_policy *policy)' "${task_sched_info_c}"
check task-sched-info-isolate-definition \
  grep -Fq 'void update_cpu_isolate_info(int cpu, u64 type)' "${task_sched_info_c}"
check task-sched-info-frequency-call \
  test "$(grep -Fc 'update_freq_info(policy);' drivers/cpufreq/cpufreq.c)" -eq 1
check task-sched-info-limit-call \
  test "$(grep -Fc 'update_freq_limit_info(policy);' drivers/cpufreq/cpufreq.c)" -eq 1
check task-sched-info-frequency-after-current \
  awk '/policy->cur = freqs->new;/{assignment=NR} /update_freq_info\(policy\);/{call=NR} END{exit !(assignment && call > assignment && call - assignment <= 4)}' drivers/cpufreq/cpufreq.c
check task-sched-info-limit-after-policy \
  awk '/policy->max = new_policy->max;/{assignment=NR} /update_freq_limit_info\(policy\);/{call=NR} END{exit !(assignment && call > assignment && call - assignment <= 4)}' drivers/cpufreq/cpufreq.c
check task-sched-info-isolate-call \
  test "$(grep -Fc 'update_cpu_isolate_info(cpu, cpu_isolate);' kernel/sched/core.c)" -eq 1
check task-sched-info-unisolate-call \
  test "$(grep -Fc 'update_cpu_isolate_info(cpu, cpu_unisolate);' kernel/sched/core.c)" -eq 1
check task-sched-info-isolate-success-only \
  awk '/^int sched_isolate_cpu\(int cpu\)/{inside=1} inside && /update_cpu_isolate_info\(cpu, cpu_isolate\);/{seen=1} inside && /^out:/{out=1; exit} END{exit !(seen && out)}' kernel/sched/core.c
check task-sched-info-unisolate-success-only \
  awk '/^int sched_unisolate_cpu_unlocked\(int cpu\)/{inside=1} inside && /update_cpu_isolate_info\(cpu, cpu_unisolate\);/{seen=1} inside && /^out:/{out=1; exit} END{exit !(seen && out)}' kernel/sched/core.c
check task-sched-info-frequency-disabled-fastpath \
  grep -Fq 'if (!READ_ONCE(task_sched_info_enable) || !policy)' "${task_sched_info_c}"
check task-sched-info-frequency-state-reset \
  grep -Fq '[0 ... TASK_SCHED_CPU_COUNT - 1] = ~0U' "${task_sched_info_c}"
check task-sched-info-frequency-limit-pack \
  grep -Fq '((u64)min & 0x00ffffffULL)' "${task_sched_info_c}"
check task-sched-info-isolate-pack \
  grep -Fq '(type & 0xffULL)' "${task_sched_info_c}"
check_absent task-sched-info-no-global-reader-snapshot \
  grep -Fq 'static u64 datainfo' "${task_sched_info_c}"
check_absent task-sched-info-no-raw-address-output \
  grep -Fq '%px' "${task_sched_info_c}"
check_absent task-sched-info-no-trace-printk \
  grep -Fq 'trace_printk' "${task_sched_info_c}"

for node in pids_set sched_buffer task_sched_info_enable sched_info_threshold d_convert; do
  check "task-sched-info-node-${node}" \
    grep -Fq "proc_create(\"${node}\", 0666" "${task_sched_info_c}"
done

# A14 9R ledger batch 1 contains only isolated, hardware-independent ABIs.
check proactive-compact-source test -f "${proactive_compact_c}"
check proactive-compact-kconfig \
  grep -Fq 'config OPLUS_PROACTIVE_COMPACT' fs/proc/Kconfig
check proactive-compact-config-enabled \
  grep -Fxq 'CONFIG_OPLUS_PROACTIVE_COMPACT=y' "${config}"
check proactive-compact-kbuild \
  grep -Fq 'obj-$(CONFIG_OPLUS_PROACTIVE_COMPACT) += oplus_proactive_compact.o' fs/proc/Makefile
check proactive-compact-node \
  grep -Fq 'proc_create("fragmentation_index", 0666' "${proactive_compact_c}"
check proactive-compact-no-trigger \
  grep -Fq 'does not initiate compaction' fs/proc/Kconfig
check_absent proactive-compact-no-compact-node \
  grep -Fq 'compact_node' "${proactive_compact_c}"

check storage-log-source test -f "${storage_log_c}"
check storage-log-kconfig \
  grep -Fq 'config OPLUS_STORAGE_LOG' fs/proc/Kconfig
check storage-log-config-enabled \
  grep -Fxq 'CONFIG_OPLUS_STORAGE_LOG=y' "${config}"
check storage-log-kbuild \
  grep -Fq 'obj-$(CONFIG_OPLUS_STORAGE_LOG) += oplus_storage_log.o' fs/proc/Makefile
check storage-log-node \
  grep -Fq 'proc_create("buf_log", 0666' "${storage_log_c}"
check storage-log-bound \
  grep -Fq '#define OPLUS_STORAGE_LOG_SIZE' "${storage_log_c}"
check storage-log-export \
  grep -Fq 'EXPORT_SYMBOL_GPL(pr_storage);' "${storage_log_c}"

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

# Task tracking is a real scheduler telemetry backend.  It must preserve the
# companion task_track ABI, account time in the reference window layout, and
# keep the tracepoint hook out of the normal scheduling path until userspace
# explicitly enables tracking for a selected PID.
check cpu-jank-tasktrack-source test -f "${tasktrack_c}"
check cpu-jank-tasktrack-kbuild \
  grep -Fq 'oplus_schedinfo-y := oplus_sched_info.o tasktrack.o \' "${sched_info_dir}/Makefile"
check cpu-jank-tasktrack-init \
  grep -Fq 'ret = tasktrack_proc_init(cpu_jank_dir);' "${sched_info_c}"
check cpu-jank-tasktrack-exit \
  grep -Fq 'tasktrack_deinit();' "${sched_info_c}"
check cpu-jank-tasktrack-window-layout \
  grep -Fq '#define TASKTRACK_WINDOW_COUNT' "${tasktrack_c}"
check cpu-jank-tasktrack-window-duration \
  grep -Fq '#define TASKTRACK_WINDOW_NS' "${tasktrack_c}"
check cpu-jank-tasktrack-explicit-gate \
  grep -Fq 'tasktrack_enabled && tasktrack_has_entries_locked()' "${tasktrack_c}"
check cpu-jank-tasktrack-fastpath-gate \
  grep -Fq 'if (!READ_ONCE(tasktrack_active))' "${tasktrack_c}"
check cpu-jank-tasktrack-untracked-fastpath \
  grep -Fq 'if (!prev_tracked && !next_tracked)' "${tasktrack_c}"
check cpu-jank-tasktrack-fast-pid-set \
  grep -Fq 'tasktrack_pid_maybe_tracked' "${tasktrack_c}"
check cpu-jank-tasktrack-sched-switch \
  grep -Fq 'register_trace_sched_switch(tasktrack_sched_switch, NULL)' "${tasktrack_c}"
check cpu-jank-tasktrack-sched-waking \
  grep -Fq 'register_trace_sched_waking(tasktrack_sched_waking, NULL)' "${tasktrack_c}"
check_absent cpu-jank-tasktrack-no-trace-printk \
  grep -Fq 'trace_printk' "${tasktrack_c}"

for node in task_track task_track_enable; do
  check "cpu-jank-tasktrack-node-${node}" \
    grep -Fq "proc_create(\"${node}\", 0666" "${tasktrack_c}"
done

# CPU-jank reporting is a functional donor-derived telemetry batch.  It has
# one bounded tick producer and cpufreq counters, but no stack walk, uevent,
# workqueue, futex, Binder or donor busy-loop debug producer.
for source in \
  "${cpu_jank_base_c}" \
  "${cpu_jank_cpuload_c}" \
  "${cpu_jank_freq_c}" \
  "${cpu_jank_loadindicator_c}" \
  "${cpu_jank_onlinecpu_c}" \
  "${cpu_jank_topology_c}" \
  "${cpu_jank_version_c}"; do
  check "cpu-jank-reporting-source-$(basename "${source}")" test -f "${source}"
done

for object in osi_base.o osi_topology.o osi_onlinecpu.o osi_freq.o \
  osi_cpuload.o osi_loadindicator.o osi_version.o; do
  check "cpu-jank-reporting-object-${object}" \
    grep -Fq "${object}" "${sched_info_dir}/Makefile"
done

check cpu-jank-reporting-header test -f include/linux/oplus_jankinfo.h
check cpu-jank-reporting-tick-hook \
  grep -Fq 'jankinfo_update_time_info(rq, p, TICK_NSEC);' kernel/sched/cputime.c
check cpu-jank-reporting-init-gate \
  grep -Fq 'if (unlikely(jankinfo_init == false))' "${cpu_jank_cpuload_c}"
check cpu-jank-reporting-cpufreq-hooks test \
  "$(grep -Fc 'jankinfo_update_freq_reach_limit_count(policy' drivers/cpufreq/cpufreq.c)" -eq 3
check cpu-jank-reporting-hotthread-grammar \
  grep -Fq 'seq_puts(m, "- - -");' "${cpu_jank_cpuload_c}"
check_absent cpu-jank-reporting-no-hotthread-producer \
  grep -Fq 'jank_hotthread_update_tick' "${cpu_jank_cpuload_c}"
check_absent cpu-jank-reporting-no-stack-capture \
  grep -E 'get_wchan|stack_trace|save_stack' "${cpu_jank_cpuload_c}"
check_absent cpu-jank-reporting-no-workqueue \
  grep -E 'schedule_work|queue_work|schedule_delayed_work' "${cpu_jank_cpuload_c}"
check_absent cpu-jank-reporting-no-uevent \
  grep -Fq 'kobject_uevent' "${cpu_jank_cpuload_c}"

for node in cpu_info cpu_info_sig cpu_load cpu_load32 cpu_load32_scale; do
  check "cpu-jank-reporting-node-${node}" \
    grep -Fq "proc_create(\"${node}\"" "${cpu_jank_cpuload_c}"
done
check cpu-jank-reporting-node-load-indicator \
  grep -Fq 'proc_create("load_indicator"' "${cpu_jank_loadindicator_c}"
check cpu-jank-reporting-node-version \
  grep -Fq 'proc_create("version"' "${cpu_jank_version_c}"
check cpu-jank-reporting-abi-document \
  test -f Documentation/ABI/testing/procfs-oplus-cpu-jank-reporting

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
check frame-boost-rt-include \
  grep -Fq '#include "../tuning/frame_group.h"' kernel/sched/rt.c
check frame-boost-rt-runtime-hook \
  grep -Fq 'fbg_update_rt_util_hook(NULL, curr, delta_exec);' kernel/sched/rt.c
check frame-boost-rt-wakeup-filter \
  grep -Fq 'fbg_rt_task_fits_capacity(task, cpu)' kernel/sched/rt.c
check frame-boost-rt-pull-filter \
  grep -Fq 'fbg_rt_task_fits_capacity(p, this_cpu)' kernel/sched/rt.c
check frame-boost-placement-hook \
  grep -Fq 'set_frame_group_task_to_perfer_cpu(p, &target_cpu)' kernel/sched/fair.c
check frame-boost-migration-hook \
  grep -Fq 'fbg_skip_migration(p, env->src_cpu, env->dst_cpu)' kernel/sched/fair.c
check frame-boost-walt-rotation-filter \
  grep -Fq 'fbg_skip_migration(rq->curr, i, src_cpu)' kernel/sched/fair.c
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
  grep -Fq 'fbg_binder_wait_for_work_hook(NULL, do_proc_work, thread->task);' drivers/android/binder.c
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
check frame-boost-ioctl-abi-header \
  grep -Fq '#include "frame_ioctl.h"' "${frame_ioctl_c}"
check frame-boost-ioctl-uaccess-header \
  grep -Fq '#include <linux/uaccess.h>' "${frame_ioctl_c}"
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
check frame-boost-h40-im-sched-header \
  grep -Fq '#include <linux/sched.h>' "${frame_ioctl_c}"
check frame-boost-h40-im-state-guard \
  grep -Fq '#ifdef OPLUS_FEATURE_SCHED_ASSIST' "${frame_ioctl_c}"
check frame-boost-h40-im-state \
  grep -Fq 'return task->ux_im_flag;' "${frame_ioctl_c}"
check frame-boost-sysctl-enabled \
  grep -Fq '.procname	= "frame_boost_enabled"' "${frame_sysctl_c}"
check frame-boost-sysctl-debug \
  grep -Fq '.procname	= "frame_boost_debug"' "${frame_sysctl_c}"
check frame-boost-shared-boost-header \
  grep -Fq '#include <linux/sched.h>' "${frame_sysctl_c}"
check frame-boost-shared-input-owner \
  grep -Fq 'int sysctl_input_boost_enabled = 0;' "${sched_assist_c}"
check frame-boost-shared-slide-owner \
  grep -Fq 'int sysctl_slide_boost_enabled = 0;' "${sched_assist_slide_c}"
check_absent frame-boost-duplicate-input-state \
  grep -Fq 'unsigned int sysctl_input_boost_enabled;' "${frame_sysctl_c}"
check_absent frame-boost-duplicate-slide-state \
  grep -Fq 'unsigned int sysctl_slide_boost_enabled;' "${frame_sysctl_c}"
check_absent frame-boost-duplicate-input-export \
  grep -Fq 'EXPORT_SYMBOL(sysctl_input_boost_enabled);' "${frame_sysctl_c}"
check_absent frame-boost-duplicate-slide-export \
  grep -Fq 'EXPORT_SYMBOL(sysctl_slide_boost_enabled);' "${frame_sysctl_c}"
check frame-boost-h40-frequency-bits \
  grep -Fq '#define SCHED_CPUFREQ_DEF_FRAMEBOOST    (1U << 10)' "${frame_boost_dir}/frame_group.h"
check_absent frame-boost-h40-private-sched-header \
  grep -Fq '#include <../kernel/sched/sched.h>' "${frame_boost_dir}/frame_group.h"
check frame-boost-h40-version-api-header \
  grep -Fq '#include <linux/version.h>' "${frame_boost_dir}/frame_group.h"
check frame-boost-h40-capacity-api-header \
  grep -Fq '#include <linux/sched/topology.h>' "${frame_boost_dir}/frame_info.c"
check frame-boost-cpu-util-helper-declaration \
  grep -Fq 'unsigned long cpu_util_without(int cpu, struct task_struct *p);' kernel/sched/sched.h
check frame-boost-cpu-util-helper-definition \
  grep -Fq 'unsigned long cpu_util_without(int cpu, struct task_struct *p)' kernel/sched/fair.c
check_absent frame-boost-duplicate-cpu-util-helper \
  grep -Fq 'unsigned long cpu_util_without(int cpu, struct task_struct *p)' "${frame_group_c}"
check frame-boost-native-cpu-util-helper-call \
  grep -Fq 'cpu_util_without(iter_cpu, p)' "${frame_group_c}"
check frame-boost-h40-walt-handoff \
  grep -Fq '#define FBG_CPUFREQ_UPDATE_FLAGS(flags) ((flags) | SCHED_CPUFREQ_WALT)' "${frame_group_c}"
check frame-boost-h40-topology \
  grep -Fq 'cpuid_topo->cluster_id' "${frame_group_c}"
check frame-boost-h40-idle-adapter \
  grep -Fq 'static inline bool fbg_available_idle_cpu(int cpu)' "${frame_boost_dir}/cluster_boost.c"
check frame-boost-h40-idle-api \
  grep -Fq 'return idle_cpu(cpu);' "${frame_boost_dir}/cluster_boost.c"
check frame-boost-h40-group-binder-task-boundary \
  grep -Fq 'struct task_struct *tsk);' "${frame_boost_dir}/frame_group.h"
check_absent frame-boost-h40-group-private-binder-header \
  grep -Fq '#include <../drivers/android/binder_internal.h>' "${frame_group_c}"
check_absent frame-boost-h40-group-possible-ux \
  grep -Fq 'POSSIBLE_UX_MASK' "${frame_group_c}"
check frame-boost-h40-group-rt-adapter \
  grep -Fq 'static inline bool fbg_rt_rq_is_runnable' "${frame_group_c}"
check frame-boost-h40-group-rt-runnable-state \
  grep -Fq 'return rt_rq->rt_nr_running && !rt_rq->rt_throttled;' "${frame_group_c}"
check frame-boost-h40-group-idle-adapter \
  grep -Fq 'static inline bool fbg_available_idle_cpu(int cpu)' "${frame_group_c}"
check frame-boost-h40-group-idle-api \
  grep -Fq 'return idle_cpu(cpu);' "${frame_group_c}"

cat <<EOF
result=PASS
proc_iomem=core-4.14
sched_assist_im_flag=task-backed
task_ux_state=per-thread-registered
audio_sched_assist=task-boost-and-enqueue-hook
cpu_jank_control_plane=h40-live-sampling
cpu_jank_tasktrack=on-demand-sched-tracepoint
cpu_jank_reporting=donor-windowed-cputime-frequency-cgroup
task_cpustats=real-tick-accounting
task_sched_info=full-scheduler-frequency-isolation-telemetry
frame_boost_control_plane=task-group-walt-ioctl-sysctl
EOF
