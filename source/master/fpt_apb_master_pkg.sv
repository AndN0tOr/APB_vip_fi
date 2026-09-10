`ifndef FPT_APB_MASTER_PKG_SVH
`define FPT_APB_MASTER_PKG_SVH

`include "uvm_macros.svh"
`include "../fpt_apb_global_pkg.sv"

package fpt_apb_master_pkg;
    import uvm_pkg::*;
    import fpt_apb_global_pkg::*;
    import fpt_apb_enum_pkg::*;
    import fpt_apb_typedef_pkg::*;

    `include "fpt_apb_master_seq_item.svh"
    `include "fpt_apb_master_driver.svh"
    `include "fpt_apb_master_seq.svh"
    `include "fpt_apb_master_sequencer.svh"
    `include "fpt_apb_master_agent.svh"
endpackage




`endif // FPT_APB_MASTER_PKG_SVH