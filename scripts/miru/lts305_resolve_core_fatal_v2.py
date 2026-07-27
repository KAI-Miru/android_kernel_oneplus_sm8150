#!/usr/bin/env python3
"""Run the reviewed core-fatal resolver with repository-authentic mode identity."""

from __future__ import annotations

import importlib.util
from pathlib import Path

MODULE_PATH = Path(__file__).with_name("lts305_resolve_core_fatal.py")
AUTHENTIC_PATCH_SHA256 = "1c719cf6207dd2e93928710e6420b3d812ac7b124655151173ebcc1b63733446"

spec = importlib.util.spec_from_file_location("lts305_core_fatal_resolver", MODULE_PATH)
if spec is None or spec.loader is None:
    raise SystemExit(f"cannot load resolver: {MODULE_PATH}")
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
module.EXPECTED_PATCH_SHA256 = AUTHENTIC_PATCH_SHA256
module.main()
