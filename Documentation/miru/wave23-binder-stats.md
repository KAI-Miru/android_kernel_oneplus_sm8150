# Wave 23: Android 14 MIDAS Binder accounting

The ported OnePlus 9R PowerStats implementation contains a hard-coded
`/dev/binder_stats` consumer, and the exact 9R vendor policy and uevent rules
already label that device. H.40 lacked both the device and the Binder notifier
transport even though the authoritative Android 14 9R configuration enables
`CONFIG_OPLUS_FEATURE_BINDER_STATS_ENABLE`.

Wave 23 restores the donor architecture:

- Binder nodes retain the bounded 32-byte service identifier;
- new service nodes derive the identifier from the transaction interface token;
- transaction delivery emits the donor atomic notifier record with caller,
  destination, service, and pending-async state;
- the existing 9R MIDAS `binder_stats_dev.c` is rebuilt as
  `oplus_binder_stats.ko` against the exact H.40 kernel ABI;
- the module is added to the verified DLKM manifest and boot load list.

The compatibility adapter only hardens interface-token reads: failed userspace
reads and empty tokens become `unknown` rather than exposing uninitialized
stack data. The ioctl ABI and record layout are unchanged.

Runtime cost is gated. With no open `/dev/binder_stats` client the atomic
notifier chain is empty. Opening the device registers the consumer, and record
collection begins only after userspace explicitly enables it.
