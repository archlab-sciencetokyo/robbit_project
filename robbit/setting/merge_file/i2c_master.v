module i2c_master(
    input             clk_i,             //input clock CLK_FREQ_MHZ
    input             rst_i,             //reset 
    input      [6:0]  slave_addr_i,      //7 bit address
    input      [7:0]  reg_addr_i,        //contains sub addr to send to slave, partition is decided on bit_sel
    input      [4:0]  byte_len_i,        //the bit length of read or write
    input      [7:0]  wdata_i,           //write data
    input             cmd_valid_i,          //signal of start a new transaction
    input             write_valid_i,
    input             read_valid_i,
    input             rw_mode_i,           //1: read, 0:write
    output reg        cmd_ready,             //cmd_ready signal
    output reg        write_ready,
    output reg        read_ready,
    output reg [7:0]  data_out,
    output reg        valid_out,
    inout             scl_o,             //i2c clck line, output by this module, 400 kHz
    inout             sda_o,             //i2c data line, set to 1'bz when not utilized (resistors will pull it high)
    output reg        busy,              //when communicating with slave = 1, not communicating = 0
    output reg        nack               //Negative Acknowledgment(failed transaction)
);

    reg [5:0] state, next_state;
    reg [7:0] slave_rw_r;
    reg [7:0] reg_addr_r;
    reg [7:0] wdata_r;
    reg [4:0] bit_counter, byte_len_r;
    reg scl_posedge, scl_negedge, read_flag;
    reg scl_sync1, scl_sync2, sda_sync2, sda_o_r;
    reg [1:0] sda_sync1;
    reg clk_scl, en_scl;
    reg [15:0] clk_scl_cntr;
    reg scl_low, scl_high;

    localparam LOW_PIREOD_TIME  = 130,  //scl low(400KHz)
               HIGH_PIREOD_TIME = 120,  //scl high(400KHz)
               SETUP_TIME = 70,
               DATA_HOLD_TIME = 5;

    //main state
    localparam IDLE = 0,
               START = 1,
               SLAVE_ADDR_WRITE = 2,
               REG_ADDR_WRITE = 3,
               WRITE_WAIT = 4,
               WRITE = 5,
               ACK_WAIT = 6,
               REPEATED_START = 7,
               READ_WAIT = 8,
               READ = 9,
               ACK_SEND = 10,
               STOP = 11,
               RELEASE_BUS = 12;

    assign sda_o = sda_o_r;
    assign scl_o = en_scl ? clk_scl : 1'bz;    

    localparam [15:0] DIV_SCLCK = 16'd125;
    always@(posedge clk_i) begin
        if(!rst_i) begin
            clk_scl_cntr <= 16'b0; 
            clk_scl <= 1'b1;
        end else if(!en_scl) begin
            clk_scl_cntr <= 16'b0; 
            clk_scl <= 1'b1;
        end else begin
            clk_scl_cntr <= clk_scl_cntr + 1;
            if(clk_scl_cntr == DIV_SCLCK-1) begin
                clk_scl <= !clk_scl;
                clk_scl_cntr <= 0;
            end
        end
    end

    always @(posedge clk_i) begin
        if(!rst_i) begin
            {scl_sync1, scl_sync2} <= 0;
            {sda_sync1, sda_sync2} <= 0;
        end else begin
            {scl_sync1, scl_sync2} <= {clk_scl, scl_sync1};
            sda_sync1 <= {sda_sync1[0], sda_o};
            sda_sync2 <= sda_sync1;
        end
    end

    always @(posedge clk_i) begin
        if(!rst_i) begin
            scl_posedge <= 0;
            scl_negedge <= 0;
        end else begin
            if(scl_sync2 & !scl_sync1) begin
                scl_posedge <= 1'b0;
                scl_negedge <= 1'b1;
            end else if(!scl_sync2 & scl_sync1) begin
                scl_posedge <= 1'b1;
                scl_negedge <= 1'b0;
            end else begin
                scl_posedge <= 1'b0;
                scl_negedge <= 1'b0;
            end
        end
    end

    //main state machine
    always @(posedge clk_i) begin
        if(!rst_i) begin
            state <= IDLE;
            next_state <= IDLE;
            slave_rw_r <= 0;
            reg_addr_r <= 0;
            wdata_r <= 0;
            bit_counter <= 0;
            read_flag <= 0;
            byte_len_r <= 0;
            nack <= 0;
            data_out <= 0;
            busy <= 0;
            valid_out <= 0;
            scl_low <= 0;
            scl_high <= 0;
            cmd_ready <= 0;
            write_ready <= 0;
            read_ready <= 0;
        end else begin
            case (state)
                IDLE: begin //setting values
                    valid_out <= 1'b0;
                    cmd_ready <= 1'b1;
                    if(cmd_ready & cmd_valid_i) begin
                        slave_rw_r <= {slave_addr_i, 1'b0}; //Always write first
                        reg_addr_r <= reg_addr_i;
                        // wdata_r <= wdata_i;
                        byte_len_r <= byte_len_i;
                        busy <= 1'b1;
                        state <= START;
                        nack <= 1'b0;
                        en_scl <= 1'b1;   
                        read_flag <= 1'b0;
                        sda_o_r <= 1'b1;  
                        cmd_ready <= 1'b0;
                        write_ready <= 1'b0;
                        read_ready <= 1'b0;
                    end
                end 

                START: begin //set start condition
                    if(scl_sync1 & scl_sync2 & clk_scl_cntr == SETUP_TIME) begin //start setup margin
                        sda_o_r <= 1'b0;
                        state <= SLAVE_ADDR_WRITE;
                        bit_counter <= 4'd8;
                    end
                end

                SLAVE_ADDR_WRITE: begin //write slave address                   
                    if(bit_counter == 4'd0 && scl_negedge) begin
                        scl_low <= 1'b0;
                        sda_o_r <= 1'b0;
                        state <= ACK_WAIT;
                        //next_state <= (read_flag) ? READ : REG_ADDR_WRITE;
                        next_state <= (read_flag) ? READ_WAIT : REG_ADDR_WRITE;
                        bit_counter <= 4'd8;
                        slave_rw_r <= rw_mode_i ? {slave_addr_i, 1'b1} : slave_rw_r;
                    end else if(scl_negedge) begin
                        scl_low <= 1'b0;
                        sda_o_r <= slave_rw_r[bit_counter-1];
                        bit_counter <= bit_counter-1;
                    end
                end

                REG_ADDR_WRITE: begin //write register address(command)                   

                    if(bit_counter == 4'd0 && scl_negedge) begin
                            scl_low <= 1'b0;
                            sda_o_r <= 1'b0;
                            state <= ACK_WAIT;
                            //next_state <= rw_mode_i ? REPEATED_START : WRITE; //1: restart->read, 0: write
                            next_state <= rw_mode_i ? REPEATED_START : WRITE_WAIT; //1: restart->read, 0: write
                            bit_counter <= 4'd8;
                    end else if(scl_negedge) begin  
                        scl_low <= 1'b0;
                        sda_o_r <= reg_addr_r[bit_counter-1];
                        bit_counter <= bit_counter-1;
                    end
                end
                
                WRITE_WAIT: begin //wait write valid signal 
                    write_ready <= 1'b1;
                    if(write_ready & write_valid_i) begin
                        state <= WRITE;
                        wdata_r <= wdata_i;
                    end
                end

                WRITE: begin //write data to slave
                    if(bit_counter == 4'd0 && scl_negedge) begin
                        state <= ACK_WAIT;
                        next_state <= STOP;
                        bit_counter <= 4'd8;
                        sda_o_r <= 1'bz;
                        write_ready <= 1'b0;
                    end else if(scl_negedge) begin
                        sda_o_r <= wdata_r[bit_counter-1];
                        bit_counter <= bit_counter-1;
                    end
                end

                ACK_WAIT: begin //wait ack from slave
                    sda_o_r <= 1'bz;

                    if(scl_posedge) begin
                        scl_high <= 1'b0;
                        if(!sda_sync2) begin
                            state <= next_state;
                        end else begin
                            nack <= 1'b1;
                            state <= IDLE;
                            en_scl <= 1'b0;
                            sda_o_r <= 1'bz;
                            busy <= 1'b0;
                        end
                    end
                end

                REPEATED_START: begin //repeated start
                    if(scl_negedge) begin
                        sda_o_r <= 1'b1;
                    end else if(scl_posedge) begin
                        sda_o_r <= 1'b0;
                        state <= SLAVE_ADDR_WRITE;
                        read_flag <= 1;
                    end
                end
                
                READ_WAIT: begin //wait read valid signal
                    read_ready <= 1'b1;
                    if(read_ready & read_valid_i) begin
                        state <= READ;
                    end
                end

                READ: begin //read data from slave
                    if(bit_counter == 0 && scl_negedge) begin
                        state <= ACK_SEND;
                        valid_out <= 1'b1;
                        bit_counter <= 4'd8;
                    end else if(scl_posedge) begin  
                        scl_high <= 1'b0;
                        valid_out <= 1'b0;
                        data_out[bit_counter-1] <= sda_sync2;
                        bit_counter <= bit_counter - 1;
                    end
                end

                ACK_SEND: begin //send ack to slave
                    //already scl is low.
                    sda_o_r <= (byte_len_r == 1) ? 1'b1 : 1'b0; //ack or

                    if(scl_negedge) begin
                        sda_o_r <= (byte_len_r == 1) ? 1'b0 : 1'bz;
                        valid_out <= 1'b0;
                        byte_len_r <= byte_len_r - 1;
                        state <= (byte_len_r == 1) ? STOP : READ_WAIT; 
                    end
                end

                STOP: begin //stop condition
                    //initially, scl is high.
                    if(scl_negedge) begin 
                        sda_o_r <= 1'b0;
                    end 

                    if(scl_posedge) begin
                        sda_o_r <= 1'b1;
                        state <= RELEASE_BUS;
                    end
                end

                RELEASE_BUS: begin //release bus
                    if(clk_scl_cntr == HIGH_PIREOD_TIME - 3) begin //stop margin
                        en_scl <= 1'b0;
                        state <= IDLE;
                        sda_o_r <= 1'bz;
                        busy <= 1'b0;
                    end
                end

                default: state <= IDLE;
            endcase 
        end       
    end

endmodule