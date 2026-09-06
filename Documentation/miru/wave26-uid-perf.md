# Wave 26: Android 14 UID performance accounting

Wave 25 is the MIDAS core wave. After its kernel, external modules, H.40 DTB/
DTBO bundle, and artifact all passed, Wave 26 takes the next separately audited
9R configuration item: `CONFIG_OPLUS_FEATURE_UID_PERF`.

The Android 14 OnePlus 9R donor enables this feature in both Kona production
configurations. It extends Android UID statistics with three raw per-task PMU
counters and instruction-count attribution across cpuset groups. The complete
donor data path spans task creation and exit, cpuset migration, cgroup creation,
and `uid_sys_stats`; enabling only its proc node would therefore provide an
incomplete ABI.

Wave 26 restores:

- `/proc/uid_cputime/show_uid_perf`;
- `/proc/cpuset_info/show_hash` and `dbg_enable`;
- the `uid_perf_enable`, `uid_perf_debug`, `uid_perf_event_id`,
  `uid_perf_event_type`, and `uid_perf_event_pin` parameters;
- task-fork and task-exit perf-event lifetime accounting;
- cpuset migration settlement and cgroup-name/index discovery.

Runtime cost remains opt-in. `uid_perf_enable` defaults to 0, so boot and normal
task creation do not allocate PMU events until the Android performance stack
explicitly enables collection. The H.40 compatibility port also bounds cpuset
indices to the eight slots present in the donor ABI, rejects invalid enable
values, and avoids waking unavailable worker threads.
