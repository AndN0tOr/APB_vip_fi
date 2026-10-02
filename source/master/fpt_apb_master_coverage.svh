`ifndef FPT_APB_MASTER_COVERAGE_SVH
`define FPT_APB_MASTER_COVERAGE_SVH

class fpt_apb_master_coverage extends uvm_subscriber #(fpt_apb_master_seq_item);
	`uvm_component_utils(fpt_apb_master_coverage)

	// The master monitor publishes one item for each completed APB transfer.
	covergroup fpt_apb_covergroup with function sample(
		tx_type_e pwrite,
		bit [`FPT_APB_ADDR_WIDTH-1:0] paddr,
		bit [`FPT_APB_DATA_WIDTH-1:0] pwdata,
		bit [`FPT_APB_DATA_WIDTH-1:0] prdata,
		bit [(`FPT_APB_DATA_WIDTH/8)-1:0] pstrb,
		int unsigned wait_cycles,
		slave_error_e pslverr
	);
		option.per_instance = 1;

		PWRITE_CP: coverpoint pwrite {
			bins read_transfer  = {READ};
			bins write_transfer = {WRITE};
		}

		PADDR_CP: coverpoint paddr {
			bins zero  = {32'h0};
			bins low   = {[32'h1:32'h3FFF]};
			bins mid   = {[32'h4000:32'hFFFF]};
			bins upper = {[32'h1_0000:32'hFFFF_FFFF]};
		}

		PWDATA_CP: coverpoint pwdata iff (pwrite == WRITE) {
			bins zero     = {32'h0};
			bins all_ones = {32'hFFFF_FFFF};
			bins other    = {[32'h1:32'hFFFF_FFFE]};
		}

		PRDATA_CP: coverpoint prdata
			iff (pwrite == READ && pslverr == NO_ERROR) {
			bins zero     = {32'h0};
			bins all_ones = {32'hFFFF_FFFF};
			bins other    = {[32'h1:32'hFFFF_FFFE]};
		}

		PSTRB_CP: coverpoint pstrb iff (pwrite == WRITE) {
			bins patterns[] = {[0:((1 << (`FPT_APB_DATA_WIDTH/8)) - 1)]};
		}

		// item.delay is the wait-cycle count measured by the monitor.
		WAIT_CP: coverpoint wait_cycles {
			bins no_wait = {0};
			bins short_wait = {[1:3]};
			bins medium_wait = {[4:15]};
			bins long_wait = {[16:32'hFFFF_FFFF]};
		}

		PSLVERR_CP: coverpoint pslverr {
			bins no_error = {NO_ERROR};
			bins error_response = {ERROR};
		}

		OP_X_ERROR: cross PWRITE_CP, PSLVERR_CP;
	endgroup: fpt_apb_covergroup

	extern function new(string name = "fpt_apb_master_coverage", uvm_component parent = null);

	extern virtual function void write(fpt_apb_master_seq_item t);
endclass

function fpt_apb_master_coverage::new(string name = "fpt_apb_master_coverage", uvm_component parent = null);
    super.new(name, parent);
    fpt_apb_covergroup = new();
endfunction

function void fpt_apb_master_coverage::write(fpt_apb_master_seq_item t);
	if (t == null) begin
		`uvm_warning(get_type_name(), "Ignoring null master transaction")
		return;
	end
	fpt_apb_covergroup.sample(
		t.PWRITE, t.PADDR, t.PWDATA, t.PRDATA,
		t.PSTRB, t.delay, t.PSLVERR
	);
endfunction


`endif // FPT_APB_MASTER_COVERAGE_SVH
