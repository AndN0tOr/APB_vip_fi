`ifndef FPT_APB_MEM_RANGE_TEST_SV
`define FPT_APB_MEM_RANGE_TEST_SV

// Sweep every in-range word, then probe two aligned addresses above the range.
class fpt_apb_mem_range_slave_seq extends fpt_apb_slave_seq;
    `uvm_object_utils(fpt_apb_mem_range_slave_seq)

    bit [`FPT_APB_DATA_WIDTH-1:0] mem_size = 'h00010000;
    int unsigned word_count = mem_size / 4; // 4 byte / word

    function new(string name = "fpt_apb_mem_range_slave_seq");
        super.new(name);
    endfunction

    virtual task body();
        // Two transfers per word, plus write/read at two invalid addresses.
        for (int unsigned i = 0; i < word_count * 2 + 4; i++) begin
            apb_slave_resp(RAND_DELAY);
        end
    endtask
endclass

class fpt_apb_mem_range_master_seq extends fpt_apb_master_seq;
    `uvm_object_utils(fpt_apb_mem_range_master_seq)

    bit [`FPT_APB_ADDR_WIDTH-1:0] base_address = 'b0;
    bit [`FPT_APB_DATA_WIDTH-1:0] mem_size = 'h00010000;
    int unsigned word_count = mem_size / 4; // 4 byte / word

    bit [`FPT_APB_ADDR_WIDTH-1:0] address;
    bit [`FPT_APB_DATA_WIDTH-1:0] write_data;
    bit [`FPT_APB_DATA_WIDTH-1:0] read_data;
    slave_error_e read_pslverr;


    function new(string name = "fpt_apb_mem_range_master_seq");
        super.new(name);
    endfunction

    virtual task check_out_of_range(input bit [`FPT_APB_ADDR_WIDTH-1:0] bad_address);
        fpt_apb_master_seq_item write_item;

        // Use a request item so the test can inspect the write response.
        write_item = fpt_apb_master_seq_item::type_id::create("out_of_range_write");
        start_item(write_item);
        write_item.PADDR  = bad_address;
        write_item.PWRITE = WRITE;
        write_item.PWDATA = 32'hA5A5_5A5A;
        write_item.PSTRB  = '1;
        write_item.delay  = 0;
        finish_item(write_item);

        if (write_item.PSLVERR != ERROR) begin
            `uvm_error(
                "MEM_RANGE",
                $sformatf("Out-of-range write at 0x%0h did not return PSLVERR", bad_address)
            )
        end

        apb_master_read(
            .read_address(bad_address),
            .read_data(read_data),
            .read_pslverr(read_pslverr)
        );

        if (read_pslverr != ERROR) begin
            `uvm_error(
                "MEM_RANGE",
                $sformatf("Out-of-range read at 0x%0h did not return PSLVERR", bad_address)
            )
        end
        // PRDATA is not checked when the read completes with PSLVERR.
    endtask

    virtual task body();
        for (int unsigned i = 0; i < word_count; i++) begin
            address    = base_address + (i * 4);
            write_data = (i << 16) + i;

            apb_master_write(
                .write_address(address), 
                .write_data(write_data), 
                .delay_rand(RAND_DELAY),
                .write_strobe('hF)
            );
        end

        for (int unsigned i = 0; i < word_count; i++) begin
            address    = base_address + (i * 4);
            write_data = (i << 16) + i;

            apb_master_read(
                .read_address(address), 
                .read_data(read_data), 
                .read_pslverr(read_pslverr),
                .delay_rand(RAND_DELAY)
            );

            if (read_pslverr != NO_ERROR || read_data !== write_data) begin
                `uvm_error(
                    "MEM_READBACK",
                    $sformatf(
                        "Address=0x%08h expected=0x%08h actual=0x%08h PSLVERR=%s",
                        address, write_data, read_data, read_pslverr.name()
                    )
                )
            end
        end

        // First invalid word and the next aligned word above the region.
        check_out_of_range(base_address + mem_size);
        check_out_of_range(base_address + mem_size + 4);
    endtask
endclass

class fpt_apb_mem_range_test extends fpt_apb_base_test;
    `uvm_component_utils(fpt_apb_mem_range_test)

    function new(
        string        name = "fpt_apb_mem_range_test",
        uvm_component parent = null
    );
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        // Match the 0x10000-byte sweep to the configured slave region.
        fpt_sys_config.fpt_mem_model_addr_range[0] = 32'h0001_0000;
    endfunction

    virtual task seq_control;
        fpt_apb_mem_range_master_seq master_seq;
        fpt_apb_mem_range_slave_seq  slave_seq;

        master_seq = fpt_apb_mem_range_master_seq::type_id::create("master_seq");
        slave_seq  = fpt_apb_mem_range_slave_seq::type_id::create("slave_seq");

        start_master_slave_seq(master_seq, slave_seq);
    endtask
endclass

`endif // FPT_APB_MEM_RANGE_TEST_SV
