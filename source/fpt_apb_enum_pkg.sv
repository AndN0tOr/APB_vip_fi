`ifndef FPT_APB_ENUM_SVH
`define FPT_APB_ENUM_SVH

package fpt_apb_enum_pkg;
    //-------------------------------------------------------
    // Enum : slave_error_e
    //  Used to declare enum type for the pslverr
    //-------------------------------------------------------
    typedef enum bit{
        NO_ERROR = 1'b0,
        ERROR    = 1'b1
    } slave_error_e;

    //-------------------------------------------------------
    // Enum : tx_type_e 
    //  Used to declare the type of transaction done
    //-------------------------------------------------------
    typedef enum bit{
        WRITE = 1'b1,
        READ  = 1'b0 
    } tx_type_e; 


    //-------------------------------------------------------
    // Enum : apb_fsm_state_e
    //  Used to declare the type of fsm state
    //-------------------------------------------------------
    typedef enum bit[2:0] {
        //NO_STATE, 
        IDLE,
        SETUP,
        ACCESS,
        WAIT
    }apb_fsm_state_e; 

    //-------------------------------------------------------
    // Enum : transfer_size_e
    //  Used to declare enum type for all transfer sizes
    //-------------------------------------------------------
    // typedef enum bit[31:0]{
    //     BIT_8  = 32'd8,
    //     BIT_16 = 32'd16,
    //     BIT_24 = 32'd24,
    //     BIT_32 = 32'd32
    // } transfer_size_e;

endpackage: fpt_apb_enum_pkg

`endif
