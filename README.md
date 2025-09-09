# Asynchronous-Spiking-CNN-Accelerator-with-Mesh-NoC
An event-driven SCNN accelerator with a 2×3 mesh NoC: five-port routers, deterministic XY routing, and 64-bit packets with hop counts and dir flags; each node integrates packetizer/de-packetizer for memory/Processing Element/controller traffic.

Designed and integrated the Processing Element’s gate-level bundled-data micropipeline (four-phase fully-decoupled controller with asymmetric Muller C-elements); measured ~7 ns pipeline latency and ≥6 ns safe input spacing under max load.

Traffic optimization: added a controller-side input buffer to eliminate redundant ifmap fetches (overlapping 5×5 windows), reducing memory traffic and modestly cutting end-to-end sim time.
