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


    property PRESETn_DROP_SIGNALS (signal);
        @(posedge PCLK) !PRESETn |-> !signal;
    endproperty: PRESETn_DROP_SIGNALS

    PRESETn_DROP_PSEL:assert property(PRESETn_DROP_SIGNALS(PSEL));
    PRESETn_DROP_PENABLE:assert property(PRESETn_DROP_SIGNALS(PENABLE));

    //-----------------------------------------
    // Check if unknown values appear
    //-----------------------------------------

    property p_no_x(condition, sig);
        @(posedge PCLK) disable iff (!PRESETn)
        condition |-> !$isunknown(sig);
    endproperty

    CHK_X_PSEL: assert property (p_no_x(1'b1, PSEL))
        else $error("PSEL is unknown while reset is inactive");
    CHK_X_PENABLE: assert property (p_no_x(1'b1, PENABLE))
        else $error("PENABLE is unknown while reset is inactive");
    CHK_X_PWRITE: assert property (p_no_x(PSEL, PWRITE))
        else $error("PWRITE is unknown during a valid transfer");
    CHK_X_PADDR: assert property (p_no_x(PSEL, PADDR))
        else $error("PADDR is unknown during a valid transfer");
    CHK_X_PWDATA: assert property (p_no_x(PSEL && PWRITE, PWDATA))
        else $error("PWDATA is unknown during a Write transfer");
    CHK_X_PSTRB: assert property (p_no_x(PSEL && PWRITE, PSTRB))
        else $error("PSTRB is unknown during a Write transfer");
    CHK_X_PREADY: assert property (p_no_x(PSEL && PENABLE, PREADY))
        else $error("PREADY is unknown during the ACCESS phase");
    CHK_X_PRDATA: assert property (p_no_x(PSEL && PENABLE && !PWRITE && PREADY && !PSLVERR, PRDATA))
        else $error("PRDATA is unknown during a valid Read transfer completion");
    CHK_X_PSLVERR: assert property (p_no_x(PSEL && PENABLE, PSLVERR))
        else $error("PSLVERR is unknown during the ACCESS phase");

    

endinterface

`endif//FPT_APB_IF_SV