/*********************************************************************************************************/
/* robbit(Two-wheeled Self Balancing Car Project) since 2025-10 Copyright(c) 2025 Archlab. Science Tokyo */
/* Released under the MIT license https://opensource.org/licenses/mit                                    */
/*********************************************************************************************************/

module i2c_master(
    input             clk_i,             //input clock CLK_FREQ_MHZ
    input             rst_i,             //reset (active low)
    input      [6:0]  slave_addr_i,      //7 bit slave address
    input      [7:0]  reg_addr_i,        //8 bit register address
    input      [4:0]  byte_len_i,        //the bit length of read or write
    input      [7:0]  wdata_i,           //write data
    input             cmd_valid_i,       //valid signal for start of transaction 
    input             write_valid_i,     //valid signal for write
    input             read_valid_i,      //valid signal for read
    input             rw_mode_i,         //1: read, 0:write
    output reg        cmd_ready_o,       //ready signal for start of transaction  
    output reg        write_ready_o,     //ready signal for write
    output reg        read_ready_o,      //ready signal for read
    output reg [7:0]  read_data_o,       //read data from slave
    output reg        data_valid_o,      //data valid of read_data
    output reg        nack_o,            //Negative Acknowledgment(failed transaction)
    inout             scl,               //i2c clock line
    inout             sda                //i2c data line
);

    reg [5:0] r_state, r_next_state;
    reg [7:0] r_slave_rw;
    reg [7:0] r_reg_addr;
    reg [7:0] r_wdata;
    reg [4:0] r_bit_counter, r_byte_len;
    reg [15:0] r_clk_scl_cntr;
    reg r_scl_posedge, r_scl_negedge, r_read_flag;
    reg r_scl_sync1, r_scl_sync2, r_sda_sync1, r_sda_sync2, r_sda;
    reg r_clk_scl, r_en_scl;
    reg r_scl_low, r_scl_high;

    localparam [9:0] DIV_SCLCK     = 10'd200,
                     SETUP_TIME    = 70,
                     BUS_FREE_TIME = 150;

    localparam [3:0] ST_IDLE           = 4'd0,
                     ST_START          = 4'd1,
                     ST_SLAVE_WRITE    = 4'd2,
                     ST_REG_WRITE      = 4'd3,
                     ST_WRITE_WAIT     = 4'd4,
                     ST_WRITE          = 4'd5,
                     ST_ACK_WAIT       = 4'd6,
                     ST_REPEATED_START = 4'd7,
                     ST_READ_WAIT      = 4'd8,
                     ST_READ           = 4'd9,
                     ST_ACK_SEND       = 4'd10,
                     ST_STOP           = 4'd11,
                     ST_RELEASE_BUS    = 4'd12;

    assign sda = r_sda;
    assign scl = r_en_scl ? r_clk_scl : 1'bz;    

    always@(posedge clk_i) begin
        if(!rst_i) begin
            r_clk_scl_cntr <= 16'b0; 
            r_clk_scl <= 1'b1;
        end else if(!r_en_scl) begin
            r_clk_scl_cntr <= 16'b0; 
            r_clk_scl <= 1'b1;
        end else begin
            r_clk_scl_cntr <= r_clk_scl_cntr + 1;
            if(r_clk_scl_cntr == DIV_SCLCK-1) begin
                r_clk_scl <= !r_clk_scl;
                r_clk_scl_cntr <= 16'b0;
            end
        end
    end

    always @(posedge clk_i) begin
        if(!rst_i) begin
            r_scl_sync1 <= 1'b0;
            r_scl_sync2 <= 1'b0;
            r_sda_sync1 <= 1'b0; 
            r_sda_sync2 <= 1'b0;
        end else begin
            r_scl_sync1 <= r_clk_scl; 
            r_scl_sync2 <= r_scl_sync1;
            r_sda_sync1 <= sda;
            r_sda_sync2 <= r_sda_sync1;
        end
    end

    always @(posedge clk_i) begin
        if(!rst_i) begin
            r_scl_posedge <= 1'b0;
            r_scl_negedge <= 1'b0;
        end else begin
            if(r_scl_sync2 & !r_scl_sync1) begin
                r_scl_posedge <= 1'b0;
                r_scl_negedge <= 1'b1;
            end else if(!r_scl_sync2 & r_scl_sync1) begin
                r_scl_posedge <= 1'b1;
                r_scl_negedge <= 1'b0;
            end else begin
                r_scl_posedge <= 1'b0;
                r_scl_negedge <= 1'b0;
            end
        end
    end

    //main r_state machine
    always @(posedge clk_i) begin
        if(!rst_i) begin
            r_state <= ST_IDLE;
            r_next_state <= ST_IDLE;
            r_slave_rw <= 0;
            r_reg_addr <= 0;
            r_wdata <= 0;
            r_bit_counter <= 0;
            r_read_flag <= 0;
            r_byte_len <= 0;
            nack_o <= 0;
            read_data_o <= 0;
            data_valid_o <= 0;
            r_scl_low <= 0;
            r_scl_high <= 0;
            cmd_ready_o <= 0;
            write_ready_o <= 0;
            read_ready_o <= 0;
        end else begin
            case (r_state)
                ST_IDLE: begin //setting values
                    data_valid_o <= 1'b0;
                    cmd_ready_o <= 1'b1;
                    if(cmd_ready_o & cmd_valid_i) begin
                        r_slave_rw <= {slave_addr_i, 1'b0}; //Always write firstly
                        r_reg_addr <= reg_addr_i;
                        r_byte_len <= byte_len_i;
                        r_state <= ST_START;
                        nack_o <= 1'b0;
                        r_en_scl <= 1'b1;   
                        r_read_flag <= 1'b0;
                        r_sda <= 1'b1;  
                        cmd_ready_o <= 1'b0;
                        write_ready_o <= 1'b0;
                        read_ready_o <= 1'b0;
                    end
                end 

                ST_START: begin //set ST_START condition
                    if(r_scl_sync1 & r_scl_sync2 & r_clk_scl_cntr == SETUP_TIME) begin //ST_START setup margin
                        r_sda <= 1'b0;
                        r_state <= ST_SLAVE_WRITE;
                        r_bit_counter <= 4'd8;
                    end
                end

                ST_SLAVE_WRITE: begin //write slave address                   
                    if(r_bit_counter == 4'd0 && r_scl_negedge) begin
                        r_scl_low <= 1'b0;
                        r_sda <= 1'b0;
                        r_state <= ST_ACK_WAIT;
                        r_next_state <= (r_read_flag) ? ST_READ_WAIT : ST_REG_WRITE;
                        r_bit_counter <= 4'd8;
                        r_slave_rw <= rw_mode_i ? {slave_addr_i, 1'b1} : r_slave_rw;
                    end else if(r_scl_negedge) begin
                        r_scl_low <= 1'b0;
                        r_sda <= r_slave_rw[r_bit_counter-1];
                        r_bit_counter <= r_bit_counter-1;
                    end
                end

                ST_REG_WRITE: begin //write register address(command)                   
                    if(r_bit_counter == 4'd0 && r_scl_negedge) begin
                            r_scl_low <= 1'b0;
                            r_sda <= 1'b0;
                            r_state <= ST_ACK_WAIT;
                            r_next_state <= rw_mode_i ? ST_REPEATED_START : ST_WRITE_WAIT; //1: reST_START->read, 0: write
                            r_bit_counter <= 4'd8;
                    end else if(r_scl_negedge) begin  
                        r_scl_low <= 1'b0;
                        r_sda <= r_reg_addr[r_bit_counter-1];
                        r_bit_counter <= r_bit_counter-1;
                    end
                end
                
                ST_WRITE_WAIT: begin //wait write valid signal 
                    write_ready_o <= 1'b1;
                    if(write_ready_o & write_valid_i) begin
                        r_state <= ST_WRITE;
                        r_wdata <= wdata_i;
                    end else if(r_scl_negedge) begin //no valid signal
                        r_state <= ST_IDLE;
                    end
                end

                ST_WRITE: begin //write data to slave
                    if(r_bit_counter == 4'd0 && r_scl_negedge) begin
                        r_state <= ST_ACK_WAIT;
                        r_next_state <= ST_STOP;
                        r_bit_counter <= 4'd8;
                        r_sda <= 1'bz;
                        write_ready_o <= 1'b0;
                    end else if(r_scl_negedge) begin
                        r_sda <= r_wdata[r_bit_counter-1];
                        r_bit_counter <= r_bit_counter-1;
                    end
                end

                ST_ACK_WAIT: begin //wait ack from slave
                    r_sda <= 1'bz;
                    if(r_scl_posedge) begin
                        r_scl_high <= 1'b0;
                        if(!r_sda_sync2) begin
                            r_state <= r_next_state;
                        end else begin
                            nack_o <= 1'b1;
                            r_state <= ST_IDLE;
                            r_en_scl <= 1'b0;
                            r_sda <= 1'bz;
                        end
                    end
                end

                ST_REPEATED_START: begin //repeated ST_START
                    if(r_scl_negedge) begin
                        r_sda <= 1'b1;
                    end else if(r_scl_posedge) begin
                        r_sda <= 1'b0;
                        r_state <= ST_SLAVE_WRITE;
                        r_read_flag <= 1;
                    end
                end
                
                ST_READ_WAIT: begin //wait read valid signal
                    read_ready_o <= 1'b1;
                    if(read_ready_o & read_valid_i) begin
                        r_state <= ST_READ;
                    end  else if(r_scl_posedge) begin //no valid signal
                        r_state <= ST_IDLE;
                    end
                end

                ST_READ: begin //read data from slave
                    if(r_bit_counter == 0 && r_scl_negedge) begin
                        r_state <= ST_ACK_SEND;
                        data_valid_o <= 1'b1;
                        r_bit_counter <= 4'd8;
                    end else if(r_scl_posedge) begin  
                        r_scl_high <= 1'b0;
                        data_valid_o <= 1'b0;
                        read_data_o[r_bit_counter-1] <= r_sda_sync2;
                        r_bit_counter <= r_bit_counter - 1;
                    end
                end

                ST_ACK_SEND: begin //send ack to slave
                    //already scl is low.
                    r_sda <= (r_byte_len == 1) ? 1'b1 : 1'b0; //ack or nack
                    if(r_scl_negedge) begin
                        r_sda <= (r_byte_len == 1) ? 1'b0 : 1'bz;
                        data_valid_o <= 1'b0;
                        r_byte_len <= r_byte_len - 1;
                        r_state <= (r_byte_len == 1) ? ST_STOP : ST_READ_WAIT; 
                    end
                end

                ST_STOP: begin //stop condition
                    //initially, scl is high.
                    if(r_scl_negedge) begin 
                        r_sda <= 1'b0;
                    end 

                    if(r_scl_posedge) begin
                        r_sda <= 1'b1;
                        r_state <= ST_RELEASE_BUS;
                    end
                end

                ST_RELEASE_BUS: begin //release bus
                    if(r_clk_scl_cntr == BUS_FREE_TIME) begin //stop margin
                        r_en_scl <= 1'b0;
                        r_state <= ST_IDLE;
                        r_sda <= 1'bz;
                    end
                end

                default: r_state <= ST_IDLE;
            endcase 
        end       
    end

endmodule