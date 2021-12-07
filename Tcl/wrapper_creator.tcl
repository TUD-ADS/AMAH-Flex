#################################################################################################
## Description: TCL script to generate the wrapper for the reconfigurable partition and        ##
## the connection partition                                                                    ##
##                                                                                             ##
## Created by: Najdet Charaf                                                                   ##
#################################################################################################


#############################################################################
# GLOBAL CONFIG
#############################################################################
set DEBUG_WRAPPER_CREATOR 1
set DECOUPLE_RESET_SIGNAL_NAME "decouple_reset"
set INTERIM_SIGNAL_POSTNAME "_pin"
set CP_COMPONENT_POSTNAME "_cp"
set EXCLUDE_SIGNALS {"clk"}

#set WRAPPER_CONFIG_FILE_NAME "Tcl/wrapper.config"
set WRAPPER_CONFIG_FILE_NAME "Sources/hdl/shift_left/shift_left.vhd"
set WRAPPER_OUTPUT_FILE_NAME "Sources/hdl/top/automatic_created_wrapper.vhd"

#############################################################################
# procedures
#############################################################################
#add line
proc addl { str } {
	global res
	lappend res $str
}

proc vector_size_str { port } {
	if {[dict get $port endian] == "to" } {
		return "([dict get $port lbound] to [dict get $port ubound])"
	} else {
		return "([dict get $port ubound] downto [dict get $port lbound])"
	}
}

proc port_type_str { port } {
	set tmp ""
	if { [dict get $port type] == "std_logic" } {
		append tmp "std_logic"
	} else {
		append tmp "std_logic_vector"
		append tmp [vector_size_str $port]
	}
	return $tmp
}

proc component_ports { ports } {
	global DEBUG_WRAPPER_CREATOR
	set res {}
	set port_count [llength $ports]
	for { set port_idx 0 } { $port_idx < $port_count } { incr port_idx } {
		set port [lindex $ports $port_idx]
		if $DEBUG_WRAPPER_CREATOR {
				puts "create entity port $port"
		}
		set tmp {}
		append tmp "		[dict get $port name] : [dict get $port dir] "
		append tmp [port_type_str $port]
		#close bracket at last port declaration
		if { $port_idx + 1 == $port_count } {
			append tmp ");"
		} else {
			append tmp ";"
		}
		lappend res $tmp
	}
	return $res
}

proc insert_ports { port_list } {
	global res
	foreach p $port_list {
		lappend res $p
	}
}

# invert port direction, only expecting "in" or "out" 
proc invert_dir { dir } {
	if {$dir == "out"} { return "in" } else { return "out" }	
}

# returns list of dictionary without exclude signals
proc rm_exclude_signals { ports } {
	set r {}
	foreach p $ports {
		set port_name [dict get $p name]
		if { [lsearch $::EXCLUDE_SIGNALS $port_name] == -1  } {
			lappend r $p
		}
	}
	return $r
}

# generate list of dict with CP ports
# - without EXCLUDE_SIGNALS
# - copy all ports and add ports witch inverted direction (with INTERIM_SIGNAL_POSTNAME)
proc gen_cp_ports { target_ports } {
	global DEBUG_WRAPPER_CREATOR
	set ports_clean [rm_exclude_signals $target_ports]
	set res {}
	foreach p $ports_clean {
		if $DEBUG_WRAPPER_CREATOR { puts $p }
		# copy port to result list
		lappend res $p
		# copy port with inverted direction to result list
		set tmp $p
		dict set tmp dir [invert_dir [dict get $p dir]]
		dict set tmp name "[dict get $p name]$::INTERIM_SIGNAL_POSTNAME"
		lappend res $tmp
	}
	return $res
}

#############################################################################
# Main script
#############################################################################
# Open wrapper config file and read all needed information
if {[file exists $WRAPPER_CONFIG_FILE_NAME]} { 
	set fp [open $WRAPPER_CONFIG_FILE_NAME r]
	set wrapper_config [split [read $fp] "\n"]
	close $fp
} else {
   set errMsg "\n ERROR: No valid wrapper configuration file found.\n"
   error $errMsg
}

#found component name
set found_cn 0 
set component_name ""
set cp_component_name ""
set wrapper_name ""
set ports {}
set regexp_end_entity "end $component_name\(?:.*)"
for {set i 0} {$i < [llength $wrapper_config]} {incr i} {
	#substitute all multiple whitespaces
	set config_line [lindex $wrapper_config $i]
	regsub -all -- {:} [lindex $wrapper_config $i] " : " config_line
	regsub -all -- {\s+} $config_line " " config_line
	
	if !$found_cn {
		set found_cn [regexp {entity (.*) is.*} $config_line a cn]
		if {$found_cn} {
			set component_name $cn
			set cp_component_name "$component_name$CP_COMPONENT_POSTNAME"
			set wrapper_name "$component_name\_wrapper"
			if $DEBUG_WRAPPER_CREATOR {
				puts "Found entity name: $component_name"
			}
			continue
		}
	}
	
	if [regexp $regexp_end_entity $config_line] {
		if $DEBUG_WRAPPER_CREATOR {
			puts "found entity end, stop parsing configuration file"
		}
		break
	}
	
	set regexp_match [regexp {^(?: )?(.*) : (in|out) (std_logic|std_logic_vector)} $config_line m port_name port_dir port_type]
	
	if {!$regexp_match} {
		if $DEBUG_WRAPPER_CREATOR {
		set wMsg "\nWarning: unexpected syntax in wrapper config line: $i. Skipping this line (can be ignored if line number != entity port description).\n"
		puts $wMsg
		} 
		continue
	}
	
	if $DEBUG_WRAPPER_CREATOR {
			puts "reg ex of $config_line"
			puts "match $regexp_match"
			puts "$port_name $port_dir $port_type"
		}
	
	if { !( $port_dir != "in" || $port_dir != "out")} {
		set errMsg "\nERROR: wrong syntax in wrapper config: \n"
		append errMsg "line: $i\n"
		append errMsg "Expected port direction (in or out) but $port_dir is given.\n"
		error $errMsg
	}
	
	set port_config {}
	if {$port_type == "std_logic"} {
		#is allowed
		set port_config [dict create name $port_name dir $port_dir type $port_type] 
	} elseif {$port_type == "std_logic_vector"} {
		if { [regexp {(\d) downto (\d)} $config_line m upper_bound lower_bound] } {
			set port_endian "downto"
		} elseif { [regexp {(\d) to (\d)} $config_line m lower_bound upper_bound] } {
			set port_endian "to"
		} else {
			set errMsg "\nERROR: wrong syntax in wrapper config: \n"
			append errMsg "line: $i\n"
			append errMsg "Regular expression does not match, while parsing for endianess."
			error $errMsg
		}
		set port_config [dict create name $port_name dir $port_dir type $port_type endian $port_endian lbound $lower_bound ubound $upper_bound] 
	} else { 
		set errMsg "\nERROR: wrong syntax in wrapper config: \n"
		append errMsg "line: $i\n"
		append errMsg "Unsupported port type."
		error $errMsg
	}
	lappend ports $port_config
}

# CP ports, list of dict 
set cp_ports [gen_cp_ports $ports]
# result list of lines
set res "----------------------------------------------------------------------------------"
addl "-- Automatic created wrapper for module: $component_name"
addl "-- With this ports:"
foreach port $ports {
	addl "-- 		$port"
}
addl "----------------------------------------------------------------------------------"
addl ""
addl "library IEEE;"
addl "use IEEE.STD_LOGIC_1164.ALL;"
addl "Library UNISIM;"
addl "use UNISIM.vcomponents.all;"
addl ""
addl "entity $wrapper_name is"
addl "	Port ("
# addlitional wrapper port
addl "		$DECOUPLE_RESET_SIGNAL_NAME : in std_logic;"
# all target ports
set target_ports [component_ports $ports]
insert_ports $target_ports
addl "end $wrapper_name;"
addl ""
addl "architecture Behavioral of $wrapper_name is"
addl ""
# target component
addl "	component $component_name port("
insert_ports $target_ports
addl "	end component;"
addl ""
# CP component
addl " 	component $cp_component_name port("
addl "		$DECOUPLE_RESET_SIGNAL_NAME : in std_logic;"
set cp_ports_str [component_ports $cp_ports]
insert_ports $cp_ports_str
addl "	end component;"
addl ""
# create interim signals
foreach port $ports {
	set port_name [dict get $port name]
	if { [lsearch $EXCLUDE_SIGNALS $port_name] == -1  } {
		addl "	signal $port_name$INTERIM_SIGNAL_POSTNAME : [port_type_str $port];"
	}
}
addl ""
addl "	attribute black_box : string;"
addl "	attribute black_box of $component_name : component is \"yes\";"
addl ""
addl "	attribute DONT_TOUCH : string;"
addl "	attribute DONT_TOUCH of inst_$cp_component_name : label is \"TRUE\";"
addl ""
addl "begin"
addl "-- instantiate target component"
addl "	inst_$component_name : $component_name port map("
set port_count [llength $ports]
for { set port_idx 0 } { $port_idx < $port_count } { incr port_idx } {
	set tmp ""
	set port [lindex $ports $port_idx]
	set port_name [dict get $port name]
	if { [lsearch $EXCLUDE_SIGNALS $port_name] == -1  } {
		append tmp "		$port_name => $port_name$INTERIM_SIGNAL_POSTNAME"
	} else {
		append tmp "		$port_name => $port_name"
	}
	if { $port_idx + 1 == $port_count } {
		append tmp ");"
	} else {
		append tmp ","
	}
	addl $tmp
}
addl ""
addl "-- instantiate Connection Partition"
addl " inst_$cp_component_name : $cp_component_name port map("
addl "		$DECOUPLE_RESET_SIGNAL_NAME => $DECOUPLE_RESET_SIGNAL_NAME,"
set cp_port_count [llength $cp_ports]
for { set port_idx 0 } { $port_idx < $cp_port_count } { incr port_idx } {
	set tmp ""
	set port [lindex $cp_ports $port_idx]
	set port_name [dict get $port name]
	append tmp "		$port_name => $port_name"
	if { $port_idx + 1 == $cp_port_count } {
		append tmp ");"
	} else {
		append tmp ","
	}
	addl $tmp
}
addl ""
addl "end Behavioral;"
addl ""
addl "----------------------------------------------------------------------------------"
addl "-- Conection Partition"
addl "----------------------------------------------------------------------------------"
addl ""
addl "library IEEE;"
addl "use IEEE.STD_LOGIC_1164.ALL;"
addl "Library UNISIM;"
addl "use UNISIM.vcomponents.all;"
addl ""
addl "entity $cp_component_name is"
addl "	Port ("
# addlitional wrapper port
addl "		$DECOUPLE_RESET_SIGNAL_NAME : in std_logic;"
insert_ports $cp_ports_str
addl "end $cp_component_name;"
addl ""
addl "architecture Behavioral of $cp_component_name is"
addl ""
addl "begin"
addl "-- instantiate LUTs for CP"
foreach port $ports {
	set port_name [dict get $port name]
	if { [lsearch $EXCLUDE_SIGNALS $port_name] != -1  } {
		#skip excluded signal
		continue
	} 
    if { [dict get $port type] == "std_logic" } {
    	set port_width 1
    } else {
    	set ub [dict get $port ubound]
		set lb [dict get $port lbound]
		set port_width [expr 1 + $ub - $lb]		
    }
	for { set idx 0 } { $idx < $port_width } { incr idx } {
		if { [dict get $port type] == "std_logic" } {
			set inst_idx ""
			set addr ""
		} else {
			set inst_idx "_$idx"
			set addr "($idx)"
		}
		addl "	LUT2_inst_$port_name$inst_idx : LUT2 generic map (INIT => X\"2\")"
		addl "		port map ("
		if { [dict get $port dir] == "in" } {
			addl "			O => $port_name$INTERIM_SIGNAL_POSTNAME$addr,"
			addl "			I0 => $port_name$addr,"
		} else {
			# port direction out
			addl "			O => $port_name$addr,"
			addl "			I0 => $port_name$INTERIM_SIGNAL_POSTNAME$addr,"
		}
		addl "			I1 => $DECOUPLE_RESET_SIGNAL_NAME);"
		addl ""
	}
}
addl "end Behavioral;"

#write result to file
set fp [open $WRAPPER_OUTPUT_FILE_NAME w]
foreach line $res {
	puts $fp $line 
}
close $fp
