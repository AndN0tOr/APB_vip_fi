`ifndef FPT_APB_SLAVE_PKG_SVH
`define FPT_APB_SLAVE_PKG_SVH

`include "uvm_macros.svh"
`include "../fpt_apb_global_pkg.sv"

package fpt_apb_slave_pkg;
    import uvm_pkg::*;
    import fpt_apb_global_pkg::*;
    import fpt_apb_enum_pkg::*;
    import fpt_apb_typedef_pkg::*;


    `include "fpt_apb_slave_seq_item.svh"
    `include "fpt_apb_slave_sequence.svh"
    `include "fpt_apb_slave_sequencer.svh"
    `include "fpt_apb_slave_driver.svh"
    `include "fpt_apb_slave_agent.svh"
endpackage




`endif // FPT_APB_SLAVE_PKG_SVH
