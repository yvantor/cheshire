##############################
# BOARD SPECIFIC CONSTRAINTS #
##############################

#############
# Sys clock #
#############

# 100 MHz ref clock
set SYS_TCK 10
create_clock -period $SYS_TCK -name sys_clk [get_pins u_ibufg_sys_clk/O]
set_property CLOCK_DEDICATED_ROUTE BACKBONE [get_pins u_ibufg_sys_clk/O]

#############
# Mig clock #
#############

# Dram axi clock : 750ps * 4
set MIG_TCK 3
create_generated_clock -source [get_pins i_dram_wrapper/i_dram/inst/u_ddr4_infrastructure/gen_mmcme4.u_mmcme_adv_inst/CLKOUT0] \
 -divide_by 1 -add -master_clock mmcm_clkout0 -name dram_axi_clk [get_pins i_dram_wrapper/i_dram/c0_ddr4_ui_clk]
# Aynch reset in
set MIG_RST_I [get_pin i_dram_wrapper/i_dram/inst/c0_ddr4_aresetn]
set_false_path -hold -setup -through $MIG_RST_I
# Synch reset out
set MIG_RST_O [get_pins i_dram_wrapper/i_dram/c0_ddr4_ui_clk_sync_rst]
set_false_path -hold -through $MIG_RST_O
set_max_delay -through $MIG_RST_O $MIG_TCK

########
# CDCs #
########

set_max_delay -datapath \
 -from [get_pins i_dram_wrapper/gen_cdc.i_axi_cdc_mig/i_axi_cdc_*/i_cdc_fifo_gray_*/*reg*/C] \
  -to [get_pins i_dram_wrapper/gen_cdc.i_axi_cdc_mig/i_axi_cdc_*/i_cdc_fifo_gray_*/*i_sync/reg*/D] $MIG_TCK

set_max_delay -datapath \
 -from [get_pins i_dram_wrapper/gen_cdc.i_axi_cdc_mig/i_axi_cdc_*/i_cdc_fifo_gray_*/*reg*/C] \
  -to [get_pins i_dram_wrapper/gen_cdc.i_axi_cdc_mig/i_axi_cdc_*/i_cdc_fifo_gray_*/i_spill_register/spill_register_flushable_i/*reg*/D] $MIG_TCK

#################################################################################

###############
# ASSIGN PINS #
###############

#  Based on
#  VCU128 Rev1.0 XDC
#  Date: 01/24/2018

set_property PACKAGE_PIN BP26     [get_ports "uart_rx_i"] ;# Bank  67 VCCO - VCC1V8   - IO_L2N_T0L_N3_67
set_property IOSTANDARD  LVCMOS18 [get_ports "uart_rx_i"] ;# Bank  67 VCCO - VCC1V8   - IO_L2N_T0L_N3_67
set_property PACKAGE_PIN BN26     [get_ports "uart_tx_o"] ;# Bank  67 VCCO - VCC1V8   - IO_L2P_T0L_N2_67
set_property IOSTANDARD  LVCMOS18 [get_ports "uart_tx_o"] ;# Bank  67 VCCO - VCC1V8   - IO_L2P_T0L_N2_67

set_property PACKAGE_PIN BM29 [get_ports cpu_reset]
set_property IOSTANDARD LVCMOS12 [get_ports cpu_reset]


set_property PACKAGE_PIN A23     [get_ports jtag_gnd_o] ;# A23 - C15 (FMCP_HSPC_LA10_N) - J1.04 - GND
set_property IOSTANDARD LVCMOS18 [get_ports jtag_gnd_o] ;

set_property PACKAGE_PIN B23     [get_ports jtag_vdd_o] ;# B23 - C14 (FMCP_HSPC_LA10_P) - J1.02 - VDD
set_property IOSTANDARD LVCMOS18 [get_ports jtag_vdd_o] ;

set_property PACKAGE_PIN B25     [get_ports jtag_tdo_o] ;# B25 - H17 (FMCP_HSPC_LA11_N) - J1.08 - TDO
set_property IOSTANDARD LVCMOS18 [get_ports jtag_tdo_o]

set_property PACKAGE_PIN B26     [get_ports jtag_tck_i] ;# B26 - H16 (FMCP_HSPC_LA11_P) - J1.06 - TCK
set_property IOSTANDARD LVCMOS18 [get_ports jtag_tck_i] ;

set_property PACKAGE_PIN H22     [get_ports jtag_tms_i] ;# H22 - G16 (FMCP_HSPC_LA12_N) - J1.12 - TNS
set_property IOSTANDARD LVCMOS18 [get_ports jtag_tms_i] ;

set_property PACKAGE_PIN J22     [get_ports jtag_tdi_i] ;# J22 - G15 (FMCP_HSPC_LA12_P) - J1.10 - TDI
set_property IOSTANDARD LVCMOS18 [get_ports jtag_tdi_i]

set_property PACKAGE_PIN AN1      [get_ports "pcie_rxn[3]"] ;# Bank 227 - MGTYRXN0_227 PCIE_EP_RX3_N
set_property PACKAGE_PIN AN5      [get_ports "pcie_rxn[2]"] ;# Bank 227 - MGTYRXN1_227 PCIE_EP_RX2_N
set_property PACKAGE_PIN AM3      [get_ports "pcie_rxn[1]"] ;# Bank 227 - MGTYRXN2_227 PCIE_EP_RX1_N
set_property PACKAGE_PIN AL1      [get_ports "pcie_rxn[0]"] ;# Bank 227 - MGTYRXN3_227 PCIE_EP_RX0_N
set_property PACKAGE_PIN AN2      [get_ports "pcie_rxp[3]"] ;# Bank 227 - MGTYRXP0_227 PCIE_EP_RX3_P
set_property PACKAGE_PIN AN6      [get_ports "pcie_rxp[2]"] ;# Bank 227 - MGTYRXP1_227 PCIE_EP_RX2_P
set_property PACKAGE_PIN AM4      [get_ports "pcie_rxp[1]"] ;# Bank 227 - MGTYRXP2_227 PCIE_EP_RX1_P
set_property PACKAGE_PIN AL2      [get_ports "pcie_rxp[0]"] ;# Bank 227 - MGTYRXP3_227 PCIE_EP_RX0_P
set_property PACKAGE_PIN AP8      [get_ports "pcie_txn[3]"] ;# Bank 227 - MGTYTXN0_227 PCIE_EP_TX3_N
set_property PACKAGE_PIN AN10     [get_ports "pcie_txn[2]"] ;# Bank 227 - MGTYTXN1_227 PCIE_EP_TX2_N
set_property PACKAGE_PIN AM8      [get_ports "pcie_txn[1]"] ;# Bank 227 - MGTYTXN2_227 PCIE_EP_TX1_N
set_property PACKAGE_PIN AL10     [get_ports "pcie_txn[0]"] ;# Bank 227 - MGTYTXN3_227 PCIE_EP_TX0_N
set_property PACKAGE_PIN AP9      [get_ports "pcie_txp[3]"] ;# Bank 227 - MGTYTXP0_227 PCIE_EP_TX3_P
set_property PACKAGE_PIN AN11     [get_ports "pcie_txp[2]"] ;# Bank 227 - MGTYTXP1_227 PCIE_EP_TX2_P
set_property PACKAGE_PIN AM9      [get_ports "pcie_txp[1]"] ;# Bank 227 - MGTYTXP2_227 PCIE_EP_TX1_P
set_property PACKAGE_PIN AL11     [get_ports "pcie_txp[0]"] ;# Bank 227 - MGTYTXP3_227 PCIE_EP_TX0_P

#set_property LOC [get_package_pins -filter {PIN_FUNC =~ *_PERSTN0_65}] [get_ports sys_rst_n]
set_property LOC [get_package_pins -of_objects [get_bels [get_sites -filter {NAME =~ *COMMON*} -of_objects [get_iobanks -of_objects [get_sites GTYE4_CHANNEL_X1Y15]]]/REFCLK0P]] [get_ports pcie_sys_clk_p]
set_property LOC [get_package_pins -of_objects [get_bels [get_sites -filter {NAME =~ *COMMON*} -of_objects [get_iobanks -of_objects [get_sites GTYE4_CHANNEL_X1Y15]]]/REFCLK0N]] [get_ports pcie_sys_clk_n]

set_property BOARD_PART_PIN default_100mhz_clk_n [get_ports sys_clk_n]
set_property IOSTANDARD DIFF_SSTL12 [get_ports sys_clk_n]
set_property BOARD_PART_PIN default_100mhz_clk_p [get_ports sys_clk_p]
set_property IOSTANDARD DIFF_SSTL12 [get_ports sys_clk_p]
set_property PACKAGE_PIN BH51 [get_ports sys_clk_p]
set_property PACKAGE_PIN BJ51 [get_ports sys_clk_n]