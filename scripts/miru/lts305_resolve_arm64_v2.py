#!/usr/bin/env python3
"""Run the audited ARM64 resolver against authentic recursive-merge stages."""

from __future__ import annotations

import importlib.util
import subprocess
import tempfile
from pathlib import Path

MODULE_PATH = Path(__file__).with_name("lts305_resolve_arm64.py")
DIAG = Path("lts305-arm64-resolution")


def load_resolver():
    spec = importlib.util.spec_from_file_location("lts305_arm64_resolver", MODULE_PATH)
    if spec is None or spec.loader is None:
        raise SystemExit(f"cannot load resolver module: {MODULE_PATH}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def git_output(worktree: Path, *args: str) -> bytes:
    return subprocess.check_output(["git", "-C", str(worktree), *args])


def stage_map(worktree: Path, path: str) -> dict[int, str]:
    entries: dict[int, str] = {}
    output = git_output(worktree, "ls-files", "-u", "--", path).decode()
    for line in output.splitlines():
        metadata, listed_path = line.split("\t", 1)
        _mode, sha, stage_text = metadata.split()
        if listed_path != path:
            raise SystemExit(f"unexpected unmerged path for {path}: {listed_path}")
        entries[int(stage_text)] = sha
    if set(entries) != {1, 2, 3}:
        raise SystemExit(f"missing authentic stages for {path}: {entries}")
    return entries


def diff3_preview(worktree: Path, path: str, stages: dict[int, str], temp_root: Path) -> str:
    safe = path.replace("/", "__")
    ours = temp_root / f"{safe}.stage2"
    base = temp_root / f"{safe}.stage1"
    theirs = temp_root / f"{safe}.stage3"
    ours.write_bytes(git_output(worktree, "cat-file", "blob", stages[2]))
    base.write_bytes(git_output(worktree, "cat-file", "blob", stages[1]))
    theirs.write_bytes(git_output(worktree, "cat-file", "blob", stages[3]))
    proc = subprocess.run(
        ["git", "merge-file", "-p", "--diff3", str(ours), str(base), str(theirs)],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )
    if proc.returncode < 0 or proc.returncode > 127:
        raise SystemExit(
            f"git merge-file failed for {path}: {proc.returncode}: "
            f"{proc.stderr.decode(errors='replace')}"
        )
    return proc.stdout.decode()


def reproduce_authentic_merge(module) -> dict[str, str]:
    with tempfile.TemporaryDirectory(prefix="lts305-arm64-authentic-") as tmp:
        temp_root = Path(tmp)
        worktree = temp_root / "worktree"
        stages_root = temp_root / "stage-files"
        stages_root.mkdir()
        subprocess.check_call(
            ["git", "worktree", "add", "--detach", str(worktree), module.PREPARATION_PARENT],
            stdout=subprocess.DEVNULL,
        )
        try:
            subprocess.check_call(
                ["git", "-C", str(worktree), "config", "user.name", "Miru LTS Integration Bot"]
            )
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
                [
                    "git",
                    "-C",
                    str(worktree),
                    "merge",
                    "--no-commit",
                    "--no-ff",
                    module.TARGET,
                ],
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                check=False,
            )
            conflicts = subprocess.check_output(
                ["git", "-C", str(worktree), "diff", "--name-only", "--diff-filter=U"],
                text=True,
            ).splitlines()
            DIAG.mkdir(parents=True, exist_ok=True)
            (DIAG / "authentic-merge.stdout").write_bytes(proc.stdout)
            (DIAG / "authentic-merge.stderr").write_bytes(proc.stderr)
            (DIAG / "authentic-conflicts.txt").write_text(
                "".join(f"{path}\n" for path in conflicts)
            )
            if proc.returncode == 0 or len(conflicts) != 33:
                raise SystemExit(
                    f"authentic merge reproduction mismatch: rc={proc.returncode}, "
                    f"conflicts={len(conflicts)}"
                )
            missing = sorted(set(module.PATHS) - set(conflicts))
            if missing:
                raise SystemExit(f"owned conflicts missing from authentic merge: {missing}")

            previews: dict[str, str] = {}
            manifest: list[str] = []
            for path in module.PATHS:
                stages = stage_map(worktree, path)
                manifest.append(
                    f"{path}\tstage1={stages[1]}\tstage2={stages[2]}\tstage3={stages[3]}\n"
                )
                previews[path] = diff3_preview(worktree, path, stages, stages_root)
            (DIAG / "authentic-stage-manifest.txt").write_text("".join(manifest))

            subprocess.check_call(
                ["git", "-C", str(worktree), "merge", "--abort"],
                stdout=subprocess.DEVNULL,
            )
            tracked = subprocess.check_output(
                [
                    "git",
                    "-C",
                    str(worktree),
                    "status",
                    "--porcelain",
                    "--untracked-files=no",
                ]
            )
            if tracked:
                raise SystemExit("authentic preview worktree not restored after abort")
            (DIAG / "authentic-merge-summary.txt").write_text(
                "authentic_conflict_count=33\n"
                "owned_stage_triplets=7\n"
                "preview_style=exact-stage-diff3\n"
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
    module = load_resolver()
    previews = reproduce_authentic_merge(module)
    module.merge_preview = lambda _base, path: previews[path]
    module.main()


if __name__ == "__main__":
    try:
        main()
    except BaseException as exc:
        DIAG.mkdir(parents=True, exist_ok=True)
        try:
            module = load_resolver()
            patch = subprocess.check_output(
                ["git", "diff", "--binary", module.SCAFFOLD, "--", *module.PATHS]
            )
            (DIAG / "generated-source.patch").write_bytes(patch)
        except BaseException:
            pass
        (DIAG / "resolver-v2-error.txt").write_text(f"{type(exc).__name__}: {exc}\n")
        raise
