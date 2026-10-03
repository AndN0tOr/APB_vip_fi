`ifndef FPT_APB_RST_TEST_SV
`define FPT_APB_RST_TEST_SV

localparam NUM_TEST = 5;

class fpt_apb_rst_slave_seq extends fpt_apb_slave_seq;
    `uvm_object_utils(fpt_apb_rst_slave_seq)

    bit [`FPT_APB_ADDR_WIDTH-1:0] base_address = 'b0;
    bit [`FPT_APB_DATA_WIDTH-1:0] mem_size = 'h00010000;
    int unsigned word_count = mem_size / 4; // 4 byte / word

    function new(string name = "fpt_apb_rst_slave_seq");
        super.new(name);
    endfunction

    virtual task body();
        // Write one 32-bit word at each address.
        for (int i = 0; i < NUM_TEST; i ++) begin
            apb_slave_resp(
                .pready_delay(i)
            );
        end

        repeat (NUM_TEST) begin
            apb_slave_resp();
        end
    endtask
endclass

class fpt_apb_rst_master_seq extends fpt_apb_master_seq;
    `uvm_object_utils(fpt_apb_rst_master_seq)

    bit [`FPT_APB_ADDR_WIDTH-1:0] base_address = 'b0;
    bit [`FPT_APB_DATA_WIDTH-1:0] mem_size = 'h00010000;
    int unsigned word_count = mem_size / 4; // 4 byte / word

    bit [`FPT_APB_ADDR_WIDTH-1:0] address;
    bit [`FPT_APB_DATA_WIDTH-1:0] write_data;
    bit [`FPT_APB_DATA_WIDTH-1:0] read_data;
    slave_error_e read_pslverr;


    function new(string name = "fpt_apb_rst_master_seq");
        super.new(name);
    endfunction

    virtual task body();
        for (int unsigned i = 0; i < NUM_TEST; i++) begin
            address    = base_address + (i * 4);
            write_data = (i << 16) + i;

            apb_master_write(
                .write_address(address), 
                .write_data(write_data), 
                .delay_rand(SET_DELAY),
                .delay(i)
            );
        end

        for (int unsigned i = 0; i < NUM_TEST ; i++) begin
            address    = base_address + (i * 4);
            write_data = (i << 16) + i;

            apb_master_read(
                .read_address(address), 
                .read_data(read_data), 
                .read_pslverr(read_pslverr),
                .delay_rand(SET_DELAY),
                .delay(i)
            );
        end

       
    endtask
endclass

class fpt_apb_rst_test extends fpt_apb_base_test;
    `uvm_component_utils(fpt_apb_rst_test)

    function new(string name = "fpt_apb_rst_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        // Every transfer of this test is cut by one of the reset pulses (C9), so the
        // system monitor sees no completed transfer. Remove once the test completes some.
        fpt_sys_config.fpt_sys_monitor_min_transfer_count = 0;
    endfunction

    virtual task run_phase(uvm_phase phase);
        fpt_apb_master_seq master_seq;
        fpt_apb_slave_seq slave_seqs[];
        fpt_apb_vif_t vif;

        phase.raise_objection(this);

        // tb_top publishes the VIF only to the agents, so look it up at the master agent's path.
        if (!uvm_config_db#(fpt_apb_vif_t)::get(this, "fpt_apb_env.master_agent", "fpt_apb_vif", vif))
            `uvm_fatal(get_type_name(), "No APB virtual interface")

        // Start traffic only after the initial reset is released.
        @(posedge vif.PRESETn);

        master_seq = fpt_apb_master_seq::type_id::create("master_seq");
        // slave_seq  = fpt_apb_slave_seq::type_id::create("slave_seq");
    

        master_seq.num_items = 5;

        // The master addresses every slave, so each one needs a responder.
        slave_seqs = new[apb_env_h.fpt_slave_agents.size()];
        foreach (slave_seqs[i]) begin
            slave_seqs[i] = fpt_apb_slave_seq::type_id::create($sformatf("slave_seq_%0d", i));
            slave_seqs[i].num_items = 5;
            slave_seqs[i].use_index_delay = 1'b1; // Delays: 0, 1, 2, 3, 4
        end

        // An aborted master setup may leave one slave response unused.
        // Finish on master activity rather than waiting for equal item counts.
        foreach (slave_seqs[i]) begin
            automatic int idx = i;
            fork
                slave_seqs[idx].start(
                    apb_env_h.fpt_slave_agents[idx].m_apb_slave_sequencer
                );
            join_none
        end

        master_seq.start(
            apb_env_h.fpt_master_agent.m_apb_master_sequencer
        );
        @(vif.slave_drv_cb);
        foreach (slave_seqs[i])
            slave_seqs[i].kill();

        phase.drop_objection(this);
    endtask
endclass

`endif // FPT_APB_RST_TEST_SV
