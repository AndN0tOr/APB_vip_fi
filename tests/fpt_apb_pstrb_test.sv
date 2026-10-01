`ifndef FPT_APB_PSTRB_TEST_SV
`define FPT_APB_PSTRB_TEST_SV

class fpt_apb_pstrb_slave_seq extends fpt_apb_slave_seq;
    `uvm_object_utils(fpt_apb_pstrb_slave_seq)

    localparam int unsigned PSTRB_WIDTH = `FPT_APB_DATA_WIDTH / 8;
    localparam int unsigned PSTRB_PATTERN_COUNT = 1 << PSTRB_WIDTH;

    function new(string name = "fpt_apb_pstrb_slave_seq");
        super.new(name);
    endfunction

    virtual task body();
        // Two passes per pattern; each case reads, writes, then reads again.
        repeat (PSTRB_PATTERN_COUNT * 2 * 3) begin
            apb_slave_resp(.delay_rand(RAND_DELAY));
        end
    endtask
endclass

class fpt_apb_pstrb_master_seq extends fpt_apb_master_seq;
    `uvm_object_utils(fpt_apb_pstrb_master_seq)

    localparam int unsigned PSTRB_WIDTH = `FPT_APB_DATA_WIDTH / 8;
    localparam int unsigned PSTRB_PATTERN_COUNT = 1 << PSTRB_WIDTH;

    bit [`FPT_APB_ADDR_WIDTH-1:0] base_address = '0;
    function new(string name = "fpt_apb_pstrb_master_seq");
        super.new(name);
    endfunction

    virtual task check_strobed_write(
        input bit [`FPT_APB_ADDR_WIDTH-1:0] address,
        input bit [`FPT_APB_DATA_WIDTH-1:0] write_data,
        input bit [PSTRB_WIDTH-1:0] write_strobe
    );
        bit [`FPT_APB_DATA_WIDTH-1:0] before_data;
        bit [`FPT_APB_DATA_WIDTH-1:0] expected_data;
        bit [`FPT_APB_DATA_WIDTH-1:0] after_data;
        slave_error_e read_pslverr;

        apb_master_read(
            .read_address(address),
            .read_data(before_data),
            .read_pslverr(read_pslverr),
            .delay_rand(RAND_DELAY)
        );

        expected_data = before_data;
        for (int unsigned lane = 0; lane < PSTRB_WIDTH; lane++) begin
            if (write_strobe[lane])
                expected_data[lane*8 +: 8] = write_data[lane*8 +: 8];
        end

        apb_master_write(
            .write_address(address),
            .write_data(write_data),
            .write_strobe(write_strobe),
            .delay_rand(RAND_DELAY)
        );

        apb_master_read(
            .read_address(address),
            .read_data(after_data),
            .read_pslverr(read_pslverr),
            .delay_rand(RAND_DELAY)
        );

        if (after_data !== expected_data) begin
            `uvm_error(
                "PSTRB_READBACK",
                $sformatf(
                    "Address=0x%0h PSTRB=%04b before=0x%0h write=0x%0h expected=0x%0h actual=0x%0h",
                    address, write_strobe, before_data, write_data,
                    expected_data, after_data
                )
            )
        end
    endtask

    virtual task body();
        // First pass: strobes 0 through 15 on consecutive words.
        for (int unsigned i = 0; i < PSTRB_PATTERN_COUNT; i++) begin
            check_strobed_write(
                base_address + (i * PSTRB_WIDTH),
                32'hDEAD_BEEF,
                i
            );
        end

        // Second pass: opposite strobe on each same word. In particular,
        // PSTRB=0 must preserve a word modified by the first pass.
        for (int unsigned i = 0; i < PSTRB_PATTERN_COUNT; i++) begin
            check_strobed_write(
                base_address + (i * PSTRB_WIDTH),
                32'hCAFE_BABE,
                PSTRB_PATTERN_COUNT - 1 - i
            );
        end
    endtask
endclass

class fpt_apb_pstrb_test extends fpt_apb_base_test;
    `uvm_component_utils(fpt_apb_pstrb_test)

    function new(
        string        name = "fpt_apb_pstrb_test",
        uvm_component parent = null
    );
        super.new(name, parent);
    endfunction

    virtual task seq_control;
        fpt_apb_pstrb_master_seq master_seq;
        fpt_apb_pstrb_slave_seq  slave_seq;

        master_seq = fpt_apb_pstrb_master_seq::type_id::create("master_seq");
        slave_seq  = fpt_apb_pstrb_slave_seq::type_id::create("slave_seq");

        start_master_slave_seq(master_seq, slave_seq);
    endtask
endclass

`endif // FPT_APB_PSTRB_TEST_SV
