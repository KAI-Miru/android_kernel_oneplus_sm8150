# Wave 27: Android 14 interface/UID network accounting

After Wave 26 UID performance accounting passed its complete build and artifact
gate, Wave 27 takes the next bounded interface enabled in both authoritative
OnePlus 9R Android 14 Kona configurations:
`CONFIG_OPLUS_FEATURE_STATS_CALC`.

The implementation is the matching 9R external-source version reached through
the existing `net/oplus_modules` link. It registers the `oplus_stats` generic-
netlink family, accounts IPv4 local-input and post-routing bytes/packets by
interface and socket UID, and publishes chunked snapshots to its userspace
client. It also restores:

- `/proc/sys/net/oplus_stats_calc/debug`;
- `/proc/sys/net/oplus_stats_calc/count`;
- `/proc/sys/net/oplus_stats_calc/upload_size`.

The 9R revision defaults diagnostic logging off and caps each returned netlink
chunk at 3000 bytes. The module is built into the kernel exactly as selected by
the donor production configuration, so the existing 32-file DLKM payload does
not gain a new load-order dependency.
