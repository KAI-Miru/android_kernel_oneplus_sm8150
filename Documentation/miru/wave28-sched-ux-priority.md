# Wave 28: Android 14 ordered UX priority scheduling

Wave 28 ports the complete `CONFIG_OPLUS_FEATURE_SCHED_UX_PRIORITY` path from
the authoritative OnePlus 9R Android 14 kernel and external-module sources.
This is a scheduler-behaviour wave, not a new pathname-only ABI wave.

The 9R implementation replaces the older vruntime-bias/list-pick path with a
per-runqueue ordered UX list. It adds:

- explicit priority bits in the existing per-task `ux_state` control;
- ordered enqueue/dequeue and fair-class next-task replacement;
- wakeup-preemption decisions between UX and non-UX tasks;
- four-millisecond execution slices with donor per-type budgets;
- inherited and one-shot UX expiry handling;
- optional per-CPU priority trace markers through the existing debug gate.

The port includes every matching core-scheduler call site, the task and
runqueue state, fork initialization, rq-locked state transitions, and the
matching external `sched_assist` implementation. The old placement and pick
helpers remain compiled as the disabled-config fallback, but are not run when
ordered priority scheduling is selected.

`CONFIG_OPLUS_FEATURE_SCHED_UX_PRIORITY` is enabled in both Miru SM8150
defconfigs and the reconstructed H.40 build configuration, matching both 9R
Kona production configurations. No DLKM is added; the implementation remains
built into the existing sched_assist path.
