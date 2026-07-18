#!/usr/bin/env python3

from __future__ import annotations

import pathlib
import subprocess

TARGET = pathlib.Path("mm/huge_memory.c")
LEDGER = pathlib.Path("Documentation/miru/lts-4.14.190-conflicts.md")
EXPECTED_TARGET_BLOB = "af3be766eb8a46cd940ca2f3285a12b3939869a6"
EXPECTED_LEDGER_BLOB = "e987a433cde5c3dd4c3075c9c3e2c35e1951b6d2"
RESOLVED_TARGET_BLOB = "bd229a949abd63a28a70c56e9d3ace72336b05aa"

OLD = """void __split_huge_pmd(struct vm_area_struct *vma, pmd_t *pmd,
\t\tunsigned long address, bool freeze, struct page *page)
{
\tspinlock_t *ptl;
        bool was_locked = false;
        pmd_t _pmd;
\tstruct mm_struct *mm = vma->vm_mm;
\tunsigned long haddr = address & HPAGE_PMD_MASK;

\tmmu_notifier_invalidate_range_start(mm, haddr, haddr + HPAGE_PMD_SIZE);
\tptl = pmd_lock(mm, pmd);

\t/*
\t * If caller asks to setup a migration entries, we need a page to check
\t * pmd against. Otherwise we can end up replacing wrong page.
\t */
\tVM_BUG_ON(freeze && !page);
\tif (page) {
                VM_WARN_ON_ONCE(!PageLocked(page));
                was_locked = true;
                if (page != pmd_page(*pmd))
                        goto out;
        }

repeat:
\tif (pmd_trans_huge(*pmd)) {
\t\tif (!page) {
\t\t\tpage = pmd_page(*pmd);
\t\t\tif (unlikely(!trylock_page(page))) {
\t\t\t\tget_page(page);
\t\t\t\t_pmd = *pmd;
\t\t\t\tspin_unlock(ptl);
\t\t\t\tlock_page(page);
\t\t\t\tspin_lock(ptl);
\t\t\t\tif (unlikely(!pmd_same(*pmd, _pmd))) {
\t\t\t\t\tunlock_page(page);
\t\t\t\t\tput_page(page);
\t\t\t\t\tpage = NULL;
\t\t\t\t\tgoto repeat;
\t\t\t\t}
\t\t\t\tput_page(page);
\t\t}
\t}

\t\tif (PageMlocked(page))
\t\t\tclear_page_mlock(page);
\t} else if (!(pmd_devmap(*pmd) || is_pmd_migration_entry(*pmd)))
\t\tgoto out;
\t__split_huge_pmd_locked(vma, pmd, haddr, freeze);
out:
\tspin_unlock(ptl);
\tif (!was_locked && page)
\t\tunlock_page(page);
\tmmu_notifier_invalidate_range_end(mm, haddr, haddr + HPAGE_PMD_SIZE);
}
"""

NEW = """void __split_huge_pmd(struct vm_area_struct *vma, pmd_t *pmd,
\t\tunsigned long address, bool freeze, struct page *page)
{
\tspinlock_t *ptl;
\tstruct mm_struct *mm = vma->vm_mm;
\tunsigned long haddr = address & HPAGE_PMD_MASK;
\tbool was_locked = false;
\tpmd_t _pmd;

\tmmu_notifier_invalidate_range_start(mm, haddr, haddr + HPAGE_PMD_SIZE);
\tptl = pmd_lock(mm, pmd);

\t/*
\t * If caller asks to setup a migration entries, we need a page to check
\t * pmd against. Otherwise we can end up replacing wrong page.
\t */
\tVM_BUG_ON(freeze && !page);
\tif (page) {
\t\tVM_WARN_ON_ONCE(!PageLocked(page));
\t\twas_locked = true;
\t\tif (page != pmd_page(*pmd))
\t\t\tgoto out;
\t}

repeat:
\tif (pmd_trans_huge(*pmd)) {
\t\tif (!page) {
\t\t\tpage = pmd_page(*pmd);
\t\t\tif (unlikely(!trylock_page(page))) {
\t\t\t\tget_page(page);
\t\t\t\t_pmd = *pmd;
\t\t\t\tspin_unlock(ptl);
\t\t\t\tlock_page(page);
\t\t\t\tspin_lock(ptl);
\t\t\t\tif (unlikely(!pmd_same(*pmd, _pmd))) {
\t\t\t\t\tunlock_page(page);
\t\t\t\t\tput_page(page);
\t\t\t\t\tpage = NULL;
\t\t\t\t\tgoto repeat;
\t\t\t\t}
\t\t\t\tput_page(page);
\t\t\t}
\t\t}
\t\tif (PageMlocked(page))
\t\t\tclear_page_mlock(page);
\t} else if (!(pmd_devmap(*pmd) || is_pmd_migration_entry(*pmd)))
\t\tgoto out;
\t__split_huge_pmd_locked(vma, pmd, haddr, freeze);
out:
\tspin_unlock(ptl);
\tif (!was_locked && page)
\t\tunlock_page(page);
\tmmu_notifier_invalidate_range_end(mm, haddr, haddr + HPAGE_PMD_SIZE);
}
"""


def git(*args: str) -> str:
    return subprocess.check_output(["git", *args], text=True)


def verify_blob(path: pathlib.Path, expected: str) -> None:
    actual = git("hash-object", str(path)).strip()
    if actual != expected:
        raise SystemExit(f"{path}: expected blob {expected}, found {actual}")


def resolve_target() -> None:
    verify_blob(TARGET, EXPECTED_TARGET_BLOB)
    text = TARGET.read_text()
    if text.count(OLD) != 1:
        raise SystemExit("guarded __split_huge_pmd source block missing or duplicated")
    text = text.replace(OLD, NEW, 1)

    required = (
        "entry = mk_pte(pages[i], vmf->vma_page_prot);",
        "entry = maybe_mkwrite(pte_mkdirty(entry), vmf->vma_flags);",
        "entry = maybe_mkwrite(entry, vma->vm_flags);",
        "if (pmd_trans_huge(*pmd)) {",
        "if (PageMlocked(page))",
        "} else if (!(pmd_devmap(*pmd) || is_pmd_migration_entry(*pmd)))",
        "__split_huge_pmd_locked(vma, pmd, haddr, freeze);",
    )
    for token in required:
        if token not in text:
            raise SystemExit(f"THP resolution lost required source: {token}")

    if "entry = maybe_mkwrite(pte_mkdirty(entry), vma);" in text:
        raise SystemExit("generic stable maybe_mkwrite(vma) API leaked into H.40")
    if "entry = maybe_mkwrite(entry, vma);" in text:
        raise SystemExit("generic stable maybe_mkwrite(vma) API leaked into H.40 split path")

    TARGET.write_text(text)
    verify_blob(TARGET, RESOLVED_TARGET_BLOB)


def update_ledger() -> None:
    verify_blob(LEDGER, EXPECTED_LEDGER_BLOB)
    text = LEDGER.read_text()
    replacements = {
        "- Resolved conflicts: 25": "- Resolved conflicts: 26",
        "- Remaining conflicts: 3": "- Remaining conflicts: 2",
        "mm/huge_memory.c\n": "",
    }
    for old, new in replacements.items():
        if text.count(old) != 1:
            raise SystemExit(f"ledger guard failed for {old!r}")
        text = text.replace(old, new, 1)

    marker = "## Remaining deferred conflicts\n"
    if text.count(marker) != 1:
        raise SystemExit("remaining-conflicts marker missing or duplicated")

    section = """## Resolved in Step 9

The transparent-hugepage conflict was resolved as a minimal control-flow repair:

```text
mm/huge_memory.c
```

Android stable commit `3b6c93db0a02b843694cf91f8bacd94f8e7259c8`
(upstream `c444eb564fb16645c172d550359cb3d75fe8a040`) serializes the THP
mapcount transfer performed by `__split_huge_pmd_locked()` with the compound
page lock. H.40 already carried most of this backport, but its conflicted
`__split_huge_pmd()` block left the page-lock closing brace misplaced and
therefore evaluated `PageMlocked(page)` outside the `pmd_trans_huge()` branch.
That could dereference a non-THP or absent page when handling devmap or migration
PMDs.

The corrected function exactly matches the Lineage SM8150 4.14.190 merge result:
it retains the caller-supplied locked-page validation, retries safely if the PMD
changes while acquiring the page lock, limits mlock clearing to real THPs, and
continues to permit devmap and migration entries to reach
`__split_huge_pmd_locked()` without touching a normal `struct page`.

H.40's older `vm_fault` fields and `maybe_mkwrite(..., vm_flags)` API are
preserved in both unrelated conflict regions. No other THP allocation, collapse,
copy, migration, zero-page, deferred-split or khugepaged behavior is changed.

Resolution commit:

```text
lts: resolve transparent hugepage split conflict
```

"""
    LEDGER.write_text(text.replace(marker, section + marker, 1))


def main() -> None:
    resolve_target()
    update_ledger()
    print("Step 9 guarded THP resolution completed.")


if __name__ == "__main__":
    main()
