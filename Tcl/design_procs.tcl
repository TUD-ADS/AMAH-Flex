#################################################################################################
## Description: TCL script with all needed procedures                                          ##
##                                                                                             ##
## Created by: Xilinx                                                                          ##
## Extended and improved by: Najdet Charaf                                                     ##
#################################################################################################

set modules             [list ]

array set module_attributes [list "moduleName"           [list string   null]  \
                                  "top_level"            [list boolean {0 1}]  \
                                  "prj"                  [list string   null]  \
                                  "includes"             [list string   null]  \
                                  "generics"             [list string   null]  \
                                  "vlog_headers"         [list string   null]  \
                                  "vlog_defines"         [list string   null]  \
                                  "sysvlog"              [list string   null]  \
                                  "vlog"                 [list string   null]  \
                                  "vhdl"                 [list string   null]  \
                                  "ip"                   [list string   null]  \
                                  "ipRepo"               [list string   null]  \
                                  "bd"                   [list string   null]  \
                                  "cores"                [list string   null]  \
                                  "xdc"                  [list string   null]  \
                                  "synthXDC"             [list string   null]  \
                                  "implXDC"              [list string   null]  \
                                  "synth"                [list boolean {0 1}]  \
                                  "synth_options"        [list string   null]  \
                                  "synthCheckpoint"      [list string   null]  \
                            ]

###############################################################
### Add a module
###############################################################
proc add_module { name } {
   global modules synthDir

   if {[lsearch -exact $modules $name] >= 0} {
      set errMsg "\nERROR: Module $name is already defined"
      error $errMsg
   }

   lappend modules $name
   set_attribute module $name "moduleName"       $name
   set_attribute module $name "top_level"        0
   set_attribute module $name "prj"              ""
   set_attribute module $name "includes"         ""
   set_attribute module $name "generics"         ""
   set_attribute module $name "vlog_headers"     [list ]
   set_attribute module $name "vlog_defines"     ""
   set_attribute module $name "sysvlog"          [list ]
   set_attribute module $name "vlog"             [list ]
   set_attribute module $name "vhdl"             [list ]
   set_attribute module $name "ip"               [list ]
   set_attribute module $name "ipRepo"           [list ]
   set_attribute module $name "bd"               [list ]
   set_attribute module $name "cores"            [list ]
   set_attribute module $name "xdc"              [list ]
   set_attribute module $name "synthXDC"         [list ]
   set_attribute module $name "implXDC"          [list ]
   set_attribute module $name "synth"            0 
   set_attribute module $name "synth_options"    "-flatten_hierarchy rebuilt" 
   set_attribute module $name "synthCheckpoint"  ""
}

###############################################################
### Set an attribute
##############################################################
proc set_attribute { type name attribute {values null} } {
   global ${type}Attribute
   set procname [lindex [info level 0] 0]

   switch -exact -- $type {
      module  {set list_type "modules"}
      impl    {set list_type "implementations"}
      default {error "\nERROR: Invalid type \'$type\' specified"}
   }

   check_list $list_type $name $procname
   check_attribute $type $attribute $procname
   if {![string match $values "null"]} {
      foreach value $values {
         check_attribute_value $type $attribute $value
      }
      set ${type}Attribute(${name}.$attribute) $values
   } else {
      puts "Critical Warning: Attribute $attribute for $type $name is set to $values. The value will not be modified."
   }
   return $values
}

###############################################################
### Get an attribute
###############################################################
proc get_attribute { type name attribute } {
   global ${type}Attribute
   set procname [lindex [info level 0] 0]

   switch -exact -- $type {
      module  {set list_type "modules"}
      impl    {set list_type "implementations"}
      default {error "\nERROR: Invalid type \'$type\' specified"}
   }

   check_list $list_type $name $procname
   check_attribute $type $attribute $procname
   return [subst -nobackslash \$${type}Attribute(${name}.$attribute)]
}

###############################################################
### Check if attribute exists
###############################################################
proc check_attribute { type attribute procname } {
   global ${type}_attributes
   set attributes [array names ${type}_attributes]
   if {[lsearch -exact $attributes $attribute] < 0} {
      set errMsg "\nERROR: Invalid $type attribute \'$attribute\' specified in $procname"
      error $errMsg
   }
}


###############################################################
### Check if attribute value matches type
###############################################################
proc check_attribute_value { type attribute values } {
   global ${type}_attributes 
   if {[info exists ${type}_attributes($attribute)]} {
      set attribute_checks [subst -nobackslashes \$${type}_attributes($attribute)]
      set index 0
      foreach {attr_type attr_values} $attribute_checks {
         set value [lindex $values $index]
         if {![string match $attr_values "null"] && [llength $value]} {
            set pass 0
            foreach attr_value $attr_values {
               if {$attr_value==$value} {
                  set pass 1
               }
            }
            if {$pass==0} {
               set errMsg "\nERROR: Value \'$value\' of $type attribute $attribute of type $attr_type is not valid.\n"
               append errMsg "Supported values are: $attr_values"
               error $errMsg
            }
         }
         incr index
      }
   } else {
      set errMsg "\nERROR: Could not find attribute $attribute in array ${type}_attributes."
      error $errMsg
   }
}

###############################################################
### Check if object exists
###############################################################
proc check_list { list_type name procname } {
   global [subst $list_type]
   if {[lsearch -exact [subst -nobackslash \$$list_type] $name] < 0} {
      set errMsg "\nERROR: Invalid $list_type \'$name\' specified in $procname"
      error $errMsg 
   }
}

###############################################################
### List All modules and Runs being synthesized/implemented 
###############################################################
proc list_runs { } {
   #### Print list of Modules
   if {[llength [get_modules synth]]} {
      set table "-title {#HD: List of modules to be synthesized}"
      append table " -row {Module \"Module Name\" \"Top Level\" Options}"
      foreach module [get_modules synth] {
         set moduleName [get_attribute module $module moduleName] 
         set top [get_attribute module $module top_level]
         set synth_options [get_attribute module $module synth_options]
         append table " -row {$module $moduleName $top \"$synth_options\"}"
      }
      print_table $table 
   } else {
      puts "#HD: No modules set to be synthesized"
   }
   if {[llength [get_modules !synth]]} {
      puts "#HD: Defined modules not being synthesized:"
      set count 1
      foreach module [get_modules !synth] {
         puts "\t$count. $module ([get_attribute module $module moduleName])"
         incr count
      }
   }
   puts "\n"
}


###############################################################
### Set specified parameters
###############################################################
proc set_parameters {params} {
   command "puts \"\t#HD: Setting Tcl Params:\""
   foreach {name value} $params   {
      puts "\t$name == $value"
      command "set_param $name $value"
   }
   puts "\n"
}

###############################################################
### Report all attributes
###############################################################
proc report_attributes { type name } {
   global ${type}Attribute
   global ${type}_attributes
   set procname [lindex [info level 0] 0]
   set widthCol1 18
   set widthCol2 90

   switch -exact -- $type {
      module  {set list_type "modules"}
      impl    {set list_type "implementations"}
      default {error "\nERROR: Invalid type \'$type\' specified"}
   }

   check_list $list_type $name $procname
   puts "Report $type properties for $name:"
   puts "| [string repeat - $widthCol1] | [string repeat - $widthCol2] |"
   puts [format "| %-*s | %-*s |" $widthCol1 "Attribute" $widthCol2 "Value"]
   puts "| [string repeat - $widthCol1] | [string repeat - $widthCol2] |"
   foreach {attribute } [lsort [array names ${type}_attributes]] {
      set value [subst -nobackslash \$${type}Attribute(${name}.$attribute)]
      puts [format "| %-*s | %-*s |" $widthCol1 $attribute $widthCol2 $value]
   }
   puts "| [string repeat - $widthCol1] | [string repeat - $widthCol2] |"
}

###############################################################
### Get a list of all modules 
###############################################################
proc get_modules { {filters ""} {function &&} } {
   upvar #0 modules modules

   if {[llength $filters]} {
      set filtered_modules ""
      foreach module $modules {
         foreach filter $filters {
            #Check if value is "not", and remove ! from name
            if {[regexp {!(.*)} $filter old filter]} {
               set value 0
            } else {
               set value 1
            }
            if {[get_attribute module $module $filter] == $value} {
               set match 1
               if {[string match $function "||"]} {
                  #Add matching filter results if not already added
                  if {[lsearch -exact $filtered_modules $module] < 0} {
                     lappend filtered_modules $module
                     break
                  }
               }
            } else {
               set match 0
               if {[string match $function "&&"]} {
                  break
               }
            }
         }
         if {$match && [string match $function "&&"]} {
            #Add matching filter results if not already added
            if {[lsearch -exact $filtered_modules $module] < 0} {
               lappend filtered_modules $module
            }
         }
      }
      return $filtered_modules
   } else {
      return $modules
   }
}

###############################################################
### Check Specified Part 
###############################################################
proc check_part {part} {
   set device [lindex [split $part -] 0]
   if {![llength [get_parts $part]]} {
      puts "ERROR: No valid part found matching specifiec part:\n\t$part"
      if {[llength [get_parts ${device}*]]} {
         puts "Valid part combinations for $device:"
         puts "\t[join [get_parts ${device}*] \n\t]"
      }
      error "ERROR: Check value of specified part."
   } else {
      puts "INFO: Found part matching $part"
   }
}

###############################################################
### Simple module add 
###############################################################
proc simple_add_module {module_handle component_name dir {top 0}} {
	global run.topSynth run.rmSynth
	set file_extensions {}
	# known design sources
	set available_srcs {"prj" "sv" "v" "vhd" "xci" "bd" "tcl" "ngc" "edn" "edif" "edf" "dcp"}
	
	foreach extension $available_srcs {
		if {0 < [llength [glob -nocomplain $dir/*.$extension]]} {
			lappend file_extensions $extension
		}
	}
	
	if {[llength $file_extensions] == 0} {
		error "ERROR: couldn't find any file in directory $dir with file extension $available_srcs \n"
	} else {
		# add module and name it
		add_module $module_handle
		set_attribute module $module_handle moduleName $component_name
		
		# add all found resources
		foreach file_extension $file_extensions {
    		variable module_attr
    		switch $file_extension {
    			"prj"	{set module_attr prj}
    			"sv"	{set module_attr sysvlog}
    			"v"		{set module_attr vlog}
    			"vhd"	{set module_attr vhdl}
    			"xci"	{set module_attr ip}
    			"bd"	{set module_attr bd}
				"tcl"	{set module_attr bd}
    			"ngc"	{set module_attr cores}
    			"edn"	{set module_attr cores}
    			"edif"	{set module_attr cores}
				"edf"	{set module_attr cores}
    			"dcp"	{set module_attr cores}
    			default {error "ERROR: Unknown/unspported file type $file_extension \n"}
    		}
    		set_attribute module $module_handle $module_attr [list [glob $dir/*.$file_extension]]
		}
		
		#set top and synthesis option
		if {$top} {
			set_attribute module $module_handle top_level 1
			set_attribute module $module_handle synth ${run.topSynth}
		} else {
			set_attribute module $module_handle synth ${run.rmSynth}
		}
	}
}

###############################################################
### Add top level
###############################################################
proc add_top { component_name dir } {
	set static "static"
	simple_add_module $static $component_name $dir 1
	return $static
}

###############################################################
### Add a RM
###############################################################
proc add_rm { component_name dir {module_name ""}} {
	global RM_modules
	set module_nr [llength $RM_modules]
	if {$module_name == ""} {
		set variant module_variant_$module_nr
	} else {
		set variant $module_name
	}
	simple_add_module $variant $component_name $dir
	lappend RM_modules $variant
	return $variant
}

###############################################################
### Add module attribute
###############################################################
proc add_attr {module_handle attr val} {
	set_attribute module $module_handle $attr $val
}

###############################################################
# Add all XDC files in list, and mark as OOC if applicable
###############################################################
proc add_xdc { xdc {synth 0} {cell ""} } {
   #Flatten list if nested lists exist
   set files [join [join $xdc]]
   foreach file $files {
	  if {[file exists $file]} {
		 puts "\t#HD: Adding 'xdc' file $file"
		 command "add_files $file"
		 set file_split [split $file "/"]
		 set fileName [lindex $file_split end]
		 if { $synth ==2 || [string match "*synth*" $fileName] } { 
			if {[string match "*ooc*" $fileName]} {
			   command "set_property USED_IN {synthesis out_of_context} \[get_files $file\]"
			} else {
			   command "set_property USED_IN {synthesis} \[get_files $file\]"
			}
		 } elseif { $synth==1 } {
			if {[string match "*ooc*" $fileName]} {
			   command "set_property USED_IN {synthesis implementation out_of_context} \[get_files $file\]"
			} else {
			   command "set_property USED_IN {synthesis implementation} \[get_files $file\]"
			}
		 } else {
			if {[string match "*ooc*" $fileName]} {
			   command "set_property USED_IN {implementation out_of_context} \[get_files $file\]"
			} else {
			   command "set_property USED_IN {implementation} \[get_files $file\]"
			}
		 }

		 if {[llength $cell]} {
			#Check if this file is already scoped to another partition
			if {[llength [get_property SCOPED_TO_CELLS [get_files $file]]]} {
			   set cells [get_property SCOPED_TO_CELLS [get_files $file]]
			   lappend cells $cell
			   command "set_property SCOPED_TO_CELLS \{$cells\} \[get_files $file\]"
			} else {
			   command "set_property SCOPED_TO_CELLS \{$cell\} \[get_files $file\]"
			}
		 }

		 #Set all partition scoped XDC to late by default. May need to review.
		 if {[string match "*late*" $fileName] || [llength $cell]} {
			command "set_property PROCESSING_ORDER late \[get_files $file\]"
		 } elseif {[string match "*early*" $fileName]} {
			command "set_property PROCESSING_ORDER early \[get_files $file\]"
		 }
	  } else {
		 set errMsg "\nERROR: Could not find specified XDC: $file" 
		 error $errMsg 
	  }
   }
}

###############################################################
# A proc to read in XDC files post link_design 
###############################################################
proc readXDC { xdc {cell ""} } {
   upvar resultDir resultDir

   puts "\tReading XDC files"
   #Flatten list if nested lists exist
   set files [join [join $xdc]]
   foreach file $files {
	  if {[file exists $file]} {
		 if {![llength $cell]} {
			command "read_xdc $file" "$resultDir/read_xdc.log"
		 } else {
			command "read_xdc -cell $cell $file" "$resultDir/read_xdc_cell.log"
		 }
	  } else {
		 set errMsg "\nERROR: Could not find specified XDC: $file" 
		 error $errMsg 
	  }
   }
}

###############################################################
### Add all XCI files in list
###############################################################
proc add_ip { ips } {
   global verbose
   upvar resultDir resultDir

   foreach ip $ips {
	  if {[string length ip] > 0} { 
		 if {[file exists $ip]} {
			set ip_split [split $ip "/"] 
			set xci [lindex $ip_split end]
			set ipPathList [lrange $ip_split 0 end-1]
			set ipPath [join $ipPathList "/"]
			set ipName [lindex [split $xci "."] 0]
			set ipType [lindex [split $xci "."] end]
			puts "\t#HD: Adding \'$ipType\' file $xci"
			command "add_files $ipPath/$xci" "$resultDir/${ipName}_add.log"
			if {[string match $ipType "bd"] || $verbose==0} {
			   return
			}
			if {[get_property GENERATE_SYNTH_CHECKPOINT [get_files $ipPath/$xci]]} {
			   if {![file exists $ipPath/${ipName}.dcp]} {
				  puts "\tSynthesizing IP $ipName"
				  command "synth_ip \[get_files $ipPath/$xci]" "$resultDir/${ipName}_synth.log"
			   }
			} else {
			   puts "\tGenerating output for IP $ipName"
			   command "generate_target all \[get_ips $ipName]" "$resultDir/${ipName}_generate.log"
			}
		 } else {
			set errMsg "\nERROR: Could not find specified IP file: $ip" 
			error $errMsg
		 }
	  }
   }
}

###############################################################
# Add all core netlists in list 
###############################################################
proc add_cores { cores } {
   #Flatten list if nested lists exist
   set files [join [join $cores]]
   foreach file $files {
	  if {[string length $file] > 0} { 
		 if {[file exists $file]} {
			#Comment this out to prevent adding files 1 at a time. Add all at once instead.
			puts "\t#HD: Adding core file $file"
			command "add_files $file"
		 } else {
			set errMsg "\nERROR: Could not find specified core file: $file" 
			error $errMsg
		 }
	  }
   }
}
