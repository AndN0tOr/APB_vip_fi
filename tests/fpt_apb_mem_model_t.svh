`ifndef FPT_APB_MEM_MODEL_T_SVH
`define FPT_APB_MEM_MODEL_T_SVH

`include "uvm_macros.svh"
import uvm_pkg::*;

typedef enum bit[2:0] {
    ALL0 = 3'b000,
    ALL1 = 3'b111,
    INCR = 3'b001,
    DECR = 3'b110,
    RAND = 3'b010
} FPT_MEMORY_INIT_PATTERN_E;

class fpt_apb_mem_model_t extends uvm_object;
    `uvm_object_utils(fpt_apb_mem_model_t)

    // Memory model parameters
    int unsigned fpt_base_addr;
    int unsigned fpt_addr_range; 
    
    // Associative array: Uses addresses as keys. Prevents out-of-memory errors
    // when using high base addresses, while naturally accepting any address written to it.
    byte fpt_mem_array[int unsigned];

    extern function new(string name = "fpt_apb_mem_model_t", int unsigned fpt_base_addr = 32'h0, int unsigned fpt_addr_range = 32'hFFFF);
    
    // UVM Core Methods
    extern virtual function void do_print(uvm_printer printer);
    extern virtual function void do_copy(uvm_object rhs);
    extern virtual function bit  do_compare(uvm_object rhs, uvm_comparer comparer);

    // Initialization
    extern function void fpt_init_mem_model(FPT_MEMORY_INIT_PATTERN_E fpt_pattern = ALL0);
    
    // Write / Read functions (Bounds checks removed as requested)
    extern function void fpt_write (int unsigned fpt_addr, byte data [3:0], bit fpt_mem_pstrobe [3:0]);
    extern function void fpt_write_32(int unsigned fpt_addr, byte data [3:0]);
    extern function void fpt_write_8(int unsigned fpt_addr, byte data);
    
    // Using 'output' ensures data is passed back to the caller
    extern function void fpt_read_32(int unsigned fpt_addr, output byte data [3:0]);
    extern function void fpt_read_8(int unsigned fpt_addr, output byte data);

endclass: fpt_apb_mem_model_t


// ------------------------------------------------------------------------
// Function Implementations
// ------------------------------------------------------------------------

function fpt_apb_mem_model_t::new(string name = "fpt_apb_mem_model_t", int unsigned fpt_base_addr = 32'h0, int unsigned fpt_addr_range = 32'hFFFF);
    super.new(name);
    this.fpt_base_addr  = fpt_base_addr;
    this.fpt_addr_range = fpt_addr_range;
endfunction: new

function void fpt_apb_mem_model_t::do_print(uvm_printer printer);
    super.do_print(printer);
    printer.print_field("fpt_base_addr", fpt_base_addr, 32, UVM_HEX);
    printer.print_field("fpt_addr_range", fpt_addr_range, 32, UVM_HEX);
    // .num() gets the current number of active entries in the associative array
    printer.print_string("fpt_mem_array", $sformatf("Associative array with %0d active bytes", fpt_mem_array.num()));
endfunction

function void fpt_apb_mem_model_t::do_copy(uvm_object rhs);
    fpt_apb_mem_model_t rhs_;
    if (!$cast(rhs_, rhs)) begin
        `uvm_error(get_type_name(), "Cast failed in do_copy()")
        return;
    end
    super.do_copy(rhs);
    this.fpt_base_addr  = rhs_.fpt_base_addr;
    this.fpt_addr_range = rhs_.fpt_addr_range;
    this.fpt_mem_array  = rhs_.fpt_mem_array; 
endfunction

function bit fpt_apb_mem_model_t::do_compare(uvm_object rhs, uvm_comparer comparer);
    fpt_apb_mem_model_t rhs_;
    bit status = 1;
    if (!$cast(rhs_, rhs)) return 0;
    
    status &= super.do_compare(rhs, comparer);
    status &= (this.fpt_base_addr == rhs_.fpt_base_addr);
    status &= (this.fpt_addr_range == rhs_.fpt_addr_range);
    return status;
endfunction

function void fpt_apb_mem_model_t::fpt_init_mem_model(FPT_MEMORY_INIT_PATTERN_E fpt_pattern = ALL0);
    int unsigned current_addr;
    
    // Initialize exactly 'fpt_addr_range' bytes, starting from 'fpt_base_addr'
    for (int i = 0; i < fpt_addr_range; i++) begin
        current_addr = fpt_base_addr + i;
        case(fpt_pattern)
            ALL0: fpt_mem_array[current_addr] = 8'h00;
            ALL1: fpt_mem_array[current_addr] = 8'hFF;
            INCR: fpt_mem_array[current_addr] = i[7:0];
            DECR: fpt_mem_array[current_addr] = ~i[7:0]; 
            RAND: fpt_mem_array[current_addr] = $urandom(); // Fixed to generate actual random data
        endcase
    end
endfunction: fpt_init_mem_model

function void fpt_apb_mem_model_t::fpt_write(int unsigned fpt_addr, byte data [3:0], bit fpt_mem_pstrobe [3:0]);
    for (int i = 0; i < 4; i++) begin
        if (fpt_mem_pstrobe[i]) begin
            fpt_write_8(fpt_addr + i, data[i]);
        end
    end
endfunction: fpt_write

function void fpt_apb_mem_model_t::fpt_write_32(int unsigned fpt_addr, byte data [3:0]);
    // No bounds checking. Associative array simply creates keys if they don't exist.
    fpt_mem_array[fpt_addr]     = data[3];
    fpt_mem_array[fpt_addr + 1] = data[2];
    fpt_mem_array[fpt_addr + 2] = data[1];
    fpt_mem_array[fpt_addr + 3] = data[0];
endfunction: fpt_write_32

function void fpt_apb_mem_model_t::fpt_write_8(int unsigned fpt_addr, byte data);
    fpt_mem_array[fpt_addr] = data;
endfunction: fpt_write_8

function void fpt_apb_mem_model_t::fpt_read_32(int unsigned fpt_addr, output byte data [3:0]);
    // Use .exists() to avoid simulator warnings when reading uninitialized memory.
    // If the master reads an address that was never written/initialized, it safely returns 8'h00.
    data[3] = fpt_mem_array.exists(fpt_addr)     ? fpt_mem_array[fpt_addr]     : 8'h00;
    data[2] = fpt_mem_array.exists(fpt_addr + 1) ? fpt_mem_array[fpt_addr + 1] : 8'h00;
    data[1] = fpt_mem_array.exists(fpt_addr + 2) ? fpt_mem_array[fpt_addr + 2] : 8'h00;
    data[0] = fpt_mem_array.exists(fpt_addr + 3) ? fpt_mem_array[fpt_addr + 3] : 8'h00;
endfunction: fpt_read_32

function void fpt_apb_mem_model_t::fpt_read_8(int unsigned fpt_addr, output byte data);
    data = fpt_mem_array.exists(fpt_addr) ? fpt_mem_array[fpt_addr] : 8'h00;
endfunction: fpt_read_8

`endif // FPT_APB_MEM_MODEL_T_SVH