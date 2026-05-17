module uart_ctrl(
  input wire clk,
  input wire rst,
  output reg iTx,
  output reg [7:0] tx_data
  );

  parameter IDLE   = 3'b000;
  parameter STATE1 = 3'b001;
  parameter STATE2 = 3'b010;
  parameter STATE3 = 3'b011;
  parameter STATE4 = 3'b100;
  parameter STATE5 = 3'b101;
  parameter STATE6 = 3'b110;
  parameter STATE7 = 3'b111;

  reg [1:0] current_state, next_state;

  always @(posedge clk or posedge rst) begin //1
    if (rst) begin //2
      current_state <= IDLE; 
      //iTx=0;
      //tx_data=0;
    end else begin //2
      current_state <= next_state;
    end //2
  end

   always @(*) begin 
    if (current_state==IDLE) begin
        iTx=0;
        tx_data=0;
    end else if (current_state==STATE1) begin
        iTx =1;
        tx_data=8'b10101010;
    end else if (current_state==2) begin
        iTx=0;
    end
  end //1

  always @(*) begin
    case (current_state)
      IDLE: begin
        next_state = STATE1; 
      end
      STATE1: begin
        next_state = STATE2; 
      end
      STATE2: begin
        next_state = STATE2;  // stay here until TX byte is transmitted. TBD.
      end
      STATE3: begin
        next_state = IDLE; 
      end
      default: begin
        next_state = IDLE; 
      end
    endcase
  end

  
  //assign state_out = current_state; //(current_state == STATE1); // Example: Output is high in STATE1


endmodule // uart_ctrl
