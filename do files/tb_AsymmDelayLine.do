# tb_AsymmDelayLine.do

# Exit when TB calls $stop
quit -sim

vlog -reportprogress 300 -timescale 1ns/1ps \
     +incdir+include \
     include/SystemVerilogCSP.sv \
     tb/tb_AsymmDelayLine.sv    \
     design/AsymmDelayLine.sv    \

# Run the TB
vsim -novopt work.tb_AsymmDelayLine
run -all
