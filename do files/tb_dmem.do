# tb_dmem.do

# Exit when TB calls $stop
quit -sim

vlog -reportprogress 300 -timescale 1ns/1ps \
     +incdir+include \
     include/SystemVerilogCSP.sv \
     design/dmem.sv    \
     tb/tb_dmem.sv

# Run the TB
vsim -novopt work.tb_dmem
run -all
