/******************************************************************************************/
/* robbit(Two-wheeled Self Balancing Car Project) since 2025-10 Copyright(c) 2025 Archlab. Science Tokyo /
/ Released under the MIT license https://opensource.org/licenses/mit           */
/******************************************************************************************/

module mmio_control (
    input  wire                        clk_i,
    input  wire                        rst_i,
    input  wire [1:0]                  button_i,
    input  wire  [31:0]                r_dmem_addr_i,
    input  wire                        dbus_we_i,
    input  wire [`DBUS_ADDR_WIDTH-1:0] dbus_addr_i,
    input  wire [`DBUS_DATA_WIDTH-1:0] dbus_wdata_i,
    output wire [31:0]                 w_mmio_data_o,
    output wire                        scl_io,
    `ifdef SYNTHESIS             
        inout  wire sda_io          // I2C Gyroscope sensor
    `else
        input  wire sda_io          // I2C Gyroscope sensor
    `endif   
);

`ifdef SYNTHESIS    
    wire [31:0] w_MPU_ayax, w_MPU_gxaz, w_MPU_gzgy;
    mpu6050 mpu6050(clk_i, rst_i, w_MPU_ayax, w_MPU_gxaz, w_MPU_gzgy, scl_io, sda_io);
`else
    wire [31:0] w_MPU_ayax = {16'd100, 16'd100};
    wire [31:0] w_MPU_gxaz = {16'd100, 16'd100};
    wire [31:0] w_MPU_gzgy = {16'd100, 16'd100};
`endif

    reg [31:0] r_MPU_ayax = 0;
    reg [31:0] r_MPU_gxaz = 0;
    reg [31:0] r_MPU_gzgy = 0;
    always@(posedge clk_i) begin
        r_MPU_ayax <= w_MPU_ayax;
        r_MPU_gxaz <= w_MPU_gxaz;
        r_MPU_gzgy <= w_MPU_gzgy;
    end

    reg [31:0] r_timer_cnt = 1;
    reg [31:0] r_timer = 0;
    always@(posedge clk_i) begin
        r_timer_cnt <= (r_timer_cnt==(`CLK_FREQ_MHZ*10)) ? 1 : r_timer_cnt + 1;
        if(r_timer_cnt==1) r_timer <= r_timer + 1;
    end

////check button pushing
    reg [31:0] r_button = 0;
    always @(posedge clk_i) begin
        r_button <= {30'd0, button_i[1:0]};
    end

    assign w_mmio_data_o =    (r_dmem_addr_i[7:0]==8'h00) ? r_MPU_ayax :
                              (r_dmem_addr_i[7:0]==8'h04) ? r_MPU_gxaz :
                              (r_dmem_addr_i[7:0]==8'h08) ? r_MPU_gzgy :
                              (r_dmem_addr_i[7:0]==8'h10) ? r_timer    :
                              (r_dmem_addr_i[7:0]==8'h44) ? r_button   : 0;

endmodule

/******************************************************************************************/
// (0,0) stop, (0,1) normal rotation, (1,0) reverse rotation, (1,1) brake
/******************************************************************************************/
module tb6612fng (
    input  wire         clk_i,    
    input  wire         we_i,     // dbus_addr==32'h3000_0040 & dbus_we
    input  wire [31:0]  ctrl_i,   // in1, in2, duty[7:0]
    output wire         stby_o,   // after cnt == 0x0100_0000 , high
    output wire         in1_o,    //
    output wire         in2_o,    //
    output wire         pwm_o     
);

    reg [31:0] r_motor_ctrl = 0;
    always@(posedge clk_i) begin
        if (we_i) r_motor_ctrl <= ctrl_i;
    end
    assign in1_o  = r_motor_ctrl[17];
    assign in2_o  = r_motor_ctrl[16];

    reg [31:0] r_cnt = 0;
    always@(posedge clk_i) r_cnt <= r_cnt + 1;

    reg r_motor_stby = 0;
    always@(posedge clk_i) if(r_cnt[27]) r_motor_stby <= 1;
    assign stby_o = r_motor_stby;

    // clk_i mhz / 2048 cycle < 100khz 
    wire [10:0] dutyx8 = {r_motor_ctrl[7:0], 3'b111};
    assign pwm_o  = (r_cnt[10:0] <= dutyx8);
    
endmodule

`resetall