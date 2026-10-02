`ifndef FPT_APB_READ_WRITE_TEST_SV
`define FPT_APB_READ_WRITE_TEST_SV

// Check randomized byte strobes with a read/write/read at each address.
class fpt_apb_read_write_slave_seq extends fpt_apb_slave_seq;
    `uvm_object_utils(fpt_apb_read_write_slave_seq)

    bit [`FPT_APB_ADDR_WIDTH-1:0] base_address = 'b0;
    bit [`FPT_APB_DATA_WIDTH-1:0] mem_size = 'h00010000;
    int unsigned num_test = 100;

    function new(string name = "fpt_apb_read_write_slave_seq");
        super.new(name);
    endfunction

    virtual task body();
        // One pre-write read, one write, and one readback per address.
        for (int unsigned i = 0; i < num_test * 3; i++) begin
            apb_slave_resp(RAND_DELAY);
        end
    endtask
endclass

class fpt_apb_read_write_master_seq extends fpt_apb_master_seq;
    `uvm_object_utils(fpt_apb_read_write_master_seq)

    localparam int unsigned PSTRB_WIDTH = `FPT_APB_DATA_WIDTH / 8;

    bit [`FPT_APB_ADDR_WIDTH-1:0] base_address = 'b0;
    bit [`FPT_APB_DATA_WIDTH-1:0] mem_size = 'h00010000;
    int unsigned num_test = 100;

    bit [`FPT_APB_ADDR_WIDTH-1:0] address;
    bit [`FPT_APB_DATA_WIDTH-1:0] write_data;
    bit [`FPT_APB_DATA_WIDTH-1:0] read_data;
    bit [`FPT_APB_DATA_WIDTH-1:0] before_data;
    bit [`FPT_APB_DATA_WIDTH-1:0] expected_data;
    bit [PSTRB_WIDTH-1:0] write_strobe;
    slave_error_e read_pslverr;


    function new(string name = "fpt_apb_read_write_master_seq");
        super.new(name);
    endfunction

    virtual task body();
        for (int unsigned i = 0; i < num_test; i++) begin
            address    = base_address + (i * PSTRB_WIDTH);
            write_data = (i << 16) + i;

            apb_master_read(
                .read_address(address),
                .read_data(before_data),
                .read_pslverr(read_pslverr),
                .delay_rand(RAND_DELAY)
            );

            if (read_pslverr != NO_ERROR)
                `uvm_error("MEM_READBACK", $sformatf("Pre-write read failed at 0x%08h", address))

            apb_master_write_pstrb_rand(
                .write_address(address),
                .write_data(write_data),
                .delay_rand(RAND_DELAY),
                .write_strobe(write_strobe)
            );

            expected_data = before_data;
            for (int unsigned lane = 0; lane < PSTRB_WIDTH; lane++) begin
                if (write_strobe[lane])
                    expected_data[lane*8 +: 8] = write_data[lane*8 +: 8];
            end

            apb_master_read(
                .read_address(address),
                .read_data(read_data),
                .read_pslverr(read_pslverr),
                .delay_rand(RAND_DELAY)
            );

            if (read_pslverr != NO_ERROR || read_data !== expected_data) begin
                `uvm_error(
                    "MEM_READBACK",
                    $sformatf(
                        "Address=0x%08h PSTRB=%04b before=0x%08h write=0x%08h expected=0x%08h actual=0x%08h PSLVERR=%s",
                        address, write_strobe, before_data, write_data,
                        expected_data, read_data, read_pslverr.name()
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

        // Slave 0 answers in the background; the master decides when the test ends.
        fork
            slave_seq.start(
                apb_env_h.fpt_slave_agents[0].m_apb_slave_sequencer
            );
        join_none

        master_seq.start(
            apb_env_h.fpt_master_agent.m_apb_master_sequencer
        );
    endtask
endclass

`endif // FPT_APB_READ_WRITE_TEST_SV
