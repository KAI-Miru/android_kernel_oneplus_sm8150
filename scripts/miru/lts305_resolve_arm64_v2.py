#!/usr/bin/env python3
"""Run the audited ARM64 resolver against an authentic recursive merge preview."""

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


def reproduce_authentic_merge(module) -> dict[str, str]:
    with tempfile.TemporaryDirectory(prefix="lts305-arm64-authentic-") as tmp:
        worktree = Path(tmp) / "worktree"
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
            previews = {path: (worktree / path).read_text() for path in module.PATHS}
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
                "authentic_conflict_count=33\ntracked_worktree_restored=yes\n"
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
