module top_tb;

  parameter NUMBER_OF_TEST_RUNS = 1000;
  parameter DATA_BUS_WIDTH      = 16;
  parameter DATA_MOD_WIDTH      = 4;

  bit                          clk;
  logic                        srst;
  bit                          srst_done;

  logic [DATA_BUS_WIDTH - 1:0] data;
  logic [DATA_MOD_WIDTH - 1:0] data_mod;
  logic                        data_val;

  logic                        ser_data;
  logic                        ser_data_val;
  logic                        busy;

  // flag to indicate if there is an error
  bit test_succeed;

  initial forever #5 clk = !clk;

  default clocking cb @( posedge clk );
  endclocking

  initial 
    begin
      srst <= 1'b0;
      ##1;
      srst <= 1'b1;
      ##1;
      srst <= 1'b0;
      srst_done = 1'b1;
    end

  serializer #(
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

  typedef logic output_data_t[$:DATA_BUS_WIDTH - 1];

  mailbox #( logic [DATA_BUS_WIDTH - 1:0] ) input_data     = new(1);
  mailbox #( logic [DATA_BUS_WIDTH - 1:0] ) generated_data = new(1);
  mailbox #( logic [DATA_MOD_WIDTH - 1:0] ) size           = new(1);

  mailbox #( output_data_t ) output_data                   = new(1);

  function void display_error( input logic [DATA_BUS_WIDTH - 1:0] in,  
                               input output_data_t out
                             );
    for ( int i = 1; i < DATA_BUS_WIDTH - out.size() - 1; i++)
      in[i - 1] = 0; // assign 0 to not valid bits
    $display( "expected values:%b, result value:%p", in, out);

  endfunction

  task raise_transaction_strobes( logic [DATA_BUS_WIDTH - 1:0] data_to_send,
                                  logic [DATA_MOD_WIDTH - 1:0] size_to_send
                                ); 
    
    // data comes at random moment
    int delay;
    delay = $urandom_range(10, 0);
    ##(delay);

    data     <= data_to_send;
    data_mod <= size_to_send;
    data_val <= 1;
    ## 1;
    data     <= '0;
    data_mod <= '0;
    data_val <= '0; 

  endtask

  task compare_data( mailbox #( logic [DATA_BUS_WIDTH - 1:0] ) input_data,
                     mailbox #( output_data_t ) output_data
                   );
    
    logic [DATA_BUS_WIDTH - 1:0] i_data;
    output_data_t o_data;
    int index;

    output_data.get( o_data );
    input_data.get( i_data );
    index = 0;
    
    while ( index++ != o_data.size() ) begin
      if ( i_data[DATA_BUS_WIDTH - index - 1] != o_data[index] )
        begin
          display_error( i_data, o_data );
          test_succeed <= 0;
          return;
        end
    end
    
  endtask

  task generate_transaction ( mailbox #( logic [DATA_BUS_WIDTH - 1:0]) generated_data,
                              mailbox #( logic [DATA_MOD_WIDTH - 1:0]) size
                            );
    
    logic [DATA_BUS_WIDTH - 1:0] data_to_send;
    logic [DATA_MOD_WIDTH - 1:0] size_to_send;

    data_to_send = $urandom_range( DATA_BUS_WIDTH**2 - 1, 0 );
    size_to_send = $urandom_range( DATA_MOD_WIDTH**2 - 1, 3 ) * $urandom_range(1, 0);

    generated_data.put(data_to_send);
    size.put(size_to_send);

  endtask

  task send_data ( mailbox #( logic [DATA_BUS_WIDTH - 1:0]) input_data,
                   mailbox #( logic [DATA_BUS_WIDTH - 1:0]) generated_data,
                   mailbox #( logic [DATA_MOD_WIDTH - 1:0]) size
                 );

    logic [DATA_BUS_WIDTH - 1:0] data_to_send;
    logic [DATA_BUS_WIDTH - 1:0] size_to_send;

    generated_data.get( data_to_send );
    input_data.put( data_to_send );
    size.get( size_to_send );

    raise_transaction_strobes( data_to_send, size_to_send );

  endtask

  task read_data ( mailbox #( output_data_t ) output_data );
    
    output_data_t recieved_data;
        
    // reinitialize empty queue
    recieved_data = {};
    
    @( posedge ser_data_val );
    while ( 1 ) begin
      @( posedge clk );
      if ( ser_data_val == 1 )
        recieved_data.push_back(ser_data);
      else 
        break;
    end

    output_data.put(recieved_data);

  endtask

  task one_two_sizes_check;
    logic [DATA_BUS_WIDTH - 1:0] data_to_send;
    logic [DATA_MOD_WIDTH - 1:0] size_to_send;

    data_to_send = '1;  

    size_to_send = 1;
    raise_transaction_strobes( data_to_send, size_to_send );
    ##2
    if ( ser_data_val == 1 )
      begin
        $display("Error occures! Transaction of size one activates DUT!");
        test_succeed <= 0;
      end
      
    size_to_send = 2;
    raise_transaction_strobes( data_to_send, size_to_send );
    ##2
    if ( ser_data_val == 1 )
      begin
        $display("Error occures! Transaction of size two activates DUT!");
        test_succeed <= 0;
      end

  endtask

  initial begin
    test_succeed <= 1;

    $display("Simulation started!");
    wait( srst_done );

    repeat ( NUMBER_OF_TEST_RUNS )
    begin
      fork
        generate_transaction( generated_data, size );
        send_data( input_data, generated_data, size );
        read_data( output_data );
        compare_data( input_data, output_data );
      join
    end

    one_two_sizes_check();

    $display("Simulation is over!");
    if ( test_succeed )
      $display("All tests passed!");
    $stop();
  end



endmodule
