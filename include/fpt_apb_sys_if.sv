`ifndef FPT_APB_SYS_IF_SV
`define FPT_APB_SYS_IF_SV

interface fpt_apb_sys_if_t#(
    parameter int FPT_MAX_MASTERS = 4,
    parameter int FPT_MAX_SLAVES  = 8,
    parameter int FPT_DATA_WIDTH  = 32,
    parameter int FPT_ADDR_WIDTH  = 32
)(
    input logic PCLK,
    input logic PRESETn
);

    // 1. Instantiate the physical interfaces
    fpt_apb_if #(
        .FPT_DATA_WIDTH(FPT_DATA_WIDTH), 
        .FPT_ADDR_WIDTH(FPT_ADDR_WIDTH)
    ) fpt_master_if_arr [FPT_MAX_MASTERS] (PCLK, PRESETn);

    fpt_apb_if #(
        .FPT_DATA_WIDTH(FPT_DATA_WIDTH), 
        .FPT_ADDR_WIDTH(FPT_ADDR_WIDTH)
    ) fpt_slave_if_arr [FPT_MAX_SLAVES] (PCLK, PRESETn);

    // 2. Hardware storage for UVM Config
    logic [31:0] fpt_slv_base_addr  [FPT_MAX_SLAVES];
    logic [31:0] fpt_slv_addr_range [FPT_MAX_SLAVES];
    bit          fpt_slv_is_active  [FPT_MAX_SLAVES];
    int          fpt_mst_priority   [FPT_MAX_MASTERS];
    bit          fpt_mst_is_active  [FPT_MAX_MASTERS];

    function void fpt_set_memory_map(int slv_idx, logic [31:0] base, logic [31:0] range);
        fpt_slv_base_addr[slv_idx]  = base;
        fpt_slv_addr_range[slv_idx] = range;
        fpt_slv_is_active[slv_idx]  = 1'b1;
    endfunction

    function void fpt_set_master_priority(int mst_idx, int prio);
        fpt_mst_priority[mst_idx] = prio;
        fpt_mst_is_active[mst_idx] = 1'b1;
    endfunction

    // ========================================================================
    // GIẢI PHÁP SỬA LỖI: BRIDGE ARRAYS
    // ========================================================================
    // Master Inputs -> Router
    logic [FPT_ADDR_WIDTH-1:0] mst_in_paddr   [FPT_MAX_MASTERS];
    logic                      mst_in_pwrite  [FPT_MAX_MASTERS];
    logic [FPT_DATA_WIDTH-1:0] mst_in_pwdata  [FPT_MAX_MASTERS];
    logic [(FPT_DATA_WIDTH/8)-1:0] mst_in_pstrb [FPT_MAX_MASTERS];
    logic                      mst_in_psel    [FPT_MAX_MASTERS];
    logic                      mst_in_penable [FPT_MAX_MASTERS];

    // Router Outputs -> Master
    logic [FPT_DATA_WIDTH-1:0] mst_out_prdata  [FPT_MAX_MASTERS];
    logic                      mst_out_pready  [FPT_MAX_MASTERS];
    logic                      mst_out_pslverr [FPT_MAX_MASTERS];

    // Slave Inputs -> Router
    logic [FPT_DATA_WIDTH-1:0] slv_in_prdata  [FPT_MAX_SLAVES];
    logic                      slv_in_pready  [FPT_MAX_SLAVES];
    logic                      slv_in_pslverr [FPT_MAX_SLAVES];

    // Router Outputs -> Slave
    logic [FPT_ADDR_WIDTH-1:0] slv_out_paddr   [FPT_MAX_SLAVES];
    logic                      slv_out_pwrite  [FPT_MAX_SLAVES];
    logic [FPT_DATA_WIDTH-1:0] slv_out_pwdata  [FPT_MAX_SLAVES];
    logic                      slv_out_psel    [FPT_MAX_SLAVES];
    logic                      slv_out_penable [FPT_MAX_SLAVES];
    logic [(FPT_DATA_WIDTH/8)-1:0] slv_out_pstrb [FPT_MAX_SLAVES];

    // Dùng genvar kết nối tĩnh (Static Binding) interface vào các logic arrays
    genvar g;
    generate
        // Lấy lại genvar g đã khai báo trước đó (hoặc khai báo mới genvar i_gen)
        for (g = 0; g < FPT_MAX_MASTERS; g++) begin : gen_mst_assert_ctrl
            initial begin
                #1; // Đợi 1 timestep cho UVM connect_phase cập nhật cờ active
                if (fpt_mst_is_active[g] == 1'b0) begin
                    $assertoff(0, fpt_master_if_arr[g]);
                end
            end
        end

        for (g = 0; g < FPT_MAX_SLAVES; g++) begin : gen_slv_assert_ctrl
            initial begin
                #1; // Đợi 1 timestep cho UVM connect_phase cập nhật cờ active
                if (fpt_slv_is_active[g] == 1'b0) begin
                    $assertoff(0, fpt_slave_if_arr[g]);
                end
            end
        end
    endgenerate
    generate
        for (g = 0; g < FPT_MAX_MASTERS; g++) begin : gen_mst_bridge
            assign mst_in_paddr[g]   = fpt_mst_is_active[g] ? fpt_master_if_arr[g].PADDR   : 'h0;
            assign mst_in_pwrite[g]  = fpt_mst_is_active[g] ? fpt_master_if_arr[g].PWRITE  : 1'b0;
            assign mst_in_pwdata[g]  = fpt_mst_is_active[g] ? fpt_master_if_arr[g].PWDATA  : 'h0;
            assign mst_in_psel[g]    = fpt_mst_is_active[g] ? fpt_master_if_arr[g].PSEL    : 1'b0;
            assign mst_in_penable[g] = fpt_mst_is_active[g] ? fpt_master_if_arr[g].PENABLE : 1'b0;
            assign mst_in_pstrb[g]   = fpt_mst_is_active[g] ? fpt_master_if_arr[g].PSTRB   : 'h0;

            assign fpt_master_if_arr[g].PRDATA  = mst_out_prdata[g];
            assign fpt_master_if_arr[g].PREADY  = mst_out_pready[g];
            assign fpt_master_if_arr[g].PSLVERR = mst_out_pslverr[g];
        end

        for (g = 0; g < FPT_MAX_SLAVES; g++) begin : gen_slv_bridge
            assign slv_in_prdata[g]  = fpt_slv_is_active[g] ? fpt_slave_if_arr[g].PRDATA  : 'h0;
            assign slv_in_pready[g]  = fpt_slv_is_active[g] ? fpt_slave_if_arr[g].PREADY  : 1'b0;
            assign slv_in_pslverr[g] = fpt_slv_is_active[g] ? fpt_slave_if_arr[g].PSLVERR : 1'b0;

            assign fpt_slave_if_arr[g].PADDR   = slv_out_paddr[g];
            assign fpt_slave_if_arr[g].PWRITE  = slv_out_pwrite[g];
            assign fpt_slave_if_arr[g].PWDATA  = slv_out_pwdata[g];
            assign fpt_slave_if_arr[g].PSTRB   = slv_out_pstrb[g];
            assign fpt_slave_if_arr[g].PSEL    = slv_out_psel[g];
            assign fpt_slave_if_arr[g].PENABLE = slv_out_penable[g];
        end
    endgenerate

    // ========================================================================
    // ROUTING LOGIC (Sử dụng logic arrays thay vì interface arrays)
    // ========================================================================
    int fpt_granted_master;
    int fpt_target_slave;
    bit fpt_valid_slave_found;
    bit fpt_any_master_req;

    always_comb begin
        fpt_granted_master    = 0;
        fpt_target_slave      = 0;
        fpt_valid_slave_found = 1'b0;
        fpt_any_master_req    = 1'b0;
        
        // -------------------------------------------------------------
        // BƯỚC A: ARBITRATION
        // -------------------------------------------------------------
        begin
            int fpt_curr_max_prio = -1;
            for (int i = 0; i < FPT_MAX_MASTERS; i++) begin
                // THÊM ĐIỀU KIỆN: Chỉ quan tâm nếu Master này ĐÃ ACTIVE
                if (fpt_mst_is_active[i] && mst_in_psel[i] === 1'b1) begin 
                    fpt_any_master_req = 1'b1;
                    if (fpt_mst_priority[i] > fpt_curr_max_prio) begin
                        fpt_curr_max_prio  = fpt_mst_priority[i];
                        fpt_granted_master = i;
                    end
                end
            end
        end
        // -------------------------------------------------------------
        // BƯỚC B: ADDRESS DECODING
        // -------------------------------------------------------------
        if (fpt_any_master_req) begin
            for (int i = 0; i < FPT_MAX_SLAVES; i++) begin
                if (fpt_slv_is_active[i] && 
                    (mst_in_paddr[fpt_granted_master] >= fpt_slv_base_addr[i]) && 
                    (mst_in_paddr[fpt_granted_master] < (fpt_slv_base_addr[i] + fpt_slv_addr_range[i]))) begin
                    fpt_target_slave      = i;
                    fpt_valid_slave_found = 1'b1;
                    break;
                end
            end
        end

        // -------------------------------------------------------------
        // BƯỚC C: SIGNAL ROUTING
        // -------------------------------------------------------------
        // 1. Mặc định: Gửi tín hiệu của Granted Master tới TẤT CẢ Slave, nhưng ngắt PSEL
        for (int i = 0; i < FPT_MAX_SLAVES; i++) begin
            slv_out_paddr[i]   = mst_in_paddr[fpt_granted_master];
            slv_out_pwrite[i]  = mst_in_pwrite[fpt_granted_master];
            slv_out_pwdata[i]  = mst_in_pwdata[fpt_granted_master];
            slv_out_pstrb[i]   = mst_in_pstrb[fpt_granted_master];
            slv_out_psel[i]    = 1'b0; 
            slv_out_penable[i] = 1'b0;
        end

        // 2. Mặc định: Trả tín hiệu về cho TẤT CẢ Master
        for (int i = 0; i < FPT_MAX_MASTERS; i++) begin
            mst_out_prdata[i]  = 'h0;
            mst_out_pslverr[i] = 1'b0;
            // Ép Master chờ (pready = 0) nếu nó ĐANG YÊU CẦU nhưng KHÔNG ĐƯỢC CHỌN
            mst_out_pready[i]  = (mst_in_psel[i] && (i != fpt_granted_master)) ? 1'b0 : 1'b1;
        end

        // 3. Kết nối thực sự giữa Granted Master và Target Slave
        if (fpt_any_master_req) begin
            if (fpt_valid_slave_found) begin
                // Forward PSEL & PENABLE tới đúng Slave
                slv_out_psel[fpt_target_slave]    = mst_in_psel[fpt_granted_master];
                slv_out_penable[fpt_target_slave] = mst_in_penable[fpt_granted_master];

                // Trả kết quả từ đúng Slave về Granted Master
                mst_out_prdata[fpt_granted_master]  = slv_in_prdata[fpt_target_slave];
                mst_out_pready[fpt_granted_master]  = slv_in_pready[fpt_target_slave];
                mst_out_pslverr[fpt_granted_master] = slv_in_pslverr[fpt_target_slave];
            end else begin
                // Master truy cập địa chỉ rác không thuộc Slave nào -> Phản hồi lỗi
                mst_out_pready[fpt_granted_master]  = 1'b1;
                mst_out_pslverr[fpt_granted_master] = 1'b1;
            end
        end
    end
endinterface

`endif // FPT_APB_SYS_IF_SV