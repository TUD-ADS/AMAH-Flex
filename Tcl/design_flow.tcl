#################################################################################################
## Description: TCL script prepare the design flow and supply it with all needed information   ## 
## that can be find in the config.config file. At the end this script will call the run        ##
## script which start the design flow beginning with synthesize phase.                         ##
##                                                                                             ##
## Created by: Xilinx and Najdet Charaf                                                        ##
#################################################################################################

set tclDir "./Tcl"

if {![file exists ${tclDir}]} { 
   set errMsg "\n ERROR: No valid location found for required Tcl scripts. Set \$tclDir in design.tcl to a valid location.\n"
   error $errMsg
}

# Source required for Tcl procs
source $tclDir/design_procs.tcl
source $tclDir/log_utils.tcl
source $tclDir/synth_utils.tcl

# Setting the config file path, this file includes all needed information for the design flow
set config_path "./Tcl/config.tcl"

####Output Directories
set synthDir  "./Synth"
set floorDir  "./Floorplanning"
set implDir   "./Implement"
set dcpDir    "./Checkpoint"
set bitDir    "./Bitstreams"
set otherDir  "./Misc"

###################################
###   Tcl Variables
###  Setup Variables
###################################

set vivado_version [version -short]

set RM_modules             [list ]
set RP_partitions          [list ]
set pblocks_name           [list ]
set CP_pblocks_name        [list ]
set parents_path           [list ]
set wrappers_path          [list ]

# flow control
set run.topSynth       1
set run.staticSynth    1
set run.rmSynth        1
set run.prImpl         1
set run.prVerify       1
set run.writeBitstream 1

# Report and DCP controls - values: 0-required min; 1-few extra; 2-all
set verbose      1
set dcpLevel     1

# Open config file and read all needed information
if {[file exists $config_path]} { 
	source $config_path
} else {
   set errMsg "\n ERROR: No valid configuration file found.\n"
   error $errMsg
}

###################################
# Start preparing the design flow
###################################

# Create Output Directories if not exist
if {![file exists ${synthDir}]} { 
   command "file mkdir $synthDir"
}

if {![file exists ${floorDir}]} { 
   command "file mkdir $floorDir"
}

if {![file exists ${implDir}]} { 
   command "file mkdir $implDir"
}

if {![file exists ${dcpDir}]} { 
   command "file mkdir $dcpDir"
}

if {![file exists ${bitDir}]} { 
   command "file mkdir $bitDir"
}

if {![file exists ${otherDir}]} { 
   command "file mkdir $otherDir"
}

command "puts \"----------------------------------------------------------------\""
command "puts \"Setting TCL directory to                             $tclDir\""
command "puts \"Setting Synthesize directory to                      $synthDir\""
command "puts \"Setting Floorplanning directory to                   $floorDir\""
command "puts \"Setting Implementation directory to                  $implDir\""
command "puts \"Setting Checkpoints Directory                        $dcpDir\""
command "puts \"Setting Bitstreams directory to                      $bitDir\""
command "puts \"Setting Misc directory to                            $otherDir\""
command "puts \"Setting Source directory to                          $srcDir\""
command "puts \"Setting VHDL directory to                            $srcDir/hdl\""
command "puts \"Setting XDC directory to                             $srcDir/xdc\""
command "puts \"----------------------------------------------------------------\""


###################################
### Define Part, Package, Speedgrade
### example: xc7vx485tffg1761-2
###################################
#defined in config
set board_part $device$package$speed
command "check_part $board_part"
command "puts \"----------------------------------------------------------------\""

###################################
### Get the product family of the board 
### whether the board belongs to the UltraScale
### or 7-Series family  
### ###############################
set product_family [get_property FAMILY [get_parts $board_part]]

###################################
### Define how many SliceLL and SliceLM per CLB_Tile
### how many RAM_18 and RAM_36 per BRAM_Tile
### how many DSP48 per DSP_Tile
###################################
if {[string match -nocase "*uplus" $product_family]} {
    set sliceLL_per_LLtile  1
    set sliceLL_per_LMtile  0
    set sliceLM_per_LLtile  0
    set sliceLM_per_LMtile  1
    set ram_18_per_tile     2
    set ram_36_per_tile     1
    set dsp_48_per_tile     2
} else {
    set sliceLL_per_LLtile  2
    set sliceLL_per_LMtile  1
    set sliceLM_per_LLtile  0
    set sliceLM_per_LMtile  1
    set ram_18_per_tile     2
    set ram_36_per_tile     1
    set dsp_48_per_tile     2
}



###################################
### Top level Definition
###################################
#from config.tcl

###################################
### Define on which side the connection 
### partition should be placed (right or left)
###################################
#from config.tcl

###################################
### RM and RP Definitions
###################################
#from config.tcl
set RP_number [llength $RP_partitions]

###################################
### Start with the design flow
###################################

source $tclDir/run_design.tcl

#exit
