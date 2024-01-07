module serializer_top (
    input  logic        clk_i,
    input  logic        srst_i,

    input  logic [15:0] data_i,
    input  logic [3:0]  data_mod_i,
    input  logic        data_val_i,

    output logic        ser_data_o,
    output logic        ser_data_val_o,
    output logic        busy_o
);

  logic        srst;

  logic [15:0] data;
  logic [3:0]  data_mod;
  logic        data_val;

  logic        ser_data;
  logic        ser_data_val;
  logic        busy;

  always_ff @( posedge clk_i )
    begin
      srst     <= srst_i;
      data     <= data_i;
      data_mod <= data_mod_i;
      data_val <= data_val_i; 
    end 

  serializer #(
    .DATA_BUS_WIDTH ( 16           ),
    .DATA_MOD_WIDTH ( 4            )
  ) serializer_ins (
    .clk_i          ( clk_i        ),
    .srst_i         ( srst         ),

    .data_mod_i     ( data_mod     ),
    .data_i         ( data         ),
    .data_val_i     ( data_val     ),

    .ser_data_o     ( ser_data     ),
    .ser_data_val_o ( ser_data_val ),
    .busy_o         ( busy         )    
  );

  always_ff @( posedge clk_i )
    begin
      ser_data_o     <= ser_data;
      ser_data_val_o <= ser_data_val;
      busy_o         <= busy; 
    end


endmodule
