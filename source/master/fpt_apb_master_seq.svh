`ifndef FPT_APB_MASTER_SEQ_SVH
`define FPT_APB_MASTER_SEQ_SVH

class fpt_apb_master_seq extends uvm_sequence#(fpt_apb_master_seq_item);

	`uvm_object_utils(fpt_apb_master_seq)
	int unsigned num_items = 100;
	
	extern function new (string name = "fpt_apb_master_seq");
	extern task body();	

	 extern virtual task apb_master_write(
        input bit [`FPT_APB_ADDR_WIDTH-1:0]         write_address,
        input bit [`FPT_APB_DATA_WIDTH-1:0]         write_data,
        input bit [(`FPT_APB_DATA_WIDTH/8)-1:0]     write_strobe,
		input int unsigned delay = 0
    );

    extern virtual task apb_master_read(
        input  bit [`FPT_APB_ADDR_WIDTH-1:0] read_address,
        output bit [`FPT_APB_DATA_WIDTH-1:0] read_data
    );
endclass
	
// Function: new
function fpt_apb_master_seq::new(string name ="fpt_apb_master_seq");
	super.new(name);
endfunction

// Function: body
task fpt_apb_master_seq::body();
	bit enable_log;
	int log_file; 
	fpt_apb_master_seq_item m_apb_master_seq_item;	

	enable_log = $test$plusargs("FPT_APB_ENABLE_FILE_LOG");

	if (enable_log) begin
    	log_file = $fopen("master_transactions.log", "w");
		if (log_file == 0)
        `uvm_fatal(get_type_name(), "Cannot open transaction log")
	end
	
	repeat(num_items) begin
		m_apb_master_seq_item = fpt_apb_master_seq_item::type_id::create("m_apb_master_seq_item");
		start_item(m_apb_master_seq_item);
		assert (m_apb_master_seq_item.randomize());

		if (enable_log)
		$fdisplay(log_file, "%s",
			m_apb_master_seq_item.sprint(uvm_default_line_printer));

		finish_item(m_apb_master_seq_item);
	end
	
	if (enable_log)
    $fclose(log_file);
endtask

task fpt_apb_master_seq::apb_master_write(
    input  bit [`FPT_APB_ADDR_WIDTH-1:0]     write_address,
    input  bit [`FPT_APB_DATA_WIDTH-1:0]     write_data,
    input  bit [(`FPT_APB_DATA_WIDTH/8)-1:0] write_strobe,
	input int unsigned delay = 0
);
    fpt_apb_master_seq_item item;

    item = fpt_apb_master_seq_item::type_id::create("item");
    start_item(item);
    item.PADDR  = write_address;
    item.PWRITE = WRITE;
    item.PWDATA = write_data;
    item.PSTRB  = write_strobe;
    item.delay  = delay;
    finish_item(item);

    // if (item.PSLVERR != NO_ERROR)
    //     `uvm_error(
    //         "apb_master_write",
    //         $sformatf("Unexpected PSLVERR for %s at address 0x%0h",
    //                     direction.name(), TEST_ADDR)
    //     )
endtask


task fpt_apb_master_seq::apb_master_read(
    input   bit [`FPT_APB_ADDR_WIDTH-1:0]   read_address,
    output  bit [`FPT_APB_DATA_WIDTH-1:0]   read_data
);
    fpt_apb_master_seq_item item;

    item = fpt_apb_master_seq_item::type_id::create("item");
    start_item(item);
    item.PADDR  = read_address;
    item.PWRITE = READ;
    item.PSTRB  = 4'b0;
    item.delay  = 0;
    finish_item(item);

    // if (item.PSLVERR != NO_ERROR)
    //     `uvm_error(
    //         "apb_master_read",
    //         $sformatf("Unexpected PSLVERR for %s at address 0x%0h",
    //                     direction.name(), TEST_ADDR)
    //     )

    read_data = item.PRDATA;
endtask

`endif
