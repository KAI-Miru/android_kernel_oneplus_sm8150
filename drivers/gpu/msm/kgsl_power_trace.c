/* SPDX-License-Identifier: GPL-2.0-only */
/*
 * Copyright (c) 2022 Qualcomm Innovation Center, Inc. All rights reserved.
 */

#include <linux/module.h>

/* Linux 4.14 requires each TRACE_SYSTEM power definition in its own TU. */
#define CREATE_TRACE_POINTS
#include "kgsl_power_trace.h"
