/*********************************************************************************************************/
/* robbit(Two-wheeled Self Balancing Car Project) since 2025-10 Copyright(c) 2025 Archlab. Science Tokyo */
/* Released under the MIT license https://opensource.org/licenses/mit                                    */
/*********************************************************************************************************/

`include "config.vh"

module mpu6050(
    input clk_i,           
    input rst_i,           
    output [31:0] data1_o, 
    output [31:0] data2_o, 
    output [31:0] data3_o, 
    inout scl,             
    inout sda              
    );

    reg [7:0] r_whoami;
    reg [8*14-1:0] r_senser_14_data; // {ax, ay, az, temp, gx, gy, gz}
    
    assign data1_o = {r_senser_14_data[95:80], r_senser_14_data[111:96]}; // ay, ax
    assign data2_o = {r_senser_14_data[47:32], r_senser_14_data[ 79:64]}; // gx, az
    assign data3_o = {r_senser_14_data[15: 0], r_senser_14_data[ 31:16]}; // gz, gy

    localparam [6:0] MPU6050_I2C_ADDR = 7'h68;

    //state machine
    localparam [3:0] ST_WRITE_INIT_SETUP      = 4'd0,
                     ST_WRITE_INIT_REQ        = 4'd1,
                     ST_WRITE_INIT_DONE       = 4'd2,
                     ST_READ_WHO_SETUP        = 4'd3,
                     ST_READ_WHO_REQ          = 4'd4,
                     ST_READ_WHO_AWAIT        = 4'd5,
                     ST_READ_WHO_LOAD         = 4'd6,
                     SEN_14_DATA_REQ          = 4'd7,
                     ST_READ_1BYTE_REQ        = 4'd8,
                     ST_READ_1BYTE_AWAIT      = 4'd9,
                     ST_READ_1BYTE_LOAD       = 4'd10,
                     ST_ERROR                 = 4'd11;

    //Internal registers
    reg [3:0]  r_state;
    reg [7:0]  r_readbyte;
    reg [26:0] r_delay_cnt;
    reg [23:0] r_readbyte_cnt;
    reg        r_senser_14_read;

    //For I2C Master
    reg  [6:0]  r_i2c_slave_addr;
    reg  [7:0]  r_i2c_sub_addr;
    reg  [4:0]  r_i2c_byte_len;
    reg         r_i2c_rw;
    reg  [7:0]  r_i2c_wdata;
    reg         r_cmd_valid, r_write_valid, r_read_valid;
    wire        w_cmd_ready, w_write_ready, w_read_ready;
    wire [7:0]  w_i2c_data_out;
    wire        w_valid_out;
    wire        w_nack;

    always@(posedge clk_i) begin
        //Set all regs to a known r_state
        if(rst_i) begin
            //For I2C Driver Regs
            r_i2c_slave_addr <= MPU6050_I2C_ADDR;     
            r_i2c_sub_addr <= 'h0;
            r_i2c_byte_len <= 'h0;
            r_i2c_wdata <= 'h0;
            r_cmd_valid <= 'h0;
            r_i2c_rw <= 'h0;
            r_state <= ST_WRITE_INIT_SETUP;
            r_readbyte_cnt <= 'h0;
            r_readbyte <= 'h0; 
            r_senser_14_read <= 'h0;
            r_delay_cnt <= 'h0;
            r_whoami <= 'h0;
            r_senser_14_data <= 'h0;
        end
        else begin
            case(r_state)
                //release sleep mode 
                ST_WRITE_INIT_SETUP: begin
                    if(w_cmd_ready) begin
                        r_cmd_valid <= 1'b1;
                        r_i2c_slave_addr <= MPU6050_I2C_ADDR;     
                        r_i2c_rw <= 1'b0;                     //write
                        r_i2c_sub_addr <= 8'h6B;              //register address is 0x6B for Device ID
                        r_i2c_byte_len <= 5'd1;               //write 1byte 
                        r_state <= ST_WRITE_INIT_REQ;
                    end
                end

                ST_WRITE_INIT_REQ: begin
                    if(w_write_ready) begin
                        r_write_valid <= 1'b1;
                        r_cmd_valid <= 1'b0;
                        r_i2c_wdata <= 8'b0;
                        r_state <= ST_WRITE_INIT_DONE;
                    end
                end

                ST_WRITE_INIT_DONE: begin
                    if(w_cmd_ready) begin
                        r_write_valid <= 1'b0;
                        r_state <= ST_READ_WHO_SETUP;
                    end
                end

                ST_READ_WHO_SETUP: begin
                    if(r_delay_cnt == 100_000_000) begin       
                        r_cmd_valid <= 1'b1;
                        r_i2c_slave_addr <= MPU6050_I2C_ADDR;    
                        r_i2c_rw <= 1'b1;                      //read
                        r_i2c_sub_addr <= 8'h75;               //register address is 0x75 for WHO AM I
                        r_i2c_byte_len <= 5'd1;                //read 1byte 
                        r_i2c_wdata <= 8'b0;                   //nothing to write, this is a read
                        r_state <= ST_READ_WHO_REQ;
                        r_readbyte_cnt <= 0;
                    end else begin
                        r_delay_cnt <= r_delay_cnt + 'h1;
                    end
                end

                ST_READ_WHO_REQ: begin
                    if(w_read_ready) begin
                        r_cmd_valid <= 1'b0;
                        r_read_valid <= 1'b1;
                        r_state <= ST_READ_WHO_AWAIT;
                    end
                end

                ST_READ_WHO_AWAIT: begin
                    if(w_valid_out) begin
                        r_state <= ST_READ_WHO_LOAD;
                        r_readbyte <= w_i2c_data_out;
                        r_read_valid <= 1'b0;
                    end
                end

                ST_READ_WHO_LOAD: begin
                    r_state <= SEN_14_DATA_REQ;
                    r_whoami <= r_readbyte;
                end

                SEN_14_DATA_REQ: begin
                    if(w_cmd_ready) begin
                        r_i2c_slave_addr <= MPU6050_I2C_ADDR;     
                        r_i2c_rw <= 1'b1;                      //read
                        r_i2c_sub_addr <= 8'h3B;               //Register address is 0x3B for ACCEL_XOUT_H
                        r_i2c_byte_len <= 5'd14;               //read 14byte 
                        r_i2c_wdata <= 8'b0;                   //Nothing to write, this is a read
                        r_state <= ST_READ_1BYTE_REQ ;
                        r_cmd_valid <= 1'b1;
                        r_readbyte_cnt <= 0;
                    end
                end

                ST_READ_1BYTE_REQ : begin
                    if(w_read_ready) begin // wait until i2c master start communicating
                        r_state <= ST_READ_1BYTE_AWAIT;
                        r_cmd_valid <= 1'b0;
                        r_read_valid <= 1'b1;
                    end
                end

                ST_READ_1BYTE_AWAIT: begin
                    if(w_valid_out) begin // wait until data comes from slave
                        r_state <= ST_READ_1BYTE_LOAD;
                        r_readbyte <= w_i2c_data_out;
                    end
                end

                ST_READ_1BYTE_LOAD: begin
                    if(r_readbyte_cnt == r_i2c_byte_len-1) begin
                        r_state <= SEN_14_DATA_REQ;
                        r_senser_14_read <= 1'b1;
                        r_read_valid <= 1'b0;
                    end
                    else if (!w_valid_out) begin
                        r_readbyte_cnt <= r_readbyte_cnt + 1;
                        r_state <= ST_READ_1BYTE_AWAIT;
                    end
                    case(r_readbyte_cnt)
                       0:  r_senser_14_data[111 : 104] <= r_readbyte; // ax_h
                       1:  r_senser_14_data[103 :  96] <= r_readbyte; // ax_l
                       2:  r_senser_14_data[95 :   88] <= r_readbyte; // ay_h
                       3:  r_senser_14_data[87 :   80] <= r_readbyte; // ay_l
                       4:  r_senser_14_data[79 :   72] <= r_readbyte; // az_h
                       5:  r_senser_14_data[71 :   64] <= r_readbyte; // az_l
                       6:  r_senser_14_data[63 :   56] <= r_readbyte; // tp_h
                       7:  r_senser_14_data[55 :   48] <= r_readbyte; // tp_l
                       8:  r_senser_14_data[47 :   40] <= r_readbyte; // gx_h
                       9:  r_senser_14_data[39 :   32] <= r_readbyte; // gx_l
                       10: r_senser_14_data[31 :   24] <= r_readbyte; // gy_h
                       11: r_senser_14_data[23 :   16] <= r_readbyte; // gy_l
                       12: r_senser_14_data[15 :    8] <= r_readbyte; // gz_h
                       13: r_senser_14_data[7  :    0] <= r_readbyte; // gz_l
                       default: ;
                    endcase
                end

                ST_ERROR: begin
                    r_whoami <= 8'he9;
                end

                default:
                    r_state <= ST_WRITE_INIT_SETUP;
            endcase

            if(w_write_ready & w_cmd_ready & w_nack) begin
                r_state <= ST_ERROR;
            end
        end
    end

    //Instantiate daughter modules 
    i2c_master i_i2c_master(
        .clk_i          (clk_i),                   //input clock CLK_FREQ_MHZ in config.vh
        .rst_i          (!rst_i),                  //reset i2c_master
        .slave_addr_i   (r_i2c_slave_addr),        //slave address(7bit)
        .reg_addr_i     (r_i2c_sub_addr),          //register address(8bit) 
        .byte_len_i     (r_i2c_byte_len),          //number of bytes to read or write
        .wdata_i        (r_i2c_wdata),             //write data(8bit)
        .cmd_valid_i    (r_cmd_valid),             //valid signal for start of transaction 
        .write_valid_i  (r_write_valid),           //valid signal for write
        .read_valid_i   (r_read_valid),            //valid signal for read
        .rw_mode_i      (r_i2c_rw),                //1: read, 0:write
        .cmd_ready_o    (w_cmd_ready),             //ready signal for start of transaction  
        .write_ready_o  (w_write_ready),           //ready signal for write
        .read_ready_o   (w_read_ready),            //ready signal for read
        .read_data_o    (w_i2c_data_out),          //read data from slave
        .data_valid_o   (w_valid_out),             //data valid of read_data
        .nack_o         (w_nack),                  //negative Acknowledgment(failed transaction)
        .scl            (scl),                     //clock bus 
        .sda            (sda)                      //data bus
    );  

endmodule
