#################################################################################################
## Description: TCL script to implement all other reconfigurable modules and write the results ## 
## in the Implementation directory.                                                            ##
## The impl_other procedure needs four args (RM_modules_path, rp_all_instance_paths,           ##
## checkpoints, checkpoint_name). This phase is after the identical phase and before           ##
## the verification and writing the bitstreams phase.                                          ##
##                                                                                             ##
## Created by: Roel Oomen and Najdet Charaf                                                    ##
#################################################################################################

proc impl_other {RM_modules_DCP_path rp_all_instance_paths checkpoints checkpoint_name} {

    global implDir
    
    set RM_modules_DCP_path $RM_modules_DCP_path
    set rp_all_instance_paths $rp_all_instance_paths
    set checkpoints $checkpoints
    set checkpoint_name $checkpoint_name

    # Open local log files
    set rfh [open "$implDir/run.log" w]
    set cfh [open "$implDir/command.log" w]
    set wfh [open "$implDir/critical.log" w]

    # Implement the different modules
    # Iteration can start at one since the first module already has been implemented
    for {set i 1} {$i < [llength $RM_modules_DCP_path]} {incr i [llength $rp_all_instance_paths]} {	
        set checkpoint_name "checkpoint"
        for {set j 0} {$j < [llength $rp_all_instance_paths]} {incr j} {
		    set value [expr $i + $j ]
		    if {$value < [llength $RM_modules_DCP_path]} {
			    command "read_checkpoint -cell [lindex $rp_all_instance_paths $j] [lindex $RM_modules_DCP_path $value]" 
			    append checkpoint_name "_rp${j}_module${value}"
		    } else {
               # all RPs without RM called blackboxes, this blackboxes need to have buffer ports so that vivado can place and route the whole design together
               command "update_design -cells [lindex $rp_all_instance_paths $j] -buffer_ports"
               append checkpoint_name "_rp${j}_blanking"
                }
	    }

	    command "place_design"
	    command "route_design"
	    command "write_checkpoint ${implDir}/${checkpoint_name}.dcp -force"
	    lappend checkpoints "$checkpoint_name"
	
	    for {set j 0} {$j < [llength $rp_all_instance_paths]} {incr j} {
		    command "update_design -cells [lindex $rp_all_instance_paths $j] -black_box"
	    }
   }

   set ::checkpoints $checkpoints

   close $rfh
   close $cfh
   close $wfh

}
