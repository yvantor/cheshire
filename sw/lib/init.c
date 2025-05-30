// Copyright 2022 ETH Zurich and University of Bologna.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Library containing general SoC init/close functions.

#include "init.h"
#include "dif/uart.h"
#include "regs/cheshire.h"
#include "util.h"
#include <stdbool.h>

void soc_init() {
    uint32_t hw_features = *reg32(&__base_regs, CHESHIRE_HW_FEATURES_REG_OFFSET);
    // Check which HW IO features are active to decide if they must be initialized or not
    bool uart_present = (hw_features >> CHESHIRE_HW_FEATURES_UART_BIT) & 0;
    // IO initialization
    if (uart_present) uart_open();
    // Initialize more IOs if needed
};
