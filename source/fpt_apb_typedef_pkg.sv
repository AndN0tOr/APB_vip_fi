`ifndef FPT_APB_TYPEDEF_PKG
`define FPT_APB_TYPEDEF_PKG

`include "fpt_apb_def.svh"

package fpt_apb_typedef_pkg;
    typedef virtual fpt_apb_if #(
        .DATA_WIDTH (`FPT_APB_DATA_WIDTH),
        .ADDR_WIDTH (`FPT_APB_ADDR_WIDTH)
    ) fpt_apb_vif_t;

endpackage: fpt_apb_typedef_pkg

`endif
