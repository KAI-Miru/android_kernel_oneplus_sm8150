# Miru H.40 Linux 4.14.241 release validation

## Candidate identity

- Production branch before promotion: `miru-h40`
- Immutable production baseline: `cc49ffcb5c5207746618a799b250c67decdc0d15`
- Integration branch: `miru-h40-lts241-integration`
- Android Common stable range: `4.14.211` through `4.14.241`
- Android Common parent/target: `a446f52a5d3fc71698a073d08ce1eeb923727b42`
- Original authentic merge scaffold: `ff895111416c91c1aaf9acf518ca79ac3f66a80b`

The production branch was read and held unchanged while the 4.14.241 source
was resolved and device-tested. The integration preserves the Android stable
history; it is intended to be promoted with a normal merge commit, never by
squash or rebase.

## Source review

- The authentic merge contained 32 conflicts. Each has a focused semantic
  resolution record in `Documentation/miru/lts-4.14.241-conflicts.md`.
- `kernel/cgroup/cgroup.c` is a no-source-delta resolution: the downstream
  implementation was intentionally retained rather than edited.
- A later dma-buf correction restores the downstream ownership and release
  lifecycle. It prevents freeing an aliased `name`/`buf_name` twice and moves
  list removal back to file release.
- The LineageOS-backed GLINK missing-channel FIFO advance remains in
  `qcom_glink_handle_intent()`.

## QRTR boot correction

The actual boot-blocking semantic merge defect was in `net/qrtr/qrtr.c`.
`alloc_skb_with_frags()` allocated the downstream SKB and established its
fragment/backup lifetime. A later upstream `__netdev_alloc_skb()` allocation
overwrote that result. Commit
`47f4767bd9040d574664d5b93abe3a54b97aa4e2` removes only that second
allocation and retains the downstream `alloc_skb_with_frags()` /
`qrtr_get_backup()` path.

## GLINK decision

An experimental workaround changed a consumed GLINK RX `-ENOENT` result to
success in the IRQ loop. It was not supported by the LineageOS references and
was removed by `935b66cf9ef5bcbd40063e830935744b35a3d5cf`
(`rpmsg: restore GLINK RX error propagation`). That commit changes only
`drivers/rpmsg/qcom_glink_native.c`; normal RX error propagation is retained.

## Exact-source kernel build

| Item | Recorded result |
|---|---|
| GitHub Actions run | `29967983528` |
| Source commit | `935b66cf9ef5bcbd40063e830935744b35a3d5cf` |
| Kernel release | `4.14.241-miru-h40-lts241-qrtr-ci6+` |
| Kernel artifact | `miru-h40-lts-4.14.241-qrtr-ci6-build` — ID `8548812175` |
| Kernel digest | `sha256:c1a7b97368547b3fcb4a7b1abbd8de1cdc9e0549b5d7a7c13c6cf18d665d8e82` |
| Diagnostics artifact | `miru-h40-lts-4.14.241-qrtr-ci6-diagnostics` — ID `8548812492` |
| Diagnostics digest | `sha256:dad5dbce73723bcb7dfbee5ac2d0256b7a834572ecb09b71cf0625d05996c0d9` |

The Actions job is red only because its final temporary-workflow cleanup step
failed. The exact-source verification, clean kernel compilation, kernel upload,
and diagnostics upload all succeeded before that step.

## OnePlus 7 Pro result

The exact `ci6` kernel booted successfully on a real OnePlus 7 Pro. Earlier
candidates boot-looped at the splash screen and eventually entered TWRP. This
confirms the QRTR correction plus restored GLINK error propagation as the
device-tested source state.

The established H.40 device paths remain present: WLAN, the applicable audio
stack, modem IPC, storage, display, touch, charging and suspend/resume. This is
not a claim of new performance or battery behavior.

## External modules observed on the phone

The boot test used the existing 32-module `ci4` package:

```text
4.14.241-miru-h40-lts241-ci4+ SMP preempt mod_unload modversions aarch64
```

The running kernel reported:

```text
4.14.241-miru-h40-lts241-qrtr-ci6+
```

This is a valid compatibility result because `CONFIG_MODVERSIONS=y` is enabled.
In `kernel/module.c`, `same_magic()` ignores the release-string field when CRCs
are present; imported/exported symbol CRCs continue to be checked individually.
WLAN and the complete applicable audio stack loaded normally, with no `version
magic`, `Unknown symbol`, `disagrees about version`, invalid-module, or
exec-format errors.

This verifies ABI compatibility of the tested `ci4` package with the booting
`ci6` kernel. It does not represent a device test of a newly built matching
module package.

## Production publication rule

The permanent 4.14.241 workflow must rebuild the kernel and exactly 32 external
modules from the pinned vendor source
`125ff7d0153cbb3aaa8f9fd618c33b7f728d7798`, verify the
`scripts/Makefile.build` blob
`ee3b37a3bf6a586b74fe00f9e39ca5e77f08b6d3`, require zero ABI errors, and
upload the kernel output, module drop-in, diagnostics, and checksums. If its
release suffix differs from `ci6`, it is a newly built production candidate and
is not implicitly covered by the `ci6` phone test.

## Release decision

The 4.14.241 source is approved for production promotion after the permanent
workflow passes for the pull-request head. The promotion must use a merge commit
and must be followed by the same permanent workflow on the actual merge commit.
