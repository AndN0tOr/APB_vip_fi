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
    //-------------------------------------------------------
    // Externally defined Tasks and Functions
    //-------------------------------------------------------
    extern function new(string name = "fpt_apb_base_test", uvm_component parent = null);
    extern virtual function void build_phase(uvm_phase phase);
    extern virtual function void end_of_elaboration_phase(uvm_phase phase);
    extern virtual task run_phase(uvm_phase phase);

    extern task start_master_slave_seq(
        uvm_sequence_base master_seq,
        uvm_sequence_base slave_seq
    );

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
    //setup_apb_env_config();
    fpt_sys_config = fpt_apb_sys_config::type_id::create("fpt_sys_config", this);
    fpt_sys_config.fpt_master_numb = 1;
    fpt_sys_config.fpt_master_priority = new[fpt_sys_config.fpt_master_numb];
    fpt_sys_config.fpt_pready_timeout = new[fpt_sys_config.fpt_master_numb];
    fpt_sys_config.fpt_master_priority[0] = 1;
    fpt_sys_config.fpt_pready_timeout[0] = 1000;

    fpt_sys_config.fpt_slave_numb  = 1;
    fpt_sys_config.fpt_mem_model_base_addr = new[fpt_sys_config.fpt_slave_numb];
    fpt_sys_config.fpt_mem_model_addr_range = new[fpt_sys_config.fpt_slave_numb];
    fpt_sys_config.fpt_mem_model_init_pattern = new[fpt_sys_config.fpt_slave_numb];
    fpt_sys_config.fpt_mem_model_base_addr[0] = 'h0;
    fpt_sys_config.fpt_mem_model_addr_range[0] = 'h0000FFFF;
    fpt_sys_config.fpt_mem_model_init_pattern[0] = FPT_MEMORY_INIT_PATTERN_E'(INCR);

    // default configuration values, doesn't affect the testbench
    fpt_sys_config.fpt_clk_period = 10;

    fpt_sys_config.fpt_pready_timeout[0] = 1000;

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
    uvm_test_done.set_drain_time(this,1000ns);
endfunction  : end_of_elaboration_phase

//--------------------------------------------------------------------------------------------
// Task: run_phase
//  Used to give 100ns delay to complete the run_phase.
//
// Parameters:
//  phase - uvm phase
//--------------------------------------------------------------------------------------------
task fpt_apb_base_test::run_phase(uvm_phase phase);
    fpt_apb_master_seq fpt_master_seq;
    fpt_apb_slave_seq  fpt_slave_seq;

    phase.raise_objection(this);

    fpt_master_seq = fpt_apb_master_seq::type_id::create("fpt_master_seq");
    fpt_slave_seq  = fpt_apb_slave_seq::type_id::create("fpt_slave_seq");
    
    seq_control();
    
    phase.drop_objection(this);
endtask : run_phase


task fpt_apb_base_test::start_master_slave_seq(
    uvm_sequence_base master_seq,
    uvm_sequence_base slave_seq
);
    fork
        slave_seq.start(apb_env_h
                .fpt_slave_agents[0]
                .m_apb_slave_sequencer
        );

        master_seq.start(
            apb_env_h
                .fpt_master_agents[0]
                .m_apb_master_sequencer
        );
    join
endtask


task fpt_apb_base_test::seq_control();
endtask

// task fpt_apb_base_test::check_read(
//     input bit [`FPT_APB_DATA_WIDTH-1:0] expected
// );
//     bit [`FPT_APB_DATA_WIDTH-1:0] actual;
//     if (actual !== expected)
//         `uvm_error(
//             "APB_MEM_TEST",
//             $sformatf("%s: expected 0x%08h, got 0x%08h",
//                         description, expected, actual)
//         )
//     // else
//     //     `uvm_info(
//     //         "APB_MEM_TEST",
//     //         $sformatf("%s passed: read 0x%08h", description, actual),
//     //         UVM_LOW
//     //     )
// endtask

`endif
