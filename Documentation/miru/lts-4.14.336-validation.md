# Miru H.40 Linux 4.14.336 validation record

## Status

- Final public release identity: `4.14.336-miru-h40-lts336-ci1+`
- Clean final-identity release-candidate build: **PASS** — run `30854697145`
- Final physical OnePlus 7 Pro test: **PASS** — maintainer-confirmed on 2026-08-04
- Production merge: **PASS** — PR #87 normal merge `253775be7028de96f41ffcf3c5903573ff0b5fb8`
- Permanent production validation: **PASS** — run `30875788887`

## Exact identities and ancestry

| Role | Revision |
|---|---|
| Previous 4.14.305 production head | `a97fcbe96ab6d8392a0a0acf91da46ccb37fdaee` |
| Production 4.14.336 merge | `253775be7028de96f41ffcf3c5903573ff0b5fb8` (PR #87 normal merge) |
| Permanent validation head | `079c3a491e0260bbc795b8a7c2a074c2f40ac355` |
| Permanent 4.14.269 rollback tag | `miru-h40-4.14.269-final` |
| Pristine OnePlus H.40 | `180d787684d5965be5145bcfbf666ed427b4ea18` |
| Android Common 4.14.336 | `014241ad77dda0eafbdf671d5b8e86917d8ec97e` |
| Authentic integration merge | `e0fc49a4660130692e6ac893f8119282b0192b85` |
| Authentic merge parent 1 | `94d2f7f9ac571047c961addbc73aa703b5762293` |
| Authentic merge parent 2 | `014241ad77dda0eafbdf671d5b8e86917d8ec97e` |
| Clean final release-candidate head | `3ed5ff796081bc59f6d36c2f3bb0a5a355d16919` |
| Matching external modules | `3216c08bb3f97f865eb055296ea8034e1744caef` |

The normal production merge has parents `a97fcbe96ab6d8392a0a0acf91da46ccb37fdaee` and `3ed5ff796081bc59f6d36c2f3bb0a5a355d16919`. Its tree is byte-identical to the final candidate tree. The later permanent-validation commit changes only the workflow gate.

## Final candidate validation

- Kernel release: `4.14.336-miru-h40-lts336-ci1+`
- In-tree modules: `13/13`
- External modules: `32/32`
- DTBs: exactly five projects: `18821 19801 19863 18865 18857`
- DTBOs: `0`
- DWC3 semantic audit: `40/40` PASS
- Module source: production branch `oneplus/sm8150_s_12.1_op7pro` at `3216c08bb3f97f865eb055296ea8034e1744caef`
- Candidate full-validation artifact: `8872541554` (`sha256:bd3d3d74135383d3a4c8d48e47484acc5305b793a9188f33c03486349be1cb4b`)
- Candidate package artifact: `8872541095` (`sha256:a7f00718f1a02990ff377d0a8e1c921c44108f777852afd322b6ad105507670f`)

## Physical validation

The maintainer tested the exact final `ci1+` package on the OnePlus 7 Pro and confirmed that everything works. This includes the repaired Qualcomm DWC3 USB/ADB path and the matching external audio module set.

## Permanent production validation

The first automatic run after the normal merge, `30875424322`, stopped safely before packaging because the reused validator still compared the live production ref to the frozen pre-merge SHA. Workflow-only commit `079c3a491e0260bbc795b8a7c2a074c2f40ac355` made that expectation mode-aware and explicitly validates the single allowed workflow-maintenance commit against the real two-parent promotion merge.

Production run `30875788887` then passed source-equivalence, authentic-parent order, cleanup, USB semantics, kernel, five DTBs, 13 in-tree modules, 32 external modules, vermagic, MODVERSIONS, ABI, package assembly and artifact checks.

| Artifact | ID | Digest |
|---|---:|---|
| Production full validation | `8879975156` | `sha256:0cef6d7cfa450de843ef933ede4240daededd26fa402f2449297dd1698b77bd1` |
| Production package | `8879974890` | `sha256:7fda33f4d6ed7c04899e3922ebed262ab476eb91d52c90706cc6797af73fa04e` |

No GitHub Release or new tag was created. The preserved rollback target remains `miru-h40-4.14.269-final`.
