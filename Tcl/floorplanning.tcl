#################################################################################################
## Description: TCL script create the pblocks for each reconfigurable partition and each       ## 
## connection partition. This phase is after the synthesize phase and before the identical     ##
## phase.                                                                                      ##
## The floorplanning procedure needs three args (RP_partitions, pblocks_name, CP_pblocks_name) ##
## and writes the end result as a .DCP file in the Checkpoints directory                       ##
##                                                                                             ##
## Created by: Najdet Charaf                                                                   ##
#################################################################################################


proc floorplanning {RP_partitions pblocks_name CP_pblocks_name CP_paths} {

    global dcpDir
    global synthDir
    global xdcDir
    global board_part
    global floorDir
    global RP_number
    global clk_re_names
    global inserted_LUTs
    global classify_lists

    set RP_partitions $RP_partitions
    set pblocks_name $pblocks_name
    set CP_pblocks_name $CP_pblocks_name
	set CP_paths $CP_paths
    set class_names ""
	set used_clk_re ""

    #Open local log files
    set cfh [open "$floorDir/commandLog_floor.log" w] 
    set wfh [open "$floorDir/critical_floor.log" w]

    # Adding the static part 
    command "add_files $synthDir/[lindex [get_modules] 0]/[get_attribute module [lindex [get_modules] 0] moduleName]_synth.dcp"

    # Adding FPGA constraints
    foreach xdc_file [glob $xdcDir/*.xdc] { 
    command "add_files $xdc_file"
    }

    # Open, link the design and define all reconfigurable partitions 
    command "link_design -mode default -reconfig_partitions {$RP_partitions} -part $board_part -top [get_attribute module [lindex [get_modules] 0] moduleName]" "$floorDir/link_design.rds"
#    command "link_design -mode default -part $board_part -top [get_attribute module [lindex [get_modules] 0] moduleName]" "$floorDir/link_design.rds"

    foreach class_nr [dict keys $classify_lists] {
        set possible_nr 0
        foreach clk_re [dict keys [dict get $classify_lists $class_nr]] {
        set possible_nr [expr $possible_nr + [llength [dict get $classify_lists $class_nr $clk_re]]]
        }
        if {$possible_nr >= $RP_number} {
            lappend class_names $class_nr
        }
    }

    # Here is where we can optimize which clock region the tool should choose in case of time constraints and other needs
    if {$class_names ne ""} {
        set class_name [lindex $class_names end]
    } else {
        set errMsg "\n ERROR: There could not be found as many RPs as needed.\n"
		error $errMsg
    }

    set clk_interior_count 0
    set possible_interior_count 0
    # Create for each reconfigurable partition and connection partition a pblock in vivado 
    for {set var 0} {$var < $RP_number} {incr var} {
        set state clk_and_possible
        while {true} {
            switch $state {
                clk_and_possible {
                    set clock_region [lindex [dict keys [dict get $classify_lists $class_name]] $clk_interior_count]
                    set possible [lindex [dict get $classify_lists $class_name $clock_region] $possible_interior_count]
                    if {$possible ne ""} {
                        incr possible_interior_count
                        set state create
                    } else {
                        incr clk_interior_count
                        set possible_interior_count 0
                        set state clk_and_possible
                    }
                }

                create {
                    break
                }

                default {}
            }
        }

        set module_location [setLocation [findFirstLastElements $clock_region module_${possible}]]
		if $::automatic_cp_increase {
			set positions [findFirstLastElements $clock_region con_${possible}]
			set con_location ""
			foreach {a b} $positions {
				regexp {(.*)X(\d+)Y(\d+)} $a m e x y
				#adding left slice
				set x [expr $x - 1]
				set newa ""
				append newa $e X $x Y $y
				lappend con_location [concat $newa:$b]
			}
		} else {
			set con_location [setLocation [findFirstLastElements $clock_region con_${possible}]]
		}
        # C. Tietz: changed following
		# set current_wrapper [file dirname [lindex $RP_partitions $var]]
		# to: 
		set current_cp [lindex $CP_paths $var]
		# & renamed current_wrapper ocurness for clearness:
        set current_LUTs [dict get $inserted_LUTs [lsearch -inline [dict keys $inserted_LUTs] $current_cp]]
        set LUTs_list [setFullLUTPath $current_cp $current_LUTs]
        command "create_pblock [lindex $pblocks_name $var]"
        command "resize_pblock [get_pblocks [lindex $pblocks_name $var]] -add {$module_location}"
        command "add_cells_to_pblock [lindex $pblocks_name $var] [get_cells [list [lindex $RP_partitions $var]]]"

        command "create_pblock [lindex $CP_pblocks_name $var]"
        command "resize_pblock [get_pblocks [lindex $CP_pblocks_name $var]] -add {$con_location}"
        command "add_cells_to_pblock [lindex $CP_pblocks_name $var] \[get_cells [list $LUTs_list]\]"
		set GND_VCC_cells [get_cells -hierarchical -filter "name =~ $current_cp/GND || name =~ $current_cp/VCC"]
		foreach cell $GND_VCC_cells {
			command "add_cells_to_pblock [lindex $CP_pblocks_name $var] \[get_cells $cell\]"
		}

        command "set_property CONTAIN_ROUTING 1 \[get_pblocks [lindex $CP_pblocks_name $var]\]"
        command "set_property EXCLUDE_PLACEMENT 1 \[get_pblocks [lindex $CP_pblocks_name $var]\]"
		
		lappend used_clk_re $clock_region
    }
	
	if $::automatic_pblock_static {
		set pbs "pblock_static"
		command "create_pblock $pbs"
		command "resize_pblock \[get_pblocks $pbs\] -add SLR0:SLR0"
		foreach ur $used_clk_re {
			command "resize_pblock \[get_pblocks $pbs\] -remove $ur"
		}
		command "add_cells_to_pblock \[get_pblocks $pbs\] \[get_cells $::static_path\] -clear_locs"
	}

    command "write_checkpoint -force $dcpDir/synthesized_design.dcp"
    command "puts \"---------------------------------------------------\""

close $cfh
close $wfh

}
