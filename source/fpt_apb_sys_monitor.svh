`ifndef FPT_APB_SYS_MONITOR_SVH
`define FPT_APB_SYS_MONITOR_SVH

// Generates uvm_analysis_imp_fpt_master, which calls write_fpt_master().
`uvm_analysis_imp_decl(_fpt_master)

//--------------------------------------------------------------------------------------------
// Class: fpt_apb_sys_monitor
//  System-level checker. It never touches pins: it only receives the transfers
//  already rebuilt by the master and slave monitors.
//
//  During the run it only records (write_fpt_master stores the master transfer, the
//  slave transfers wait in analysis FIFOs). In check_phase it:
//    1. replays the master transfers in completion order against an expected
//       memory per slave and checks every read value and every unmapped access,
//    2. checks that each slave saw exactly the transfers routed to it,
//    3. compares the final slave memories with the expected ones.
//
//  Expected memory policy (copied from fpt_apb_slave_driver):
//    - a write is committed only when it completes with PSLVERR == NO_ERROR,
//    - byte lane i of PWDATA goes to PADDR + i, only when PSTRB[i] is set,
//    - a read that completes with PSLVERR is not checked for PRDATA.
//
//  fpt_expected_mem[i] is a separate object from the slave's own memory
//  (fpt_actual_mem[i]); it starts from a copy of the initial image so the
//  INCR/ALL1/RAND patterns match.
//--------------------------------------------------------------------------------------------
class fpt_apb_sys_monitor extends uvm_scoreboard;
    `uvm_component_utils(fpt_apb_sys_monitor)

    // Max messages per slave and per check kind, so one bug cannot flood the log.
    localparam int unsigned FPT_MAX_MESSAGES_PER_CHECK = 10;

    //--------------------------------------------------------------------
    // Ports
    //--------------------------------------------------------------------
    uvm_analysis_imp_fpt_master #(fpt_apb_master_seq_item, fpt_apb_sys_monitor) fpt_master_export;
    uvm_tlm_analysis_fifo #(fpt_apb_slave_seq_item) fpt_slave_fifo[];   // one FIFO per slave

    //--------------------------------------------------------------------
    // State
    //--------------------------------------------------------------------
    fpt_apb_sys_config      fpt_sys_config;
    fpt_common_mem_model_t  fpt_expected_mem[];   // owned here, updated only by the replay
    fpt_common_mem_model_t  fpt_actual_mem[];     // slave memories, read only, set by the env

    fpt_apb_master_seq_item fpt_master_queue[$];
    time                    fpt_master_time_queue[$];   // completion time of each fpt_master_queue entry
    fpt_apb_slave_seq_item  fpt_slave_queue[][$];       // one queue per slave

    int unsigned fpt_write_count;
    int unsigned fpt_read_count;
    int unsigned fpt_error_response_count;     // transfers that completed with PSLVERR
    int unsigned fpt_unmapped_count;           // transfers whose address matches no slave
    int unsigned fpt_unmapped_error_count;     // unmapped transfers that did not get PSLVERR
    int unsigned fpt_read_data_error_count;
    int unsigned fpt_route_match_count;
    int unsigned fpt_route_error_count;
    int unsigned fpt_memory_error_count;
    int unsigned fpt_transfer_count_per_slave[];

    extern function new(string name = "fpt_apb_sys_monitor", uvm_component parent = null);
    extern virtual function void build_phase(uvm_phase phase);
    extern virtual function void start_of_simulation_phase(uvm_phase phase);
    extern virtual function void write_fpt_master(fpt_apb_master_seq_item fpt_master_item);
    extern virtual function void check_phase(uvm_phase phase);
    extern virtual function void report_phase(uvm_phase phase);

    extern function bit fpt_decode_address(
        input  bit [`FPT_APB_ADDR_WIDTH-1:0] fpt_address,
        output int unsigned                  fpt_slave_index
    );
    extern function void fpt_drain_slave_fifos();
    extern function void fpt_replay_master_transfers();
    extern function void fpt_check_routing();
    extern function void fpt_compare_final_memory();
endclass : fpt_apb_sys_monitor

function fpt_apb_sys_monitor::new(string name = "fpt_apb_sys_monitor", uvm_component parent = null);
    super.new(name, parent);
    fpt_master_export = new("fpt_master_export", this);
endfunction : new

function void fpt_apb_sys_monitor::build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(fpt_apb_sys_config)::get(this, "", "fpt_apb_sys_config", fpt_sys_config))
        `uvm_fatal(get_type_name(), "Cannot get fpt_apb_sys_config from config_db!")

    fpt_slave_fifo              = new[fpt_sys_config.fpt_slave_numb];
    fpt_slave_queue             = new[fpt_sys_config.fpt_slave_numb];
    fpt_expected_mem            = new[fpt_sys_config.fpt_slave_numb];
    fpt_actual_mem              = new[fpt_sys_config.fpt_slave_numb];
    fpt_transfer_count_per_slave = new[fpt_sys_config.fpt_slave_numb];

    foreach (fpt_slave_fifo[fpt_slave_index])
        fpt_slave_fifo[fpt_slave_index] = new($sformatf("fpt_slave_fifo_%0d", fpt_slave_index), this);
endfunction : build_phase

// The slave memories are fully initialised by the env's build_phase and no traffic
// has run yet, so a copy here is the initial image.
function void fpt_apb_sys_monitor::start_of_simulation_phase(uvm_phase phase);
    super.start_of_simulation_phase(phase);
    foreach (fpt_expected_mem[fpt_slave_index]) begin
        if (fpt_actual_mem[fpt_slave_index] == null)
            `uvm_fatal(get_type_name(), $sformatf("fpt_actual_mem[%0d] is not connected", fpt_slave_index))
        fpt_expected_mem[fpt_slave_index] =
            fpt_common_mem_model_t::type_id::create($sformatf("fpt_expected_mem_%0d", fpt_slave_index));
        fpt_expected_mem[fpt_slave_index].copy(fpt_actual_mem[fpt_slave_index]);
    end
endfunction : start_of_simulation_phase

// Record only: no checking and no waiting in a write() function.
function void fpt_apb_sys_monitor::write_fpt_master(fpt_apb_master_seq_item fpt_master_item);
    fpt_apb_master_seq_item fpt_cloned_item;
    if (fpt_master_item == null) begin
        `uvm_warning(get_type_name(), "Ignoring null master transaction")
        return;
    end
    if (!$cast(fpt_cloned_item, fpt_master_item.clone()))
        `uvm_fatal(get_type_name(), "Cannot clone master transaction")
    fpt_master_queue.push_back(fpt_cloned_item);
    fpt_master_time_queue.push_back($time);
endfunction : write_fpt_master

// Same rule as the router: PADDR in [base, base + range), lowest index first.
function bit fpt_apb_sys_monitor::fpt_decode_address(
    input  bit [`FPT_APB_ADDR_WIDTH-1:0] fpt_address,
    output int unsigned                  fpt_slave_index
);
    longint unsigned fpt_address_value = fpt_address;
    fpt_slave_index = 0;
    foreach (fpt_sys_config.fpt_mem_model_base_addr[fpt_candidate_index]) begin
        longint unsigned fpt_region_base = fpt_sys_config.fpt_mem_model_base_addr[fpt_candidate_index];
        longint unsigned fpt_region_size = fpt_sys_config.fpt_mem_model_addr_range[fpt_candidate_index];
        if (fpt_address_value >= fpt_region_base &&
            (fpt_address_value - fpt_region_base) < fpt_region_size) begin
            fpt_slave_index = fpt_candidate_index;
            return 1'b1;
        end
    end
    return 1'b0;
endfunction : fpt_decode_address

function void fpt_apb_sys_monitor::fpt_drain_slave_fifos();
    fpt_apb_slave_seq_item fpt_slave_item;
    foreach (fpt_slave_fifo[fpt_slave_index])
        while (fpt_slave_fifo[fpt_slave_index].try_get(fpt_slave_item))
            fpt_slave_queue[fpt_slave_index].push_back(fpt_slave_item);
endfunction : fpt_drain_slave_fifos

//--------------------------------------------------------------------------------------------
// fpt_replay_master_transfers: walk the master transfers in completion order. A read
// is compared with the expected memory as it was at that point of the replay, so a
// later write cannot cause a false mismatch.
//--------------------------------------------------------------------------------------------
function void fpt_apb_sys_monitor::fpt_replay_master_transfers();
    fpt_apb_master_seq_item       fpt_master_item;
    int unsigned                  fpt_slave_index;
    int unsigned                  fpt_unmapped_message_count = 0;
    byte                          fpt_write_bytes [3:0];
    byte                          fpt_read_bytes  [3:0];
    bit [`FPT_APB_DATA_WIDTH-1:0] fpt_expected_data;

    foreach (fpt_master_queue[fpt_transfer_index]) begin
        fpt_master_item = fpt_master_queue[fpt_transfer_index];

        if (!fpt_decode_address(fpt_master_item.PADDR, fpt_slave_index)) begin
            fpt_unmapped_count++;
            if (fpt_master_item.PSLVERR != ERROR) begin
                fpt_unmapped_error_count++;
                if (fpt_unmapped_message_count++ < FPT_MAX_MESSAGES_PER_CHECK)
                    `uvm_error("SYSMON_UNMAPPED", $sformatf(
                        "@%0t %s at unmapped address 0x%08h completed without PSLVERR",
                        fpt_master_time_queue[fpt_transfer_index],
                        fpt_master_item.PWRITE.name(), fpt_master_item.PADDR))
            end
            continue;
        end

        fpt_transfer_count_per_slave[fpt_slave_index]++;

        if (fpt_master_item.PSLVERR == ERROR) begin
            fpt_error_response_count++;   // no-update-on-error, read data not checked
            continue;
        end

        if (fpt_master_item.PWRITE == WRITE) begin
            foreach (fpt_write_bytes[fpt_byte_lane])
                fpt_write_bytes[fpt_byte_lane] = fpt_master_item.PWDATA[fpt_byte_lane*8 +: 8];
            fpt_expected_mem[fpt_slave_index].fpt_write(
                fpt_master_item.PADDR, fpt_write_bytes, fpt_master_item.PSTRB);
            fpt_write_count++;
        end
        else begin
            fpt_expected_mem[fpt_slave_index].fpt_read_32(fpt_master_item.PADDR, fpt_read_bytes);
            fpt_expected_data = {fpt_read_bytes[3], fpt_read_bytes[2],
                                 fpt_read_bytes[1], fpt_read_bytes[0]};
            fpt_read_count++;
            if (fpt_master_item.PRDATA !== fpt_expected_data) begin
                fpt_read_data_error_count++;
                if (fpt_read_data_error_count <= FPT_MAX_MESSAGES_PER_CHECK)
                    `uvm_error("SYSMON_RDATA", $sformatf(
                        "@%0t slave %0d read 0x%08h: expected 0x%08h, actual 0x%08h",
                        fpt_master_time_queue[fpt_transfer_index], fpt_slave_index,
                        fpt_master_item.PADDR, fpt_expected_data, fpt_master_item.PRDATA))
            end
        end
    end
endfunction : fpt_replay_master_transfers

//--------------------------------------------------------------------------------------------
// fpt_check_routing: each slave must have seen exactly the master transfers whose
// address decodes to it, in the same order and with the same contents.
//--------------------------------------------------------------------------------------------
function void fpt_apb_sys_monitor::fpt_check_routing();
    foreach (fpt_slave_queue[fpt_slave_index]) begin
        fpt_apb_master_seq_item fpt_expected_master_items[$];
        int unsigned            fpt_decoded_slave_index;
        int unsigned            fpt_message_count = 0;
        int unsigned            fpt_compare_count;

        foreach (fpt_master_queue[fpt_transfer_index])
            if (fpt_decode_address(fpt_master_queue[fpt_transfer_index].PADDR, fpt_decoded_slave_index) &&
                fpt_decoded_slave_index == fpt_slave_index)
                fpt_expected_master_items.push_back(fpt_master_queue[fpt_transfer_index]);

        if (fpt_expected_master_items.size() != fpt_slave_queue[fpt_slave_index].size()) begin
            fpt_route_error_count++;
            `uvm_error("SYSMON_ROUTE", $sformatf(
                "slave %0d saw %0d transfers, master routed %0d to it",
                fpt_slave_index, fpt_slave_queue[fpt_slave_index].size(),
                fpt_expected_master_items.size()))
        end

        fpt_compare_count = (fpt_expected_master_items.size() < fpt_slave_queue[fpt_slave_index].size()) ?
                            fpt_expected_master_items.size() : fpt_slave_queue[fpt_slave_index].size();

        for (int unsigned fpt_transfer_index = 0; fpt_transfer_index < fpt_compare_count; fpt_transfer_index++) begin
            fpt_apb_master_seq_item fpt_master_item = fpt_expected_master_items[fpt_transfer_index];
            fpt_apb_slave_seq_item  fpt_slave_item  = fpt_slave_queue[fpt_slave_index][fpt_transfer_index];
            bit                     fpt_transfer_matches;

            fpt_transfer_matches = (fpt_master_item.PADDR   == fpt_slave_item.PADDR)  &&
                                   (fpt_master_item.PWRITE  == fpt_slave_item.PWRITE) &&
                                   (fpt_master_item.PSLVERR == fpt_slave_item.PSLVERR);
            if (fpt_master_item.PWRITE == WRITE)
                fpt_transfer_matches &= (fpt_master_item.PWDATA === fpt_slave_item.PWDATA) &&
                                        (fpt_master_item.PSTRB  === fpt_slave_item.PSTRB);
            else if (fpt_master_item.PSLVERR == NO_ERROR)
                fpt_transfer_matches &= (fpt_master_item.PRDATA === fpt_slave_item.PRDATA);

            if (fpt_transfer_matches)
                fpt_route_match_count++;
            else begin
                fpt_route_error_count++;
                if (fpt_message_count++ < FPT_MAX_MESSAGES_PER_CHECK)
                    `uvm_error("SYSMON_ROUTE", $sformatf(
                        "slave %0d transfer #%0d differs: master{%s addr=0x%08h wdata=0x%08h strb=%0b rdata=0x%08h err=%s} slave{%s addr=0x%08h wdata=0x%08h strb=%0b rdata=0x%08h err=%s}",
                        fpt_slave_index, fpt_transfer_index,
                        fpt_master_item.PWRITE.name(), fpt_master_item.PADDR, fpt_master_item.PWDATA,
                        fpt_master_item.PSTRB, fpt_master_item.PRDATA, fpt_master_item.PSLVERR.name(),
                        fpt_slave_item.PWRITE.name(), fpt_slave_item.PADDR, fpt_slave_item.PWDATA,
                        fpt_slave_item.PSTRB, fpt_slave_item.PRDATA, fpt_slave_item.PSLVERR.name()))
            end
        end
    end
endfunction : fpt_check_routing

//--------------------------------------------------------------------------------------------
// fpt_compare_final_memory: expected and actual memory must hold the same bytes, and
// no byte may sit outside the slave's own region (an unaligned access at the end
// of a region spills into the next one).
//--------------------------------------------------------------------------------------------
function void fpt_apb_sys_monitor::fpt_compare_final_memory();
    foreach (fpt_actual_mem[fpt_slave_index]) begin
        longint unsigned fpt_region_base   = fpt_sys_config.fpt_mem_model_base_addr[fpt_slave_index];
        longint unsigned fpt_region_size   = fpt_sys_config.fpt_mem_model_addr_range[fpt_slave_index];
        int unsigned     fpt_message_count = 0;
        byte             fpt_expected_byte;

        foreach (fpt_actual_mem[fpt_slave_index].fpt_mem_array[fpt_byte_address]) begin
            if (!fpt_expected_mem[fpt_slave_index].fpt_mem_array.exists(fpt_byte_address)) begin
                fpt_memory_error_count++;
                if (fpt_message_count++ < FPT_MAX_MESSAGES_PER_CHECK)
                    `uvm_error("SYSMON_MEM", $sformatf(
                        "slave %0d byte 0x%08h exists in the slave memory but not in the expected memory",
                        fpt_slave_index, fpt_byte_address))
            end
            else begin
                fpt_expected_byte = fpt_expected_mem[fpt_slave_index].fpt_mem_array[fpt_byte_address];
                if (fpt_actual_mem[fpt_slave_index].fpt_mem_array[fpt_byte_address] !== fpt_expected_byte) begin
                    fpt_memory_error_count++;
                    if (fpt_message_count++ < FPT_MAX_MESSAGES_PER_CHECK)
                        `uvm_error("SYSMON_MEM", $sformatf(
                            "slave %0d byte 0x%08h: expected 0x%02h, actual 0x%02h",
                            fpt_slave_index, fpt_byte_address, fpt_expected_byte,
                            fpt_actual_mem[fpt_slave_index].fpt_mem_array[fpt_byte_address]))
                end
            end

            if (!(longint'(fpt_byte_address) >= fpt_region_base &&
                  (longint'(fpt_byte_address) - fpt_region_base) < fpt_region_size)) begin
                fpt_memory_error_count++;
                if (fpt_message_count++ < FPT_MAX_MESSAGES_PER_CHECK)
                    `uvm_error("SYSMON_MEM_RANGE", $sformatf(
                        "slave %0d memory holds byte 0x%08h outside its region [0x%08h, 0x%0h)",
                        fpt_slave_index, fpt_byte_address, fpt_region_base,
                        fpt_region_base + fpt_region_size))
            end
        end

        foreach (fpt_expected_mem[fpt_slave_index].fpt_mem_array[fpt_byte_address]) begin
            if (!fpt_actual_mem[fpt_slave_index].fpt_mem_array.exists(fpt_byte_address)) begin
                fpt_memory_error_count++;
                if (fpt_message_count++ < FPT_MAX_MESSAGES_PER_CHECK)
                    `uvm_error("SYSMON_MEM", $sformatf(
                        "slave %0d byte 0x%08h exists in the expected memory but not in the slave memory",
                        fpt_slave_index, fpt_byte_address))
            end
        end
    end
endfunction : fpt_compare_final_memory

function void fpt_apb_sys_monitor::check_phase(uvm_phase phase);
    super.check_phase(phase);
    fpt_drain_slave_fifos();

    if (fpt_master_queue.size() < fpt_sys_config.fpt_sys_monitor_min_transfer_count)
        `uvm_error("SYSMON_EMPTY", $sformatf(
            "only %0d master transfers observed, at least %0d required",
            fpt_master_queue.size(), fpt_sys_config.fpt_sys_monitor_min_transfer_count))

    fpt_replay_master_transfers();

    if (fpt_sys_config.fpt_sys_monitor_check_routing)
        fpt_check_routing();

    if (fpt_sys_config.fpt_sys_monitor_check_final_memory)
        fpt_compare_final_memory();
endfunction : check_phase

function void fpt_apb_sys_monitor::report_phase(uvm_phase phase);
    uvm_report_server fpt_report_server = uvm_report_server::get_server();
    int unsigned      fpt_uvm_error_count = fpt_report_server.get_severity_count(UVM_ERROR) +
                                            fpt_report_server.get_severity_count(UVM_FATAL);
    string            fpt_per_slave_text = "";

    super.report_phase(phase);

    foreach (fpt_transfer_count_per_slave[fpt_slave_index])
        fpt_per_slave_text = {fpt_per_slave_text,
            $sformatf(" slave%0d=%0d", fpt_slave_index, fpt_transfer_count_per_slave[fpt_slave_index])};

    `uvm_info("SYSMON_SUMMARY", $sformatf(
        "\n  ---- System monitor summary ----\n  master transfers : %0d (write %0d, read %0d, PSLVERR %0d, unmapped %0d)\n  per slave        :%s\n  read data errors : %0d\n  unmapped errors  : %0d\n  routing          : %0d matched, %0d errors\n  final memory     : %0d errors\n  UVM errors/fatal : %0d\n  RESULT           : %s",
        fpt_master_queue.size(), fpt_write_count, fpt_read_count,
        fpt_error_response_count, fpt_unmapped_count,
        fpt_per_slave_text,
        fpt_read_data_error_count,
        fpt_unmapped_error_count,
        fpt_route_match_count, fpt_route_error_count,
        fpt_memory_error_count,
        fpt_uvm_error_count,
        (fpt_uvm_error_count == 0) ? "PASS" : "FAIL"), UVM_NONE)
endfunction : report_phase

`endif // FPT_APB_SYS_MONITOR_SVH
