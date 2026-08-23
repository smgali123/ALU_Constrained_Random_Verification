# ALU_Constrained_Random_Verification
SystemVerilog constrained-random verification testbench and design for an ALU.
1. Introduction
The objective of this project is to implement a robust, industry-standard Constrained-Random Verification (CRV) environment for a 32-bit Arithmetic Logic Unit (ALU). Instead of manual directed testing, constrained-random stimulus generation allows automated exploration of standard arithmetic paths alongside rare corner cases (such as overflows, boundary values, and division by zero).

2. Supported ALU Operations & Features
The design (design.sv) and verification environment support a comprehensive instruction set:

Arithmetic: Addition (ADD), Subtraction (SUB) with signed overflow detection.

Logic & Bitwise: AND, OR, XOR, XNOR, NOT.

Shifts: Shift Left Logical (SLL), Shift Right Logical (SRL), Shift Right Arithmetic (SRA).

Advanced Math: Multiplication (MUL), Division (DIV), and Remainder (REM) with Division-by-Zero error flagging and Zero-flag detection.

3. Verification Architecture & Methodology
Transaction Class (alu_transaction): Utilizes SystemVerilog rand variables combined with dist constraint blocks to prioritize standard math while frequently injecting edge-case values (32'h0000_0000, 32'hFFFF_FFFF, 32'h8000_0000, 32'h7FFF_FFFF).

Scoreboard & Golden Model (alu_scoreboard): Operates as a software-based reference model calculating expected outputs for each randomized test vector in real-time.

Automated Checking: Compares DUT outputs, zero flags, overflow flags, and division-by-zero flags against expected values, logging pass/fail results via mailboxes and interfaces.

4. Implementation Code Snippets
Design Module (design.sv) Summary:
module alu_rtl (
  input  logic [3:0]  alu_op,
  input  logic [31:0] operand_a,
  input  logic [31:0] operand_b,
  output logic [31:0] alu_out,
  output logic        zero_flag,
  output logic        overflow_flag,
  output logic        div_by_zero_flag
);
  // Contains combinational logic for ADD, SUB, Logical, Shifts, MUL, DIV, REM
  // and flag evaluation logic.
endmodule
@Testbench Transaction & Constraints Summary:
class alu_transaction;
  rand logic [3:0]  alu_op;
  rand logic [31:0] operand_a;
  rand logic [31:0] operand_b;

  constraint op_distribution_c { ... }
  constraint operand_a_edge_c { ... }
  constraint shift_range_c { if (alu_op >= SLL) operand_b[31:5] == 27'b0; }
endclass
5. Conclusion & Results
The testbench successfully executed 40+ randomized vectors on the ALU design in EDA Playground via VCS simulation. All test cases passed with zero mismatch errors, validating correct functionality across normal operational ranges and critical mathematical boundary conditions.
