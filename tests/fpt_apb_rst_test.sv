`ifndef FPT_APB_RST_TEST_SV
`define FPT_APB_RST_TEST_SV

class fpt_apb_rst_test extends fpt_apb_base_test;
    `uvm_component_utils(fpt_apb_rst_test)

    function new(string name = "fpt_apb_rst_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual task run_phase(uvm_phase phase);
        fpt_apb_master_seq master_seq;
        fpt_apb_slave_seq slave_seq;
        fpt_apb_vif_t vif;

        phase.raise_objection(this);

        if (!uvm_config_db#(fpt_apb_vif_t)::get(this, "", "fpt_apb_vif", vif))
            `uvm_fatal(get_type_name(), "No APB virtual interface")

        // Start traffic only after the initial reset is released.
        @(posedge vif.PRESETn);

        master_seq = fpt_apb_master_seq::type_id::create("master_seq");
        slave_seq  = fpt_apb_slave_seq::type_id::create("slave_seq");

        master_seq.num_items = 5;
        slave_seq.num_items = 5;
        slave_seq.use_index_delay = 1'b1; // Delays: 0, 1, 2, 3, 4

        // An aborted master setup may leave one slave response unused.
        // Finish on master activity rather than waiting for equal item counts.
        fork
            slave_seq.start(
                apb_env_h.fpt_slave_agents[0].m_apb_slave_sequencer
            );
        join_none

        master_seq.start(
            apb_env_h.fpt_master_agents[0].m_apb_master_sequencer
        );
        @(vif.slave_drv_cb);
        slave_seq.kill();

        phase.drop_objection(this);
    endtask
endclass

`endif // FPT_APB_RST_TEST_SV
