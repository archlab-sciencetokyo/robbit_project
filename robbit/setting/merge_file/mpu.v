/******************************************************************************************/
/* robbit(Two-wheeled Self Balancing Car Project) since 2025-10      Copyright(c) 2025 Archlab. Science Tokyo */
/* Released under the MIT license https://opensource.org/licenses/mit                             */
/******************************************************************************************/

`include "config.vh"
//I2C(センサとFPGAの通信)
module mpu6050(
    input clk_i,           //input clock CLK_FREQ_MHZ in config.vh
    input rst_i,           //reset (active high)
    output [31:0] data1_o, // MMIO
    output [31:0] data2_o, // MMIO
    output [31:0] data3_o, // MMIO
    inout scl,          //I2C SCL  PULLUP TRUE at Pmod
    inout sda           //I2C SDA  PULLUP TRUE at Pmod
    );

    reg [7:0] who_am_i;
    reg [8*14-1:0] senser_14_data; // {ax, ay, az, temp, gx, gy, gz}
    
    assign data1_o = {senser_14_data[95:80], senser_14_data[111:96]}; // ay, ax
    assign data2_o = {senser_14_data[47:32], senser_14_data[ 79:64]}; // gx, az
    assign data3_o = {senser_14_data[15: 0], senser_14_data[ 31:16]}; // gz, gy

    localparam [6:0] I2C_ADDR = 7'h68;

    //State machine
    localparam [3:0] SETUP              = 4'd0,
                     WRITE_REQ          = 4'd1,
                     WRITE_FINISH       = 4'd2,
                     WHO_AM_I_AQ        = 4'd3,
                     WHO_READ_REQ       = 4'd4,
                     WHO_AWAIT_DATA     = 4'd5,
                     WHO_LOAD_DATA_AQ   = 4'd6,
                     SEN_14_DATA_REQ    = 4'd7,
                     READ_REQ           = 4'd8,
                     AWAIT_DATA         = 4'd9,
                     INCR_DATA_AQ       = 4'd10,
                     ERROR              = 4'd11;

    //Internal registers
    reg [3:0] state;
    reg [7:0] data_read;
    reg        en_cntr;
    reg [26:0] cntr;
    reg [23:0] read_bytes;
    reg        who_am_i_read;
    reg        senser_14_read;

    //For I2C Master
    reg  [6:0]  slave_addr;
    reg  [7:0] sub_addr_i;
    reg  [4:0] byte_len_i;
    reg         rw_mode;
    reg  [7:0]  wdata_i;
    reg         cmd_valid, write_valid, read_valid;
    wire         cmd_ready, write_ready, read_ready;
    wire [7:0]  data_out;
    wire        valid_out;
    wire        busy;
    wire        nack;

    //State machine for setup and 1 second reads of Temperature
    always@(posedge clk_i or posedge rst_i) begin
        //Set all regs to a known state
        if(rst_i) begin
            //For I2C Driver Regs
            slave_addr <= I2C_ADDR;     
            {sub_addr_i, byte_len_i} <= 0;
            {wdata_i, cmd_valid} <= 0;
            rw_mode <= 0;
            state <= SETUP;
            {read_bytes, data_read, who_am_i_read, senser_14_read} <= 0;
            {cntr, en_cntr} <= 0;
            {who_am_i, senser_14_data} <= 0;
        end
        else begin
            cntr <= en_cntr ? cntr + 1 : 0;
            who_am_i_read <= 1'b0;
            case(state)
                //release sleep mode 
                SETUP: begin
                    if(cmd_ready) begin
                        slave_addr <= I2C_ADDR;     
                        rw_mode <= 1'b0;            //write
                        sub_addr_i <= 8'h6B;        //Register address is 0x6B for Device ID
                        byte_len_i <= 5'd1;         //Denotes 1 bytes to read
                        state <= WRITE_REQ;
                        cmd_valid <= 1'b1;
                    end
                end

                WRITE_REQ: begin
                    if(write_ready) begin
                        state <= WRITE_FINISH;
                        write_valid <= 1'b1;
                        cmd_valid <= 1'b0;
                        en_cntr <= 1'b1;
                        wdata_i <= 8'b0;
                    end
                end

                WRITE_FINISH: begin
                    if(cmd_ready) begin
                        state <= WHO_AM_I_AQ;
                        write_valid <= 1'b0;
                    end
                end

                WHO_AM_I_AQ: begin
                    if(cntr == 100_000_000) begin //1 sec delay
                        en_cntr <= 1'b0;
                        slave_addr <= I2C_ADDR;    
                        rw_mode <= 1'b1;               //read
                        sub_addr_i <= 8'h75;           //Register address is 0x75 for WHO AM I
                        byte_len_i <= 5'd1;            //Denotes 1 bytes to read
                        wdata_i <= 8'b0;               //Nothing to write, this is a read
                        state <= WHO_READ_REQ;
                        cmd_valid <= 1'b1;
                        read_bytes <= 0;
                    end
                end

                WHO_READ_REQ: begin
                    if(read_ready) begin
                        cmd_valid <= 1'b0;
                        read_valid <= 1'b1;
                        state <= WHO_AWAIT_DATA;
                        en_cntr <= 1'b1;
                    end
                end

                WHO_AWAIT_DATA: begin
                    if(valid_out) begin
                        state <= WHO_LOAD_DATA_AQ;
                        data_read <= data_out;
                        read_valid <= 1'b0;
                    end
                end

                WHO_LOAD_DATA_AQ: begin
                    state <= SEN_14_DATA_REQ;
                    who_am_i_read <= 1'b1;
                    who_am_i <= data_read;
                end



                SEN_14_DATA_REQ: begin
                    if(cmd_ready) begin
                        en_cntr <= 1'b0; 
                        slave_addr <= I2C_ADDR;     
                        rw_mode <= 1'b1;               //read
                        sub_addr_i <= 8'h3B;           //Register address is 0x3B for ACCEL_XOUT_H
                        byte_len_i <= 5'd14;           //Denotes 14 bytes to read
                        wdata_i <= 8'b0;               //Nothing to write, this is a read
                        state <= READ_REQ;
                        cmd_valid <= 1'b1;
                        read_bytes <= 0;
                    end
                end

                READ_REQ: begin
                    if(read_ready) begin // wait until i2c master start communicating
                        state <= AWAIT_DATA;
                        cmd_valid <= 1'b0;
                        read_valid <= 1'b1;
                        en_cntr <= 1'b1;
                    end
                end

                AWAIT_DATA: begin
                    if(valid_out) begin // wait until data comes from slave
                        state <= INCR_DATA_AQ;
                        data_read <= data_out;
                    end
                end

                INCR_DATA_AQ: begin
                    if(read_bytes == byte_len_i-1) begin
                        state <= SEN_14_DATA_REQ;
                        senser_14_read <= 1'b1;
                        read_valid <= 1'b0;
                    end
                    else if (!valid_out) begin
                        read_bytes <= read_bytes + 1;
                        state <= AWAIT_DATA;
                    end
                    case(read_bytes)
                       0:  senser_14_data[111 : 104] <= data_read; // ax_h
                       1:  senser_14_data[103 :  96] <= data_read; // ax_l
                       2:  senser_14_data[95 :   88] <= data_read; // ay_h
                       3:  senser_14_data[87 :   80] <= data_read; // ay_l
                       4:  senser_14_data[79 :   72] <= data_read; // az_h
                       5:  senser_14_data[71 :   64] <= data_read; // az_l
                       6:  senser_14_data[63 :   56] <= data_read; // tp_h
                       7:  senser_14_data[55 :   48] <= data_read; // tp_l
                       8:  senser_14_data[47 :   40] <= data_read; // gx_h
                       9:  senser_14_data[39 :   32] <= data_read; // gx_l
                       10: senser_14_data[31 :   24] <= data_read; // gy_h
                       11: senser_14_data[23 :   16] <= data_read; // gy_l
                       12: senser_14_data[15 :    8] <= data_read; // gz_h
                       13: senser_14_data[7  :    0] <= data_read; // gz_l
                       default: ;
                    endcase
                end

                ERROR: begin
                    who_am_i <= 8'he9;
                end

                default:
                    state <= SETUP;
            endcase

            //Error checking
            if(busy & nack) begin
                state <= ERROR;
            end
        end
    end

    //Instantiate daughter modules 
    i2c_master i_i2c_master(
        .clk_i          (clk_i),                   //input clock CLK_FREQ_MHZ in config.vh
        .rst_i          (!rst_i),                  //reset for creating a known start condition
        .slave_addr_i   (slave_addr),              //7 bit slave address
        .reg_addr_i     (sub_addr_i),              //8 bit register address 
        .byte_len_i     (byte_len_i),              //number of bytes to read or write
        .wdata_i        (wdata_i),                 //Data to write if performing write action
        .cmd_valid_i    (cmd_valid),               //denotes when to start a new transaction
        .write_valid_i  (write_valid),
        .read_valid_i   (read_valid),
        .rw_mode_i      (rw_mode),
        .cmd_ready      (cmd_ready),
        .write_ready    (write_ready),
        .read_ready     (read_ready),  
        .data_out       (data_out),
        .valid_out      (valid_out),
        .scl_o          (scl),                      //i2c clck line, output by this module, 400 kHz
        .sda_o          (sda),                      //i2c data line, set to 1'bz when not utilized (resistors will pull it high)
        .busy           (busy),                     //denotes whether module is currently communicating with a slave
        .nack           (nack)
    );  

endmodule
