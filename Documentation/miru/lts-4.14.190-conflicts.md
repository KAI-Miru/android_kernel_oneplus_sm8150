# Miru H.40 to Android 4.14.190 conflict ledger

This file tracks explicit resolutions following the initial Android
stable 4.14.190 merge scaffold.

- H.40/Miru scaffold merge: `5d8cba39fefb935c6feaf30ea1a57dfffa80273a`
- Android stable parent: `d2d05bcf4b4edf8d028fa420dee3c6644aa5b4ac`
- Initial deferred conflicts: 28
- Resolved conflicts: 8
- Remaining conflicts: 20
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
lts: resolve module matching and input ABI conflicts
```

## Remaining deferred conflicts

```text
drivers/md/dm-default-key.c
drivers/mmc/core/Kconfig
drivers/mmc/core/block.c
drivers/mmc/host/sdhci-msm.c
drivers/scsi/ufs/ufs-qcom.c
drivers/usb/gadget/composite.c
drivers/usb/gadget/function/f_uac1_legacy.c
fs/block_dev.c
fs/crypto/inline_crypt.c
fs/crypto/keyring.c
fs/f2fs/checkpoint.c
fs/incfs/data_mgmt.c
include/linux/fs.h
include/linux/mmc/host.h
include/net/netfilter/nf_conntrack.h
mm/huge_memory.c
net/ipv4/sysctl_net_ipv4.c
net/qrtr/qrtr.c
sound/core/compress_offload.c
sound/core/rawmidi.c
```
