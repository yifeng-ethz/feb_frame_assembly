
##################################################################################
# feb_frame_assembly "FEB (Front-end Board) Frame Assembly" v1.0
# Yifeng Wang 2024.08.11.16:06:38
# This IP is generates the Mu3e standard data frame given input of sub-frames.
###################################################################################

################################################
# History 
################################################
# 25.0.0221 - add debug_ts interface 
# 25.0.0225 - handle cdc for csr read
# 25.0.0306 - add debug_burst interface
# 25.0.0324 - add docu.
# 25.0.0505 - use pipeline search 

################################################
# request TCL package from ACDS 16.1
################################################
package require qsys


################################################
# module feb_frame_assembly
################################################
set_module_property DESCRIPTION "Generates the Mu3e standard data frame given input of sub-frames of multiple ring-CAM(s)"
set_module_property NAME feb_frame_assembly
set_module_property VERSION 25.0.0505
set_module_property INTERNAL false
set_module_property OPAQUE_ADDRESS_MAP true
set_module_property GROUP "Mu3e Data Plane/Modules"
set_module_property AUTHOR "Yifeng Wang"
set_module_property DISPLAY_NAME "FEB (Front-end Board) Frame Assembly"
set_module_property INSTANTIATE_IN_SYSTEM_MODULE true
set_module_property EDITABLE true
set_module_property REPORT_TO_TALKBACK false
set_module_property ALLOW_GREYBOX_GENERATION false
set_module_property REPORT_HIERARCHY false


################################################
# file sets
################################################ 
add_fileset QUARTUS_SYNTH QUARTUS_SYNTH "" ""
set_fileset_property QUARTUS_SYNTH TOP_LEVEL feb_frame_assembly
set_fileset_property QUARTUS_SYNTH ENABLE_RELATIVE_INCLUDE_PATHS false
set_fileset_property QUARTUS_SYNTH ENABLE_FILE_OVERWRITE_MODE false
add_fileset_file feb_frame_assembly.vhd VHDL PATH feb_frame_assembly.vhd TOP_LEVEL_FILE
# +---------------------+
# | the sub frame fifos |
# +---------------------+
add_fileset_file alt_dcfifo_w40d256.vhd VHDL PATH alt_fifos/alt_dcfifo_w40d256/alt_dcfifo_w40d256.vhd
# +----------------------+
# |  the sync gts (d->x) |
# +----------------------+
add_fileset_file alt_dcfifo_w48d4.vhd VHDL PATH alt_fifos/alt_dcfifo_w48d4/alt_dcfifo_w48d4.vhd
# +--------------+
# | the log fifo |
# +--------------+
add_fileset_file alt_scfifo_w40d8.vhd VHDL PATH alt_fifos/alt_scfifo_w40d8/alt_scfifo_w40d8.vhd
# +---------------------+
# | the main frame fifo |
# +---------------------+
add_fileset_file main_fifo.vhd VHDL PATH alt_fifos/main_fifo/main_fifo.vhd
# +-----------------+
# | the adder (csr) |
# +-----------------+
add_fileset_file alt_parallel_add.vhd VHDL PATH alt_lpm/alt_parallel_add.vhd
# +--------------------+
# | search for extreme |
# +--------------------+
add_fileset_file search_for_extreme.vhd VHDL PATH ./search_for_extreme.vhd

################################################
# parameters
################################################
add_parameter INTERLEAVING_FACTOR NATURAL 4
set_parameter_property INTERLEAVING_FACTOR DEFAULT_VALUE 4
set_parameter_property INTERLEAVING_FACTOR DISPLAY_NAME "Interleaving factor"
set_parameter_property INTERLEAVING_FACTOR TYPE NATURAL
set_parameter_property INTERLEAVING_FACTOR UNITS None
set_parameter_property INTERLEAVING_FACTOR ALLOWED_RANGES 1:16
set_parameter_property INTERLEAVING_FACTOR HDL_PARAMETER true
set dscpt \
"<html>
Set interleaving factor according to the upstream entity (ring-CAM complex). <br>
You can set it to 1, if interleaving is not enabled in upstream. <br>
This affects the stall time and latency of the output main frame, so you have to tune it with best of your knowledge. 
</html>"
set_parameter_property INTERLEAVING_FACTOR LONG_DESCRIPTION $dscpt
set_parameter_property INTERLEAVING_FACTOR DESCRIPTION $dscpt


add_parameter DEBUG NATURAL 1
set_parameter_property DEBUG DEFAULT_VALUE 1
set_parameter_property DEBUG DISPLAY_NAME "Debug Level"
set_parameter_property DEBUG TYPE NATURAL
set_parameter_property DEBUG UNITS None
set_parameter_property DEBUG ALLOWED_RANGES {0 1 2}
set_parameter_property DEBUG HDL_PARAMETER true
set dscpt \
"<html>
Select the debug level of the IP (affects generation).<br>
<ul>
	<li><b>0</b> : off <br> </li>
	<li><b>1</b> : on, synthesizble <br> </li>
	<li><b>2</b> : on, non-synthesizble, simulation-only <br> </li>
</ul>
</html>"
set_parameter_property DEBUG LONG_DESCRIPTION $dscpt
set_parameter_property DEBUG DESCRIPTION $dscpt

# 
# display items
# 


# 
# connection point hit_type2_0
# 
add_interface hit_type2_0 avalon_streaming end
set_interface_property hit_type2_0 associatedClock datapath_clock
set_interface_property hit_type2_0 associatedReset datapath_reset
set_interface_property hit_type2_0 dataBitsPerSymbol 36
set_interface_property hit_type2_0 errorDescriptor {"tsglitcherr"}
set_interface_property hit_type2_0 firstSymbolInHighOrderBits true
set_interface_property hit_type2_0 maxChannel 15
set_interface_property hit_type2_0 readyLatency 0
set_interface_property hit_type2_0 ENABLED true
set_interface_property hit_type2_0 EXPORT_OF ""
set_interface_property hit_type2_0 PORT_NAME_MAP ""
set_interface_property hit_type2_0 CMSIS_SVD_VARIABLES ""
set_interface_property hit_type2_0 SVD_ADDRESS_GROUP ""

add_interface_port hit_type2_0 asi_hit_type2_0_channel channel Input 4
add_interface_port hit_type2_0 asi_hit_type2_0_startofpacket startofpacket Input 1
add_interface_port hit_type2_0 asi_hit_type2_0_endofpacket endofpacket Input 1
add_interface_port hit_type2_0 asi_hit_type2_0_data data Input 36
add_interface_port hit_type2_0 asi_hit_type2_0_valid valid Input 1
add_interface_port hit_type2_0 asi_hit_type2_0_ready ready Output 1
add_interface_port hit_type2_0 asi_hit_type2_0_error error Input 1


# 
# connection point hit_type2_1
# 
add_interface hit_type2_1 avalon_streaming end
set_interface_property hit_type2_1 associatedClock datapath_clock
set_interface_property hit_type2_1 associatedReset datapath_reset
set_interface_property hit_type2_1 dataBitsPerSymbol 36
set_interface_property hit_type2_1 errorDescriptor {"tsglitcherr"}
set_interface_property hit_type2_1 firstSymbolInHighOrderBits true
set_interface_property hit_type2_1 maxChannel 15
set_interface_property hit_type2_1 readyLatency 0
set_interface_property hit_type2_1 ENABLED true
set_interface_property hit_type2_1 EXPORT_OF ""
set_interface_property hit_type2_1 PORT_NAME_MAP ""
set_interface_property hit_type2_1 CMSIS_SVD_VARIABLES ""
set_interface_property hit_type2_1 SVD_ADDRESS_GROUP ""

add_interface_port hit_type2_1 asi_hit_type2_1_channel channel Input 4
add_interface_port hit_type2_1 asi_hit_type2_1_startofpacket startofpacket Input 1
add_interface_port hit_type2_1 asi_hit_type2_1_endofpacket endofpacket Input 1
add_interface_port hit_type2_1 asi_hit_type2_1_data data Input 36
add_interface_port hit_type2_1 asi_hit_type2_1_valid valid Input 1
add_interface_port hit_type2_1 asi_hit_type2_1_ready ready Output 1
add_interface_port hit_type2_1 asi_hit_type2_1_error error Input 1


# 
# connection point hit_type2_2
# 
add_interface hit_type2_2 avalon_streaming end
set_interface_property hit_type2_2 associatedClock datapath_clock
set_interface_property hit_type2_2 associatedReset datapath_reset
set_interface_property hit_type2_2 dataBitsPerSymbol 36
set_interface_property hit_type2_2 errorDescriptor {"tsglitcherr"}
set_interface_property hit_type2_2 firstSymbolInHighOrderBits true
set_interface_property hit_type2_2 maxChannel 15
set_interface_property hit_type2_2 readyLatency 0
set_interface_property hit_type2_2 ENABLED true
set_interface_property hit_type2_2 EXPORT_OF ""
set_interface_property hit_type2_2 PORT_NAME_MAP ""
set_interface_property hit_type2_2 CMSIS_SVD_VARIABLES ""
set_interface_property hit_type2_2 SVD_ADDRESS_GROUP ""

add_interface_port hit_type2_2 asi_hit_type2_2_channel channel Input 4
add_interface_port hit_type2_2 asi_hit_type2_2_startofpacket startofpacket Input 1
add_interface_port hit_type2_2 asi_hit_type2_2_endofpacket endofpacket Input 1
add_interface_port hit_type2_2 asi_hit_type2_2_data data Input 36
add_interface_port hit_type2_2 asi_hit_type2_2_valid valid Input 1
add_interface_port hit_type2_2 asi_hit_type2_2_ready ready Output 1
add_interface_port hit_type2_2 asi_hit_type2_2_error error Input 1


# 
# connection point hit_type2_3
# 
add_interface hit_type2_3 avalon_streaming end
set_interface_property hit_type2_3 associatedClock datapath_clock
set_interface_property hit_type2_3 associatedReset datapath_reset
set_interface_property hit_type2_3 dataBitsPerSymbol 36
set_interface_property hit_type2_3 errorDescriptor {"tsglitcherr"}
set_interface_property hit_type2_3 firstSymbolInHighOrderBits true
set_interface_property hit_type2_3 maxChannel 15
set_interface_property hit_type2_3 readyLatency 0
set_interface_property hit_type2_3 ENABLED true
set_interface_property hit_type2_3 EXPORT_OF ""
set_interface_property hit_type2_3 PORT_NAME_MAP ""
set_interface_property hit_type2_3 CMSIS_SVD_VARIABLES ""
set_interface_property hit_type2_3 SVD_ADDRESS_GROUP ""

add_interface_port hit_type2_3 asi_hit_type2_3_channel channel Input 4
add_interface_port hit_type2_3 asi_hit_type2_3_startofpacket startofpacket Input 1
add_interface_port hit_type2_3 asi_hit_type2_3_endofpacket endofpacket Input 1
add_interface_port hit_type2_3 asi_hit_type2_3_data data Input 36
add_interface_port hit_type2_3 asi_hit_type2_3_valid valid Input 1
add_interface_port hit_type2_3 asi_hit_type2_3_ready ready Output 1
add_interface_port hit_type2_3 asi_hit_type2_3_error error Input 1


# 
# connection point hit_type3
# 
add_interface hit_type3 avalon_streaming start
set_interface_property hit_type3 associatedClock xcvr_clock
set_interface_property hit_type3 associatedReset xcvr_reset
set_interface_property hit_type3 dataBitsPerSymbol 36

add_interface_port hit_type3 aso_hit_type3_data data Output 36
add_interface_port hit_type3 aso_hit_type3_valid valid Output 1
add_interface_port hit_type3 aso_hit_type3_ready ready Input 1
add_interface_port hit_type3 aso_hit_type3_startofpacket startofpacket Output 1
add_interface_port hit_type3 aso_hit_type3_endofpacket endofpacket Output 1

# 
# connection point ctrl_datapath
# 
add_interface ctrl_datapath avalon_streaming end 
set_interface_property ctrl_datapath associatedClock datapath_clock
set_interface_property ctrl_datapath associatedReset datapath_reset
set_interface_property ctrl_datapath dataBitsPerSymbol 9

add_interface_port ctrl_datapath asi_ctrl_datapath_data data Input 9
add_interface_port ctrl_datapath asi_ctrl_datapath_valid valid Input 1
add_interface_port ctrl_datapath asi_ctrl_datapath_ready ready Output 1

# 
# connection point ctrl_xcvr
# 
add_interface ctrl_xcvr avalon_streaming end 
set_interface_property ctrl_xcvr associatedClock xcvr_clock
set_interface_property ctrl_xcvr associatedReset xcvr_reset
set_interface_property ctrl_xcvr dataBitsPerSymbol 9

add_interface_port ctrl_xcvr asi_ctrl_xcvr_data data Input 9
add_interface_port ctrl_xcvr asi_ctrl_xcvr_valid valid Input 1
add_interface_port ctrl_xcvr asi_ctrl_xcvr_ready ready Output 1


# 
# connection point csr
# 
add_interface csr avalon end 
set_interface_property csr addressUnits WORDS
set_interface_property csr associatedClock datapath_clock
set_interface_property csr associatedReset datapath_reset

add_interface_port csr avs_csr_readdata readdata Output 32
add_interface_port csr avs_csr_read read Input 1
add_interface_port csr avs_csr_address address Input 4
add_interface_port csr avs_csr_waitrequest waitrequest Output 1
add_interface_port csr avs_csr_write write Input 1
add_interface_port csr avs_csr_writedata writedata Input 32


# 
# connection point xcvr_reset
# 
add_interface xcvr_reset reset end
set_interface_property xcvr_reset associatedClock xcvr_clock
set_interface_property xcvr_reset synchronousEdges BOTH
set_interface_property xcvr_reset ENABLED true
set_interface_property xcvr_reset EXPORT_OF ""
set_interface_property xcvr_reset PORT_NAME_MAP ""
set_interface_property xcvr_reset CMSIS_SVD_VARIABLES ""
set_interface_property xcvr_reset SVD_ADDRESS_GROUP ""

add_interface_port xcvr_reset i_rst_xcvr reset Input 1


# 
# connection point datapath_reset
# 
add_interface datapath_reset reset end
set_interface_property datapath_reset associatedClock datapath_clock
set_interface_property datapath_reset synchronousEdges BOTH
set_interface_property datapath_reset ENABLED true
set_interface_property datapath_reset EXPORT_OF ""
set_interface_property datapath_reset PORT_NAME_MAP ""
set_interface_property datapath_reset CMSIS_SVD_VARIABLES ""
set_interface_property datapath_reset SVD_ADDRESS_GROUP ""

add_interface_port datapath_reset i_rst_datapath reset Input 1


# 
# connection point datapath_clock
# 
add_interface datapath_clock clock end
set_interface_property datapath_clock clockRate 125000000
set_interface_property datapath_clock ENABLED true
set_interface_property datapath_clock EXPORT_OF ""
set_interface_property datapath_clock PORT_NAME_MAP ""
set_interface_property datapath_clock CMSIS_SVD_VARIABLES ""
set_interface_property datapath_clock SVD_ADDRESS_GROUP ""

add_interface_port datapath_clock i_clk_datapath clk Input 1


# 
# connection point xcvr_clock
# 
add_interface xcvr_clock clock end
set_interface_property xcvr_clock clockRate 156250000
set_interface_property xcvr_clock ENABLED true
set_interface_property xcvr_clock EXPORT_OF ""
set_interface_property xcvr_clock PORT_NAME_MAP ""
set_interface_property xcvr_clock CMSIS_SVD_VARIABLES ""
set_interface_property xcvr_clock SVD_ADDRESS_GROUP ""

add_interface_port xcvr_clock i_clk_xcvr clk Input 1

# 
# connection point debug_ts
# 
add_interface debug_ts avalon_streaming start 
set_interface_property debug_ts associatedClock xcvr_clock
set_interface_property debug_ts associatedReset xcvr_reset
set_interface_property debug_ts dataBitsPerSymbol 16

add_interface_port debug_ts aso_debug_ts_data data Output 16
add_interface_port debug_ts aso_debug_ts_valid valid Output 1

# 
# connection point debug_burst
# 
add_interface debug_burst avalon_streaming start
set_interface_property debug_burst associatedClock xcvr_clock
set_interface_property debug_burst associatedReset xcvr_reset
set_interface_property debug_burst dataBitsPerSymbol 16

add_interface_port debug_burst aso_debug_burst_valid valid Output 1
add_interface_port debug_burst aso_debug_burst_data data Output 16







