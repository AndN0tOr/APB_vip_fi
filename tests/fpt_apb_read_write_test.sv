`ifndef FPT_APB_READ_WRITE_TEST_SV
`define FPT_APB_READ_WRITE_TEST_SV

// Supplies deterministic, error-free responses while the master sequence
// performs two writes and two reads.
class fpt_apb_read_write_slave_seq extends fpt_apb_slave_seq;
    `uvm_object_utils(fpt_apb_read_write_slave_seq)

    int unsigned num_items = 2;

    function new(string name = "fpt_apb_read_write_slave_seq");
        super.new(name);
    endfunction

    virtual task body();
        fpt_apb_slave_seq_item item;

        // repeat (num_items) begin
        //     item = fpt_apb_slave_seq_item::type_id::create("item");
        //     start_item(item);
        //     item.delay   = 0;
        //     item.PSLVERR = NO_ERROR;
        //     finish_item(item);
        // end

        apb_slave_resp(0, NO_ERROR);
        apb_slave_resp(2, ERROR);
    endtask
endclass

class fpt_apb_read_write_master_seq extends fpt_apb_master_seq;
    `uvm_object_utils(fpt_apb_read_write_master_seq)

    localparam bit [`FPT_APB_ADDR_WIDTH-1:0] TEST_ADDR = 'h100;

    function new(string name = "fpt_apb_read_write_master_seq");
        super.new(name);
    endfunction

    virtual task body();
        bit [`FPT_APB_DATA_WIDTH-1:0] read_data;
        
        apb_master_write(TEST_ADDR, 32'h1122_3344, '1, 100);
        apb_master_read(TEST_ADDR, read_data);
    endtask
endclass

class fpt_apb_read_write_test extends fpt_apb_base_test;
    `uvm_component_utils(fpt_apb_read_write_test)

    function new(
        string        name = "fpt_apb_read_write_test",
        uvm_component parent = null
    );
        super.new(name, parent);
    endfunction

    virtual task seq_control;
        fpt_apb_read_write_master_seq master_seq;
        fpt_apb_read_write_slave_seq  slave_seq;

        master_seq = fpt_apb_read_write_master_seq::type_id::create("master_seq");
        slave_seq  = fpt_apb_read_write_slave_seq::type_id::create("slave_seq");

        start_master_slave_seq(master_seq, slave_seq);
    endtask
endclass

`endif // FPT_APB_READ_WRITE_TEST_SV
