# Shipped ColorOS 12 H.40 DTBO reconstruction

This directory is the lossless source-level recovery of the original
OnePlus 7 Pro ColorOS 12 H.40 `dtbo.img`.

Input SHA-256:

```text
2f6015b1f9fa9dafd5e7fbc61a297559741c6d33bb42cb2ccd7e6dbe0526c90c
```

## Contents and verification

`dts/` contains all 15 FDT entries from the DTBO table, named by their table
index and byte offset. `stock-dtbo-manifest.tsv` records each entry's size,
offset, SHA-256, compatible string, and project selector.

Every DTS was decompiled from the shipped FDT and recompiled back to a
byte-identical FDT. `original.sha256` and `roundtrip.sha256` record that
verification.

## Inventory

| Project family | Entries | Published H.40 source status |
| --- | ---: | --- |
| 18821 | 1 | Present |
| 18865 | 3 | Present |
| 19863 | 3 | Present |
| 18857 | 1 | Present |
| 19801 | 2 | Present |
| 19861 | 3 | Absent; recovered here |
| 18961 | 2 | Absent; recovered here |

The five `19861`/`18961` entries are the previously unpublished SDX55M
overlay family. The supplied published source has no directories or build
rules for either family.

## Scope and safety

This is an evidence-preserving reconstruction, not an active build-system
change. It intentionally does not add the recovered projects to
`arch/arm64/boot/dts/Makefile` or the DTBO packaging list: their matching
base DTBs and original source composition are absent from the published H.40
tree. Enabling them now could change production DTBO output without proving
the required base-tree linkage.

For the five published project families, the matching **base DTBs** were
previously reproduced byte-for-byte. The corresponding ten overlay sources
are archived as present source, but are not asserted to be source-text or
compiled-overlay identical to the shipped DTBO entries.
