`ifndef FPT_APB_SLAVE_DRIVER_SVH
`define FPT_APB_SLAVE_DRIVER_SVH

class fpt_apb_slave_driver extends uvm_driver#(fpt_apb_slave_seq_item);
    `uvm_component_utils(fpt_apb_slave_driver)

    fpt_apb_vif_t vif;
    fpt_apb_slave_seq_item m_apb_slave_seq_item;
    fpt_apb_mem_model_t fpt_mem_model;

    extern function new(string name = "fpt_apb_slave_driver", uvm_component parent = null);
	extern virtual function void build_phase(uvm_phase phase);
	extern virtual task run_phase(uvm_phase phase);
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
    if (!uvm_config_db#(fpt_apb_vif_t)::get(this, "", "fpt_apb_vif", vif)) begin
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
    bit aborted;
    byte read_bytes [3:0];
    byte write_bytes [3:0];
    init_signals();

	forever begin
        // Initial reset handling: do not consume a response item during the initial reset.
        if (!vif.PRESETn) begin
            init_signals();
            @(posedge vif.PRESETn);
        end

        // Keep one response item ready for the next observed transfer.
        m_apb_slave_seq_item = fpt_apb_slave_seq_item::type_id::create("m_apb_slave_seq_item", this);
		seq_item_port.get_next_item(m_apb_slave_seq_item);

        `uvm_info(
                "fpt_apb_slave_driver",
                $sformatf("Slave driver finished transaction #%0d", m_apb_slave_seq_item.delay),
                UVM_LOW
        )


        // -----------------------------------------------------
        // APB SETUP phase 
        // -----------------------------------------------------
        // SETUP: PSEL is high and PENABLE is low. If reset is
        // asserted after prefetching this item, drop it so the next
        // master request uses the next slave response item.
        aborted = 1'b0;
		do begin
            @(vif.slave_drv_cb);
            if (!vif.PRESETn) begin
                aborted = 1'b1;
                break;
            end
        end while (vif.slave_drv_cb.PSEL !== 1'b1 ||
                   vif.slave_drv_cb.PENABLE !== 1'b0);

        if (aborted) begin
            init_signals();
            `uvm_info(
                "fpt_apb_slave_driver",
                $sformatf(
                    "Dropping slave response with delay=%0d during reset",
                    m_apb_slave_seq_item.delay
                ),
                UVM_MEDIUM
            )
            seq_item_port.item_done();
            m_apb_slave_seq_item = null;
            continue;
        end

        // -----------------------------------------------------
        // APB ACCESS phase
        // -----------------------------------------------------
        // Count wait states from SETUP. For delay=0, drive the response
        // now so it is valid during the very first ACCESS cycle.
        for (int unsigned wait_cycle = 0;
            wait_cycle < m_apb_slave_seq_item.delay;
            wait_cycle++) 

            begin
            @(vif.slave_drv_cb);
            if (!vif.PRESETn || vif.slave_drv_cb.PSEL !== 1'b1) begin
                aborted = 1'b1;
                break;
            end
            if (vif.slave_drv_cb.PENABLE !== 1'b1) begin
                `uvm_error("APB_SETUP", "PENABLE did not assert after SETUP")
                aborted = 1'b1;
                break;
            end
        end

        if (aborted) begin
            init_signals();
            seq_item_port.item_done();
            continue;
        end

        // The master samples these outputs at the next rising edge.
        vif.slave_drv_cb.PREADY <= 1'b1;
        vif.slave_drv_cb.PSLVERR <= m_apb_slave_seq_item.PSLVERR;

        // Read from memory model
        if (vif.slave_drv_cb.PWRITE === 1'b0) begin
            fpt_mem_model.fpt_read_32(vif.slave_drv_cb.PADDR, read_bytes);
            m_apb_slave_seq_item.PRDATA = {read_bytes[3], read_bytes[2],
                        read_bytes[1], read_bytes[0]};
        end else 
            vif.slave_drv_cb.PRDATA <= '0;

        for (int i = 0; i < 4; i++) begin
            write_bytes[i] = vif.slave_drv_cb.PWDATA[i*8 +: 8];
        end
        
        // Write to memory model
        if (vif.slave_drv_cb.PWRITE && !vif.slave_drv_cb.PSLVERR) begin
            fpt_mem_model.fpt_write(
                vif.slave_drv_cb.PADDR,
                write_bytes,
                vif.slave_drv_cb.PSTRB
            );
        end
        // This edge is the completion edge when PREADY is high.
        @(vif.slave_drv_cb);
        if (!vif.PRESETn || vif.slave_drv_cb.PSEL !== 1'b1)
            aborted = 1'b1;
        else if (vif.slave_drv_cb.PENABLE !== 1'b1) begin
            `uvm_error("APB_SETUP", "PENABLE did not assert after SETUP")
            aborted = 1'b1;
        end

        init_signals();
        seq_item_port.item_done();
        if (!aborted)
            `uvm_info("fpt_apb_slave_driver", "Driver finished", UVM_LOW)
	end				
endtask

`endif // FPT_APB_SLAVE_DRIVER_SVH
