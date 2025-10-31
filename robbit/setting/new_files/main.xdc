###############################################################################################
## main.xdc for Cmod A7-35T    ArchLab, Institute of Science Tokyo / Tokyo Tech
## CFU Proving Ground since 2025-02    Copyright(c) 2025 Archlab. Science Tokyo
## Released under the MIT license https://opensource.org/licenses/mit
## FPGA: XC7A35T-1CPG236C
###############################################################################################

## binary compression
set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]
set_property BITSTREAM.CONFIG.CONFIGRATE 50 [current_design]
set_property CONFIG_MODE SPIx4 [current_design]

## 12MHz system clock
###############################################################################################
set_property -dict {PACKAGE_PIN L17 IOSTANDARD LVCMOS33} [get_ports clk_i]
create_clock -period 83.330 -name sys_clk -add [get_ports clk_i]

###############################################################################################

##### 240x240 ST7789 mini display #####
###############################################################################################
## Pmod Header JA
set_property -dict {PACKAGE_PIN W6 IOSTANDARD LVCMOS33} [get_ports st7789_DC]
set_property -dict {PACKAGE_PIN U3 IOSTANDARD LVCMOS33} [get_ports st7789_RES]
set_property -dict {PACKAGE_PIN U7 IOSTANDARD LVCMOS33} [get_ports st7789_SDA]
set_property -dict {PACKAGE_PIN W7 IOSTANDARD LVCMOS33} [get_ports st7789_SCL]

###### Pmod Header for MPU-6050
###### Pin 3 and Pin 4
set_property PACKAGE_PIN J19 [get_ports sda]
set_property IOSTANDARD LVCMOS33 [get_ports sda]
set_property PULLTYPE PULLUP [get_ports sda]
set_property PACKAGE_PIN K18 [get_ports scl]
set_property IOSTANDARD LVCMOS33 [get_ports scl]
set_property PULLTYPE PULLUP [get_ports scl]


###############################################################################################
##### GPIO for Motor driver
set_property -dict {PACKAGE_PIN T1 IOSTANDARD LVCMOS33} [get_ports motor_stby]
set_property -dict {PACKAGE_PIN T2 IOSTANDARD LVCMOS33} [get_ports motor_ain1]
set_property -dict {PACKAGE_PIN U1 IOSTANDARD LVCMOS33} [get_ports motor_ain2]
set_property -dict {PACKAGE_PIN W2 IOSTANDARD LVCMOS33} [get_ports motor_pwma]
###############################################################################################

###############################################################################################
###### LED, BUTTON
set_property -dict {PACKAGE_PIN A18 IOSTANDARD LVCMOS33} [get_ports {button[0]}]
set_property -dict {PACKAGE_PIN B18 IOSTANDARD LVCMOS33} [get_ports {button[1]}]
## set_property -dict {PACKAGE_PIN A17 IOSTANDARD LVCMOS33} [get_ports {led[0]}]
## set_property -dict {PACKAGE_PIN C16 IOSTANDARD LVCMOS33} [get_ports {led[1]}]

#####
create_pblock PB0
resize_pblock [get_pblocks PB0] -add SLICE_X36Y50:SLICE_X65Y74
add_cells_to_pblock [get_pblocks PB0] [get_cells -quiet [list {cpu}]]
## add_cells_to_pblock [get_pblocks PB0] [get_cells -quiet [list {imem}]]
## add_cells_to_pblock [get_pblocks PB0] [get_cells -quiet [list {dmem}]]
## resize_pblock [get_pblocks PB0] -add CLOCKREGION_X1Y1

#####
create_pblock PB1
resize_pblock [get_pblocks PB1] -add CLOCKREGION_X1Y1
add_cells_to_pblock [get_pblocks PB1] [get_cells -quiet [list {imem}]]
add_cells_to_pblock [get_pblocks PB1] [get_cells -quiet [list {dmem}]]