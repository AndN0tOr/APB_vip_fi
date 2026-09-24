`ifndef FPT_APB_SLAVE_SEQ_SVH
`define FPT_APB_SLAVE_SEQ_SVH

class fpt_apb_slave_seq extends uvm_sequence#(fpt_apb_slave_seq_item);

	`uvm_object_utils(fpt_apb_slave_seq)
	int unsigned num_items = 100;
	bit use_index_delay = 1'b0;
	
	extern function new (string name = "fpt_apb_slave_seq");
	extern task body();	

	extern task apb_slave_resp(
		input delay_rand_option_e delay_rand = SET_DELAY,
		input pslverr_rand_option_e	err_rand = SET_ERR,		
		input slave_error_e response_error = NO_ERROR,
		input int unsigned  pready_delay = 0
	);
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
	
	for (int i = 0; i < num_items; i++) begin
		m_apb_slave_seq_item = fpt_apb_slave_seq_item::type_id::create("m_apb_slave_seq_item");
		start_item(m_apb_slave_seq_item);
		assert (m_apb_slave_seq_item.randomize());
		if (use_index_delay)
			m_apb_slave_seq_item.delay = i;

		if (enable_log)
		$fdisplay(log_file, "%s",
			m_apb_slave_seq_item.sprint(uvm_default_line_printer));

		finish_item(m_apb_slave_seq_item);
	end

	if (enable_log)
    $fclose(log_file);
endtask

task fpt_apb_slave_seq::apb_slave_resp(
	input delay_rand_option_e delay_rand = SET_DELAY,
	input pslverr_rand_option_e	err_rand = SET_ERR,		
	input slave_error_e response_error = NO_ERROR,
    input int unsigned  pready_delay = 0
);
    fpt_apb_slave_seq_item item;

    item = fpt_apb_slave_seq_item::type_id::create(
        "slave_response_item"
    );

    start_item(item);

	item.rand_mode(0);

	item.delay.rand_mode(delay_rand == RAND_DELAY);
    item.PSLVERR.rand_mode(err_rand == RAND_ERR);

    // Assign fields that are not being randomized.
    if (delay_rand == SET_DELAY)
        item.delay = pready_delay;

    if (err_rand == SET_ERR)
        item.PSLVERR = response_error;

    if ((delay_rand == RAND_DELAY) || (err_rand   == RAND_ERR)) begin
        if (!item.randomize())
            `uvm_fatal(
                "RAND_FAIL",
                "Failed to randomize slave response"
            )
    end

    finish_item(item);
endtask


`endif
