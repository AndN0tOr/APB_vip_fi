`timescale 1ns/1ps

`include "uvm_macros.svh"
`include "../include/fpt_apb_if.sv"
`include "../include/fpt_apb_sys_if.sv"
`include "../source/fpt_apb_typedef_pkg.sv"

`include "../source/fpt_apb_global_pkg.sv"
`include "../source/slave/fpt_apb_slave_pkg.sv"
`include "../source/master/fpt_apb_master_pkg.sv"

import uvm_pkg::*;
import fpt_apb_typedef_pkg::*;
import fpt_apb_global_pkg::*;
import fpt_apb_enum_pkg::*;
import fpt_apb_slave_pkg::*;
import fpt_apb_master_pkg::*;

`include "../source/fpt_apb_env.svh"
`include "fpt_apb_base_test.svh"
`include "fpt_apb_rst_test.sv"
`include "fpt_apb_read_write_test.sv"
`include "fpt_apb_pstrb_test.sv"
`include "fpt_apb_sys_config.svh"


module fpt_apb_tb_top;
    logic PCLK;
    logic PRESETn;
    fpt_apb_sys_if_t #(
        .FPT_DATA_WIDTH (`FPT_APB_DATA_WIDTH),
        .FPT_ADDR_WIDTH (`FPT_APB_ADDR_WIDTH),
        .FPT_MAX_MASTERS (`FPT_APB_MAX_MASTER),
        .FPT_MAX_SLAVES (`FPT_APB_MAX_SLAVE)
    ) fpt_sys_if (
        .PCLK (PCLK),
        .PRESETn (PRESETn)
    );

    initial begin
        PCLK = 1'b0;
        forever #5 PCLK = ~PCLK;
    end

    task automatic pulse_presetn(input int unsigned wait_cycle = 0, input int unsigned low_cycles = 2);
        if (low_cycles == 0)
            $fatal(1, "pulse_presetn requires at least one clock cycle");

        repeat (wait_cycle)
            @(negedge PCLK);
        PRESETn <= 1'b0;

        repeat (low_cycles) @(negedge PCLK);
        PRESETn <= 1'b1;
    endtask

    initial begin
        string selected_test;
        PRESETn = 1'b0;

        repeat (2) @(negedge PCLK);
        PRESETn <= 1'b1;

        // Apply a second reset pulse only in the reset test.
        if ($value$plusargs("UVM_TESTNAME=%s", selected_test) &&
            selected_test == "fpt_apb_rst_test") begin
            
            pulse_presetn(1, 1);
            pulse_presetn(3, 1);
            pulse_presetn(4, 1);
            pulse_presetn(7, 1);
            pulse_presetn(10, 1);
        end
    end
    // initial begin 
    //     $fsdbDumpfile("novas.fsdb");
    //     $fsdbDumpvars(0, fpt_apb_tb_top);            // Toggle this block on if run on VCS
    //     $fsdbDumpMDA();
    //     $display("[TB_TOP] FSDB dumping enabled!"); // Thêm log để xác nhận block này đã chạy
    // end
    genvar i;
    generate
        // Master VIF (1 master duy nhất)
        initial uvm_config_db#(fpt_apb_vif_t)::set(null, "*master_agent*", "fpt_apb_vif", fpt_sys_if.fpt_master_if);
        for (i = 0; i < 8; i++) begin : gen_s_vif
            // Gửi slave_if_arr[i] tới đích danh slave_agent_0, slave_agent_1...
            initial uvm_config_db#(fpt_apb_vif_t)::set(null, $sformatf("*slave_agent_%0d*", i), "fpt_apb_vif", fpt_sys_if.fpt_slave_if_arr[i]);
        end
    endgenerate
    initial begin
        string selected_test;
        uvm_config_db#(fpt_apb_sys_vif_t)::set(
            null, "*", "fpt_apb_sys_vif", fpt_sys_if
        );

        if (!$value$plusargs("UVM_TESTNAME=%s", selected_test))
            selected_test = "fpt_apb_base_test";
        run_test(selected_test);
    end
endmodule : fpt_apb_tb_top
