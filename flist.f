// Include Directories
+incdir+$ROOT/source
+incdir+$ROOT/source/master
+incdir+$ROOT/source/slave
+incdir+$ROOT/include
+incdir+$ROOT/tests

// Global Packages & Headers
$ROOT/source/fpt_apb_global_pkg.sv

// VIP Package Files
$ROOT/source/master/fpt_apb_master_pkg.sv
$ROOT/source/slave/fpt_apb_slave_pkg.sv

// Top-level Testbench & Interface
$ROOT/include/fpt_apb_if.sv
$ROOT/tests/fpt_apb_tb_top.sv