`timescale 1ns/1ps

`include "uvm_macros.svh"
`include "include/fpt_apb_if.sv"
`include "source/fpt_apb_typedef_pkg.sv"

`include "source/fpt_apb_global_pkg.sv"
`include "source/slave/fpt_apb_slave_pkg.sv"

import uvm_pkg::*;
import fpt_apb_typedef_pkg::*;
import fpt_apb_global_pkg::*;
import fpt_apb_enum_pkg::*;
import fpt_apb_slave_pkg::*;

`include "source/fpt_apb_env.svh"
`include "tests/fpt_apb_base_test.svh"

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
        PRESETn = 1'b0;

        repeat (2) @(posedge PCLK);
        PRESETn <= 1'b1;
    end

    initial begin
        uvm_config_db#(fpt_apb_vif_t)::set(
            null, "*", "fpt_apb_vif", apb_if
        );

        run_test("fpt_apb_base_test");
    end
endmodule : fpt_apb_tb_top
