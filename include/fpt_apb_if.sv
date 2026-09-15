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

    clocking master_drv_cb@ (posedge PCLK);
        default input #1step output #1ns;
        output PADDR, PSEL, PENABLE, PWRITE, PWDATA, PSTRB;
        input PREADY, PRDATA, PSLVERR;
    endclocking

    clocking slave_drv_cb@ (posedge PCLK);
        default input #1step output #1ns;
        input PADDR, PSEL, PENABLE, PWRITE, PWDATA, PSTRB;
        output PREADY, PRDATA, PSLVERR;
    endclocking
  
    clocking master_mon_cb@ (posedge PCLK);
        default input #1step output #1ns;
        input PADDR, PSEL, PENABLE, PWRITE, PWDATA, PSTRB, PREADY, PRDATA, PSLVERR;
    endclocking

    clocking slave_mon_cb@ (posedge PCLK);
        default input #1step output #1ns;
        input PADDR, PSEL, PENABLE, PWRITE, PWDATA, PSTRB, PREADY, PRDATA, PSLVERR;
    endclocking


    bit assertions_armed = 1'b0;

    always @(posedge PCLK)
        assertions_armed <= 1'b1;

    property PRESETn_DROP_SIGNALS(signal);
        @(posedge PCLK)
        (assertions_armed && !PRESETn) |-> (signal === 1'b0);
    endproperty
        //
    PRESETn_DROP_PSEL:assert property(PRESETn_DROP_SIGNALS(PSEL))
        else $error("PSEL don't drop when PRESETn was asserted. PRESETn=%b, PSEL=%b",
    $sampled(PRESETn), $sampled(PSEL));
    PRESETn_DROP_PENABLE:assert property(PRESETn_DROP_SIGNALS(PENABLE))
        else $error("PENABLE don't drop when PRESETn was asserted. PRESETn=%b, PENABLE=%b ",
    $sampled(PRESETn), $sampled(PENABLE));
    PRESETn_DROP_PREADY:assert property(PRESETn_DROP_SIGNALS(PREADY))
        else $error("PREADY don't rise when PRESETn was asserted low. PRESETn=%b, PREADY=%b",
    $sampled(PRESETn), $sampled(PREADY));

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


    property p_setup_to_access;
        @(posedge PCLK) disable iff (!PRESETn) 
        (PSEL && !PENABLE) |=> (PSEL && PENABLE);
    endproperty

    CHK_SETUP_TO_ACCESS: assert property(p_setup_to_access)
    else $error("Protocol Violation: SETUP phase did not transition to ACCESS phase.");

    property p_no_access_without_setup;
    @(posedge PCLK) disable iff (!PRESETn)
    $rose(PENABLE) |-> $past(PSEL) && !$past(PENABLE);
    endproperty

    CHK_NO_ACCESS_WITHOUT_SETUP: assert property(p_no_access_without_setup)
    else $error("Protocol Violation: PENABLE asserted without a preceding SETUP phase.");

    property p_access_wait_state;
    @(posedge PCLK) disable iff (!PRESETn)
    (PSEL && PENABLE && !PREADY) |=> (PSEL && PENABLE);
    endproperty

    CHK_ACCESS_WAIT_STATE: assert property(p_access_wait_state)
    else $error("Protocol Violation: PSEL or PENABLE dropped during wait state (!PREADY).");

    property p_access_completion;
    @(posedge PCLK) disable iff (!PRESETn)
    (PSEL && PENABLE && PREADY) |=> (!PENABLE);
    endproperty

    CHK_ACCESS_COMPLETION: assert property(p_access_completion)
    else $error("Protocol Violation: PENABLE did not deassert after transfer completion.");

    property p_back_to_back_transfer;
    @(posedge PCLK) disable iff (!PRESETn)(PSEL && PENABLE && PREADY) |=> (PSEL |-> !PENABLE);
    endproperty

    CHK_BACK_TO_BACK_TRANSFER: assert property(p_back_to_back_transfer)
    else $error("Protocol Violation: Invalid Back-to-Back transfer. PENABLE must drop to 0.");

endinterface

`endif//FPT_APB_IF_SV