module top_tb;

  parameter NUMBER_OF_TEST_RUNS = 100;
  parameter DATA_BUS_WIDTH      = 16;
  parameter DATA_MOD_WIDTH      = 4;

  bit                          clk;
  logic                        srst;

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

  mailbox #( logic [DATA_BUS_WIDTH - 1:0] ) input_data = new();
  mailbox #( logic [DATA_BUS_WIDTH - 1:0] ) output_data = new();
  mailbox #( logic [DATA_BUS_WIDTH - 1:0] ) generated_data = new();
  mailbox #( logic [DATA_MOD_WIDTH - 1:0] ) size = new();

  function void display_error( input logic [DATA_BUS_WIDTH - 1:0] in,  
                               input logic [DATA_BUS_WIDTH - 1:0] out,  
                               input int                          index
                             );

    for ( int i = 0; i <= index; i++ )
      $display( "expected values:%b, result value:%b till %d", in, out, index );

  endfunction

  task compare_data( mailbox #( logic [DATA_BUS_WIDTH - 1:0]) input_data,
                     mailbox #( logic [DATA_MOD_WIDTH - 1:0]) size,
                     mailbox #( logic [DATA_BUS_WIDTH - 1:0]) output_data
                   );
    
    logic [DATA_MOD_WIDTH - 1:0] tr_size;
    logic [DATA_BUS_WIDTH - 1:0] i_data, o_data;

    output_data.get( o_data );
    input_data.get( i_data );
    size.get( tr_size );
    
    for ( int i = 0; i < tr_size; i++ ) begin
      if ( input_data[i] != output_data[i] )
        display_error( i_data, o_data, i );
    end
    
  endtask

  task generate_transaction ( mailbox #( logic [DATA_BUS_WIDTH - 1:0]) generated_data,
                              mailbox #( logic [DATA_MOD_WIDTH - 1:0]) size
                            );
    
    logic [DATA_BUS_WIDTH - 1:0] data_to_send;
    logic [DATA_MOD_WIDTH - 1:0] size_to_send;

    data_to_send = $urandom_range( DATA_BUS_WIDTH**2 - 1, 0 );
    size_to_send = $urandom_range( DATA_MOD_WIDTH**2 - 1, 0 );

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

    data     <= data_to_send;
    data_mod <= size_to_send;
    data_val <= 1'b1;
    #10
    data     <= '0;
    data_mod <= '0;
    data_val <= 1'b0;    

  endtask

  task read_data ( mailbox #( logic [DATA_BUS_WIDTH - 1:0]) output_data,
                   mailbox #( logic [DATA_MOD_WIDTH - 1:0]) size 
                 );
    
    logic [DATA_BUS_WIDTH - 1:0] recieved_data;
    logic [DATA_MOD_WIDTH - 1:0] tr_size;
    
    recieved_data <= '0;
    size.get(tr_size);

    for ( int i = 0; i < tr_size; i++ ) begin
      @( posedge clk );
      if ( ser_data_val == 1'b1 )
        recieved_data[i] <= ser_data;
    end

    output_data.put(recieved_data);

  endtask

  initial begin
    
  end

endmodule
