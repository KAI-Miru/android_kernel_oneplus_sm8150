# Miru H.40 Linux 4.14.305 boot-regression investigation

## Physical boundary

| Candidate | Result | Finding |
|---|---|---|
| Linux 4.14.283 complete candidate | **GOOD** | Reached the second boot screen. |
| Linux 4.14.287 complete candidate | **BAD** | Stuck at the first OnePlus splash. |
| Linux 4.14.287 with RNG early-boot guard | **GOOD** | Passed the first splash. |
| Linux 4.14.291 complete candidate | **BAD** | Stuck at the first OnePlus splash. |
| Linux 4.14.291 with RNG early-boot guard | **GOOD** | Passed the first splash. |
| Linux 4.14.305 with the complete compatibility set | **GOOD** | Passed both boot screens and completed Android boot. |

## Root cause and retained correction

The reproducible boundary showed that the regression was not caused by the Linux sublevel alone. The complete 4.14.287 and 4.14.291 trees failed when the reseed thread could reach `schedule_timeout_interruptible()` before the OnePlus H.40 workqueue environment was ready. Adding the narrow `system_wq` guard restored boot at both sublevels.

Final source retains exactly one guarded path in `drivers/char/random.c`:

```c
if (system_wq && !kthread_should_stop() && crng_ready())
        schedule_timeout_interruptible(CRNG_RESEED_INTERVAL);
```

Linux 4.14.305 also requires the complete audited compatibility set, not an isolated cherry-pick:

- ARM64 SMCCC/errata callback compatibility in `arch/arm64/kernel/cpu_errata.c`
- RNG early-boot workqueue guard in `drivers/char/random.c`
- Qualcomm extcon notifier allocation, initialization and lifetime repair in `drivers/extcon/extcon.c`
- Public FDT API plus preserved `of_fdt_get_ddrtype()` in `drivers/of/fdt.c`
- Random and hardware-random includes in `drivers/soc/qcom/early_random.c`

The exact successful source is `53f76796d1b68260507a83968a4a4bee3b89754f`. It remains the runtime-source ancestor for the clean release branch. Cleanup is restricted to workflows and documentation; runtime kernel paths must remain byte-identical.

## Release implication

The successful physical package used `4.14.305-miru-h40-lts305-bootfix-ci1+`. The public `4.14.305-miru-h40-lts305-ci1+` package then passed its own complete OnePlus 7 Pro smoke test, including boot, radio/data, maximum-volume audio, NFC, 90 Hz, fingerprint/HBM, AOD, charging, USB/ADB, suspend/wake and reboot. The runtime C source is unchanged; production promotion now awaits only separate explicit authorization for the normal merge commit.