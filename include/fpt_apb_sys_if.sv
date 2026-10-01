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
    ) fpt_master_if (PCLK, PRESETn);

    fpt_apb_if #(
        .FPT_DATA_WIDTH(FPT_DATA_WIDTH), 
        .FPT_ADDR_WIDTH(FPT_ADDR_WIDTH)
    ) fpt_slave_if_arr [FPT_MAX_SLAVES] (PCLK, PRESETn);

    // 2. Hardware storage for UVM Config
    logic [31:0] fpt_slv_base_addr  [FPT_MAX_SLAVES];
    logic [31:0] fpt_slv_addr_range [FPT_MAX_SLAVES];
    bit          fpt_slv_is_active  [FPT_MAX_SLAVES];
    bit          fpt_mst_is_active;

    function void fpt_set_memory_map(int slv_idx, logic [31:0] base, logic [31:0] range);
        fpt_slv_base_addr[slv_idx]  = base;
        fpt_slv_addr_range[slv_idx] = range;
        fpt_slv_is_active[slv_idx]  = 1'b1;
    endfunction

    function void fpt_set_master_active(int mst_idx = 0);
        fpt_mst_is_active = 1'b1;
    endfunction

    // ========================================================================
    // BRIDGE SIGNALS
    // ========================================================================
    // Master Inputs -> Router (1 Master duy nhất)
    logic [FPT_ADDR_WIDTH-1:0]     mst_in_paddr;
    logic                          mst_in_pwrite;
    logic [FPT_DATA_WIDTH-1:0]     mst_in_pwdata;
    logic [(FPT_DATA_WIDTH/8)-1:0] mst_in_pstrb;
    logic                          mst_in_psel;
    logic                          mst_in_penable;

    // Router Outputs -> Master
    logic [FPT_DATA_WIDTH-1:0]     mst_out_prdata;
    logic                          mst_out_pready;
    logic                          mst_out_pslverr;

    // Slave Inputs -> Router
    logic [FPT_DATA_WIDTH-1:0]     slv_in_prdata  [FPT_MAX_SLAVES];
    logic                          slv_in_pready  [FPT_MAX_SLAVES];
    logic                          slv_in_pslverr [FPT_MAX_SLAVES];

    // Router Outputs -> Slave
    logic [FPT_ADDR_WIDTH-1:0]     slv_out_paddr   [FPT_MAX_SLAVES];
    logic                          slv_out_pwrite  [FPT_MAX_SLAVES];
    logic [FPT_DATA_WIDTH-1:0]     slv_out_pwdata  [FPT_MAX_SLAVES];
    logic                          slv_out_psel    [FPT_MAX_SLAVES];
    logic                          slv_out_penable [FPT_MAX_SLAVES];
    logic [(FPT_DATA_WIDTH/8)-1:0] slv_out_pstrb   [FPT_MAX_SLAVES];

    // Master Assertion Control (1 Master duy nhất)
    initial begin
        #1; // Đợi 1 timestep cho UVM connect_phase cập nhật cờ active
        if (fpt_mst_is_active == 1'b0) begin
            $assertoff(0, fpt_master_if);
        end
    end

    // Master Bridge (1 Master duy nhất)
    assign mst_in_paddr   = fpt_mst_is_active ? fpt_master_if.PADDR   : 'hZ;
    assign mst_in_pwrite  = fpt_mst_is_active ? fpt_master_if.PWRITE  : 1'hZ;
    assign mst_in_pwdata  = fpt_mst_is_active ? fpt_master_if.PWDATA  : 'hZ;
    assign mst_in_psel    = fpt_mst_is_active ? fpt_master_if.PSEL    : 1'bZ;
    assign mst_in_penable = fpt_mst_is_active ? fpt_master_if.PENABLE : 1'bZ;
    assign mst_in_pstrb   = fpt_mst_is_active ? fpt_master_if.PSTRB   : 'hZ;

    assign fpt_master_if.PRDATA  = mst_out_prdata;
    assign fpt_master_if.PREADY  = mst_out_pready;
    assign fpt_master_if.PSLVERR = mst_out_pslverr;

    // Slaves Assertion Control & Bridge
    genvar g;
    generate
        // for (g = 0; g < FPT_MAX_SLAVES; g++) begin : gen_slv_assert_ctrl
        //     initial begin
        //         #1; // Đợi 1 timestep cho UVM connect_phase cập nhật cờ active
        //         if (fpt_slv_is_active[g] == 1'b0) begin
        //             $assertoff(0, fpt_slave_if_arr[g]);
        //         end
        //     end
        // end

        for (g = 0; g < FPT_MAX_SLAVES; g++) begin : gen_slv_bridge
            assign slv_in_prdata[g]  = fpt_slv_is_active[g] ? fpt_slave_if_arr[g].PRDATA  : 'hZ;
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
    // ROUTING LOGIC (1 Master -> Multi Slave)
    // ========================================================================
    int fpt_target_slave;
    bit fpt_valid_slave_found;
    bit fpt_master_req;

    always_comb begin
        fpt_target_slave      = 0;
        fpt_valid_slave_found = 1'b0;
        fpt_master_req        = 1'b0;
        
        // -------------------------------------------------------------
        // BƯỚC A: REQUEST DETECTION (1 Master duy nhất)
        // -------------------------------------------------------------
        if (fpt_mst_is_active && mst_in_psel === 1'b1) begin
            fpt_master_req = 1'b1;
        end

        // -------------------------------------------------------------
        // BƯỚC B: ADDRESS DECODING
        // -------------------------------------------------------------
        if (fpt_master_req) begin
            for (int i = 0; i < FPT_MAX_SLAVES; i++) begin
                if (fpt_slv_is_active[i] && 
                    (mst_in_paddr >= fpt_slv_base_addr[i]) && 
                    (mst_in_paddr < (fpt_slv_base_addr[i] + fpt_slv_addr_range[i]))) begin
                    fpt_target_slave      = i;
                    fpt_valid_slave_found = 1'b1;
                    break;
                end
            end
        end

        // -------------------------------------------------------------
        // BƯỚC C: SIGNAL ROUTING
        // -------------------------------------------------------------
        // 1. Mặc định: Gửi tín hiệu của Master tới TẤT CẢ Slave, nhưng ngắt PSEL
        for (int i = 0; i < FPT_MAX_SLAVES; i++) begin
            slv_out_paddr[i]   = mst_in_paddr;
            slv_out_pwrite[i]  = mst_in_pwrite;
            slv_out_pwdata[i]  = mst_in_pwdata;
            slv_out_pstrb[i]   = mst_in_pstrb;
            slv_out_psel[i]    = 1'b0; 
            slv_out_penable[i] = 1'b0;
        end

        // 2. Mặc định: Trả tín hiệu về cho Master
        mst_out_prdata  = 'h0;
        mst_out_pslverr = 1'b0;
        mst_out_pready  = 1'b1;

        // 3. Kết nối thực sự giữa Master và Target Slave
        if (fpt_master_req) begin
            if (fpt_valid_slave_found) begin
                // Forward PSEL & PENABLE tới đúng Slave
                slv_out_psel[fpt_target_slave]    = mst_in_psel;
                slv_out_penable[fpt_target_slave] = mst_in_penable;

                // Trả kết quả từ đúng Slave về Master
                mst_out_prdata  = slv_in_prdata[fpt_target_slave];
                mst_out_pready  = slv_in_pready[fpt_target_slave];
                mst_out_pslverr = slv_in_pslverr[fpt_target_slave];
            end else begin
                // Master truy cập địa chỉ rác không thuộc Slave nào -> Phản hồi lỗi
                mst_out_pready  = 1'b1;
                mst_out_pslverr = 1'b1;
            end
        end
    end
endinterface

`endif // FPT_APB_SYS_IF_SV