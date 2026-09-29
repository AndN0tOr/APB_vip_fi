`ifndef FPT_APB_TYPEDEF_PKG
`define FPT_APB_TYPEDEF_PKG

`include "fpt_apb_def.svh"

package fpt_apb_typedef_pkg;
    typedef virtual fpt_apb_if #(
        .FPT_DATA_WIDTH (`FPT_APB_DATA_WIDTH),
        .FPT_ADDR_WIDTH (`FPT_APB_ADDR_WIDTH)
    ) fpt_apb_vif_t;

    typedef virtual fpt_apb_sys_if_t #(
        .FPT_MAX_MASTERS (`FPT_APB_MAX_MASTER),
        .FPT_MAX_SLAVES (`FPT_APB_MAX_SLAVE),
        .FPT_DATA_WIDTH (`FPT_APB_DATA_WIDTH),
        .FPT_ADDR_WIDTH (`FPT_APB_ADDR_WIDTH)
    ) fpt_apb_sys_vif_t;

endpackage: fpt_apb_typedef_pkg

`endif
