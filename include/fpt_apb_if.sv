`ifndef FPT_APB_IF_SV
`define FPT_APB_IF_SV

interface fpt_apb_if #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 16
)(
    input logic PCLK,
    input logic PRESETn
);
    // Address and control signals
    logic [ADDR_WIDTH-1:0] PADDR;
    logic PSEL;
    logic PENABLE;
    logic PWRITE;

    // Write data signal
    logic [DATA_WIDTH-1:0] PWDATA;
    logic [DATA_WIDTH/8-1:0] PSTRB;

    // Response signals
    logic PREADY;
    logic [DATA_WIDTH-1:0] PRDATA;
    logic PSLVERR;

    clocking master_cb@ (posedge PCLK);
        output PADDR, PSEL, PENABLE, PWRITE, PWDATA, PSTRB;
        input PREADY, PRDATA, PSLVERR;
    endclocking: master_cb

    clocking slave_cb@ (posedge PCLK);
        input PADDR, PSEL, PENABLE, PWRITE, PWDATA, PSTRB;
        output PREADY, PRDATA, PSLVERR;
    endclocking: slave_cb
  
    clocking master_mon_cb@ (posedge PCLK);
        input PREADY, PRDATA, PSLVERR;
    endclocking

    clocking slave_mon_cb@ (posedge PCLK);
        input PADDR, PSEL, PENABLE, PWRITE, PWDATA, PSTRB;
    endclocking
endinterface



`endif//FPT_APB_IF_SV