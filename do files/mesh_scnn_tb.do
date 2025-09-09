# mesh_scnn_tb.do

# Exit when TB calls $stop
quit -sim

vlog -reportprogress 300 -timescale 1ns/1ps \
     +incdir+include \
     include/SystemVerilogCSP.sv \
     design/adder.sv \
     design/mesh.sv    \
     design/dmem.sv    \
     design/arbiter.sv    \
     design/arbiter_merge.sv    \
     design/arbiter_merge_4in.sv    \
     design/async_router.sv    \
     design/copy.sv    \
     design/merge.sv    \
     design/routing.sv    \
     design/CU_baseline.sv    \
     tb/mesh_scnn_tb.sv

# Run the TB
vsim -novopt work.mesh_scnn_tb
run -all
