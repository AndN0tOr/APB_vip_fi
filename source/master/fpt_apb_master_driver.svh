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
    // extern virtual task read_method();
    // extern virtual task write_method();
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
endtask		

task fpt_apb_master_driver::get_and_drive();
    // Khởi tạo tín hiệu một lần duy nhất trước khi vào vòng lặp
    init_signals();
    
    // Thêm vòng lặp forever để liên tục nhận transaction
    forever begin
        int unsigned wait_cycles;
        // 1. Nhận item từ sequencer
        seq_item_port.get_next_item(req);
        
        // Căn chỉnh theo sườn clock trước khi bắt đầu transfer
        @(vif.master_drv_cb);

        // ---------------------------------------------------------
        // SETUP PHASE
        // ---------------------------------------------------------
        vif.master_drv_cb.PSEL    <= 1'b1;
        vif.master_drv_cb.PENABLE <= 1'b0;
        
        // Mẹo: Thay vì fix cứng 1'b0 (chỉ Read), bạn có thể dùng req.PWRITE 
        // để driver này hỗ trợ cả lệnh Read và lệnh Write nhé.
        vif.master_drv_cb.PWRITE  <= req.PWRITE; 
        vif.master_drv_cb.PADDR   <= req.PADDR; 

        // ---------------------------------------------------------
        // ACCESS PHASE
        // ---------------------------------------------------------
        @(vif.master_drv_cb);
        vif.master_drv_cb.PENABLE <= 1'b1;

        

        // Wait for PREADY, timeout if cycles > 100
        forever begin
            @(vif.master_drv_cb);

            // Reset occurred during the transfer.
            if (!vif.PRESETn) begin
                init_signals();
                seq_item_port.item_done();
                return;
            end

            // APB transfer completed.
            if (vif.master_drv_cb.PREADY === 1'b1)
                break;

            wait_cycles++;

            if (wait_cycles >= 100) begin
                `uvm_error(
                    "APB_TIMEOUT",
                    $sformatf(
                        "PREADY was not asserted after %0d ACCESS cycles",
                        wait_cycles
                    )
                )

                init_signals();
                seq_item_port.item_done();
                return;
            end
        end

        // ---------------------------------------------------------
        // COMPLETION & DATA CAPTURE
        // ---------------------------------------------------------
        // Do không có wait states (mặc định PREADY = 1), lấy data ngay
        req.PREADY  = vif.master_drv_cb.PREADY;
        req.PSLVERR =  slave_error_e'(vif.master_drv_cb.PSLVERR);

        if (!req.PWRITE)
            req.PRDATA = vif.master_drv_cb.PRDATA;

        
        // Đưa tín hiệu về trạng thái idle
        vif.master_drv_cb.PSEL    <= 1'b0;
        vif.master_drv_cb.PENABLE <= 1'b0;
        
        // 2. BẮT BUỘC CÓ: Báo cho sequencer biết transaction đã hoàn tất
        seq_item_port.item_done();
    end
endtask

`endif // FPT_APB_MASTER_DRIVER_SVH