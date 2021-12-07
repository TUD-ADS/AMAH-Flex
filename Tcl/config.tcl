#################################################################################################
## Description: TCL script to collect all relevant information from the user                   ##
##                                                                                             ##
## Created by: Najdet Charaf                                                                   ##
#################################################################################################


####Input Directories
set srcDir     "./Sources"
set rtlDir     "$srcDir/hdl"
set prjDir     "$srcDir/prj"
set xdcDir     "$srcDir/xdc"
set coreDir    "$srcDir/cores"
set netlistDir "$srcDir/netlist"

###################################
### Define target board
###################################
set xboard "zcu102"

###################################
### Define Part, Package, Speedgrade
### example: xc7vx485tffg1761-2
###################################
set device  "xczu9eg-"
set package "ffvb1156"
set speed   "-2-e"

###################################
### Design Definitions
###################################

#Top level
set top_level "top"
set top_dir "$rtlDir/top"
add_top $top_level $top_dir

#RMs
#VHDL:
add_rm "shift" "$rtlDir/shift_left" "shift_left"
add_rm "shift" "$rtlDir/shift_right" "shift_right"

###################################
### Define on which side the connection 
### partition should be placed (right or left)
###################################
set con_partition_side "right"

###################################
### RM and RP Definitions
###################################
set		static_path		"inst_static_iso"
lappend RP_partitions 	"PR_0/shift_wrapper_inst/inst_shift"
lappend pblocks_name 	"pblock_PR_0_inst_shift"
lappend CP_pblocks_name	"pblock_PR_0_CP"
lappend parents_path	"PR_0"
lappend CP_paths		"PR_0/shift_wrapper_inst/inst_shift_cp"
lappend wrappers_path	"PR_0/shift_wrapper_inst"

lappend RP_partitions 	"PR_1/shift_wrapper_inst/inst_shift"
lappend pblocks_name 	"pblock_PR_1_inst_shift"
lappend CP_pblocks_name	"pblock_PR_1_CP"
lappend parents_path	"PR_1"
lappend CP_paths		"PR_1/shift_wrapper_inst/inst_shift_cp"
lappend wrappers_path	"PR_1/shift_wrapper_inst"


# Additional constraints for IDF
set automatic_pblock_static 1
set automatic_cp_increase 1
set idf_constraints "$tclDir/idf_constr.xdc"
