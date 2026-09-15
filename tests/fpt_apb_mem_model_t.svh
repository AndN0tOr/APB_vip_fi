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
}FPT_MEMORY_INIT_PATTERN_E;
class fpt_apb_mem_model_t extends uvm_object;
    `uvm_object_utils(fpt_apb_mem_model_t)

    // Memory model parameters
    int unsigned fpt_mem_size; // Size of the memory in bytes
    byte fpt_mem_array[];      // Memory array to hold data

    extern function new(string name = "fpt_apb_mem_model_t", int unsigned fpt_addr_size = 16'hFFFF, int unsigned fpt_data_width = 32);
    extern function void fpt_init_mem_model(FPT_MEMORY_INIT_PATTERN_E fpt_pattern = ALL0);
    // Write / Read functions
    extern function void fpt_write (int unsigned fpt_addr, byte data [3:0], bit fpt_mem_pstrobe [3:0]);
    extern function void fpt_write_32(int unsigned fpt_addr, byte data [3:0]);
    extern function void fpt_write_8(int unsigned fpt_addr, byte data);
    extern function void fpt_read_32(int unsigned fpt_addr, byte data [3:0]);

endclass: fpt_apb_mem_model_t

function fpt_apb_mem_model_t::new(string name = "fpt_apb_mem_model_t", int unsigned fpt_addr_size = 16'hFFFF, int unsigned fpt_data_width = 32);
    super.new(name);
    fpt_mem_size = fpt_data_width / 8 * fpt_addr_size; // Calculate memory size in bytes
    fpt_mem_array = new[fpt_mem_size];
endfunction: new


function void fpt_apb_mem_model_t::fpt_init_mem_model(FPT_MEMORY_INIT_PATTERN_E fpt_pattern = ALL0);
    case(fpt_pattern)
        ALL0: begin
            foreach(fpt_mem_array[i]) begin
                fpt_mem_array[i] = 8'h00;
            end
        end
        ALL1: begin
            foreach(fpt_mem_array[i]) begin
                fpt_mem_array[i] = 8'hFF;
            end
        end
        INCR: begin
            foreach(fpt_mem_array[i]) begin
                fpt_mem_array[i] = i[7:0];
            end
        end
        RAND: begin
            foreach(fpt_mem_array[i]) begin
                fpt_mem_array[i] = randomize();
            end
        end
    endcase
endfunction: fpt_init_mem_model

function void fpt_apb_mem_model_t::fpt_write(int unsigned fpt_addr, byte data [3:0], bit fpt_mem_pstrobe [3:0]);
    for (int i = 0; i < 4; i++) begin
        if (fpt_mem_pstrobe[i]) begin
            fpt_write_8(fpt_addr + i, data[i]);
        end
    end
endfunction: fpt_write
function void fpt_apb_mem_model_t::fpt_write_32(int unsigned fpt_addr, byte data [3:0]);
    if (fpt_addr + 3 < fpt_mem_size) begin
        fpt_mem_array[fpt_addr]     = data[3];
        fpt_mem_array[fpt_addr + 1] = data[2];
        fpt_mem_array[fpt_addr + 2] = data[1];
        fpt_mem_array[fpt_addr + 3] = data[0];
    end else begin
        `uvm_error(get_type_name(), $sformatf("Write address %0h out of bounds", fpt_addr))
    end
endfunction: fpt_write_32

function void fpt_apb_mem_model_t::fpt_write_8(int unsigned fpt_addr, byte data);
    if (fpt_addr < fpt_mem_size) begin
        fpt_mem_array[fpt_addr] = data;
    end else begin
        `uvm_error(get_type_name(), $sformatf("Write address %0h out of bounds", fpt_addr))
    end
endfunction: fpt_write_8

function void fpt_apb_mem_model_t::fpt_read_32(int unsigned fpt_addr, byte data [3:0]);
    if (fpt_addr + 3 < fpt_mem_size) begin
        data[3] = fpt_mem_array[fpt_addr];
        data[2] = fpt_mem_array[fpt_addr + 1];
        data[1] = fpt_mem_array[fpt_addr + 2];
        data[0] = fpt_mem_array[fpt_addr + 3];
    end else begin
        `uvm_error(get_type_name(), $sformatf("Read address %0h out of bounds", fpt_addr))
    end
endfunction: fpt_read_32

`endif // FPT_APB_MEM_MODEL_T_SVH