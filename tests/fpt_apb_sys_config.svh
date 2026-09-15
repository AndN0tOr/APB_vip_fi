`ifndef FPT_APB_SYS_CONFIG_SVH
`define FPT_APB_SYS_CONFIG_SVH

class fpt_apb_sys_config extends uvm_object;
    `uvm_object_utils(fpt_apb_sys_config)
    
    int fpt_clk_period;

    int fpt_master_numb = 1;
    int fpt_slave_numb = 1;

    int fpt_delay_pready_min;
    int fpt_delay_pready_max;

    int fpt_delay_transfer_min;
    int fpt_delay_transfer_max;

    int fpt_pready_timeout;
    int fpt_penable_timeout;


    extern function new(string name = "fpt_apb_sys_config");

endclass: fpt_apb_sys_config

function fpt_apb_sys_config::new(string name = "fpt_apb_sys_config");
    super.new(name);
endfunction: new

`endif // FPT_APB_SYS_CONFIG_SVH