#################################################################################################
## Description: TCL script for making all reconfigurable partitions having the same layout     ##
## The identical procedure needs six args (RM_modules, RM_modules_path, checkpoints,           ##
## checkpoint_name, rp_wrapper_template_path, rp_wrapper_instance_paths, rp_template_path)     ##
## and writes two checkpoints, first: first implemented design with the template               ##
## reconfigurable module, second: checkpoint just with the static part.                        ##
## Identical use all procedures in the placement.tcl file                                      ##
## This phase is after the floorplanning phase and before the implement_other phase.           ##
##                                                                                             ##
## Created by: Roel Oomen                                                                      ##
## Extended and improved by : Najdet Charaf                                                    ##
#################################################################################################


proc identical {RM_modules RM_modules_DCP_path rp_template_path rp_wrapper_template_path rp_wrapper_instance_paths checkpoints checkpoint_name} {

	global dcpDir
	global synthDir
	global floorDir
	global implDir
	global pblocks_name
	global product_family
	global part_pins_pplocs
	global part_pins_names

	set RM_modules $RM_modules
	set RM_modules_DCP_path $RM_modules_DCP_path
	set rp_template_path $rp_template_path
	set rp_wrapper_template_path $rp_wrapper_template_path
	set rp_wrapper_instance_paths $rp_wrapper_instance_paths
	set checkpoint_name $checkpoint_name
	set checkpoints $checkpoints

	# Open local log files
	set cfh [open "$floorDir/commandLog_identical.log" w]
	set wfh [open "$floorDir/critical_identical.log" w]

	# read the template RM and assign it to all RPs
	foreach rp_region $::rp_all_instance_paths {
		command "read_checkpoint -cell $rp_region [lindex $RM_modules_DCP_path 0]"
	}

	# disable the CONTAIN_ROUTING parameter before doing the routing, on UltraScale+ boards
	# the partition pins disapears if keep it enabled
	if {[string match -nocase "*uplus" $product_family]} {
		command "set_param hd.routingContainmentAreaExpansion false"
	}
	
	set_property DONT_TOUCH 1 [get_cells -hierarchical -filter {NAME=~ *ISOBUF*}]

	command "opt_design" "$floorDir/opt_design.rds"
	command "place_design -directive SSI_SpreadLogic_high"
	command "route_design -directive AdvancedSkewModeling"

	command "write_checkpoint ${dcpDir}/first_time_placing_and_routing_iso.dcp -force"

	command "set_property HD.LOC_FIXED 1 \[get_pins $rp_template_path/*\]"

	# remove all connections except these in the template RP and lock them
	command "lock_design -level routing \[get_cells $rp_wrapper_template_path\]"

	# this unlock step ensure that all global connections will be also removed
	foreach wrapper $rp_wrapper_instance_paths {
		command "lock_design -unlock -level logical \[get_cells $wrapper\]"
	}
	command "route_design -unroute"
	command "place_design -unplace"

	command "write_checkpoint ${dcpDir}/ready_for_identical_layout.dcp -force"

	# design is now ready to make all RPs having the same layout
	command "make_layout_identical"

	command "write_checkpoint ${dcpDir}/identical_layout.dcp -force"
	command "close_project"
	# open and close project here to avoid errors during IDF phase
	command "open_checkpoint ${dcpDir}/identical_layout.dcp"
	# lock current routed and placed elements -> CP & RP
	command "lock_design -level routing"

	# save partition PINs from DFx flow
	set part_pins_pplocs_l [list]
	set part_pins_names_l [list]
	foreach rp_region $::rp_all_instance_paths {
		lappend part_pins_pplocs_l [get_property HD.PARTPIN_LOCS [get_pins $rp_region/*]]
		lappend part_pins_names_l [get_pins $rp_region/*]
	}

	# switch to IDF
	foreach rp_region $::rp_all_instance_paths {
		command "set_property HD.RECONFIGURABLE 0 \[get_cells $rp_region\]"
		command "set_property HD.ISOLATED 1 \[get_cells $rp_region\]"
	}
	foreach rp_region $::CP_paths {
		command "set_property HD.ISOLATED 1 \[get_cells $rp_region\]"
	}
	command "set_property DONT_TOUCH 0 \[get_cells $::static_path\]"
	command "set_property HD.ISOLATED 1 \[get_cells $::static_path\]"
	
	command "write_checkpoint ${dcpDir}/begin_isoflow.dcp -force"
	
	# IDF opt design adds Isolation LUTs and splits multiregion nets 
	command "opt_design"
	command "place_design"
	
	# stepwise routing avoids errors
	# route all unrouted nets (especially static part) & lock
	command "route_design -nets \[get_nets -hierarchical -filter {ROUTE_STATUS =~ UNROUTED}\]"
	if { [llength [get_nets -hierarchical -quiet -filter {ROUTE_STATUS =~ UNROUTED}]] > 0 } {
		command "route_design -nets \[get_nets -hierarchical -filter {ROUTE_STATUS =~ UNROUTED}\]"
	}
	if { [llength [get_nets -hierarchical  -quiet -filter {ROUTE_STATUS =~ UNROUTED}]] > 0 } {
		error "There are still unrouted nets, after trying it 2 times"
	}
	command "lock_design -level routing"

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
	command "set_property DONT_TOUCH 1 \[get_cells $::static_path\]"

	# enable RESET_AFTER_RECONFIG for 7 series
	if {![string match -nocase "*uplus" $product_family]} {
		foreach pblock $pblocks_name {
			command "set_property RESET_AFTER_RECONFIG 1 \[get_pblocks $pblock\]"
		}
	}
	
	# insert partition pin again
	for {set r 0} {$r < [llength $part_pins_names_l] } {incr r} {
		set part_pins_pplocs [lindex $part_pins_pplocs_l $r]
		set part_pins_names [lindex $part_pins_names_l $r]
		for {set var 0} {$var < [llength $part_pins_names]} {incr var} {
			set_property HD.PARTPIN_LOCS [lindex $part_pins_pplocs $var] [get_pins [lindex $part_pins_names $var]]
		}
	}

	# this step is to place the partition pins again using PRF (Partial Reconfiguration Flow)
	command "place_design -no_timing_driven"
	
	# unfixing and unroute clock_BUFG net to avoid clock_BUFG partition pin error
	# expecting only one clock in the design, needs to be investigated when using more clocks
	command "set_property is_route_fixed 0 \[get_nets -filter {TYPE == GLOBAL_CLOCK }\]"
	command "route_design -unroute -nets \[get_nets -filter {TYPE == GLOBAL_CLOCK }\]"
	# following the instruction of: CRITICAL WARNING: [Route 35-359] Clock nets were unrouted.
	# To achieve proper clock routing for UltraScale devices, update_clock_routing must be run before routing the unrouted clock nets.
	if {[string match -nocase "*uplus" $product_family]} { command "update_clock_routing" } 
	command "route_design"

	# Layout of the modules are now identical across the partitions and now the other modules can be placed and routed
	command "write_checkpoint ${implDir}/${checkpoint_name}_RM_0.dcp -force"
	lappend checkpoints "${checkpoint_name}_RM_0"

	command "lock_design -unlock -level routing"

	command "lock_design -level routing \[get_cells $rp_wrapper_template_path\]"

	command "lock_design -unlock -level routing \[get_cells [lindex $rp_wrapper_instance_paths 0]\]"

	command "lock_design -unlock -level logical \[get_cells $rp_template_path\]"

	command "update_design -cells $rp_template_path -black_box"

	for {set var 1} {$var < [llength $::rp_all_instance_paths]} {incr var} {
		#		command "lock_design -level routing \[get_cells [file dirname [lindex $::rp_all_instance_paths $var]]\]"
		#		command "lock_design -unlock -level routing \[get_cells $rp_wrapper_template_path\]"
		command "lock_design -unlock -level logical \[get_cells [lindex $::rp_all_instance_paths $var]\]"
		command "update_design -cells [lindex $::rp_all_instance_paths $var] -black_box"
	}

	command "lock_design -level routing"

	command "write_checkpoint ${dcpDir}/static.dcp -force"

	set ::checkpoints $checkpoints

	close $cfh
	close $wfh

}

