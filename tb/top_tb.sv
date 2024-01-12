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
  
  typedef struct {
    logic [DATA_BUS_WIDTH - 1:0] data;
    logic [DATA_MOD_WIDTH - 1:0] size;
  } transaction_t;

  mailbox #( transaction_t ) input_transaction     = new(1);
  mailbox #( transaction_t ) output_transaction    = new(1);
  mailbox #( transaction_t ) generated_transaction = new(1);

  function void display_error( input transaction_t in,  
                               input transaction_t out
                             );
    out.size = out.size != 0 ? out.size: 16;
    for ( int i = 0; i < DATA_BUS_WIDTH - out.size; i++)
      in.data[i] = 0; // assign 0 to not valid bits
    $display( "expected values:%b, result value:%b", in.data, out.data);

  endfunction

  task raise_transaction_strobes( input transaction_t transaction); 
    
    // data comes at random moment
    int delay;
    delay = $urandom_range(10, 0);
    ##(delay);

    data     <= transaction.data;
    data_mod <= transaction.size;
    data_val <= 1'b1;
    ## 1;
    data     <= '0;
    data_mod <= '0;
    data_val <= '0; 

  endtask

  task compare_data( mailbox #( transaction_t ) input_transaction,
                     mailbox #( transaction_t ) output_transaction
                   );
    
    transaction_t i_tr, o_tr;

    output_transaction.get( o_tr );
    input_transaction.get( i_tr );

    if ( o_tr.size != i_tr.size )
      begin
        display_error( i_tr, o_tr );
        return; 
      end
    
    for ( int i = DATA_BUS_WIDTH; i > ( o_tr.size == 0 ? 0: DATA_BUS_WIDTH - o_tr.size ); i-- ) begin
      if ( i_tr.data[i - 1] != o_tr.data[i - 1] )
        begin
          display_error( i_tr, o_tr );
          test_succeed <= 1'b0;
          return;
        end
    end
    
  endtask

  task generate_transaction ( mailbox #( transaction_t ) generated_transaction );
    
    logic [DATA_BUS_WIDTH - 1:0] data_to_send;
    logic [DATA_MOD_WIDTH - 1:0] size_to_send;
    transaction_t transaction_to_send;

    data_to_send = $urandom_range( DATA_BUS_WIDTH**2 - 1, 0 );
    size_to_send = $urandom_range( DATA_MOD_WIDTH**2 - 1, 3 ) * $urandom_range(1, 0);
    transaction_to_send = {
      data: data_to_send,
      size: size_to_send
    };

    generated_transaction.put(transaction_to_send);

  endtask

  task send_data ( mailbox #( transaction_t ) input_transaction,
                   mailbox #( transaction_t ) generated_transaction
                 );

    transaction_t transaction_to_send;

    generated_transaction.get( transaction_to_send );
    input_transaction.put( transaction_to_send );

    raise_transaction_strobes( transaction_to_send );

  endtask

  task read_data ( mailbox #( transaction_t ) output_transaction );
    
    transaction_t recieved_transaction;
    int counter;
    
    recieved_transaction.data <= '0;
    counter = 0;   
    
    @( posedge ser_data_val );
    while ( 1 ) begin
      @( posedge clk );
      if ( ser_data_val == '1 )
        recieved_transaction.data[DATA_BUS_WIDTH - 1 - counter++] = ser_data;
      else 
        begin
          recieved_transaction.size = counter;
          break;
        end
    end

    output_transaction.put(recieved_transaction);

  endtask

  task one_two_sizes_check;
    transaction_t tr_to_send;

    tr_to_send.data = '1;  
    
    tr_to_send.size = 1;
    raise_transaction_strobes( tr_to_send );
    ##2
    if ( ser_data_val == 1 )
      begin
        $display("Error occures! Transaction of size one activates DUT!");
        test_succeed <= 0;
      end
      
    tr_to_send.size = 2;
    raise_transaction_strobes( tr_to_send );
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
        generate_transaction( generated_transaction );
        send_data( input_transaction, generated_transaction);
        read_data( output_transaction );
        compare_data( input_transaction, output_transaction);
      join
    end

    one_two_sizes_check();

    $display("Simulation is over!");
    if ( test_succeed )
      $display("All tests passed!");
    $stop();
  end



endmodule
