`timescale 1ns/1ps

`include "uvm_macros.svh"
`include "../include/fpt_apb_if.sv"
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
`include "fpt_apb_sys_config.svh"

module fpt_apb_tb_top;
    logic PCLK;
    logic PRESETn;

    fpt_apb_if #(
        .DATA_WIDTH (`FPT_APB_DATA_WIDTH),
        .ADDR_WIDTH (`FPT_APB_ADDR_WIDTH)
    ) apb_if (
        .PCLK    (PCLK),
        .PRESETn (PRESETn)
    );

    initial begin
        PCLK = 1'b0;
        forever #5 PCLK = ~PCLK;
    end

    initial begin
        string selected_test;
        PRESETn = 1'b0;

        repeat (2) @(negedge PCLK);
        PRESETn <= 1'b1;

        // Apply a second reset pulse only in the reset test.
        if ($value$plusargs("UVM_TESTNAME=%s", selected_test) &&
            selected_test == "fpt_apb_rst_test") begin
            repeat (4) @(posedge PCLK);
            PRESETn <= 1'b0;

            repeat (2) @(posedge PCLK);
            PRESETn <= 1'b1;
        end
    end
    initial begin
        $fsdbDumpfile("novas.fsdb");
        $fsdbDumpvars(0, fpt_apb_tb_top);
        $fsdbDumpMDA();
        $display("[TB_TOP] FSDB dumping enabled!"); // Thêm log để xác nhận block này đã chạy
    end
    initial begin
        string selected_test;
        uvm_config_db#(fpt_apb_vif_t)::set(
            null, "*", "fpt_apb_vif", apb_if
        );

        if (!$value$plusargs("UVM_TESTNAME=%s", selected_test))
            selected_test = "fpt_apb_base_test";
        run_test(selected_test);
    end
endmodule : fpt_apb_tb_top
