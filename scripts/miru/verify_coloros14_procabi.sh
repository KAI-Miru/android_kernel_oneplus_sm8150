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
sched_assist_audio_c="${sched_assist_dir}/sched_assist_audio.c"
sched_assist_audio_h="${sched_assist_dir}/sched_assist_audio.h"
sched_assist_status_h="${sched_assist_dir}/sched_assist_status.h"
sched_assist_fork_h="${sched_assist_dir}/sched_assist_fork.h"
eas_opt_dir="${sched_assist_dir}/eas_opt"
eas_opt_c="${eas_opt_dir}/eas_opt.c"
eas_cap_c="${eas_opt_dir}/oplus_cap.c"
eas_iowait_c="${eas_opt_dir}/oplus_iowait.c"
sched_info_c="${sched_info_dir}/oplus_sched_info.c"
tasktrack_c="${sched_info_dir}/tasktrack.c"
cpu_jank_base_c="${sched_info_dir}/osi_base.c"
cpu_jank_enable_c="${sched_info_dir}/osi_enable.c"
cpu_jank_cpuload_c="${sched_info_dir}/osi_cpuload.c"
cpu_jank_freq_c="${sched_info_dir}/osi_freq.c"
cpu_jank_loadindicator_c="${sched_info_dir}/osi_loadindicator.c"
cpu_jank_onlinecpu_c="${sched_info_dir}/osi_onlinecpu.c"
cpu_jank_topology_c="${sched_info_dir}/osi_topology.c"
cpu_jank_hotthread_c="${sched_info_dir}/osi_hotthread.c"
cpu_jank_version_c="${sched_info_dir}/osi_version.c"
frame_boost_dir="${vendor_root}/oplus/kernel/oplus_performance/frame_boost"
frame_boost_c="${frame_boost_dir}/frame_boost.c"
frame_group_c="${frame_boost_dir}/frame_group.c"
frame_ioctl_c="${frame_boost_dir}/frame_ioctl.c"
frame_sysctl_c="${frame_boost_dir}/frame_sysctl.c"
ua_ioctl_common_c="${frame_boost_dir}/ua_ioctl_common.c"
ua_ioctl_common_h="${frame_boost_dir}/ua_ioctl_common.h"
touch_ioctl_c="${frame_boost_dir}/touch_ioctl.c"
task_cpustats_c="fs/proc/task_cpustats.c"
task_cpustats_h="${vendor_root}/oplus/kernel/oplus_performance/task_cpustats/task_cpustats.h"
task_sched_info_c="fs/proc/task_sched_info.c"
task_sched_info_h="include/linux/task_sched_info.h"
proactive_compact_c="fs/proc/oplus_proactive_compact.c"
storage_log_c="fs/proc/oplus_storage_log.c"
healthinfo_dir="${vendor_root}/oplus/kernel/oplus_performance/oplus_healthinfo"
healthinfo_main_c="${healthinfo_dir}/main/oplus_healthinfo.c"
healthinfo_main_h="${healthinfo_dir}/main/oplus_healthinfo.h"
blk_monitor_c="${healthinfo_dir}/main/blk_monitor.c"
healthinfo_main_kconfig="${healthinfo_dir}/main/Kconfig"
healthinfo_main_makefile="${healthinfo_dir}/main/Makefile"
athena_memory_c="${healthinfo_dir}/mm/allocator_usage.c"
athena_memory_kconfig="${healthinfo_dir}/mm/Kconfig"
athena_memory_makefile="${healthinfo_dir}/mm/Makefile"
locking_dir="${sched_assist_dir}/sync"
locking_main_c="${locking_dir}/locking_main.c"
locking_main_h="${locking_dir}/locking_main.h"
locking_sysfs_c="${locking_dir}/sysfs.c"
locking_mutex_c="${locking_dir}/mutex.c"
locking_rwsem_c="${locking_dir}/rwsem.c"
locking_futex_c="${locking_dir}/futex.c"
locking_stat_c="${locking_dir}/kern_lock_stat.c"
game_opt_dir="drivers/soc/oplus/game_opt"
game_opt_ctrl_c="${game_opt_dir}/game_ctrl.c"
game_opt_cpu_load_c="${game_opt_dir}/cpu_load.c"
game_opt_cpufreq_limits_c="${game_opt_dir}/cpufreq_limits.c"
game_opt_task_util_c="${game_opt_dir}/task_util.c"
game_opt_rt_info_c="${game_opt_dir}/rt_info.c"
game_opt_dstate_c="${game_opt_dir}/dstate_dump.c"
game_opt_header="include/linux/oplus_game_opt.h"
hybridswap_dir="drivers/block/zram/hybridswap"
hybridswap_main_c="${hybridswap_dir}/hybridswap_main.c"
hybridswap_swapd_c="${hybridswap_dir}/hybridswap_swapd.c"
hybridswap_core_c="${hybridswap_dir}/hybridswap_core.c"
zram_c="drivers/block/zram/zram_drv.c"
ufs_c="drivers/scsi/ufs/ufshcd.c"
ufs_h="drivers/scsi/ufs/ufshcd.h"
runtime_ufs_c="${vendor_root}/oplus/kernel_4.14/ufs/ufshcd.c"
runtime_ufs_h="${vendor_root}/oplus/kernel_4.14/ufs/ufshcd.h"
ddr_stats_c="drivers/soc/qcom/ddr_stats.c"
uxio_first_dir="${vendor_root}/oplus/kernel/oplus_performance/oplus_uxio_first"
uxio_first_c="${uxio_first_dir}/oplus_uxio_first_opt.c"
uxio_first_h="${uxio_first_dir}/oplus_uxio_first_opt.h"
uxio_high_prio_c="${uxio_first_dir}/oplus_high_prio_task.c"
im_dir="${vendor_root}/oplus/kernel/oplus_performance/im"
im_c="${im_dir}/im.c"
im_h="${im_dir}/im.h"
tpp_dir="${vendor_root}/oplus/kernel/oplus_performance/tpp"
tpp_c="${tpp_dir}/tpp.c"
tpp_h="${tpp_dir}/tpp.h"
sigkill_dir="${vendor_root}/oplus/kernel/oplus_performance/sigkill_diagnosis"
sigkill_c="${sigkill_dir}/sigkill_diagnosis.c"
sigkill_h="${sigkill_dir}/sigkill_diagnosis.h"

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
check frame-boost-ua-source test -f "${ua_ioctl_common_c}"
check frame-boost-ua-header test -f "${ua_ioctl_common_h}"
check frame-boost-touch-source test -f "${touch_ioctl_c}"

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
  grep -Fq 'obj-$(CONFIG_OPLUS_PROACTIVE_COMPACT) += oplus_bsp_proactive_compact.o' fs/proc/Makefile
check proactive-compact-node \
  grep -Fq 'proc_create("fragmentation_index", 0666' "${proactive_compact_c}"
check proactive-compact-no-trigger \
  grep -Fq 'does not initiate compaction' fs/proc/Kconfig
check_absent proactive-compact-no-compact-node \
  grep -Fq 'compact_node' "${proactive_compact_c}"
for parameter in compaction_hpage_order compaction_proactiveness; do
  check "proactive-compact-parameter-${parameter}" \
    grep -Fq "module_param_cb(${parameter}," "${proactive_compact_c}"
done

# Wave 10 restores the enabled 9R EAS/iowait control plane and wires each
# control into the native 4.14 scheduling/cpufreq path.
for option in OPLUS_FEATURE_EAS_OPT OPLUS_FEATURE_VT_CAP OPLUS_CPUFREQ_IOWAIT_PROTECT; do
  check "eas-config-${option}" grep -Fxq "CONFIG_${option}=y" "${config}"
done
check eas-kconfig-source \
  grep -Fq 'source "kernel/sched_assist/Kconfig"' init/Kconfig
check eas-master-source test -f "${eas_opt_c}"
check eas-cap-source test -f "${eas_cap_c}"
check eas-iowait-source test -f "${eas_iowait_c}"
check eas-master-node \
  grep -Fq 'proc_create("eas_opt_enable", 0666' "${eas_opt_c}"
for node in group_adjust_enable oplus_cap_multiple group_adjust util_thresh_percent; do
  check "eas-cap-node-${node}" grep -Fq "proc_create(\"${node}\", 0666" "${eas_cap_c}"
done
for node in iowait_reset_ticks iowait_apply_ticks oplus_iowait_boost_enabled oplus_iowait_skip_min_enabled; do
  check "eas-iowait-node-${node}" grep -Fq "\"${node}\"" "${eas_iowait_c}"
done
check eas-placement-hook grep -Fq 'oplus_eas_task_skip_cpu(p, i)' kernel/sched/fair.c
check eas-vruntime-hook grep -Fq 'oplus_eas_place_entity(cfs_rq, se, initial);' kernel/sched/fair.c
check eas-capacity-hook grep -Fq 'oplus_eas_adjust_capacity(cpu, capacity);' kernel/sched/fair.c
check eas-util-hook grep -Fq 'oplus_eas_adjust_util(sg_cpu->cpu,' kernel/sched/cpufreq_schedutil.c
check eas-iowait-reset-hook grep -Fq 'sysctl_iowait_reset_ticks' kernel/sched/cpufreq_schedutil.c
check eas-iowait-apply-hook grep -Fq 'sysctl_iowait_apply_ticks' kernel/sched/cpufreq_schedutil.c
check sched-assist-boost-kill-param \
  grep -Fq 'module_param_named(boost_kill, boost_kill, uint, 0644);' "${sched_assist_c}"
check sched-assist-boost-kill-hook \
  grep -Fq 'oplus_boost_kill_signal(sig, current, p);' kernel/signal.c

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
check sched-assist-debug-parameter \
  grep -Fq 'module_param_named(debug, param_ux_debug, uint, 0644);' "${sched_assist_c}"
check sched-assist-debug-default-off \
  grep -Fq 'static unsigned int param_ux_debug;' "${sched_assist_c}"
check sched-assist-debug-fastpath-gate \
  grep -Fq 'if (likely(!param_ux_debug))' "${sched_assist_c}"
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

# Wave 19 completes the donor-enabled CPU audio placement path behind the
# existing audio/status control. The default remains donor-correctly off until
# userspace activates the audio scene.
check audio-im-config grep -Fxq 'CONFIG_OPLUS_UX_IM_FLAG=y' "${config}"
check audio-rt-config grep -Fxq 'CONFIG_OPLUS_CPU_AUDIO_PERF=y' "${config}"
check audio-rt-kconfig grep -Fq 'config OPLUS_CPU_AUDIO_PERF' "${sched_assist_dir}/Kconfig"
check audio-rt-header \
  grep -Fq 'oplus_sched_assist_audio_perf_check_exit_latency' "${sched_assist_audio_h}"
check audio-rt-backend \
  grep -Fq 'idle->exit_latency > AUDIO_TASK_IDLE_EXIT_LATENCY' "${sched_assist_audio_c}"
check audio-rt-status-gate \
  grep -Fq 'if (!audio_perf_status_on() || !task_is_audio(task))' "${sched_assist_audio_c}"
check audio-rt-include \
  grep -Fq '#include <linux/sched_assist/sched_assist_audio.h>' kernel/sched/rt.c
check audio-rt-placement-hook \
  grep -Fq 'oplus_sched_assist_audio_perf_check_exit_latency(task,' kernel/sched/rt.c
check audio-rt-donor-threshold \
  grep -Fq '#define AUDIO_TASK_IDLE_EXIT_LATENCY 60' "${sched_assist_audio_c}"
check audio-rt-abi-document \
  test -f Documentation/ABI/testing/procfs-oplus-sched-assist-audio

# Wave 20 completes the donor-enabled small-task audio policy. It samples the
# runnable/sleep/execute cadence only for the userspace-selected audio TGID in
# the camera scene, then gives matching short tasks donor-equivalent buddy and
# wakeup preference.
check audio-small-config \
  grep -Fxq 'CONFIG_OPLUS_FEATURE_AUDIO_OPT=y' "${config}"
check audio-small-kconfig \
  grep -Fq 'config OPLUS_FEATURE_AUDIO_OPT' "${sched_assist_dir}/Kconfig"
check audio-small-status-header test -f "${sched_assist_status_h}"
check audio-small-sample-count \
  grep -Fq '#define TASK_INFO_SAMPLE 4' "${sched_assist_status_h}"
check audio-small-task-field \
  grep -Fq 'struct task_info oplus_task_info;' include/linux/sched.h
check audio-small-fork-reset \
  grep -Fq 'memset(&p->oplus_task_info, 0, sizeof(struct task_info));' "${sched_assist_fork_h}"
check audio-small-tgid-gate \
  grep -Fq 'task->tgid == READ_ONCE(save_audio_tgid)' "${sched_assist_c}"
check audio-small-camera-gate \
  grep -Fq '!sched_assist_scene(SA_CAMERA) || !audio_trace_group(task)' "${sched_assist_c}"
check audio-small-three-of-four \
  grep -Fq '#define AUDIO_SMALL_MATCHES' "${sched_assist_c}"
check audio-small-exec-threshold \
  grep -Fq '#define AUDIO_SMALL_EXEC_NS' "${sched_assist_c}"
check audio-small-four-stat-hooks \
  test "$(grep -Fc 'sched_assist_update_record(' kernel/sched/fair.c)" -eq 4
check audio-small-next-buddy-hook \
  grep -Fq 'sched_assist_pick_next_entity(cfs_rq, &se)' kernel/sched/fair.c
check audio-small-preempt-hook \
  grep -Fq 'if (unlikely(is_small_task(p)))' kernel/sched/fair.c

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
check cpu-jank-passive-enable-source test -f "${cpu_jank_enable_c}"
check cpu-jank-passive-enable-object \
  grep -Fq 'osi_base.o osi_enable.o' "${sched_info_dir}/Makefile"
check cpu-jank-passive-enable-init \
  grep -Fq 'entry = jank_enable_proc_init(cpu_jank_dir);' "${sched_info_c}"
check cpu-jank-passive-enable-node \
  grep -Fq 'proc_create("enable", S_IRUGO | S_IWUGO' "${cpu_jank_enable_c}"
check cpu-jank-passive-enable-default-off \
  grep -Fq 'unsigned int cpu_jank_info_enable;' "${cpu_jank_enable_c}"
check cpu-jank-passive-enable-hardened-input \
  grep -Fq 'if (count >= sizeof(buffer))' "${cpu_jank_enable_c}"
check cpu-jank-passive-osi-debug-init \
  grep -Fq 'ret = osi_base_proc_init(cpu_jank_dir);' "${sched_info_c}"
check cpu-jank-passive-osi-debug-node \
  grep -Fq 'proc_create("osi_debug", S_IRUGO' "${cpu_jank_base_c}"
check cpu-jank-passive-osi-debug-default-off \
  grep -Fq 'int g_osi_debug;' "${cpu_jank_base_c}"
check cpu-jank-passive-controls-document \
  test -f Documentation/ABI/testing/procfs-oplus-cpu-jank-passive-controls

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

# Stage 9I derives the donor's latency and I/O-wait event feeds from the same
# four-PID, explicitly armed tracepoint backend.  Both feeds are static rings.
for node in sched_latency sched_iowait; do
  check "cpu-jank-tasktrack-event-node-${node}" \
    grep -Fq "proc_create(\"${node}\", 0444" "${tasktrack_c}"
done
check cpu-jank-tasktrack-event-bound \
  grep -Fq '#define TASKTRACK_EVENT_COUNT' "${tasktrack_c}"
check cpu-jank-tasktrack-event-threshold \
  grep -Fq '#define TASKTRACK_EVENT_THRESHOLD_NS' "${tasktrack_c}"
check cpu-jank-tasktrack-latency-ring \
  grep -Fq 'tasktrack_latency_events[TASKTRACK_EVENT_COUNT]' "${tasktrack_c}"
check cpu-jank-tasktrack-iowait-ring \
  grep -Fq 'tasktrack_iowait_events[TASKTRACK_EVENT_COUNT]' "${tasktrack_c}"
check cpu-jank-tasktrack-event-read-lock \
  grep -Fq 'DEFINE_MUTEX(tasktrack_event_read_lock)' "${tasktrack_c}"
check cpu-jank-tasktrack-static-snapshot \
  grep -Fq 'tasktrack_event_snapshot[TASKTRACK_EVENT_COUNT]' "${tasktrack_c}"
check cpu-jank-tasktrack-latency-state \
  grep -Fq 'entry->state == TASKTRACK_RUNNABLE' "${tasktrack_c}"
check cpu-jank-tasktrack-iowait-state \
  grep -Fq 'entry->state == TASKTRACK_DISKSLEEP_INIOWAIT' "${tasktrack_c}"
check cpu-jank-tasktrack-native-iowait \
  grep -Fq 'if (task->in_iowait)' "${tasktrack_c}"
check cpu-jank-tasktrack-event-clock \
  grep -Fq 'ktime_get_real_ts64(&event->timestamp);' "${tasktrack_c}"
check cpu-jank-tasktrack-event-grammar \
  grep -Fq '"%d,%llu,%llu.%lu\n"' "${tasktrack_c}"
# Wave 13 restores the donor ux_throttle ABI using a bounded H.40-native
# runtime producer.  It retains the donor budgets and output grammar, but is
# inert unless task_track is explicitly armed for one of its four PID slots.
check cpu-jank-tasktrack-ux-throttle-node \
  grep -Fq 'proc_create("ux_throttle", 0444' "${tasktrack_c}"
check cpu-jank-tasktrack-ux-throttle-bound \
  grep -Fq '#define TASKTRACK_UX_THROTTLE_COUNT' "${tasktrack_c}"
check cpu-jank-tasktrack-ux-throttle-base-budget \
  grep -Fq '#define TASKTRACK_UX_EXEC_SLICE_NS' "${tasktrack_c}"
check cpu-jank-tasktrack-ux-throttle-ring \
  grep -Fq 'tasktrack_ux_throttle_events[TASKTRACK_UX_THROTTLE_COUNT]' "${tasktrack_c}"
check cpu-jank-tasktrack-ux-throttle-static-snapshot \
  grep -Fq 'tasktrack_ux_throttle_snapshot[TASKTRACK_UX_THROTTLE_COUNT]' "${tasktrack_c}"
check cpu-jank-tasktrack-ux-throttle-producer \
  grep -Fq 'void jankinfo_ux_throttle_tick(struct task_struct *task)' "${tasktrack_c}"
check cpu-jank-tasktrack-ux-throttle-runtime \
  grep -Fq 'task->se.sum_exec_runtime' "${tasktrack_c}"
check cpu-jank-tasktrack-ux-throttle-budget \
  grep -Fq 'tasktrack_ux_exec_limit_ns(task)' "${tasktrack_c}"
check cpu-jank-tasktrack-ux-throttle-frequency \
  grep -Fq 'policy = cpufreq_cpu_get(cpu);' "${tasktrack_c}"
check cpu-jank-tasktrack-ux-throttle-unarmed-gate \
  grep -Fq '!READ_ONCE(tasktrack_active)' "${tasktrack_c}"
check cpu-jank-tasktrack-ux-throttle-selected-pid \
  grep -Fq '!tasktrack_pid_maybe_tracked(task->pid)' "${tasktrack_c}"
check cpu-jank-tasktrack-ux-throttle-native-hook \
  grep -Fq 'jankinfo_ux_throttle_tick(curr);' kernel/sched/core.c
check cpu-jank-tasktrack-ux-throttle-abi-document \
  test -f Documentation/ABI/testing/procfs-oplus-cpu-jank-ux-throttle
check_absent cpu-jank-tasktrack-no-binder-futex-hooks \
  grep -E 'binder_wait|futex_sleep' "${tasktrack_c}"
check cpu-jank-tasktrack-latency-abi-document \
  test -f Documentation/ABI/testing/procfs-oplus-cpu-jank-tasktrack-latency

# Stage 9J ports the directly consumed callstack feed without importing the
# donor's Binder/Futex attribution.  It captures
# four native 4.14 stack frames only for a selected PID leaving a non-I/O
# uninterruptible stall of at least 50 ms, into a fixed 64-record ring.
check cpu-jank-tasktrack-callstack-node \
  grep -Fq 'proc_create("callstack", 0444' "${tasktrack_c}"
check cpu-jank-tasktrack-callstack-config \
  grep -Fxq 'CONFIG_STACKTRACE=y' "${config}"
check cpu-jank-tasktrack-callstack-bound \
  grep -Fq '#define TASKTRACK_CALLSTACK_COUNT' "${tasktrack_c}"
check cpu-jank-tasktrack-callstack-depth \
  grep -Fq '#define TASKTRACK_CALLSTACK_DEPTH' "${tasktrack_c}"
check cpu-jank-tasktrack-callstack-threshold \
  grep -Fq '#define TASKTRACK_CALLSTACK_THRESHOLD_NS' "${tasktrack_c}"
check cpu-jank-tasktrack-callstack-ring \
  grep -Fq 'tasktrack_callstacks[TASKTRACK_CALLSTACK_COUNT]' "${tasktrack_c}"
check cpu-jank-tasktrack-callstack-static-snapshot \
  grep -Fq 'tasktrack_callstack_snapshot[TASKTRACK_CALLSTACK_COUNT]' "${tasktrack_c}"
check cpu-jank-tasktrack-callstack-producer \
  grep -Fq 'entry->state == TASKTRACK_DISKSLEEP' "${tasktrack_c}"
check cpu-jank-tasktrack-callstack-capture \
  grep -Fq 'save_stack_trace_tsk(task, &trace);' "${tasktrack_c}"
check cpu-jank-tasktrack-callstack-format \
  grep -Fq '"[%llu.%lu] [%d] ["' "${tasktrack_c}"
check_absent cpu-jank-tasktrack-callstack-no-dynamic-allocation \
  grep -E 'k(m|z)alloc|vmalloc|kvzalloc' "${tasktrack_c}"
check cpu-jank-tasktrack-callstack-abi-document \
  test -f Documentation/ABI/testing/procfs-oplus-cpu-jank-tasktrack-callstack

# Stage 9H exposes OP9R's top_hotthread grammar through a bounded H.40-native
# delayed sampler.  It must remain inert until the existing CPU-jank monitor
# controls enable it and must not add another scheduler-tick hook or allocate
# candidate records from the sampling path.
check cpu-jank-hotthread-source test -f "${cpu_jank_hotthread_c}"
check cpu-jank-hotthread-object \
  grep -Fq 'osi_hotthread.o' "${sched_info_dir}/Makefile"
check cpu-jank-hotthread-init \
  grep -Fq 'ret = osi_hotthread_proc_init(cpu_jank_dir);' "${sched_info_c}"
check cpu-jank-hotthread-exit \
  grep -Fq 'osi_hotthread_proc_deinit(cpu_jank_dir);' "${sched_info_c}"
check cpu-jank-hotthread-node \
  grep -Fq 'proc_create("top_hotthread", 0444' "${cpu_jank_hotthread_c}"
check cpu-jank-hotthread-default-off \
  grep -Fq 'static bool hotthread_enabled;' "${cpu_jank_hotthread_c}"
check cpu-jank-hotthread-disabled-fastpath \
  grep -Fq 'if (!READ_ONCE(hotthread_enabled))' "${cpu_jank_hotthread_c}"
check cpu-jank-hotthread-monitor-gate \
  grep -Fq 'osi_hotthread_set_enabled(monitor_enabled || active_enabled);' "${sched_info_c}"
check cpu-jank-hotthread-static-history \
  grep -Fq 'hotthread_windows[HOTTHREAD_WINDOW_COUNT]' "${cpu_jank_hotthread_c}"
check cpu-jank-hotthread-candidate-bound \
  grep -Fq '#define HOTTHREAD_CANDIDATE_COUNT' "${cpu_jank_hotthread_c}"
check cpu-jank-hotthread-visible-window-bound \
  grep -Fq '#define HOTTHREAD_VISIBLE_WINDOWS' "${cpu_jank_hotthread_c}"
check cpu-jank-hotthread-workqueue-sampling \
  grep -Fq 'INIT_DELAYED_WORK(&hotthread_sample_work' "${cpu_jank_hotthread_c}"
check cpu-jank-hotthread-donor-grammar \
  grep -Fq '"%u$%d$%s$%d$%s$%u$%u"' "${cpu_jank_hotthread_c}"
check_absent cpu-jank-hotthread-no-dynamic-allocation \
  grep -E 'kmem_cache_alloc|kzalloc|kmalloc|vmalloc' "${cpu_jank_hotthread_c}"
check_absent cpu-jank-hotthread-no-scheduler-hook \
  grep -E 'register_trace_sched|jank_hotthread_update_tick' "${cpu_jank_hotthread_c}"
check cpu-jank-hotthread-abi-document \
  test -f Documentation/ABI/testing/procfs-oplus-cpu-jank-hotthread

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

# GameOpt CPU load uses the donor's cpuidle and cpufreq transition feeds.
# Stage 9L completes the donor GameOpt proc surface with selected-thread,
# deferred D-state diagnostics; unrelated scheduler policy remains excluded.
check gameopt-cpu-load-source test -f "${game_opt_cpu_load_c}"
check gameopt-control-source test -f "${game_opt_ctrl_c}"
check gameopt-public-header test -f "${game_opt_header}"
check gameopt-kconfig-source \
  grep -Fq 'source "drivers/soc/oplus/game_opt/Kconfig"' drivers/soc/Kconfig
check gameopt-kconfig \
  grep -Fq 'config OPLUS_FEATURE_GAME_OPT' "${game_opt_dir}/Kconfig"
check gameopt-config-enabled \
  grep -Fxq 'CONFIG_OPLUS_FEATURE_GAME_OPT=y' "${config}"
check gameopt-kbuild-link \
  grep -Fq 'obj-$(CONFIG_OPLUS_FEATURE_GAME_OPT) += oplus/game_opt/' drivers/soc/Makefile
for object in game_ctrl.o cpu_load.o cpufreq_limits.o task_util.o rt_info.o dstate_dump.o; do
  check "gameopt-object-${object%.o}" \
    grep -Fq "${object}" "${game_opt_dir}/Makefile"
done
check gameopt-proc-parent \
  grep -Fq 'proc_mkdir("game_opt", NULL)' "${game_opt_ctrl_c}"
check gameopt-cpu-load-node \
  grep -Fq 'proc_create_data("cpu_load", 0444' "${game_opt_cpu_load_c}"
check gameopt-cpu-load-grammar \
  grep -Fq 'CPU:%d busy_pct:%d util_pct:%d' "${game_opt_cpu_load_c}"
check gameopt-reset-on-read \
  grep -Fq 'reset_cur_state_after_read(icpu, now);' "${game_opt_cpu_load_c}"
check gameopt-idle-public-declaration \
  grep -Fq 'void g_time_in_state_update_idle(int cpu, unsigned int new_idle_index);' "${game_opt_header}"
check gameopt-idle-definition \
  grep -Fq 'void g_time_in_state_update_idle(int cpu, unsigned int new_idle_index)' "${game_opt_cpu_load_c}"
check gameopt-idle-hooks \
  test "$(grep -Fc 'g_time_in_state_update_idle(dev->cpu,' drivers/cpuidle/cpuidle.c)" -eq 2
check gameopt-idle-enter-hook \
  grep -Fq 'g_time_in_state_update_idle(dev->cpu, 1);' drivers/cpuidle/cpuidle.c
check gameopt-idle-exit-hook \
  grep -Fq 'g_time_in_state_update_idle(dev->cpu, 0);' drivers/cpuidle/cpuidle.c
check gameopt-cpufreq-notifier \
  grep -Fq 'cpufreq_register_notifier(&cpufreq_transition_notifier,' "${game_opt_cpu_load_c}"
check gameopt-cpufreq-postchange \
  grep -Fq 'event != CPUFREQ_POSTCHANGE' "${game_opt_cpu_load_c}"
check gameopt-zero-before-init \
  grep -Fq '*util_pct = 0;' "${game_opt_cpu_load_c}"
check_absent gameopt-cpu-load-no-write-handler \
  grep -Eq '\.(write|unlocked_ioctl)[[:space:]]*=' "${game_opt_cpu_load_c}"
check gameopt-abi-document \
  test -f Documentation/ABI/testing/procfs-oplus-gameopt-cpu-load

# Stage 9K restores the exact 9R CPU:kHz proc ABI using the native 4.14
# CPUFREQ_ADJUST notifier.  Defaults are neutral, parsing is transactional,
# and no scheduler hot-path producer is introduced.
check gameopt-cpufreq-limits-source test -f "${game_opt_cpufreq_limits_c}"
check gameopt-cpufreq-limits-init \
  grep -Fq 'ret = cpufreq_limits_init();' "${game_opt_ctrl_c}"
check gameopt-cpufreq-limits-unwind \
  grep -Fq 'cpufreq_limits_exit();' "${game_opt_ctrl_c}"
check gameopt-cpufreq-min-node \
  grep -Fq 'proc_create_data("cpu_min_freq", 0664' "${game_opt_cpufreq_limits_c}"
check gameopt-cpufreq-max-node \
  grep -Fq 'proc_create_data("cpu_max_freq", 0664' "${game_opt_cpufreq_limits_c}"
check gameopt-cpufreq-pair-parser \
  grep -Fq "separator = strnchr(token, token_len, ':');" "${game_opt_cpufreq_limits_c}"
check gameopt-cpufreq-transactional-parse \
  grep -Fq 'if (!ret)' "${game_opt_cpufreq_limits_c}"
check gameopt-cpufreq-request-serialization \
  grep -Fq 'DEFINE_MUTEX(game_cpu_freq_lock)' "${game_opt_cpufreq_limits_c}"
check gameopt-cpufreq-neutral-min \
  grep -Fq 'per_cpu(game_cpu_freq_status, cpu).min = 0;' "${game_opt_cpufreq_limits_c}"
check gameopt-cpufreq-neutral-max \
  grep -Fq 'per_cpu(game_cpu_freq_status, cpu).max = UINT_MAX;' "${game_opt_cpufreq_limits_c}"
check gameopt-cpufreq-policy-notifier \
  grep -Fq 'CPUFREQ_POLICY_NOTIFIER' "${game_opt_cpufreq_limits_c}"
check gameopt-cpufreq-policy-adjust \
  grep -Fq 'event != CPUFREQ_ADJUST' "${game_opt_cpufreq_limits_c}"
check gameopt-cpufreq-policy-clamp \
  grep -Fq 'cpufreq_verify_within_limits(policy, min, max);' "${game_opt_cpufreq_limits_c}"
check gameopt-cpufreq-policy-lifetime \
  grep -Fq 'cpufreq_cpu_put(policy);' "${game_opt_cpufreq_limits_c}"
check gameopt-cpufreq-register-unwind \
  grep -Fq 'remove_proc_entry("cpu_min_freq", game_opt_dir);' "${game_opt_cpufreq_limits_c}"
check_absent gameopt-cpufreq-no-workqueue \
  grep -E 'schedule_work|queue_work|delayed_work' "${game_opt_cpufreq_limits_c}"
check_absent gameopt-cpufreq-no-uevent \
  grep -Fq 'kobject_uevent' "${game_opt_cpufreq_limits_c}"
check gameopt-cpufreq-abi-document \
  test -f Documentation/ABI/testing/procfs-oplus-gameopt-cpufreq-limits

# Stage 9F adds the donor-compatible process selector and heavy-thread runtime
# report.  Its CFS/RT producers are dormant until a valid game PID is written,
# use a trylock, and cap state at 256 threads.
check gameopt-task-runtime-source test -f "${game_opt_task_util_c}"
check gameopt-task-runtime-init \
  grep -Fq 'ret = task_util_init();' "${game_opt_ctrl_c}"
check gameopt-game-pid-node \
  grep -Fq 'proc_create_data("game_pid", 0664' "${game_opt_task_util_c}"
check gameopt-heavy-task-node \
  grep -Fq 'proc_create_data("heavy_task_info", 0444' "${game_opt_task_util_c}"
check gameopt-heavy-task-grammar \
  grep -Fq '%d;%s;%u' "${game_opt_task_util_c}"
check gameopt-task-runtime-default-off \
  grep -Fq 'need_stat_runtime = ATOMIC_INIT(0)' "${game_opt_task_util_c}"
check gameopt-task-runtime-cap \
  grep -Fq '#define MAX_TID_COUNT 256' "${game_opt_task_util_c}"
check gameopt-task-runtime-trylocks \
  test "$(grep -Fc 'raw_spin_trylock_irqsave(&game_task_lock' "${game_opt_task_util_c}")" -eq 2
check gameopt-task-runtime-game-pid-only-write \
  test "$(grep -Ec '\.write[[:space:]]*=' "${game_opt_task_util_c}")" -eq 1
check_absent gameopt-task-runtime-no-ioctl \
  grep -Eq '\.unlocked_ioctl[[:space:]]*=' "${game_opt_task_util_c}"
check gameopt-task-runtime-fair-hook \
  test "$(grep -Fc 'g_update_task_runtime(curtask, delta_exec);' kernel/sched/fair.c)" -eq 1
check gameopt-task-runtime-rt-hook \
  test "$(grep -Fc 'g_update_task_runtime(curr, delta_exec);' kernel/sched/rt.c)" -eq 1
check gameopt-task-runtime-death-hook \
  test "$(grep -Fc 'g_rt_task_dead(prev);' kernel/sched/core.c)" -eq 1
check gameopt-task-runtime-public-api \
  grep -Fq 'void g_update_task_runtime(struct task_struct *task, u64 runtime);' "${game_opt_header}"
check gameopt-task-runtime-reset-on-read \
  grep -Fq 'info->sum_exec_scale = 0;' "${game_opt_task_util_c}"
check_absent gameopt-task-runtime-no-private-sched-header \
  grep -Fq 'kernel/sched/sched.h' "${game_opt_task_util_c}"
check_absent gameopt-task-runtime-no-stack-capture \
  grep -E 'get_wchan|stack_trace|save_stack|trace_printk' "${game_opt_task_util_c}"
check gameopt-task-runtime-abi-document \
  test -f Documentation/ABI/testing/procfs-oplus-gameopt-task-runtime

# Stage 9G adds the donor render-thread waker ABI.  Stage 9L connects its
# selected TIDs to the bounded D-state diagnostics without changing wakeup
# accounting.
# Accounting is off until userspace writes up to two target TIDs, the wakeup
# hook never waits for the reporting lock, and a static pool caps state at 256
# wakers across both targets.
check gameopt-render-waker-source test -f "${game_opt_rt_info_c}"
check gameopt-render-waker-init \
  grep -Fq 'ret = rt_info_init();' "${game_opt_ctrl_c}"
check gameopt-render-waker-build \
  grep -Fq 'rt_info.o' "${game_opt_dir}/Makefile"
check gameopt-render-waker-node \
  grep -Fq 'proc_create_data("render_thread_info", 0664' "${game_opt_rt_info_c}"
check gameopt-render-count-node \
  grep -Fq 'proc_create_data("rt_num", 0444' "${game_opt_rt_info_c}"
check gameopt-render-waker-grammar \
  grep -Fq '%d;%s;%d;%llu;%u' "${game_opt_rt_info_c}"
check gameopt-render-waker-default-off \
  grep -Fq 'need_stat_wake = ATOMIC_INIT(0)' "${game_opt_rt_info_c}"
check gameopt-render-waker-two-target-cap \
  grep -Fq '#define MAX_RT_NUM 2' "${game_opt_dir}/game_ctrl.h"
check gameopt-render-waker-pool-cap \
  grep -Fq '#define MAX_WAKER_COUNT 256' "${game_opt_rt_info_c}"
check gameopt-render-waker-static-pool \
  grep -Fq 'waker_pool[MAX_WAKER_COUNT]' "${game_opt_rt_info_c}"
check gameopt-render-waker-trylock \
  grep -Fq 'raw_spin_trylock_irqsave(&rt_info_lock' "${game_opt_rt_info_c}"
check gameopt-render-waker-wakeup-hook \
  grep -Fq 'g_rt_try_to_wake_up(p);' kernel/sched/core.c
check gameopt-render-waker-death-hook \
  grep -Fq 'g_rt_waker_task_dead(prev);' kernel/sched/core.c
check gameopt-render-waker-public-api \
  grep -Fq 'void g_rt_try_to_wake_up(struct task_struct *task);' "${game_opt_header}"
check gameopt-render-waker-task-name-buffer \
  grep -Fq 'char comm[TASK_COMM_LEN];' "${game_opt_rt_info_c}"
check gameopt-render-waker-task-name-copy \
  grep -Fq 'memcpy(name, comm, sizeof(comm));' "${game_opt_rt_info_c}"
check gameopt-render-waker-reset-on-read \
  grep -Fq 'waker->increment = 0;' "${game_opt_rt_info_c}"
check gameopt-render-waker-only-write \
  test "$(grep -Ec '\.write[[:space:]]*=' "${game_opt_rt_info_c}")" -eq 1
check_absent gameopt-render-waker-no-ioctl \
  grep -Eq '\.unlocked_ioctl[[:space:]]*=' "${game_opt_rt_info_c}"
check gameopt-render-waker-dstate-coupling \
  grep -Fq 'rt_set_dstate_interested_threads' "${game_opt_rt_info_c}"
check gameopt-render-waker-abi-document \
  test -f Documentation/ABI/testing/procfs-oplus-gameopt-render-waker

# Stage 9L completes the three-node 9R D-state ABI.  The 4.14 adaptation uses
# the native sched_stat_blocked tracepoint, accepts only selected threads, and
# moves task inspection and stack reporting out of the scheduler callback.
check gameopt-dstate-source test -f "${game_opt_dstate_c}"
check gameopt-dstate-init \
  grep -Fq 'ret = dstate_dump_init();' "${game_opt_ctrl_c}"
for node in dump_enable duration interested_tids; do
  check "gameopt-dstate-node-${node}" \
    grep -Fq "proc_create_data(\"${node}\", 0664" "${game_opt_dstate_c}"
done
check gameopt-dstate-donor-default-enabled \
  grep -Fq 'dstate_dump_enable = ATOMIC_INIT(1)' "${game_opt_dstate_c}"
check gameopt-dstate-donor-duration \
  grep -Fq '#define DSTATE_DURATION_DEFAULT_MS 5' "${game_opt_dstate_c}"
check gameopt-dstate-no-target-fastpath \
  grep -Fq '!atomic_read(&dstate_targets_enabled)' "${game_opt_dstate_c}"
check gameopt-dstate-selected-thread-filter \
  grep -Fq 'if (!dstate_tid_interested(task->pid))' "${game_opt_dstate_c}"
check gameopt-dstate-scheduler-trylocks \
  test "$(grep -Fc 'raw_spin_trylock_irqsave' "${game_opt_dstate_c}")" -eq 2
check gameopt-dstate-non-iowait-filter \
  grep -Fq 'task->in_iowait' "${game_opt_dstate_c}"
check gameopt-dstate-native-tracepoint \
  grep -Fq 'register_trace_sched_stat_blocked' "${game_opt_dstate_c}"
check gameopt-dstate-selection-enables-schedstats \
  grep -Fq 'force_schedstat_enabled();' "${game_opt_dstate_c}"
check gameopt-dstate-deferred-stack \
  grep -Fq 'save_stack_trace_tsk(event.task, &trace);' "${game_opt_dstate_c}"
check gameopt-dstate-irq-work \
  grep -Fq 'irq_work_queue(&dstate_report_irq_work);' "${game_opt_dstate_c}"
check gameopt-dstate-rate-limit \
  grep -Fq '#define DSTATE_REPORT_INTERVAL_NS' "${game_opt_dstate_c}"
check gameopt-dstate-single-pending-slot \
  grep -Fq 'static struct gameopt_dstate_event dstate_pending_event;' "${game_opt_dstate_c}"
check_absent gameopt-dstate-no-trace-printk \
  grep -Fq 'trace_printk' "${game_opt_dstate_c}"
check gameopt-dstate-abi-document \
  test -f Documentation/ABI/testing/procfs-oplus-gameopt-dstate

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

for object in frame_info.o cluster_boost.o frame_boost.o frame_debug.o \
  frame_group.o frame_ioctl.o frame_sysctl.o ua_ioctl_common.o touch_ioctl.o; do
  check "frame-boost-object-${object}" \
    grep -Fq "obj-y += ${object}" "${frame_boost_dir}/Makefile"
done

check frame-boost-init-sysctl \
  grep -Fq 'fbg_sysctl_init();' "${frame_boost_c}"
check frame-boost-init-ioctl \
  grep -Fq 'frame_ioctl_init();' "${frame_boost_c}"
check frame-boost-init-ua \
  grep -Fq 'ret = ua_ioctl_init();' "${frame_boost_c}"
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
check frame-boost-proc-stune \
  grep -Fq 'proc_create("stune_boost", (S_IRUGO|S_IWUSR|S_IWGRP)' "${frame_ioctl_c}"
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
check frame-boost-donor-default-enabled \
  grep -Fq 'sysctl_frame_boost_enable = 1;' "${frame_sysctl_c}"
check frame-boost-safe-mode-default-clear \
  grep -Fq 'sysctl_frame_boost_safe_mode = 0;' "${frame_sysctl_c}"
check frame-boost-kernel-sysctl-enabled \
  grep -Fq '.procname	= "frame_boost_enabled"' kernel/sysctl.c
check frame-boost-kernel-sysctl-enabled-storage \
  grep -Fq '.data		= &sysctl_frame_boost_enable' kernel/sysctl.c
check frame-boost-kernel-sysctl-debug \
  grep -Fq '.procname	= "frame_boost_debug"' kernel/sysctl.c
check frame-boost-kernel-sysctl-debug-storage \
  grep -Fq '.data		= &sysctl_frame_boost_debug' kernel/sysctl.c
check frame-boost-kernel-sysctl-slide \
  grep -Fq '.procname	= "slide_boost_enabled"' kernel/sysctl.c
check frame-boost-kernel-sysctl-input \
  grep -Fq '.procname	= "input_boost_enabled"' kernel/sysctl.c
check frame-boost-ua-parent \
  grep -Fq '#define UA_PROC_NODE "oplus_cpu"' "${ua_ioctl_common_c}"
check frame-boost-ua-control-node \
  grep -Fq 'proc_create("ua_ctrl", UA_CTRL_MODE' "${ua_ioctl_common_c}"
check frame-boost-ua-control-mode \
  grep -Fq '#define UA_CTRL_MODE 0777' "${ua_ioctl_common_c}"
check frame-boost-ua-donor-magic \
  grep -Fq "#define CPU_CTRL_MAGIC 'o'" "${ua_ioctl_common_h}"
check frame-boost-ua-prev-util \
  grep -Fq 'fbg_get_prev_util(&info.frame_prev_util_scale);' "${ua_ioctl_common_c}"
check frame-boost-ua-current-util \
  grep -Fq 'fbg_get_curr_util(&info.frame_curr_util_scale);' "${ua_ioctl_common_c}"
check frame-boost-touch-parent \
  grep -Fq '#define TOUCHBOOST_PROC_NODE "oplus_touch_boost"' "${touch_ioctl_c}"
check frame-boost-touch-info \
  grep -Fq 'proc_create("touch_info", 0444' "${touch_ioctl_c}"
check frame-boost-touch-handler \
  grep -Fq 'input_register_handler(&touchboost_input_handler);' "${touch_ioctl_c}"
check frame-boost-parity-abi-document \
  test -f Documentation/ABI/testing/procfs-oplus-frame-boost
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
check frame-boost-h40-native-walt-cadence \
  grep -Fq '#define FBG_CPUFREQ_UPDATE_FLAGS(flags) (flags)' "${frame_group_c}"
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

# Athena and Performance AIDL need real allocator totals and writable reclaim
# state.  Keep the production debug trackers disabled: these nodes sample the
# existing allocators only when userspace reads them.
check athena-memory-source test -f "${athena_memory_c}"
check athena-memory-main-source test -f "${healthinfo_main_c}"
check athena-memory-kconfig-source test -f "${athena_memory_kconfig}"
check athena-memory-kbuild-source test -f "${athena_memory_makefile}"
check athena-memory-config-enabled \
  grep -Fxq 'CONFIG_OPLUS_ATHENA_MEMORY_ABI=y' "${config}"
check athena-memory-kconfig \
  grep -Fq 'config OPLUS_ATHENA_MEMORY_ABI' "${athena_memory_kconfig}"
check athena-memory-kbuild \
  grep -Fq 'obj-$(CONFIG_OPLUS_ATHENA_MEMORY_ABI) += allocator_usage.o' "${athena_memory_makefile}"
check athena-memory-healthinfo-init \
  grep -Fq 'create_athena_memory_abi(oplus_healthinfo);' "${healthinfo_main_c}"
check athena-memory-kmalloc-node \
  grep -Fq 'proc_create("kmalloc_used", 0444' "${athena_memory_c}"
check athena-memory-vmalloc-node \
  grep -Fq 'proc_create("vmalloc_used", 0444' "${athena_memory_c}"
check athena-memory-swappiness-node \
  grep -Fq 'proc_create("swappiness_para", 0666' "${athena_memory_c}"
check athena-memory-live-kmalloc-accounting \
  grep -Fq 'get_slabinfo(cache, &info);' "${athena_memory_c}"
check athena-memory-memcg-accounting \
  grep -Fq 'for_each_memcg_cache(child, cache)' "${athena_memory_c}"
check athena-memory-live-vmalloc-accounting \
  grep -Fq 'vmalloc_nr_pages() << 2' "${athena_memory_c}"
check athena-memory-native-hybridswapd-binding \
  grep -Fq '&hybridswapd_swappiness' "${athena_memory_c}"
check athena-memory-native-direct-binding \
  grep -Fq '&direct_vm_swappiness' "${athena_memory_c}"
check_absent athena-memory-no-debug-cache-replacement \
  grep -Fq 'kmalloc_debug_caches' "${athena_memory_c}"
check_absent athena-memory-no-stack-tracking \
  grep -Fq 'stack_trace' "${athena_memory_c}"
check athena-memory-abi-document \
  test -f Documentation/ABI/testing/procfs-oplus-athena-memory

# Wave 15 replaces the legacy NandSwap path with the complete Android 14 9R
# OSwap 2.0 implementation: zram backing-store core, per-node swapd reclaim,
# per-memcg controls, and the allocator/reclaim lifecycle feeds it consumes.
for option in HYBRIDSWAP HYBRIDSWAP_SWAPD HYBRIDSWAP_CORE; do
  check "hybridswap-config-${option}" grep -Fxq "CONFIG_${option}=y" "${config}"
done
check_absent hybridswap-legacy-nandswap-disabled \
  grep -Eq '^CONFIG_NANDSWAP=[ym]$' "${config}"
check hybridswap-kconfig grep -Fq 'config HYBRIDSWAP' drivers/block/zram/Kconfig
for object in hybridswap_main.o hybridswap_swapd.o hybridswap_area.o \
  hybridswap_core.o hybridswap_ctrl.o hybridswap_list.o hybridswap_lru_rmap.o \
  hybridswap_manager.o hybridswap_perf.o hybridswap_schedule.o \
  hybridswap_stats.o; do
  check "hybridswap-object-${object}" grep -Fq "${object}" drivers/block/zram/Makefile
done
for source in hybridswap_main.c hybridswap_swapd.c hybridswap_area.c \
  hybridswap_core.c hybridswap_ctrl.c hybridswap_list.c hybridswap_lru_rmap.c \
  hybridswap_manager.c hybridswap_perf.c hybridswap_schedule.c \
  hybridswap_stats.c hybridswap_akcompress.c hybridswap_area.h \
  hybridswap_list.h hybridswap_lru_rmap.h hybridswap_internal.h hybridswap.h; do
  check "hybridswap-source-${source}" test -f "${hybridswap_dir}/${source}"
done
for node in hybridswap_vmstat hybridswap_loglevel hybridswap_enable \
  hybridswap_swapd_pause hybridswap_core_enable hybridswap_loop_device \
  hybridswap_dev_life hybridswap_quota_day hybridswap_report \
  hybridswap_stat_snap hybridswap_meminfo hybridswap_zram_increase; do
  check "hybridswap-zram-node-${node}" \
    grep -Eq "DEVICE_ATTR_(RO|RW|WO)\\(${node}\\)" "${zram_c}"
  check "hybridswap-zram-registration-${node}" grep -Fq "dev_attr_${node}.attr" "${zram_c}"
done
for node in force_shrink_anon total_info_per_app swap_stat name app_score \
  app_uid ub_ufs2zram_ratio force_swapin force_swapout psi stored_wm_ratio; do
  check "hybridswap-memcg-node-${node}" grep -Fq ".name = \"${node}\"" "${hybridswap_main_c}"
done
for node in active_app_info_list zram_wm_ratio compress_ratio swapd_pressure \
  swapd_pid avail_buffers swapd_max_reclaim_size area_anon_refault_threshold \
  empty_round_skip_interval max_skip_interval empty_round_check_threshold \
  anon_refault_snapshot_min_interval swapd_memcgs_param \
  swapd_single_memcg_param zram_critical_threshold cpuload_threshold \
  reclaim_exceed_sleep_ms swapd_bind max_reclaimin_size_mb \
  swapd_shrink_parameter swapd_nap_jiffies; do
  check "hybridswap-swapd-memcg-node-${node}" grep -Fq ".name = \"${node}\"" "${hybridswap_swapd_c}"
done
for hook in hybridswap_track hybridswap_untrack hybridswap_fault_out \
  hybridswap_delete; do
  check "hybridswap-zram-hook-${hook}" grep -Fq "${hook}(zram" "${zram_c}"
done
check hybridswap-pre-init grep -Fq 'hybridswap_pre_init();' "${zram_c}"
for hook in hybridswap_mem_cgroup_alloc hybridswap_mem_cgroup_free \
  hybridswap_mem_cgroup_online hybridswap_mem_cgroup_offline \
  mem_cgroup_id_remove_hook; do
  check "hybridswap-memcg-lifecycle-${hook}" grep -Fq "${hook}(" mm/memcontrol.c
done
check hybridswap-rmqueue-feed grep -Fq 'rmqueue_hook(NULL' mm/page_alloc.c
check hybridswap-slowpath-feed \
  grep -Fq 'alloc_pages_slowpath_hook(NULL' mm/page_alloc.c
check hybridswap-scan-feed \
  grep -Fq 'hybridswap_tune_scan_type((char *)&scan_balance);' mm/vmscan.c
check hybridswap-swapd-swappiness \
  grep -Fq 'int hybridswapd_swappiness = 200;' mm/vmscan.c
check hybridswap-abi-document \
  test -f Documentation/ABI/testing/sysfs-block-zram-hybridswap

# Wave 16 carries the remaining donor-enabled Midas hardware telemetry.  UFS
# accounting is native to the H.40 host driver; DDR residency remains gated by
# the AOP firmware's shared-memory pointer and therefore fails closed.
check midas-feature-macro grep -Fq -- '-DOPLUS_FEATURE_MIDAS' Makefile
check midas-ufs-source test -f "${ufs_c}"
check midas-ufs-header test -f "${ufs_h}"
check midas-runtime-ufs-source test -f "${runtime_ufs_c}"
check midas-runtime-ufs-header test -f "${runtime_ufs_h}"
check midas-ufs-node-name grep -Fq '"ufs_transmission_status"' "${ufs_c}"
check midas-runtime-ufs-node-name \
  grep -Fq '"ufs_transmission_status"' "${runtime_ufs_c}"
check midas-ufs-node-mode grep -Fq 'attr->attr.mode = 0644;' "${ufs_c}"
check midas-ufs-enabled-default \
  grep -Fq 'ufs_transmission_status.transmission_status_enable = 1;' "${ufs_c}"
check midas-ufs-send-accounting grep -Fq 'scsi_send_count++;' "${ufs_c}"
check midas-runtime-ufs-send-accounting \
  grep -Fq 'scsi_send_count++;' "${runtime_ufs_c}"
check midas-ufs-completion-accounting \
  grep -Fq 'ufshcd_lrb_scsicmd_time_statistics(hba, lrbp);' "${ufs_c}"
check midas-runtime-ufs-completion-accounting \
  grep -Fq 'ufshcd_lrb_scsicmd_time_statistics(hba, lrbp);' "${runtime_ufs_c}"
check midas-ufs-device-accounting \
  grep -Fq 'ufshcd_lrb_devcmd_time_statistics(hba, lrbp);' "${ufs_c}"
check midas-ufs-state grep -Fq 'struct ufs_transmission_status {' "${ufs_h}"
check midas-runtime-ufs-state \
  grep -Fq 'struct ufs_transmission_status {' "${runtime_ufs_h}"
check midas-ufs-abi-document \
  test -f Documentation/ABI/testing/sysfs-devices-ufs-transmission-status

check ddr-stats-source test -f "${ddr_stats_c}"
check ddr-stats-config grep -Fxq 'CONFIG_QTI_DDR_STATS_LOG=y' "${config}"
check ddr-stats-kconfig grep -Fq 'config QTI_DDR_STATS_LOG' drivers/soc/qcom/Kconfig
check ddr-stats-kbuild \
  grep -Fq 'obj-$(CONFIG_QTI_DDR_STATS_LOG) += ddr_stats.o' drivers/soc/qcom/Makefile
check ddr-stats-node-name grep -Fq 'attr->ka.attr.name = "residency";' "${ddr_stats_c}"
check ddr-stats-firmware-guard \
  grep -Fq 'DDR stats are not exported by this AOP firmware' "${ddr_stats_c}"
for project in 18821 18857 18865 19801 19863; do
  check "ddr-stats-dts-${project}" \
    grep -Fq 'qcom,ddr-stats@c3f0000' "arch/arm64/boot/dts/${project}/sm8150-pm.dtsi"
done
check ddr-stats-abi-document \
  test -f Documentation/ABI/testing/sysfs-power-ddr-residency

# Wave 17 replaces the dormant foreground-only queue shim with the donor's
# active UX/foreground/background dispatch policy and its complete controls.
check uxio-first-source test -f "${uxio_first_c}"
check uxio-first-header test -f "${uxio_first_h}"
check uxio-first-high-prio-source test -f "${uxio_high_prio_c}"
check uxio-first-config \
  grep -Fxq 'CONFIG_OPLUS_FEATURE_UXIO_FIRST=y' "${config}"
check uxio-first-healthinfo-config \
  grep -Fxq 'CONFIG_OPLUS_HEALTHINFO=y' "${config}"
check uxio-first-wbt-config grep -Fxq 'CONFIG_BLK_WBT=y' "${config}"
check uxio-first-wbt-sq-config grep -Fxq 'CONFIG_BLK_WBT_SQ=y' "${config}"
check uxio-first-block-symlink test -L block/oplus_foreground_io_opt
check uxio-first-block-symlink-target \
  test "$(readlink block/oplus_foreground_io_opt)" = '../../../vendor/oplus/kernel/oplus_performance/oplus_uxio_first'
check uxio-first-kconfig \
  grep -Fq 'source block/oplus_foreground_io_opt/Kconfig' block/Kconfig
check uxio-first-kbuild \
  grep -Fq 'obj-$(CONFIG_OPLUS_FEATURE_UXIO_FIRST)' block/Makefile
check uxio-first-sysctl-node grep -Fq '"uxio_first_opt"' kernel/sysctl.c
check uxio-first-sysctl-default grep -Fq 'unsigned int sysctl_uxio_io_opt = 1;' kernel/sysctl.c
check uxio-first-wbt-node grep -Fq '"wbt_enable"' kernel/sysctl.c
check uxio-first-wbt-default grep -Fq 'unsigned int sysctl_wbt_enable = 1;' kernel/sysctl.c
check uxio-first-wbt-gate grep -Fq 'return sysctl_wbt_enable && rwb' block/blk-wbt.c
check uxio-first-request-list grep -Fq 'struct list_head ux_fg_bg_list;' include/linux/blkdev.h
for list in ux_head fg_head bg_head; do
  check "uxio-first-queue-${list}" grep -Fq "${list};" include/linux/blkdev.h
done
for bucket in BLK_RW_UX BLK_RW_FG BLK_RW_BG; do
  check "uxio-first-bucket-${bucket}" grep -Fq "${bucket}" include/linux/backing-dev-defs.h
done
check uxio-first-inflight-width grep -Fq 'in_flight[5];' include/linux/blkdev.h
check uxio-first-inflight-add-declaration grep -Fq 'extern void ohm_ioqueue_add_inflight' include/linux/blkdev.h
check uxio-first-inflight-dec-declaration grep -Fq 'extern void ohm_ioqueue_dec_inflight' include/linux/blkdev.h
check uxio-first-inflight-add-hook grep -Fq 'ohm_ioqueue_add_inflight(q, rq);' block/blk-core.c
check uxio-first-inflight-dec-hooks \
  test "$(grep -Fc 'ohm_ioqueue_dec_inflight(q, rq);' block/elevator.c)" -eq 2
check uxio-first-queue-throttle grep -Fq 'void queue_throtl_add_request' "${uxio_first_c}"
check uxio-first-smart-peek grep -Fq 'struct request * smart_peek_request' "${uxio_first_c}"
check uxio-first-pm-adapter grep -Fq 'bool blk_pm_allow_request(struct request *rq)' block/blk-core.c
check uxio-first-pm-native-policy grep -Fq 'return blk_pm_peek_request(rq->q, rq) != NULL;' block/blk-core.c
check uxio-first-safe-fallback grep -Fq 'if (!list_empty(&q->queue_head))' block/blk.h
check uxio-first-bg-depth-definition grep -Fq '#define BLK_MAX_BG_DEPTH' "${uxio_first_h}"
check uxio-first-bg-depth-field grep -Fq 'int bg_max_depth;' include/linux/blkdev.h
check uxio-first-bg-depth-node grep -Fq '.name = "bg_max_depth"' block/blk-sysfs.c
check uxio-first-inflight-node grep -Fq '.name = "ohm_inflight"' block/blk-sysfs.c
check uxio-first-inflight-ux-output grep -Fq '"ux:%d\n"' block/blk-sysfs.c
check uxio-first-abi-document \
  test -f Documentation/ABI/testing/sysfs-block-queue-oplus-uxio-first

# Wave 18 restores the donor-enabled OHM block request latency monitor. The
# only adaptation is using the 4.14 request clock for all four time deltas.
check blk-monitor-config grep -Fxq 'CONFIG_OPLUS_BLK_MONITOR=y' "${config}"
check blk-monitor-source test -f "${blk_monitor_c}"
check blk-monitor-kconfig grep -Fq 'config OPLUS_BLK_MONITOR' "${healthinfo_main_kconfig}"
check blk-monitor-kbuild \
  grep -Fq 'obj-$(CONFIG_OPLUS_BLK_MONITOR) +=  blk_monitor.o' "${healthinfo_main_makefile}"
check blk-monitor-type grep -Fq 'struct blk_wait_para {' "${healthinfo_main_h}"
check blk-monitor-control-bit grep -Fq 'OHM_CTRL_BLKMON' "${healthinfo_main_c}"
check blk-monitor-event-name grep -Fq '"blk_monitor"' "${healthinfo_main_c}"
for node in blk_q2c_wait blk_q2i_wait blk_i2d_wait blk_d2c_wait; do
  check "blk-monitor-node-${node}" grep -Fq "proc_create(\"${node}\"" "${healthinfo_main_c}"
done
for tracepoint in block_rq_insert block_rq_issue block_rq_complete; do
  check "blk-monitor-trace-${tracepoint}" \
    grep -Fq "register_trace_${tracepoint}" "${blk_monitor_c}"
done
for parameter in q2c_wait_high_ms q2c_wait_low_ms q2i_wait_high_ms \
  q2i_wait_low_ms i2d_wait_high_ms i2d_wait_low_ms d2c_wait_high_ms \
  d2c_wait_low_ms; do
  check "blk-monitor-param-${parameter}" \
    grep -Fq "module_param_named(${parameter}" "${blk_monitor_c}"
done
check blk-monitor-clock-adapter grep -Fq 'u64 now = sched_clock();' "${blk_monitor_c}"
check blk-monitor-default-active \
  grep -Fq 'OHM_CTRL_IONMON | OHM_CTRL_SCHEDTOTAL | OHM_CTRL_BLKMON' "${healthinfo_main_c}"
check blk-monitor-abi-document \
  test -f Documentation/ABI/testing/procfs-oplus-healthinfo-blk-monitor

# Wave 12 imports the complete locking strategy selected by the Android 14
# OnePlus 9R Kona configuration.  Its mutex/rwsem strategy and OSQ timeout
# hooks are active.  The donor's newer futex hook call sites remain inactive
# in its published main kernel, so retain only that donor behavior and ABI.
for option in OPLUS_LOCKING_STRATEGY OPLUS_LOCKING_OSQ OPLUS_LOCKING_MONITOR; do
  check "locking-config-${option}" grep -Fxq "CONFIG_${option}=y" "${config}"
done
check locking-kconfig-strategy \
  grep -Fq 'config OPLUS_LOCKING_STRATEGY' "${sched_assist_dir}/Kconfig"
check locking-kbuild-composite \
  grep -Fq 'obj-y += oplus_locking_strategy.o' "${sched_assist_dir}/Makefile"
for source in "${locking_main_c}" "${locking_main_h}" "${locking_sysfs_c}" \
  "${locking_mutex_c}" "${locking_rwsem_c}" "${locking_futex_c}" "${locking_stat_c}"; do
  check "locking-source-$(basename "${source}")" test -f "${source}"
done
check locking-donor-default-mutex \
  grep -Fq 'g_opt_enable |= LK_MUTEX_ENABLE;' "${locking_main_c}"
check locking-donor-default-rwsem \
  grep -Fq 'g_opt_enable |= LK_RWSEM_ENABLE;' "${locking_main_c}"
check locking-donor-default-futex \
  grep -Fq 'g_opt_enable |= LK_FUTEX_ENABLE;' "${locking_main_c}"
check locking-donor-default-osq \
  grep -Fq 'g_opt_enable |= LK_OSQ_ENABLE;' "${locking_main_c}"
check locking-task-state grep -Fq 'struct locking_info lkinfo;' include/linux/sched.h
check locking-fork-init grep -Fq 'init_task_lkinfo(p);' kernel/fork.c
check locking-mutex-storage grep -Fq 'u64 android_oem_data1[2];' include/linux/mutex.h
check locking-rwsem-storage grep -Fq 'u64 android_oem_data1[2];' include/linux/rwsem.h
for hook in locking_vh_mutex_opt_spin_start locking_vh_mutex_opt_spin_finish \
  locking_vh_mutex_can_spin_on_owner locking_vh_mutex_wait_start \
  locking_vh_mutex_wait_finish; do
  check "locking-main-${hook}" grep -Fq "${hook}" kernel/locking/mutex.c
done
for hook in locking_vh_rwsem_read_wait_start locking_vh_rwsem_read_wait_finish \
  locking_vh_rwsem_write_wait_start locking_vh_rwsem_write_wait_finish \
  locking_vh_rwsem_opt_spin_start locking_vh_rwsem_opt_spin_finish \
  locking_vh_rwsem_can_spin_on_owner; do
  check "locking-main-${hook}" grep -Fq "${hook}" kernel/locking/rwsem-xadd.c
done
check locking-proc-parent grep -Fq 'proc_mkdir(OPLUS_LOCKING_PROC_DIR, NULL)' "${locking_sysfs_c}"
check locking-thread-control grep -Fq 'proc_create("thread_info_ctrl"' "${locking_sysfs_c}"
for node in mutex rwsem_read rwsem_write futex_art; do
  check "locking-stat-node-${node}" grep -Fq "\"${node}\"" "${locking_stat_c}"
done
for node in kern_lock_stats kern_lock_stats_rclear fatal_lock_stats lock_thres_ctrl; do
  check "locking-proc-node-${node}" grep -Fq "proc_create(\"${node}\"" "${locking_stat_c}"
done
check locking-internal-top-node-guard \
  grep -Fq '#ifdef CONFIG_OPLUS_INTERNAL_VERSION' "${locking_stat_c}"
check_absent locking-internal-config-disabled \
  grep -Fxq 'CONFIG_OPLUS_INTERNAL_VERSION=y' "${config}"
for parameter in locking_enable locking_debug; do
  check "locking-param-${parameter}" grep -Fq "module_param_named(${parameter}" "${locking_main_c}"
done
for parameter in mutex_opt_spin_time_threshold mutex_ux_opt_spin_time_threshold \
  mutex_opt_spin_total_cnt mutex_opt_spin_timeout_exit_cnt; do
  check "locking-param-${parameter}" grep -Fq "module_param(${parameter}" "${locking_mutex_c}"
done
for parameter in rwsem_opt_spin_time_threshold rwsem_ux_opt_spin_time_threshold \
  rwsem_opt_spin_total_cnt rwsem_opt_spin_timeout_exit_cnt; do
  check "locking-param-${parameter}" grep -Fq "module_param(${parameter}" "${locking_rwsem_c}"
done
for parameter in futex_ux_set_cnt futex_ux_unset_cnt futex_set_blocked_ux_cnt; do
  check "locking-param-${parameter}" grep -Fq "module_param(${parameter}" "${locking_futex_c}"
done
check_absent locking-donor-futex-hooks-not-activated \
  grep -Fq 'locking_vh_' kernel/futex.c
check locking-abi-document \
  test -f Documentation/ABI/testing/procfs-oplus-locking-strategy

# Wave 21 restores donor task identity, the default-off Unity TPP framework,
# and Athena's bounded SIGKILL reason recorder.  TPD is deliberately a later
# wave because it actively constrains CPU affinity in several scheduler paths.
check im-config grep -Fxq 'CONFIG_OPLUS_FEATURE_IM=y' "${config}"
check im-source test -f "${im_c}"
check im-header test -f "${im_h}"
check im-task-field grep -Fq 'int im_flag;' include/linux/sched.h
check im-comm-hook grep -Fq 'im_wmi(tsk);' fs/exec.c
check im-fork-hook grep -Fq 'im_tsk_init_flag((void *)p);' kernel/fork.c
check im-per-task-proc-count \
  test "$(grep -Fc 'ONE("im_flag", 0444, proc_im_flag)' fs/proc/base.c)" -eq 2
check im-abi-document \
  test -f Documentation/ABI/testing/procfs-oplus-wave21-task-identity

check tpp-config grep -Fxq 'CONFIG_OPLUS_FEATURE_TPP=y' "${config}"
check tpp-source test -f "${tpp_c}"
check tpp-header test -f "${tpp_h}"
check tpp-task-field grep -Fq 'int tpp_flag;' include/linux/sched.h
check tpp-default-off grep -Fq 'static int tpp_on = 0;' "${tpp_c}"
check tpp-lazy-topology grep -Fq 'if (val && !tpp_topology_ready && !record_system_cpu_state())' "${tpp_c}"
check tpp-late-init grep -Fq 'late_initcall(tpp_init);' "${tpp_c}"
check tpp-enqueue-hook grep -Fq 'tpp_enqueue(cpu_of(rq), p);' kernel/sched/fair.c
check tpp-dequeue-hook grep -Fq 'tpp_dequeue(cpu_of(rq), p);' kernel/sched/fair.c
check tpp-select-hook grep -Fq 'tpp_find_cpu(&target_cpu, p);' kernel/sched/fair.c
for node in tpp_task_report tpp_tagged_list tpp_cpu_select_report; do
  check "tpp-proc-${node}" grep -Fq "proc_create(\"${node}\"" "${tpp_c}"
done

check sigkill-config \
  grep -Fxq 'CONFIG_OPLUS_FEATURE_SIGKILL_DIAGNOSIS=y' "${config}"
check sigkill-source test -f "${sigkill_c}"
check sigkill-header test -f "${sigkill_h}"
check sigkill-built-in grep -Fq 'bool "sigkill diagnosis driver"' "${sigkill_dir}/Kconfig"
check sigkill-ring-size grep -Fq '#define SIGKILL_RECORD_SIZE 20' "${sigkill_c}"
check sigkill-proc grep -Fq '"sigkill_reason" : "oplus_mem/sigkill_reason"' "${sigkill_c}"
check sigkill-preinit-guard grep -Fq 'unlikely(!READ_ONCE(g_sigkill_records))' "${sigkill_c}"
check sigkill-native-414-hook \
  grep -Fq 'record_sigkill_reason(NULL, sig, current, p);' kernel/signal.c
check sigkill-abi-document \
  test -f Documentation/ABI/testing/procfs-oplus-sigkill-diagnosis

cat <<EOF
result=PASS
proc_iomem=core-4.14
sched_assist_im_flag=task-backed
task_ux_state=per-thread-registered
audio_sched_assist=task-boost-and-enqueue-hook
audio_rt_placement=donor-status-gated-deep-idle-avoidance
audio_small_task=donor-audio-tgid-camera-cadence-preference
task_identity=donor-comm-classification-per-task-proc
tpp_unity_policy=donor-default-off-lazy-msmnile-topology
athena_sigkill_diagnosis=donor-ring-native-4.14-signal-hook
cpu_jank_control_plane=h40-live-sampling
cpu_jank_tasktrack=on-demand-sched-tracepoint
cpu_jank_tasktrack_latency=on-demand-bounded-sched-events
cpu_jank_tasktrack_callstack=on-demand-bounded-dsleep-stacktrace
cpu_jank_ux_throttle=opt-in-bounded-ux-runtime-frequency-telemetry
cpu_jank_reporting=donor-windowed-cputime-frequency-cgroup
cpu_jank_hotthread=opt-in-bounded-workqueue-sampling
cpu_jank_passive_controls=donor-enable-osi-debug-default-off
gameopt_cpu_load=donor-time-in-state-idle-frequency
gameopt_cpufreq_limits=donor-cpu-khz-policy-controls
gameopt_task_runtime=opt-in-bounded-cfs-rt-accounting
gameopt_render_waker=opt-in-bounded-wakeup-accounting
gameopt_dstate=selected-rate-limited-deferred-stack-reporting
sched_assist_debug=donor-module-parameter-default-off
task_cpustats=real-tick-accounting
task_sched_info=full-scheduler-frequency-isolation-telemetry
frame_boost_control_plane=task-group-walt-ioctl-sysctl
eas_opt=active-4.14-placement-capacity-schedutil-iowait
proactive_compact_parameters=bounded-runtime-tunables
sched_assist_boost_kill=donor-background-exit-acceleration
athena_memory_abi=read-triggered-allocator-totals-native-reclaim-controls
oswap2_hybridswap=donor-core-swapd-memcg-extent-io
midas_ufs_telemetry=donor-transmission-status-live-accounting
ddr_residency=donor-aop-table-firmware-gated
uxio_first=donor-ux-fg-bg-priority-and-wbt-control
blk_monitor=donor-q2i-i2d-q2c-d2c-latency-telemetry
locking_strategy=active-donor-mutex-rwsem-osq-monitor-futex-control-abi
EOF
