/******************************************************************************************/
/* Self Balancing Car Project since 2025-01      Copyright(c) 2025 Archlab. Science Tokyo */
/* this code is not verified well                                                         */
/******************************************************************************************/
`include "config.vh"
//I2C(センサとFPGAの通信)
module mpu6050(
    input clk_i,          //input clock CLK_FREQ_MHZ in config.vh
    input rst_i,          //reset (active high)
    output [31:0] data1_o, // MMIO
    output [31:0] data2_o, // MMIO
    output [31:0] data3_o, // MMIO
    //MPU6050 Interface
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
    reg [3:0 ] state;
    reg [7:0 ] data_read;
    reg        en_cntr;
    reg [26:0] cntr;
    reg [23:0] read_bytes;
    reg        who_am_i_read;
    reg        senser_14_read;

    //For I2C Master
    reg  [7:0]  slave_addr;
    reg  [15:0] sub_addr_i;
    reg  [23:0] byte_len_i;
    reg  [7:0]  wdata_i;
    reg         request_transmit;
    wire [7:0]  data_out;
    wire        valid_out;
    wire        busy;
    wire        nack;

    //State machine for setup and 1 second reads of Temperature
    always@(posedge clk_i or posedge rst_i) begin
        //Set all regs to a known state
        if(rst_i) begin
            //For I2C Driver Regs
            slave_addr <= {I2C_ADDR, 1'b1};     //Pretty much always do reads for this module
            {sub_addr_i, byte_len_i} <= 0;
            {wdata_i, request_transmit} <= 0;

            //For internal regs
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
                    slave_addr <= {I2C_ADDR, 1'b0};     //LSB denotes write
                    sub_addr_i <= 16'h6B;               //Register address is 0x6B for Device ID
                    byte_len_i <= 23'd1;                //Denotes 1 bytes to read
                    wdata_i <= 8'b0;               //Write 0000_0000
                    state <= WRITE_REQ;
                    request_transmit <= 1'b1;
                end

                WRITE_REQ: begin
                    if(busy) begin
                        state <= WRITE_FINISH;
                        request_transmit <= 1'b0;
                        en_cntr <= 1'b1;
                    end
                end

                WRITE_FINISH: begin
                    if(!busy) begin
                        state <= WHO_AM_I_AQ;
                    end
                end

                WHO_AM_I_AQ: begin
                    if(cntr == 100_000_000) begin //1 sec delay
                        en_cntr <= 1'b0;
                        slave_addr <= {I2C_ADDR, 1'b1};     //LSB denotes read
                        sub_addr_i <= 16'h75;               //Register address is 0x75 for WHO AM I
                        byte_len_i <= 23'd1;                //Denotes 1 bytes to read
                        wdata_i <= 8'b0;               //Nothing to write, this is a read
                        state <= WHO_READ_REQ;
                        request_transmit <= 1'b1;
                        read_bytes <= 0;
                    end
                end

                WHO_READ_REQ: begin
                    if(busy) begin
                        state <= WHO_AWAIT_DATA;
                        request_transmit <= 1'b0;
                        en_cntr <= 1'b1;
                    end
                end

                WHO_AWAIT_DATA: begin
                    if(valid_out) begin
                        state <= WHO_LOAD_DATA_AQ;
                        data_read <= data_out;
                    end
                end

                WHO_LOAD_DATA_AQ: begin
                    state <= SEN_14_DATA_REQ;//TEMP_DATA_AQ;
                    who_am_i_read <= 1'b1;
                    who_am_i <= data_read;
                end

                SEN_14_DATA_REQ: begin
                    if(!busy) begin
                    // wait until busy is 0 (and valid out is 0) : busy is 1 (READ_REQ~ I2C:RELEASE), (valid is 1 (AWAIT_DATA~)
                    // wait til busy is 0 in order to verify I2C master is IDLE state
                        en_cntr <= 1'b0; //  =: cntr <= 0
                        slave_addr <= {I2C_ADDR, 1'b1};     //LSB denotes read
                        sub_addr_i <= 16'h3B;               //Register address is 0x3B for ACCEL_XOUT_H
                        byte_len_i <= 23'd14;                //Denotes 14 bytes to read
                        wdata_i <= 8'b0;               //Nothing to write, this is a read
                        state <= READ_REQ;
                        request_transmit <= 1'b1;
                        read_bytes <= 0;
                    end
                end

                READ_REQ: begin
                    if(busy) begin // wait until i2c master start communicating
                        state <= AWAIT_DATA;
                        request_transmit <= 1'b0;
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
                    end
                    //else begin
                    else if (!valid_out) begin
                    // wait !valid_out from i2c master but maybe it is in void
                    // at i2c master, valid_out asserted only 1 clk in my understanding.
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
    i2c_master i_i2c_master(.clk_i          (clk_i),                   //input clock CLK_FREQ_MHZ in config.vh
                            .reset_n        (!rst_i),                  //reset for creating a known start condition
                            .slave_addr_i    (slave_addr),              //7 bit address, LSB is the read write bit, with 0 being write, 1 being read
                            .sub_addr_i     (sub_addr_i),              //contains sub addr to send to slave, partition is decided on bit_sel
                            .byte_len_i     (byte_len_i),              //denotes whether a single or sequential read or write will be performed (denotes number of bytes to read or write)
                            .wdata_i        (wdata_i),            //Data to write if performing write action
                            .req_trans      (request_transmit),        //denotes when to start a new transaction

                            /** For Reads **/
                            .data_out       (data_out),
                            .valid_out      (valid_out),

                            /** I2C Lines **/
                            .scl_o          (scl),                     //i2c clck line, output by this module, 400 kHz
                            .sda_o          (sda),                     //i2c data line, set to 1'bz when not utilized (resistors will pull it high)

                            /** Comms to Master Module **/
                            .busy           (busy),                    //denotes whether module is currently communicating with a slave
                            .nack           (nack)
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


