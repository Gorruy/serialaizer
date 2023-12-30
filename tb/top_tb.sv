class RandomTransactionData;
  rand logic [15:0] input_data;
  rand logic [3:0] size;

  constraint c { size != 1; size != 2;}
endclass

task automatic run_one_transaction(input logic [15:0] data,
                               input logic [3:0] data_mod,
                               input logic data_val); 
  logic [15:0] output_data;
  RandomTransactionData tr = new();

  data <= tr.input_data;
  data_val <= 1;
  data_mod <= tr.size;

  for (int i = 0; i < tr.size; i++)
  begin
    @(posedge clk);
    if (ser_data != tr.input_data[15 - i]) display_error(tr.input_data, ser_data, i);
  end
endtask 

task automatic display_error(input logic [15:0] in, 
                             input logic value, 
                             input int index);
  $display("expected value:%i, result value:%i", in[index], value);
endtask

module top_tb;

  parameter RUNS = 1000;

  logic clk;
  logic srts;

  logic ser_data;
  logic ser_data_val;
  logic busy;

  logic [15:0] data;
  logic [3:0] data_mod;
  logic data_val;

  // flag to indicate if there is an error
  bit test_succeed;

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

  initial begin
    srst <= 1;
    #10;
    srst <= 0;
    test_succeed <= 1;
    $display("Tests started!");

    for (int i = 0; i < RUNS; i++)
    begin
      run_one_transaction(data, data_mod, data_val);
    end
  end



endmodule
