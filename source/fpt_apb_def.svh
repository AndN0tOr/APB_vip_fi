`ifndef FPT_APB_DEF_SVH
`define FPT_APB_DEF_SVH

`ifndef FPT_APB_ADDR_WIDTH
`define FPT_APB_ADDR_WIDTH 32
`endif

`ifndef FPT_APB_DATA_WIDTH
`define FPT_APB_DATA_WIDTH 32
`endif

// Slave PREADY delay profiles, measured in PCLK cycles.
`ifndef FPT_APB_PREADY_DELAY_LOW
`define FPT_APB_PREADY_DELAY_LOW [0:15]
`endif

`ifndef FPT_APB_PREADY_DELAY_MEDIUM
`define FPT_APB_PREADY_DELAY_MEDIUM [16:30]
`endif

`ifndef FPT_APB_PREADY_DELAY_HIGH
`define FPT_APB_PREADY_DELAY_HIGH [31:45]
`endif

// Master transaction delay cycles
`ifndef FPT_APB_TRANS_DELAY_LOW
`define FPT_APB_TRANS_DELAY_LOW [0:15]
`endif

`ifndef FPT_APB_TRANS_DELAY_MEDIUM
`define FPT_APB_TRANS_DELAY_MEDIUM [16:30]
`endif

`ifndef FPT_APB_TRANS_DELAY_HIGH
`define FPT_APB_TRANS_DELAY_HIGH [31:45]
`endif

`endif // FPT_APB_DEF_SVH
