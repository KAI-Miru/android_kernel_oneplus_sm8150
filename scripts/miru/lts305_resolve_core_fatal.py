#!/usr/bin/env python3
"""Resolve the authentic exit/panic conflicts for Miru H.40 LTS 4.14.305."""

from __future__ import annotations

import hashlib
import re
import subprocess
import tempfile
from pathlib import Path

SCAFFOLD = "b92a77e96dd54fd30f8f39c7eef23e76f211c515"
PREPARATION_PARENT = "b125a425ef1559871b1d6cd662806c8afc53e934"
TARGET = "4415bf5e08942aee6487946a3e0a50956ef68f1e"
EXPECTED_PATCH_SHA256 = "daaae4d64d68d18986a067785e83ab3391ffdb714b8fc8a9710c385b5eb8a034"
DIAG = Path("lts305-core-fatal-resolution")
PATHS = ["kernel/exit.c", "kernel/panic.c"]
EXPECTED_CONFLICTS = {"kernel/exit.c": 1, "kernel/panic.c": 2}
CONFLICT_RE = re.compile(r"^<<<<<<<.*?^>>>>>>>.*?\n", re.MULTILINE | re.DOTALL)


def output(*args: str) -> bytes:
    return subprocess.check_output(list(args))


def split_conflict(block: str) -> tuple[str, str, str]:
    ours: list[str] = []
    base: list[str] = []
    theirs: list[str] = []
    state: str | None = None
    for line in block.splitlines(keepends=True):
        if line.startswith("<<<<<<<"):
            state = "ours"
            continue
        if line.startswith("|||||||"):
            state = "base"
            continue
        if line.startswith("======="):
            state = "theirs"
            continue
        if line.startswith(">>>>>>>"):
            state = None
            continue
        if state == "ours":
            ours.append(line)
        elif state == "base":
            base.append(line)
        elif state == "theirs":
            theirs.append(line)
    return "".join(ours), "".join(base), "".join(theirs)


def union_conflicts(path: str, text: str) -> str:
    conflicts = list(CONFLICT_RE.finditer(text))
    if len(conflicts) != EXPECTED_CONFLICTS[path]:
        raise SystemExit(
            f"unexpected conflict count for {path}: got {len(conflicts)}, "
            f"expected {EXPECTED_CONFLICTS[path]}"
        )
    pieces: list[str] = []
    position = 0
    for conflict in conflicts:
        ours, _base, theirs = split_conflict(conflict.group())
        if not ours.strip() or not theirs.strip():
            raise SystemExit(f"non-union conflict shape for {path}")
        pieces.append(text[position : conflict.start()])
        pieces.append(ours.rstrip() + "\n\n" + theirs.lstrip())
        position = conflict.end()
    pieces.append(text[position:])
    resolved = "".join(pieces)
    if any(marker in resolved for marker in ("<<<<<<<", "|||||||", ">>>>>>>")):
        raise SystemExit(f"unresolved marker remains in {path}")
    return resolved


def stage_map(worktree: Path, path: str) -> dict[int, str]:
    entries: dict[int, str] = {}
    raw = output("git", "-C", str(worktree), "ls-files", "-u", "--", path).decode()
    for line in raw.splitlines():
        metadata, listed = line.split("\t", 1)
        _mode, sha, stage = metadata.split()
        if listed != path:
            raise SystemExit(f"unexpected stage path for {path}: {listed}")
        entries[int(stage)] = sha
    if set(entries) != {1, 2, 3}:
        raise SystemExit(f"missing stage triplet for {path}: {entries}")
    return entries


def diff3_preview(worktree: Path, path: str, stages: dict[int, str], root: Path) -> str:
    safe = path.replace("/", "__")
    ours = root / f"{safe}.stage2"
    base = root / f"{safe}.stage1"
    theirs = root / f"{safe}.stage3"
    ours.write_bytes(output("git", "-C", str(worktree), "cat-file", "blob", stages[2]))
    base.write_bytes(output("git", "-C", str(worktree), "cat-file", "blob", stages[1]))
    theirs.write_bytes(output("git", "-C", str(worktree), "cat-file", "blob", stages[3]))
    proc = subprocess.run(
        ["git", "merge-file", "-p", "--diff3", str(ours), str(base), str(theirs)],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )
    if proc.returncode != EXPECTED_CONFLICTS[path]:
        raise SystemExit(
            f"merge-file conflict count mismatch for {path}: "
            f"got {proc.returncode}, expected {EXPECTED_CONFLICTS[path]}"
        )
    return proc.stdout.decode()


def reproduce() -> dict[str, str]:
    with tempfile.TemporaryDirectory(prefix="lts305-core-fatal-") as temporary:
        root = Path(temporary)
        worktree = root / "worktree"
        stage_files = root / "stages"
        stage_files.mkdir()
        subprocess.check_call(
            ["git", "worktree", "add", "--detach", str(worktree), PREPARATION_PARENT],
            stdout=subprocess.DEVNULL,
        )
        try:
            subprocess.check_call(["git", "-C", str(worktree), "config", "user.name", "Miru LTS Integration Bot"])
            subprocess.check_call(
                [
                    "git",
                    "-C",
                    str(worktree),
                    "config",
                    "user.email",
                    "miru-lts-integration@users.noreply.github.com",
                ]
            )
            proc = subprocess.run(
                ["git", "-C", str(worktree), "merge", "--no-commit", "--no-ff", TARGET],
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                check=False,
            )
            conflicts = output(
                "git", "-C", str(worktree), "diff", "--name-only", "--diff-filter=U"
            ).decode().splitlines()
            DIAG.mkdir(parents=True, exist_ok=True)
            (DIAG / "authentic-merge.stdout").write_bytes(proc.stdout)
            (DIAG / "authentic-merge.stderr").write_bytes(proc.stderr)
            (DIAG / "authentic-conflicts.txt").write_text("".join(f"{p}\n" for p in conflicts))
            if proc.returncode == 0 or len(conflicts) != 33:
                raise SystemExit(
                    f"authentic merge mismatch: rc={proc.returncode}, conflicts={len(conflicts)}"
                )
            missing = sorted(set(PATHS) - set(conflicts))
            if missing:
                raise SystemExit(f"owned paths absent from conflict set: {missing}")

            previews: dict[str, str] = {}
            manifest: list[str] = []
            for path in PATHS:
                stages = stage_map(worktree, path)
                manifest.append(
                    f"{path}\tstage1={stages[1]}\tstage2={stages[2]}\tstage3={stages[3]}\n"
                )
                previews[path] = diff3_preview(worktree, path, stages, stage_files)
            (DIAG / "authentic-stage-manifest.txt").write_text("".join(manifest))

            subprocess.check_call(
                ["git", "-C", str(worktree), "merge", "--abort"],
                stdout=subprocess.DEVNULL,
            )
            if output(
                "git", "-C", str(worktree), "status", "--porcelain", "--untracked-files=no"
            ):
                raise SystemExit("authentic worktree not restored after abort")
            (DIAG / "authentic-merge-summary.txt").write_text(
                "authentic_conflict_count=33\n"
                "owned_stage_triplets=2\n"
                "preview_style=exact-stage-diff3\n"
                "patch_format=git-diff-binary-full-index\n"
                "tracked_worktree_restored=yes\n"
            )
            return previews
        finally:
            subprocess.run(
                ["git", "worktree", "remove", "--force", str(worktree)],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                check=False,
            )


def main() -> None:
    current = output("git", "rev-parse", "HEAD").decode().strip()
    if subprocess.run(["git", "merge-base", "--is-ancestor", SCAFFOLD, current]).returncode:
        raise SystemExit(f"scaffold {SCAFFOLD} is not an ancestor of {current}")
    for path in PATHS:
        if subprocess.run(["git", "diff", "--quiet", SCAFFOLD, "--", path]).returncode:
            raise SystemExit(f"owned path drifted after scaffold: {path}")

    previews = reproduce()
    for path in PATHS:
        Path(path).write_text(union_conflicts(path, previews[path]))

    exit_text = Path("kernel/exit.c").read_text()
    panic_text = Path("kernel/panic.c").read_text()
    required = {
        "kernel/exit.c": [
            "#include <linux/reserve_area.h>",
            "static unsigned int oops_limit = 10000;",
            "static atomic_t oops_count = ATOMIC_INIT(0);",
            "void __noreturn make_task_dead(int signr)",
        ],
        "kernel/panic.c": [
            "#include <trace/events/exception.h>",
            "#include <soc/qcom/minidump.h>",
            "#include <linux/sysfs.h>",
            "static unsigned int warn_limit __read_mostly;",
            "void check_panic_on_warn(const char *origin)",
            "panic_flush_device_cache(2000);",
            "save_dump_reason_to_smem(buf, function_name);",
            "check_panic_on_warn(\"kernel\");",
        ],
    }
    for needle in required["kernel/exit.c"]:
        if needle not in exit_text:
            raise SystemExit(f"missing exit behavior: {needle}")
    for needle in required["kernel/panic.c"]:
        if needle not in panic_text:
            raise SystemExit(f"missing panic behavior: {needle}")

    patch = output("git", "diff", "--binary", "--full-index", SCAFFOLD, "--", *PATHS)
    digest = hashlib.sha256(patch).hexdigest()
    if digest != EXPECTED_PATCH_SHA256:
        raise SystemExit(
            f"audited core-fatal patch mismatch: got {digest}, expected {EXPECTED_PATCH_SHA256}"
        )
    Path("lts305-core-fatal.patch").write_bytes(patch)
    print(f"resolved_paths={len(PATHS)}")
    print(f"patch_sha256={digest}")


if __name__ == "__main__":
    try:
        main()
    except BaseException as exc:
        DIAG.mkdir(parents=True, exist_ok=True)
        try:
            patch = output("git", "diff", "--binary", "--full-index", SCAFFOLD, "--", *PATHS)
            (DIAG / "generated-source.patch").write_bytes(patch)
        except BaseException:
            pass
        (DIAG / "resolver-error.txt").write_text(f"{type(exc).__name__}: {exc}\n")
        raise
