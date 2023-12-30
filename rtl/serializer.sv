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
  logic [ 3:0] final_index;
  logic [15:0] data_buf;

  always_ff @(posedge clk_i) begin
    if (srst_i) state <= IDLE_S;
    else state <= next_state;
  end

  always_comb begin
    next_state = state;
    case (state)
      IDLE_S: begin
        if (data_mod_i == 1 || data_mod_i == 2) next_state = IDLE_S;
        else if (data_val_i) next_state = WORK_S;
        else next_state = IDLE_S;
      end

      WORK_S: begin
        if (counter == final_index + 4'b1) next_state = IDLE_S;
        else next_state = WORK_S;
      end
    endcase
  end

  // Set counter and data buffer
  always_ff @(posedge clk_i) begin
    if (state == IDLE_S) counter <= 4'd15;
    if (state == IDLE_S && next_state == WORK_S) begin
      data_buf <= data_i;
      if (!data_mod_i) final_index <= 0;
      else final_index <= 4'd15 - data_mod_i;
    end else if (next_state == WORK_S || state == WORK_S) counter <= counter - 4'b1;
  end

  always_comb begin
    ser_data_o     = '0;
    ser_data_val_o = 0;
    busy_o         = 0;
    case (state)
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
    endcase
  end

endmodule
