`ifndef FPT_APB_READ_WRITE_TEST_SV
`define FPT_APB_READ_WRITE_TEST_SV

// Supplies deterministic, error-free responses while the master sequence
// performs two writes and two reads.
class fpt_apb_memory_slave_seq extends uvm_sequence #(fpt_apb_slave_seq_item);
    `uvm_object_utils(fpt_apb_memory_slave_seq)

    int unsigned num_items = 4;

    function new(string name = "fpt_apb_memory_slave_seq");
        super.new(name);
    endfunction

    virtual task body();
        fpt_apb_slave_seq_item item;

        repeat (num_items) begin
            item = fpt_apb_slave_seq_item::type_id::create("item");
            start_item(item);
            item.delay   = 0;
            item.PSLVERR = NO_ERROR;
            finish_item(item);
        end
    endtask
endclass

class fpt_apb_memory_master_seq extends uvm_sequence #(fpt_apb_master_seq_item);
    `uvm_object_utils(fpt_apb_memory_master_seq)

    localparam bit [`FPT_APB_ADDR_WIDTH-1:0] TEST_ADDR = 'h100;

    function new(string name = "fpt_apb_memory_master_seq");
        super.new(name);
    endfunction

    virtual task transfer(
        input  tx_type_e                         direction,
        input  bit [`FPT_APB_DATA_WIDTH-1:0]     write_data,
        input  bit [(`FPT_APB_DATA_WIDTH/8)-1:0] write_strobe,
        output bit [`FPT_APB_DATA_WIDTH-1:0]     read_data
    );
        fpt_apb_master_seq_item item;

        item = fpt_apb_master_seq_item::type_id::create("item");
        start_item(item);
        item.PADDR  = TEST_ADDR;
        item.PWRITE = direction;
        item.PWDATA = write_data;
        item.PSTRB  = write_strobe;
        item.delay  = 0;
        finish_item(item);

        if (item.PSLVERR != NO_ERROR)
            `uvm_error(
                "APB_MEM_TEST",
                $sformatf("Unexpected PSLVERR for %s at address 0x%0h",
                          direction.name(), TEST_ADDR)
            )

        read_data = item.PRDATA;
    endtask

    virtual task check_read(
        input bit [`FPT_APB_DATA_WIDTH-1:0] expected,
        input string                       description
    );
        bit [`FPT_APB_DATA_WIDTH-1:0] actual;

        transfer(READ, '0, '0, actual);
        if (actual !== expected)
            `uvm_error(
                "APB_MEM_TEST",
                $sformatf("%s: expected 0x%08h, got 0x%08h",
                          description, expected, actual)
            )
        else
            `uvm_info(
                "APB_MEM_TEST",
                $sformatf("%s passed: read 0x%08h", description, actual),
                UVM_LOW
            )
    endtask

    virtual task body();
        bit [`FPT_APB_DATA_WIDTH-1:0] unused_read_data;

        // Full-word write/read verifies normal storage and byte ordering.
        transfer(WRITE, 32'h1122_3344, 4'b1111, unused_read_data);
        check_read(32'h1122_3344, "full-word write/read");

        // Update lanes 0 and 2 only:
        //   old = 11 22 33 44
        //   new = AA BB CC DD, PSTRB=0101
        // result = 11 BB 33 DD
        transfer(WRITE, 32'hAABB_CCDD, 4'b0101, unused_read_data);
        check_read(32'h11BB_33DD, "strobed write/read");
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

    virtual task run_phase(uvm_phase phase);
        fpt_apb_memory_master_seq master_seq;
        fpt_apb_memory_slave_seq  slave_seq;
        fpt_apb_vif_t             vif;

        phase.raise_objection(this);

        if (!uvm_config_db#(fpt_apb_vif_t)::get(
                this, "", "fpt_apb_vif", vif))
            `uvm_fatal(get_type_name(), "No APB virtual interface")

        @(posedge vif.PRESETn);

        master_seq = fpt_apb_memory_master_seq::type_id::create("master_seq");
        slave_seq  = fpt_apb_memory_slave_seq::type_id::create("slave_seq");

        fork
            slave_seq.start(
                apb_env_h.fpt_slave_agents[0].m_apb_slave_sequencer
            );
        join_none

        master_seq.start(
            apb_env_h.fpt_master_agents[0].m_apb_master_sequencer
        );

        wait fork;
        phase.drop_objection(this);
    endtask
endclass

`endif // FPT_APB_READ_WRITE_TEST_SV
