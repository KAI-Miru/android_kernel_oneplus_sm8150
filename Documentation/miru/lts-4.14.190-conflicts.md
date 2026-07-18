# Miru H.40 to Android 4.14.190 conflict ledger

This file tracks the initial Android stable 4.14.190 merge scaffold.

- H.40/Miru parent: the branch tip before merge commit `5d8cba39fefb935c6feaf30ea1a57dfffa80273a`
- Android stable parent: `d2d05bcf4b4edf8d028fa420dee3c6644aa5b4ac`
- Cleanly merged paths: accepted from Git's three-way merge
- Conflicted paths: temporarily preserved from the H.40/Miru parent
- Kernel version after the scaffold: `4.14.190`
- Status: **incomplete and not suitable for building or flashing**

Each path below must receive an explicit follow-up resolution before the
milestone can be considered integrated:

```text
Documentation/devicetree/bindings/usb/dwc3.txt
arch/x86/kernel/cpu/bugs.c
drivers/block/virtio_blk.c
drivers/md/dm-default-key.c
drivers/mmc/core/Kconfig
drivers/mmc/core/block.c
drivers/mmc/host/sdhci-msm.c
drivers/net/ethernet/stmicro/stmmac/stmmac.h
drivers/net/ethernet/stmicro/stmmac/stmmac_ethtool.c
drivers/net/ethernet/stmicro/stmmac/stmmac_main.c
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
include/linux/mod_devicetable.h
include/net/netfilter/nf_conntrack.h
include/uapi/linux/input-event-codes.h
mm/huge_memory.c
net/ipv4/sysctl_net_ipv4.c
net/qrtr/qrtr.c
sound/core/compress_offload.c
sound/core/rawmidi.c
```
