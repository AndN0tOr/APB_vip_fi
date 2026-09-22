`ifndef FPT_APB_MASTER_MONITOR_SVH
`define FPT_APB_MASTER_MONITOR_SVH

class fpt_apb_master_monitor extends uvm_monitor;
    `uvm_component_utils(fpt_apb_master_monitor)

    fpt_apb_vif_t vif;
    uvm_analysis_port #(fpt_apb_master_seq_item) item_collected_port;

    extern function new(
        string        name = "fpt_apb_master_monitor",
        uvm_component parent = null
    );
    extern virtual function void build_phase(uvm_phase phase);
    extern virtual task run_phase(uvm_phase phase);
endclass

function fpt_apb_master_monitor::new(
    string        name = "fpt_apb_master_monitor",
    uvm_component parent = null
);
    super.new(name, parent);
    item_collected_port = new("item_collected_port", this);
endfunction

function void fpt_apb_master_monitor::build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(fpt_apb_vif_t)::get(
            this, "", "fpt_apb_vif", vif
        )) begin
        `uvm_fatal(
            get_full_name(),
            "No virtual interface specified for fpt_apb_master_monitor"
        )
    end
endfunction : build_phase

task fpt_apb_master_monitor::run_phase(uvm_phase phase);
    fpt_apb_master_seq_item item;
    int unsigned wait_cycles;
    bit aborted;

    super.run_phase(phase);

    forever begin
        // Find a valid SETUP phase. Multiple transfers can occur per reset.
        do begin
            @(vif.master_mon_cb);
        end while (!vif.PRESETn ||
                   vif.master_mon_cb.PSEL !== 1'b1 ||
                   vif.master_mon_cb.PENABLE !== 1'b0);

        item = fpt_apb_master_seq_item::type_id::create(
            "observed_master_item",
            this
        );

        // Request signals are valid from SETUP until completion.
        item.PADDR   = vif.master_mon_cb.PADDR;
        item.PWRITE  = tx_type_e'(vif.master_mon_cb.PWRITE);
        item.PWDATA  = vif.master_mon_cb.PWDATA;
        item.PSTRB   = vif.master_mon_cb.PSTRB;

        wait_cycles = 0;
        aborted = 1'b0;

        // The next cycle must be ACCESS. Stay here through all wait states
        // and publish only on PSEL && PENABLE && PREADY.
        forever begin
            @(vif.master_mon_cb);

            if (!vif.PRESETn) begin
                aborted = 1'b1;
                break;
            end

            if (vif.master_mon_cb.PSEL !== 1'b1 ||
                vif.master_mon_cb.PENABLE !== 1'b1) begin
                `uvm_error(
                    "APB_MONITOR",
                    "SETUP did not transition to or remain in ACCESS"
                )
                aborted = 1'b1;
                break;
            end

            if (vif.master_mon_cb.PREADY === 1'b1) begin
                item.PRDATA  = vif.master_mon_cb.PRDATA;
                item.PSLVERR = slave_error_e'(
                    vif.master_mon_cb.PSLVERR
                );
                item.delay = wait_cycles;
                break;
            end

            wait_cycles++;
        end

        if (!aborted) begin
            item_collected_port.write(item);
            `uvm_info(
                get_type_name(),
                $sformatf(
                    "Observed APB transfer: address=0x%0h, write=%s, rdata=%0h wait_cycles=%0d",
                    item.PADDR,
                    item.PWRITE.name(),
                    item.PRDATA,
                    item.delay
                ),
                UVM_MEDIUM
            )
        end
    end
endtask : run_phase

`endif // FPT_APB_master_MONITOR_SVH
