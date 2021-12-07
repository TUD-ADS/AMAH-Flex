#################################################################################################
## Description: TCL script to get information about the FPGA board (e.g. number of the slices  ##
## per clock region, the height of a particular clock region ....)                             ##
## This file contains the following procs:                                                     ##
## - sort {file_name}                                                                          ##
## - getClkRegionNum {file_name}                                                               ##
## - createClkRegionDicts {number}                                                             ##
## - getClkHeight {}                                                                           ##
## - setResourcesPerClkRe {}                                                                   ##
## - getClbLL {clk_region_name}                                                                ##
## - getClbLM {clk_region_name}                                                                ##
## - getSlicesLL {clk_region_name}                                                             ##
## - getSlicesLM {clk_region_name}                                                             ##
## - getDsps {clk_region_name}                                                                 ##
## - getBrams_18 {clk_region_name}                                                             ##
## - getBrams_36 {clk_region_name}                                                             ##
## - pairsIncreasing {dict_values}                                                             ##
## - pairsDecreasing {dict_values}                                                             ##
## - setUpperHalfCols {}                                                                       ##
## - getUpperHalfCols {clk_region_name}                                                        ##
## - setLowerHalfCols {}                                                                       ##
## - getLowerHalfCols {clk_region_name}                                                        ##
## - checkIfHardCore {clk_region_name}                                                         ##
## - updateColumnLists {clk_region_name missing_cols}                                          ##
## - makeOneBigColList {clk_region_name}                                                       ##
## - findAllIps {}                                                                             ##
##                                                                                             ##
## Created by: Najdet Charaf                                                                   ##
#################################################################################################

# This procedure is the main funktion in this file/section, it starts with counting all available 
# clock regions and create for each one a dictionary. It will be fill with all available resources
# then one big list will be created for each clock region that tells how many clomuns exist and 
# in which column what kind of resource is available. Additional, an array will be created which
# tells which clock region has IPs 
proc startSES {_file} {

    global clk_re_names

    set clkregion_num [getClkRegionNum $_file]
    createClkRegionDicts $clkregion_num
    sort $_file 
    setUpperHalfCols
    setLowerHalfCols

    foreach clk_re $clk_re_names {
        set checking_value [checkIfHardCore $clk_re]
        if {$checking_value ne "no"} {
            updateColumnLists $clk_re $checking_value
            makeOneBigColList $clk_re
        } else {
            makeOneBigColList $clk_re
        }
    }

    setResourcesPerClkRe
    findAllIps 
}

# sort and spilt the FPGA_info_file into 3 main groups (tile, pkgpin, clock_region) and save for 
# each group all needed information
proc sort {_file} {
    
    global main_info
    global product_family
    global clk_re_with_clk_tiles

    # open FPGA_info_arch file and read all needed information
    set fp [open $_file r]
    set info_info [split [read $fp] %]
    close $fp 

    # split the whole file into 3 groups (tile, pkgpin, clock_region) and save for each tile/pkgpin/clock_region 
    # its information (row, column, site number...)
    foreach group_info $info_info {
        set group_info_new [split [string trim $group_info] "\n"]
        # Checking if the first information entry equals begin
        set begin [string trim [lindex [split [lindex $group_info_new 0] {:}] 0]]
        if { $begin eq "begin"} {
            set group_name [string trim [lindex [split [lindex $group_info_new 0] {:}] 1]]
            switch -nocase $group_name {
                clockregion {
                    for {set j 2} {$j < [llength $group_info_new]} {incr j} {
                        # Checking if the end of the current information reached 
                        set end [string trim [lindex [split [lindex $group_info_new $j] {:}] 0]]
                        if { $end ne "end"} {
                            # Setting name of the current clock region and save its information (e.g. row, col, top_left ...)
                            set clock_region_name [string trim [lindex [split [lindex $group_info_new 1] {:}] 1]]
                            set information_label [string trim [lindex [split [lindex $group_info_new $j] {:}] 0]]
                            set information_value [string trim [lindex [split [lindex $group_info_new $j] {:}] 1]]
                            dict set main_info clockregions $clock_region_name $information_label $information_value
                        }
                    }
                }

                tile {
                    # Checking if the subgroup name is one of the below
                    set subgroup_name [string trim [lindex [split [lindex $group_info_new 4] {:}] 1]]
                    if {[string match -nocase "*uplus" $product_family]} {
                        if {[string match -nocase "cle*" $subgroup_name] \
                            || [string match -nocase "dsp" $subgroup_name] \
                            || [string match -nocase "bram" $subgroup_name]} {
                            # Adding for each row in the clock region its tiles information
                            set clock_region_name [string trim [lindex [split [lindex $group_info_new 5] {:}] 1]]
                            set tile_name [string trim [lindex [split [lindex $group_info_new 1] {:}] 1]]
                            set row_number [string trim [lindex [split [lindex $group_info_new 2] {:}] 1]]
                            dict set $clock_region_name row_$row_number $tile_name {}
                            # update and all value if the tile have more than 0 site
                            set site_number [string trim [lindex [split [lindex $group_info_new 6] {:}] 1]]
                            if { $site_number > 0} {
                                for {set var 0} {$var < $site_number} {incr var} {
                                    dict update ::$clock_region_name row_$row_number varkey1 {
                                        dict lappend varkey1 $tile_name [string trim [lindex [split [lindex $group_info_new [expr 7 + $var]] {:}] 1]]
                                    }
                                }
                            }
                        } elseif {[string match -nocase "rclk_bram*" $subgroup_name] \
				   || [string match -nocase "rclk_dsp*" $subgroup_name]} {
			    # Adding for each row in the clock region its tiles information
			    set clock_region_name [string trim [lindex [split [lindex $group_info_new 5] {:}] 1]]
                            set tile_name [string trim [lindex [split [lindex $group_info_new 1] {:}] 1]]
                            set row_number [string trim [lindex [split [lindex $group_info_new 2] {:}] 1]]
                            dict update clk_re_with_clk_tiles $clock_region_name varkey1 {
			       dict lappend varkey1 row_$row_number $tile_name
			    }
			}
                    } else {
                        if {[string match -nocase "clb*" $subgroup_name] \
                            || [string match -nocase "dsp_r" $subgroup_name] \
                            || [string match -nocase "dsp_l" $subgroup_name] \
                            || [string match -nocase "bram_r" $subgroup_name] \
                            || [string match -nocase "bram_l" $subgroup_name]} {
                            # Adding for each row in the clock region its tiles information
                            set clock_region_name [string trim [lindex [split [lindex $group_info_new 5] {:}] 1]]
                            set tile_name [string trim [lindex [split [lindex $group_info_new 1] {:}] 1]]
                            set row_number [string trim [lindex [split [lindex $group_info_new 2] {:}] 1]]
                            dict set $clock_region_name row_$row_number $tile_name {}
                            # update and all value if the tile have more than 0 site
                            set site_number [string trim [lindex [split [lindex $group_info_new 6] {:}] 1]]
                            if { $site_number > 0} {
                                for {set var 0} {$var < $site_number} {incr var} {
                                    dict update ::$clock_region_name row_$row_number varkey1 {
                                        dict lappend varkey1 $tile_name [string trim [lindex [split [lindex $group_info_new [expr 7 + $var]] {:}] 1]]
                                    }
                                }
                            }
                        } elseif {[string match -nocase "hclk_bram*" $subgroup_name] \
                                    || [string match -nocase "hclk_dsp*" $subgroup_name]} {
	                    # Adding for each row in the clock region its tiles information
	                    set clock_region_name [string trim [lindex [split [lindex $group_info_new 5] {:}] 1]]
                            set tile_name [string trim [lindex [split [lindex $group_info_new 1] {:}] 1]]
                            set row_number [string trim [lindex [split [lindex $group_info_new 2] {:}] 1]]
                            dict update clk_re_with_clk_tiles $clock_region_name varkey1 {
	                             dict lappend varkey1 row_$row_number $tile_name
	                    }
	                }
                    }
                }

                pkgpin {
                    for {set j 2} {$j < [llength $group_info_new]} {incr j} {
                        # Save pins which have a tile and/or a site
                        set null [string trim [lindex [split [lindex $group_info_new $j] {:}] 1]]
                        if { $null ne "NULL"} {
                            # Checking if the end of the current information reached
                            set end [string trim [lindex [split [lindex $group_info_new $j] {:}] 0]]
                            if {$end ne "end"} {
                            # Setting name of the current pin and save its information (e.g. tile, site)
                            set pkgpin_name [string trim [lindex [split [lindex $group_info_new 1] {:}] 1]]
                            set information_label [string trim [lindex [split [lindex $group_info_new $j] {:}] 0]]
                            set information_value [string trim [lindex [split [lindex $group_info_new $j] {:}] 1]]
                                dict set main_info pkgpins $pkgpin_name $information_label $information_value
                            }
                        }
                    }    
                }

                default {}
            }  
        }
    }

}

# Get the total number of the available clock regions on the FPGA
proc getClkRegionNum {_file} {

    global clk_re_names

    # open FPGA_info_arch file and read how many clock regions exist
    set fp [open $_file]
    while {[gets $fp line] >= 0} {
        if {[regexp -nocase -- "num_clkregion" $line]} {
            set clk_re_num $line
        } elseif {[string match -nocase "name*clockregion*" $line]} {
            lappend clk_re_names [lindex $line 2]
        }
    }
    close $fp

    return [string trim [lindex $clk_re_num 2] "%"]
}

# Create for each clock region an array  
proc createClkRegionDicts {number} {

    global clk_re_names

    for {set var 0} {$var <= $number} {incr var} {
        set ::[lindex $clk_re_names $var] [dict create]
    }
}

# Get the height of the clock region
proc getClkHeight {} {

    global clk_re_names
    global clk_re_height

    for {set i 0} {$i < [llength $clk_re_names]} {incr i} {
        global [lindex $clk_re_names $i]
        # Get the clock region name
        set clk_re_name [subst $[lindex $clk_re_names $i]]
        if {$clk_re_name ne ""} {
            # Get the first key from the clock region dictionary
            set first_key [lindex [dict keys $clk_re_name] 0]
            # Get the last key from the clock region dictionary
            set last_key [lindex [dict keys $clk_re_name] end]
            break
        }
    }
        # Return the result of the subtraction first row value from last row value
        return [expr [lindex [split $last_key "_"] 1] - [lindex [split $first_key "_"] 1]]

} 

# Set all resources (e.g. CLBs, BRAMs, DSPs) per clock region
proc setResourcesPerClkRe {} {

    global clk_re_names
    global product_family

    foreach var $clk_re_names {
        global $var
        if {[subst $$var] ne ""} {
            global [subst one_big_column_list_${var}]
            if {[string match -nocase "*uplus" $product_family]} {
                set ::${var}_list_clel ""
                set ::${var}_list_clem ""
                set ::${var}_list_brams ""
                set ::${var}_list_dsps ""

                set dict_name [subst $[subst one_big_column_list_${var}]]
                foreach key [dict keys $dict_name] {
                    set ::${var}_list_clel [expr [subst $[subst ::${var}_list_clel]] + [llength [lsearch -all -nocase [dict get $dict_name $key] "clel*"]]]
                    set ::${var}_list_clem [expr [subst $[subst ::${var}_list_clem]] + [llength [lsearch -all -nocase [dict get $dict_name $key] "clem*"]]]
                    set ::${var}_list_brams [expr [subst $[subst ::${var}_list_brams]] + [llength [lsearch -all -nocase [dict get $dict_name $key] "bram*"]]]
                    set ::${var}_list_dsps [expr [subst $[subst ::${var}_list_dsps]] + [llength [lsearch -all -nocase [dict get $dict_name $key] "dsp*"]]]
                } 
            } else {
                set ::${var}_list_clbll ""
                set ::${var}_list_clblm ""
                set ::${var}_list_brams ""
                set ::${var}_list_dsps ""

                set dict_name [subst $[subst one_big_column_list_${var}]]
                foreach key [dict keys $dict_name] {
                    set ::${var}_list_clbll [expr [subst $[subst ::${var}_list_clbll]] + [llength [lsearch -all -nocase [dict get $dict_name $key] "clbll*"]]]
                    set ::${var}_list_clblm [expr [subst $[subst ::${var}_list_clblm]] + [llength [lsearch -all -nocase [dict get $dict_name $key] "clblm*"]]]
                    set ::${var}_list_brams [expr [subst $[subst ::${var}_list_brams]] + [llength [lsearch -all -nocase [dict get $dict_name $key] "bram*"]]]
                    set ::${var}_list_dsps [expr [subst $[subst ::${var}_list_dsps]] + [llength [lsearch -all -nocase [dict get $dict_name $key] "dsp_*"]]]
                }
            }
        }
    }
}

# Get the whole CLBLL number of a particular clock region
proc getClbLL {clk_region_name} {

    global product_family

    if {[string match -nocase "*uplus" $product_family]} {
        global ${clk_region_name}_list_clel

        return [subst $${clk_region_name}_list_clel]
    } else {
        global ${clk_region_name}_list_clbll

        return [subst $${clk_region_name}_list_clbll]
    }
}

# Get the whole CLBLM number of a particular clock region
proc getClbLM {clk_region_name} {

    global product_family

    if {[string match -nocase "*uplus" $product_family]} {
        global ${clk_region_name}_list_clem

        return [subst $${clk_region_name}_list_clem]
    } else {
        global ${clk_region_name}_list_clblm

        return [subst $${clk_region_name}_list_clblm]
    }
}

# Get the whole SLICE_LL number of a particular clock region
proc getSlicesLL {clk_region_name} {

    global sliceLL_per_LLtile
    global sliceLL_per_LMtile

    return [expr ([getClbLL $clk_region_name] * $sliceLL_per_LLtile) + ([getClbLM $clk_region_name] * $sliceLL_per_LMtile)]
}

# Get the whole SLICE_LM number of a particular clock region
proc getSlicesLM {clk_region_name} {

    global sliceLM_per_LLtile
    global sliceLM_per_LMtile

    return [expr ([getClbLM $clk_region_name] * $sliceLM_per_LLtile) + ([getClbLM $clk_region_name] * $sliceLM_per_LMtile)]
}

# Get the whole DSPs number of a particular clock region
proc getDsps {clk_region_name} {

    global ${clk_region_name}_list_dsps
    global dsp_48_per_tile

    return [expr [subst $${clk_region_name}_list_dsps] * $dsp_48_per_tile]
}

# Get the whole BRAM_18s number of a particular clock region
proc getBrams_18 {clk_region_name} {

    global ${clk_region_name}_list_brams
    global ram_18_per_tile

    return [expr [subst $${clk_region_name}_list_brams] * $ram_18_per_tile] 
}

# Get the whole BRAM_36s number of a particular clock region
proc getBrams_36 {clk_region_name} {

    global ${clk_region_name}_list_brams
    global ram_36_per_tile

    return [expr [subst $${clk_region_name}_list_brams] * $ram_36_per_tile]
}

# This function sort the dictionary contents in increasing order
# vivado can't use the option "-stride" in "lsort" which was added in TCL version 8.6
# because vivado is still using TCL version 8.5
# that's why I added this function, it will be no more necessary if vivado update its TCL version
proc pairsIncreasing {dict_values} {

    set pair ""

    foreach {a b} [dict get $dict_values] {
        lappend pair [list $a $b]
    }
    return [concat {*}[lsort -dic -index 0 $pair]]
}

# This function sort the dictionary contents in decreasing order
# vivado can't use the option "-stride" in "lsort" which was added in TCL version 8.6
# because vivado is still using TCL version 8.5
# that's why I added this function, it will be no more necessary if vivado update its TCL version
proc pairsDecreasing {dict_values} {

    set pair ""

    foreach {a b} [dict get $dict_values] {
        lappend pair [list $a $b]
    }
    return [concat {*}[lsort -decreasing -dic -index 0 $pair]]
}

# Create a dictionary with all available columns (e.g. CLBs, BRAMs ...) 
# which are placed in the upper half of a particular clock region.
proc setUpperHalfCols {} {

    global clk_re_names
    set clk_height [getClkHeight]
    
    # search in every clock region
    foreach clk_re $clk_re_names {
        global $clk_re
        if {[subst $$clk_re] ne ""} {
            set first_row [lindex [split [lindex [dict keys [subst $$clk_re]] 0] "_"] 1]
            set last_row [lindex [split [lindex [dict keys [subst $$clk_re]] end] "_"] 1]

            # search in every row in the upper half clock region
            for {set var $first_row} {$var < [expr $last_row - [expr $clk_height / 2]]} {incr var} {
                set row_info [dict keys [dict get [subst $$clk_re] row_${var}]]
                
                # search and save all available columns
                for {set var1 0} {$var1 < [llength $row_info]} {incr var1} {
                    set column_index [lindex [split [lindex [split [lindex $row_info $var1] "X"] 1] "Y"] 0]
                    dict lappend ${clk_re}_upper_half_columns col_${column_index} [lindex $row_info $var1]
                }
            }
            # sort the columns of the dictionary in increasing order
            set ::${clk_re}_upper_half_columns [pairsIncreasing [subst $${clk_re}_upper_half_columns]]
        }
    }
}

# Get all columns in the upper half of a particular clock region
proc getUpperHalfCols {clk_region_name} {

    global ${clk_region_name}_upper_half_columns

    return [subst $${clk_region_name}_upper_half_columns]
}

# Create a dictionary with all available columns (e.g. CLBs, BRAMs ...) 
# which are placed in the lower half of a particular clock region.
proc setLowerHalfCols {} {

    global clk_re_names
    set clk_height [getClkHeight]
    
    # search in every clock region
    foreach clk_re $clk_re_names {
        global $clk_re
        if {[subst $$clk_re] ne ""} {
            set middle_row [lindex [split [lindex [dict keys [subst $$clk_re]] [expr $clk_height / 2]] "_"] 1]
            set last_row [lindex [split [lindex [dict keys [subst $$clk_re]] end] "_"] 1]

            # search in every row in the lower half clock region
            for {set var $middle_row} {$var <= $last_row} {incr var} {
                set row_info [dict keys [dict get [subst $$clk_re] row_${var}]]

                # search and save all available columns
                for {set var1 0} {$var1 < [llength $row_info]} {incr var1} {
                    set column_index [lindex [split [lindex [split [lindex $row_info $var1] "X"] 1] "Y"] 0]

                    dict lappend ${clk_re}_lower_half_columns col_${column_index} [lindex $row_info $var1]
                }
            }
            # sort the columns of the dictionary in increasing order
            set ::${clk_re}_lower_half_columns [pairsIncreasing [subst $${clk_re}_lower_half_columns]]
        }
    }
}

# Get all columns in the lower half of a particular clock region
proc getLowerHalfCols {clk_region_name} {

    global ${clk_region_name}_lower_half_columns

    return [subst $${clk_region_name}_lower_half_columns]
}

# Checking if the clock region contains any IP-cores
proc checkIfHardCore {clk_region_name} {

    global ${clk_region_name}_upper_half_columns
    global ${clk_region_name}_lower_half_columns
    global $clk_region_name
    
    set missing_in_upper {}
    set missing_in_lower {}

    if {[subst $$clk_region_name] ne ""} {
        foreach item [dict keys [subst $${clk_region_name}_upper_half_columns]] {
            if { [ lsearch -exact [subst $${clk_region_name}_lower_half_columns] $item ] == -1 } {
                lappend missing_in_lower $item
            }
        }
        foreach item [dict keys [subst $${clk_region_name}_lower_half_columns]] {
            if { [ lsearch -exact [subst $${clk_region_name}_upper_half_columns] $item ] == -1 } {
                lappend missing_in_upper $item
            }
        }

        if {[llength $missing_in_upper] == 0 && [llength $missing_in_lower] == 0} {

            return no
        } else { 
            dict set missing_cols missing_in_upper $missing_in_upper
            dict set missing_cols missing_in_lower $missing_in_lower
            return $missing_cols
        }
    } else {
        return no
    }
}

# Make both column lists (upper half and lower half) of a particular clock region identical
proc updateColumnLists {clk_region_name missing_cols} {

    global ${clk_region_name}_upper_half_columns
    global ${clk_region_name}_lower_half_columns
    
    set missing_in_upper [dict get $missing_cols [lindex [dict keys $missing_cols] 0]]
    set missing_in_lower [dict get $missing_cols [lindex [dict keys $missing_cols] 1]]
    
    foreach var $missing_in_lower {
        set ${clk_region_name}_upper_half_columns [dict remove [subst $${clk_region_name}_upper_half_columns ] $var]
    }

    foreach var $missing_in_upper {
        set ${clk_region_name}_lower_half_columns [dict remove [subst $${clk_region_name}_lower_half_columns ] $var]
    }
}

# Merge the two identical upper and lower column lists together to create one big column list of a particular clock region
proc makeOneBigColList {clk_region_name} {

    global ${clk_region_name}_upper_half_columns
    global ${clk_region_name}_lower_half_columns
    global $clk_region_name

    if {[subst $$clk_region_name] ne ""} {
        set ::one_big_column_list_${clk_region_name} [subst $${clk_region_name}_upper_half_columns]

        foreach key [dict keys [subst $${clk_region_name}_lower_half_columns]] {
            foreach value [dict get [subst $${clk_region_name}_lower_half_columns] $key] {
                dict lappend ::one_big_column_list_${clk_region_name} $key $value
            }
        }
    }

}

# This proc will filling a dictionary with all missing columns in each clock region, 
# which means either this clock region has a hard core or a list of pins or both of them 
# or just a column without resources to continue with identical (X, Y) indexes 
proc findAllIps {} {

    global clk_re_with_IPs
    global clk_re_names
    foreach clk_re $clk_re_names {
        global $clk_re
        if {[subst $$clk_re] ne ""} {
            global one_big_column_list_${clk_re}

            set index_column_list 0
            set start_var_at [lindex [split [lindex [dict keys [subst $[subst one_big_column_list_${clk_re}]]] $index_column_list] "_"] 1]
            set end_var_at [lindex [split [lindex [dict keys [subst $[subst one_big_column_list_${clk_re}]]] end] "_"] 1]
            set IPs_list ""

            for {set var $start_var_at} {$var <= $end_var_at} {incr var} {
                set column_number [lindex [split [lindex [dict keys [subst $[subst one_big_column_list_${clk_re}]]] $index_column_list] "_"] 1]
                if {$var != $column_number} {
                    lappend IPs_list col_${var}
                } else {
                    incr index_column_list
                }
            }
            set first [lindex [split [lindex $IPs_list 0] "_"] 1]
            set index 1
            for {set var 1} {$var <= [llength $IPs_list]} {incr var} {
                set second [lindex [split [lindex $IPs_list $var] "_"] 1]

                if {$second ne "" || [llength $IPs_list] == 1} {
                    if {[llength $IPs_list] > 2 && [lindex $IPs_list end] ne [lindex $IPs_list $var]} {
                        if {[expr $first + 1] == $second} {
                            dict update clk_re_with_IPs $clk_re varkey {
                                dict lappend varkey col_list_$index col_$first
                            }
                            set first $second
                        } else {
                            if {[dict exists $clk_re_with_IPs $clk_re col_list_$index]} {
                                dict update clk_re_with_IPs $clk_re varkey {
                                    dict lappend varkey col_list_$index col_$first
                                }
                            } else {
                                dict update clk_re_with_IPs $clk_re varkey {
                                    dict lappend varkey col_list_$index col_$first
                                }
                            }
                            set first $second
                            incr index
                        }
                    } else {
                        if {[expr $first + 1] == $second} {
                            dict update clk_re_with_IPs $clk_re varkey {
                                dict lappend varkey col_list_$index col_$first col_$second
                            }
                        } else {
                            dict update clk_re_with_IPs $clk_re varkey {
                                dict lappend varkey col_list_$index col_$first
                            }
                        }
                    }
                }
            }
        }
    }
}
