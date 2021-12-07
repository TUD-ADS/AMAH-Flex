#################################################################################################
## Description: TCL script to find all possible positions for the reconfigurable partition     ##
## with the maximum of resources                                                               ##
##                                                                                             ##
## Created by: Najdet Charaf                                                                   ##
#################################################################################################

# Setting global variables
set slicell_per_llcol ""
set slicell_per_lmcol ""
set slicelm_per_llcol ""
set slicelm_per_lmcol ""
set ram_18_per_col ""
set ram_36_per_col ""
set dsp_per_col ""
set clk_re_enough_list [dict create ]
set possible_positions [dict create ]
set classify_lists [dict create ]

# Start with the main procedure
main clk_re_enough_list

