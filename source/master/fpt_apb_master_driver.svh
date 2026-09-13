`ifndef FPT_APB_MASTER_DRIVER_SVH
`define FPT_APB_MASTER_DRIVER_SVH

class fpt_apb_master_driver extends uvm_driver #(fpt_apb_master_seq_item);
    `uvm_component_utils(fpt_apb_master_driver)
    fpt_apb_vif_t vif;

    extern function new (string name = "fpt_apb_master_driver", uvm_component parent = null);
    extern virtual function void build_phase(uvm_phase phase);
    extern virtual task run_phase(uvm_phase phase);
    // extern virtual task wait_for_reset();
	extern virtual task get_and_drive();
    extern virtual task setup_phase();
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
	super.run_phase(phase);

    get_and_drive();
endtask

task fpt_apb_master_driver::init_signals();
	vif.master_drv_cb.PSEL  <= 1'b0;
    vif.master_drv_cb.PENABLE <= 1'b0;
    vif.master_drv_cb.PADDR <= 'x;
    vif.master_drv_cb.PWDATA <= 'x;
    vif.master_drv_cb.PSTRB <= 'x;
    vif.master_drv_cb.PWRITE <= 'x;
endtask

task fpt_apb_master_driver::setup_phase();
    // Control signals
    vif.master_drv_cb.PSEL <= 1'b1;
    vif.master_drv_cb.PENABLE <= 1'b0;
    // Address + Data signal
    vif.master_drv_cb.PADDR <= req.PADDR;
    vif.master_drv_cb.PWDATA <= req.PWDATA;
    vif.master_drv_cb.PSTRB <= req.PSTRB;
    vif.master_drv_cb.PWRITE <= req.PWRITE;
    // just pass signals to the interface, the seq handle the data
endtask

task fpt_apb_master_driver::get_and_drive();
    int unsigned wait_cycles;

    init_signals();
    // Obtain the first transaction.
    seq_item_port.get_next_item(req);
    @(vif.master_drv_cb);

    forever begin
        // SETUP PHASE--
        setup_phase();
        // ACCESS PHASE
        @(vif.master_drv_cb);
        vif.master_drv_cb.PENABLE <= 1'b1;
        wait_cycles = 0;
        forever begin
            @(vif.master_drv_cb);
            if (!vif.PRESETn) begin
                init_signals();
                seq_item_port.item_done();
                return;
            end
            if (vif.master_drv_cb.PREADY === 1'b1)
                break;

            wait_cycles++;
            if (wait_cycles >= 100) begin
                `uvm_error(
                    "APB_TIMEOUT",
                    $sformatf(
                        "PREADY was not asserted after %0d access cycles",
                        wait_cycles
                    )
                )
                init_signals();
                seq_item_port.item_done();
                return;
            end
        end

        // -----------------------------------------------------
        // COMPLETION
        // -----------------------------------------------------
        req.PSLVERR =
            slave_error_e'(vif.master_drv_cb.PSLVERR);

        if (req.PWRITE == READ)
            req.PRDATA = vif.master_drv_cb.PRDATA;

        seq_item_port.item_done();

        // Give the sequencer an opportunity to provide the next item.
        req = null;
        seq_item_port.try_next_item(req);

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