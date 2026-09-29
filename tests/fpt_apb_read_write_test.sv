`ifndef FPT_APB_READ_WRITE_TEST_SV
`define FPT_APB_READ_WRITE_TEST_SV

// Supplies deterministic, error-free responses while the master sequence
// performs two writes and two reads.
class fpt_apb_read_write_slave_seq extends fpt_apb_slave_seq;
    `uvm_object_utils(fpt_apb_read_write_slave_seq)

    bit [`FPT_APB_ADDR_WIDTH-1:0] base_address = 'b0;
    bit [`FPT_APB_DATA_WIDTH-1:0] mem_size = 'h00010000;
    int unsigned word_count = mem_size / 4; // 4 byte / word

    function new(string name = "fpt_apb_read_write_slave_seq");
        super.new(name);
    endfunction

    virtual task body();
        // Write one 32-bit word at each address.
        for (int unsigned i = 0; i < word_count * 2; i++) begin
            apb_slave_resp(RAND_DELAY);
        end
    endtask
endclass

class fpt_apb_read_write_master_seq extends fpt_apb_master_seq;
    `uvm_object_utils(fpt_apb_read_write_master_seq)

    bit [`FPT_APB_ADDR_WIDTH-1:0] base_address = 'b0;
    bit [`FPT_APB_DATA_WIDTH-1:0] mem_size = 'h00010000;
    int unsigned word_count = mem_size / 4; // 4 byte / word

    bit [`FPT_APB_ADDR_WIDTH-1:0] address;
    bit [`FPT_APB_DATA_WIDTH-1:0] write_data;
    bit [`FPT_APB_DATA_WIDTH-1:0] read_data;


    function new(string name = "fpt_apb_read_write_master_seq");
        super.new(name);
    endfunction

    virtual task body();
        for (int unsigned i = 0; i < word_count; i++) begin
            address    = base_address + (i * 4);
            write_data = (i << 16) + i;

            apb_master_write(address, write_data, 4'b1111, RAND_DELAY);
        end

        for (int unsigned i = 0; i < word_count; i++) begin
            address    = base_address + (i * 4);
            write_data = (i << 16) + i;

            apb_master_read(address, read_data, RAND_DELAY);

            if (read_data !== write_data) begin
            `uvm_error(
                "MEM_READBACK",
                $sformatf(
                    "Address=0x%08h expected=0x%08h actual=0x%08h",
                    address,
                    write_data,
                    read_data
                )
            )
        end
        end

       
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
