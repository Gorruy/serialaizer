module serializer #(
  // This module will accept parallel data
  // and start putting serialized data at the 
  // next posedge, starting with MSB
  parameter DATA_BUS_WIDTH = 16,
  parameter DATA_MOD_WIDTH = 4
)(
  input  logic                        clk_i,
  input  logic                        srst_i,

  input  logic [DATA_BUS_WIDTH - 1:0] data_i,
  input  logic [DATA_MOD_WIDTH - 1:0] data_mod_i,
  input  logic                        data_val_i,

  output logic                        ser_data_o,
  output logic                        ser_data_val_o,
  output logic                        busy_o
);

  enum logic { IDLE_S,
               WORK_S } state, next_state;

  logic [ 3:0] counter;
  logic [ 3:0] final_index; // will hold index till wich serial data sended
  logic [15:0] data_buf;

  always_ff @( posedge clk_i ) 
    begin
      if ( srst_i ) 
        state <= IDLE_S;
      else 
        state <= next_state;
    end

  always_comb 
    begin
      next_state = state;
      case ( state )
        IDLE_S: begin
          // ignoring transaction's sizes of 1 and 2 bits
          if (data_mod_i == 1 || data_mod_i == 2) 
            next_state = IDLE_S;
          else if (data_val_i) 
            next_state = WORK_S;
          else 
            next_state = IDLE_S;
        end

        WORK_S: begin
          if ( counter == final_index ) 
            next_state = IDLE_S;
          else 
            next_state = WORK_S;
        end

        default: begin
          next_state = IDLE_S;
        end
      endcase
    end

  // Set counter and data buffer
  // always_ff @( posedge clk_i ) 
  //   begin
  //     if ( state == IDLE_S ) 
  //       // Reset counter before transaction
  //       counter <= DATA_MOD_WIDTH'( DATA_BUS_WIDTH - 1 );
  //     // transaction started, valid data on bus
  //     if ( state == IDLE_S && next_state == WORK_S ) begin
  //       data_buf <= data_i;
  //       if ( !data_mod_i ) 
  //         final_index <= 0;
  //       else 
  //         final_index <= DATA_MOD_WIDTH'(DATA_BUS_WIDTH - data_mod_i);
  //     end 
  //     else if ( next_state == WORK_S || state == WORK_S ) 
  //       counter <= counter - 4'b1;
  //   end

  always_ff @( posedge clk_i ) 
    begin
      if ( state == IDLE_S )
        counter <= DATA_BUS_WIDTH'( DATA_MOD_WIDTH - 1 );
      else if ( state == WORK_S || data_val_i == 1)
        counter <= counter - 4'b1;  
    end

  always_ff @( posedge clk_i ) 
    begin
      if ( state == WORK_S ) begin
        data_buf <= data_i;
      end 
    end

  always_ff @( posedge clk_i )
    begin
      if ( state == IDLE_S && data_val_i == 1 ) begin
        if ( !data_mod_i ) 
          final_index <= 0;
        else 
          final_index <= DATA_MOD_WIDTH'( DATA_BUS_WIDTH - data_mod_i );
      end
    end

  always_comb 
    begin
      ser_data_o     = '0;
      ser_data_val_o = 0;
      busy_o         = 0;
      case ( state )
        IDLE_S: begin
          ser_data_o     = '0;
          ser_data_val_o = 0;
          busy_o         = 0;
        end

        WORK_S: begin
          busy_o         = 1;
          ser_data_val_o = 1;
          // Msb go first
          ser_data_o     = data_buf[counter];
        end

        default: begin
          ser_data_o     = DATA_BUS_WIDTH'hx;
          ser_data_val_o = 1'hx;
          busy_o         = 1'hx;
        end
      endcase
    end

endmodule
