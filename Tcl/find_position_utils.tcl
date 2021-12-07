#################################################################################################
## Description: TCL script to find all possible positions for the reconfigurable partition     ##
## with the maximum of resources.                                                              ##
## This file contains the following procs:                                                     ##
## - isEnoughResources {clk_region}                                                            ##
## - setWhichIsEnough {enough_list}                                                            ##
## - setColumnDefinition {}                                                                    ##
## - setColumnDefForUSP {clk_re dict_value}                                                    ##
## - sortDictByValueIncreasing {dict_values}                                                   ##
## - sortDictByValueDecreasing {dict_values}                                                   ##
## - reSortIPColLists {}                                                                       ##
## - setColumnEntryCount {}                                                                    ##
## - findPositions {enough_list}                                                               ##
## - findPossibilities {clk_re dict_value_col_def column_list start_IP_col end_IP_col          ##
##			current_place right left con_partition_side possible_number}                       ##
## - findPlacement {placement}								                                   ##
## - findCLB {kind}                                                                            ##
## - needed {resources kind}                                                                   ##
## - add {clk_region column col_kind rest_resources possible_number add_status}                ##
## - remove {found_resources}			   					                                   ##
## - maxRegionResources {resources}							                                   ##
## - addLUT {clk_region column col_kind rest_LUTs}                                             ##
## - possible_number add_status								                                   ##
## - isEnough {rest_resources}                                                                 ##
## - stillEnough {rest_resources needed_resources}					                           ##
## - isEnoughLUTs {LUTs}                                                                       ##
## - getFirstOfAll {entries}                                                                   ##
## - getLastOfAll {entries}                                                                    ##
## - findEntry {clk_re_name value filter_name}                                                 ##
## - findTile {clk_re_name filter_name}							                               ##
## - findFirstLastElements {clk_re_name possible}                                              ##
## - setLocation {positions}                                                                   ##
## - setFullLUTPath {wrapper_name LUTs_list}                                                   ##
## - classify {}									                                           ##
##                                                                                             ##
## Created by: Najdet Charaf                                                                   ##
#################################################################################################

namespace import ::tcl::mathfunc::min

# This procedure is the main function it start with checking which clock region has enough
# resources for the maximum reconfigurable module. Then some steps sorting and dealing with 
# all the entries in each clock region dictionary. At the end find all positions possibilities 
# for the max raconfigurable partition. 
proc main {enough_list} {
    global product_family
    setWhichIsEnough $enough_list
    setColumnDefinition
    reSortIPColLists
    setColumnEntryCount
    findPositions $enough_list
    classify
}

# Checking each clock region if it has enough resources for the max reconfigurable module plus connection partition
# plus 20% more room for reouting resources
proc isEnoughResources {clk_region} {

    global max_resources
    global inserted_LUTs

    set max_LUTs 0

    foreach key [dict keys $inserted_LUTs] {
        set max_LUTs [max $max_LUTs [llength [dict get $inserted_LUTs $key]]]
    }

    set slicell_number [getSlicesLL $clk_region]
    set slicelm_number [getSlicesLM $clk_region]
    set dsp_number [getDsps $clk_region]
    set bram_18_number [getBrams_18 $clk_region]
    set bram_36_number [getBrams_36 $clk_region]

    set max_slicell [expr [dict get $max_resources {Logic LUTs}] + [dict get $max_resources FFs] + $max_LUTs]
    set max_slicelm [expr [dict get $max_resources LUTRAMs] + [dict get $max_resources SRLs]]
    set max_dsps [dict get $max_resources {DSP48 Blocks}]
    set max_bram_18 [dict get $max_resources RAMB18]
    set max_bram_36 [dict get $max_resources RAMB36]

    if {$max_slicell <= $slicell_number && $max_slicelm <= $slicelm_number && $max_dsps <= $dsp_number \
        && $max_bram_18 <= $bram_18_number && $max_bram_36 <= $bram_36_number} {
         return yes
    } else {
        return no
    }
}

# Create an array which contains clock regions that have either enough resources or not
proc setWhichIsEnough {enough_list} {

    global clk_re_names
    global $enough_list

    foreach clk_re $clk_re_names {
        global $clk_re
        if {[subst $$clk_re] ne ""} {
            lappend $enough_list $clk_re [isEnoughResources $clk_re]
        }
    }
    
    set clock_status ""
    foreach {clk_region status} [subst $$enough_list] {
        lappend clock_status $status
    }

    if {[lsearch $clock_status yes] == -1} {
        set errMsg "\n ERROR: There are not enough resources within a clock region and therefore it is immpossible to place the RPs.\n"
        error $errMsg
    }
}

# Creating a dictionary for each clock region which contains all resources columns of that
# clock region and which kind of resource and its placement 
# (e.g. kind: CLBLL, placement: right; kind: DSP, placement: left ...)
proc setColumnDefinition {} {

    global clk_re_names
    global product_family

    foreach clk_re $clk_re_names {
        global $clk_re

        if {[subst $$clk_re] ne ""} {
            global one_big_column_list_${clk_re}

            # set column_def_{clock_region_name} global
            set ::column_def_${clk_re} [dict create ]
            set dict_value [subst $[subst one_big_column_list_${clk_re}]]
            
            if {[string match -nocase "*uplus" $product_family]} {
                # re-order the columns so that only uniform elements exist within a column
                set dict_value [setColumnDefForUSP $clk_re $dict_value]
                foreach key [dict keys $dict_value] {
                    set col_placement [lindex [split $key "_"] end]
                    set col_kind [lindex [split [lindex [dict get $dict_value $key] 0] "_"] 0]
                    dict update ::column_def_${clk_re} $key varkey {
                        dict lappend varkey column_kind $col_kind
                        dict lappend varkey column_placement $col_placement
                    }
                }
            } else {
                foreach key [dict keys $dict_value] {
                    set col_placement [lindex [split [lindex [dict get $dict_value $key] 0] "_"] 1]
                    set col_kind [lindex [split [lindex [dict get $dict_value $key] 0] "_"] 0]
                    dict update ::column_def_${clk_re} $key varkey {
                        dict lappend varkey column_kind $col_kind
                        dict lappend varkey column_placement $col_placement
                    }
                }
            }
        }
    }
}

# Since the architecture of the UltraScale plus FPGAs is different from the 7 series, 
# a reordering must be performed to sort the columns with uniform contents only.
proc setColumnDefForUSP {clk_re dict_value} {

    global one_big_column_list_${clk_re}
    global clk_re_with_IPs

    set index 1
    set init true
    # split columns with the same number into tow sub-columns (col_number_l and col_number_r)
    foreach key [dict keys $dict_value] {
        # compare the 1st and 2nd item or 5th and 6th item -> if different then the column is divided
        #                                                  -> if not then the column will not be included into the RP
        set first_col_kind [lindex [split [lindex [dict get $dict_value $key] 0] "_"] 0]
        set second_col_kind [lindex [split [lindex [dict get $dict_value $key] 1] "_"] 0]
        if {$first_col_kind eq $second_col_kind} {
            set fourth_col_kind [lindex [split [lindex [dict get $dict_value $key] 3] "_"] 0]
            set fifth_col_kind [lindex [split [lindex [dict get $dict_value $key] 4] "_"] 0]
            set sixth_col_kind [lindex [split [lindex [dict get $dict_value $key] 5] "_"] 0]
            if {$fifth_col_kind eq $sixth_col_kind} {
                dict update one_big_column_list_${clk_re} $key varkey {
                    unset varkey
                }
                if {$init eq "true"} {
                    while {[dict exists $clk_re_with_IPs $clk_re col_list_$index]} {
                        incr index
                    }
                    dict update clk_re_with_IPs $clk_re varkey {
                        dict lappend varkey col_list_$index $key
                    }
                    set prior_key $key
                    set init false
                } else {
                    if {[expr [lindex [split $prior_key "_"] 1] + 1] == [lindex [split $key "_"] 1]} {
                        dict update clk_re_with_IPs $clk_re varkey {
                            dict lappend varkey col_list_$index $key
                        }
                    } else {
                        incr index
                        dict update clk_re_with_IPs $clk_re varkey {
                            dict lappend varkey col_list_$index $key
                        }
                    }
                    set prior_key $key
                }
            } else {
                dict update one_big_column_list_${clk_re} $key varkey {
                    unset varkey
                    if {$fourth_col_kind eq $fifth_col_kind} {
                        if {[string match -nocase "clel" $first_col_kind]} {
                            dict update one_big_column_list_${clk_re} ${key}_l varkey1 {
                                set varkey1 [lsearch -inline -all -nocase [dict get $dict_value $key] "$sixth_col_kind*"]
                            }
                            dict update one_big_column_list_${clk_re} ${key}_r varkey2 {
                                set varkey2 [lsearch -inline -all -nocase [dict get $dict_value $key] "$first_col_kind*"]
                            }
                        } else {
                            dict update one_big_column_list_${clk_re} ${key}_l varkey1 {
                                set varkey1 [lsearch -inline -all -nocase [dict get $dict_value $key] "$first_col_kind*"]
                            }
                            dict update one_big_column_list_${clk_re} ${key}_r varkey2 {
                                set varkey2 [lsearch -inline -all -nocase [dict get $dict_value $key] "$sixth_col_kind*"]
                            }
                        }
                    } else {
                       if {[string match -nocase "clel" $first_col_kind]} {
                            dict update one_big_column_list_${clk_re} ${key}_l varkey1 {
                                set varkey1 [lsearch -inline -all -nocase [dict get $dict_value $key] "$fifth_col_kind*"]
                            }
                            dict update one_big_column_list_${clk_re} ${key}_r varkey2 {
                                set varkey2 [lsearch -inline -all -nocase [dict get $dict_value $key] "$first_col_kind*"]
                            }
                        } else {
                            dict update one_big_column_list_${clk_re} ${key}_l varkey1 {
                                set varkey1 [lsearch -inline -all -nocase [dict get $dict_value $key] "$first_col_kind*"]
                            }
                            dict update one_big_column_list_${clk_re} ${key}_r varkey2 {
                                set varkey2 [lsearch -inline -all -nocase [dict get $dict_value $key] "$fifth_col_kind*"]
                            }
                        }
                    }
                }
            }
        } else {
            dict update one_big_column_list_${clk_re} $key varkey {
                unset varkey
                dict update one_big_column_list_${clk_re} ${key}_l varkey1 {
                    set varkey1 [lsearch -inline -all -nocase [dict get $dict_value $key] "$first_col_kind*"]
                }
                dict update one_big_column_list_${clk_re} ${key}_r varkey2 {
                    set varkey2 [lsearch -inline -all -nocase [dict get $dict_value $key] "$second_col_kind*"]
                }
            }
        }
    }
    return [subst $[subst one_big_column_list_${clk_re}]]
}

# This function re-sorts the lists of the IP columns in increasing order so that the columns have an 
# upward order. In the case that after the function "find all IPs" new IP columns are added.
proc sortDictByValueIncreasing {dict_values} {

    set pair ""

    foreach {a b} [dict get $dict_values] {
        lappend pair [list $a $b]
    }
    return [concat {*}[lsort -dic -index 1 $pair]]
}

# This function re-sorts the lists of the IP columns in decreasing order so that the columns have an 
# downward order. In the case that after the function "find all IPs" new IP columns are added.
proc sortDictByValueDecreasing {dict_values} {

    set pair ""

    foreach {a b} [dict get $dict_values] {
        lappend pair [list $a $b]
    }
    return [concat {*}[lsort -decreasing -dic -index 1 $pair]]
}

proc reSortIPColLists {} {

    global clk_re_with_IPs
    global con_partition_side

    foreach clock_region [dict keys $clk_re_with_IPs] {
        set column_lists [dict get $clk_re_with_IPs $clock_region]
        if {$con_partition_side eq "right"} {
            dict update clk_re_with_IPs $clock_region varkey {
                set varkey [sortDictByValueIncreasing $column_lists]
            }
        } elseif {$con_partition_side eq "left"} {
            dict update clk_re_with_IPs $clock_region varkey {
                set varkey [sortDictByValueDecreasing $column_lists]
            }
        }
    }
}

# This function count and save how many resources are available in each column
# (e.g. CLBLL column has 100 sliceLL; DSP column has 20 DSP48 ....)
proc setColumnEntryCount {} {

    global clk_re_names
    global sliceLL_per_LLtile
    global sliceLL_per_LMtile
    global sliceLM_per_LLtile
    global sliceLM_per_LMtile
    global ram_18_per_tile
    global ram_36_per_tile
    global dsp_48_per_tile
    global slicell_per_llcol
    global slicell_per_lmcol
    global slicelm_per_llcol
    global slicelm_per_lmcol
    global ram_18_per_col
    global ram_36_per_col
    global dsp_per_col

    for {set i 0} {$i < [llength $clk_re_names]} {incr i} {
        global [lindex $clk_re_names $i]
        set clk_re_entry [subst $[lindex $clk_re_names $i]]
        set clk_re_name [lindex $clk_re_names $i]
        if {$clk_re_entry ne ""} {
            global one_big_column_list_${clk_re_name}
            set dict_value [subst $[subst one_big_column_list_${clk_re_name}]]
        break
        }
    }

    foreach key [dict keys $dict_value] {
        set col_kind [lindex [split [lindex [dict get $dict_value $key] 0] "_"] 0]
        if {$slicell_per_llcol eq "" || $slicell_per_lmcol eq "" || $slicelm_per_llcol eq ""\
            || $slicelm_per_lmcol eq "" || $ram_18_per_col eq "" || $ram_36_per_col eq ""\
            || $dsp_per_col eq ""} {
            set count_entry [llength [dict get $dict_value $key]]
            switch -nocase $col_kind {
                clbll {
                    set slicell_per_llcol [expr $count_entry * $sliceLL_per_LLtile]
                    set slicelm_per_llcol [expr $count_entry * $sliceLM_per_LLtile]
                }

                clblm {
                set slicell_per_lmcol [expr $count_entry * $sliceLL_per_LMtile]
                set slicelm_per_lmcol [expr $count_entry * $sliceLM_per_LMtile]
                }

                clel {
                    set slicell_per_llcol [expr $count_entry * $sliceLL_per_LLtile]
                    set slicelm_per_llcol [expr $count_entry * $sliceLM_per_LLtile]
                }

                clem {
                set slicell_per_lmcol [expr $count_entry * $sliceLL_per_LMtile]
                set slicelm_per_lmcol [expr $count_entry * $sliceLM_per_LMtile]
                }

                bram {
                set ram_18_per_col [expr $count_entry * $ram_18_per_tile]
                set ram_36_per_col [expr $count_entry * $ram_36_per_tile]
                }

                dsp {
                set dsp_per_col [expr $count_entry * $dsp_48_per_tile]
                }

                default {}
            }
        }
    }
}

# This procedure splits the clock region into several parts, if that clock region
# contains IP cores. This step ensures that no IP cores will be placed inside RPs 
# or between RPs and CPs 
proc findPositions {enough_list} {

    global $enough_list
    global con_partition_side
    global clk_re_with_IPs

    foreach {clk_re status} [subst $$enough_list] {
        global column_def_${clk_re}

        # checking the status of the clock region if it has enough resources or not
        if {$status eq yes} {
            set possible_number 1
            set current_place 0
            if {[dict exist $clk_re_with_IPs $clk_re]} {
                set IP_lists_number [llength [dict keys [dict get $clk_re_with_IPs $clk_re]]]
            } else {
                set IP_lists_number 0
            }
            if {$con_partition_side eq "right"} {
                set dict_value_col_def [subst $[subst column_def_${clk_re}]]
                set column_list [dict keys $dict_value_col_def]
                set left yes
                set right no
                if {$IP_lists_number == 0} {
                    set start_IP_col [lindex [split [lindex $column_list end] "_"] 1]
                    set end_IP_col [lindex [split [lindex $column_list 0] "_"] 1]
                    findPossibilities $clk_re $dict_value_col_def $column_list $start_IP_col $end_IP_col $current_place $right $left $con_partition_side $possible_number
                } else {
                    for {set var 1} {$var <= $IP_lists_number} {incr var} {
                        if {[dict exist $clk_re_with_IPs $clk_re]} {
                            set start_IP_col [lindex [split [lindex [dict get $clk_re_with_IPs $clk_re [lindex [dict keys [dict get $clk_re_with_IPs $clk_re]] [expr $var - 1]]] 0] "_"] 1]
                            set end_IP_col [lindex [split [lindex $column_list end] "_"] 1]
                            set find_result [findPossibilities $clk_re $dict_value_col_def $column_list $start_IP_col $end_IP_col $current_place $right $left $con_partition_side $possible_number]
                            set possible_number [lindex $find_result 0]
                            set current_place [lindex $find_result 1]
                            if {$var == $IP_lists_number} {
                                set start_IP_col [lindex [split [lindex $column_list 0] "_"] 1]
                                set end_IP_col [lindex [split [lindex [dict get $clk_re_with_IPs $clk_re [lindex [dict keys [dict get $clk_re_with_IPs $clk_re]] [expr $var - 1]]] end] "_"] 1]
                                findPossibilities $clk_re $dict_value_col_def $column_list $start_IP_col $end_IP_col $current_place $right $left $con_partition_side $possible_number
                            }
                        } else {
                            set start_IP_col [lindex [split [lindex $column_list 0] "_"] 1]
                            set end_IP_col [lindex [split [lindex $column_list end] "_"] 1]
                            findPossibilities $clk_re $dict_value_col_def $column_list $start_IP_col $end_IP_col $current_place $right $left $con_partition_side $possible_number
                        }
                    }
                }
            } else {
                set dict_value_col_def [pairsDecreasing [subst $[subst column_def_${clk_re}]]]
                set column_list [dict keys $dict_value_col_def]
                set left no
                set right yes
                if {$IP_lists_number == 0} {
                    set start_IP_col [lindex [split [lindex $column_list end] "_"] 1]
                    set end_IP_col [lindex [split [lindex $column_list 0] "_"] 1]
                    findPossibilities $clk_re $dict_value_col_def $column_list $start_IP_col $end_IP_col $current_place $right $left $con_partition_side $possible_number
                } else {
                    for {set var 1} {$var <= $IP_lists_number} {incr var} {
                        if {[dict exist $clk_re_with_IPs $clk_re]} {
                            set end_IP_col [lindex [split [lindex [dict get $clk_re_with_IPs $clk_re [lindex [dict keys [dict get $clk_re_with_IPs $clk_re]] [expr $var - 1]]] end] "_"] 1]
                            set start_IP_col [lindex [split [lindex $column_list end] "_"] 1]
                            set find_result [findPossibilities $clk_re $dict_value_col_def $column_list $start_IP_col $end_IP_col $current_place $right $left $con_partition_side $possible_number]
                            set possible_number [lindex $find_result 0]
                            set current_place [lindex $find_result 1]
                            if {$var == $IP_lists_number} {
                                set end_IP_col [lindex [split [lindex $column_list 0] "_"] 1]
                                set start_IP_col [lindex [split [lindex [dict get $clk_re_with_IPs $clk_re [lindex [dict keys [dict get $clk_re_with_IPs $clk_re]] [expr $var - 1]]] 0] "_"] 1]
                                findPossibilities $clk_re $dict_value_col_def $column_list $start_IP_col $end_IP_col $current_place $right $left $con_partition_side $possible_number
                            } else {
                                set start_IP_col [lindex [split [lindex $column_list 0] "_"] 1]
                                set end_IP_col [lindex [split [lindex $column_list end] "_"] 1]
                                findPossibilities $clk_re $dict_value_col_def $column_list $start_IP_col $end_IP_col $current_place $right $left $con_partition_side $possible_number
                            }
                        }
                    }
                }
            }
        }
    }

}

# Find all position's possibilities for the maximum reconfigurable partition
# Starting with the first left placement column of a certain resource which is needed
# then find the next right placemnt column if the clock region is placed on the left 
# on the FPGA if on the right then do the same but starting from the right. Check if what 
# was found is enough, if no continues with the next left placement column then the next 
# right placement column and so on until there is enough resources found. If yes continues
# finding columns for the connection partition then start with the next clock region. 
proc findPossibilities {clk_re dict_value_col_def column_list start_IP_col end_IP_col current_place right left con_partition_side possible_number} {

    global max_resources
    global max_inserted_LUTs

    set needed_slicell [expr [dict get $max_resources {Logic LUTs}] + [dict get $max_resources FFs]]
    set needed_slicelm [expr [dict get $max_resources LUTRAMs] + [dict get $max_resources SRLs]]
    set needed_ram18 [dict get $max_resources RAMB18]
    set needed_ram36 [dict get $max_resources RAMB36]
    set needed_dsp [dict get $max_resources {DSP48 Blocks}]
    set needed_LUTs $max_inserted_LUTs

    set state init
    set col_placement_prev ""

    for {set var $current_place} {$var < [llength $column_list]} {incr var} {

        set key [lindex $column_list $var]
        set current_col_index [lindex [split $key "_"] 1]
        if {$current_col_index < $start_IP_col || $current_col_index > $end_IP_col} {
            # the wait variable let the state machine change its state value without changing the value of the key
            set wait true
            while {$wait} {
                set col_placement [dict get $dict_value_col_def $key column_placement]
                set col_kind [dict get $dict_value_col_def $key column_kind]

                switch $state {
                    init {
                        set needed_resources [dict create slicell $needed_slicell\
                                                            slicelm $needed_slicelm\
                                                            ram18 $needed_ram18\
                                                            ram36 $needed_ram36\
                                                            dsp $needed_dsp]
                        set rest_resources ""
                        set rest_region_resources ""
                        set remove_col ""
                        set found_region_resources ""
                        set found_region_resources_new ""
                        set found_con_resources ""
                        set rest_LUTs $needed_LUTs
                        set state idle
                        set add_status no
                        set wait true
                    }

                    idle {
                        set col_placement_result [findPlacement $col_placement]
                        if {$right eq yes && $col_placement_result eq "right"\
                            || $left eq yes && $col_placement_result eq "left"} {
                            set col_placement_prev $col_placement_result
                            set state needed
                            set wait true
                        } else {
                            set state idle
                            set wait false
                        }
                    }

                    needed {
                        if {[needed $max_resources $col_kind]} {
                            if {[lindex $column_list end] ne $key} {
                                set rest_resources [add $clk_re $key $col_kind $needed_resources $possible_number $add_status]
                                lappend found_region_resources "$key $col_kind"
                                set state find_next
                                set wait false
                            } else {
                                set state finish
                                set wait false
                            }
                        } else {
                            set state idle
                            set wait false
                        }
                    }

                    find_next {
                        if {[lindex $column_list end] ne $key} {
                            set col_placement_result [findPlacement $col_placement]
                            if {$col_placement_result eq "left" && $col_placement_prev eq "right" \
                                || $col_placement_result eq "right" && $col_placement_prev eq "left"} {
                                if {$right eq yes && $col_placement_result eq "left"\
                                    || $left eq yes && $col_placement_result eq "right"} {
                                    set rest_resources [add $clk_re $key $col_kind $rest_resources $possible_number $add_status]
                                    lappend found_region_resources "$key $col_kind"
                                    set col_placement_prev $col_placement_result
                                    set state is_enough
                                    set wait false
                                } else {
                                    set rest_resources [add $clk_re $key $col_kind $rest_resources $possible_number $add_status]
                                    lappend found_region_resources "$key $col_kind"
                                    set col_placement_prev $col_placement_result
                                    set state find_next
                                    set wait false
                                } 
                            } else {
                                set state find_next
                                set wait false
                            } 
                        } else {
                            set state finish
                            set wait false
                        }
                    }

                    is_enough {
                        if {![isEnough $rest_resources]} {
                            set state find_next
                            set wait true
                        } else {
                            set state reduce_region
                            set wait false
                        }
                    }

                    reduce_region {
                        set result_proc_remove [remove $found_region_resources]
                        set rest_resources [lindex $result_proc_remove 0]
                        set remove_col [lindex $result_proc_remove 1]
                        set state still_enough
                        set wait true
                    }

                    still_enough {
                        set rest_region_resources [maxRegionResources $rest_resources]
                        set found_region_resources $rest_resources
                        if {[stillEnough $rest_region_resources $needed_resources]} {
                            set state reduce_region
                            set wait true
                        } else {
                            lappend found_region_resources_new $remove_col
                            lappend found_region_resources_new $found_region_resources
#                            foreach {a b} $found_region_resources {
#                                lappend found_region_resources_new [lindex $a 0]
#                                lappend found_region_resources_new [lindex $b 0]
#                            }
                            set state find_con_partition
                            set wait true
                        }
                    }

                    find_con_partition {
                        if {[findCLB $col_kind]} {
                            set rest_LUTs [addLUT $clk_re $key $col_kind $rest_LUTs $possible_number $add_status]
                            lappend found_con_resources "$key $col_kind"
                            set state is_enough_LUTs
                            set wait false
                        } else {
                            set state find_con_partition
                            set wait false
                        }
                    }

                    is_enough_LUTs {
                        if {![isEnoughLUTs $rest_LUTs]} {
                            set state find_con_partition
                            set wait true
                        } else {
                            set add_status yes
                            set state add_possibility
                            set wait true
                        }
                    }

                    add_possibility {
                        add $clk_re $found_region_resources_new "" "" $possible_number $add_status
                        addLUT $clk_re $found_con_resources "" "" $possible_number $add_status
                        set state init
                        incr possible_number
                        set wait false
                    }

                    finish {
                        set state finish
                        set wait false
                    }

                    default {}
                }
            }
        } else {
            return "$possible_number $var"
        }
    }

}

# Find the column placement
proc findPlacement {placement} {

    if {[string match -nocase "l" $placement]} {
        return "left"
    } else {
        return "right"
    }
}

# Check if the column is a CLB column
proc findCLB {kind} {

    if {[string match -nocase "clbll*" $kind] || [string match -nocase "clel*" $kind]} {
        return 1
    } else {
        return 0
    }
}

# Checking if the resource of the first left placement column is needed 
proc needed {resources kind} {

    switch -nocase $kind {
        clbll {
            set needed_slicell [expr [dict get $resources {Logic LUTs}] + [dict get $resources FFs]]
            if {$needed_slicell != 0} {
                return 1
            } else {
                return 0
            }
        }

        clblm {
            set needed_slicelm [expr [dict get $resources LUTRAMs] + [dict get $resources SRLs]]
            set needed_slicell [expr [dict get $resources {Logic LUTs}] + [dict get $resources FFs]]
            if {$needed_slicelm != 0 || $needed_slicell != 0} {
                return 1
            } else {
                return 0
            }
        }

        clel {
            set needed_slicell [expr [dict get $resources {Logic LUTs}] + [dict get $resources FFs]]
            if {$needed_slicell != 0} {
                return 1
            } else {
                return 0
            }
        }

        clem {
            set needed_slicelm [expr [dict get $resources LUTRAMs] + [dict get $resources SRLs]]
            set needed_slicell [expr [dict get $resources {Logic LUTs}] + [dict get $resources FFs]]
            if {$needed_slicelm != 0 || $needed_slicell != 0} {
                return 1
            } else {
                return 0
            }
        }

        bram {
            set needed_ram18 [dict get $resources RAMB18]
            set needed_ram36 [dict get $resources RAMB36]
            if {$needed_ram18 != 0 || $needed_ram36 != 0} {
                return 1
            } else {
                return 0
            }
        }

        dsp {
            set needed_dsp [dict get $resources {DSP48 Blocks}]
            if {$needed_dsp != 0} {
                return 1
            } else {
                return 0
            }
        }

        default {return 0}
    }
}

# Create a dictionary with all position's possibilities for each clock region
# for the max reconfigurable module and each time the column is added 
# to the possible list, the amount of the max needed resources will 
# be reduced until all resources was found.
proc add {clk_region columns col_kind rest_resources possible_number add_status} {

    global possible_positions
    global slicell_per_llcol
    global slicell_per_lmcol
    global slicelm_per_llcol
    global slicelm_per_lmcol
    global ram_18_per_col
    global ram_36_per_col
    global dsp_per_col

    switch -nocase $col_kind {
        clbll {
            set rest_slicell [dict get $rest_resources slicell]
            set rest_slicelm [dict get $rest_resources slicelm]
            set used_slicell $slicell_per_llcol
            set used_slicelm $slicelm_per_llcol
            if {$rest_slicell > $used_slicell } {
                dict set rest_resources slicell [expr $rest_slicell - $used_slicell]
            } else {
                dict set rest_resources slicell 0
            }
            if {$rest_slicelm > $used_slicelm } {
                dict set rest_resources slicelm [expr $rest_slicelm - $used_slicelm]
            } else {
                dict set rest_resources slicelm 0
            }
        }

        clblm {
            set rest_slicell [dict get $rest_resources slicell]
            set rest_slicelm [dict get $rest_resources slicelm]
            set used_slicell $slicell_per_lmcol
            set used_slicelm $slicelm_per_lmcol
            if {$rest_slicell > $used_slicell } {
                dict set rest_resources slicell [expr $rest_slicell - $used_slicell]
            } else {
                dict set rest_resources slicell 0
            }
            if {$rest_slicelm > $used_slicelm } {
                dict set rest_resources slicelm [expr $rest_slicelm - $used_slicelm]
            } else {
                dict set rest_resources slicelm 0
            }
        }

        clel {
            set rest_slicell [dict get $rest_resources slicell]
            set rest_slicelm [dict get $rest_resources slicelm]
            set used_slicell $slicell_per_llcol
            set used_slicelm $slicelm_per_llcol
            if {$rest_slicell > $used_slicell } {
                dict set rest_resources slicell [expr $rest_slicell - $used_slicell]
            } else {
                dict set rest_resources slicell 0
            }
            if {$rest_slicelm > $used_slicelm } {
                dict set rest_resources slicelm [expr $rest_slicelm - $used_slicelm]
            } else {
                dict set rest_resources slicelm 0
            }
        }

        clem {
            set rest_slicell [dict get $rest_resources slicell]
            set rest_slicelm [dict get $rest_resources slicelm]
            set used_slicell $slicell_per_lmcol
            set used_slicelm $slicelm_per_lmcol
            if {$rest_slicell > $used_slicell } {
                dict set rest_resources slicell [expr $rest_slicell - $used_slicell]
            } else {
                dict set rest_resources slicell 0
            }
            if {$rest_slicelm > $used_slicelm } {
                dict set rest_resources slicelm [expr $rest_slicelm - $used_slicelm]
            } else {
                dict set rest_resources slicelm 0
            }
        }

        bram {
            set rest_ram18 [dict get $rest_resources ram18]
            set rest_ram36 [dict get $rest_resources ram36]
            set used_ram18 $ram_18_per_col
            set used_ram36 $ram_36_per_col
            if {$rest_ram18 > $used_ram18 } {
                dict set rest_resources ram18 [expr $rest_ram18 - $used_ram18]
            } else {
                dict set rest_resources ram18 0
            }
            if {$rest_ram36 > $used_ram36 } {
                dict set rest_resources ram36 [expr $rest_ram36 - $used_ram36]
            } else {
                dict set rest_resources ram36 0
            }
        }

        dsp {
            set rest_dsp [dict get $rest_resources dsp]
            set used_dsp $dsp_per_col
            if {$rest_dsp > $used_dsp } {
                dict set rest_resources dsp [expr $rest_dsp - $used_dsp]
            } else {
                dict set rest_resources dsp 0
            }
        }

        default {}
    }

    # If the column number is larger than the last column number in the list it will be placed at the end 
    # if not it will be placed at the beginning
    if {$add_status eq yes} {
        foreach subcolumns $columns {
            foreach column $subcolumns {
                set col_number [lindex [split [lindex $column 0] "_"] 1]
                if {[dict exists $possible_positions $clk_region] == 0} {
                    dict set possible_positions $clk_region module_possible_$possible_number $column
                } else {
                    if {[dict exists $possible_positions $clk_region module_possible_$possible_number] == 0} {
                        dict set possible_positions $clk_region module_possible_$possible_number $column
                    } else {
                        set col_list [dict get $possible_positions $clk_region module_possible_$possible_number]
                        set last_col_number_in_the_list [lindex [split [lindex $col_list end-1] "_"] 1]
                        if { $col_number < $last_col_number_in_the_list} {
                            dict set possible_positions $clk_region module_possible_$possible_number [concat $column [lrange $col_list 0 end]]
                        } else {
                            dict set possible_positions $clk_region module_possible_$possible_number [concat [lrange $col_list 0 end] $column]
                        }
                    }
                }
            }
        }
    }

    return $rest_resources
}

# In this procedure, the two left-placed columns of the RP
# are removed to reduce the total size of the RP found
proc remove {found_resources} {

#    set new_list [lrange $found_resources 2 end]
#    set remove_col [lindex [lindex $found_resources 0] 0]
#    lappend remove_col [lindex [lindex $found_resources 1] 0]

#    return "{$new_list} {$remove_col}"

    set new_list [lrange $found_resources 2 end]
    set remove_col [lrange $found_resources 0 1]

    return "{$new_list} {$remove_col}"
}

# This procedure calculates the remaining resources and insert them into a new array
proc maxRegionResources {resources} {

    global slicell_per_llcol
    global slicell_per_lmcol
    global slicelm_per_llcol
    global slicelm_per_lmcol
    global ram_18_per_col
    global ram_36_per_col
    global dsp_per_col
    global product_family

    if {[string match -nocase "*uplus" $product_family]} {
        set CLBLL_cols [llength [lsearch -all -inline -index 1 $resources "CLEL"]]
        set CLBLM_cols [llength [lsearch -all -inline -index 1 $resources "CLEM"]]
    } else {
        set CLBLL_cols [llength [lsearch -all -inline -index 1 $resources "CLBLL"]]
        set CLBLM_cols [llength [lsearch -all -inline -index 1 $resources "CLBLM"]]
    }
    set BRAM_cols [llength [lsearch -all -inline -index 1 $resources "BRAM"]]
    set DSP_cols [llength [lsearch -all -inline -index 1 $resources "DSP"]]

    set resource [dict create ]

    dict set resource slicell [expr [expr $slicell_per_llcol * $CLBLL_cols] + [expr $slicell_per_lmcol * $CLBLM_cols]]
    dict set resource slicelm [expr [expr $slicelm_per_llcol * $CLBLL_cols] + [expr $slicelm_per_lmcol * $CLBLM_cols]]
    dict set resource ram18 [expr $ram_18_per_col * $BRAM_cols]
    dict set resource ram36 [expr $ram_36_per_col * $BRAM_cols]
    dict set resource dsp [expr $dsp_per_col * $DSP_cols]

    return $resource
}

# Create a dictionary with all position's possibilities for each clock region
# for the max connection partion and each time the column is added to 
# the possible list, the amount of the max needed resources will be 
# reduced until all resources was found.
proc addLUT {clk_region column col_kind rest_LUTs possible_number add_status} {

    global possible_positions
    global slicell_per_llcol
    global slicell_per_lmcol

    switch -nocase $col_kind {
        clbll {
            set used_slicell $slicell_per_llcol
            if {$rest_LUTs > $used_slicell} {
                set rest_LUTs [expr $rest_LUTs - $used_slicell]
            } else {
                set rest_LUTs 0
            }
        }

        clblm {
            set used_slicell $slicell_per_lmcol
            if {$rest_LUTs > $used_slicell} {
                set rest_LUTs [expr $rest_LUTs - $used_slicell]
            } else {
                set rest_LUTs 0
            }
        }

        clel {
            set used_slicell $slicell_per_llcol
            if {$rest_LUTs > $used_slicell} {
                set rest_LUTs [expr $rest_LUTs - $used_slicell]
            } else {
                set rest_LUTs 0
            }
        }

        clem {
            set used_slicell $slicell_per_lmcol
            if {$rest_LUTs > $used_slicell} {
                set rest_LUTs [expr $rest_LUTs - $used_slicell]
            } else {
                set rest_LUTs 0
            }
        }

        default {}
    }

    # If the column number is larger than the last column number in the list it will be placed at the end 
    # if not it will be placed at the beginning
    if {$add_status eq yes} {
        foreach subcolumns $column {
                set col_number [lindex [split [lindex $subcolumns 0] "_"] 1]
                if {[dict exists $possible_positions $clk_region con_possible_$possible_number] == 0} {
                    dict set possible_positions $clk_region con_possible_$possible_number $subcolumns
                } else {
                    set col_list [dict get $possible_positions $clk_region con_possible_$possible_number]
                    set last_col_number_in_the_list [lindex [split [lindex [dict get $possible_positions $clk_region con_possible_$possible_number] end] "_"] 1]
                    if { $col_number < $last_col_number_in_the_list} {
                        dict set possible_positions $clk_region con_possible_$possible_number [concat $subcolumns [lrange $col_list 0 end]]
                    } else {
                        dict set possible_positions $clk_region con_possible_$possible_number [concat [lrange $col_list 0 end] $subcolumns]
                    }
                }
        }
    }

        return $rest_LUTs
}

# Checking if all needed resources was found
proc isEnough {rest_resources} {

    set rest_slicell [dict get $rest_resources slicell]
    set rest_slicelm [dict get $rest_resources slicelm]
    set rest_ram18 [dict get $rest_resources ram18]
    set rest_ram36 [dict get $rest_resources ram36]
    set rest_dsp [dict get $rest_resources dsp]

    if {$rest_slicell == 0 && $rest_slicelm == 0 && $rest_ram18 == 0 && $rest_ram36 == 0 && $rest_dsp == 0} {
        return 1
    } else {
        return 0
    }
}

# Checking if the resources inside the RP are still
# enough. This check is after the reduce procedure.
proc stillEnough {rest_resources needed_resources} {

    set rest_slicell [dict get $rest_resources slicell]
    set rest_slicelm [dict get $rest_resources slicelm]
    set rest_ram18 [dict get $rest_resources ram18]
    set rest_ram36 [dict get $rest_resources ram36]
    set rest_dsp [dict get $rest_resources dsp]
    set needed_slicell [dict get $needed_resources slicell]
    set needed_slicelm [dict get $needed_resources slicelm]
    set needed_ram18 [dict get $needed_resources ram18]
    set needed_ram36 [dict get $needed_resources ram36]
    set needed_dsp [dict get $needed_resources dsp]

    if {$rest_slicell >= $needed_slicell && $rest_slicelm >= $needed_slicelm \
        && $rest_ram18 >= $needed_ram18 && $rest_ram36 >= $needed_ram36 \
        && $rest_dsp >= $needed_dsp} {
        return 1
    } else {
        return 0
    }

}

# Checking if all needed LUTs was found
proc isEnoughLUTs {LUTs} {

    set rest_LUTs $LUTs

    if {$rest_LUTs == 0} {
        return 1
    } else {
        return 0
    }
}

# Get the first X and Y values of the logic element inside a tile
proc getFirstOfAll {entries} {

    set all_X_entries [dict create ]
    set all_Y_entries [dict create ]

    for {set var 0} {$var < [llength $entries]} {incr var} {
        set entry_$var [lindex [split [lindex [split [lindex $entries $var] "X"] 1] "Y"] 0]
        dict lappend all_X_entries [subst $[subst entry_$var]] [lindex $entries $var]
    }

    if {[llength [dict keys $all_X_entries]] < 2} {
        set key [dict keys $all_X_entries]
        for {set var 0} {$var < [llength [dict get $all_X_entries $key]]} {incr var} {
            set entry_$var [lindex [split [lindex [dict get $all_X_entries $key] $var] "Y"] 1]
            dict lappend all_Y_entries [subst $[subst entry_$var]] [lindex [dict get $all_X_entries $key] $var]
        }
        set Y_min [min {*}[dict keys $all_Y_entries]]
        return [dict get $all_Y_entries $Y_min]
    } else {
        set X_min [min {*}[dict keys $all_X_entries]]
        return [dict get $all_X_entries $X_min]
    }
}

# Get the last X and Y values of the logic element inside a tile
proc getLastOfAll {entries} {

    set all_X_entries [dict create ]
    set all_Y_entries [dict create ]

    for {set var 0} {$var < [llength $entries]} {incr var} {
        set entry_$var [lindex [split [lindex [split [lindex $entries $var] "X"] 1] "Y"] 0]
        dict lappend all_X_entries [subst $[subst entry_$var]] [lindex $entries $var]
    }

    if {[llength [dict keys $all_X_entries]] < 2} {
        set key [dict keys $all_X_entries]
        for {set var 0} {$var < [llength [dict get $all_X_entries $key]]} {incr var} {
            set entry_$var [lindex [split [lindex [dict get $all_X_entries $key] $var] "Y"] 1]
            dict lappend all_Y_entries [subst $[subst entry_$var]] [lindex [dict get $all_X_entries $key] $var]
        }
        set Y_max [max {*}[dict keys $all_Y_entries]]
        return [dict get $all_Y_entries $Y_max]
    } else {
        set X_max [max {*}[dict keys $all_X_entries]]
        return [dict get $all_X_entries $X_max]
    }
}

# Find all logic elements inside a tile
proc findEntry {clk_re_name value filter_name} {

    global $clk_re_name

    foreach row [dict keys [subst $$clk_re_name]] {
        if {[lsearch [dict get [subst $$clk_re_name] $row] $value] != -1} {
            set entries [lsearch -nocase -all -inline [dict get [subst $$clk_re_name] $row $value] $filter_name]
        }
    }
    if {$entries ne ""} {
        return $entries
    } else {
        return "Null"
    }
}

# Find for the given site its tile
proc findTile {clk_re_name filter_name} {

    global $clk_re_name

    set tile_name ""

    foreach row [dict keys [subst $$clk_re_name]] {
		foreach tile [dict keys [dict get [subst $$clk_re_name] $row]] {
		    if {[lsearch [dict get [subst $$clk_re_name] $row $tile] $filter_name] != -1} {
		        set tile_name $tile
		    }
		}
	}
    return $tile_name
}

# Find all X and Y values of the logic elements inside the tiles which will be used 
# in further steps to create the pblocks for reconfigurable partitions and connection
# partitions in vivado. 
proc findFirstLastElements {clk_re_name possible} {

    global possible_positions
    global one_big_column_list_$clk_re_name

    set value [dict get $possible_positions $clk_re_name $possible]
    set first_slice ""
    set last_slice ""
    set first_dsp ""
    set last_dsp ""
    set first_bram_18 ""
    set first_bram_36 ""
    set last_bram_18 ""
    set last_bram_36 ""
    foreach {col kind} $value {
        set col_entries [dict get [subst $[subst one_big_column_list_$clk_re_name]] $col]
        set first_entry [lindex $col_entries 0]
        set last_entry [lindex $col_entries end]
        if {[string match -nocase "clb*" $first_entry] || [string match -nocase "cle*" $first_entry]} {
            if {$first_slice eq ""} {
                set elements_of_tile [findEntry $clk_re_name $last_entry "slice*"]
                set first_slice [getFirstOfAll $elements_of_tile]
                set elements_of_tile [findEntry $clk_re_name $first_entry "slice*"]
                set last_slice [getLastOfAll $elements_of_tile]
            } else {
                set elements_of_tile [findEntry $clk_re_name $first_entry "slice*"]
                set last_slice [getLastOfAll $elements_of_tile]
            }
        } elseif {[string match -nocase "bram*" $first_entry]} {
            if {$first_bram_18 eq ""} {
                set elements_of_tile_ram_18 [findEntry $clk_re_name $last_entry "ramb18*"]
                set first_bram_18 [getFirstOfAll $elements_of_tile_ram_18]
                set elements_of_tile_ram_18 [findEntry $clk_re_name $first_entry "ramb18*"]
                set last_bram_18 [getLastOfAll $elements_of_tile_ram_18]
                set elements_of_tile_ram_36 [findEntry $clk_re_name $last_entry "ramb36*"]
                set first_bram_36 [getFirstOfAll $elements_of_tile_ram_36]
                set elements_of_tile_ram_36 [findEntry $clk_re_name $first_entry "ramb36*"]
                set last_bram_36 [getLastOfAll $elements_of_tile_ram_36]
            } else {
                set elements_of_tile_ram_18 [findEntry $clk_re_name $first_entry "ramb18*"]
                set last_bram_18 [getLastOfAll $elements_of_tile_ram_18]
                set elements_of_tile_ram_36 [findEntry $clk_re_name $first_entry "ramb36*"]
                set last_bram_36 [getLastOfAll $elements_of_tile_ram_36]
            }
        } elseif {[string match -nocase "dsp*" $first_entry]} {
            if {$first_dsp eq ""} {
                set elements_of_tile [findEntry $clk_re_name $last_entry "dsp*"]
                set first_dsp [getFirstOfAll $elements_of_tile]
                set elements_of_tile [findEntry $clk_re_name $first_entry "dsp*"]
                set last_dsp [getLastOfAll $elements_of_tile]
            } else {
                set elements_of_tile [findEntry $clk_re_name $first_entry "dsp*"]
                set last_dsp [getLastOfAll $elements_of_tile]
            }
        }
    }
    set elements_list [list $first_slice $last_slice $first_bram_18 $last_bram_18 $first_bram_36 $last_bram_36 $first_dsp $last_dsp]
    set no_empty_list [lsearch -all -inline -not -exact $elements_list {}]
    
    return $no_empty_list
    
}

# This function edit the list of the logic elements from (logic_element_X_Y logic_element_X_Y) 
# to (logic_element_X_Y:logic_element_X_Y) so that it can be used in vivado 
# to allocate the start and the end of the X and Y values to create the pblock
proc setLocation {positions} {

    set vivado_location ""
    foreach {a b} $positions {
        lappend vivado_location [concat $a:$b]
    }
    return $vivado_location
}

# This function edit the list of the inserted LUTs from (LUT_variable_name_1 LUT_variable_name_2 ...)
# to (parent/.../wrapper_name/LUT_variable_name_1 parent/.../wrapper_name/LUT_variable_name_2 ...) 
# so that it can be used in vivado to assign all LUT cells to the connection pblock
proc setFullLUTPath {wrapper_name LUTs_list} {

    set vivado_LUT_names ""
    foreach var $LUTs_list {
        lappend vivado_LUT_names $wrapper_name/$var
    }
    return $vivado_LUT_names
}

# In this procedure, all found placement possibilities for the RPs are divided into separate groups.
# Each group involves RPs that conatin the same resource arrangement.
proc classify {} {

    global possible_positions
    global classify_lists

    set classify_lists_local_kind [dict create ]
    set classify_lists_local_loc [dict create ]
    set possible [dict create ]

    if {$possible_positions eq ""} {
        set errMsg "\n ERROR: There are no placement possibilities, so that the design can be used for relocation.\n"
        error $errMsg
    }

    foreach clk_re [dict keys $possible_positions] {
        set possible_lists_rp [lsearch -all -inline [dict keys [dict get $possible_positions $clk_re]] "module*"]
        set possible_lists_cp [lsearch -all -inline [dict keys [dict get $possible_positions $clk_re]] "con*"]
        for {set var 0} {$var < [llength $possible_lists_rp]} {incr var} {
            dict update possible $clk_re varkey {
                dict lappend varkey [lindex $possible_lists_rp $var] [lindex $possible_lists_cp $var]
            }
        }
        foreach {possbl_mod possbl_con} [dict get $possible $clk_re] {
            set columns_mod [dict get $possible_positions $clk_re $possbl_mod]
            set columns_con [dict get $possible_positions $clk_re $possbl_con]
            set possbl_number [lindex [split $possbl_mod "_"] end]
            dict set classify_lists_local_kind $clk_re possible_${possbl_number} $possbl_mod ""
            dict set classify_lists_local_loc $clk_re possible_${possbl_number} $possbl_mod ""
            foreach col $columns_mod {
                if {![string match -nocase "col_*" $col]} {
                    set column_kind_mod $col
                    dict with classify_lists_local_kind {
                        dict update $clk_re possible_${possbl_number} varkey {
                            dict lappend varkey $possbl_mod $column_kind_mod
                        }
                    }
                } else {
                    set column_loc_mod $col
                    dict with classify_lists_local_loc {
                        dict update $clk_re possible_${possbl_number} varkey {
                            dict lappend varkey $possbl_mod $column_loc_mod
                        }
                    }
                }
            }
            set column_kind_con [lindex $columns_con 1]
            set column_loc_con [lindex $columns_con 0]
            dict with classify_lists_local_kind {
                dict update $clk_re possible_${possbl_number} varkey {
                    dict lappend varkey $possbl_con $column_kind_con
                }
            }
            dict with classify_lists_local_loc {
                dict update $clk_re possible_${possbl_number} varkey {
                    dict lappend varkey $possbl_con $column_loc_con
                }
            }
        }
    }
    set state init
    set class_nr 0
    set all_possible $classify_lists_local_kind
    set all_possible_new $classify_lists_local_kind
    while {$all_possible ne ""} {
        switch $state {
            init {
                set all_possible $all_possible_new
                dict set classify_lists class_$class_nr [lindex [dict keys $all_possible] 0] [lindex [dict keys [dict get $all_possible [lindex [dict keys $all_possible] 0]]] 0]
                set template_footprint_clk_re [lindex [dict get $classify_lists [lindex [dict keys $classify_lists] $class_nr]] 0]
                set template_footprint_possible [lindex [dict get $classify_lists [lindex [dict keys $classify_lists] $class_nr] $template_footprint_clk_re] 0]
                set template_footprint [dict get $classify_lists_local_kind $template_footprint_clk_re $template_footprint_possible]
                set template_last_col_num_in_RP [lindex [dict get $classify_lists_local_loc $template_footprint_clk_re $template_footprint_possible module_${template_footprint_possible}] end]
                set template_col_num_in_CP [dict get $classify_lists_local_loc $template_footprint_clk_re $template_footprint_possible con_${template_footprint_possible}]
                set template_RP_CP_distance [expr [lindex [split $template_col_num_in_CP "_"] 1] - [lindex [split $template_last_col_num_in_RP "_"] 1]]
                dict set classify_lists class_$class_nr [lindex [dict keys $all_possible] 0] ""
                set all_possible_new ""
                set state compare
            }

            compare {
                foreach clk_re [dict keys $all_possible] {
                    foreach possible [dict keys [dict get $all_possible $clk_re]] {
                        set footprint [dict get $classify_lists_local_kind $clk_re $possible]
                        set last_col_num_in_RP [lindex [dict get $classify_lists_local_loc $clk_re $possible module_${possible}] end]
                        set col_num_in_CP [dict get $classify_lists_local_loc $clk_re $possible con_${possible}]
                        if {([dict get $template_footprint [lindex [dict keys $template_footprint] 0]] eq [dict get $footprint [lindex [dict keys $footprint] 0]]) \
                            && ([dict get $template_footprint [lindex [dict keys $template_footprint] 1]] eq [dict get $footprint [lindex [dict keys $footprint] 1]])} {
                            set RP_CP_distance [expr [lindex [split $col_num_in_CP "_"] 1] - [lindex [split $last_col_num_in_RP "_"] 1]]
                            if {$template_RP_CP_distance == $RP_CP_distance} {
                                dict update classify_lists class_$class_nr varkey {
                                    dict lappend varkey $clk_re $possible
                                }
                            } else {
                                dict update all_possible_new $clk_re varkey {
                                    dict lappend varkey $possible $footprint
                                }
                            }
                        }
                    }
                }
                set state no_more_entries
            }

            no_more_entries {
                if {$all_possible_new ne ""} {
                    set state init
                    incr class_nr
                } else {
                    set state finish
                }
            }

            finish {
                set all_possible $all_possible_new
            }

            default {}
        }
    }

    set class_keys [dict keys $classify_lists]
    if {[llength $class_keys] == 1} {
        set clk_keys [dict keys [dict get $classify_lists $class_keys]]
        if {[llength $clk_keys] == 1} {
            set possible_values [dict get $classify_lists $class_keys $clk_keys]
            if {[llength $possible_values] == 1} {
                set errMsg "\n ERROR: There is only one placement possibility to place the RP, there must be at least two possibilities in order to perform relocation.\n"
                error $errMsg
            }
        }
    }
}
