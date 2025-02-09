
########################### Define Top Module ############################
                                                   
set top_module PL_TOP

##################### Define Working Library Directory ######################
                                                   
define_design_lib work -path ./work

############################# Formality Setup File ##########################
                                                   
set_svf $top_module.svf

################## Design Compiler Library Files #setup ######################

puts "###########################################"
puts "#      #setting Design Libraries          #"
puts "###########################################"

#Add the path of the libraries and RTL files to the search_path variable

set PROJECT_PATH /home/IC/RX_PCIE
set LIB_PATH     /home/IC/tsmc_fb_cl013g_sc/aci/sc-m

lappend search_path $LIB_PATH/synopsys
lappend search_path $PROJECT_PATH/RTL 

set SSLIB "scmetro_tsmc_cl013g_rvt_ss_1p08v_125c.db"
set TTLIB "scmetro_tsmc_cl013g_rvt_tt_1p2v_25c.db"
set FFLIB "scmetro_tsmc_cl013g_rvt_ff_1p32v_m40c.db"

## Standard Cell libraries 
set target_library [list $SSLIB $TTLIB $FFLIB]

## Standard Cell & Hard Macros libraries 
set link_library [list * $SSLIB $TTLIB $FFLIB]  

######################## Reading RTL Files #################################

puts "###########################################"
puts "#             Reading RTL Files           #"
puts "###########################################"

set file_format sverilog


analyze -format $file_format BA_counters.sv
analyze -format $file_format BA_flag_genarator.sv
analyze -format $file_format BA_FSM.sv
analyze -format $file_format BA_TOP.sv
analyze -format $file_format Block_Type_Logic.sv
analyze -format $file_format Byte_unstripping.sv
analyze -format $file_format Counter.sv
analyze -format $file_format Descrambler.sv
analyze -format $file_format elstc_buff_TOP.sv
analyze -format $file_format Filtering_Buffer.sv
analyze -format $file_format Frame_Checker.sv
analyze -format $file_format lane_control.sv
analyze -format $file_format lane_deskew.sv
analyze -format $file_format Descrambler_Controler.sv
analyze -format $file_format Packet_Filter_fsm.sv
analyze -format $file_format Packet_Filter_TOP.sv
analyze -format $file_format PHY_RX.sv
analyze -format $file_format PIPE_Counter.sv
analyze -format $file_format PIPE_Counter_pipe.sv
analyze -format $file_format read_proc_and_ptr_genr.sv
analyze -format $file_format Rx_Buffer.sv
analyze -format $file_format RX_TOP.sv
analyze -format $file_format storage_unit.sv
analyze -format $file_format dff_sync2.sv
analyze -format $file_format top_RX.sv
analyze -format $file_format wptr_generation.sv
analyze -format $file_format write_processor.sv
analyze -format $file_format LFSR_8_gen3.sv
analyze -format $file_format LFSR_8.sv
analyze -format $file_format decoder.sv
analyze -format $file_format LTSSM.sv
analyze -format $file_format LTSSM_TOP.sv
analyze -format $file_format OS_CREATOR.sv
analyze -format $file_format Timer.sv
analyze -format $file_format Counter.sv
analyze -format $file_format DC_Balance.sv
analyze -format $file_format Framing_Buffer.sv
analyze -format $file_format Framing_fsm_one_lane.sv
analyze -format $file_format Framing_fsm.sv
analyze -format $file_format Gen3_Top.sv
analyze -format $file_format OR_Gate.sv
analyze -format $file_format PHY_TX.sv
analyze -format $file_format scrambler_and_sync.sv
analyze -format $file_format Scrambler_Controler.sv
analyze -format $file_format Scrambler.sv
analyze -format $file_format Sync_Logic.sv
analyze -format $file_format tokens.sv
analyze -format $file_format Interface_Buffer.sv
analyze -format $file_format Tx_Framing.sv
analyze -format $file_format TX_TOP.sv
analyze -format $file_format PL_TOP.sv
analyze -format $file_format phy_top.sv
analyze -format $file_format IDLE_Counter.sv
analyze -format $file_format SKP_Counter.sv

elaborate -lib WORK PL_TOP

###################### Defining toplevel ###################################

current_design $top_module

#################### Liniking All The Design Parts #########################
puts "###############################################"
puts "######## Liniking All The Design Parts ########"
puts "###############################################"

link 

#################### Liniking All The Design Parts #########################
puts "###############################################"
puts "######## checking design consistency ##########"
puts "###############################################"

check_design >> reports/check_design.rpt

#################### Define Design Constraints #########################
puts "###############################################"
puts "############ Design Constraints #### ##########"
puts "###############################################"

source -echo ./cons.tcl

###################### Mapping and optimization ########################
puts "###############################################"
puts "########## Mapping & Optimization #############"
puts "###############################################"

compile -map_effort medium

##################### Close Formality Setup file ###########################

set_svf -off

#############################################################################
# Write out files
#############################################################################

write_file -format ddc -hierarchy -output netlists/$top_module.ddc
write_file -format verilog -hierarchy -output netlists/$top_module.v
write_sdf  sdf/$top_module.sdf
write_sdc  -nosplit sdc/$top_module.sdc

####################### reporting ##########################################

report_area -hierarchy > reports/area.rpt
report_power -hierarchy > reports/power.rpt
report_timing -delay_type min -max_paths 20 > reports/hold.rpt
report_timing -delay_type max -max_paths 20 > reports/setup.rpt
report_clock -attributes > reports/clocks.rpt
report_constraint -all_violators -nosplit > reports/constraints.rpt



################# starting graphical user interface #######################

#gui_start

#exit
