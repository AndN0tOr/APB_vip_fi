`ifndef FPT_APB_BASE_TEST
`define FPT_APB_BASE_TEST

//--------------------------------------------------------------------------------------------
// Class: apb_base_test
//  Base test has the testcase scenarios for the tesbench
//  Env and Config are created in apb_base_test
//  Sequences are created and started in the test
//--------------------------------------------------------------------------------------------
class fpt_apb_base_test extends uvm_test;
    `uvm_component_utils(fpt_apb_base_test)
    
    //Variable: env_h
    //Declaring a handle for env
    fpt_apb_env apb_env_h;
    fpt_apb_sys_config fpt_sys_config;
    int err_log_fd;
    //-------------------------------------------------------
    // Externally defined Tasks and Functions
    //-------------------------------------------------------
    extern function new(string name = "fpt_apb_base_test", uvm_component parent = null);
    extern virtual function void build_phase(uvm_phase phase);
    extern virtual function void end_of_elaboration_phase(uvm_phase phase);
    extern virtual task run_phase(uvm_phase phase);
    extern virtual function void final_phase(uvm_phase phase);

    // Sequences of the test, declared in config_seqs().
    fpt_apb_master_seq master_seq;    // The one sequence run on the master
    fpt_apb_slave_seq  slave_seqs[];  // slave_seqs[i] answers on slave agent i

    extern virtual function void config_seqs();
    extern virtual task seq_control();

endclass : fpt_apb_base_test

//--------------------------------------------------------------------------------------------
// Construct: new
//
// Parameters:
//  name - apb_base_test
//  parent - parent under which this component is created
//--------------------------------------------------------------------------------------------
function fpt_apb_base_test::new(string name = "fpt_apb_base_test",uvm_component parent = null);
    super.new(name, parent);
endfunction : new

//--------------------------------------------------------------------------------------------
// Function: build_phase
//  Creates env and required configuarions
//
// Parameters:
//  phase - uvm phase
//--------------------------------------------------------------------------------------------
function void fpt_apb_base_test::build_phase(uvm_phase phase);
    super.build_phase(phase);
    fpt_sys_config = fpt_apb_sys_config::type_id::create("fpt_sys_config", this);
    fpt_sys_config.fpt_pready_timeout = 1000;

    // CONFIGURE NUMBER OF SLAVE AND ALLOCATE MEMORY
    fpt_sys_config.fpt_slave_numb  = 2;
    fpt_sys_config.fpt_mem_model_base_addr = new[fpt_sys_config.fpt_slave_numb];
    fpt_sys_config.fpt_mem_model_addr_range = new[fpt_sys_config.fpt_slave_numb];
    fpt_sys_config.fpt_mem_model_init_pattern = new[fpt_sys_config.fpt_slave_numb];

    // SPECIFIC INFO ABOUT MEMORY MODEL - CORRESPONDING TO THE SLAVE
    fpt_sys_config.fpt_mem_model_base_addr[0] = 'h0;
    fpt_sys_config.fpt_mem_model_addr_range[0] = 'h10000;
    fpt_sys_config.fpt_mem_model_init_pattern[0] = FPT_MEMORY_INIT_PATTERN_E'(INCR);

    fpt_sys_config.fpt_mem_model_base_addr[1] = 'h10000;
    fpt_sys_config.fpt_mem_model_addr_range[1] = 'h10000;
    fpt_sys_config.fpt_mem_model_init_pattern[1] = FPT_MEMORY_INIT_PATTERN_E'(ALL1);

    // DEFAULT MASTER TRAFFIC (used by config_seqs)
    fpt_sys_config.fpt_master_addr_min  = 'h0;
    fpt_sys_config.fpt_master_addr_max  = 'h1FFFF;
    fpt_sys_config.fpt_master_num_trans = 500;

    // default configuration values, doesn't affect the testbench
    fpt_sys_config.fpt_clk_period = 10;

    uvm_config_db#(fpt_apb_sys_config)::set(this, "*", "fpt_apb_sys_config", fpt_sys_config);
    apb_env_h = fpt_apb_env::type_id::create("fpt_apb_env",this);
endfunction : build_phase

//--------------------------------------------------------------------------------------------
// Function: end_of_elaboration_phase
//  Used to print topology
//
// Parameters:
//  phase - uvm phase
//--------------------------------------------------------------------------------------------
function void fpt_apb_base_test::end_of_elaboration_phase(uvm_phase phase);
    super.end_of_elaboration_phase(phase);
    uvm_top.print_topology();

    // Copy warnings/errors/fatals to apb_error.log, and keep them on the
    // terminal and in simulation.log so a failure is never file-only.
    err_log_fd = $fopen("apb_error.log", "w");
    uvm_top.set_report_default_file_hier(err_log_fd);
    uvm_top.set_report_severity_action_hier(UVM_WARNING, UVM_DISPLAY | UVM_LOG | UVM_COUNT);
    uvm_top.set_report_severity_action_hier(UVM_ERROR,   UVM_DISPLAY | UVM_LOG | UVM_COUNT);
    uvm_top.set_report_severity_action_hier(UVM_FATAL,   UVM_DISPLAY | UVM_LOG | UVM_EXIT);
endfunction  : end_of_elaboration_phase

//--------------------------------------------------------------------------------------------
// Function: final_phase
//  Closes the error log after the report summary has been written.
//--------------------------------------------------------------------------------------------
function void fpt_apb_base_test::final_phase(uvm_phase phase);
    super.final_phase(phase);
    if (err_log_fd != 0)
        $fclose(err_log_fd);
endfunction : final_phase

//--------------------------------------------------------------------------------------------
// Task: run_phase
//  Raises the objection around seq_control(). The drain time keeps the phase
//  open after the last objection drops so in-flight transfers can finish.
//
// Parameters:
//  phase - uvm phase
//--------------------------------------------------------------------------------------------
task fpt_apb_base_test::run_phase(uvm_phase phase);
    // Per-phase objection replaces the deprecated uvm_test_done.
    phase.get_objection().set_drain_time(this, 1000ns);

    phase.raise_objection(this);
    config_seqs();
    seq_control();
    phase.drop_objection(this);
endtask : run_phase

//--------------------------------------------------------------------------------------------
// Function: config_seqs
//  Declares every sequence of the test in one place. Default: one random
//  master sequence and one random responder per slave agent.
//  A test overrides this function, optionally calling super.config_seqs()
//  first and then changing what it needs, for example:
//    master_seq    = my_master_seq::type_id::create("master_seq");
//    slave_seqs[0] = my_slave_seq::type_id::create("slave_seq_0");
//  An entry of slave_seqs left null gets no responder.
//--------------------------------------------------------------------------------------------
function void fpt_apb_base_test::config_seqs();
    master_seq = fpt_apb_master_seq::type_id::create("fpt_master_seq");
    master_seq.num_items = fpt_sys_config.fpt_master_num_trans;
    master_seq.addr_min  = fpt_sys_config.fpt_master_addr_min;
    master_seq.addr_max  = fpt_sys_config.fpt_master_addr_max;

    slave_seqs = new[apb_env_h.fpt_slave_agents.size()];
    foreach (slave_seqs[i])
        slave_seqs[i] = fpt_apb_slave_seq::type_id::create($sformatf("fpt_slave_seq_%0d", i));
endfunction : config_seqs

//--------------------------------------------------------------------------------------------
// Task: seq_control
//  Starts the slave sequences in the background, then runs the master
//  sequence. The master alone decides when the test ends.
//--------------------------------------------------------------------------------------------
task fpt_apb_base_test::seq_control();
    if (master_seq == null)
        `uvm_fatal(get_type_name(), "master_seq is null, config_seqs() declared no master sequence")

    if (slave_seqs.size() != apb_env_h.fpt_slave_agents.size())
        `uvm_fatal(get_type_name(), $sformatf(
            "slave_seqs has %0d entries but there are %0d slave agents",
            slave_seqs.size(), apb_env_h.fpt_slave_agents.size()))

    foreach (slave_seqs[i]) begin
        automatic int idx = i;
        if (slave_seqs[idx] == null)
            continue;
        fork
            slave_seqs[idx].start(apb_env_h.fpt_slave_agents[idx].m_apb_slave_sequencer);
        join_none
    end

    master_seq.start(apb_env_h.fpt_master_agent.m_apb_master_sequencer);
endtask : seq_control

`endif
