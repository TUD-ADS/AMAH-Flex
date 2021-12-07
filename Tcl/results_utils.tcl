#################################################################################################
## Description: TCL script to get information for each RM from the synthesize utilization      ##
## reports (e.g. total LUTs number, total DSPs number ....) and which names Vivado gives for   ##
## the wrapper instances                                                                       ##
## This file contains the following procs:                                                     ##
## - getInformation {reports start_word}                                                       ##
## - findAllReports {modules filter_word}                                                      ##
## - getVivadoWrapperNames {names wrappers_path}                                               ##
## - maxOfBoth {first_num second_num}                                                          ##
## - maximum {all_rms first_RM next_RM}                                                        ##
## - setMaximumRP {all_rms}                                                                    ##
## - getMaxRP {all_rms}                                                                        ##
## - LUTFilter {key args}                                                                      ##
## - getLUT2 {_file filter_words}                                                              ##
## - getMaxLUTs {LUTs}                                                                         ##
##                                                                                             ##
## Created by: Najdet Charaf                                                                   ##
#################################################################################################

namespace import ::tcl::mathfunc::max

# Open the report file and read all needed resources and then save them in the respective dictionary
proc getInformation {reports start_word} {

    set all_RMs [dict create ]

    foreach key [dict keys $reports] {
        set _info ""
        set header_entries [list ]
        set values [list ]
        set start 0
        set next_word 0
        set start_table 0

        # open report files and read how many resources are needed
        set fp [open [dict get $reports $key]]
        while {[gets $fp line] >= 0} {
            if {[regexp -nocase -- $start_word $line]} {
                set start 1
            } 
            if {$start == 1} {
                if {[string match -nocase "+*" $line] || $start_table == 1} {
                    set start_table 1
                }
            }
            if {$start_table == 1} {
                if {[string match -nocase "+*" $line]} {
                    set next_word 1
                } elseif {$next_word == 1} {
                    if {$line ne "" && ![string match -nocase "-*" $line]} {
                        lappend _info $line
                        set next_word 0
                    } else {
                        set start 0
                        set start_table 0 
                    }
                } else {
                    lappend _info $line
                }
            }
        }
        close $fp

        # delete all empty elements and split the entries so that just header entry will be saved 
        foreach var [lsearch -all -inline -not -exact [split [lindex $_info 0] "|"] {}] {

            if {[string trim $var] eq ""} {
                set var "Null"
            }
            lappend header_entries [string trim $var]
        }

        set _info [lrange $_info 1 end]

        # delete all empty elements and split the entries so that just the values which belong to the header entry will be saved
        foreach line $_info {
            foreach var [lsearch -all -inline -not -exact [split $line "|"] {}] {
                lappend values [string trim $var]
            }
        }

        # now save each header/value pair together
        for {set value 0} {$value < [llength $values]} {incr value [llength $header_entries]} {
            for {set var 0} {$var < [llength $header_entries]} {incr var} {
                dict update all_RMs $key varkey {
                    dict lappend varkey [lindex $header_entries $var] [lindex $values [expr $var + $value]]
                }
            }
        }
    }

    return $all_RMs
}

# Find all synthesize utilization reports for each reconfigurable module
proc findAllReports {modules filter_word} {

    foreach module $modules {
        dict set report_files $module [glob ./Synth/$module/*$filter_word]
    }
    return $report_files
}

# Find which names Vivado gives to the wrapper instances 
proc getVivadoWrapperNames {names wrappers_path} {

    foreach path $wrappers_path {
        set wrapper_parent [lindex [split $path "/"] 0]
        set path_length [llength [split $path "/"]]
        set parent_position [lsearch [dict get $names static Instance] $wrapper_parent]
        set vi_wrapper_name [lindex [dict get $names static Module] [expr $parent_position + [expr $path_length - 1]]]
        dict lappend names_list $path $vi_wrapper_name
    }
    return $names_list
}

# Return the maximum of tow numbers
proc maxOfBoth {first_num second_num} {

    return [max $first_num  $second_num]
}

# Create a maximum reconfigurable module which contains the maximum amount of resources of the two reconfigurable modules 
proc maximum {all_rms first_RM next_RM} {

    global $all_rms vivado_version

    set slice_LL_f_RM [dict get [subst $$all_rms] $first_RM {Logic LUTs}]
    set slice_LL_n_RM [dict get [subst $$all_rms] $next_RM {Logic LUTs}]
    set slice_LRAM_f_RM [dict get [subst $$all_rms] $first_RM LUTRAMs]
    set slice_LRAM_n_RM [dict get [subst $$all_rms] $next_RM LUTRAMs]
    set slice_LSRL_f_RM [dict get [subst $$all_rms] $first_RM SRLs]
    set slice_LSRL_n_RM [dict get [subst $$all_rms] $next_RM SRLs]
    set FFs_f_RM [dict get [subst $$all_rms] $first_RM FFs]
    set FFs_n_RM [dict get [subst $$all_rms] $next_RM FFs]
    set RAMB36_f_RM [dict get [subst $$all_rms] $first_RM RAMB36]
    set RAMB36_n_RM [dict get [subst $$all_rms] $next_RM RAMB36]
    set RAMB18_f_RM [dict get [subst $$all_rms] $first_RM RAMB18]
    set RAMB18_n_RM [dict get [subst $$all_rms] $next_RM RAMB18]
    # TODO check other vivado versions
	if {$vivado_version == 2020.2} { 
		set DSP_f_RM [dict get [subst $$all_rms] $first_RM {DSP Blocks}]
		set DSP_n_RM [dict get [subst $$all_rms] $next_RM {DSP Blocks}]
	} else {
		#2020.2 changed DSP naming to "DSP Blocks"
        set DSP_f_RM [dict get [subst $$all_rms] $first_RM {DSP48 Blocks}] 
		set DSP_n_RM [dict get [subst $$all_rms] $next_RM {DSP48 Blocks}]
	}
    
    set max_slice_LL [maxOfBoth $slice_LL_f_RM $slice_LL_n_RM]
    set max_slice_LRAM [maxOfBoth $slice_LRAM_f_RM $slice_LRAM_n_RM]
    set max_slice_LSRL [maxOfBoth $slice_LSRL_f_RM $slice_LSRL_n_RM]
    set max_FFs [maxOfBoth $FFs_f_RM $FFs_n_RM]
    set max_RAMB36 [maxOfBoth $RAMB36_f_RM $RAMB36_n_RM]
    set max_RAMB18 [maxOfBoth $RAMB18_f_RM $RAMB18_n_RM]
    set max_DSP [maxOfBoth $DSP_f_RM $DSP_n_RM]

    dict set $all_rms max_module {Logic LUTs} $max_slice_LL
    dict set $all_rms max_module LUTRAMs $max_slice_LRAM
    dict set $all_rms max_module SRLs $max_slice_LSRL
    dict set $all_rms max_module FFs $max_FFs
    dict set $all_rms max_module RAMB36 $max_RAMB36
    dict set $all_rms max_module RAMB18 $max_RAMB18
    dict set $all_rms max_module {DSP48 Blocks} $max_DSP

}

# Finding the maximum of resources to create a max reconfigurable partition which contains all needed resources
proc setMaximumRP {all_rms} {

    global $all_rms

    set all_keys [dict keys [subst $$all_rms]]
    set next_index 2

    set max_PR [maximum $all_rms [lindex $all_keys 0] [lindex $all_keys 1]]

    if {[llength $all_keys] > 2} {
        while {$next_index < [llength $all_keys]} {
            set max_PR [maximum $all_rms max_module [lindex $all_keys $next_index]]
            incr next_index
        }
    }
}

# Getting the maximum reconfigurable module which contains the maximum of resources plus 20% more
# for routing resources, this percentage can be reduced in future work.
proc getMaxRP {all_rms} {

    global $all_rms

    set resources [dict get [subst $$all_rms] max_module]
    set LL [dict get $resources {Logic LUTs}]
    set FF [dict get $resources FFs]
    set LUTRAM [dict get $resources LUTRAMs]
    set SRL [dict get $resources SRLs]
    set 20_percent_more_ll [expr $LL * 20 / 100]
    set 20_percent_more_ff [expr $FF * 20 / 100]
    set 20_percent_more_lutram [expr $LUTRAM * 20 / 100]
    set 20_percent_more_srl [expr $SRL * 20 / 100]
    dict set resources {Logic LUTs} [expr $20_percent_more_ll + $LL]
    dict set resources FFs [expr $20_percent_more_ff + $FF]
    dict set resources LUTRAMs [expr $20_percent_more_lutram + $LUTRAM]
    dict set resources SRLs [expr $20_percent_more_srl + $SRL]

    return $resources
}

# Filter the line which was found in the .edif file 
# find just the variable name for the inserted LUT
proc LUTFilter {key args} {

    global inserted_LUTs

    set new_list [lsearch -all -inline -not -exact [split $args] {}]
    foreach var $new_list {
        if {[string match -nocase "LUT*_*" $var]} {
            dict lappend inserted_LUTs $key $var
        }
    }
}

# Find all inserted LUTs for each reconfigurable module which are placed 
# in the wrapper VHDL file by the user 
proc setLUTs {_file filter_words} {

    foreach key [dict keys $filter_words] {
        set word [dict get $filter_words $key]
        set _info_$word ""
        set start 0
        set start_cell 0

        # open report files and read how many resources are needed
        set fp [open [dict get $_file static]]
        while {[gets $fp line] >= 0} {
            if {[regexp -nocase -- "cell " $line]} {
                set start_cell 1
            } elseif {$start_cell == 1} {
                if {[regexp -nocase -- "view $word " $line]} {
                    set start 1
                    set start_cell 0
                } else {
                    set start 0
                    set start_cell 0
                } 
            } elseif {$start == 1} {
                lappend _info_$word $line
            }
        }
        close $fp
        set _info_$word [lsearch -nocase -all -inline [subst $[subst _info_$word]] "*instance LUT*"]
        LUTFilter $key [subst $[subst _info_$word]]
    }
}

# Find the maximun number of the inserted LUTs in all wrappers which contain the reconfigurable modules 
proc getMaxLUTs {LUTs} {

    global $LUTs

    set max_number 0

    foreach key [dict keys [subst $$LUTs]] {
        set LUTs_number [llength [dict get [subst $$LUTs] $key]]
        set max_number [max $max_number $LUTs_number]
    }

    return $max_number
}
