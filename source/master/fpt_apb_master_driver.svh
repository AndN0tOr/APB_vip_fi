`ifndef FPT_APB_MASTER_DRIVER_SVH
`define FPT_APB_MASTER_DRIVER_SVH

class fpt_apb_master_driver extends uvm_driver #(fpt_apb_master_seq_item);
    `uvm_component_utils(fpt_apb_master_driver)
    fpt_apb_vif_t vif;

    extern function new (string name = "fpt_apb_master_driver", uvm_component parent = null);
    extern virtual function void build_phase(uvm_phase phase);
    extern virtual task run_phase(uvm_phase phase);
	extern virtual task handle_reset(output bit reset_handled);
	extern virtual task drop_transaction();
	extern virtual task get_and_drive();
	extern virtual task wait_for_pready(
		input  int unsigned max_wait_cycles,
		output bit          pready_seen
	);
	extern virtual task init_signals();
endclass

function fpt_apb_master_driver::new(string name = "fpt_apb_master_driver", uvm_component parent = null);
    super.new(name, parent);
endfunction

function void fpt_apb_master_driver::build_phase(uvm_phase phase);
	super.build_phase(phase);
	if (!uvm_config_db#(fpt_apb_vif_t)::get(this, "", "fpt_apb_vif", vif)) begin
		`uvm_fatal(get_full_name(), "No virtual interface specified for fpt_apb_master_driver")
	end 
endfunction: build_phase	

task fpt_apb_master_driver::run_phase(uvm_phase phase);
    bit unused_var;
    super.run_phase(phase);
    
    // Initial reset handling and get first item
    handle_reset(unused_var);

    // Driving logic for all sequence items
    get_and_drive();

    // Set to intial signals when done
    init_signals();
endtask

// handle_reset: recognize PRESETn, drop transaction and get the next sequence item
task fpt_apb_master_driver::handle_reset(output bit reset_handled);
    reset_handled = 1'b0;
    if (!vif.PRESETn) begin
        reset_handled = 1'b1;
        init_signals();
        drop_transaction();

        @(posedge vif.PRESETn);

        seq_item_port.get_next_item(req);
        @(vif.master_drv_cb);
    end
endtask

// drop_transaction: mainly used for reset handling
task fpt_apb_master_driver::drop_transaction();
    if (req != null) begin
        `uvm_info(
            get_type_name(),
            $sformatf("Dropping transaction '%s'", req.get_name()),
            UVM_MEDIUM
        )
        seq_item_port.item_done();
        req = null;
    end
endtask

// wait_for_pready: wait for PREADY signal from slave 
task fpt_apb_master_driver::wait_for_pready(
    input  int unsigned max_wait_cycles,
    output bit          pready_seen
);
    pready_seen = 1'b0;

    for (int unsigned wait_cycle = 0;
        wait_cycle < max_wait_cycles;
        wait_cycle++) begin
        @(vif.master_drv_cb);

        if (!vif.PRESETn)
            return;

        if (vif.master_drv_cb.PREADY === 1'b1) begin
            pready_seen = 1'b1;
            return;
        end
    end

    `uvm_error(
        "APB_TIMEOUT",
        $sformatf(
            "PREADY was not asserted after %0d access cycles",
            max_wait_cycles
        )
    )
endtask

task fpt_apb_master_driver::init_signals();
	vif.master_drv_cb.PSEL  <= 1'b0;
    vif.master_drv_cb.PENABLE <= 1'b0;
    vif.master_drv_cb.PADDR <= 'x;
    vif.master_drv_cb.PWDATA <= 'x;
    vif.master_drv_cb.PSTRB <= 'x;
    vif.master_drv_cb.PWRITE <= 'x;
endtask

task fpt_apb_master_driver::get_and_drive();
    bit reset_handled;
    bit pready_seen;
    bit restart_transaction;

    forever begin
        // -----------------------------------------------------
        // APB IDLE phase 
        // -----------------------------------------------------
        // Reset handling
        handle_reset(reset_handled);
        if (reset_handled)
            continue;

        // Delay before asserting PSEL.
        restart_transaction = 1'b0;

        if (req.delay > 0) begin
            vif.master_drv_cb.PSEL    <= 1'b0;
            vif.master_drv_cb.PENABLE <= 1'b0;

            repeat (req.delay) begin
                @(vif.master_drv_cb);

                handle_reset(reset_handled);
                if (reset_handled) begin
                    restart_transaction = 1'b1;
                    break;
                end
            end

            if (restart_transaction)
                continue;
        end

        // -----------------------------------------------------
        // APB SETUP phase 
        // -----------------------------------------------------
        // Drive setup signals
        vif.master_drv_cb.PSEL      <= 1'b1;
        vif.master_drv_cb.PENABLE   <= 1'b0;
        vif.master_drv_cb.PADDR     <= req.PADDR;
        vif.master_drv_cb.PWDATA    <= req.PWDATA;
        vif.master_drv_cb.PSTRB     <= req.PSTRB;
        vif.master_drv_cb.PWRITE    <= req.PWRITE;

        // -----------------------------------------------------
        // APB ACCESS PHASE
        // -----------------------------------------------------
        @(vif.master_drv_cb);

        // Reset handling
        handle_reset(reset_handled);
        if (reset_handled)
            continue;

        // Assert PENABLE
        vif.master_drv_cb.PENABLE   <= 1'b1;
        
        // Wait for PREADY from Slave and Timeout 
        wait_for_pready(100, pready_seen);
        if (!pready_seen) begin
            init_signals();
            drop_transaction();
            return;
        end

        // When PREADY is asserted, drive PENABLE and read PSLVERR, PRDATA
        vif.master_drv_cb.PENABLE <= 1'b0;
        req.PSLVERR = slave_error_e'(vif.master_drv_cb.PSLVERR);

        if (req.PWRITE == READ)
            req.PRDATA = vif.master_drv_cb.PRDATA;

        // Full transaction is completed
        seq_item_port.item_done();
        `uvm_info(
            get_type_name(),
            $sformatf("Completed transaction '%s'", req.get_name()),
            UVM_MEDIUM
        )

        // Get the next item from sequencer for continous transfer
        req = null;
        seq_item_port.try_next_item(req);

        // Else wait for the next item to be generated
        if (req == null) begin
            // No immediate transaction: enter the IDLE phase.
            vif.master_drv_cb.PSEL    <= 1'b0;
            vif.master_drv_cb.PENABLE <= 1'b0;
            // Wait until another transaction becomes available.
            seq_item_port.get_next_item(req);
            @(vif.master_drv_cb);

        end

        // If try_next_item returned an item, the loop immediately
        // drives its setup phase at the current completion edge.
        // PSEL consequently remains asserted.
    end
endtask

`endif // FPT_APB_MASTER_DRIVER_SVH