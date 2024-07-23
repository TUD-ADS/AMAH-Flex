#################################################################################################
## Description: TCL script for the design flow steps. This script automate all needed steps.   ##
## It takes all information from the design_flow.tcl file and organize the steps to generate   ##
## at the end full and partial bitstreams.                                                     ##
##                                                                                             ##
## Created by: Najdet Charaf                                                                   ##
#################################################################################################

    # create a table with all modules   
    list_runs

    #### Run Synthesis on any modules requiring synthesis
    foreach module [get_modules synth] {
      synthesize $module
    }

    # Source required for Tcl Procs
    source $tclDir/floorplanning.tcl
    source $tclDir/placement.tcl
    source $tclDir/identical.tcl
    source $tclDir/implement_other.tcl
    source $tclDir/board_utils.tcl
    source $tclDir/results_utils.tcl
    source $tclDir/find_position_utils.tcl

    # _template is the rp region that acts as an template for all the other rp regions
    set rp_template_path [lindex $RP_partitions 0]
    set rp_instance_paths [lrange $RP_partitions 1 end]

    set rp_template_name [lindex $parents_path 0]
    set rp_instance_names [lrange $parents_path 1 end]

	set template_con_partion_pblock_path [lindex $CP_pblocks_name 0]

    # This variable is used for updating the netlists of the regions, since there is no need to have a template in that case
    set rp_all_instance_paths $RP_partitions

    set rp_wrapper_template_path [lindex $wrappers_path 0]
    set rp_wrapper_instance_paths [lrange $wrappers_path 1 end]

    set ranges_pblock { RAMB36_X RAMB36_Y RAMB18_X RAMB18_Y DSP48_X DSP48_Y SLICE_X SLICE_Y} 
    interp alias {} ranges_pblock@  {} lsearch $ranges_pblock

    set region {Name Range Path}
    interp alias {} region@ {} lsearch $region

    set rp_regions ""
    set rp_wrapper_regions "" 
    set rp_template_region ""
    set rp_wrapper_template_region ""

    set checkpoints "" 
    set checkpoint_name "checkpoint"
    set RM_modules_DCP_path ""

    set part_pins_pplocs ""
    set part_pins_names ""

    # This list contain all finished syntesized reconfigurable modules
    foreach module $RM_modules {
        set module_name [get_attribute module $module moduleName]
        set path $synthDir/$module/${module_name}_synth.dcp
        lappend RM_modules_DCP_path $path
    }

    #### After reading the board information the first step will be sorting and editing them
    #### then read the report results from the synthesize phase to know all needed resources 
    #### for each reconfigurable module. At the end a maximum reconfigurable module which contains 
    #### maximum of resources will be created and find all possible positions for its max reconfigurable 
    #### partition. 
    source $tclDir/assign_tiles.tcl
    source $tclDir/read_results.tcl
    source $tclDir/find_RP_positions.tcl


    #### Create Pblocks and do the floorplanning
    floorplanning $RP_partitions $pblocks_name $CP_pblocks_name $CP_paths

# procedure after IDF floorplanning
proc finalize_design_flow { {switch_back_to_prflow 1} } {
	if $switch_back_to_prflow {
		# switch back to DFx
		foreach rp_region $::rp_all_instance_paths {
			command "set_property HD.ISOLATED 0 \[get_cells $rp_region\]"
			command "set_property DONT_TOUCH 0 \[get_cells $rp_region\]"
			command "set_property HD.RECONFIGURABLE 1 \[get_cells $rp_region\]"
			command "set_property DONT_TOUCH 1 \[get_cells $rp_region\]"
		}
		foreach rp_region $::CP_paths {
			command "set_property HD.ISOLATED 0 \[get_cells $rp_region\]"
			command "set_property DONT_TOUCH 1 \[get_cells $rp_region\]"
		}
		command "set_property HD.ISOLATED 0 \[get_cells $::static_path\]"
	}
	
    #### Make layout identical for all RPs/instances
    identical $::RM_modules $::RM_modules_DCP_path $::rp_template_path $::rp_wrapper_template_path $::rp_wrapper_instance_paths $::checkpoints $::checkpoint_name

    #### Implement now all other RMs 
    impl_other $::RM_modules_DCP_path $::rp_all_instance_paths $::checkpoints $::checkpoint_name

    #### Run PR verify 
    # PR verify only works when HD.RECONFIGURABLE is set to true
    for {set i 1} {$i < [llength $::checkpoints]} {incr i} {
	    command "pr_verify ${::implDir}/[lindex $::checkpoints 0].dcp ${::implDir}/[lindex $::checkpoints $i].dcp"
    }
    
	set bs_rp_template_path ""
	set bs_rp_others_paths ""
	set greybox_complete 0
    #### Genearte PR bitstreams 
    for {set i 0} {$i < [llength $::checkpoints]} {incr i} {
	    command "open_checkpoint ${::implDir}/[lindex $::checkpoints $i].dcp"
        # turn off CRC
        command "set_property BITSTREAM.GENERAL.CRC DISABLE \[current_design\]"
		if {$i == 0} {
			#write full bitstream
			set bsname ""
			append bsname "implement_all_" [lindex $::RM_modules $i] "_full.bit"
			command "write_bitstream -force $::bitDir/$bsname -no_partial_bitfile"
			#write template rp RM0
			set bsname ""
			append bsname [lindex $::pblocks_name $i] "_" [lindex $::RM_modules $i] "_partial.bit"
			set bs_rp_template_path "$::bitDir/$bsname"
			command "write_bitstream -force -cell $::rp_template_path $bs_rp_template_path" 
		} else {
			#write template rp and current RM
			set bsname ""
			append bsname [lindex $::pblocks_name 0] "_" [lindex $::RM_modules $i] "_partial.bit"
			command "write_bitstream -force -cell $::rp_template_path $::bitDir/$bsname" 
			# greybox bitstreams are in 2nd checkpoint
			#write partial greybox for each other RP
			if !$greybox_complete {
    			for {set y 1} {$y < [llength $::rp_all_instance_paths]} {incr y} {
    				set bsname ""
    				append bsname [lindex $::pblocks_name $y] "_greybox_partial.bit"
    				set bpath "$::bitDir/$bsname"
    				lappend bs_rp_others_paths $bpath
    				command "write_bitstream -force -cell [lindex $::rp_all_instance_paths $y] $bpath" 
    			}
				set greybox_complete 1
			}
		}
	    command "close_project"
    }

    set helpMsg ""
    set FH "stdout"
    lappend helpMsg "The design flow completed successfully, full bitstreams as well as partial bitstreams are generated."
    lappend helpMsg "\n ----  INFORMATION  ----\n"
	if {[string match -nocase "*uplus" $::product_family]} { 
		lappend helpMsg "In order to get FAR shift informations needed for the simple_far_shift programm call:"
		set prgcall "./get_far_start far_shift_info.txt $bs_rp_template_path"
		foreach r $bs_rp_others_paths {
			set prgcall [concat $prgcall $r]
		}
		lappend helpMsg $prgcall
		lappend helpMsg ""
	} else {
        lappend helpMsg "In order to relocate a partial bitstream, the FAR (Frame Address Register) must be changed."
        lappend helpMsg "An example for the FAR value: 0x 00 40 0A 00."
        lappend helpMsg "You need to get these information:"
        lappend helpMsg "+-----------------------+----------------------------------------------------+------------------+"
        lappend helpMsg "|  Address Information  | Bit index |              Description               |      Example     |"
        lappend helpMsg "+-----------------------+----------------------------------------------------+------------------+"
        lappend helpMsg "|1- The minor address:  |   \[6:0\]   | selects a frame within a major column. |    \"000 0000\"    |"
        lappend helpMsg "+-----------------------+----------------------------------------------------+------------------+"
        lappend helpMsg "|2- The column address: |   \[16:7\]  | selects the start left column of the   |  \"00 0111 0000\"  |"
        lappend helpMsg "|                       |           | RP (Reconfigurable Partition).         |                  |"
        lappend helpMsg "+-----------------------+----------------------------------------------------+------------------+"
        lappend helpMsg "|3- The row address:    |  \[21:17\]  | selects the current row where the RP   |     \"0 0001\"     |"
        lappend helpMsg "|                       |           | is located on the FPGA.                |                  |"
        lappend helpMsg "+-----------------------+----------------------------------------------------+------------------+"
        lappend helpMsg "|4- The Top/Bottom bit: |    \[22\]   | selects between top-half '0'           |                  |"
        lappend helpMsg "|                       |           | and bottom-half '1'                    |                  |"
        lappend helpMsg "+-----------------------+----------------------------------------------------+------------------+"
        lappend helpMsg "|5- The block type:     |  \[25:23\]  | valid types are: CLB,I/O,CLK \"000\"     |                  | "
        lappend helpMsg "|                       |           | block RAM content \"001\"                |                  |"
        lappend helpMsg "|                       |           | CFG_CLB \"010\"                          |                  |"
        lappend helpMsg "+-----------------------+----------------------------------------------------+------------------+"
    }
	
	foreach line $helpMsg {
       puts $FH $line
    }


    close $::RFH
    close $::CFH
    close $::WFH
}


# using interactive mode for static flooplanning 
if {[file exists $idf_constraints ]} {
	puts "Using additional IDF constraints: $idf_constraints"
	command "read_xdc $idf_constraints"
	finalize_design_flow 0
} else {
   	puts "No additional IDF constraints specified. Starting GUI for interactive floorplanning. Switching to IDF."
	# switch to IDF
	foreach rp_region $rp_all_instance_paths {
		command "set_property HD.RECONFIGURABLE 0 \[get_cells $rp_region\]"
		command "set_property HD.ISOLATED 1 \[get_cells $rp_region\]"
	}
	foreach rp_region $CP_paths {
		command "set_property HD.ISOLATED 1 \[get_cells $rp_region\]"
	}
	command "set_property HD.ISOLATED 1 \[get_cells $static_path\]"
	command "set_param hd.enableIDFDRC true"
	start_gui
	puts "Please constrain all Pblocks IDF comform. Finalize design flow by calling finalize_design_flow."
}
