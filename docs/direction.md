from pathlib import Path

content = """# ECE 298A Project Outline — Fixed-Weight Neural Network ASIC

## 1. Project Goal

Design and fabricate a small ASIC that performs inference for a tiny neural network whose trained weights are fixed at design time.

The chip will:

1. Receive input features through a simple digital interface.
2. Store those inputs internally.
3. Run a small fixed-weight neural network.
4. Produce a classification or regression result.
5. Return the result through the digital interface.

The initial design should prioritize simplicity, verifiability, and successful tapeout over model size or maximum performance.

---

## 2. High-Level Architecture

```text
External host / test board
        |
        | SPI or simple serial interface
        v
+---------------------------+
|       Input Interface     |
| - SPI receiver            |
| - control state machine   |
+-------------+-------------+
              |
              v
+---------------------------+
|      Input Registers      |
| x[0], x[1], ... x[N-1]    |
+-------------+-------------+
              |
              v
+---------------------------+
| Neural Network Datapath   |
|                           |
| - fixed weights           |
| - multiply/shift/add      |
| - accumulator             |
| - activation function     |
+-------------+-------------+
              |
              v
+---------------------------+
|      Output Register      |
+-------------+-------------+
              |
              v
+---------------------------+
|      Output Interface     |
| - result/status           |
+-------------+-------------+
              |
              v
External host / test board