`ifndef FPT_APB_SYS_CONFIG_SVH
`define FPT_APB_SYS_CONFIG_SVH

`include "fpt_common_mem_model_t.svh"

class fpt_apb_sys_config extends uvm_object;
    `uvm_object_utils(fpt_apb_sys_config)
    
    int unsigned fpt_clk_period;
    int unsigned fpt_slave_numb;
    int unsigned fpt_mem_model_base_addr[];
    int unsigned fpt_mem_model_addr_range[]; // Region size in bytes: [base, base + range)

    FPT_MEMORY_INIT_PATTERN_E fpt_mem_model_init_pattern[];

    int unsigned fpt_pready_timeout = 1000;
    extern function new(string name = "fpt_apb_sys_config");
    extern function void validate();

endclass: fpt_apb_sys_config

function fpt_apb_sys_config::new(string name = "fpt_apb_sys_config");
    super.new(name);
endfunction: new

// Function: validate
// Checks the slave count and address map, and reports every problem in one
// UVM_FATAL. A bad map is a testbench bug, so the run stops at build time.
function void fpt_apb_sys_config::validate();
    string           errors[$];
    string           msg;
    bit              sizes_ok;
    longint unsigned addr_limit = 64'd1 << `FPT_APB_ADDR_WIDTH;
    int unsigned     bus_bytes  = `FPT_APB_DATA_WIDTH / 8;
    longint unsigned end_i;
    longint unsigned end_j;

    if (fpt_slave_numb == 0 || fpt_slave_numb > `FPT_APB_MAX_SLAVE)
        errors.push_back($sformatf(
            "fpt_slave_numb=%0d, must be 1..%0d (FPT_APB_MAX_SLAVE)",
            fpt_slave_numb, `FPT_APB_MAX_SLAVE));

    sizes_ok = fpt_mem_model_base_addr.size()    == fpt_slave_numb &&
               fpt_mem_model_addr_range.size()   == fpt_slave_numb &&
               fpt_mem_model_init_pattern.size() == fpt_slave_numb;
    if (!sizes_ok)
        errors.push_back($sformatf(
            "array sizes base_addr=%0d addr_range=%0d init_pattern=%0d, all must equal fpt_slave_numb=%0d",
            fpt_mem_model_base_addr.size(), fpt_mem_model_addr_range.size(),
            fpt_mem_model_init_pattern.size(), fpt_slave_numb));

    // Region checks index all three arrays, so they need matching sizes.
    if (sizes_ok) begin
        foreach (fpt_mem_model_base_addr[i]) begin
            end_i = longint'(fpt_mem_model_base_addr[i]) + fpt_mem_model_addr_range[i];

            if (fpt_mem_model_addr_range[i] == 0)
                errors.push_back($sformatf("slave %0d: addr_range=0", i));
            else if (end_i > addr_limit)
                errors.push_back($sformatf(
                    "slave %0d: base 0x%08h + range 0x%08h = 0x%0h exceeds the %0d-bit address space",
                    i, fpt_mem_model_base_addr[i], fpt_mem_model_addr_range[i],
                    end_i, `FPT_APB_ADDR_WIDTH));

            // The slave driver and memory model access whole bus words.
            if (fpt_mem_model_base_addr[i] % bus_bytes != 0 ||
                fpt_mem_model_addr_range[i] % bus_bytes != 0)
                errors.push_back($sformatf(
                    "slave %0d: base 0x%08h and range 0x%08h must be multiples of %0d bytes",
                    i, fpt_mem_model_base_addr[i], fpt_mem_model_addr_range[i], bus_bytes));

            for (int j = i + 1; j < fpt_slave_numb; j++) begin
                end_j = longint'(fpt_mem_model_base_addr[j]) + fpt_mem_model_addr_range[j];
                if (fpt_mem_model_addr_range[i] != 0 && fpt_mem_model_addr_range[j] != 0 &&
                    fpt_mem_model_base_addr[i] < end_j &&
                    fpt_mem_model_base_addr[j] < end_i)
                    errors.push_back($sformatf(
                        "slave %0d [0x%08h, 0x%0h) overlaps slave %0d [0x%08h, 0x%0h)",
                        i, fpt_mem_model_base_addr[i], end_i,
                        j, fpt_mem_model_base_addr[j], end_j));
            end
        end
    end

    if (errors.size() != 0) begin
        msg = "Invalid fpt_apb_sys_config:";
        foreach (errors[k])
            msg = {msg, "\n  - ", errors[k]};
        `uvm_fatal(get_type_name(), msg)
    end
endfunction: validate
`endif // FPT_APB_SYS_CONFIG_SVH