/******************************************************************************************/
/* Self Balancing Car Project since 2025-01      Copyright(c) 2025 Archlab. Science Tokyo */
/* this code is not verified well                                                         */
/******************************************************************************************/
`include "config.vh"
module mpu6050(
    input clk_i,            //input clock CLK_FREQ_MHZ in config.vh
    input rst_i,            //reset (active high)
    output [31:0] data1_o,  //MMIO dara
    output [31:0] data2_o,  //MMIO data
    output [31:0] data3_o,  //MMIO data
    inout scl,              //I2C SCL PULLUP TRUE at Pmod
    inout sda               //I2C SDA PULLUP TRUE at Pmod
    );

    reg [7:0] r_whoami;
    reg [8*14-1:0] r_sensor14data; // {ax, ay, az, temp, gx, gy, gz}
    
    assign data1_o = {r_sensor14data[95:80], r_sensor14data[111:96]}; // ay, ax
    assign data2_o = {r_sensor14data[47:32], r_sensor14data[ 79:64]}; // gx, az
    assign data3_o = {r_sensor14data[15: 0], r_sensor14data[ 31:16]}; // gz, gy

    localparam [6:0] MPU6050_I2C_ADDR = 7'h68;

    //States
    localparam [3:0] ST_WRITE_INIT_SETUP    = 4'd0,
                     ST_WRITE_INIT_REQ      = 4'd1,
                     ST_WRITE_INIT_DONE     = 4'd2,
                     ST_READ_WHO_SETUP      = 4'd3,
                     ST_READ_WHO_REQ        = 4'd4,
                     ST_READ_WHO_AWAIT      = 4'd5,
                     ST_READ_WHO_LOAD       = 4'd6,
                     ST_READ_14_SETUP       = 4'd7,
                     ST_READ_1BYTE_REQ      = 4'd8,
                     ST_READ_1BYTE_AWAIT    = 4'd9,
                     ST_READ_1BYTE_LOAD     = 4'd10,
                     ST_ERROR               = 4'd11;

    reg  [3:0 ] r_state;
    reg  [7:0 ] r_readbyte;
    reg  [26:0] r_delay_cnt;
    reg  [23:0] r_readbyte_cnt;

    reg  [6:0 ] r_i2c_slave_addr = MPU6050_I2C_ADDR;
    reg         r_i2c_rw;
    reg  [15:0] r_i2c_sub_addr;
    reg  [23:0] r_i2c_byte_len;
    reg  [7:0 ] r_i2c_wdata;
    reg         r_i2c_req_trans;
    wire [7:0 ] w_i2c_data_out;
    wire        w_i2c_valid_out;
    wire        w_i2c_busy;
    wire        w_i2c_nack;

    always@(posedge clk_i) begin
        if(rst_i) begin
            r_state <= ST_WRITE_INIT_SETUP;
            r_readbyte <= 'h0;
            r_readbyte_cnt <= 'h0;
            r_delay_cnt <= 'h0;
            r_i2c_rw <= 1'b1;
            r_i2c_sub_addr <= 'h0;
            r_i2c_byte_len <= 'h0;
            r_i2c_wdata <= 'h0;
            r_i2c_req_trans <= 'h0;
            r_whoami <= 'h0;
            r_sensor14data <= 'h0;
        end else if(w_i2c_busy & w_i2c_nack) begin
            r_state <= ST_ERROR;
        end else begin
            case(r_state)
                ST_WRITE_INIT_SETUP: begin
                    r_state <= ST_WRITE_INIT_REQ;
                    r_i2c_rw <= 1'b0;                       //Write
                    r_i2c_sub_addr <= 16'h6B;               //PWR_MGMT_1 in MPU6050 (include SLEEP flag)
                    r_i2c_byte_len <= 23'd1;                //Write 1byte
                    r_i2c_wdata <= 8'b0;                    //Write 0000_0000 (relese SLEEP)
                    r_i2c_req_trans <= 1'b1;                //Request transmit
                end

                ST_WRITE_INIT_REQ: begin
                    if(w_i2c_busy) begin
                        r_state <= ST_WRITE_INIT_DONE;
                        r_i2c_req_trans <= 1'b0;
                    end
                end

                ST_WRITE_INIT_DONE: begin
                    if(!w_i2c_busy) begin
                        r_state <= ST_READ_WHO_SETUP;
                        r_delay_cnt <= 'h0;
                    end
                end

                ST_READ_WHO_SETUP: begin
                    if(r_delay_cnt == 27'd100_000_000) begin //Delay for IMU setup
                        r_state <= ST_READ_WHO_REQ;
                        r_readbyte_cnt <= 'h0;
                        r_i2c_rw <= 1'b1;                       //Read
                        r_i2c_sub_addr <= 16'h75;               //WHO_AM_I in MPU6050
                        r_i2c_byte_len <= 23'd1;                //Read 1byte
                        r_i2c_req_trans <= 1'b1;                //Request transmit
                    end
                    r_delay_cnt <= r_delay_cnt + 'h1;
                end

                ST_READ_WHO_REQ: begin
                    if(w_i2c_busy) begin
                        r_state <= ST_READ_WHO_AWAIT;
                        r_i2c_req_trans <= 1'b0;
                    end
                end

                ST_READ_WHO_AWAIT: begin
                    if(w_i2c_valid_out) begin
                        r_state <= ST_READ_WHO_LOAD;
                        r_readbyte <= w_i2c_data_out;
                    end
                end

                ST_READ_WHO_LOAD: begin
                    r_state <= ST_READ_14_SETUP;
                    r_whoami <= r_readbyte;
                end

                ST_READ_14_SETUP: begin
                    if(!w_i2c_busy) begin // Wait until w_i2c_busy is 0 in order to verify I2C master is IDLE
                        r_state <= ST_READ_1BYTE_REQ;
                        r_readbyte_cnt <= 'h0;
                        r_i2c_rw <= 1'b1;                       //Read
                        r_i2c_sub_addr <= 16'h3B;               //ACCEL_XOUT_H in MPU6050
                        r_i2c_byte_len <= 23'd14;               //Read 14bytes
                        r_i2c_req_trans <= 1'b1;                //Request transmit
                    end
                end

                ST_READ_1BYTE_REQ: begin
                    if(w_i2c_busy) begin // Wait until i2c master start communicating
                        r_state <= ST_READ_1BYTE_AWAIT;
                        r_i2c_req_trans <= 1'b0;
                    end
                end

                ST_READ_1BYTE_AWAIT: begin
                    if(w_i2c_valid_out) begin // Wait until data comes from slave
                        r_state <= ST_READ_1BYTE_LOAD;
                        r_readbyte <= w_i2c_data_out;
                    end
                end

                ST_READ_1BYTE_LOAD: begin
                    if(r_readbyte_cnt == r_i2c_byte_len-1) begin
                        r_state <= ST_READ_14_SETUP;
                    end
                    //else begin
                    else if (!w_i2c_valid_out) begin // Wait !w_i2c_valid_out from i2c master but maybe it is in void
                        r_state <= ST_READ_1BYTE_AWAIT;
                        r_readbyte_cnt <= r_readbyte_cnt + 'h1;
                    end
                    case(r_readbyte_cnt)
                       0:  r_sensor14data[111 : 104] <= r_readbyte; // ax_h
                       1:  r_sensor14data[103 :  96] <= r_readbyte; // ax_l
                       2:  r_sensor14data[95 :   88] <= r_readbyte; // ay_h
                       3:  r_sensor14data[87 :   80] <= r_readbyte; // ay_l
                       4:  r_sensor14data[79 :   72] <= r_readbyte; // az_h
                       5:  r_sensor14data[71 :   64] <= r_readbyte; // az_l
                       6:  r_sensor14data[63 :   56] <= r_readbyte; // tp_h
                       7:  r_sensor14data[55 :   48] <= r_readbyte; // tp_l
                       8:  r_sensor14data[47 :   40] <= r_readbyte; // gx_h
                       9:  r_sensor14data[39 :   32] <= r_readbyte; // gx_l
                       10: r_sensor14data[31 :   24] <= r_readbyte; // gy_h
                       11: r_sensor14data[23 :   16] <= r_readbyte; // gy_l
                       12: r_sensor14data[15 :    8] <= r_readbyte; // gz_h
                       13: r_sensor14data[7  :    0] <= r_readbyte; // gz_l
                       default: ;
                    endcase
                end

                ST_ERROR: begin
                    r_whoami <= 8'he9;
                end

                default:
                    r_state <= ST_WRITE_INIT_SETUP;
            endcase
        end
    end

    /**************************************************/
    // i2c master based on  chance189/I2C_Master      //
    /**************************************************/
    i2c_master i_i2c_master(.clk_i          (clk_i),                //input clock CLK_FREQ_MHZ in config.vh
                            .reset_n        (!rst_i),               //reset for creating a known start condition
                            .slave_addr_i   ({r_i2c_slave_addr, r_i2c_rw}),     //7 bit address, LSB is the read write bit, with 0 being write, 1 being read
                            .sub_addr_i     (r_i2c_sub_addr),       //contains sub addr to send to slave, partition is decided on bit_sel
                            .byte_len_i     (r_i2c_byte_len),       //denotes whether a single or sequential read or write will be performed (denotes number of bytes to read or write)
                            .wdata_i        (r_i2c_wdata),          //Data to write if performing write action
                            .req_trans      (r_i2c_req_trans),      //denotes when to start a new transaction

                            /** For Reads **/
                            .data_out       (w_i2c_data_out),
                            .valid_out      (w_i2c_valid_out),

                            /** I2C Lines **/
                            .scl_o          (scl),                  //i2c clck line, output by this module, 400 kHz
                            .sda_o          (sda),                  //i2c data line, set to 1'bz when not utilized (resistors will pull it high)

                            /** Comms to Master Module **/
                            .busy           (w_i2c_busy),           //denotes whether module is currently communicating with a slave
                            .nack           (w_i2c_nack)
                            );  

endmodule


//i2c_master module excluding multi-bit write
module i2c_master(input             clk_i,              //input clock CLK_FREQ_MHZ
                  input             reset_n,            //reset 
                  input      [7:0]  slave_addr_i,       //7 bit address(LSB is a bit explaing read or wite)
                  input      [15:0] sub_addr_i,         //contains sub addr to send to slave, partition is decided on bit_sel
                  input      [23:0] byte_len_i,         //the bit length of read or write
                  input      [7:0]  wdata_i,            //write data
                  input             req_trans,          //signal of start a new transaction
                  output reg [7:0]  data_out,
                  output reg        valid_out,
                  inout             scl_o,              //i2c clck line, output by this module, 400 kHz
                  inout             sda_o,              //i2c data line, set to 1'bz when not utilized (resistors will pull it high)
                  output reg        busy,               //when communicating with slave = 1, not communicating = 0
                  output reg        nack                //Negative Acknowledgment(failed transaction)
                  );

//all state               
localparam [3:0] IDLE        = 4'd0,
                 START       = 4'd1,
                 RESTART     = 4'd2,
                 SLAVE_ADDR  = 4'd3,
                 SUB_ADDR    = 4'd4,
                 READ        = 4'd5,
                 WRITE       = 4'd6,
                 ACK_NACK_SLAVE = 4'd7,
                 ACK_NACK_MASTER = 4'd8,
                 STOP        = 4'h9,
                 RELEASE_BUS = 4'hA;

//Frequency dividing ratio tailored to 400 KHz
localparam [15:0] DIV_CLK = (`CLK_FREQ_MHZ*1_000_000)/(400_000*2);

//communication restrictions
localparam [7:0]  START_SETUP_TIME  = (600 * (`CLK_FREQ_MHZ*1_000)) / 1_000_000,  //start setup
                  START_HOLD_TIME   = (95 * (`CLK_FREQ_MHZ*1_000)) / 1_000_000,   //start hold
                  DATA_HOLD_TIME   = (30 * (`CLK_FREQ_MHZ*1_000)) / 1_000_000,    //data hold
                  DATA_SETUP_TIME  = (20 * (`CLK_FREQ_MHZ*1_000)) / 1_000_000,    //data setup
                  STOP_SETUP_TIME   = (600 * (`CLK_FREQ_MHZ*1_000)) / 1_000_000,  //stop setop
                  LOW_PIREOD_TIME  = (1300 * (`CLK_FREQ_MHZ*1_000)) / 1_000_000,  //scl low(400KHz)
                  HIGH_PIREOD_TIME = (1200 * (`CLK_FREQ_MHZ*1_000)) / 1_000_000;  //scl high(400KHz)

reg [3:0]  state;
reg [3:0]  next_state;
reg        reg_sda_o;
reg [7:0]  addr;
reg        rw;
reg [15:0] sub_addr;
reg [23:0] byte_len;
reg        en_scl;
reg        byte_sent;
reg [23:0] num_byte_sent;
reg [2:0]  cntr;
reg [7:0]  byte_sr;
reg        read_sub_addr_sent_flag;
reg [7:0]  data_to_write;
reg [7:0]  data_in_sr;
reg        sub_len;

//400KHz clock generation
reg        clk_scl;
reg [15:0] clk_scl_cntr;

//sampling sda and scl
reg        sda_prev;
reg [1:0]  sda_curr;
reg        scl_prev;
reg        scl_curr;
reg        ack_in_prog;
reg        ack_nack;
reg        en_end_indicator;
reg        scl_is_high;
reg        scl_is_low;


//i2c_clock_generation(400KHz)
//always@(posedge clk_i or negedge reset_n) begin
always@(posedge clk_i) begin
    if(!reset_n)
        {clk_scl_cntr, clk_scl} <= 17'b1;
    else if(!en_scl)
        {clk_scl_cntr, clk_scl} <= 17'b1;
    else begin
        clk_scl_cntr <= clk_scl_cntr + 1;
        if(!clk_scl && clk_scl_cntr == LOW_PIREOD_TIME-1) begin //scl high period
            clk_scl <= !clk_scl;
            clk_scl_cntr <= 0;
        end else if(clk_scl && clk_scl_cntr == HIGH_PIREOD_TIME-1) begin //scl low period
            clk_scl <= !clk_scl;
            clk_scl_cntr <= 0;
        end
    end
end



//main state
//always@(posedge clk_i or negedge reset_n) begin
always@(posedge clk_i) begin
    if(!reset_n) begin
        {data_out, valid_out} <= 0;
        {busy, nack} <= 0;
        {addr, rw, sub_addr, sub_len, byte_len, en_scl} <= 0;
        {byte_sent, num_byte_sent, cntr, byte_sr} <= 0;
        {read_sub_addr_sent_flag, data_to_write, data_in_sr} <= 0;
        {ack_nack, ack_in_prog, en_end_indicator} <= 0;
        {scl_is_high, scl_is_low} <= 0;
        reg_sda_o <= 1'bz;
        state <= IDLE;
        next_state <= IDLE;
    end
    else begin
        valid_out <= 1'b0;
        case(state)
            //wait for new transaction
            IDLE: begin
                if(req_trans & !busy) begin
                    
                    busy <= 1'b1;
                    state <= START;
                    next_state <= SLAVE_ADDR;
                    
                    addr <= slave_addr_i;
                    rw <= slave_addr_i[0];
                    sub_addr <= {sub_addr_i[7:0], 8'b0};
                    sub_len <= 1'd0;
                    data_to_write <= wdata_i;
                    byte_len <= byte_len_i;
              
                    en_scl <= 1'b1;
                    reg_sda_o <= 1'b1;
            
                    nack <= 1'b0;  
                    read_sub_addr_sent_flag <= 1'b0;
                    num_byte_sent <= 0;
                    byte_sent <= 1'b0;
                end
            end
            
            //setup start condition
            START: begin
                if(scl_prev & scl_curr & clk_scl_cntr == START_SETUP_TIME) begin   
                    reg_sda_o <= 1'b0;                                       //set start bit for negedge of clock, and toggle for the clock to begin
                    byte_sr <= {addr[7:1], 1'b0};                            
                    state <= SLAVE_ADDR;
                end
            end
            
            //repeat start
            RESTART: begin
                if(!scl_curr & scl_prev) begin
                    reg_sda_o <= 1'b1;              //Set line high
                end
                
                if(!scl_prev & scl_curr) begin      //so i2c cntr has reset
                    scl_is_high <= 1'b1;
                end
                
                if(scl_is_high) begin
                    if(clk_scl_cntr == START_SETUP_TIME) begin   
                        scl_is_high <= 1'b0;
                        reg_sda_o <= 1'b0;
                        state <= SLAVE_ADDR;
                        byte_sr <= addr;
                    end
                end
            end
            
            //write slave addr
            SLAVE_ADDR: begin
                if(byte_sent & cntr[0]) begin
                    byte_sent <= 1'b0;                      
                    next_state <= read_sub_addr_sent_flag ? READ : SUB_ADDR; //sub_addr[15:8] was sent -> READ, not yet -> SUB_ADDR   
                    byte_sr <= sub_addr[15:8];              
                    state <= ACK_NACK_SLAVE;                  
                    reg_sda_o <= 1'bz;                      
                    cntr <= 0;
                end
                else begin
                    if(!scl_curr & scl_prev) begin
                        scl_is_low <= 1'b1;
                    end
                    
                    if(scl_is_low) begin
                        if(clk_scl_cntr == DATA_HOLD_TIME) begin
                            {byte_sent, cntr} <= {byte_sent, cntr} + 1;       //check 8bit shift
                            reg_sda_o <= byte_sr[7];                //send MSB
                            byte_sr <= {byte_sr[6:0], 1'b0};        //shift out MSB
                            scl_is_low <= 1'b0;
                        end
                    end
                end
            end
            
            //sub_addr
            SUB_ADDR: begin
                if(byte_sent & cntr[0]) begin
                    if(sub_len) begin                       //1 for 16 bit
                        state <= ACK_NACK_SLAVE;
                        next_state <= SUB_ADDR;
                        sub_len <= 1'b0;                    //denote only want 8 bit next time
                        byte_sr <= sub_addr[7:0];           //set the byte shift register
                    end
                    else begin
                        //rw=0 : move to write state, rw=1 : move to RESTART
                        next_state <= rw ? RESTART : WRITE;   
                        byte_sr <= rw ? byte_sr : data_to_write; 
                        read_sub_addr_sent_flag <= 1'b1;    
                    end
                    
                    cntr <= 0;
                    byte_sent <= 1'b0;                      //deassert the flag
                    state <= ACK_NACK_SLAVE;                   //await for nack_ack
                    reg_sda_o <= 1'bz;                      //release sda line
                end
                else begin
                    if(!scl_curr & scl_prev) begin
                        scl_is_low <= 1'b1;
                    end
                    
                    if(scl_is_low) begin
                        if(clk_scl_cntr == DATA_HOLD_TIME) begin
                            scl_is_low <= 1'b0;
                            {byte_sent, cntr} <= {byte_sent, cntr} + 1;       //check 8bit shift
                            reg_sda_o <=  byte_sr[7];                         //send MSB
                            byte_sr <= {byte_sr[6:0], 1'b0};                  //shift out MSB
                        end
                    end
                end
            end
            
            //read data from slave(mpu-6050)
            READ: begin
                if(byte_sent) begin
                    byte_sent <= 1'b0;          //reset flag
                    data_out  <= data_in_sr;    //put information in valid output
                    valid_out <= 1'b1;          //valid signal to master
                    state <= ACK_NACK_MASTER;       //Send ack(Acknowledgment)

                    //chek reading all bytes
                    next_state <= (num_byte_sent == byte_len-1) ? STOP : READ;      
                    ack_nack <= num_byte_sent == byte_len-1;                        
                    num_byte_sent <= num_byte_sent + 1;  
                    ack_in_prog <= 1'b1;
                end
                else begin
                    if(!scl_prev & scl_curr) begin
                        scl_is_high <= 1'b1;
                    end
                    
                    //read one bit at a time.
                    if(scl_is_high) begin
                        if(clk_scl_cntr == START_SETUP_TIME) begin
                            valid_out <= 1'b0;
                            {byte_sent, cntr} <= cntr + 1;
                            data_in_sr <= {data_in_sr[6:0], sda_prev}; //MSB first
                            scl_is_high <= 1'b0;
                        end
                    end
                end
            end
            
            //write data to slave(mpu-6050)
            WRITE: begin
                if(byte_sent & cntr[0]) begin
                    cntr <= 0;
                    byte_sent <= 1'b0;
                    state <= ACK_NACK_SLAVE;
                    reg_sda_o <= 1'bz;
                    next_state <= STOP;  //only 1bit write
                    num_byte_sent <= num_byte_sent + 1'b1;
                end
                else begin

                    //detect scl posedge
                    if(!scl_curr & scl_prev) begin
                        scl_is_low <= 1'b1;
                    end
                    
                    //send MSB 
                    if(scl_is_low) begin //negedge
                        if(clk_scl_cntr == DATA_HOLD_TIME) begin
                            {byte_sent, cntr} <= {byte_sent, cntr} + 1;
                            reg_sda_o <= byte_sr[7];                //send MSB
                            byte_sr <= {byte_sr[6:0], 1'b0};        //shift out MSB
                            scl_is_low <= 1'b0;
                        end
                    end
                end
            end
            
            //get ack or nack from slave
            //sda = 1'b1 -> nack, sda = 1'b0 -> ack
            ACK_NACK_SLAVE: begin
                //detect scl posedge
                if(!scl_prev & scl_curr) begin
                    scl_is_high <= 1'b1;
                end
                
                if(scl_is_high) begin
                    if(clk_scl_cntr == START_SETUP_TIME) begin
                        if(!sda_prev) begin      
                            state <= next_state;
                        end
                        else begin
                            nack <= 1'b1;
                            busy <= 1'b0;
                            reg_sda_o <= 1'bz;
                            en_scl <= 1'b0;
                            state <= IDLE;
                        end  
                        scl_is_high <= 1'b0;
                    end
                end
            end
            
            //send ack or nack from master to slave
            //sda = 1'b1 -> nack, sda = 1'b0 -> ack
            ACK_NACK_MASTER: begin
                //detect scl nesedge
                if(!scl_curr & scl_prev) begin
                    scl_is_low <= 1'b1;
                end
                if(scl_is_low) begin          //negedge
                    if(clk_scl_cntr == DATA_HOLD_TIME) begin
                        if(ack_in_prog) begin 
                            reg_sda_o <= ack_nack;          //write ack until negedge of clk
                            ack_in_prog <= 1'b0;
                        end
                        else begin
                            reg_sda_o <= next_state == STOP ? 1'b0 : 1'bz;
                            en_end_indicator <= next_state == STOP ? 1'b1 : en_end_indicator;
                            state <= next_state;
                        end
                        scl_is_low <= 1'b0;
                    end
                end
            end
            
            //stop transaction
            STOP: begin 
                //detect scl nesedge
                if(!scl_curr & scl_prev & !rw) begin 
                    reg_sda_o <= 1'b0;               //Set to low
                    en_end_indicator <= 1'b1;
                end
                
                //detect scl posedge 
                if(scl_curr & scl_prev & en_end_indicator) begin
                    scl_is_high <= 1'b1;
                    en_end_indicator <= 1'b0;
                end
                
                if(scl_is_high) begin
                    if(clk_scl_cntr == STOP_SETUP_TIME) begin
                        reg_sda_o <= 1'b1;
                        state <= RELEASE_BUS;
                        scl_is_high <= 1'b0;
                    end
                end
            end
            
            //bus_release
            RELEASE_BUS: begin
                if(clk_scl_cntr == DIV_CLK-3) begin
                    en_scl <= 1'b0;
                    state <= IDLE;
                    reg_sda_o <= 1'bz;
                    busy <= 1'b0;
                end
            end
            
            default:
                state <= IDLE;
        endcase
    end
end

//syncronize sda and acl
always@(negedge clk_i) begin
    if(!reset_n) begin
        {sda_curr, sda_prev} <= 0;
        {scl_curr, scl_prev} <= 0;
    end
    else begin
        sda_curr <= {sda_curr[0], sda_o};  //2 flip flop synchronization chain
        sda_prev <= sda_curr[1];
        scl_curr <= clk_scl;
        scl_prev <= scl_curr;
    end
end

//inout cannot be reg
assign sda_o = reg_sda_o;
assign scl_o = en_scl ? clk_scl : 1'bz;     //the line will be pulled up to VCC so 1'bz is high
endmodule
/******************************************************************************************/


