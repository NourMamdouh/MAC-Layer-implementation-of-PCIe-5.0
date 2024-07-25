# Constraints
# ----------------------------------------------------------------------------
# 1. Master Clock Definitions
# 2. Generated Clock Definitions
# 3. Clock Uncertainties
# 4. Clock Latencies 
# 5. Clock Relationships
# 6. set input/output delay on ports
# 7. Driving cells
# 8. Output load

####################################################################################
           #########################################################
                  #### Section 0 : DC Variables ####
           #########################################################
#################################################################################### 

# Prevent assign statements in the generated netlist (must be applied before compile command)
set_fix_multiple_port_nets -all -buffer_constants -feedthroughs


####################################################################################
                  #### Section 1 : Clock Definition ####
#################################################################################### 
# 1. Master Clock Definitions 
# 2. Generated Clock Definitions
# 3. Clock Latencies
# 4. Clock Uncertainties
# 5. Clock Transitions
####################################################################################

set CLK_NAME clk
set CLK_PER 7
set CLK_SETUP_SKEW 0.2
set CLK_HOLD_SKEW 0.1
set CLK_LAT 0
set CLK_RISE 0.05
set CLK_FALL 0.05

create_clock -name $CLK_NAME -period $CLK_PER -waveform "0 [expr $CLK_PER/2]" [get_ports clk]
set_clock_uncertainty -setup $CLK_SETUP_SKEW [get_clocks $CLK_NAME]
set_clock_uncertainty -hold $CLK_HOLD_SKEW  [get_clocks $CLK_NAME]
set_clock_transition -rise $CLK_RISE  [get_clocks $CLK_NAME]
set_clock_transition -fall $CLK_FALL  [get_clocks $CLK_NAME]
set_clock_latency $CLK_LAT [get_clocks $CLK_NAME]		   
					   
set_dont_touch_network {clk rst}


####################################################################################
             #### Section 2 : set input/output delay on ports ####
####################################################################################

set in_delay  [expr 0.2*$CLK_PER]
set out_delay [expr 0.2*$CLK_PER]

#Constrain Input Paths
set_input_delay $in_delay -clock $CLK_NAME [get_port rst]

## -------- INPUTS from PIPE --------
set_input_delay $in_delay -clock $CLK_NAME [get_port valid_lower_gen]
set_input_delay $in_delay -clock $CLK_NAME [get_port PIPE_d_K]
set_input_delay $in_delay -clock $CLK_NAME [get_port RX_Data_Valid]
set_input_delay $in_delay -clock $CLK_NAME [get_port RX_Start_Block]
set_input_delay $in_delay -clock $CLK_NAME [get_port RX_SYNC_Header]
set_input_delay $in_delay -clock $CLK_NAME [get_port I_Rcv_Deteted]
set_input_delay $in_delay -clock $CLK_NAME [get_port I_RX_EIdle]
set_input_delay $in_delay -clock $CLK_NAME [get_port I_PhyStatus]

## ------ Outputs to PIPE ----------
set_output_delay $out_delay -clock $CLK_NAME [get_port O_St_Detect]
set_output_delay $out_delay -clock $CLK_NAME [get_port TxStartBlock]
set_output_delay $out_delay -clock $CLK_NAME [get_port TxSyncHeader]
set_output_delay $out_delay -clock $CLK_NAME [get_port powerDown_PIPE]
set_output_delay $out_delay -clock $CLK_NAME [get_port O_rate]
set_output_delay $out_delay -clock $CLK_NAME [get_port TxElecIdle_PIPE]
set_output_delay $out_delay  -clock $CLK_NAME [get_port o_PIPE_rst]
set_output_delay $out_delay  -clock $CLK_NAME [get_port o_K_PIPE]

#############################################################
          #### Section 3 : Driving cells ####
#############################################################

set_driving_cell -library scmetro_tsmc_cl013g_rvt_ss_1p08v_125c -lib_cell BUFX2M -pin Y [get_port valid_lower_gen]
set_driving_cell -library scmetro_tsmc_cl013g_rvt_ss_1p08v_125c -lib_cell BUFX2M -pin Y [get_port PIPE_d_K]
set_driving_cell -library scmetro_tsmc_cl013g_rvt_ss_1p08v_125c -lib_cell BUFX2M -pin Y [get_port RX_Data_Valid]
set_driving_cell -library scmetro_tsmc_cl013g_rvt_ss_1p08v_125c -lib_cell BUFX2M -pin Y [get_port RX_Start_Block]
set_driving_cell -library scmetro_tsmc_cl013g_rvt_ss_1p08v_125c -lib_cell BUFX2M -pin Y [get_port RX_SYNC_Header]
set_driving_cell -library scmetro_tsmc_cl013g_rvt_ss_1p08v_125c -lib_cell BUFX2M -pin Y [get_port I_Rcv_Deteted]
set_driving_cell -library scmetro_tsmc_cl013g_rvt_ss_1p08v_125c -lib_cell BUFX2M -pin Y [get_port I_RX_EIdle]
set_driving_cell -library scmetro_tsmc_cl013g_rvt_ss_1p08v_125c -lib_cell BUFX2M -pin Y [get_port I_PhyStatus]

####################################################################################
                  #### Section 4 : Output load ####
####################################################################################
set REG_LOAD 0.5

set_load $REG_LOAD [get_port TxStartBlock]
set_load $REG_LOAD [get_port TxSyncHeader]
set_load $REG_LOAD [get_port O_St_Detect]
set_load $REG_LOAD [get_port powerDown_PIPE]
set_load $REG_LOAD [get_port O_rate]
set_load $REG_LOAD [get_port TxElecIdle_PIPE]
set_load $REG_LOAD [get_port o_PIPE_rst]
set_load $REG_LOAD [get_port o_K_PIPE]

####################################################################################
           #########################################################
                 #### Section 6 : Operating Condition ####
           #########################################################
####################################################################################

# Define the Worst Library for Max(#setup) analysis
# Define the Best Library for Min(hold) analysis

set_operating_conditions -min_library "scmetro_tsmc_cl013g_rvt_ff_1p32v_m40c" -min "scmetro_tsmc_cl013g_rvt_ff_1p32v_m40c" -max_library "scmetro_tsmc_cl013g_rvt_ss_1p08v_125c" -max "scmetro_tsmc_cl013g_rvt_ss_1p08v_125c"

####################################################################################
           #########################################################
                  #### Section 7 : wireload Model ####
           #########################################################
####################################################################################

#set_wire_load_model -name tsmc13_wl30 -library scmetro_tsmc_cl013g_rvt_ss_1p08v_125c

####################################################################################


