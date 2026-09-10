`ifndef FPT_APB_SLAVE_SEQ_SVH
`define FPT_APB_SLAVE_SEQ_SVH

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
	// Logger for slave transactions
	// Add +FPT_APB_ENABLE_FILE_LOG to command
	// Ex: python .\sim\questa.py --gui +FPT_APB_ENABLE_FILE_LOG
	bit enable_log;
	int log_file; 
	fpt_apb_slave_seq_item m_apb_slave_seq_item;

	enable_log = $test$plusargs("FPT_APB_ENABLE_FILE_LOG");

	if (enable_log) begin
    	log_file = $fopen("slave_transactions.log", "w");
		if (log_file == 0)
        `uvm_fatal(get_type_name(), "Cannot open transaction log")
	end
	
	repeat(10) begin
		m_apb_slave_seq_item = fpt_apb_slave_seq_item::type_id::create("m_apb_slave_seq_item");
		start_item(m_apb_slave_seq_item);
		assert (m_apb_slave_seq_item.randomize());

		if (enable_log)
		$fdisplay(log_file, "%s",
			m_apb_slave_seq_item.sprint(uvm_default_line_printer));

		finish_item(m_apb_slave_seq_item);
	end

	if (enable_log)
    $fclose(log_file);
endtask

`endif