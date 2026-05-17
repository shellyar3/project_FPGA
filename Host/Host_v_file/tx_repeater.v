module tx_repeater(
input clk,
input rst,
input Rx_valid,         // the recieved byte is valid
input [7:0] Rx_data,    // the recievr's data
output reg iTx_DV,      // data to transmitter is valid
output reg [7:0] tx_data, // data to the transmitter
input o_Tx_Done         // transmitted finished 
// can be used to trigger another trasmition
);

// this block will transmit to the host the same byte that was recieved
// Like a loop back, following the Python sw on the host
// in order to check massively the reliability
// the trigger is Rx_Valid signal, when the receivong data is ready

  parameter STATE0 = 3'b000;
  parameter STATE1 = 3'b001;
  parameter STATE2 = 3'b010;
  parameter STATE3 = 3'b011;
  parameter STATE4 = 3'b100;
  parameter STATE5 = 3'b101;
  parameter STATE6 = 3'b110;
  parameter STATE7 = 3'b111;

  reg [2:0] current_state, next_state;
  reg [7:0] rx_inc_data;

  always @(posedge clk or posedge rst) begin //1
    if (rst) begin //2
      current_state <= STATE0; 
    end else begin //2
      current_state <= next_state;
    end //2
  end

  /*
   always @(posedge clk) begin 
    if (current_state==IDLE) begin
    end else if (current_state==STATE1) begin
    end else if (current_state==2) begin
    end
  end //1
  */

  always @(*) begin
    case (current_state)
      STATE0: begin
        // after reset
        iTx_DV =0;
        if (Rx_valid) begin
            // byte was recieved
            rx_inc_data=Rx_data+1;
            next_state = STATE1;  
        end else begin
            next_state = STATE0; 
        end
      end

      STATE1: begin
        // Reciever data is ready, starting the tx side
        next_state = STATE2; 
		    iTx_DV =1;
		    tx_data=rx_inc_data;
      end

      STATE2: begin
        // create Tx data
        next_state = STATE3; 
		    iTx_DV =0;
      end

      STATE3: begin
        // wait until Tx is done, when done, go to state0
        iTx_DV =0;
        if ( o_Tx_Done) begin
          next_state = STATE0;
        end else begin
          next_state = STATE3;  // stay here until TX byte is transmitted. TBD.
        end 
      end

      STATE4: begin
        // Should not be here
        next_state = STATE4;
      end

      default: begin
        next_state = STATE0; 
      end
    endcase
  end

endmodule