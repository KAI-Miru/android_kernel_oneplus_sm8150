# Reconstructed ColorOS 12.1 H.40 device trees

This directory is the active H.40 production device-tree source. It replaces
the incomplete project-directory selection with the complete payload recovered
from the original images:

- 25 ordered FDTs from the Android boot-v2 DTB field (24 base trees plus RTIC)
- 15 ordered overlays from the Android DT table

The historical componentized project directories remain in the repository for
reference, but `arch/arm64/boot/dts/Makefile` no longer uses them to assemble
the H.40 production payload.

## Canonical inputs

| Input | SHA-256 |
| --- | --- |
| H.40 `boot.img` | `991cf738f5a6dc874c6261fa073c89182e61935a9493dc27347699c4d0a68792` |
| H.40 `dtbo.img` | `2f6015b1f9fa9dafd5e7fbc61a297559741c6d33bb42cb2ccd7e6dbe0526c90` |
| Boot-header DTB field | `36f8cbbcf1fd393b8df397f69596069e715bf8da1603b0c8f5fd690005fcf7eb` |
| Recovery-DTBO table | `ddf316ecd06a35b554cf66d0f217063490eccb9e297c4c51302ae03cb6cdafef` |

The stock reconstruction was compiled with Android DTC 1.6.0 using the
`epapr` phandle format. Every one of the 25 base/RTIC outputs and 15 overlay
outputs matched the corresponding stock FDT byte for byte. Concatenating the
base outputs reproduced the complete boot-header DTB field, and packing the
overlays in the original Android DT-table order reproduced the recovery-DTBO
table.

## Project selectors

| Selector | Identification | Base variants | Overlay entries |
| --- | --- | ---: | ---: |
| 18821 | OnePlus 7 Pro | 4 | 1 |
| 18857 | Unknown; deliberately not guessed | 4 | 1 |
| 18865 | Unknown; deliberately not guessed | 4 | 3 |
| 19801 | Unknown; deliberately not guessed | 4 | 2 |
| 19861 | OnePlus 7T Pro 5G (`hotdogg`) | 4 | 5 |
| 19863 | Unknown; deliberately not guessed | 4 | 3 |

Two shipped overlay `model` strings contain `18961`, but their actual
`oplus,dtsi_no` selector is `19861`. They are preserved verbatim and remain
part of selector family 19861; no separate project mapping is inferred.

`boot-fdt-manifest.tsv`, `overlay-manifest.tsv`, and `dtb-order.mk` are the
authoritative order and identity ledgers. `h40-repro/build-reconstructed-device-trees.py`
compiles, validates, concatenates, and packs them into `h40-dtb.img` and
`h40-dtbo.img`.

## Miru active delta

Commit `4f857d7` records the stock-exact source reconstruction and its hashes.
The active sources then add the Wave 16 `qcom,ddr-stats@c3f0000` node to all
24 base variants. The RTIC FDT and all 15 overlays remain stock-exact. The
manifest keeps both the stock baseline hash and the expected active hash for
every compiled entry, so the intended delta is checked on every production
device-tree build.

The resulting active `h40-dtb.img` SHA-256 is
`6f2c50573cb31f7cb6ff47a2279077ab7a9b5ffc786eacef904b48cc862a13f2`.
The active `h40-dtbo.img` remains stock-identical at
`ddf316ecd06a35b554cf66d0f217063490eccb9e297c4c51302ae03cb6cdafef`.

## Packaging rule

H.40 uses an Android boot-v2 image with a separate DTB field. A production
repack must install `h40-dtb.img` in that field and use `h40-dtbo.img` for the
DTBO payload. Merely appending DTBs to `Image.gz` does not replace the DTB
selected by the bootloader.
