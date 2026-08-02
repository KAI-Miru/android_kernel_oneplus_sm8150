#!/usr/bin/env python3
"""Resolve the exact Miru H.40 -> Android Common 4.14.336 conflict set.

This script is intentionally narrow. It refuses to run unless the unmerged
index contains the exact 14 paths and exact base/Miru/Android Common blobs
captured by the read-only provenance audit. Every conflict block is resolved
explicitly, then the final blob and file mode are verified before staging.
"""

from __future__ import annotations

import argparse
import os
from pathlib import Path
import subprocess
import sys
from typing import Dict, List, Tuple

Stage = Tuple[str, str]

MANIFEST: Dict[str, Dict[int, Stage]] = {
    "drivers/devfreq/devfreq.c": {
        1: ("100644", "b05e6a15221c9dfc6ab65a84bf26761aeaa72b73"),
        2: ("100644", "e66ea89537923a3b8232a568e150d173b33f4cc6"),
        3: ("100644", "e6674448a0bc3ae69f223af9f40d7d9cb7e751ec"),
    },
    "drivers/gpu/drm/drm_mipi_dsi.c": {
        1: ("100644", "bd5e8661f826a596c99f191298bb948da9a503d7"),
        2: ("100644", "e58eebf6d459a0220c4f4b64fd7a8564976679e6"),
        3: ("100644", "6995bee5ad0fb30582f2b89ca27c9d0e4524cb1f"),
    },
    "drivers/mmc/core/block.c": {
        1: ("100644", "f2871464db5b85d2e01e387e40703ef15ca616d0"),
        2: ("100755", "21c4179c26706167ca0298b46e2e9149c4dc76cd"),
        3: ("100644", "3fc4bba0f785967d9a03bc95666cf35f6ed3b7e1"),
    },
    "drivers/mtd/ubi/wl.c": {
        1: ("100644", "545a92eb8f56977dcd5f480e8ddbf0db6d1a4b05"),
        2: ("100644", "52c108378831c0d3cd44392d335aaf82a8b18f5f"),
        3: ("100644", "4411ce5d1c8fcc940e37bc6f8caa8a1bf26f0e6d"),
    },
    "drivers/thermal/thermal_core.c": {
        1: ("100644", "8374b8078b7df60b79077049390ee605fa91d581"),
        2: ("100644", "fa8dbf393e73618dd51c917eb684e3214f86ba75"),
        3: ("100644", "e24d46f7157157664dff54547a498562deb3cbdc"),
    },
    "drivers/usb/dwc3/core.c": {
        1: ("100644", "5a4bd093c311fd5a8abbbb45d85af3ef46a34ddd"),
        2: ("100644", "533a1b635e051d27b8691834da3ce6f1d3506179"),
        3: ("100644", "2e0ef23d2122ac4da37282dc09b304649787f81a"),
    },
    "drivers/usb/dwc3/gadget.c": {
        1: ("100644", "5d142d7f6272fdbe11854a02291513863ddfc990"),
        2: ("100644", "015201f84063803c8009885c7aae9ca7923ea48e"),
        3: ("100644", "0b65328adff17d8679abe2b8625ae36568c0b4c7"),
    },
    "drivers/usb/gadget/function/f_fs.c": {
        1: ("100644", "946cf039edddb7d5cf4b144c61703218a24d6c41"),
        2: ("100644", "75f0b7e042bce29ce74418808f1ec2d44ae673e4"),
        3: ("100644", "b66b70812554d3151221f67b6a164624ee49ecb9"),
    },
    "include/net/pkt_sched.h": {
        1: ("100644", "b3869f97d37d777224c4e925b2f89d853b3211a4"),
        2: ("100755", "9a90f99fa554d95dec0a23f8ca2a87a9870a588d"),
        3: ("100644", "7b6024f2d4eaa0d151f75394b73fbeca7eac05a9"),
    },
    "init/main.c": {
        1: ("100644", "d50ea3c3473e7c84fee9eb94859686e99a234208"),
        2: ("100644", "46a986812509dab8d0a1769364b8557687fb7ddd"),
        3: ("100644", "4a0518fbfd21d0e68b62aeca74d9f4cc8e94c36a"),
    },
    "kernel/events/core.c": {
        1: ("100644", "19993a31d3106386c0888c78ff797ed5fe8b61df"),
        2: ("100644", "71b136b7750e65a5763f54977164eefb4ae11908"),
        3: ("100644", "4a1e54b83ca351de73460f81f8d2fda66372c39b"),
    },
    "kernel/sched/fair.c": {
        1: ("100644", "2ffa6ee813ada10f4bd6f99bd4103a6037dc04cb"),
        2: ("100755", "2b91d65923269f242aa1406de35edda76afc5d7f"),
        3: ("100644", "67eede9ddd4c739edd5b45ce4507de598d2069fc"),
    },
    "lib/ubsan.h": {
        1: ("100644", "7e30b26497e0cd0e2d7c055222349eac5d228a84"),
        2: ("100644", "f3e96ddf9bcad11e3a03e3297275a5f1d7545d02"),
        3: ("100644", "f4d8d0bd4016f42d7c9c50b66d0250367e8dd555"),
    },
    "scripts/checkpatch.pl": {
        1: ("100755", "4107f4094e0cabad95064e762936b998e085c093"),
        2: ("100755", "b340a951e355208f86f99a3f2e827492d487c2da"),
        3: ("100755", "25fdb7fda1128aa99d2d32ee3a125fc4c00292cf"),
    },
}

FINAL: Dict[str, Stage] = {
    "drivers/devfreq/devfreq.c": ("100644", "ffa38b2a847440ef62661d1a8b72e43ff61dc875"),
    "drivers/gpu/drm/drm_mipi_dsi.c": ("100644", "2b0af50e5e0999478a584c62b41b32c22909294f"),
    "drivers/mmc/core/block.c": ("100644", "db2fdbbe7478ba7d389383e6e7d930d18e44bffe"),
    "drivers/mtd/ubi/wl.c": ("100644", "404cb6e1099cb3f9a7b36a9a9ff715419b7104cc"),
    "drivers/thermal/thermal_core.c": ("100644", "6df9a1c24217ae7463be653b7525c82b1e7464ae"),
    "drivers/usb/dwc3/core.c": ("100644", "f2602eb6901f4ff2e7fbbad6bef2b9c560f7aadd"),
    "drivers/usb/dwc3/gadget.c": ("100644", "f897b4fbda584d473f8a96cdd4440e2b4425c782"),
    "drivers/usb/gadget/function/f_fs.c": ("100644", "57f07af22817b0bbf8b252bc4eb017177455f6e6"),
    "include/net/pkt_sched.h": ("100644", "317dcf495a8f198950a7ee6fb262bbff489e2097"),
    "init/main.c": ("100644", "bc4e5bb5430c7da5a71195c1daa34fbc429d1c4d"),
    "kernel/events/core.c": ("100644", "9ad14fba1fc171f45f58456d92b84c01da92cf14"),
    "kernel/sched/fair.c": ("100644", "eb4e41c0f0df42567f73cea1c7e3c8f5c5a5898d"),
    "lib/ubsan.h": ("100644", "f3e96ddf9bcad11e3a03e3297275a5f1d7545d02"),
    "scripts/checkpatch.pl": ("100755", "fe521eb72ad53ed4a0c72639ed089ec920822b40"),
}

RESOLUTIONS: Dict[str, List[str]] = {
    "drivers/devfreq/devfreq.c": [
        "\tmutex_destroy(&devfreq->event_lock);\n"
        "\tsrcu_cleanup_notifier_head(&devfreq->transition_notifier_list);"
    ],
    "drivers/gpu/drm/drm_mipi_dsi.c": [
        """int mipi_dsi_dcs_write_c1(struct mipi_dsi_device *dsi,
\t\t\t\t\t\tu16 read_number)
{
\t\tu8 payload[3] = {0x0A, read_number >> 8, read_number & 0xff};
\t\tssize_t err;

\t\terr = mipi_dsi_dcs_write(dsi, 0xC1,payload, sizeof(payload));
\t\tif (err < 0)
\t\t\treturn err;

\t\treturn 0;
}
EXPORT_SYMBOL(mipi_dsi_dcs_write_c1);

/**
 * mipi_dsi_dcs_set_display_brightness_large() - sets the 16-bit brightness value
 *    of the display
 * @dsi: DSI peripheral device
 * @brightness: brightness value
 *
 * Return: 0 on success or a negative error code on failure.
 */
int mipi_dsi_dcs_set_display_brightness_large(struct mipi_dsi_device *dsi,
\t\t\t\t\t     u16 brightness)
{
\tu8 payload[2] = { brightness >> 8, brightness & 0xff };
\tssize_t err;

\terr = mipi_dsi_dcs_write(dsi, MIPI_DCS_SET_DISPLAY_BRIGHTNESS,
\t\t\t\t payload, sizeof(payload));
\tif (err < 0)
\t\treturn err;

\treturn 0;
}
EXPORT_SYMBOL(mipi_dsi_dcs_set_display_brightness_large);

/**
 * mipi_dsi_dcs_get_display_brightness_large() - gets the current 16-bit
 *    brightness value of the display
 * @dsi: DSI peripheral device
 * @brightness: brightness value
 *
 * Return: 0 on success or a negative error code on failure.
 */
int mipi_dsi_dcs_get_display_brightness_large(struct mipi_dsi_device *dsi,
\t\t\t\t\t     u16 *brightness)
{
\tu8 brightness_be[2];
\tssize_t err;

\terr = mipi_dsi_dcs_read(dsi, MIPI_DCS_GET_DISPLAY_BRIGHTNESS,
\t\t\t\tbrightness_be, sizeof(brightness_be));
\tif (err <= 0) {
\t\tif (err == 0)
\t\t\terr = -ENODATA;

\t\treturn err;
\t}

\t*brightness = (brightness_be[0] << 8) | brightness_be[1];

\treturn 0;
}
EXPORT_SYMBOL(mipi_dsi_dcs_get_display_brightness_large);"""
    ],
    "drivers/mmc/core/block.c": [
        "\treq_to_mmc_queue_req(req)->drv_op =\n"
        "\t\trpmb ? MMC_DRV_OP_IOCTL_RPMB : MMC_DRV_OP_IOCTL;\n"
        "\treq_to_mmc_queue_req(req)->drv_op_result = -EIO;",
        "\treq_to_mmc_queue_req(req)->drv_op =\n"
        "\t\trpmb ? MMC_DRV_OP_IOCTL_RPMB : MMC_DRV_OP_IOCTL;\n"
        "\treq_to_mmc_queue_req(req)->drv_op_result = -EIO;",
    ],
    "drivers/mtd/ubi/wl.c": [
        """\tif (!e) {
\t\t/*
\t\t * This wl entry has been removed for some errors by other
\t\t * process (eg. wear leveling worker), corresponding process
\t\t * (except __erase_worker, which cannot concurrent with
\t\t * ubi_wl_put_peb) will set ubi ro_mode at the same time,
\t\t * just ignore this wl entry.
\t\t */
\t\tspin_unlock(&ubi->wl_lock);
\t\tup_read(&ubi->fm_protect);
\t\treturn 0;
\t}
\te->sqnum = UBI_UNKNOWN;"""
    ],
    "drivers/thermal/thermal_core.c": [
        """\tsnprintf(dev->upper_attr_name, THERMAL_NAME_LENGTH,
\t\t\t\"cdev%d_upper_limit\", dev->id);
\tsysfs_attr_init(&dev->upper_attr.attr);
\tdev->upper_attr.attr.name = dev->upper_attr_name;
\tdev->upper_attr.attr.mode = 0644;
\tdev->upper_attr.show = thermal_cooling_device_upper_limit_show;
\tdev->upper_attr.store = thermal_cooling_device_upper_limit_store;
\tresult = device_create_file(&tz->device, &dev->upper_attr);
\tif (result)
\t\tgoto remove_trip_file;

\tsnprintf(dev->lower_attr_name, THERMAL_NAME_LENGTH,
\t\t\t\"cdev%d_lower_limit\", dev->id);
\tsysfs_attr_init(&dev->lower_attr.attr);
\tdev->lower_attr.attr.name = dev->lower_attr_name;
\tdev->lower_attr.attr.mode = 0644;
\tdev->lower_attr.show = thermal_cooling_device_lower_limit_show;
\tdev->lower_attr.store = thermal_cooling_device_lower_limit_store;
\tresult = device_create_file(&tz->device, &dev->lower_attr);
\tif (result)
\t\tgoto remove_upper_file;

\tsnprintf(dev->weight_attr_name, sizeof(dev->weight_attr_name),
\t\t \"cdev%d_weight\", dev->id);"""
    ],
    "drivers/usb/dwc3/core.c": ["\tdma_set_max_seg_size(dev, UINT_MAX);\n", ""],
    "drivers/usb/dwc3/gadget.c": [
        """\tif (!evt)
\t\treturn IRQ_NONE;

\tdwc = evt->dwc;
\tif (pm_runtime_suspended(dwc->dev)) {
\t\tdwc->pending_events = true;
\t\t/*
\t\t * Trigger runtime resume. The get() function will be balanced
\t\t * after processing the pending events in
\t\t * dwc3_gadget_process_pending_events().
\t\t */
\t\tpm_runtime_get(dwc->dev);
\t\tdisable_irq_nosync(dwc->irq_gadget);
\t\treturn IRQ_HANDLED;
\t}

\tstart_time = ktime_get();
\tdwc->irq_cnt++;

\t/* controller reset is still pending */
\tif (dwc->err_evt_seen)"""
    ],
    "drivers/usb/gadget/function/f_fs.c": [
        "\tffs_log(\"exit: state %d setup_state %d flag %lu\", ffs->state,\n"
        "\t\tffs->setup_state, ffs->flags);"
    ],
    "include/net/pkt_sched.h": [
        "extern int tc_qdisc_flow_control(struct net_device *dev, u32 tcm_handle,\n"
        "\t\t\t\t  int flow_enable);\n"
        "extern const struct nla_policy rtm_tca_policy[TCA_MAX + 1];\n"
    ],
    "init/main.c": [
        "//#ifdef OPLUS_FEATURE_PHOENIX\n"
        "\tif(phx_set_boot_stage)\n"
        "\t\tphx_set_boot_stage(KERNEL_DELAYACCT_INIT_DONE);\n"
        "//#endif"
    ],
    "kernel/events/core.c": [
        "\t\tevent->group_leader->group_generation++;\n\n"
        "\t\tif (event->shared)\n"
        "\t\t\tevent->group_leader = event;\n"
    ],
    "kernel/sched/fair.c": [
        """\t/*
\t * Pull vruntime of the entity being placed to the base level of
\t * cfs_rq, to prevent boosting it if placed backwards.
\t * However, min_vruntime can advance much faster than real time, with
\t * the extreme being when an entity with the minimal weight always runs
\t * on the cfs_rq. If the waking entity slept for a long time, its
\t * vruntime difference from min_vruntime may overflow s64 and their
\t * comparison may get inversed, so ignore the entity's original
\t * vruntime in that case.
\t * The maximal vruntime speedup is given by the ratio of normal to
\t * minimal weight: scale_load_down(NICE_0_LOAD) / MIN_SHARES.
\t * When placing a migrated waking entity, its exec_start has been set
\t * from a different rq. In order to take into account a possible
\t * divergence between new and prev rq's clocks task because of irq and
\t * stolen time, we take an additional margin.
\t * So, cutting off on the sleep time of
\t *     2^63 / scale_load_down(NICE_0_LOAD) ~ 104 days
\t * should be safe.
\t */
\tif (entity_is_long_sleeper(se))
\t\tse->vruntime = vruntime;
\telse
\t\tse->vruntime = max_vruntime(se->vruntime, vruntime);
#ifdef OPLUS_FEATURE_SCHED_ASSIST
\tplace_entity_adjust_ux_task(cfs_rq, se, initial);
#endif"""
    ],
    "lib/ubsan.h": [""],
    "scripts/checkpatch.pl": [
        """# Check for old stable address
\t\tif ($line =~ /^\\s*cc:\\s*.*<?\\bstable\\@kernel\\.org\\b>?.*$/i) {
\t\t\tERROR(\"STABLE_ADDRESS\",
\t\t\t      \"The 'stable' address should be 'stable\\@vger.kernel.org'\\n\" . $herecurr);
\t\t}

# Check for Gerrit Change-Ids not in any patch context
\t\tif ($realfile eq '' && !$has_patch_separator && $line =~ /^\\s*change-id:/i) {
\t\t\tif (ERROR(\"GERRIT_CHANGE_ID\",
\t\t\t          \"Remove Gerrit Change-Id's before submitting upstream\\n\" . $herecurr) &&
\t\t\t    $fix) {
\t\t\t\tfix_delete_line($fixlinenr, $rawline);
\t\t\t}""",
        """# Check the patch for invalid author credentials
\t\tif ($chk_author && $line =~ /^From:.*(quicinc|qualcomm)\\.com/) {
\t\t\tWARN(\"BAD_AUTHOR\", \"invalid author identity\\n\" . $line );
\t\t}

# Check for adding new DT bindings not in schema format
\t\tif (!$in_commit_log &&
\t\t    ($line =~ /^new file mode\\s*\\d+\\s*$/) &&
\t\t    ($realfile =~ m@^Documentation/devicetree/bindings/.*\\.txt$@)) {
\t\t\tWARN(\"DT_SCHEMA_BINDING_PATCH\",
\t\t\t     \"DT bindings should be in DT schema format. See: Documentation/devicetree/bindings/writing-schema.rst\\n\");""",
        """\t\t\t# Extremely long macros may fall off the end of the
\t\t\t# available context without closing.  Give a dangling
\t\t\t# backslash the benefit of the doubt and allow it
\t\t\t# to gobble any hanging open-parens.
\t\t\t$dstat =~ s/\\(.+\\\\$/1/;

\t\t\t# Flatten any obvious string concatenation.""",
        "\t\t\t     \"Consider removing the code enclosed by this #if 0 and its #endif\\n\" . $herecurr);",
        "\t\t\t     \"Consider removing the #if 1 and its #endif\\n\" . $herecurr);",
    ],
}

PENDING_OLD = """void dwc3_gadget_process_pending_events(struct dwc3 *dwc)
{
\tif (dwc->pending_events) {
\t\tdwc3_interrupt(dwc->irq_gadget, dwc->ev_buf);
\t\tdwc3_thread_interrupt(dwc->irq_gadget, dwc->ev_buf);
\t\tpm_runtime_put(dwc->dev);
\t\tdwc->pending_events = false;
\t\tenable_irq(dwc->irq_gadget);
\t}
}
"""
PENDING_NEW = """void dwc3_gadget_process_pending_events(struct dwc3 *dwc)
{
\tif (dwc->pending_events) {
\t\tif (dwc3_check_event_buf(dwc->ev_buf) == IRQ_WAKE_THREAD)
\t\t\tdwc3_thread_interrupt(dwc->irq_gadget, dwc->ev_buf);
\t\tpm_runtime_put(dwc->dev);
\t\tdwc->pending_events = false;
\t\tenable_irq(dwc->irq_gadget);
\t}
}
"""


def run(*args: str, check: bool = True) -> subprocess.CompletedProcess[str]:
    return subprocess.run(args, text=True, capture_output=True, check=check)


def parse_unmerged() -> Dict[str, Dict[int, Stage]]:
    result: Dict[str, Dict[int, Stage]] = {}
    for line in run("git", "ls-files", "-u").stdout.splitlines():
        meta, path = line.split("\t", 1)
        mode, blob, stage = meta.split()
        result.setdefault(path, {})[int(stage)] = (mode, blob)
    return result


def replace_conflicts(text: str, replacements: List[str], path: str) -> str:
    lines = text.splitlines()
    output: List[str] = []
    i = 0
    used = 0
    while i < len(lines):
        if lines[i].startswith("<<<<<<<"):
            if used >= len(replacements):
                raise RuntimeError(f"{path}: more conflict blocks than decisions")
            i += 1
            while i < len(lines) and not lines[i].startswith("======="):
                i += 1
            if i == len(lines):
                raise RuntimeError(f"{path}: missing conflict separator")
            i += 1
            while i < len(lines) and not lines[i].startswith(">>>>>>>"):
                i += 1
            if i == len(lines):
                raise RuntimeError(f"{path}: missing conflict terminator")
            output.extend(replacements[used].splitlines())
            used += 1
            i += 1
        else:
            output.append(lines[i])
            i += 1
    if used != len(replacements):
        raise RuntimeError(f"{path}: used {used} of {len(replacements)} decisions")
    return "\n".join(output) + "\n"


def staged_entry(path: str) -> Stage:
    line = run("git", "ls-files", "-s", "--", path).stdout.strip()
    if not line:
        raise RuntimeError(f"{path}: missing staged entry")
    mode, blob, _stage_and_path = line.split(maxsplit=2)
    return mode, blob


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--report",
        default="Documentation/miru/lts-4.14.336-resolution-results.tsv",
        help="machine-readable staged result report",
    )
    args = parser.parse_args()

    repo = Path(run("git", "rev-parse", "--show-toplevel").stdout.strip())
    os.chdir(repo)

    actual = parse_unmerged()
    if actual != MANIFEST:
        expected_paths = sorted(MANIFEST)
        actual_paths = sorted(actual)
        raise RuntimeError(
            "unmerged manifest mismatch\n"
            f"expected paths: {expected_paths}\n"
            f"actual paths:   {actual_paths}\n"
            f"expected stages: {MANIFEST}\n"
            f"actual stages:   {actual}"
        )

    for path, replacements in RESOLUTIONS.items():
        file_path = Path(path)
        original = file_path.read_text()
        resolved = replace_conflicts(original, replacements, path)
        if path == "drivers/usb/dwc3/gadget.c":
            if resolved.count(PENDING_OLD) != 1:
                raise RuntimeError(
                    "DWC3 clean-merge runtime interaction not found exactly once"
                )
            resolved = resolved.replace(PENDING_OLD, PENDING_NEW)
        file_path.write_text(resolved)

    for path, (mode, _blob) in FINAL.items():
        os.chmod(path, 0o755 if mode == "100755" else 0o644)
        text = Path(path).read_text(errors="replace")
        if any(marker in text for marker in ("<<<<<<<", "=======", ">>>>>>>")):
            raise RuntimeError(f"{path}: unresolved merge marker")
        run("git", "add", "--", path)

    if run("git", "ls-files", "-u").stdout.strip():
        raise RuntimeError("unmerged index entries remain")

    rows = ["path\tbase_blob\tmiru_blob\tandroid_common_blob\tfinal_mode\tfinal_blob"]
    for path in sorted(MANIFEST):
        final_mode, final_blob = staged_entry(path)
        expected_mode, expected_blob = FINAL[path]
        if (final_mode, final_blob) != (expected_mode, expected_blob):
            raise RuntimeError(
                f"{path}: final {(final_mode, final_blob)} != "
                f"expected {(expected_mode, expected_blob)}"
            )
        rows.append(
            "\t".join(
                [
                    path,
                    MANIFEST[path][1][1],
                    MANIFEST[path][2][1],
                    MANIFEST[path][3][1],
                    final_mode,
                    final_blob,
                ]
            )
        )

    report = Path(args.report)
    report.parent.mkdir(parents=True, exist_ok=True)
    report.write_text("\n".join(rows) + "\n")
    run("git", "add", "--", str(report))

    run("git", "diff", "--cached", "--check")
    perl = run("perl", "-c", "scripts/checkpatch.pl", check=False)
    if perl.returncode != 0:
        sys.stderr.write(perl.stdout + perl.stderr)
        raise RuntimeError("resolved checkpatch.pl failed Perl syntax validation")

    print("resolution_result=PASS")
    print(f"resolved_conflicts={len(MANIFEST)}")
    print(f"report={report}")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:
        print(f"resolution_result=FAIL: {exc}", file=sys.stderr)
        raise
