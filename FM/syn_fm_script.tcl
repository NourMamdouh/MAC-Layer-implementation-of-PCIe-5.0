
############################  Search PATH ################################
set PROJECT_PATH /home/IC/RX_PCIE

lappend search_path /home/IC/tsmc_fb_cl013g_sc/aci/sc-m/synopsys
lappend search_path $PROJECT_PATH/RTL
lappend search_path $PROJECT_PATH/syn

########################### Define Top Module ############################
                                                   
set top_module PL_TOP

######################### Formality Setup File ###########################

set synopsys_auto_setup true

set_svf "/home/IC/RX_PCIE/Syn/PL_TOP.svf"

####################### Read Reference tech libs ########################
 

set SSLIB "/home/IC/tsmc_fb_cl013g_sc/aci/sc-m/synopsys/scmetro_tsmc_cl013g_rvt_ss_1p08v_125c.db"
set TTLIB "/home/IC/tsmc_fb_cl013g_sc/aci/sc-m/synopsys/scmetro_tsmc_cl013g_rvt_tt_1p2v_25c.db"
set FFLIB "/home/IC/tsmc_fb_cl013g_sc/aci/sc-m/synopsys/scmetro_tsmc_cl013g_rvt_ff_1p32v_m40c.db"

read_db -container Ref [list $SSLIB $TTLIB $FFLIB]

###################  Read Reference Design Files ######################## 

read_sverilog -container Ref "BA_counters.sv"
read_sverilog -container Ref "BA_flag_genarator.sv"
read_sverilog -container Ref "BA_FSM.sv"
read_sverilog -container Ref "BA_TOP.sv"
read_sverilog -container Ref "Block_Type_Logic.sv"
read_sverilog -container Ref "Counter.sv"
read_sverilog -container Ref "Descrambler.sv"
read_sverilog -container Ref "elstc_buff_TOP.sv"
read_sverilog -container Ref "Filtering_Buffer.sv"
read_sverilog -container Ref "Frame_Checker.sv"
read_sverilog -container Ref "lane_control.sv"
read_sverilog -container Ref "lane_deskew.sv"
read_sverilog -container Ref "Descrambler_Controler.sv"
read_sverilog -container Ref "Packet_Filter_fsm.sv"
read_sverilog -container Ref "Packet_Filter_TOP.sv"
read_sverilog -container Ref "PHY_RX.sv"
read_sverilog -container Ref "PIPE_Counter.sv"
read_sverilog -container Ref "PIPE_Counter_pipe.sv"
read_sverilog -container Ref "read_proc_and_ptr_genr.sv"
read_sverilog -container Ref "Rx_Buffer.sv"
read_sverilog -container Ref "RX_TOP.sv"
read_sverilog -container Ref "storage_unit.sv"
read_sverilog -container Ref "dff_sync2.sv"
read_sverilog -container Ref "top_RX.sv"
read_sverilog -container Ref "wptr_generation.sv"
read_sverilog -container Ref "write_processor.sv"
read_sverilog -container Ref "LFSR_8_gen3.sv"
read_sverilog -container Ref "LFSR_8.sv"
read_sverilog -container Ref "decoder.sv"
read_sverilog -container Ref "LTSSM.sv"
read_sverilog -container Ref "LTSSM_TOP.sv"
read_sverilog -container Ref "OS_CREATOR.sv"
read_sverilog -container Ref "Timer.sv"
read_sverilog -container Ref "DC_Balance.sv"
read_sverilog -container Ref "Framing_Buffer.sv"
read_sverilog -container Ref "Framing_fsm_one_lane.sv"
read_sverilog -container Ref "Framing_fsm.sv"
read_sverilog -container Ref "Gen3_Top.sv"
read_sverilog -container Ref "OR_Gate.sv"
read_sverilog -container Ref "PHY_TX.sv"
read_sverilog -container Ref "scrambler_and_sync.sv"
read_sverilog -container Ref "Scrambler_Controler.sv"
read_sverilog -container Ref "Scrambler.sv"
read_sverilog -container Ref "Sync_Logic.sv"
read_sverilog -container Ref "tokens.sv"
read_sverilog -container Ref "Interface_Buffer.sv"
read_sverilog -container Ref "Tx_Framing.sv"
read_sverilog -container Ref "TX_TOP.sv"
read_sverilog -container Ref "PL_TOP.sv"
read_sverilog -container Ref "phy_top.sv"
read_sverilog -container Ref "IDLE_Counter.sv"
read_sverilog -container Ref "SKP_Counter.sv"

######################## set the top Reference Design ######################## 

set_reference_design PL_TOP
set_top PL_TOP

####################### Read Implementation tech libs ######################## 

read_db -container Imp [list $SSLIB $TTLIB $FFLIB]

#################### Read Implementation Design Files ######################## 

read_verilog -container Imp -netlist "/home/IC/RX_PCIE/Syn/netlists/PL_TOP.v"

####################  set the top Implementation Design ######################

set_implementation_design PL_TOP
set_top PL_TOP


## matching Compare points
match

## verify
set successful [verify]
if {!$successful} {
diagnose
analyze_points -failing
}

report_passing_points > "reports/passing_points.rpt"
report_failing_points > "reports/failing_points.rpt"
report_aborted_points > "reports/aborted_points.rpt"
report_unverified_points > "reports/unverified_points.rpt"


start_gui
