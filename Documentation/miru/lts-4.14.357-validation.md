# Miru H.40 OpenELA Linux 4.14.357 validation record

## Status

- Final public release identity: `4.14.357-openela-miru-ci1+`
- Production promotion: **PASS** — PR #88 normal merge `50313dfbd4e8c369a04d6400c140c23909267021`
- Final candidate build: **PASS** — run `30996359788`, job `92274276122`
- Physical OnePlus 7 Pro validation: **PASS** — normal boot and operation confirmed
- Output classification: non-empty raw `Image.gz-dtb`; this record does not claim a packaged boot image.

## Exact identities and provenance

| Item | Value |
|---|---|
| Previous production merge | `253775be7028de96f41ffcf3c5903573ff0b5fb8` (Linux 4.14.336) |
| Validated Stage 357 source | `24626c96027f0bfc4431741ee0d249826a286293` |
| Stage 357 Miru parent | `a6aa49e75e8345027ea90b95858df682068d3a0e` |
| Exact OpenELA second parent | `1e6347375d088ecc896aabb067131d0f9e3c0575` |
| Production merge | `50313dfbd4e8c369a04d6400c140c23909267021` |
| Compiler | `clang-r377782c` at `252aba16f513a857bc923172f67b0e55e23de35f` |
| External-module base | `3216c08bb3f97f865eb055296ea8034e1744caef` |
| External-module repair / production head | `c03a4c6339b959f1a9b288a157d5b5d16fbcf015` |

The Stage 357 source commit has the required real merge topology: its first parent is the Miru integration parent and its second parent is the exact OpenELA 4.14.357 target.

## Final candidate validation

- Artifact: `4.14.357-openela-miru-ci1-kernel-and-modules` (artifact ID `8927175846`, 227,227,603 bytes).
- Raw kernel candidate: `4.14.357-openela-miru-ci1+-Image.gz-dtb`, 19,101,303 bytes.
- Kernel release and Linux banner: `4.14.357-openela-miru-ci1+`.
- The artifact verifies Linux `4.14.357`, `EXTRAVERSION=-openela`, exact compiler identity, source topology and unchanged pre-promotion production boundary.

## Matching external modules

- 32 external modules were built from the matching module source.
- ABI report: `errors=0`.
- All modules carry the expected 4.14.357 OpenELA Miru vermagic.
- The obsolete module source SHA `125ff7d0153cbb3aaa8f9fd618c33b7f728d7798` was not used.

## Downstream trace cleanup

The matching module source removes the Oplus ext4 and UFS `trace_printk()` diagnostics. The final artifact records:

```
trace_printk_format_entries=0
trace_printk_format_bytes=0
```

Physical testing confirmed that the boot-time trace-printk / DEBUG-kernel warning disappeared. This avoids the trace-buffer preallocation caused by those retained debug calls.

## Production promotion

PR #88 was marked ready only after the candidate and device checks completed, then merged normally into `miru-h40`. The release-specific workflows were retired after promotion so they cannot be reused to build a misleading legacy 4.14.336 candidate.
