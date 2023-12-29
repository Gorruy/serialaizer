module serializer (
    input  logic        clk_i,
    input  logic        srst_i,
    input  logic [15:0] data_i,
    input  logic [ 3:0] data_mod_i,
    input  logic        data_val_i,
    output logic        ser_data_o,
    output logic        ser_data_val_o,
    output logic        busy_o
);

  enum logic [1:0] {
    IDLE_S,
    WORK_S
  }
      state, next_state;

  logic [ 3:0] counter;
  logic [15:0] data_buf;

  always_ff @(posedge clk_i) begin
    if (!srst_i) state <= IDLE_S;
    else state <= next_state;
  end

  always_comb begin
    next_state = state;
    case (state)
      IDLE_S: begin
        if (data_val_i) next_state = WORK_S;
        else next_state = IDLE_S;
      end

      WORK_S: begin
        if (counter == 15) next_state = IDLE_S;
        else next_state = WORK_S;
      end
    endcase
  end

  always_comb begin
    data_buf       = '0;
    ser_data_o     = '0;
    ser_data_val_o = 0;
    busy_o         = 0;
    counter        = 0;
    case (state)
      IDLE_S: begin
        if (data_val_i) begin
          if (!data_mod_i) counter = 0;
          else counter = data_mod_i;
          data_buf       = data_i;
          ser_data_val_o = 1;
          ser_data_o     = data_buf[4'b15-counter];
          busy_o         = 1;
          counter        = 0;
        end else begin
          data_buf       = '0;
          ser_data_o     = '0;
          ser_data_val_o = 0;
          busy_o         = 0;
          counter        = 0;
        end
      end

      WORK_S: begin
        counter        = counter + 4'b1;
        busy_o         = 1;
        ser_data_val_o = 1;
        ser_data_o     = data_buf[4'b15-counter];
        data_buf       = data_buf;
      end
    endcase
  end

endmodule
