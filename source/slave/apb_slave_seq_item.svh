`ifndef FPT_APB_SLAVE_TX
`define FPT_APB_SLAVE_TX

class apb_slave_seq_item extends uvm_sequence_item;
   `uvm_object_utils(apb_slave_seq_item)

    // Request signals from APB master/ DUT
    bit [ADDRESS_WIDTH-1:0] PADDR;
    bit PSEL;
    tx_type_e PWRITE;
    bit PENABLE;
    bit [DATA_WIDTH-1:0]PWDATA;
    bit [(DATA_WIDTH/8)-1:0]PSTRB; 

    // Randomized signals 
    bit PREADY; 
    rand bit [DATA_WIDTH-1:0] PRDATA;
    rand slave_error_e PSLVERR;
    rand int unsigned delay;

    // Constraints
    // 1. PREADY: cycles delayed for 
    constraint c_pready_delay {soft delay inside {[1:5]};}

    // 2. PSLVERR: 95% NO_ERROR, 5% ERROR
    constraint c_pslverr {
        soft PSLVERR dist {
            NO_ERROR := 95,
            ERROR    := 5
        };
    }

endclass : apb_slave_seq_item

`endif