module top_tb;

  parameter NUMBER_OF_TEST_RUNS = 100;
  parameter DATA_BUS_WIDTH      = 16;
  parameter DATA_MOD_WIDTH      = 4;

  bit clk;
  logic srst;

  logic ser_data;
  logic ser_data_val;
  logic busy;

  logic [DATA_BUS_WIDTH - 1:0] data;
  logic [DATA_MOD_WIDTH - 1:0] data_mod;
  logic data_val;

  logic [DATA_BUS_WIDTH - 1:0] output_test_data = '0;

  // flag to indicate if there is an error
  bit test_succeed;

  serializer_impl #(
    .DATA_BUS_WIDTH ( DATA_BUS_WIDTH ),
    .DATA_MOD_WIDTH ( DATA_MOD_WIDTH )
  ) DUT ( 
    .clk_i          ( clk            ),
    .srst_i         ( srst           ),
    .ser_data_o     ( ser_data       ),
    .ser_data_val_o ( ser_data_val   ),
    .busy_o         ( busy           ),
    .data_i         ( data           ),
    .data_val_i     ( data_val       ),
    .data_mod_i     ( data_mod       )
  );

  class RandomTransactionData;
    rand logic [DATA_BUS_WIDTH - 1:0] input_data;
    rand logic [DATA_MOD_WIDTH - 1:0] size;

    constraint c {
      size != 1;
      size != 2;
    }
  endclass

  task display_error(
    input logic [DATA_BUS_WIDTH - 1:0] in, 
    input logic [DATA_BUS_WIDTH - 1:0] out, 
    input int                          index
  );
    for ( int i = 0; i <= index; i++ )
      $display( "expected values:%b, result value:%b till %d", in, out, index );
  endtask

  initial forever #5 clk = !clk;

  default clocking cb @( posedge clk );
  endclocking

  initial begin
    RandomTransactionData tr;
    srst <= 1;
    #10;
    srst         <= 0;
    test_succeed <= 1;
    $display( "Tests started!" );

    for ( int i = 0; i < NUMBER_OF_TEST_RUNS; i++ ) begin
      tr = new();
      tr.randomize();

      data     <= tr.input_data;
      data_val <= 1;
      data_mod <= tr.size;
      // Wait for DUT to read data at posedge
      @( posedge clk );
      data_val <= 0;

      for ( int i = 0; i < ( tr.size != 0 ? tr.size : DATA_BUS_WIDTH ); i++ ) begin
        // wait for next posedge to read data
        @( posedge clk) ;
        if ( ser_data_val ) 
          output_test_data[DATA_BUS_WIDTH - 1 - i] <= ser_data;
        if ( ser_data != tr.input_data[DATA_BUS_WIDTH - 1 - i] ) begin
          test_succeed <= 0;
          display_error(tr.input_data, output_test_data, i);
        end
      end
      output_test_data <= '0;
    end
    if ( test_succeed ) 
      $display( "Tests completed successfully!" );
    else 
      $display( "Tests failed!" );
    $stop();
  end

endmodule
