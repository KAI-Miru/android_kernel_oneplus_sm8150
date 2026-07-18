#!/usr/bin/env python3

from __future__ import annotations

import pathlib
import subprocess

COMPOSITE = pathlib.Path("drivers/usb/gadget/composite.c")
UAC1 = pathlib.Path("drivers/usb/gadget/function/f_uac1_legacy.c")
HEADER = pathlib.Path("include/linux/usb/composite.h")
LEDGER = pathlib.Path("Documentation/miru/lts-4.14.190-conflicts.md")

EXPECTED_HASHES = {
    COMPOSITE: "90f6ad5523d82f6534a7643046dfe7583bb32626",
    UAC1: "5cdb2f3227405ec9ce3e70729ae91042ced6c6fe",
    HEADER: "218520253ff280bcc4fcf19b25c72a7483925209",
    LEDGER: "6e3fc98e72e6b0bd16a99256adbcf5460eaca6f7",
}
EXPECTED_RESOLVED_COMPOSITE = "cfcd8259355b84c54ee6998aa59b6919f4b1997b"


def git(*args: str) -> str:
    return subprocess.check_output(["git", *args], text=True)


def replace_exact(text: str, old: str, new: str, expected_count: int = 1) -> str:
    count = text.count(old)
    if count != expected_count:
        raise SystemExit(
            f"replacement guard failed: expected {expected_count}, found {count}: {old!r}"
        )
    return text.replace(old, new, expected_count)


def verify_hashes() -> None:
    for path, expected in EXPECTED_HASHES.items():
        actual = git("hash-object", str(path)).strip()
        if actual != expected:
            raise SystemExit(f"{path}: expected blob {expected}, found {actual}")


def resolve_composite() -> None:
    text = COMPOSITE.read_text()

    old_iterator = '''/**
 * next_ep_desc() - advance to the next EP descriptor
 * @t: currect pointer within descriptor array
 *
 * Return: next EP descriptor or NULL
 *
 * Iterate over @t until either EP descriptor found or
 * NULL (that indicates end of list) encountered
 */
static struct usb_descriptor_header**
next_ep_desc(struct usb_descriptor_header **t)
{
	for (; *t; t++) {
		if ((*t)->bDescriptorType == USB_DT_ENDPOINT)
			return t;
	}
	return NULL;
}

/*
 * for_each_ep_desc()- iterate over endpoint descriptors in the
 *		descriptors list
 * @start:	pointer within descriptor array.
 * @ep_desc:	endpoint descriptor to use as the loop cursor
 */
#define for_each_ep_desc(start, ep_desc) \\
	for (ep_desc = next_ep_desc(start); \\
	      ep_desc; ep_desc = next_ep_desc(ep_desc+1))
'''
    new_iterator = '''/**
 * next_desc() - advance to the next desc_type descriptor
 * @t: currect pointer within descriptor array
 * @desc_type: descriptor type
 *
 * Return: next desc_type descriptor or NULL
 *
 * Iterate over @t until either desc_type descriptor found or
 * NULL (that indicates end of list) encountered
 */
static struct usb_descriptor_header**
next_desc(struct usb_descriptor_header **t, u8 desc_type)
{
	for (; *t; t++) {
		if ((*t)->bDescriptorType == desc_type)
			return t;
	}
	return NULL;
}

/*
 * for_each_desc() - iterate over desc_type descriptors in the
 * descriptors list
 * @start: pointer within descriptor array.
 * @iter_desc: desc_type descriptor to use as the loop cursor
 * @desc_type: wanted descriptr type
 */
#define for_each_desc(start, iter_desc, desc_type) \\
	for (iter_desc = next_desc(start, desc_type); \\
	     iter_desc; iter_desc = next_desc(iter_desc + 1, desc_type))
'''
    text = replace_exact(text, old_iterator, new_iterator)

    old_decl = '''/**
 * config_ep_by_speed() - configures the given endpoint
 * according to gadget speed.
 * @g: pointer to the gadget
 * @f: usb function
 * @_ep: the endpoint to configure
 *
 * Return: error code, 0 on success
'''
    new_decl = '''/**
 * config_ep_by_speed_and_alt() - configures the given endpoint
 * according to gadget speed.
 * @g: pointer to the gadget
 * @f: usb function
 * @_ep: the endpoint to configure
 * @alt: alternate setting number
 *
 * Return: error code, 0 on success
'''
    text = replace_exact(text, old_decl, new_decl, expected_count=1)

    old_signature = '''int config_ep_by_speed(struct usb_gadget *g,
			struct usb_function *f,
			struct usb_ep *_ep)
{
	struct usb_composite_dev *cdev;
	struct usb_endpoint_descriptor *chosen_desc = NULL;
	struct usb_descriptor_header **speed_desc = NULL;
'''
    new_signature = '''int config_ep_by_speed_and_alt(struct usb_gadget *g,
				struct usb_function *f,
				struct usb_ep *_ep,
				u8 alt)
{
	struct usb_composite_dev *cdev;
	struct usb_endpoint_descriptor *chosen_desc = NULL;
	struct usb_interface_descriptor *int_desc = NULL;
	struct usb_descriptor_header **speed_desc = NULL;
'''
    text = replace_exact(text, old_signature, new_signature)

    old_search = '''	if (!speed_desc) {
		DBG(cdev, "%s desc not present for function %s\\n",
			usb_speed_string(g->speed), f->name);
		return -EIO;
	}

	/* find descriptors */
	for_each_ep_desc(speed_desc, d_spd) {
'''
    new_search = '''	if (!speed_desc) {
		DBG(cdev, "%s desc not present for function %s\\n",
			usb_speed_string(g->speed), f->name);
		return -EIO;
	}

	/* find correct alternate setting descriptor */
	for_each_desc(speed_desc, d_spd, USB_DT_INTERFACE) {
		int_desc = (struct usb_interface_descriptor *)*d_spd;

		if (int_desc->bAlternateSetting == alt) {
			speed_desc = d_spd;
			goto intf_found;
		}
	}
	return -EIO;

intf_found:
	/* find descriptors */
	for_each_desc(speed_desc, d_spd, USB_DT_ENDPOINT) {
'''
    text = replace_exact(text, old_search, new_search)

    old_tail = '''	}
	return 0;
}
EXPORT_SYMBOL_GPL(config_ep_by_speed);

/**
 * usb_add_function() - add a function to a configuration
'''
    new_tail = '''	}
	return 0;
}
EXPORT_SYMBOL_GPL(config_ep_by_speed_and_alt);

/**
 * config_ep_by_speed() - configures the given endpoint
 * according to gadget speed.
 * @g: pointer to the gadget
 * @f: usb function
 * @_ep: the endpoint to configure
 *
 * Return: error code, 0 on success
 *
 * This function chooses the right descriptors for a given
 * endpoint according to gadget speed and saves it in the
 * endpoint desc field. If the endpoint already has a descriptor
 * assigned to it - overwrites it with currently corresponding
 * descriptor. The endpoint maxpacket field is updated according
 * to the chosen descriptor.
 * Note: the supplied function should hold all the descriptors
 * for supported speeds
 */
int config_ep_by_speed(struct usb_gadget *g,
			struct usb_function *f,
			struct usb_ep *_ep)
{
	return config_ep_by_speed_and_alt(g, f, _ep, 0);
}
EXPORT_SYMBOL_GPL(config_ep_by_speed);

/**
 * usb_add_function() - add a function to a configuration
'''
    text = replace_exact(text, old_tail, new_tail)

    COMPOSITE.write_text(text)
    actual = git("hash-object", str(COMPOSITE)).strip()
    if actual != EXPECTED_RESOLVED_COMPOSITE:
        raise SystemExit(
            f"resolved composite blob differs from audited Lineage result: {actual}"
        )


def validate_uac1() -> None:
    if git("hash-object", str(UAC1)).strip() != EXPECTED_HASHES[UAC1]:
        raise SystemExit("legacy UAC1 changed unexpectedly")
    text = UAC1.read_text()
    required = (
        "spin_lock_irqsave(&audio->playback_lock, flags);",
        "list_add_tail(&copy_buf->list, &audio->play_queue);",
        "spin_unlock_irqrestore(&audio->playback_lock, flags);",
        "spin_lock_irqsave(&audio->capture_lock, flags);",
        "audio_playback_realtime",
        "f_audio_playback_ep_complete",
        "f_audio_capture_ep_complete",
    )
    for token in required:
        if token not in text:
            raise SystemExit(f"legacy UAC1 lost required H.40 behavior: {token}")


def validate_header_and_callsites() -> None:
    header = HEADER.read_text()
    prototype = '''int config_ep_by_speed_and_alt(struct usb_gadget *g, struct usb_function *f,
				struct usb_ep *_ep, u8 alt);'''
    if prototype not in header:
        raise SystemExit("composite alternate-setting prototype missing")

    uses = git("grep", "-n", "config_ep_by_speed_and_alt", "--", "drivers/usb/gadget", "include/linux/usb")
    if "drivers/usb/gadget/composite.c:" not in uses:
        raise SystemExit("alternate-setting implementation missing")
    if "include/linux/usb/composite.h:" not in uses:
        raise SystemExit("alternate-setting declaration missing")
    if len(uses.splitlines()) < 3:
        raise SystemExit("no USB function callsite uses config_ep_by_speed_and_alt")


def update_ledger() -> None:
    text = LEDGER.read_text()
    replacements = {
        "- Resolved conflicts: 20": "- Resolved conflicts: 22",
        "- Remaining conflicts: 8": "- Remaining conflicts: 6",
        "drivers/usb/gadget/composite.c\n": "",
        "drivers/usb/gadget/function/f_uac1_legacy.c\n": "",
    }
    for old, new in replacements.items():
        text = replace_exact(text, old, new)

    marker = "## Remaining deferred conflicts\n"
    if text.count(marker) != 1:
        raise SystemExit("remaining-conflicts marker missing or duplicated")

    section = """## Resolved in Step 7

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
alternate-setting-zero wrapper. H.40's Qualcomm boot-stat include, OS
descriptor handling and composite setup/disconnect behavior are preserved.

`f_uac1_legacy.c` remains byte-for-byte H.40 and already matches the Lineage
4.14.190 resolution. Its expanded driver protects `play_queue` insertion and
removal with the dedicated `playback_lock`, satisfying stable commit
`c0689058968d4cf756d1fe887c62dc57edcefbc0` (upstream
`8778eb0927ddcd3f431805c37b78fa56481aeed9`) without introducing the generic
upstream driver's unrelated `audio->lock` layout. Capture locking, real-time
packet-drop policy and ColorOS legacy audio descriptors remain unchanged.

Resolution commit:

```text
lts: resolve USB composite and legacy UAC1 conflicts
```

"""
    LEDGER.write_text(text.replace(marker, section + marker, 1))


def main() -> None:
    verify_hashes()
    resolve_composite()
    validate_uac1()
    validate_header_and_callsites()
    update_ledger()
    print("Step 7 guarded USB gadget resolution completed.")


if __name__ == "__main__":
    main()
