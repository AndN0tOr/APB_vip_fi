`ifndef FPT_APB_SLAVE_DRIVER_SVH
`define FPT_APB_SLAVE_DRIVER_SVH

class fpt_apb_slave_driver extends uvm_driver#(fpt_apb_slave_seq_item);
    `uvm_component_utils(fpt_apb_slave_driver)

    virtual fpt_apb_if vif;
    fpt_apb_slave_seq_item m_apb_slave_seq_item;

    extern function new(string name = "fpt_apb_slave_driver", uvm_component parent = null);
	extern virtual function void build_phase(uvm_phase phase);
	extern virtual task run_phase(uvm_phase phase);
	extern virtual task wait_for_reset();
	extern virtual task get_and_drive();
	extern virtual task init_signals();
endclass

// Function: new
function fpt_apb_slave_driver::new(string name = "fpt_apb_slave_driver", uvm_component parent = null);
    super.new(name, parent);
endfunction

// Function: build_phase
function void fpt_apb_slave_driver::build_phase(uvm_phase phase);
	super.build_phase(phase);
    if (!uvm_config_db#(virtual fpt_apb_if)::get(this, "", "fpt_apb_vif", vif)) begin
        `uvm_fatal("NO_VIF", "No virtual interface specified for fpt_apb_slave_driver")
    end
endfunction: build_phase	

// Task: run_phase
task fpt_apb_slave_driver::run_phase(uvm_phase phase);
	super.run_phase(phase);

    get_and_drive();
endtask

// Task: init_signals
// Description: This class is used give initial value to apb slave signals.	
task fpt_apb_slave_driver::init_signals();
	vif.slave_drv_cb.PREADY  <= 1'b0;	
    vif.slave_drv_cb.PRDATA  <= '0;	
    vif.slave_drv_cb.PSLVERR <= 1'b0;	
endtask		

// Task: get_and_drive
// Definition:	this task call drive signals.
task fpt_apb_slave_driver::get_and_drive();
    init_signals();

	forever begin 
		m_apb_slave_seq_item = fpt_apb_slave_seq_item::type_id::create("m_apb_slave_seq_item", this);
		seq_item_port.get_next_item(m_apb_slave_seq_item);
		
        //  Skip all PRESETn cycles while waiting for Wait for PSEL and PENABLE
		do begin
            @(vif.slave_drv_cb);
            if (!vif.PRESETn) begin
                init_signals();
                return;
            end
        end while (!(vif.slave_drv_cb.PSEL &&
                    vif.slave_drv_cb.PENABLE));
		
        // Simulation time unit delay
		#(m_apb_slave_seq_item.delay);

        // Make sure PRESETn is not asserted after delay
        if (!vif.PRESETn) begin
            init_signals();
            seq_item_port.item_done();
            continue;
        end
		
        // Drive PREADY and PSLVERR
        vif.slave_drv_cb.PREADY <= 1'b1;
        vif.slave_drv_cb.PSLVERR <= m_apb_slave_seq_item.PSLVERR;
		
		if(!vif.slave_drv_cb.PWRITE)
			vif.slave_drv_cb.PRDATA <= m_apb_slave_seq_item.PRDATA;
		else
        vif.slave_drv_cb.PRDATA <= '0;

        @ (vif.slave_drv_cb);
		vif.slave_drv_cb.PREADY <= 1'b0;	
        vif.slave_drv_cb.PSLVERR <= 1'b0;		
		
		seq_item_port.item_done();
		`uvm_info("fpt_apb_slave_driver", "Driver finished", UVM_LOW);
	end				
endtask