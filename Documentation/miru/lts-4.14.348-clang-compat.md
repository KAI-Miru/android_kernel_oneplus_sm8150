# Miru H.40 Linux 4.14.348 pinned-Clang compatibility review

## Boundaries

- Genuine stage-3 merge: `2be978e53f5bddc97eb1ebc2a8da987b1c762b1f`
- Exact OpenELA second parent: `ef4cb0aa8addc73e6257039a17061cb1766b7477`
- Pinned production Clang repository commit: `252aba16f513a857bc923172f67b0e55e23de35f`
- Pinned compiler directory: `clang-r377782c`
- Immutable production: `eb9451c0a1639e1aa49ee094681f98df0545f797`
- External modules pin: `3216c08bb3f97f865eb055296ea8034e1744caef`

## Finding

The OpenELA 4.14.344 to 4.14.348 range added these flags directly to `scripts/Makefile.extrawarn` for Clang builds:

- `-Wno-enum-compare-conditional`
- `-Wno-enum-enum-conversion`

They are warning groups from a newer Clang generation and are not understood by Miru H.40's pinned `clang-r377782c`. Miru's compiler wrapper promotes the resulting unknown-warning diagnostic to failure. Because kernel `cc-option` probes inherit `KBUILD_CFLAGS`, the first visible error was misleadingly reported by `prepare-compiler-check` as unsupported `-fstack-protector-strong`, even though a direct pinned-compiler probe confirmed stack-protector support.

This was a cleanly merged, non-textual compatibility issue. It was not one of the four stage-3 merge conflicts.

## Resolution

Commit `cf6da7a583920c5923c7f55ebb803b2007e11109` preserves both suppressions but changes them to the kernel's feature-tested form:

```make
KBUILD_CFLAGS += $(call cc-disable-warning, enum-compare-conditional)
KBUILD_CFLAGS += $(call cc-disable-warning, enum-enum-conversion)
```

`cc-disable-warning` tests the positive warning option with `-Werror` and emits the negative suppression only when the compiler recognizes that warning group. Newer Clang versions therefore retain the intended suppression, while Miru's pinned Clang omits unsupported flags.

Classification: **adapted**.

## Validation requirements

- Preserve `2be978e53f5b...` as the genuine OpenELA stage-3 merge boundary.
- Build a source descendant containing only this compatibility delta relative to the merge before CI-only files.
- Verify both warning suppressions use `cc-disable-warning` and neither raw flag remains.
- Run the direct `-fstack-protector-strong` probe through the pinned Clang and Miru compiler wrapper.
- Run `olddefconfig`, `prepare`, and `modules_prepare`.
- Compile the stage-3 affected objects plus DWC3 and QRTR preservation probes.
- Confirm the exact 4.14.348 OpenELA/Miru release identity.
- Do not write production or the external-modules branch.
