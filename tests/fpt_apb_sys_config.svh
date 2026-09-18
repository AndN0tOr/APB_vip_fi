`ifndef FPT_APB_SYS_CONFIG_SVH
`define FPT_APB_SYS_CONFIG_SVH

`include "fpt_apb_mem_model_t.svh"

class fpt_apb_sys_config extends uvm_object;
    `uvm_object_utils(fpt_apb_sys_config)
    
    int unsigned fpt_clk_period;

    int unsigned fpt_master_numb = 1;
    int unsigned fpt_master_priority[];

    int unsigned fpt_slave_numb = 1;
    int unsigned fpt_mem_model_base_addr[];
    int unsigned fpt_mem_model_addr_range[];

    FPT_MEMORY_INIT_PATTERN_E fpt_mem_model_init_pattern[];

    int unsigned fpt_delay_pready_min;
    int unsigned fpt_delay_pready_max;

    int unsigned fpt_delay_transfer_min;
    int unsigned fpt_delay_transfer_max;

    int unsigned fpt_pready_timeout;

    extern function new(string name = "fpt_apb_sys_config");

endclass: fpt_apb_sys_config

function fpt_apb_sys_config::new(string name = "fpt_apb_sys_config");
    super.new(name);
endfunction: new
`endif // FPT_APB_SYS_CONFIG_SVH