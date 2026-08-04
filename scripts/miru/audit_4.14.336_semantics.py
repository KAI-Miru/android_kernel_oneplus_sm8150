#!/usr/bin/env python3
"""Semantic gates for the Miru H.40 Android Common 4.14.336 merge."""

from pathlib import Path


passed: list[str] = []


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"semantic gate failed: {message}")
    passed.append(message)


devfreq = Path("drivers/devfreq/devfreq.c").read_text()
require(
    devfreq.count("mutex_destroy(&devfreq->event_lock);") == 1,
    "devfreq downstream event_lock teardown",
)
require(
    devfreq.count(
        "srcu_cleanup_notifier_head(&devfreq->transition_notifier_list);"
    )
    == 1,
    "devfreq Android Common SRCU teardown",
)

dsi = Path("drivers/gpu/drm/drm_mipi_dsi.c").read_text()
for symbol in (
    "mipi_dsi_dcs_write_c1",
    "mipi_dsi_dcs_set_display_brightness_large",
    "mipi_dsi_dcs_get_display_brightness_large",
):
    require(dsi.count(f"int {symbol}(") == 1, f"DSI symbol {symbol}")

mmc = Path("drivers/mmc/core/block.c").read_text()
require(
    mmc.count("rpmb ? MMC_DRV_OP_IOCTL_RPMB : MMC_DRV_OP_IOCTL;") == 2,
    "MMC RPMB-aware ioctl operation selection",
)
require(
    mmc.count("req_to_mmc_queue_req(req)->drv_op_result = -EIO;") >= 2,
    "MMC ioctl error initialization",
)

ubi = Path("drivers/mtd/ubi/wl.c").read_text()
ubi_marker = "e->sqnum = UBI_UNKNOWN;"
require(ubi_marker in ubi, "UBI downstream sqnum reset")
ubi_context = ubi[max(0, ubi.index(ubi_marker) - 800) : ubi.index(ubi_marker)]
require(
    "if (!e) {" in ubi_context and "up_read(&ubi->fm_protect);" in ubi_context,
    "UBI missing-entry guard before sqnum reset",
)

thermal = Path("drivers/thermal/thermal_core.c").read_text()
for token in (
    "snprintf(dev->upper_attr_name",
    "snprintf(dev->lower_attr_name",
    "snprintf(dev->weight_attr_name",
):
    require(token in thermal, f"thermal bounded name formatting: {token}")

core = Path("drivers/usb/dwc3/core.c").read_text()
require(
    core.count("dma_set_max_seg_size(dev, UINT_MAX);") == 1,
    "DWC3 DMA max segment size",
)
require("pm_runtime_allow(dev);" in core, "DWC3 downstream runtime-PM lifecycle")

gadget = Path("drivers/usb/dwc3/gadget.c").read_text()
require(
    "if (pm_runtime_suspended(dwc->dev)) {" in gadget,
    "DWC3 suspended-event gate",
)
require("pm_runtime_get(dwc->dev);" in gadget, "DWC3 pending-event runtime reference")
require(
    "if (dwc3_check_event_buf(dwc->ev_buf) == IRQ_WAKE_THREAD)" in gadget,
    "DWC3 Qualcomm-compatible pending buffer check",
)
require(
    "dwc3_interrupt(dwc->irq_gadget, dwc->ev_buf);" not in gadget,
    "DWC3 incompatible upstream callback signature absent",
)
pending = gadget[gadget.index("void dwc3_gadget_process_pending_events") :]
require(
    pending.index("dwc3_thread_interrupt")
    < pending.index("pm_runtime_put(dwc->dev);"),
    "DWC3 pending processing before runtime put",
)

ffs = Path("drivers/usb/gadget/function/f_fs.c").read_text()
ffs_tail = ffs[ffs.index("static void ffs_func_unbind") :]
require(
    ffs_tail.index("ffs_event_add(ffs, FUNCTIONFS_UNBIND);")
    < ffs_tail.index("functionfs_unbind(ffs);"),
    "FunctionFS UNBIND event ordering",
)

pkt = Path("include/net/pkt_sched.h").read_text()
require("tc_qdisc_flow_control" in pkt, "downstream qdisc flow-control API")
require("rtm_tca_policy" in pkt, "Android Common qdisc policy API")
require("READ_ONCE(dev->mtu)" in pkt, "qdisc MTU READ_ONCE hardening")

init = Path("init/main.c").read_text()
require(init.count("arch_cpu_finalize_init();") == 1, "early architecture finalization")
require("KERNEL_DELAYACCT_INIT_DONE" in init, "Oplus Phoenix delayacct boot stage")
require("check_bugs();" not in init, "no duplicate direct check_bugs invocation")

perf = Path("kernel/events/core.c").read_text()
perf_sequence = (
    "event->group_leader->group_generation++;\n\n"
    "\t\tif (event->shared)\n"
    "\t\t\tevent->group_leader = event;"
)
require(perf_sequence in perf, "perf generation update before shared leader rewrite")
require(
    "parent->group_generation != leader->group_generation" in perf,
    "perf inherited group mismatch guard",
)

fair = Path("kernel/sched/fair.c").read_text()
require("entity_is_long_sleeper(se)" in fair, "scheduler long-sleeper vruntime guard")
require(
    "place_entity_adjust_ux_task(cfs_rq, se, initial);" in fair,
    "Oplus UX placement hook",
)

ubsan = Path("lib/ubsan.h").read_text()
require(
    ubsan.count("struct nonnull_arg_data {") == 1,
    "single compiler-compatible UBSAN nonnull_arg_data",
)
require(
    "struct nonnull_return_data" not in ubsan,
    "obsolete UBSAN nonnull return data removed",
)

checkpatch = Path("scripts/checkpatch.pl").read_text()
for token in (
    "STABLE_ADDRESS",
    "GERRIT_CHANGE_ID",
    "BAD_AUTHOR",
    "DT_SCHEMA_BINDING_PATCH",
    "string concatenation",
):
    require(token in checkpatch, f"checkpatch semantic token {token}")

for path in (
    "drivers/mmc/core/block.c",
    "include/net/pkt_sched.h",
    "kernel/sched/fair.c",
):
    require(
        (Path(path).stat().st_mode & 0o111) == 0,
        f"normalized non-executable mode {path}",
    )

print(f"semantic_gate_count={len(passed)}")
for item in passed:
    print(f"PASS\t{item}")
