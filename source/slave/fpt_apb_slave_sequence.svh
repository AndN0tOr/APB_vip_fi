`ifndef FPT_APB_SLAVE_SEQUENCE_SVH
`define FPT_APB_SLAVE_SEQUENCE_SVH

class fpt_apb_slave_seq extends uvm_sequence#(fpt_apb_slave_seq_item);

	`uvm_object_utils(fpt_apb_slave_seq)
	
	extern function new (string name = "fpt_apb_slave_seq");
	extern task body();	
endclass
	
// Function: new
function fpt_apb_slave_seq::new(string name ="fpt_apb_slave_seq");
	super.new(name);
endfunction

// Function: body
task fpt_apb_slave_seq::body();
	fpt_apb_slave_seq_item m_apb_slave_seq_item;
	
	repeat(10) begin
		m_apb_slave_seq_item = fpt_apb_slave_seq_item::type_id::create("m_apb_slave_seq_item");
		start_item(m_apb_slave_seq_item);
		assert (m_apb_slave_seq_item.randomize());
		finish_item(m_apb_slave_seq_item);
	end
endtask

`endif