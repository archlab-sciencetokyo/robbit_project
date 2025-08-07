`include "config.vh"

/******************************************************************************************/
/* Self Balancing Car Project since 2025-01      Copyright(c) 2025 Archlab. Science Tokyo */
/* this code is not verified well                                                         */
/******************************************************************************************/

module mpu6050 (
    input clk_i,          //12MHz input crystal
    input rst_i,          //reset (active high)
    output [31:0] data1_o, // MMIO
    output [31:0] data2_o, // MMIO
    output [31:0] data3_o, // MMIO
    //MPU6050 Interface
    inout scl,          //I2C SCL  PULLUP TRUE at Pmod
    inout sda           //I2C SDA  PULLUP TRUE at Pmod
    );

    assign data1_o = {senser_14_data[95:80], senser_14_data[111:96]}; // ay, ax
    assign data2_o = {senser_14_data[47:32], senser_14_data[ 79:64]}; // gx, az
    assign data3_o = {senser_14_data[15: 0], senser_14_data[ 31:16]}; // gz, gy

    reg [7:0] who_am_i;
    reg [8*14-1:0] senser_14_data; // {ax, ay, az, temp, gx, gy, gz}
    
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
    reg  [15:0] i_sub_addr;
    reg         i_sub_len;
    reg  [23:0] i_byte_len;
    reg  [7:0]  i_data_write;
    reg         request_transmit;
    wire [7:0]  data_out;
    wire        valid_out;
    wire        req_data_chunk;
    wire        busy;
    wire        nack;

    localparam CNT_1_SEC = `CLK_FREQ_MHZ * 1_000_000;                     // 1 second delay

    //State machine for setup and 1 second reads of Temperature
    always@(posedge clk_i or posedge rst_i) begin
        //Set all regs to a known state
        if(rst_i) begin
            //For I2C Driver Regs
            slave_addr <= {I2C_ADDR, 1'b1};     //Pretty much always do reads for this module
            {i_sub_addr, i_sub_len, i_byte_len} <= 0;
            {i_data_write, request_transmit} <= 0;

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
                SETUP: begin
                    slave_addr <= {I2C_ADDR, 1'b0};     //LSB denotes write
                    i_sub_addr <= 16'h6B;               //Register address is 0x6B for Device ID
                    i_sub_len <= 1'b0;                  //Denotes reg addr is 8 bit
                    i_byte_len <= 23'd1;                //Denotes 1 bytes to read
                    i_data_write <= 8'b0;               //Write 0000_0000
                    state <= WRITE_REQ;
                    request_transmit <= 1'b1;
                end

                WRITE_REQ: begin
                    if(busy) begin //I2C_IDLEから遷移
                        state <= WRITE_FINISH;
                        request_transmit <= 1'b0;
                        en_cntr <= 1'b1;
                    end
                end

                WRITE_FINISH: begin //busyはi2cからACKが返ってきた時と終了したときに1になる
                    if(!busy) begin
                        state <= WHO_AM_I_AQ;
                    end
                end

                WHO_AM_I_AQ: begin
                    if(cntr == CNT_1_SEC) begin //1 sec delay
                        en_cntr <= 1'b0;
                        slave_addr <= {I2C_ADDR, 1'b1};     //LSB denotes read
                        i_sub_addr <= 16'h75;               //Register address is 0x75 for WHO AM I
                        i_sub_len <= 1'b0;                  //Denotes reg addr is 8 bit
                        i_byte_len <= 23'd1;                //Denotes 1 bytes to read
                        i_data_write <= 8'b0;               //Nothing to write, this is a read
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
                    if(!busy) begin //0.005 sec delay for 14 byte read 200Hz
                        en_cntr <= 1'b0;
                        slave_addr <= {I2C_ADDR, 1'b1};     //LSB denotes read
                        i_sub_addr <= 16'h3B;               //Register address is 0x3B for ACCEL_XOUT_H
                        i_sub_len <= 1'b0;                  //Denotes reg addr is 8 bit
                        i_byte_len <= 23'd14;                //Denotes 14 bytes to read
                        i_data_write <= 8'b0;               //Nothing to write, this is a read
                        state <= READ_REQ;
                        request_transmit <= 1'b1;
                        read_bytes <= 0;
                    end
                end

                READ_REQ: begin
                    if(busy) begin
                        state <= AWAIT_DATA;
                        request_transmit <= 1'b0;
                        en_cntr <= 1'b1;
                    end
                end

                AWAIT_DATA: begin
                    if(valid_out) begin
                        state <= INCR_DATA_AQ;
                        data_read <= data_out;
                    end
                end

                INCR_DATA_AQ: begin
                    if(read_bytes == i_byte_len-1) begin
                        state <= SEN_14_DATA_REQ;
                        senser_14_read <= 1'b1;
                    end
                    //else begin
                    else begin
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
                    //senser_14_data[8 +: (13-read_bytes)*8] <= data_read;  // {ax_h, ax_l, ay_h, ... temp_h, temp_l, gx_h ... gz_l} : 1byte x 14
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

    // ila_0 your_ila_instance (
    // .clk(clk_i),
    // .probe0(state),
    // .probe1(who_am_i)
    // );

    //Instantiate daughter modules 
    i2c_master #(
    )i_i2c_master(.i_clk          (clk_i),                    //input clock to the module @100MHz (or whatever crystal you have on the board)
                            .reset_n        (!rst_i),                  //reset for creating a known start condition
                            .i_addr_w_rw    (slave_addr),       //7 bit address, LSB is the read write bit, with 0 being write, 1 being read
                            .i_sub_addr     (i_sub_addr),        //contains sub addr to send to slave, partition is decided on bit_sel
                            .i_sub_len      (i_sub_len),          //denotes whether working with an 8 bit or 16 bit sub_addr, 0 is 8bit, 1 is 16 bit
                            .i_byte_len     (i_byte_len),        //denotes whether a single or sequential read or write will be performed (denotes number of bytes to read or write)
                            .i_data_write   (i_data_write),    //Data to write if performing write action
                            .req_trans      (request_transmit),   //denotes when to start a new transaction

                            /** For Reads **/
                            .data_out       (data_out),
                            .valid_out      (valid_out),

                            /** I2C Lines **/
                            .scl_o          (scl),                    //i2c clck line, output by this module, 400 kHz
                            .sda_o          (sda),                    //i2c data line, set to 1'bz when not utilized (resistors will pull it high)

                            /** Comms to Master Module **/
                            .req_data_chunk (req_data_chunk),//Request master to send new data chunk in i_data_write
                            .busy           (busy),                    //denotes whether module is currently communicating with a slave
                            .nack           (nack)
                            );  

endmodule

module i2c_master(input             i_clk,              //input clock to the module 
                  input             reset_n,            //reset for creating a known start condition
                  input      [7:0]  i_addr_w_rw,        //7 bit address, LSB is the read write bit, with 0 being write, 1 being read
                  input      [15:0] i_sub_addr,         //contains sub addr to send to slave, partition is decided on bit_sel
                  input             i_sub_len,          //denotes whether working with an 8 bit or 16 bit sub_addr, 0 is 8bit, 1 is 16 bit
                  input      [23:0] i_byte_len,         //denotes whether a single or sequential read or write will be performed (denotes number of bytes to read or write)
                  input      [7:0]  i_data_write,       //Data to write if performing write action
                  input             req_trans,          //denotes when to start a new transaction
                  
                  /** For Reads **/
                  output reg [7:0]  data_out,
                  output reg        valid_out,
                  
                  /** I2C Lines **/
                  inout             scl_o,              //i2c clck line, output by this module, 400 kHz
                  inout             sda_o,              //i2c data line, set to 1'bz when not utilized (resistors will pull it high)
                  
                  /** Comms to Master Module **/
                  output reg        req_data_chunk ,    //Request master to send new data chunk in i_data_write
                  output reg        busy,               //denotes whether module is currently communicating with a slave
                  output reg        nack                //denotes whether module is encountering a nack from slave (only activates when master is attempting to contact device)
                  
                  `ifdef DEBUG
                  ,
                  output reg [3:0]  state,
                  output reg [3:0]  next_state,
                  output reg        reg_sda_o,
                  output reg [7:0]  addr,
                  output reg        rw,
                  output reg [15:0] sub_addr,
                  output reg        sub_len,
                  output reg [23:0] byte_len,
                  output reg        en_scl,
                  output reg        byte_sent,
                  output reg [23:0] num_byte_sent,
                  output reg [2:0]  cntr,
                  output reg [7:0]  byte_sr,
                  output reg        read_sub_addr_sent_flag,
                  output reg [7:0]  data_to_write,
                  output reg [7:0]  data_in_sr,
                  
                  //400KHz clock generation
                  output reg        clk_i2c,
                  output reg [15:0] clk_i2c_cntr,
                  
                  //sampling sda and scl
                  output reg        sda_prev,
                  output reg [1:0]  sda_curr,
                  output reg        scl_prev,
                  output reg        scl_curr,
                  output reg        ack_in_prog,
                  output reg        ack_nack,
                  output reg        en_end_indicator,
                  output reg        grab_next_data,
                  output reg        scl_is_high,
                  output reg        scl_is_low
                  `endif
                  );



//For state machine                 
localparam [3:0] IDLE        = 4'd0,
                 START       = 4'd1,
                 RESTART     = 4'd2,
                 SLAVE_ADDR  = 4'd3,
                 SUB_ADDR    = 4'd4,
                 
                 READ        = 4'd5,
                 WRITE       = 4'd6,
                 GRAB_DATA   = 4'd7,
                 ACK_NACK_RX = 4'd8,
                 ACK_NACK_TX = 4'd9,
                 STOP        = 4'hA,
                 RELEASE_BUS = 4'hB;
                 
parameter CLK_FREQ  = `CLK_FREQ_MHZ*1_000_000; // System Clock Frequency in Hz
parameter SCL_FREQ = 400_000;     // Desired I2C SCL Clock Frequency in Hz

localparam T_SCL_NS   = 2500; // SCL cycle
localparam T_LOW_NS   = 1300; // SCL low period
localparam T_HIGH_NS  = T_SCL_NS - T_LOW_NS; // SCL high period

localparam [15:0] DIVIDER = (CLK_FREQ/SCL_FREQ)/2;   
localparam T_HD_STA_NS = 600;  // tHD;STA: Hold time for START condition
localparam T_SU_STA_NS = 700;  // tSU;STA: Setup time for START condition
localparam T_SU_DAT_NS = 100;  // tSU;DAT: Data setup time
localparam T_HD_DAT_NS = 30;    // tHD;DAT: Data hold time (spec is 0, using a margin)
localparam T_SU_STO_NS = 600;  // tSU;STO: Setup time for STOP condition
localparam T_BUS_NS   = 1300; // tBUS Bus free

//timing parametor
localparam [7:0]  START_IND_SETUP  = (T_SU_STA_NS * (CLK_FREQ / 1000)) / 1000000,  //Time before negedge of scl
                  START_IND_HOLD   = (T_HD_STA_NS * (CLK_FREQ / 1000)) / 1000000,  //Time after posedge of clock when start occurs (not used)
                  DATA_SETUP_TIME  = (T_SU_DAT_NS * (CLK_FREQ / 1000)) / 1000000,  //Time needed before posedge of scl 
                  DATA_HOLD_TIME   = (T_HD_DAT_NS * (CLK_FREQ / 1000)) / 1000000,  //Time after negedge that scl is held
                  STOP_IND_SETUP   = (T_SU_STO_NS * (CLK_FREQ / 1000)) / 1000000,  //Time after posedge of scl before stop occurs
                  BUS_FREE_TIME    = (T_BUS_NS * (CLK_FREQ / 1000)) / 1000000;
                 
localparam [15:0] DIVIDER_LOW  = (T_LOW_NS  * (CLK_FREQ / 1000)) / 1000000;
localparam [15:0] DIVIDER_HIGH = (T_HIGH_NS * (CLK_FREQ / 1000)) / 1000000;

reg [7:0] wait_cntr;       
reg       en_wait_cntr;      

`ifndef DEBUG
    reg [3:0]  state;
    reg [3:0]  next_state;
    reg        reg_sda_o;
    reg [7:0]  addr;
    reg        rw;
    reg [15:0] sub_addr;
    reg        sub_len;
    reg [23:0] byte_len;
    reg        en_scl;
    reg        byte_sent;
    reg [23:0] num_byte_sent;
    reg [2:0]  cntr;
    reg [7:0]  byte_sr;
    reg        read_sub_addr_sent_flag;
    reg [7:0]  data_to_write;
    reg [7:0]  data_in_sr;

    //For generation of 400KHz clock
    reg clk_i2c;
    reg [15:0] clk_i2c_cntr;
    reg [15:0] clk_state_cntr;

    //For taking a sample of the scl and sda
    reg [1:0] sda_curr;    //So this one is asynchronous especially with replies from the slave, must have synchronization chain of 2
    reg       sda_prev;
    reg scl_prev, scl_curr;          //master will always drive this line, so it doesn't matter

    reg ack_in_prog;      //For sending acks during read
    reg ack_nack;
    reg en_end_indicator;

    reg grab_next_data;
    reg scl_is_high;
    reg scl_is_low;
`endif

//clk_i2c 400KHz is synchronous to i_clk, so no need for 2 reg synchronization chain in other blocks
always@(posedge i_clk or negedge reset_n) begin
    if(!reset_n)
        {clk_i2c_cntr, clk_i2c} <= 17'b1;
    else if(!en_scl)
        {clk_i2c_cntr, clk_i2c} <= 17'b1;
    else begin
        clk_i2c_cntr <= clk_i2c_cntr + 1;
        if(clk_i2c == 1'b1) begin
            if(clk_i2c_cntr == DIVIDER_HIGH-1) begin
                clk_i2c <= !clk_i2c;
                clk_i2c_cntr <= 0;
            end
        end
        if(clk_i2c == 1'b0) begin
            if(clk_i2c_cntr == DIVIDER_LOW-1) begin
                clk_i2c <= !clk_i2c;
                clk_i2c_cntr <= 0;
            end
        end
    end
end

always @(posedge i_clk or negedge reset_n) begin
    if (!reset_n) begin
        wait_cntr <= 8'd0;
    end else if (en_wait_cntr) begin
        wait_cntr <= wait_cntr + 1;
    end else begin
        wait_cntr <= 8'd0; 
    end
end

//Main FSM
always@(posedge i_clk or negedge reset_n) begin
    if(!reset_n) begin
        {data_out, valid_out} <= 0;
        {req_data_chunk, busy, nack} <= 0;
        {addr, rw, sub_addr, sub_len, byte_len, en_scl} <= 0;
        {byte_sent, num_byte_sent, cntr, byte_sr} <= 0;
        {read_sub_addr_sent_flag, data_to_write, data_in_sr} <= 0;
        {ack_nack, ack_in_prog, en_end_indicator} <= 0;
        {scl_is_high, scl_is_low, grab_next_data} <= 0;
        reg_sda_o <= 1'bz;
        state <= IDLE;
        next_state <= IDLE;
    end
    else begin
        valid_out <= 1'b0;
        req_data_chunk <= 1'b0;
        case(state)
            
            IDLE: begin
                if(req_trans & !busy) begin
                    busy <= 1'b1;
                    state <= START;
                    next_state <= SLAVE_ADDR;
                    
                    addr <= i_addr_w_rw;
                    rw <= i_addr_w_rw[0];
                    sub_addr <= i_sub_len ? i_sub_addr : {i_sub_addr[7:0], 8'b0};
                    sub_len <= i_sub_len;
                    data_to_write <= i_data_write;
                    byte_len <= i_byte_len;
            
                    en_scl <= 1'b1;
                    reg_sda_o <= 1'b1;
                    
                    nack <= 1'b0;  
                    read_sub_addr_sent_flag <= 1'b0;
                    num_byte_sent <= 0;
                    byte_sent <= 1'b0;
                end
            end
            
            START: begin
                en_wait_cntr <= 1'b1;
                if(scl_prev & scl_curr & wait_cntr == START_IND_SETUP) begin   //check that scl is high, and that a necessary wait time is held
                    en_wait_cntr <= 1'b0;                                       //set start bit for negedge of clock, and toggle for the clock to begin
                    reg_sda_o <= 1'b0;
                    byte_sr <= {addr[7:1], 1'b0};                            //Don't need to check read or write, will always have write in a read request as well
                    state <= SLAVE_ADDR;
                    $display("DUT: I2C MASTER | TIMESTAMP: %t | MESSAGE: START INDICATION!", $time);
                end
            end
            
            RESTART: begin
                if(!scl_curr & scl_prev) begin
                    reg_sda_o <= 1'b1;              //Set line high
                end
                
                if(!scl_prev & scl_curr) begin      //so i2c cntr has reset
                    scl_is_high <= 1'b1;
                end
                
                if(scl_is_high) begin
                    en_wait_cntr <= 1'b1;
                    if(wait_cntr == START_IND_SETUP) begin   //Must wait minimum setup time
                        en_wait_cntr <= 1'b0;
                        scl_is_high <= 1'b0;
                        reg_sda_o <= 1'b0;
                        state <= SLAVE_ADDR;
                        byte_sr <= addr;
                    end
                end
            end
            
            SLAVE_ADDR: begin
                //When scl has fallen, we can change sda 
                if(byte_sent & cntr[0]) begin
                    byte_sent <= 1'b0;                      //deassert the flag
                    next_state <= read_sub_addr_sent_flag ? READ : SUB_ADDR;    //Check to see if sub addr was sent, we ony reach this state again if doing a read
                    byte_sr <= sub_addr[15:8];              //regardless of sub addr length, higher byte will be sent first
                    state <= ACK_NACK_RX;                   //await for nack_ack
                    reg_sda_o <= 1'bz;                      //release sda line
                    cntr <= 0;
                    $display("DUT: I2C MASTER | TIMESTAMP: %t | MESSAGE: SLAVE_ADDR SENT!", $time);
                end
                else begin
                    if(!scl_curr & scl_prev) begin
                        scl_is_low <= 1'b1;
                    end
                    
                    if(scl_is_low) begin
                        en_wait_cntr <= 1'b1;
                        if(wait_cntr == DATA_HOLD_TIME) begin
                            en_wait_cntr <= 1'b0;
                            {byte_sent, cntr} <= {byte_sent, cntr} + 1;       //incr cntr, with overflow being caught (due to overflow, no need to set cntr to 0)
                            reg_sda_o <= byte_sr[7];                //send MSB
                            byte_sr <= {byte_sr[6:0], 1'b0};        //shift out MSB
                            scl_is_low <= 1'b0;
                        end
                    end
                end
            end
            
            SUB_ADDR: begin
                if(byte_sent & cntr[0]) begin
                    if(sub_len) begin                       //1 for 16 bit
                        state <= ACK_NACK_RX;
                        next_state <= SUB_ADDR;
                        sub_len <= 1'b0;                    //denote only want 8 bit next time
                        byte_sr <= sub_addr[7:0];           //set the byte shift register
                        $display("DUT: I2C MASTER | TIMESTAMP: %t | MESSAGE: MSB OF SUB ADDR SENT", $time);
                    end
                    else begin
                        next_state <= rw ? RESTART : WRITE;   //move to appropriate state
                        byte_sr <= rw ? byte_sr : data_to_write; //if write, want to setup the data to write to device
                        read_sub_addr_sent_flag <= 1'b1;    //For dictating state of machine
                        $display("DUT: I2C MASTER | TIMESTAMP: %t | MESSAGE: SUB ADDR SENT", $time);
                    end
                    
                    cntr <= 0;
                    byte_sent <= 1'b0;                      //deassert the flag
                    state <= ACK_NACK_RX;                   //await for nack_ack
                    reg_sda_o <= 1'bz;                       //release sda line
                end
                else begin
                    if(!scl_curr & scl_prev) begin
                        scl_is_low <= 1'b1;
                    end
                    
                    if(scl_is_low) begin
                        en_wait_cntr <= 1'b1;
                        if(wait_cntr == DATA_HOLD_TIME) begin
                            en_wait_cntr <= 1'b0;
                            scl_is_low <= 1'b0;
                            {byte_sent, cntr} <= {byte_sent, cntr} + 1;       //incr cntr, with overflow being caught
                            reg_sda_o <=  byte_sr[7];               //send MSB
                            byte_sr <= {byte_sr[6:0], 1'b0};        //shift out MSB
                        end
                    end
                end
            end
            
            READ: begin
                if(byte_sent) begin
                    byte_sent <= 1'b0;          //reset flag
                    data_out  <= data_in_sr;    //put information in valid output
                    valid_out <= 1'b1;          //Let master know valid output
                    state <= ACK_NACK_TX;       //Send ack
                    next_state <= (num_byte_sent == byte_len-1) ? STOP : READ;      //Have we read all bytes?
                    ack_nack <= num_byte_sent == byte_len-1;                        //If true, then 1, which is a nack
                    num_byte_sent <= num_byte_sent + 1;  //Incr number of bytes read
                    ack_in_prog <= 1'b1;
                    $display("DUT: I2C MASTER | TIMESTAMP: %t | MESSAGE: READ BYTE #%d SENT!", $time, num_byte_sent);
                end
                else begin
                    if(!scl_prev & scl_curr) begin
                        scl_is_high <= 1'b1;
                    end
                    
                    if(scl_is_high) begin
                        en_wait_cntr <= 1'b1;
                        if(wait_cntr == START_IND_SETUP) begin
                            en_wait_cntr <= 1'b0;
                            valid_out <= 1'b0;
                            {byte_sent, cntr} <= cntr + 1;
                            data_in_sr <= {data_in_sr[6:0], sda_prev}; //MSB first
                            scl_is_high <= 1'b0;
                        end
                    end
                end
            end
            
            WRITE: begin
                if(byte_sent & cntr[0]) begin
                    cntr <= 0;
                    byte_sent <= 1'b0;
                    state <= ACK_NACK_RX;
                    reg_sda_o <= 1'bz;
                    next_state <= (num_byte_sent == byte_len-1) ? STOP : GRAB_DATA;
                    num_byte_sent <= num_byte_sent + 1'b1;
                    grab_next_data <= 1'b1;
                    $display("DUT: I2C MASTER | TIMESTAMP: %t | MESSAGE: WRITE BYTE #%d SENT!", $time, num_byte_sent);
                end
                else begin
                    if(!scl_curr & scl_prev) begin
                        scl_is_low <= 1'b1;
                    end
                    
                    if(scl_is_low) begin //negedge
                        en_wait_cntr <= 1'b1;
                        if(wait_cntr == DATA_HOLD_TIME) begin
                            en_wait_cntr <= 1'b0;
                            {byte_sent, cntr} <= {byte_sent, cntr} + 1;
                            reg_sda_o <= byte_sr[7];
                            byte_sr <= {byte_sr[6:0], 1'b0};        //shift out MSB
                            scl_is_low <= 1'b0;
                        end
                    end
                end
            end
            
            GRAB_DATA: begin
                if(grab_next_data) begin
                    req_data_chunk <= 1'b1;
                    grab_next_data <= 1'b0;
                end
                else begin
                    state <= WRITE;
                    byte_sr <= i_data_write;
                end
            end
            
            ACK_NACK_RX: begin
                if(!scl_prev & scl_curr) begin
                    scl_is_high <= 1'b1;
                end
                
                if(scl_is_high) begin
                    en_wait_cntr <= 1'b1;
                    if(wait_cntr == START_IND_SETUP) begin
                        en_wait_cntr <= 1'b0;
                        if(!sda_prev) begin      //checking for the ack condition (its low)
                            state <= next_state;
                            $display("DUT: I2C MASTER | TIMESTAMP: %t | MESSAGE: rx ack encountered", $time);
                        end
                        else begin
                            $display("DUT: I2C MASTER | TIMESTAMP: %t | MESSAGE: rx nack encountered", $time);
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
            
            ACK_NACK_TX: begin
                if(!scl_curr & scl_prev) begin
                    scl_is_low <= 1'b1;
                end
                if(scl_is_low) begin          //negedge
                    en_wait_cntr <= 1'b1;
                    if(wait_cntr == DATA_HOLD_TIME) begin
                        en_wait_cntr <= 1'b0;
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
            
            STOP: begin 
                if(!scl_curr & scl_prev & !rw) begin //negedge only if we are writing
                    reg_sda_o <= 1'b0;               //Set to low
                    en_end_indicator <= 1'b1;
                end
                
                //Note addition of counter, needed to ensure that there is enough delay for target device
                if(scl_curr & scl_prev & en_end_indicator) begin
                    scl_is_high <= 1'b1;
                    en_end_indicator <= 1'b0;
                end
                
                if(scl_is_high) begin
                    en_wait_cntr <= 1'b1;
                    if(wait_cntr == STOP_IND_SETUP) begin
                        en_wait_cntr <= 1'b0;
                        reg_sda_o <= 1'b1;
                        state <= RELEASE_BUS;
                        scl_is_high <= 1'b0;
                    end
                end
            end
            
            RELEASE_BUS: begin
                en_wait_cntr <= 1'b1;
                if(wait_cntr == BUS_FREE_TIME) begin
                    en_wait_cntr <= 1'b0;
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

always@(negedge i_clk or negedge reset_n) begin
    if(!reset_n) begin
        {sda_curr, sda_prev} <= 0;
        {scl_curr, scl_prev} <= 0;
    end
    else begin
        sda_curr <= {sda_curr[0], sda_o};  //2 flip flop synchronization chain
        sda_prev <= sda_curr[1];
        scl_curr <= clk_i2c;
        scl_prev <= scl_curr;
    end
end

//inout cannot be reg
assign sda_o = reg_sda_o;
assign scl_o = en_scl ? clk_i2c : 1'bz;     //the line will be pulled up to VCC so 1'bz is high
endmodule
/******************************************************************************************/

