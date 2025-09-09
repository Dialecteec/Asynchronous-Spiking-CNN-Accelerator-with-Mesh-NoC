quit -sim
vlog   include/SystemVerilogCSP.sv design/CU_baseline.sv tb/tb_scnn.sv
vsim -novopt work.tb_scnn


run -all