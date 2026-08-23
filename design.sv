module alu_rtl (
  input  logic [3:0]  alu_op,
  input  logic [31:0] operand_a,
  input  logic [31:0] operand_b,
  output logic [31:0] alu_out,
  output logic        zero_flag,
  output logic        overflow_flag,
  output logic        div_by_zero_flag
);

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

  always_comb begin
    overflow_flag    = 1'b0;
    div_by_zero_flag = 1'b0;
    
    case (alu_op)
      ADD: begin
        alu_out = operand_a + operand_b;
        if ((operand_a[31] == operand_b[31]) && (alu_out[31] != operand_a[31]))
          overflow_flag = 1'b1;
      end
      SUB: begin
        alu_out = operand_a - operand_b;
        if ((operand_a[31] != operand_b[31]) && (alu_out[31] != operand_a[31]))
          overflow_flag = 1'b1;
      end
      AND:  alu_out = operand_a & operand_b;
      OR:   alu_out = operand_a | operand_b;
      XOR:  alu_out = operand_a ^ operand_b;
      XNOR: alu_out = ~(operand_a ^ operand_b);
      NOT:  alu_out = ~operand_a;
      SLL:  alu_out = operand_a << operand_b[4:0];
      SRL:  alu_out = operand_a >> operand_b[4:0];
      SRA:  alu_out = $signed(operand_a) >>> operand_b[4:0];
      MUL: begin
        // Lower 32-bits of multiplication result
        logic [63:0] mul_res;
        mul_res = {32'h0, operand_a} * {32'h0, operand_b};
        alu_out = mul_res[31:0];
      end
      DIV: begin
        if (operand_b == 32'h0) begin
          div_by_zero_flag = 1'b1;
          alu_out = 32'hFFFF_FFFF; // Standard error value for division by zero
        end else begin
          alu_out = operand_a / operand_b;
        end
      end
      REM: begin
        if (operand_b == 32'h0) begin
          div_by_zero_flag = 1'b1;
          alu_out = 32'h0;
        end else begin
          alu_out = operand_a % operand_b;
        end
      end
      default: alu_out = 32'h0;
    endcase
    
    zero_flag = (alu_out == 32'h0);
  end

endmodule
