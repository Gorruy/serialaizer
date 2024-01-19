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

  typedef logic data_t[$:DATA_BUS_WIDTH - 1];

  mailbox #( data_t ) input_data     = new(1);
  mailbox #( data_t ) generated_data = new(1);
  mailbox #( data_t ) output_data    = new(1);

  function void display_error( input data_t in,  
                               input data_t out
                             );
    $error( "expected values:%p, expected size:%d, result value:%p, result size:%d", in, in.size(), out, out.size() );

  endfunction

  task raise_transaction_strobes( input data_t data_to_send ); 
    
    // data comes at random moment
    int delay;
    delay = $urandom_range(10, 0);
    ##(delay);

    data_mod = data_to_send.size() != 16? data_to_send.size(): 0;
    data     = { << {data_to_send} };
    data_val = 1'b1;
    ## 1;
    data     = '0;
    data_mod = '0;
    data_val = 1'b0; 

  endtask

  task compare_data( mailbox #( data_t ) input_data,
                     mailbox #( data_t ) output_data
                   );
    
    data_t i_data;
    data_t o_data;
    int index;

    output_data.get( o_data );
    input_data.get( i_data );
    index = 0;

    if ( o_data.size() != i_data.size() )
      begin
        display_error( i_data, o_data );
        return;
      end
    
    while ( index++ != o_data.size() ) begin
      if ( i_data[index] !== o_data[index] )
        begin
          display_error( i_data, o_data );
          test_succeed = 1'b0;
          return;
        end
    end
    
  endtask

  task generate_transaction ( mailbox #( data_t ) generated_data );
    
    data_t data_to_send;
    int size;

    data_to_send = {};

    size = $urandom_range( DATA_MOD_WIDTH**2, 3 );
    for ( int i = 0; i < size; i++ ) begin
      data_to_send.push_back( $urandom_range( 1, 0 ) );
    end

    generated_data.put(data_to_send);

  endtask

  task send_data ( mailbox #( data_t ) input_data,
                   mailbox #( data_t ) generated_data
                 );

    data_t data_to_send;

    generated_data.get( data_to_send );

    raise_transaction_strobes( data_to_send );

    input_data.put( data_to_send );

  endtask

  task read_data ( mailbox #( data_t ) output_data );
    
    data_t recieved_data;
        
    // reinitialize empty queue
    recieved_data = {};
    @( posedge ser_data_val );
    while ( 1 ) 
      begin
        @( posedge clk );
        if ( ser_data_val === 1'b1 )
          recieved_data.push_front(ser_data);
        else 
          break;
      end

    output_data.put(recieved_data);

  endtask

  task one_two_sizes_check;
    data_t data_to_send;
    data_t size_to_send;

    data_to_send.push_back(1);  

    raise_transaction_strobes( data_to_send );
    ##2
    if ( ser_data_val === 1'b1 )
      begin
        $error("Error occures! Transaction of size one activates DUT!");
        test_succeed <= 1'b0;
      end
      
    data_to_send.push_back(1);
    raise_transaction_strobes( data_to_send );
    ##2
    if ( ser_data_val === 1'b1 )
      begin
        $error("Error occures! Transaction of size two activates DUT!");
        test_succeed <= 1'b0;
      end

  endtask

  initial begin
    test_succeed <= 1'b1;

    $display("Simulation started!");
    wait( srst_done );

    repeat ( NUMBER_OF_TEST_RUNS )
    begin
      fork
        generate_transaction( generated_data );
        send_data( input_data, generated_data );
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
