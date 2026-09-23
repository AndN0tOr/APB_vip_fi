`ifndef FPT_APB_SLAVE_DRIVER_SVH
`define FPT_APB_SLAVE_DRIVER_SVH

class fpt_apb_slave_driver extends uvm_driver#(fpt_apb_slave_seq_item);
    `uvm_component_utils(fpt_apb_slave_driver)

    fpt_apb_vif_t vif;
    fpt_apb_slave_seq_item m_apb_slave_seq_item;
    fpt_common_mem_model_t fpt_mem_model;

    extern function new(string name = "fpt_apb_slave_driver", uvm_component parent = null);
	extern virtual function void build_phase(uvm_phase phase);
	extern virtual task run_phase(uvm_phase phase);
    extern virtual task drive_one_response(output bit transaction_completed);
    extern virtual task reset_detect(ref bit reset_seen);
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
            `uvm_fatal("NOVIF", {"virtual interface must be set for: ", get_full_name(), ".vif"})
        end
endfunction: build_phase	

// Task: run_phase
task fpt_apb_slave_driver::run_phase(uvm_phase phase);
    bit reset_seen;
    bit transaction_completed;

	super.run_phase(phase);

    init_signals();
    forever begin
        // Do not consume a response during initial reset.
        wait (vif.PRESETn === 1'b1);

         // get_next_item supplies the sequence's response-policy item.
        seq_item_port.get_next_item(m_apb_slave_seq_item);

        reset_seen            = 1'b0;
        transaction_completed = 1'b0;

        fork: TRANSFER_OR_RESET
            drive_one_response(transaction_completed);
            reset_detect(reset_seen);
        join_any
        disable TRANSFER_OR_RESET;

        if (reset_seen || vif.PRESETn !== 1'b1) begin
            `uvm_info(
                get_type_name(),
                $sformatf(
                    "Dropping slave response with delay=%0d because of reset",
                    m_apb_slave_seq_item.delay
                ),
                UVM_MEDIUM
            )
        end

        else if (!transaction_completed) begin
            `uvm_error("APB_SLAVE", "Slave response did not complete")
        end

        else begin
            `uvm_info(
                get_type_name(),
                "Slave response completed",
                UVM_LOW
            )
        end

        // Parent owns cleanup and sequencer handshaking.
        init_signals();
        seq_item_port.item_done();
        m_apb_slave_seq_item = null;
    end
endtask

// Task: init_signals
// Description: This class is used give initial value to apb slave signals.	
task fpt_apb_slave_driver::init_signals();
	vif.slave_drv_cb.PREADY  <= 1'b0;	
    vif.slave_drv_cb.PRDATA  <= '0;	
    vif.slave_drv_cb.PSLVERR <= 1'b0;	
endtask		

// Task: reset_detect
// Definition:	this task call drive signals.
task fpt_apb_slave_driver::reset_detect(ref bit reset_seen);
    wait (vif.PRESETn === 1'b0);
    reset_seen = 1'b1;
endtask

// Task: drive_one_response
// Definition:	this task returns one response transaction
task fpt_apb_slave_driver::drive_one_response(
    output bit transaction_completed
);
    byte read_bytes  [3:0];
    byte write_bytes [3:0];

    transaction_completed = 1'b0;
    
    // ---------------------------------------------------------
    // Wait for SETUP
    // ---------------------------------------------------------
    do @(vif.slave_drv_cb);
    while (
        vif.slave_drv_cb.PSEL    !== 1'b1 ||
        vif.slave_drv_cb.PENABLE !== 1'b0
    );

    // Capture the request during SETUP.
    m_apb_slave_seq_item.PADDR = vif.slave_drv_cb.PADDR;
    m_apb_slave_seq_item.PWRITE = tx_type_e'(vif.slave_drv_cb.PWRITE);
    m_apb_slave_seq_item.PWDATA = vif.slave_drv_cb.PWDATA;
    m_apb_slave_seq_item.PSTRB = vif.slave_drv_cb.PSTRB;

    // ---------------------------------------------------------
    // ACCESS wait states
    // ---------------------------------------------------------
    repeat (m_apb_slave_seq_item.delay) begin
        @(vif.slave_drv_cb);

        if (vif.slave_drv_cb.PSEL    !== 1'b1 ||
            vif.slave_drv_cb.PENABLE !== 1'b1) begin
            `uvm_error(
                "APB_SETUP",
                "SETUP did not transition to or remain in ACCESS"
            )
            return;
        end
    end

    // ---------------------------------------------------------
    // Prepare the response
    // ---------------------------------------------------------
    vif.slave_drv_cb.PREADY <= 1'b1;
    vif.slave_drv_cb.PSLVERR <=
        m_apb_slave_seq_item.PSLVERR;

    if (m_apb_slave_seq_item.PWRITE == READ) begin
        fpt_mem_model.fpt_read_32(
            m_apb_slave_seq_item.PADDR,
            read_bytes
        );

        m_apb_slave_seq_item.PRDATA = {
            read_bytes[3],
            read_bytes[2],
            read_bytes[1],
            read_bytes[0]
        };

        vif.slave_drv_cb.PRDATA <=
            m_apb_slave_seq_item.PRDATA;
    end
    else begin
        vif.slave_drv_cb.PRDATA <= '0;
    end

    // ---------------------------------------------------------
    // Completion edge
    // ---------------------------------------------------------
    @(vif.slave_drv_cb);

    if (vif.slave_drv_cb.PSEL    !== 1'b1 ||
        vif.slave_drv_cb.PENABLE !== 1'b1) begin
        `uvm_error(
            "APB_ACCESS",
            "Transfer did not complete in ACCESS"
        )
        return;
    end

    // Commit a successful write only after completion.
    if (m_apb_slave_seq_item.PWRITE == WRITE &&
        m_apb_slave_seq_item.PSLVERR == NO_ERROR) begin

        foreach (write_bytes[i])
            write_bytes[i] =
                m_apb_slave_seq_item.PWDATA[i*8 +: 8];

        fpt_mem_model.fpt_write(
            m_apb_slave_seq_item.PADDR,
            write_bytes,
            m_apb_slave_seq_item.PSTRB
        );
    end

    transaction_completed = 1'b1;
endtask

`endif // FPT_APB_SLAVE_DRIVER_SVH
