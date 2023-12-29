module top_tb;

  logic clk;
  logic srts;

  logic ser_data;
  logic ser_data_val;
  logic busy;

  logic [15:0] data;
  logic [3:0] data_mod;
  logic data_val;

  serializer DUT (
    .clk         (clk_i),
    .srst        (srst_i),
    .ser_data    (ser_data_o),
    .ser_data_val(ser_data_val_o),
    .busy        (busy_o),
    .data        (data_i),
    .data_val    (data_val_i),
    .data_mod    (data_mod_i)
  );

  initial 
    forever begin
      #5 clk = !clk;
    end

    initial
    begin
      #15 data <= 16'd10;
      data_mod <= 4'b0;
      data_val <= 1;
    end

endmodule
