`ifndef FPT_APB_PSLVERR_TEST_SVH
`define FPT_APB_PSLVERR_TEST_SVH

class fpt_apb_pslverr_slave_seq extends fpt_apb_slave_seq;
    `uvm_object_utils(fpt_apb_pslverr_slave_seq)

    function new(string name = "fpt_apb_pslverr_slave_seq");
        super.new(name);
    endfunction

    virtual task body();
        // Seed write, rejected write, then readback.
        apb_slave_resp(.response_error(NO_ERROR));
        apb_slave_resp(.response_error(ERROR));
        apb_slave_resp(.response_error(NO_ERROR));

        // Error for read
        apb_slave_resp(.response_error(ERROR));
    endtask
endclass

class fpt_apb_pslverr_master_seq extends fpt_apb_master_seq;
    `uvm_object_utils(fpt_apb_pslverr_master_seq)

    localparam bit [`FPT_APB_ADDR_WIDTH-1:0] TEST_ADDR = 'h100;
    localparam bit [`FPT_APB_DATA_WIDTH-1:0] OLD_DATA = 32'h1122_3344;
    localparam bit [`FPT_APB_DATA_WIDTH-1:0] NEW_DATA = 32'hAABB_CCDD;
    

    function new(string name = "fpt_apb_pslverr_master_seq");
        super.new(name);
    endfunction

    virtual task body();
        fpt_apb_master_seq_item error_write;
        bit [`FPT_APB_DATA_WIDTH-1:0] read_data;
        slave_error_e read_pslverr = NO_ERROR;

        // Establish a known value at the address.
        apb_master_write(
            .write_address(TEST_ADDR),
            .write_data(OLD_DATA),
            .write_strobe('1)
        );

        apb_master_write(
            .write_address(TEST_ADDR),
            .write_data(NEW_DATA),
            .write_strobe('1)
        );

        apb_master_read(
            .read_address(TEST_ADDR),
            .read_data(read_data),
            .read_pslverr(read_pslverr)
        );

        if (read_pslverr != NO_ERROR)
            `uvm_error("PSLVERR_TEST", "Readback unexpectedly returned PSLVERR")

        if (read_data !== OLD_DATA) begin
            `uvm_error(
                "PSLVERR_TEST",
                $sformatf(
                    "Error write changed 0x%0h: expected 0x%08h, read 0x%08h",
                    TEST_ADDR, OLD_DATA, read_data
                )
            )
        end

        // Check read PSLVERR
        apb_master_read(
            .read_address(TEST_ADDR),
            .read_data(read_data),
            .read_pslverr(read_pslverr)
        );

        if (read_pslverr != ERROR) begin
            `uvm_error(
                "PSLVERR_TEST",
                $sformatf("Master read from 0x%0h did not capture PSLVERR", TEST_ADDR)
            )
        end
    endtask
endclass

class fpt_apb_pslverr_test extends fpt_apb_base_test;
    `uvm_component_utils(fpt_apb_pslverr_test)

    function new(
        string name = "fpt_apb_pslverr_test",
        uvm_component parent = null
    );
        super.new(name, parent);
    endfunction

    virtual task seq_control();
        fpt_apb_pslverr_master_seq master_seq;
        fpt_apb_pslverr_slave_seq slave_seq;

        master_seq = fpt_apb_pslverr_master_seq::type_id::create("master_seq");
        slave_seq = fpt_apb_pslverr_slave_seq::type_id::create("slave_seq");

        start_master_slave_seq(master_seq, slave_seq);
    endtask
endclass

`endif // FPT_APB_PSLVERR_TEST_SVH
