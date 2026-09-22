`ifndef FPT_APB_MASTER_DRIVER_SVH
`define FPT_APB_MASTER_DRIVER_SVH

class fpt_apb_master_driver extends uvm_driver #(fpt_apb_master_seq_item);
    `uvm_component_utils(fpt_apb_master_driver)
    fpt_apb_vif_t vif;

    extern function new (string name = "fpt_apb_master_driver", uvm_component parent = null);
    extern virtual function void build_phase(uvm_phase phase);
    extern virtual task run_phase(uvm_phase phase);
	extern virtual task reset_detect(ref bit reset_seen);
	extern virtual task get_and_drive(input bit back_to_back, output bit transaction_completed);
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
    bit reset_seen;
    bit transaction_completed;
    bit previous_completed;
    bit back_to_back;

    super.run_phase(phase);

    previous_completed = 1'b0;
    init_signals();

    forever begin
        // Ignore first PRESET
        wait (vif.PRESETn === 1'b1);

        seq_item_port.get_next_item(req);

        // Back to back transaction is recognized when previous
        // transaction was completed successfully and no delay
        back_to_back = previous_completed && (req.delay == 0);
        reset_seen            = 1'b0;
        transaction_completed = 1'b0;

        fork : TRANSFER_OR_RESET
            get_and_drive(back_to_back, transaction_completed);
            reset_detect(reset_seen);
        join_any

        disable TRANSFER_OR_RESET;

        if (reset_seen || !vif.PRESETn) begin
            `uvm_info(
                get_type_name(),
                $sformatf(
                    "Reset detected, dropping transaction '%s'",
                    req.get_name()
                ),
                UVM_MEDIUM
            )

            // Reset or aborted transaction enters IDLE.
            init_signals();
            previous_completed = 1'b0;
        end
        else if (transaction_completed) begin
            `uvm_info(
                get_type_name(),
                $sformatf(
                    "Completed transaction '%s'",
                    req.get_name()
                ),
                UVM_MEDIUM
            )

            // End ACCESS but keep PSEL asserted so the next zero-delay
            // transaction can begin SETUP without an idle cycle.
            vif.master_drv_cb.PENABLE <= 1'b0;
            previous_completed = 1'b1;
        end
        else begin
            init_signals();
            previous_completed = 1'b0;
        end

        seq_item_port.item_done();

        // Drives PSEL = 0 when all transactions are completed
        seq_item_port.try_next_item(req);
        if (req == null) 
            vif.master_drv_cb.PSEL  <= 1'b0;
    end
endtask

// reset_detect: used for fork #1
task fpt_apb_master_driver::reset_detect(ref bit reset_seen);
    wait (vif.PRESETn === 1'b0);
    reset_seen = 1'b1;
endtask

// wait_for_pready: wait for PREADY signal from slave 
task fpt_apb_master_driver::wait_for_pready(
    input  int unsigned max_wait_cycles,
    output bit          pready_seen
);
    pready_seen = 1'b0;

    for (int unsigned wait_cycle = 0; wait_cycle < max_wait_cycles; wait_cycle++) begin
        @(vif.master_drv_cb);

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

task fpt_apb_master_driver::get_and_drive(
    input  bit back_to_back,
    output bit transaction_completed
);
    bit pready_seen;

    transaction_completed = 1'b0;

    // Align with a clocking-block event first. Assignments below will
    // then be driven at this event's output skew.
     if (!back_to_back) begin
        vif.master_drv_cb.PSEL    <= 1'b0;
        // Starting from IDLE: align before driving SETUP.
        @(vif.master_drv_cb);

        repeat (req.delay) 
            @(vif.master_drv_cb);
    end

    // SETUP phase
    vif.master_drv_cb.PSEL    <= 1'b1;
    vif.master_drv_cb.PENABLE <= 1'b0;
    vif.master_drv_cb.PADDR   <= req.PADDR;
    vif.master_drv_cb.PWDATA  <= req.PWDATA;
    vif.master_drv_cb.PSTRB   <= req.PSTRB;
    vif.master_drv_cb.PWRITE  <= req.PWRITE;

    // Hold SETUP for a complete sampled clock cycle.
    @(vif.master_drv_cb);

    // ACCESS phase
    vif.master_drv_cb.PENABLE <= 1'b1;

    wait_for_pready(100, pready_seen);

    if (!pready_seen)
        return;

    req.PSLVERR = slave_error_e'(vif.master_drv_cb.PSLVERR);

    if (req.PWRITE == READ)
        req.PRDATA = vif.master_drv_cb.PRDATA;

    transaction_completed = 1'b1;
endtask

`endif // FPT_APB_MASTER_DRIVER_SVH