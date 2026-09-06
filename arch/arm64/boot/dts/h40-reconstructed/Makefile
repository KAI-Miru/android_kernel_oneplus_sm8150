# SPDX-License-Identifier: GPL-2.0

include $(src)/dtb-order.mk

dtb-$(CONFIG_ARCH_SM8150) += $(addprefix base/,$(H40_DTB_NAMES))

# The shipped RTIC FDT has boot_cpuid_phys=1.  cmd_dtc supplies -b 0 first;
# this target-specific final option preserves the shipped header value.
DTC_FLAGS_025-rtic := -b 1

always := $(dtb-y)
clean-files := base/*.dtb overlays/*.dtbo
