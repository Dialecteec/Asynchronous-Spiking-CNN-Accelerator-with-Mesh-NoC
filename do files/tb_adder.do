# tb_adder.do

# Exit when TB calls $stop
quit -sim

vlog -reportprogress 300 -timescale 1ns/1ps \
     +incdir+include \
     include/SystemVerilogCSP.sv \
     design/adder.sv    \
     design/FDController.sv    \
     design/AsymmDelayLine.sv    \
     tb/tb_adder.sv

# Run the TB
vsim -novopt work.tb_adder
run -all
