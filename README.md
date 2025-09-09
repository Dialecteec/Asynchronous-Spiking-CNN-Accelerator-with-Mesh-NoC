# Asynchronous-Spiking-CNN-Accelerator-with-Mesh-NoC

## 🚀 Key Features
- **Spiking CNN with output-stationary dataflow**  
  Efficient reuse of input spikes and weights to reduce memory traffic.
- **Mesh NoC (2×3 topology)**  
  Scalable interconnect with deterministic XY routing.
- **Packet-based communication**  
  64-bit packets with hop counts, direction flags, and payload.
- **Processing Elements (PEs)**  
  Gate-level bundled-data micropipeline for spiking convolution.
- **Verification & Testing**  
  Gather testbench methodology for router/mesh correctness and arbitration.
- **Performance Analysis**  
  Explored buffering, throughput, and critical path in bundled-data pipelines.

---

## 📐 Technical Specs
- Kernel size: **5 × 5**  
- Input feature map: **25 × 25**  
- Channels: **1 input, 1 output**  
- Router: **5-port** (N/S/E/W + local)  
- Routing: **Deterministic XY**

---

## 🏗 Architecture Overview
- **NoC:** 2×3 mesh of routers connecting 5 PEs, controller, and memory.  
- **Router:** Arbitration modules with hierarchical 2-input/4-input merges.  
- **PE:** Includes packetizer/de-packetizer and spiking MAC operations.  
- **Controller:** Manages memory access, weight distribution, and synchronization.  

---

## 🔧 Improvements
- Reduced redundant input fetches with **larger controller buffering**.  
- Bundled-data micropipeline tested at **7 ns total latency**, bottlenecked by adder array.  

---

## 🔮 Future Work
- **Multicasting support** for weight distribution.  
- **Advanced switching** (wormhole / virtual cut-through).  
- **Error detection/correction** (Hamming codes).  
