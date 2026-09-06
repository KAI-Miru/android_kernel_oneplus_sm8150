# Wave 22 GPU eBPF accounting

## Result

The graphics stack is healthy. The Android GPU service failure is an
observability limitation caused by absent kernel tracepoints, not an Adreno,
KGSL, EGL/GLES, Vulkan, linker, or SELinux failure.

Two independent attachment attempts fail with `ENOENT`:

- `gpu_mem/gpu_mem_total`, consumed by `/system/etc/bpf/gpuMem.o`.
- `power/gpu_work_period`, consumed by `/system/etc/bpf/gpuWork.o`.

Both eBPF programs and all three maps are already loaded and pinned in bpffs.
That proves the loader, syscall, verifier, JIT, pinning, filesystem labels, and
GpuService access path work before tracepoint attachment is attempted.

## Runtime evidence

The audited phone ran
`4.14.357-openela-miru-h40-wave18-blk-monitor-ci1+`. Its kernel configuration
already enables `BPF`, `BPF_SYSCALL`, `BPF_JIT`, `BPF_JIT_ALWAYS_ON`,
`BPF_EVENTS`, `CGROUP_BPF`, `TRACEPOINTS`, `TRACING`, `FTRACE`, and
`PERF_EVENTS`. Tracefs is mounted at `/sys/kernel/tracing` and bpffs at
`/sys/fs/bpf`.

The missing paths are:

- `/sys/kernel/tracing/events/gpu_mem/gpu_mem_total`
- `/sys/kernel/tracing/events/power/gpu_work_period`

The first program expects `gpu_id` at offset 8, `pid` at offset 12, and `size`
at offset 16. It stores a hash keyed by `(gpu_id << 32) | pid`, with a `u64`
byte total and a maximum of 1024 entries.

The second program expects `gpu_id` at offset 8, `uid` at offset 12,
`start_time_ns` at offset 16, `end_time_ns` at offset 24, and
`total_active_duration_ns` at offset 32. It aggregates per-GPU/per-UID active
and inactive durations. Correct events require real driver-side work tracking;
an empty tracepoint or zero-valued emitter would produce false telemetry.

## Donor boundary

The pinned Android 14 OnePlus 9R sources were checked at:

- `OnePlusOSS/android_kernel_oneplus_sm8250`, branch
  `oneplus/sm8250_u_14.0.0_op9r`, commit
  `b339700f85cb393563c802733bc39cca2617190c`.
- `OnePlusOSS/android_kernel_modules_and_devicetree_oneplus_sm8250`, branch
  `oneplus/sm8250_u_14.0.0_op9r`, commit
  `aa8395c52848104591110306e9cb5cdb4ce55a7a`.

The 9R main tree contains the generic `gpu_mem` trace header and trace object,
but KGSL does not select `CONFIG_TRACE_GPU_MEM` and has no memory-accounting
call sites. Neither 9R repository contains `gpu_work_period` or GPU work-period
accounting. These interfaces are therefore optional Android telemetry, not a
required 9R vendor/ODM ABI.

Newer official OnePlus Android 14 sources were then audited as implementation
references:

- OnePlus 9RT SM8350 main kernel, branch
  `oneplus/sm8350_u_14.0.0_oneplus9rt`, commit
  `21e927b4f4c13414a8bfc8d9b8ed20a1cdc2efa0`.
- OnePlus 10 Pro SM8450 main kernel, branch
  `oneplus/sm8450_u_14.0.0_oneplus_10pro`, commit
  `2953daac4fd6da6ff95460d8df44c44976b16ed8`.
- OnePlus 11 SM8550 external graphics module, branch
  `oneplus/sm8550_u_14.0.0_oneplus11`, commit
  `44161778fb115dc464b1f1bfebae012ec544c55e`.

SM8350 and SM8450 contain the complete KGSL `gpu_mem` integration but not GPU
work-period accounting. SM8550 is the first of these OnePlus donors with the
complete Qualcomm per-UID `gpu_work_period` implementation. Wave 22 adapts
that code to the 4.14 in-tree KGSL lifecycle and timer APIs. It intentionally
uses `ktime_get_raw_ns()` instead of the donor's `ktime_get_ns()` because the
Android BPF contract explicitly requires `CLOCK_MONOTONIC_RAW`.

## Wave 22 implementation

Wave 22 ports the established Android/Qualcomm 4.19 KGSL memory-accounting
implementation:

1. `QCOM_KGSL` selects `TRACE_GPU_MEM`, instantiating the standard event that
   is already present in the Miru tree.
2. Each KGSL device owns an atomic device-wide mapped-byte total.
3. Per-process totals come from successful process-pagetable map/unmap updates.
4. Device totals cover ordinary mappings, sparse ranges, and dma-buf imports.
5. A shared dma-buf is added only on its first KGSL import and removed only
   after its final import is destroyed, avoiding double accounting.

Wave 22 also ports the complete SM8550 Qualcomm GPU work-period design rather
than adding a trace-only stub:

1. KGSL shares a reference-counted work-period object between processes with
   the same Android UID.
2. Command-object creation and destruction bound the UID object's active
   lifetime, including submissions that fail before reaching hardware.
3. A6xx command streams capture `CP_ALWAYS_ON_CONTEXT` at the beginning and end
   of each profiled command. Adreno 640 exposes the same registers used by the
   newer driver (`0x982`/`0x983`).
4. Retirement accumulates real 19.2 MHz context-active ticks and excludes
   secure/protected contexts.
5. A 900 ms timer converts ticks to nanoseconds, clamps the value to the period,
   and emits ordered per-UID events with `gpu_id=0` using
   `CLOCK_MONOTONIC_RAW` timestamps.
6. Work-period references are released asynchronously only after the last
   command belonging to that UID is gone.

No eBPF syscall, verifier, JIT, cgroup-BPF, tracefs, bpffs, or SELinux backport
is required.

## Expected runtime interface

After a Wave 22 kernel is deployed, tracefs must expose:

- `/sys/kernel/tracing/events/gpu_mem/gpu_mem_total/enable`
- `/sys/kernel/tracing/events/gpu_mem/gpu_mem_total/filter`
- `/sys/kernel/tracing/events/gpu_mem/gpu_mem_total/format`
- `/sys/kernel/tracing/events/gpu_mem/gpu_mem_total/id`
- `/sys/kernel/tracing/events/gpu_mem/gpu_mem_total/trigger`
- `/sys/kernel/tracing/events/power/gpu_work_period/enable`
- `/sys/kernel/tracing/events/power/gpu_work_period/filter`
- `/sys/kernel/tracing/events/power/gpu_work_period/format`
- `/sys/kernel/tracing/events/power/gpu_work_period/id`
- `/sys/kernel/tracing/events/power/gpu_work_period/trigger`

The `format` file must preserve the offsets consumed by the shipped BPF object:

```text
field:u32 gpu_id; offset:8; size:4
field:u32 pid;    offset:12; size:4
field:u64 size;   offset:16; size:8
```

The work-period `format` file must preserve the shipped BPF object's offsets:

```text
field:u32 gpu_id;                   offset:8;  size:4
field:u32 uid;                      offset:12; size:4
field:u64 start_time_ns;            offset:16; size:8
field:u64 end_time_ns;              offset:24; size:8
field:u64 total_active_duration_ns; offset:32; size:8
```

## Validation criteria

1. The final build config contains `CONFIG_TRACE_GPU_MEM=y` and retains the
   existing Android BPF and tracing options.
2. `System.map` contains `__tracepoint_gpu_mem_total` and
   `__tracepoint_gpu_work_period`; `vmlinux` contains both trace events and the
   KGSL accounting helpers.
3. The live tracepoint format has the exact offsets above.
4. GpuService no longer logs an attachment failure for
   `gpu_mem/gpu_mem_total` and `dumpsys gpu` no longer prints
   `Failed to initialize GPU memory eBPF`.
5. Launching a GPU client creates nonzero global and per-process values; closing
   it removes or reduces the process entry without underflowing the global
   total.
6. GpuService logs `GpuWork: Initialized!`, `dumpsys gpu` prints GPU work
   information, and a GPU client produces a nonzero row for its UID without an
   increasing error count.
7. Consecutive work events for one UID have strictly increasing, nonoverlapping
   raw timestamps; each duration is at most one second and active time never
   exceeds its containing period.
8. Secure/protected GPU work does not increase the UID's active total.
