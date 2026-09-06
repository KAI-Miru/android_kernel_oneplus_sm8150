# Wave 23: Android 14 MIDAS Binder accounting

The ported OnePlus 9R PowerStats implementation contains a hard-coded
`/dev/binder_stats` consumer, and the exact 9R vendor policy already labels
that device. H.40 lacked both the device and the Binder notifier transport
even though the authoritative Android 14 9R configuration enables
`CONFIG_OPLUS_FEATURE_BINDER_STATS_ENABLE`.

Wave 23 restores the donor architecture:

- Binder nodes retain the bounded 32-byte service identifier;
- new service nodes derive the identifier from the transaction interface token;
- transaction delivery emits the donor atomic notifier record with caller,
  destination, service, and pending-async state;
- the source-owned MIDAS `binder_stats_dev.c` is linked into the kernel, as
  required by the donor's boolean `=y` configuration;
- the external-module payload no longer contains or tries to load a duplicate
  `oplus_binder_stats.ko`.

The compatibility adapter hardens interface-token reads: failed userspace
reads and empty tokens become `unknown` rather than exposing uninitialized
stack data. Wave 24 also accepts the Android 14 servicemanager controls 120
(`BINDER_STATS_CTL_SRVMGR_INT`) and 121
(`BINDER_STATS_CTL_SRVMGR_SET_HANDLE_NAME`). The registered handle/name table
is retained as compatibility state while the existing Binder-node notifier
remains the sole transaction-accounting path.

The matching companion-source revision is
`f318506796eb57527c2a6404b35706b6649b242a`.

Runtime cost is gated. With no open `/dev/binder_stats` client the atomic
notifier chain is empty. Opening the device registers the consumer, and record
collection begins only after userspace explicitly enables it.
