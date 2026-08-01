#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="${PWD}"
RESULT="${ROOT}/diagnostic-result"
FULL="${ROOT}/full-artifact"
COMPACT_DIR="${RUNNER_TEMP}/diag29-compact"
COMPACT_ZIP="${RESULT}/miru-h40-4.14.292-diag29-fdt-rng-fix-kernel.zip"
OUT="${RUNNER_TEMP}/android-root/out/h40-kernel"

PRODUCTION_SHA=61371a1024e341f434deaf61b79a05f73827260a
BASE_DIAG25_SHA=eb04d54f581da4257a331a816444bd6fe88b1ae1
SOURCE_291_SHA=a79859d15ae0025897791a77654bcebeedc708ab
STABLE_291_SHA=e548869f356fead9fdcb3562f52d2226574f4f41
STABLE_292_SHA=65640c873dcf9c9736c071807b371c487bc6377f
FDT_292_SHA=3c2ae48eceaa40f1ecb18ba31dda3f6fe755796c
BASE_RANDOM_BLOB=7c4af47ab1e5f6dfce02bdee41434072de149f0c
SOURCE_VSPRINTF_BLOB=ad1d198627f1c31e0e3135de8f2320a605a58a3f
SOURCE_FDT_BLOB=5e96a55f73b725d0aaf17c1343d380b723238645
FIXED_EXTCON_BLOB=3643c82ca1532c62d5596cff8e05878a4d52543f
EARLY_RANDOM_BLOB=c498b09b1b36b6cc9d34a16b08422e9299bc4a02
EXPECTED_RELEASE=4.14.292-miru-h40-diag29-fdt-rng-fix+

mkdir -p "${RESULT}" "${FULL}/images" "${FULL}/dtbs" "${FULL}/logs" "${FULL}/validation" "${COMPACT_DIR}"

on_error() {
  local rc=$?
  local line=${1:-unknown}
  set +e
  git diff --name-only --diff-filter=U > "${FULL}/validation/unmerged-files.txt" 2>/dev/null || true
  git status --short > "${FULL}/validation/git-status.txt" 2>/dev/null || true
  {
    echo result=FAILURE
    echo failure_stage=source_or_build
    echo "exit_code=${rc}"
    echo "line=${line}"
    echo "launch_head=$(git rev-parse HEAD 2>/dev/null || echo unknown)"
    echo "production_sha=${PRODUCTION_SHA}"
    echo "stable_292=${STABLE_292_SHA}"
  } | tee "${RESULT}/SUMMARY.txt" "${FULL}/validation/SUMMARY.txt"
  echo FAILURE > "${RESULT}/RESULT"
  exit 0
}
trap 'on_error ${LINENO}' ERR

# Immutable boundaries and known-good 4.14.291 source state.
test "$(git ls-remote origin refs/heads/miru-h40 | awk '{print $1}')" = "${PRODUCTION_SHA}"
git fetch --no-tags origin "${PRODUCTION_SHA}" "${SOURCE_291_SHA}" "${STABLE_291_SHA}" "${STABLE_292_SHA}" "${FDT_292_SHA}"
git merge-base --is-ancestor "${PRODUCTION_SHA}" HEAD
git merge-base --is-ancestor "${SOURCE_291_SHA}" HEAD
git merge-base --is-ancestor "${STABLE_291_SHA}" HEAD
! git merge-base --is-ancestor "${STABLE_292_SHA}" HEAD
test "$(sed -n 's/^SUBLEVEL = //p' Makefile | head -n1)" = 291

test "$(git hash-object drivers/char/random.c)" = "${BASE_RANDOM_BLOB}"
test "$(git hash-object lib/vsprintf.c)" = "${SOURCE_VSPRINTF_BLOB}"
test "$(git hash-object drivers/of/fdt.c)" = "${SOURCE_FDT_BLOB}"
test "$(git hash-object drivers/extcon/extcon.c)" = "${FIXED_EXTCON_BLOB}"
test "$(git hash-object drivers/soc/qcom/early_random.c)" = "${EARLY_RANDOM_BLOB}"
grep -Fq 'struct notifier_block random_ready' lib/vsprintf.c
grep -Fq 'register_random_ready_notifier(&random_ready)' lib/vsprintf.c
grep -Fq 'int of_fdt_get_ddrtype(void)' drivers/of/fdt.c
grep -Fq 'edev->bnh = kcalloc(edev->max_supported, sizeof(*edev->bnh)' drivers/extcon/extcon.c
grep -Fq '#include <linux/random.h>' drivers/soc/qcom/early_random.c

# Merge the complete Linux 4.14.292 endpoint. Only the ARM64 FDT transition is
# allowed to conflict; all other conflicts are rejected instead of guessed.
set +e
git merge --no-ff --no-commit "${STABLE_292_SHA}"
merge_rc=$?
set -e
git diff --name-only --diff-filter=U | sort -u > merge-conflicts.txt
cat > expected-possible-conflicts.txt <<'EOF'
arch/arm64/include/asm/mmu.h
arch/arm64/kernel/kaslr.c
arch/arm64/kernel/setup.c
arch/arm64/mm/mmu.c
EOF
unexpected="$(comm -23 merge-conflicts.txt expected-possible-conflicts.txt)"
test -z "${unexpected}"
if [ -s merge-conflicts.txt ]; then
  while IFS= read -r path; do
    git checkout --ours -- "${path}"
  done < merge-conflicts.txt
fi

# Apply the 4.14.292 FDT API semantically over the downstream ARM64 tree,
# preserving arch_read_machine_name() and all unrelated Qualcomm code.
python3 - <<'PY'
from pathlib import Path
import re

# Prototype.
p = Path('arch/arm64/include/asm/mmu.h')
s = p.read_text()
old = 'extern void *fixmap_remap_fdt(phys_addr_t dt_phys);'
new = 'extern void *fixmap_remap_fdt(phys_addr_t dt_phys, int *size, pgprot_t prot);'
if old in s:
    s = s.replace(old, new, 1)
if s.count(new) != 1:
    raise SystemExit('unexpected fixmap_remap_fdt prototype state')
p.write_text(s)

# KASLR caller.
p = Path('arch/arm64/kernel/kaslr.c')
s = p.read_text()
extern = ('extern void *__init __fixmap_remap_fdt(phys_addr_t dt_phys, int *size,\n'
          '\t\t\t\t       pgprot_t prot);\n\n')
if extern in s:
    s = s.replace(extern, '', 1)
s = s.replace('fdt = __fixmap_remap_fdt(dt_phys, &size, PAGE_KERNEL);',
              'fdt = fixmap_remap_fdt(dt_phys, &size, PAGE_KERNEL);', 1)
if s.count('fdt = fixmap_remap_fdt(dt_phys, &size, PAGE_KERNEL);') != 1:
    raise SystemExit('unexpected KASLR FDT caller state')
if '__fixmap_remap_fdt' in s:
    raise SystemExit('obsolete KASLR FDT helper remains')
p.write_text(s)

# setup_machine_fdt(): RW scan, reserve, then RO remap while retaining the
# downstream machine-name hook.
p = Path('arch/arm64/kernel/setup.c')
s = p.read_text()
old = ('static void __init setup_machine_fdt(phys_addr_t dt_phys)\n'
       '{\n'
       '\tvoid *dt_virt = fixmap_remap_fdt(dt_phys);\n'
       '\tconst char *machine_name;')
new = ('static void __init setup_machine_fdt(phys_addr_t dt_phys)\n'
       '{\n'
       '\tint size;\n'
       '\tvoid *dt_virt = fixmap_remap_fdt(dt_phys, &size, PAGE_KERNEL);\n'
       '\tconst char *machine_name;\n\n'
       '\tif (dt_virt)\n'
       '\t\tmemblock_reserve(dt_phys, size);')
if old in s:
    s = s.replace(old, new, 1)
anchor = '\tmachine_name = arch_read_machine_name();'
ro = ('\t/* Early fixups are done, map the FDT as read-only now */\n'
      '\tfixmap_remap_fdt(dt_phys, &size, PAGE_KERNEL_RO);\n\n')
if ro not in s:
    if s.count(anchor) != 1:
        raise SystemExit('downstream machine-name anchor changed')
    s = s.replace(anchor, ro + anchor, 1)
for needle in (
    'void *dt_virt = fixmap_remap_fdt(dt_phys, &size, PAGE_KERNEL);',
    'memblock_reserve(dt_phys, size);',
    'fixmap_remap_fdt(dt_phys, &size, PAGE_KERNEL_RO);',
    'machine_name = arch_read_machine_name();',
):
    if s.count(needle) != 1:
        raise SystemExit(f'unexpected setup FDT state: {needle}')
p.write_text(s)

# Consolidate the low-level helper and remove the obsolete one-argument wrapper.
p = Path('arch/arm64/mm/mmu.c')
s = p.read_text()
s = s.replace('void *__init __fixmap_remap_fdt(phys_addr_t dt_phys, int *size, pgprot_t prot)',
              'void *__init fixmap_remap_fdt(phys_addr_t dt_phys, int *size, pgprot_t prot)', 1)
pattern = re.compile(
    r'\nvoid \*__init fixmap_remap_fdt\(phys_addr_t dt_phys\)\n'
    r'\{\n.*?\n\}\n\n(?=int __init arch_ioremap_pud_supported)',
    re.S,
)
s, count = pattern.subn('\n', s, count=1)
if count != 1:
    raise SystemExit(f'unexpected one-argument FDT wrapper count: {count}')
needle = 'void *__init fixmap_remap_fdt(phys_addr_t dt_phys, int *size, pgprot_t prot)'
if s.count(needle) != 1 or '__fixmap_remap_fdt' in s:
    raise SystemExit('unexpected low-level FDT helper state')
p.write_text(s)
PY

git add arch/arm64/include/asm/mmu.h arch/arm64/kernel/kaslr.c \
  arch/arm64/kernel/setup.c arch/arm64/mm/mmu.c
test -z "$(git diff --name-only --diff-filter=U)"
test "${merge_rc}" = 0 || test -s merge-conflicts.txt

# Retain the exact RNG early-boot guard proven on physical 4.14.287 and 4.14.291.
python3 - <<'PY'
from pathlib import Path
p = Path('drivers/char/random.c')
s = p.read_text()
old = '\tif (!kthread_should_stop() && crng_ready())\n\t\tschedule_timeout_interruptible(CRNG_RESEED_INTERVAL);'
new = '\tif (system_wq && !kthread_should_stop() && crng_ready())\n\t\tschedule_timeout_interruptible(CRNG_RESEED_INTERVAL);'
if old in s:
    s = s.replace(old, new, 1)
if s.count(new) != 1:
    raise SystemExit('unexpected RNG guard state')
p.write_text(s)
PY

git add drivers/char/random.c
git config user.name github-actions[bot]
git config user.email 41898282+github-actions[bot]@users.noreply.github.com
git commit -m 'diag: merge Linux 4.14.292 with FDT and RNG boot fixes'
SOURCE_COMMIT="$(git rev-parse HEAD)"
test "$(git rev-parse HEAD^2)" = "${STABLE_292_SHA}"
git merge-base --is-ancestor "${FDT_292_SHA}" HEAD
test "$(sed -n 's/^SUBLEVEL = //p' Makefile | head -n1)" = 292
grep -Fq 'if (system_wq && !kthread_should_stop() && crng_ready())' drivers/char/random.c
! grep -Fq 'if (!kthread_should_stop() && crng_ready())' drivers/char/random.c
grep -Fq 'void *dt_virt = fixmap_remap_fdt(dt_phys, &size, PAGE_KERNEL);' arch/arm64/kernel/setup.c
grep -Fq 'fixmap_remap_fdt(dt_phys, &size, PAGE_KERNEL_RO);' arch/arm64/kernel/setup.c
grep -Fq 'machine_name = arch_read_machine_name();' arch/arm64/kernel/setup.c
test "$(git hash-object drivers/extcon/extcon.c)" = "${FIXED_EXTCON_BLOB}"
test "$(git hash-object drivers/soc/qcom/early_random.c)" = "${EARLY_RANDOM_BLOB}"
test "$(git hash-object drivers/of/fdt.c)" = "${SOURCE_FDT_BLOB}"
git diff --check "${BASE_DIAG25_SHA}" HEAD -- . ':!Documentation' ':!.github' ':!scripts/miru'

{
  echo result=PASS
  echo "launch_head=${GITHUB_SHA}"
  echo "local_source_commit=${SOURCE_COMMIT}"
  echo "production_sha=${PRODUCTION_SHA}"
  echo "base_4.14.291=${BASE_DIAG25_SHA}"
  echo "stable_4.14.292=${STABLE_292_SHA}"
  echo "fdt_transition=${FDT_292_SHA}"
  echo "merge_conflicts=$(paste -sd, merge-conflicts.txt)"
  echo kernel_version=4.14.292
  echo rng_guard=system_wq
  echo fdt_scan_mapping=RW_then_RO
} | tee source-validation.txt

# Reuse the proven kernel-only build architecture.
test "$(git hash-object scripts/Makefile.build)" = ee3b37a3bf6a586b74fe00f9e39ca5e77f08b6d3
python3 scripts/miru/prepare_vendor_v6_linewise.py
python3 scripts/miru/inject_vendor_compat_v3_into_ci_build.py
sed -i 's/apply_vendor_lts190_compat_v3.py/apply_vendor_lts190_compat_v6.py/' scripts/miru/ci_build_4.14.190.sh
python3 scripts/miru/insert_vendor_format_fixer.py

python3 - <<'PY'
from pathlib import Path
from textwrap import dedent
p = Path('scripts/miru/ci_build_4.14.190.sh')
s = p.read_text()
replacements = [
    ('BASE_SHA=59858c8f798778f4e6c1c4449baba631e353600e', 'BASE_SHA=61371a1024e341f434deaf61b79a05f73827260a'),
    ('SCAFFOLD_SHA=5d8cba39fefb935c6feaf30ea1a57dfffa80273a', 'SCAFFOLD_SHA=a79859d15ae0025897791a77654bcebeedc708ab'),
    ('STABLE_SHA=d2d05bcf4b4edf8d028fa420dee3c6644aa5b4ac', 'STABLE_SHA=65640c873dcf9c9736c071807b371c487bc6377f'),
    ('git diff --check "${BASE_SHA}" HEAD > "${DIAG_DIR}/diff-check.txt" 2>&1', '''git diff --check "${SCAFFOLD_SHA}" HEAD -- . \\
            ':!Documentation' ':!.github' ':!scripts/miru' > "${DIAG_DIR}/diff-check.txt" 2>&1'''),
    ("':!Documentation/miru/lts-4.14.190-conflicts.md'", "':!Documentation' ':!.github' ':!scripts/miru'"),
    ('test "$(sed -n \'s/^SUBLEVEL = //p\' Makefile | head -n1)" = "190"', 'test "$(sed -n \'s/^SUBLEVEL = //p\' Makefile | head -n1)" = "292"'),
    ("grep -Fq -- '- Resolved conflicts: 28' Documentation/miru/lts-4.14.190-conflicts.md", 'test "$(git hash-object drivers/extcon/extcon.c)" = 3643c82ca1532c62d5596cff8e05878a4d52543f'),
    ("grep -Fq -- '- Remaining conflicts: 0' Documentation/miru/lts-4.14.190-conflicts.md", "grep -Fq 'if (system_wq && !kthread_should_stop() && crng_ready())' drivers/char/random.c"),
    ('echo "== Miru H.40 Android 4.14.190 CI build =="', 'echo "== Miru H.40 Linux 4.14.292 FDT and RNG diagnostic =="'),
    ('echo "kernel_version=4.14.190"', 'echo "kernel_version=4.14.292"'),
    ('echo "conflicts=28/28 resolved"', 'echo "compatibility_delta=4.14.292 FDT transition plus proven extcon early_random notifier DDR helper and RNG guard"'),
    ('export KERNEL_LOCALVERSION=-miru-h40-lts190-ci1', 'export KERNEL_LOCALVERSION=-miru-h40-diag29-fdt-rng-fix'),
    ('CONFIG_LOCALVERSION="-miru-h40-lts190-ci1"', 'CONFIG_LOCALVERSION="-miru-h40-diag29-fdt-rng-fix"'),
    ("grep -m1 '^Linux version 4\\.14\\.190-'", "grep -m1 '^Linux version 4\\.14\\.292-miru-h40-diag29-fdt-rng-fix+'"),
]
for old, new in replacements:
    if s.count(old) != 1:
        raise SystemExit(f'unexpected build-driver replacement count for: {old}')
    s = s.replace(old, new, 1)
anchor = 'git worktree add --detach "${KERNEL_WORKTREE}" HEAD\n'
patch = dedent(r'''
git worktree add --detach "${KERNEL_WORKTREE}" HEAD
python3 - "${KERNEL_WORKTREE}/h40-repro/build-h40.sh" <<'INNERPY'
from pathlib import Path
import sys
p = Path(sys.argv[1])
s = p.read_text()
old = 'Image Image.gz Image.gz-dtb dtbs modules'
if s.count(old) != 2:
    raise SystemExit(f'unexpected kernel target count: {s.count(old)}')
p.write_text(s.replace(old, 'Image Image.gz Image.gz-dtb dtbs'))
INNERPY
''').lstrip()
if s.count(anchor) != 1:
    raise SystemExit('kernel worktree anchor changed')
p.write_text(s.replace(anchor, patch, 1))
PY

bash -n scripts/miru/ci_build_4.14.190.sh
trap - ERR
set +e
export GITHUB_WORKSPACE="${ROOT}"
bash scripts/miru/ci_build_4.14.190.sh
COMPILE_EXIT=$?
set -e
trap 'on_error ${LINENO}' ERR

status=0
test "${COMPILE_EXIT}" = 0 || status=1
for f in Image Image.gz Image.gz-dtb; do test -s "${OUT}/arch/arm64/boot/${f}" || status=1; done
for f in vmlinux System.map Module.symvers .config; do test -s "${OUT}/${f}" || status=1; done
release="$(tr -d '\n' < "${OUT}/include/config/kernel.release" 2>/dev/null || true)"
test "${release}" = "${EXPECTED_RELEASE}" || status=1
ko_count="$(find "${OUT}" -type f -name '*.ko' 2>/dev/null | wc -l)"
dtb_count="$(find "${OUT}/arch/arm64/boot/dts" -type f -name '*.dtb' 2>/dev/null | wc -l)"
test "${ko_count}" = 0 || status=1
test "${dtb_count}" = 5 || status=1
grep -Fq 'clang_path=clang-r377782c' build-diagnostics/toolchain-manifest.txt || status=1
grep -Fq 'clang version 10.0.5' build-diagnostics/toolchain-manifest.txt || status=1
test "$(git ls-remote origin refs/heads/miru-h40 | awk '{print $1}')" = "${PRODUCTION_SHA}" || status=1

python3 - "${OUT}" "${FULL}/validation/IMAGE-STRUCTURE.txt" <<'PY' || status=1
from pathlib import Path
import gzip, hashlib, struct, sys
out = Path(sys.argv[1]); boot = out / 'arch/arm64/boot'
image = (boot / 'Image').read_bytes(); gz = (boot / 'Image.gz').read_bytes(); combo = (boot / 'Image.gz-dtb').read_bytes()
order = ['18821', '19801', '19863', '18865', '18857']
hashes = {
 '18821':'6d8b05d573a066e1ed6ce7f5986c2976d1c663002c85fadaa187107bef04ef3e',
 '19801':'a5eded3b56c8f82a5daf6ec04474e701fbdcf9cd8a3a15d19cdedfee9c4700cc',
 '19863':'1c2d7d697118855c01e875b4d44c602a5638a2bdc4b6c17365bf46fc44877b70',
 '18865':'fa9114713c9e74767f7ec2eedd06dcd1f9eb38eb3b8ab14162553cfded751f9a',
 '18857':'9c56cb07b600a325fdccb3ca0dfe970c95e6700c8cefa50407ea75b411e53a81',
}
if gzip.decompress(gz) != image: raise SystemExit('Image.gz mismatch')
dtbs=[]; rows=[]
for key in order:
 hits=list((boot/'dts').glob(f'{key}/sm8150-v2-mtp.dtb'))
 if len(hits)!=1: raise SystemExit(f'unexpected DTB {key}: {hits}')
 data=hits[0].read_bytes(); digest=hashlib.sha256(data).hexdigest()
 if digest!=hashes[key]: raise SystemExit(f'known-good DTB mismatch {key}')
 dtbs.append(data); rows += [f'{key}_size={len(data)}', f'{key}_sha256={digest}']
if combo != gz + b''.join(dtbs): raise SystemExit('DTB order, padding, or payload mismatch')
text_offset=struct.unpack_from('<Q', image, 8)[0]; flags=struct.unpack_from('<Q', image, 24)[0]
if gz[:2]!=b'\x1f\x8b' or text_offset!=524288 or flags!=10 or image[56:60]!=b'ARMd': raise SystemExit('ARM64 header mismatch')
Path(sys.argv[2]).write_text('\n'.join([
 f'Image_size={len(image)}', f'Image_sha256={hashlib.sha256(image).hexdigest()}',
 f'Image.gz_size={len(gz)}', f'Image.gz_sha256={hashlib.sha256(gz).hexdigest()}',
 f'Image.gz-dtb_size={len(combo)}', f'Image.gz-dtb_sha256={hashlib.sha256(combo).hexdigest()}',
 f'dtb_tail_size={len(combo)-len(gz)}', 'gzip_matches_Image=True', 'gzip_magic=1f8b',
 f'arm64_text_offset={text_offset}', f'arm64_flags={flags}', 'arm64_magic=ARMd',
 f'appended_dtb_order={",".join(order)}', 'dtb_bytes_match_known_good_269=True',
 'appended_dtb_padding=none', 'extra_payload=none', *rows])+'\n')
PY

cp -a source-validation.txt merge-conflicts.txt expected-possible-conflicts.txt "${FULL}/validation/" 2>/dev/null || true
cp -a build-diagnostics/. "${FULL}/logs/" 2>/dev/null || true
for f in Image Image.gz Image.gz-dtb; do test -f "${OUT}/arch/arm64/boot/${f}" && cp -a "${OUT}/arch/arm64/boot/${f}" "${FULL}/images/"; done
for f in vmlinux System.map Module.symvers .config; do test -f "${OUT}/${f}" && cp -a "${OUT}/${f}" "${FULL}/"; done
find "${OUT}/arch/arm64/boot/dts" -type f -name '*.dtb' -exec cp -a --parents {} "${FULL}/dtbs/" \; 2>/dev/null || true
image_path="${OUT}/arch/arm64/boot/Image.gz-dtb"
image_sha="$(sha256sum "${image_path}" 2>/dev/null | awk '{print $1}')"; [ -n "${image_sha}" ] || image_sha=missing
image_size="$(stat -c %s "${image_path}" 2>/dev/null || echo 0)"
{
 echo "result=$([ "${status}" = 0 ] && echo SUCCESS || echo FAILURE)"
 echo "local_source_commit=${SOURCE_COMMIT}"
 echo "production_sha=${PRODUCTION_SHA}"
 echo "stable_4.14.292=${STABLE_292_SHA}"
 echo "fdt_transition=${FDT_292_SHA}"
 echo "kernel_release=${release:-missing}"
 echo "compile_exit=${COMPILE_EXIT}"
 echo "validation_exit=${status}"
 echo "dtb_count=${dtb_count}"
 echo "ko_count=${ko_count}"
 echo "Image.gz-dtb_size=${image_size}"
 echo "Image.gz-dtb_sha256=${image_sha}"
 echo external_modules=not_built
 echo installer_generated=no
} | tee "${RESULT}/SUMMARY.txt" "${FULL}/validation/SUMMARY.txt"

if [ "${status}" = 0 ]; then
 cp -a "${image_path}" "${COMPACT_DIR}/4.14.292-miru-h40-diag29-fdt-rng-fix+.img"
 cp -a "${RESULT}/SUMMARY.txt" "${COMPACT_DIR}/BUILD-INFO.txt"
 cat > "${COMPACT_DIR}/README.txt" <<'EOF'
Miru H.40 Linux 4.14.292 FDT/RNG physical diagnostic.
Kernel only; external modules were not rebuilt.
GOOD: reaches the second boot logo.
BAD: hangs or reboots at the first OnePlus splash.
EOF
 (cd "${COMPACT_DIR}" && sha256sum * > SHA256SUMS)
 (cd "${COMPACT_DIR}" && zip -9 -q "${ROOT}/${COMPACT_ZIP}" ./*)
 test -s "${COMPACT_ZIP}" || status=1
fi
sha256sum "${FULL}/images/"* "${FULL}/"vmlinux "${FULL}/"System.map "${FULL}/"Module.symvers "${FULL}/".config > "${FULL}/validation/SHA256SUMS" 2>/dev/null || true
echo "$([ "${status}" = 0 ] && echo SUCCESS || echo FAILURE)" > "${RESULT}/RESULT"
exit 0
