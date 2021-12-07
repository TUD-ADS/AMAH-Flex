#################################################################################################
## Description: TCL script to read all needed resources from the synthesize utilization        ##
## reports (e.g. how many CLBs, DSPs ....) and other informations (e.g. modules names, how     ##
## many LUT2 instances are needed ....)                                                        ##
##                                                                                             ##
## Created by: Najdet Charaf                                                                   ##
#################################################################################################

# Initial a dictionary for all inserted LUT2
set inserted_LUTs [dict create ]

# Find for each reconfigurable module its synthesize utilization report
set report_files [findAllReports $RM_modules "hierarchical_synth.rpt"]

# Create a dictionary that contains all reconfigurable modules and for each module all needed resources are saved
set all_RMs [getInformation $report_files "Utilization"]

# Find for the top level its Vivado synthesize report
set report_files [findAllReports static "synth_design.rds"]

# Create a dictionary that contains the names which Vivado gives for the instances
set vivado_module_names [getInformation $report_files "Report Instance"]

# Create a dictionary that contains the names which Vivado gives for the instances for Vivado version 2020.2
# because the .rds file does not contain the "report instance table" anymore
# vivado_wrapper_names is only used to find the CP LUTs in edf, due to the additional hierarchy changed wrappers_path -> CP_path
if {$vivado_module_names eq ""} {
    #foreach path $CP_paths {
    #    dict set vivado_wrapper_names $path [get_property REF_NAME [get_cells $path]]
    #}
	command "open_checkpoint $synthDir/[lindex [get_modules] 0]/[get_attribute module [lindex [get_modules] 0] moduleName]_synth.dcp"
	foreach cp $CP_paths {
		foreach lut [get_cells $cp/*] {
			dict set inserted_LUTs $cp [get_property NAME [get_cells $lut]]
		}
	}
	command "close_design"
} else {
    # Find and save the wrapper instance names which Vivado gives
    set vivado_wrapper_names [getVivadoWrapperNames $vivado_module_names $CP_paths]
	
	# Find for the top level (the static part) the .edif file 
	set edif_file [findAllReports static ".edf"]
	
	# Find all manual insterted LUT2 for each reconfigurable module
	setLUTs $edif_file $vivado_wrapper_names
}

# Dictionary Searching to find the maximum of resources 
setMaximumRP all_RMs

# Get for the inserted LUTs per module the maximum number
set max_inserted_LUTs [getMaxLUTs inserted_LUTs]

# Get for each element (e.g. DSP, BRAM ...) the maximum number
set max_resources [getMaxRP all_RMs]
