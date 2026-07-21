# Miru H.40 Linux 4.14.210 release validation

## Production release

- Kernel release: `4.14.210-miru-h40-lts210-ci1+`
- Production branch: `miru-h40`
- Production merge: `f78e220d9b5b49fb309b25877f6f423e5eb4f55e`
- Pull request: `#24`
- Android stable range: 4.14.191 through 4.14.210
- Production integration base: `40a2cb6fcf0411c100a7aaa609e128705a0bc2d8`
- Android stable parent: `39a7f9a39c0bd6d0f67869df227f6fa23286edd2`
- Device-tested source head: `548efae59678abf8d9c1711df2a688a17a364f81`
- Final pull-request head: `b265cd1f4f77b0cfe117d46adb7d18ac90821da2`

## Source integration

- Initial authentic semantic conflicts: `19`
- Explicitly resolved semantic conflicts: `19`
- Remaining semantic conflicts: `0`
- Index-level unmerged entries: `0`
- Authentic Android-stable merge ancestry retained: **yes**

Detailed conflict decisions are recorded in `Documentation/miru/lts-4.14.210-conflicts.md`.

## Build validation

The integration build from `fix: use shared block sector size in dm-bow` completed successfully in the temporary 4.14.210 workflow as run #4.

The final production pull-request workflow completed successfully as run #8 (`29792358348`) against head `6e7c1d66740cef5152a07f22b4df9ab25463c42d`.

Successful gates:

- source sanity and merge-ancestry validation;
- clean 4.14.210 kernel build;
- five production DTBs;
- configured in-tree modules;
- complete 32-module Miru v3 external-module rebuild;
- external-module dependency, vermagic, imported-symbol and MODVERSIONS CRC audits;
- kernel, module and diagnostic artifact publication.

Published artifacts from run #8:

- `miru-h40-lts-4.14.210-ci1-build`;
- `miru-h40-lts-4.14.210-ci1-diagnostics`;
- `miru-v3-modules-dropin-4.14.210`;
- `miru-v3-modules-dropin-4.14.210-diagnostics`.

## Device validation

Date: **2026-07-20**

Device: **OnePlus 7 Pro (`guacamole`)**

Userspace: **ColorOS 14 port with H.40 vendor and ODM**

Tested build source: `548efae59678abf8d9c1711df2a688a17a364f81` (`fix: use shared block sector size in dm-bow`).

Result:

- phone booted successfully;
- all Miru v3 modules loaded;
- normal device functionality was confirmed working;
- no regression was reported in the validated DT2W, smart-PA/audio, AOD, fingerprint/display, WLAN, storage, modem IPC, suspend/resume or charging paths.

All commits after the tested source head modified only CI or documentation. The runtime kernel source promoted by pull request #24 is therefore the same source that passed device validation.

## Release decision

The 4.14.210 milestone passed source integration, complete kernel/module CI and OnePlus 7 Pro device validation. Pull request #24 was merged into the permanent `miru-h40` production branch with merge commit `f78e220d9b5b49fb309b25877f6f423e5eb4f55e` on 2026-07-21.

The temporary integration workflow was removed before the merge. The permanent `.github/workflows/miru-h40-build.yml` workflow is now the sole production kernel-and-modules workflow.
