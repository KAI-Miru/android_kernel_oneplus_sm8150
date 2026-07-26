# Miru H.40 4.14.269 production validation

Status: **production merged and device-confirmed**.

This is the final validation record for the Android Common 4.14.242–4.14.269 integration and the later KCAL display-calibration follow-on. It distinguishes the exact device-tested LTS source from the later KCAL source because both intentionally use the same pinned ci3 release suffix.

## Production history

| Item | Value |
|---|---|
| 4.14.241 production parent | `4394ccbfa3805ce392b65b3ea148ff1eb084a974` |
| Android Common parent / target | `a446f52a5d3fc71698a073d08ce1eeb923727b42` → `0eec6f6001d15bb1108835a642ec4637d75eef19` |
| Exact LTS source built and device-tested | `14d41d8a57b1e08aa15ff786973b855c78f58fd7` |
| 4.14.269 production merge | `eb1cc39f93fb080c9903ffdba48f432ab0ac2b7b` (PR #68) |
| KCAL source built and validated | `5c21d9d15ac7228837f9cb63de3061bb6b383a5d` |
| KCAL production merge | `c8107343ced9e589447aa29f8c025425bd148b0a` (PR #69) |
| Current production branch | `miru-h40` |

## Exact LTS build validation

- GitHub Actions run: [30197447946](https://github.com/KAI-Miru/android_kernel_oneplus_sm8150/actions/runs/30197447946)
- Result: **PASS**
- Compiler: Android Clang 10.0.5 / r377782c
- Kernel release: `4.14.269-miru-h40-lts269-14d41d8-ci3+`
- Vermagic: `4.14.269-miru-h40-lts269-14d41d8-ci3+ SMP preempt mod_unload modversions aarch64`
- Kernel: successful Image, Image.gz, Image.gz-dtb, five DTBs, and 13 configured in-tree modules.
- External modules: exactly **32** `.ko` files from `KAI-Miru/android_kernel_modules_and_devicetree_oneplus_sm8150@125ff7d0153cbb3aaa8f9fd618c33b7f728d7798`.
- ABI report: **0 errors**; all 32 matching module vermagic checks passed and the module-set diff was empty.
- `scripts/Makefile.build` integrity hash: `ee3b37a3bf6a586b74fe00f9e39ca5e77f08b6d3`.
- Source gates: Android Common ancestry, clean diff, no unmerged paths, no source conflict markers, the QRTR allocation/lifetime correction, and normal GLINK error propagation all passed.

### LTS artifacts

| Artifact | ID | SHA-256 digest |
|---|---:|---|
| Kernel build: `miru-h40-lts-4.14.269-14d41d8-ci3-build` | `8630770373` | `sha256:0166e18df8158045f51ae168f8a5ebc8d339a70875cdfb5570588cedf5154152` |
| Matching module drop-in: `miru-v3-modules-dropin-4.14.269-14d41d8-ci3` | `8630770614` | `sha256:2fabd3ed8de1388b58dd5d3cf292cb3392f1dbe76a5d9f0bdf34f285c4f4fde4` |
| Diagnostics | `8630770804` | `sha256:958b35219b6dcf1257032ead6f23caeea50ca231e2535a07aa781557a973c5c2` |

## KCAL follow-on validation

KCAL was added after the LTS merge. It provides the `kcal`, `kcal_enable`, and `kcal_min` RGB calibration controls through the SDE DSPP PCC pipeline. It scales only the intended PCC diagonal coefficients, preserves userspace PCC data, performs a safe DRM lifecycle teardown, and schedules an immediate atomic display refresh.

- GitHub Actions run: [30204348781](https://github.com/KAI-Miru/android_kernel_oneplus_sm8150/actions/runs/30204348781)
- Result: **PASS** — full kernel and exactly 32 external modules built with ABI-report errors `0`.
- Modified KCAL files: no compiler warnings reported.
- Kernel artifact ID `8632871821`; digest `sha256:f7a437ba97febe2238fd2599e0896ae47daeeec4981540641abd90594fc4822e`.
- Module artifact ID `8632871935`; digest `sha256:7bdd0a0ea667e498d788f7a3419a4f451234c565e7bf75a2165f4889b3487fb6`.
- Diagnostics artifact ID `8632872029`; digest `sha256:b9d7f62054ead8f77e2cc6d4ca3d0f7bdc82f4a53a933ca6f305a102c7961e34`.

## Release identity and module ABI

The ci3 release string is deliberately pinned in the reproducible workflow. The LTS build from `14d41d8a57b1e08aa15ff786973b855c78f58fd7` and the KCAL validation build from `5c21d9d15ac7228837f9cb63de3061bb6b383a5d` therefore share `4.14.269-miru-h40-lts269-14d41d8-ci3+`. This is intentional, not a claim that both sources are bit-identical. Use the source SHA and artifact ID for exact identity.

`CONFIG_MODVERSIONS` is enabled. The matching module builds verify individual exported-symbol CRCs as well as the expected release/vermagic, which is why the ABI report's zero-error result matters. The device confirmation covers the kernel's normal operation; it does not claim that a separately rebuilt KCAL module package was independently flashed unless that exact package is identified by source and artifact.

## Real-device validation

- Device: OnePlus 7 Pro.
- LTS release flashed: `4.14.269-miru-h40-lts269-14d41d8-ci3+`.
- Result: maintainer confirmed successful boot and normal operation on 2026-07-26, then reconfirmed on 2026-07-27.
- KCAL: maintainer confirmed the KCAL kernel working on device before PR #69 merged.

## Production and workflow cleanup

- PR #68 and PR #69 were normal merge commits; Android stable integration history was neither squashed nor rebased.
- Production was unchanged during 4.14.269 integration, then advanced by PR #68; KCAL followed through PR #69.
- The current production tree contains only `.github/workflows/miru-h40-build.yml`. It is the permanent 4.14.269 kernel-and-modules workflow.
- The merge and documentation commits use `[skip ci]` because their exact runtime source had already passed dedicated compilation and artifact validation. No duplicate compilation is represented as a post-merge validation result.
- The completed 4.14.269 integration and helper branches were deleted after promotion; the normal merge history, permanent conflict ledger, validation record, and artifact references remain as the audit record.
