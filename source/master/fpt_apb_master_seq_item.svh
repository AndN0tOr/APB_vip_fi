`ifndef _FPT_APB_MASTER_SEQ_ITEM_SVH_
`define _FPT_APB_MASTER_SEQ_ITEM_SVH_

class fpt_apb_master_seq_item extends uvm_sequence_item;
    `uvm_object_utils(fpt_apb_master_seq_item)

    rand bit [`FPT_APB_ADDR_WIDTH-1:0] PADDR;
    bit PSEL;
    rand tx_type_e PWRITE;
    bit PENABLE;
    rand bit [`FPT_APB_DATA_WIDTH-1:0]PWDATA;
    rand bit [(`FPT_APB_DATA_WIDTH/8)-1:0]PSTRB; 

    bit PREADY; 
    bit [`FPT_APB_DATA_WIDTH-1:0] PRDATA;
    slave_error_e PSLVERR;
    int unsigned delay;

    constraint pstrb_read_pstrb_c {(PWRITE == READ) -> (PSTRB == '0);}

    extern function new(string name = "fpt_apb_master_seq_item");
    extern virtual function void do_copy(uvm_object rhs);
    extern virtual function bit do_compare(
        uvm_object   rhs,
        uvm_comparer comparer
    );
    extern virtual function void do_print(uvm_printer printer);

endclass

function fpt_apb_master_seq_item::new(string name = "fpt_apb_master_seq_item");
    super.new(name);
endfunction : new

//--------------------------------------------------------------------------------------------
// Function: do_copy
//  Copy method is implemented using handle rhs
//
// Parameters:
//  rhs - uvm_object
//--------------------------------------------------------------------------------------------
function void fpt_apb_master_seq_item::do_copy(uvm_object rhs);
    fpt_apb_master_seq_item rhs_item;

    if (!$cast(rhs_item, rhs)) begin
        `uvm_fatal("APB_SLAVE_DO_COPY", "Failed to cast rhs")
    end

    super.do_copy(rhs);

    PADDR   = rhs_item.PADDR;
    PSEL    = rhs_item.PSEL;
    PWRITE  = rhs_item.PWRITE;
    PENABLE = rhs_item.PENABLE;
    PWDATA  = rhs_item.PWDATA;
    PSTRB   = rhs_item.PSTRB;
    PREADY  = rhs_item.PREADY;
    PRDATA  = rhs_item.PRDATA;
    PSLVERR = rhs_item.PSLVERR;
    delay   = rhs_item.delay;
endfunction : do_copy

//--------------------------------------------------------------------------------------------
// Function: do_compare
//  Compare method is implemented using handle rhs
//
// Parameters:
//  phase - uvm phase
//--------------------------------------------------------------------------------------------
function bit fpt_apb_master_seq_item::do_compare(
    uvm_object   rhs,
    uvm_comparer comparer
);
    fpt_apb_master_seq_item rhs_item;

    if (!$cast(rhs_item, rhs)) begin
        `uvm_error("APB_MASTER_DO_COMPARE", "Failed to cast rhs")
        return 1'b0;
    end

    return super.do_compare(rhs, comparer) &&
           (PADDR   == rhs_item.PADDR)   &&
           (PSEL    == rhs_item.PSEL)    &&
           (PWRITE  == rhs_item.PWRITE)  &&
           (PENABLE == rhs_item.PENABLE) &&
           (PWDATA  == rhs_item.PWDATA)  &&
           (PSTRB   == rhs_item.PSTRB)   &&
           (PREADY  == rhs_item.PREADY)  &&
           (PRDATA  == rhs_item.PRDATA)  &&
           (PSLVERR == rhs_item.PSLVERR) &&
           (delay   == rhs_item.delay);
endfunction : do_compare

//--------------------------------------------------------------------------------------------
// Function: do_print method
//  Print method can be added to display the data members values
//
// Parameters:
//  printer - uvm_printer
//--------------------------------------------------------------------------------------------
function void fpt_apb_master_seq_item::do_print(uvm_printer printer);
    //super.do_print(printer);

    printer.print_field("PADDR",   PADDR,   $bits(PADDR),   UVM_HEX);
    //printer.print_field("PSEL",    PSEL,    $bits(PSEL),    UVM_BIN);
    printer.print_string("PWRITE", PWRITE.name());
    //printer.print_field("PENABLE", PENABLE, $bits(PENABLE), UVM_BIN);
    printer.print_field("PWDATA",  PWDATA,  $bits(PWDATA),  UVM_HEX);
    printer.print_field("PSTRB",   PSTRB,   $bits(PSTRB),   UVM_BIN);
    //printer.print_field("PREADY",  PREADY,  $bits(PREADY),  UVM_BIN);
    //printer.print_field("PRDATA",  PRDATA,  $bits(PRDATA),  UVM_HEX);
    //printer.print_string("PSLVERR", PSLVERR.name());
    printer.print_field("delay", delay, $bits(delay), UVM_DEC);
endfunction : do_print

`endif // FPT_APB_MASTER_SEQ_ITEM_SVH