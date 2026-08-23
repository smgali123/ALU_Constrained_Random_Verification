// 1. Transaction Class
class alu_transaction;
  rand logic [3:0]  alu_op;
  rand logic [31:0] operand_a;
  rand logic [31:0] operand_b;

  localparam ADD  = 4'b0000;
  localparam SUB  = 4'b0001;
  localparam AND  = 4'b0010;
  localparam OR   = 4'b0011;
  localparam XOR  = 4'b0100;
  localparam XNOR = 4'b0101;
  localparam NOT  = 4'b0110;
  localparam SLL  = 4'b0111;
  localparam SRL  = 4'b1000;
  localparam SRA  = 4'b1001;
  localparam MUL  = 4'b1010;
  localparam DIV  = 4'b1011;
  localparam REM  = 4'b1100;

  constraint op_distribution_c {
    alu_op dist { 
      ADD  := 15, 
      SUB  := 15, 
      AND  := 8, 
      OR   := 8, 
      XOR  := 8, 
      XNOR := 8, 
      NOT  := 5,  
      SLL  := 5,  
      SRL  := 5,  
      SRA  := 5,
      MUL  := 10,
      DIV  := 8,
      REM  := 5
    };
  }

  constraint operand_a_edge_c {
    operand_a dist {
      32'h0000_0000 := 5,
      32'hFFFF_FFFF := 5,
      32'h8000_0000 := 5,
      32'h7FFF_FFFF := 5,
      [32'h0000_0001:32'h7FFE_FFFF] :/ 80
    };
  }

  constraint operand_b_edge_c {
    operand_b dist {
      32'h0000_0000 := 15,
      32'h0000_0001 := 10,
      32'hFFFF_FFFF := 5,
      [32'h0000_0002:32'h7FFF_FFFF] :/ 70
    };
  }

  constraint shift_range_c {
    if (alu_op == SLL || alu_op == SRL || alu_op == SRA) {
      operand_b[31:5] == 27'b0; 
    }
  }
endclass


// 2. Scoreboard Class
class alu_scoreboard;
  mailbox #(alu_transaction) mbx;
  alu_transaction trans;
  int error_count = 0;

  function new(mailbox #(alu_transaction) mbx);
    this.mbx = mbx;
  endfunction

  task run(virtual alu_if vif);
    forever begin
      mbx.get(trans);
      
      vif.alu_op    = trans.alu_op;
      vif.operand_a = trans.operand_a;
      vif.operand_b = trans.operand_b;
      
      #1; // Propagation delay
      
      check_result(trans, vif.alu_out, vif.zero_flag, vif.overflow_flag, vif.div_by_zero_flag);
    end
  endtask

  function void check_result(alu_transaction t, logic [31:0] actual_out, logic actual_zero, logic actual_ovf, logic actual_dbz);
    logic [31:0] expected;
    logic        exp_zero;
    logic        exp_ovf;
    logic        exp_dbz;
    
    exp_ovf = 1'b0;
    exp_dbz = 1'b0;
    
    case (t.alu_op)
      4'b0000: begin
        expected = t.operand_a + t.operand_b;
        if ((t.operand_a[31] == t.operand_b[31]) && (expected[31] != t.operand_a[31]))
          exp_ovf = 1'b1;
      end
      4'b0001: begin
        expected = t.operand_a - t.operand_b;
        if ((t.operand_a[31] != t.operand_b[31]) && (expected[31] != t.operand_a[31]))
          exp_ovf = 1'b1;
      end
      4'b0010: expected = t.operand_a & t.operand_b;
      4'b0011: expected = t.operand_a | t.operand_b;
      4'b0100: expected = t.operand_a ^ t.operand_b;
      4'b0101: expected = ~(t.operand_a ^ t.operand_b);
      4'b0110: expected = ~t.operand_a;
      4'b0111: expected = t.operand_a << t.operand_b[4:0];
      4'b1000: expected = t.operand_a >> t.operand_b[4:0];
      4'b1001: expected = $signed(t.operand_a) >>> t.operand_b[4:0];
      4'b1010: begin
        logic [63:0] mul_res;
        mul_res = {32'h0, t.operand_a} * {32'h0, t.operand_b};
        expected = mul_res[31:0];
      end
      4'b1011: begin
        if (t.operand_b == 32'h0) begin
          exp_dbz = 1'b1;
          expected = 32'hFFFF_FFFF;
        end else begin
          expected = t.operand_a / t.operand_b;
        end
      end
      4'b1100: begin
        if (t.operand_b == 32'h0) begin
          exp_dbz = 1'b1;
          expected = 32'h0;
        end else begin
          expected = t.operand_a % t.operand_b;
        end
      end
      default: expected = 32'h0;
    endcase

    exp_zero = (expected == 32'h0);

    if ((actual_out === expected) && (actual_zero === exp_zero) && (actual_ovf === exp_ovf) && (actual_dbz === exp_dbz)) begin
      $display("[PASS] Time=%0t | Op=%0b | A=%0h | B=%0h | Out=%0h | DBZ=%0b", 
                $time, t.alu_op, t.operand_a, t.operand_b, actual_out, actual_dbz);
    end else begin
      $error("[FAIL] Time=%0t | Op=%0b | A=%0h | B=%0h | ExpOut=%0h ActOut=%0h | ExpDBZ=%0b ActDBZ=%0b", 
              $time, t.alu_op, t.operand_a, t.operand_b, expected, actual_out, exp_dbz, actual_dbz);
      error_count++;
    end
  endfunction
endclass


// 3. Interface
interface alu_if;
  logic [3:0]  alu_op;
  logic [31:0] operand_a;
  logic [31:0] operand_b;
  logic [31:0] alu_out;
  logic        zero_flag;
  logic        overflow_flag;
  logic        div_by_zero_flag;
endinterface


// 4. Testbench Top Module (with VCD Dump)
module tb_top;
  mailbox #(alu_transaction) mbx;
  alu_scoreboard sb;
  alu_transaction tr;

  alu_if vif();

  alu_rtl dut (
    .alu_op(vif.alu_op),
    .operand_a(vif.operand_a),
    .operand_b(vif.operand_b),
    .alu_out(vif.alu_out),
    .zero_flag(vif.zero_flag),
    .overflow_flag(vif.overflow_flag),
    .div_by_zero_flag(vif.div_by_zero_flag)
  );

  initial begin
    // --- VCD Waveform Generation for EPWave ---
    $dumpfile("dump.vcd");
    $dumpvars(0, tb_top);

    mbx = new();
    sb  = new(mbx);

    fork
      sb.run(vif);
    join_none

    // Run 40 test vectors
    repeat (40) begin
      tr = new();
      if (!tr.randomize()) begin
        $fatal("[TB] Randomization failed!");
      end
      mbx.put(tr);
      #10;
    end

    #20;
    if (sb.error_count == 0)
      $display("\n*** ALL MATH UNIT TESTS PASSED SUCCESSFULLY! ***\n");
    else
      $display("\n*** TEST FAILED WITH %0d ERRORS ***\n", sb.error_count);
      
    $finish;
  end
endmodule
