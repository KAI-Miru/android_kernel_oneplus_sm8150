# Wave 25: MIDAS core

Wave 25 completes the production-enabled MIDAS core found in the pinned
OnePlus 9R Android 14 kernel repositories. It is based on main-kernel commit
`b339700f85cb393563c802733bc39cca2617190c` and external-kernel commit
`aa8395c52848104591110306e9cb5cdb4ce55a7a`.

The built-in implementation provides:

- `/dev/midas_dev`, including the donor mmap record format and ioctl surface;
- per-UID, per-process, and per-CPU frequency-residency accounting fed from
  `cpufreq_acct_update_power()`;
- workqueue-name attribution for worker tasks;
- `/sys/class/kgsl/kgsl-3d0/gpu_status_time` and KGSL slumber accounting;
- `oplus,midas-pdev` in all 24 reconstructed H.40 hardware base trees.

The RTIC metadata FDT and the 15 H.40 overlays are intentionally unchanged.
The rebuilt active DTB bundle is
`af32d362df25d7be0b822c43b521ff835418c0b08d6cd62f24fcc917a05dc4f4`.

Two bounded safety fixes accompany the donor code: task-state indices beyond
the 60-entry ABI are ignored, and suspend/resume timestamps no longer alias
the character-device private data. Neither changes the userspace ABI.
