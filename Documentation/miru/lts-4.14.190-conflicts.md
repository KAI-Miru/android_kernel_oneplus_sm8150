# Miru H.40 to Android 4.14.190 conflict ledger

This file tracks explicit resolutions following the initial Android
stable 4.14.190 merge scaffold.

- H.40/Miru scaffold merge: `5d8cba39fefb935c6feaf30ea1a57dfffa80273a`
- Android stable parent: `d2d05bcf4b4edf8d028fa420dee3c6644aa5b4ac`
- Initial deferred conflicts: 28
- Resolved conflicts: 28
- Remaining conflicts: 0
- Status: **incomplete and not suitable for building or flashing as a release**

## Resolved in Step 1

The following non-target architecture, non-target hardware, and
documentation paths now exactly match Android 4.14.190:

```text
Documentation/devicetree/bindings/usb/dwc3.txt
arch/x86/kernel/cpu/bugs.c
drivers/block/virtio_blk.c
drivers/net/ethernet/stmicro/stmmac/stmmac.h
drivers/net/ethernet/stmicro/stmmac/stmmac_ethtool.c
drivers/net/ethernet/stmicro/stmmac/stmmac_main.c
```

Resolution commit:

```text
ef0ad709bdbc098fd98f02eeaacc04e47255762a
lts: resolve non-target architecture and documentation conflicts
```

## Resolved in Step 2

The module matching and input ABI conflicts use the LineageOS SM8150
4.14.190 resolution from `0190a01fb1cde1c2ba48e7836084bad818c14d94`:

```text
include/linux/mod_devicetable.h
include/uapi/linux/input-event-codes.h
```

This preserves the H.40 GPR, SoundWire, Slimbus and MHI device-table
structures and `INPUT_DEVICE_ID_SW_MAX=0x20`, while adding the stable
x86 stepping field. All existing H.40 input codes retain their numeric
values. `SW_MACHINE_COVER` is added at the unused value `0x14`, avoiding
collisions with H.40 headset switch values `0x10` through `0x13`.

Resolution commit:

```text
247d219b2140ee4745a96d72f327a2654e06c24e
lts: resolve module matching and input ABI conflicts
```

## Resolved in Step 3

The block core and device-mapper encryption conflicts were resolved as one
boot-critical unit:

```text
drivers/md/dm-default-key.c
fs/block_dev.c
include/linux/fs.h
```

`dm-default-key.c` remains byte-for-byte H.40 because it is a strict functional
superset of the Android stable version. This preserves the legacy `AES-256-XTS`
syntax conversion, wrapped-key handling, the accepted `set_dun` option, and the
legacy `mmcblk0` 512-byte sector compatibility path.

`block_dev.c` preserves the Oplus I/O-monitor hooks while applying Android
stable commit `a43abf15844c9e5de016957b8e612f447b7fb077`'s delayed `bdput(bdev)`
placement, fixing a `blkdev_get()` error-path use-after-free. The two
`blk_queue_enter()` boolean arguments are also updated from `0` to `false`.

`fs.h` preserves H.40's `RWF_APPEND`, file-table debugging, mount-aware
tmpfile API, `umount_end`, and runtime filesystem-list interfaces. It adopts
the stable flexible-array declaration `f_handle[]` in place of the zero-length
array `f_handle[0]`.

Resolution commit:

```text
715ff54e56da56f94eac62e4eb16725e7837a1aa
lts: resolve block core and dm-default-key conflicts
```

## Resolved in Step 4

The fscrypt, F2FS and IncFS conflicts were resolved as one storage-consistency
unit:

```text
fs/crypto/inline_crypt.c
fs/crypto/keyring.c
fs/f2fs/checkpoint.c
fs/incfs/data_mgmt.c
```

`inline_crypt.c` preserves H.40's private-mode UFS/SDHCI DUN sizing, ext4
crypto-context flag and defensive direct-I/O check. It adds Android stable's
IV_INO_LBLK_32/sub-page exclusion before inline encryption is selected.

`keyring.c` uses Android stable's separated `do_add_master_key()` flow,
hardware-wrapped-key validation and per-boot test-dummy key support. H.40's
five-attempt raw-secret derivation workaround is retained without its temporary
error-path debug spam.

`checkpoint.c` adopts `f2fs_kvzalloc()`, inline-data flushing, active metadata
writeback while waiting, and CP_RESIZE mutex handling. H.40's UFSTW checkpoint
turbo-write hooks remain active.

`data_mgmt.c` remains byte-for-byte H.40. The surrounding `format.c`,
`format.h` and `vfs.c` still use the mount-aware `backing_file_context` API, so
taking Android stable's newer file-based calls would create a source-level ABI
mismatch. H.40's signature ownership and explicit `df_signature` cleanup are
therefore retained.

Resolution commit:

```text
327465ec7fc88d85aa12124ee9c7090e0fa66071
lts: resolve fscrypt f2fs and incfs conflicts
```

## Resolved in Step 5

The MMC core, MMC block path, host ABI and Qualcomm SDHCI driver were resolved
as one request/host compatibility unit:

```text
drivers/mmc/core/Kconfig
drivers/mmc/core/block.c
drivers/mmc/host/sdhci-msm.c
include/linux/mmc/host.h
```

`Kconfig` adds the Android stable generic `MMC_CRYPTO` option while preserving
H.40's ring-buffer, deferred-resume, clock-gating and speed-simulation options.
The H.40 target configuration does not enable this generic option, so its
shipping structure layout and legacy Qualcomm CMDQ/ICE path remain unchanged.

`block.c` adds generic `mmc_crypto_prepare_req()` request metadata preparation.
All H.40 legacy CMDQ, RPMB, timeout-abnormality detection, stuck-program-state,
capacity reporting and vendor command-class compatibility behavior is retained.

`host.h` adds the unused bit-1 `MMC_CAP2_CRYPTO` capability and the generic
keyslot-manager fields under `CONFIG_MMC_CRYPTO`. H.40's vendor timeout tracking,
card-detection retry, programming-state, devfreq, CMDQ and inline-crypto fields
remain in place.

`sdhci-msm.c` applies the stable HS400 re-initialization fix by clearing
`tuning_done` before re-tuning, and enables the controller's supported automatic
CMD12 handling for multiblock reads. Qualcomm bus voting, PM QoS, register
save/restore, reset workarounds and QTI CMDQ crypto integration are preserved.

Resolution commit:

```text
7443ab8fc7f0e58cff5c0280bd20685d73ce869f
lts: resolve MMC core and SDHCI-MSM conflicts
```

## Resolved in Step 6

The Qualcomm UFS conflict was resolved as a minimal atomic-context safety
backport:

```text
drivers/scsi/ufs/ufs-qcom.c
```

The file retains the complete H.40 implementation, including QTI ICE setup,
secure-configuration restoration, retained ICE clock memory, bus voting,
per-CPU PM QoS, clock scaling, regulator control, PHY reset/calibration,
full-controller reset, debugfs and suspend/resume behavior.

Android stable commit `291ae253fb695258fbdf2d73f5f37b43f597e537`
(upstream `3be60b564de49875e47974c37fabced893cd0931`) is applied to
`ufs_qcom_dump_dbg_regs()`: five `usleep_range(1000, 1100)` calls are replaced
with `udelay(1000)` because this diagnostic path can be reached from interrupt
and other atomic contexts. No other UFS behavior is changed.

Resolution commit:

```text
643a93c1ff8dca9f4f28cb8e005826a008cf6662
lts: resolve Qualcomm UFS atomic dump conflict
```

## Resolved in Step 7

The USB composite core and legacy UAC1 conflicts were resolved as one gadget
compatibility unit:

```text
drivers/usb/gadget/composite.c
drivers/usb/gadget/function/f_uac1_legacy.c
```

`composite.c` adopts Android stable commit
`0c8c366c54f07f70d03260db9e0faa52f8d65749` (upstream
`5d363120aa548ba52d58907a295eee25f8207ed2`). The new
`config_ep_by_speed_and_alt()` selects the interface descriptor for the
requested alternate setting before locating its endpoint and SuperSpeed
companion descriptor. The existing `config_ep_by_speed()` API remains as an
alternate-setting-zero wrapper. H.40's Qualcomm boot-stat include, EP0 length
clamping, OS-descriptor bounds validation, zeroed control-buffer allocation,
resume marker and composite setup/disconnect behavior are preserved.

`f_uac1_legacy.c` remains byte-for-byte H.40 and already matches the Lineage
4.14.190 resolution. Its expanded driver protects `play_queue` insertion and
removal with the dedicated `playback_lock`, satisfying stable commit
`c0689058968d4cf756d1fe887c62dc57edcefbc0` (upstream
`8778eb0927ddcd3f431805c37b78fa56481aeed9`) without introducing the generic
upstream driver's unrelated `audio->lock` layout. Capture locking, real-time
packet-drop policy and ColorOS legacy audio descriptors remain unchanged.

Resolution commit:

```text
98ef978aa19abe7ab4f1463c41e3f86312ac6bb1
lts: resolve USB composite and legacy UAC1 conflicts
```

## Resolved in Step 8

The conntrack ABI marker, IPv4 sysctl registration and Qualcomm QRTR conflict
were resolved as one networking compatibility unit:

```text
include/net/netfilter/nf_conntrack.h
net/ipv4/sysctl_net_ipv4.c
net/qrtr/qrtr.c
```

`nf_conntrack.h` applies stable commit
`7addf56d9a45e8601b726a7efbcbe75713a15e91` (upstream
`2c407aca64977ede9b9f35158e919773cae2082f`), replacing the zero-length
`__nfct_init_offset[0]` marker with an empty structure so GCC 10 does not emit
an out-of-bounds warning. H.40's Oplus application UID, SFE pointer, SIP
segmentation state, NATTYPE field and protocol tail remain in their original
order and continue to be covered by the existing allocation-time `memset()`.

`sysctl_net_ipv4.c` applies Android commit
`08870bd1a24fc7f3ae4ff30bc7e64c09edd931d4`, moving
`tcp_default_init_rwnd` from the global IPv4 table into `ipv4_net_table` and
using `proc_dointvec_minmax` with limits 3 through 100. This makes the Android
sysctl use the existing per-network-namespace field. H.40's delayed-ACK,
user-config, reserved-port, timestamp-control and random-timestamp sysctls are
preserved.

`qrtr.c` applies stable commit `33fe397c18f4788232793f3fbf5d3156f3100b6f`
(upstream `6dbf02acef69b0742c238574583b3068afbd227c`) by passing `NULL` to the
local leg after broadcast endpoint iteration instead of reusing the loop's
last node pointer. H.40's modem wake accounting, service matching, IPC logging,
emergency skb backup pools, multi-node forwarding and socket-orphan release
ordering remain unchanged.

Resolution commit:

```text
fdf8bc143cc6e6a911d645e0f2eb4b025ce6e3cd
lts: resolve conntrack IPv4 sysctl and QRTR conflicts
```

## Resolved in Step 9

The transparent-hugepage conflict was resolved as a minimal control-flow repair:

```text
mm/huge_memory.c
```

Android stable commit `3b6c93db0a02b843694cf91f8bacd94f8e7259c8`
(upstream `c444eb564fb16645c172d550359cb3d75fe8a040`) serializes the THP
mapcount transfer performed by `__split_huge_pmd_locked()` with the compound
page lock. H.40 already carried most of this backport, but its conflicted
`__split_huge_pmd()` block left the page-lock closing brace misplaced and
therefore evaluated `PageMlocked(page)` outside the `pmd_trans_huge()` branch.
That could dereference a non-THP or absent page when handling devmap or migration
PMDs.

The corrected function exactly matches the Lineage SM8150 4.14.190 merge result:
it retains the caller-supplied locked-page validation, retries safely if the PMD
changes while acquiring the page lock, limits mlock clearing to real THPs, and
continues to permit devmap and migration entries to reach
`__split_huge_pmd_locked()` without touching a normal `struct page`.

H.40's older `vm_fault` fields and `maybe_mkwrite(..., vm_flags)` API are
preserved in both unrelated conflict regions. No other THP allocation, collapse,
copy, migration, zero-page, deferred-split or khugepaged behavior is changed.

Resolution commit:

```text
15ac7e5128349f446221947fa7947433e962f1bd
lts: resolve transparent hugepage split conflict
```

## Resolved in Step 10

The ALSA compressed-offload and raw-MIDI conflicts were resolved as one audio
core compatibility unit:

```text
sound/core/compress_offload.c
sound/core/rawmidi.c
```

`compress_offload.c` applies stable commit
`0a117d00e86fe6ec856e72548e405169ab9dc78d` (upstream
`f79a732a8325dfbd570d87f1435019d7e5501c6d`). Partial drains are marked before
the DSP trigger so `snd_compr_drain_notify()` returns the stream to RUNNING,
and STOP clears both partial-drain and metadata state before waking waiters.
The resulting file exactly matches the Lineage SM8150 4.14.190 merge while
preserving H.40's next-track parameter ioctl, simple-ioctl split, error work and
exported `snd_compress_free()` interface.

`rawmidi.c` applies stable commits `8645ac3684a70e4e8a21c7c407c07a1a4316beec`
(upstream `c1f6e3c818dd734c30f6a7eeebf232ba2cf3181d`) and
`e8e3fcbc66f608d38a72fc716ff45e31b7f3d123` (upstream
`5a7b44a8df822e0667fc76ed7130252523993bda`). Runtime buffer accesses now carry
a spinlock-protected reference while user copies temporarily drop the lock, and
new buffers are zero-initialized.

The raw-MIDI resize resolution is intentionally stricter than the mechanical
Lineage merge. H.40's `realloc_mutex` is preserved, but resize allocates a
separate zeroed buffer before taking the runtime spinlock. If a buffer user is
active, the new allocation is freed, IRQ flags and the mutex are restored, and
`-EBUSY` is returned. This avoids calling downstream `__krealloc()` on a live
buffer before the stable busy check and avoids the incomplete early-return
cleanup present in the mechanical merge. Successful resize atomically swaps the
buffer and resets stream pointers only after drain has completed.

Resolution commit:

```text
lts: resolve ALSA compress and rawmidi conflicts
```

## Remaining deferred conflicts

None. All 28 merge conflicts now have explicit source-level resolutions. The
branch remains unsuitable for release until the full build, symbol/ABI audit and
device validation are complete.
