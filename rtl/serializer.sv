module serializer #(
  // This module will accept parallel data
  // and start putting serialized data at the 
  // next posedge, starting with MSB
  parameter DATA_BUS_WIDTH,
  parameter DATA_MOD_WIDTH
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

  logic [DATA_MOD_WIDTH - 1:0] counter;
  logic [DATA_MOD_WIDTH - 1:0] final_index; // will hold index till wich serial data sended
  logic [DATA_BUS_WIDTH - 1:0] data_buf;

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
          if ( data_mod_i == 1 || data_mod_i == 2 ) 
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
          next_state = 'x;
        end
      endcase
    end

  always_ff @( posedge clk_i ) 
    begin
      if ( state == IDLE_S )
        counter <= ( DATA_MOD_WIDTH )'( DATA_BUS_WIDTH - 1 );
      else
        counter <= counter - ( DATA_MOD_WIDTH )'b1;  
    end

  always_ff @( posedge clk_i )
    begin
      if ( state == IDLE_S && data_val_i == 1'b1 ) begin
        data_buf <= data_i;
        if ( !data_mod_i ) 
          final_index <= 0; // all data to be transferred
        else 
          final_index <= ( DATA_MOD_WIDTH )'( DATA_BUS_WIDTH - data_mod_i );
      end else if ( state == IDLE_S ) begin
        data_buf    <= '0;
        final_index <= 0;
      end

    end

  always_comb 
    begin
      ser_data_o     = 0;
      ser_data_val_o = 0;
      busy_o         = 0;
      case ( state )
        IDLE_S: begin
          ser_data_o     = 0;
          ser_data_val_o = 0;
          busy_o         = 0;
        end

        WORK_S: begin
          busy_o         = 1'b1;
          ser_data_val_o = 1'b1;
          // Msb go first
          ser_data_o     = data_buf[counter];
        end

        default: begin
          ser_data_o     = 'x;
          ser_data_val_o = 'x;
          busy_o         = 'x;
        end
      endcase
    end

endmodule
