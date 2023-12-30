  class RandomTransactionData;
  rand logic [15:0] input_data;
  rand logic [3:0] size;

  constraint c { size != 1; size != 2;}
  endclass

  task display_error(input logic [15:0] in, 
                     input logic [15:0] out,
                     input int index);
    for (int i = 0; i <= index; i++ ) begin
      $display("expected values:%b, result value:%b till %d", in, out, index);
    end
  endtask

module top_tb;

  parameter RUNS = 100;

  bit clk;
  logic srst;

  logic ser_data;
  logic ser_data_val;
  logic busy;

  logic [15:0] data;
  logic [3:0] data_mod;
  logic data_val;

  logic [15:0] output_test_data = '0;

  // flag to indicate if there is an error
  bit test_succeed;

  serializer DUT (
      .clk_i         (clk),
      .srst_i        (srst),
      .ser_data_o    (ser_data),
      .ser_data_val_o (ser_data_val),
      .busy_o        (busy),
      .data_i        (data),
      .data_val_i    (data_val),
      .data_mod_i    (data_mod)
  );

  initial
    forever 
      #5 clk = !clk;

    default clocking cb @ (posedge clk);
    endclocking

  initial begin
    RandomTransactionData tr;
    srst <= 1;
    #10;
    srst <= 0;
    test_succeed <= 1;
    $display("Tests started!");

    for (int i = 0; i < RUNS; i++)
    begin
      tr = new();
      tr.randomize();

      data <= tr.input_data;
      data_val <= 1;
      data_mod <= tr.size;
      // Wait for DUT to read data at posedge
      @(posedge clk);

      for (int i = 0; i < (tr.size != 4'b0 ? tr.size: 15); i++)
      begin
        // wait for next posedge to read data
        @(posedge clk);
        if (ser_data_val)
          output_test_data[15 - i] <= ser_data;
          if (ser_data != tr.input_data[15 - i])
          begin
            test_succeed <= 0;
            display_error(tr.input_data, output_test_data, i);
          end
      end
      end
      if (test_succeed) $display("Tests completed successfully!");
      else $display("Tests failed!");
      $stop();
  end



endmodule
