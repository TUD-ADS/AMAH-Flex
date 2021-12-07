#################################################################################################
## Description: TCL script to modify the layout of implemented module in the RPs to increase   ## 
## the flexibility.in the Implementation directory.                                            ##
##                                                                                             ##
## Created by: Roel Oomen                                                                      ##
## Extended and improved by: Najdet Charaf                                                     ##
#################################################################################################

    proc copy_placement {} {
	    copy_BEL_placement
	    copy_LOC_placement
	    copy_con_partition
	    copy_partition_pins
    }

    proc make_layout_identical {} {
	    get_regions_properties
	    copy_placement
	    copy_pins
	    copy_nets
    }

    proc get_ranges {pblock} {
	    set RAMB36_X 0
	    set RAMB36_Y 0
	    set RAMB18_X 0
	    set RAMB18_Y 0
	    set DSP48_X 0
	    set DSP48_Y 0
	    set SLICE_X 0
	    set SLICE_Y 0
	
	    # Change this to an if statement if aligned at the right side we need different coordinates probably X 3 or something

	    foreach type [get_property GRID_RANGES [get_pblocks $pblock]] {
		    set locations [regexp -inline -all -- {\d+} $type]
		    if {[regexp {RAMB36} $type]} {
			    set RAMB36_X [lindex $locations 1]
			    set RAMB36_Y [lindex $locations 2]
		    }
		    if {[regexp {RAMB18} $type]} {
			    set RAMB18_X [lindex $locations 1]
			    set RAMB18_Y [lindex $locations 2]
		    }
		    if {[regexp {DSP48} $type]} {
			    set DSP48_X [lindex $locations 1]
			    set DSP48_Y [lindex $locations 2]
		    }
		    if {[regexp {SLICE} $type]} {
			    set SLICE_X [lindex $locations 0]
			    set SLICE_Y [lindex $locations 1]
		    }
	    }
	
	    return [list $RAMB36_X $RAMB36_Y $RAMB18_X $RAMB18_Y $DSP48_X $DSP48_Y $SLICE_X $SLICE_Y] 
    }

    # Since rp_wrapper and rp have a different structure, the methods will be a bit different in regards to getting the pblock
    proc get_regions_properties {} {
 puts "your are now in the get_regions_properties proc"
	    set ::rp_template_region [list $::rp_template_name [get_ranges [get_property PBLOCK [get_cells $::rp_template_path]]] $::rp_template_path]
	    set ::rp_wrapper_template_region [list $::rp_template_name [get_ranges [get_property PBLOCK [get_cells [lindex [get_cells $::rp_wrapper_template_path/*] 1]]]] $::rp_wrapper_template_path]
	    for {set i 0} {$i < [llength $::rp_instance_names]} {incr i} {
		    lappend ::rp_regions [list [lindex $::rp_instance_names $i] [get_ranges [get_property PBLOCK [get_cells [lindex $::rp_instance_paths $i]]]] [lindex $::rp_instance_paths $i]]
	    }
	    for {set i 0} {$i < [llength $::rp_instance_names]} {incr i} {
		    lappend ::rp_wrapper_regions [list [lindex $::rp_instance_names $i] [get_ranges [get_property PBLOCK [get_cells [lindex [get_cells [lindex $::rp_wrapper_instance_paths $i]/*] 1]]]] [lindex $::rp_wrapper_instance_paths $i]]
	    }
    } 


    proc copy_BEL_placement {} {
puts "your are now in the copy_BEL_placement proc"
	    set rp_template_name [lindex $::rp_template_region [region@ Name]]
	    set rp_template_range [lindex $::rp_template_region [region@ Range]]
	    foreach rp_region $::rp_regions {
            
		    set rp_name [lindex $rp_region [region@ Name]]
		    set rp_range [lindex $rp_region [region@ Range]]
		    #No clue yet how to remove the parenthesis from A && B && !C && !D && !(E && F) if someone knows it the if statement can be integrated in the filter, since the filter doesn't like parenthesis
		    foreach leafcell [get_cells -hierarchical  -filter "NAME =~ *$rp_template_name* && IS_PRIMITIVE && PRIMITIVE_TYPE != OTHERS.others.GND && PRIMITIVE_TYPE != OTHERS.others.VCC"] {
			    if {!((([get_property PRIMITIVE_LEVEL [get_cells $leafcell]] == "MACRO") || ([get_property PRIMITIVE_LEVEL [get_cells $leafcell]] == "INTERNAL")) && ([get_property PRIMITIVE_GROUP [get_cells $leafcell]] == "DMEM"))} {		
				    regsub -all $rp_template_name $leafcell $rp_name new_leafcell
				    set master_BEL [get_property BEL [get_cells $leafcell]]
				    set_property BEL $master_BEL [get_cells $new_leafcell]
			    }
		    }
	    }
    }


    proc copy_LOC_placement {} {
		global template_con_partion_pblock_path
puts "your are now in the copy_LOC_placement proc"
	    set rp_template_name [lindex $::rp_template_region [region@ Name]]
	    set rp_template_range [lindex $::rp_template_region [region@ Range]]
		set template_con_partition_pblock_name [file tail $template_con_partion_pblock_path]

	    foreach rp_region $::rp_regions {
		    set rp_name [lindex $rp_region [region@ Name]]
		    set rp_range [lindex $rp_region [region@ Range]]

		    foreach leafcell [get_cells -hierarchical -filter "NAME =~ *$rp_template_name* && PRIMITIVE_GROUP =~  FLOP_LATCH" ] {

			    regsub -all $rp_template_name $leafcell $rp_name new_leafcell
			    set master_LOC [get_property LOC [get_cells $leafcell]]
			    set locations [regexp -inline -all -- {\d+} $master_LOC]
			    set normalized_SLICE_X [expr [lindex $locations 0] - [lindex $rp_template_range [ranges_pblock@ SLICE_X]]]
			    set normalized_SLICE_Y [expr [lindex $locations 1] - [lindex $rp_template_range [ranges_pblock@ SLICE_Y]]]
			    set_property LOC SLICE_X[expr [lindex $rp_range [ranges_pblock@ SLICE_X]] + $normalized_SLICE_X]Y[expr [lindex $rp_range [ranges_pblock@ SLICE_Y]] + $normalized_SLICE_Y] [get_cells $new_leafcell]
		    }
		    foreach leafcell [get_cells -hierarchical -filter "NAME =~ *$rp_template_name* && PRIMITIVE_GROUP =~  CARRY" ] {
			    regsub -all $rp_template_name $leafcell $rp_name new_leafcell
			    set master_LOC [get_property LOC [get_cells $leafcell]]
			    set locations [regexp -inline -all -- {\d+} $master_LOC]
			    set normalized_SLICE_X [expr [lindex $locations 0] - [lindex $rp_template_range [ranges_pblock@ SLICE_X]]]
			    set normalized_SLICE_Y [expr [lindex $locations 1] - [lindex $rp_template_range [ranges_pblock@ SLICE_Y]]]
			    set_property LOC SLICE_X[expr [lindex $rp_range [ranges_pblock@ SLICE_X]] + $normalized_SLICE_X]Y[expr [lindex $rp_range [ranges_pblock@ SLICE_Y]] + $normalized_SLICE_Y] [get_cells $new_leafcell]
		    }

		    foreach leafcell [get_cells -hierarchical -filter "NAME =~ *$rp_template_name* && PRIMITIVE_GROUP =~  MUXFX" ] {
			    regsub -all $rp_template_name $leafcell $rp_name new_leafcell
			    set master_LOC [get_property LOC [get_cells $leafcell]]
			    set locations [regexp -inline -all -- {\d+} $master_LOC]
			    set normalized_SLICE_X [expr [lindex $locations 0] - [lindex $rp_template_range [ranges_pblock@ SLICE_X]]]
			    set normalized_SLICE_Y [expr [lindex $locations 1] - [lindex $rp_template_range [ranges_pblock@ SLICE_Y]]]
			    set_property LOC SLICE_X[expr [lindex $rp_range [ranges_pblock@ SLICE_X]] + $normalized_SLICE_X]Y[expr [lindex $rp_range [ranges_pblock@ SLICE_Y]] + $normalized_SLICE_Y] [get_cells $new_leafcell]
		    }

		    #First do LUTs that have BEL x6LUT and than x5LUT
		    foreach leafcell [get_cells -hierarchical -filter "NAME =~ *$rp_template_name* && PRIMITIVE_GROUP =~  LUT && PRIMITIVE_LEVEL != INTERNAL && PBLOCK != $template_con_partition_pblock_name" ] {
			    if {[regexp {6} [get_property BEL [get_cells $leafcell]]]} {
				    regsub -all $rp_template_name $leafcell $rp_name new_leafcell
				    set master_LOC [get_property LOC [get_cells $leafcell]]
				    set locations [regexp -inline -all -- {\d+} $master_LOC]
				    set normalized_SLICE_X [expr [lindex $locations 0] - [lindex $rp_template_range [ranges_pblock@ SLICE_X]]]
				    set normalized_SLICE_Y [expr [lindex $locations 1] - [lindex $rp_template_range [ranges_pblock@ SLICE_Y]]]
				    set_property LOC SLICE_X[expr [lindex $rp_range [ranges_pblock@ SLICE_X]] + $normalized_SLICE_X]Y[expr [lindex $rp_range [ranges_pblock@ SLICE_Y]] + $normalized_SLICE_Y] [get_cells $new_leafcell]
			    }
		    }
		
		    foreach leafcell [get_cells -hierarchical -filter "NAME =~ *$rp_template_name* && PRIMITIVE_GROUP =~  LUT && PRIMITIVE_LEVEL != INTERNAL && PBLOCK != $template_con_partition_pblock_name" ] {
			    if {[regexp {5} [get_property BEL [get_cells $leafcell]]]} {
				    regsub -all $rp_template_name $leafcell $rp_name new_leafcell
				    set master_LOC [get_property LOC [get_cells $leafcell]]
				    set locations [regexp -inline -all -- {\d+} $master_LOC]
				    set normalized_SLICE_X [expr [lindex $locations 0] - [lindex $rp_template_range [ranges_pblock@ SLICE_X]]]
				    set normalized_SLICE_Y [expr [lindex $locations 1] - [lindex $rp_template_range [ranges_pblock@ SLICE_Y]]]
				    set_property LOC SLICE_X[expr [lindex $rp_range [ranges_pblock@ SLICE_X]] + $normalized_SLICE_X]Y[expr [lindex $rp_range [ranges_pblock@ SLICE_Y]] + $normalized_SLICE_Y] [get_cells $new_leafcell]
			    }
		    }
		
		    foreach leafcell [get_cells -hierarchical -filter "NAME =~ *$rp_template_name* && PRIMITIVE_GROUP =~  DMEM && PRIMITIVE_LEVEL != INTERNAL" ] {
			    regsub -all $rp_template_name $leafcell $rp_name new_leafcell
			    set master_LOC [get_property LOC [get_cells $leafcell]]
			    set locations [regexp -inline -all -- {\d+} $master_LOC]
			    set normalized_SLICE_X [expr [lindex $locations 0] - [lindex $rp_template_range [ranges_pblock@ SLICE_X]]]
			    set normalized_SLICE_Y [expr [lindex $locations 1] - [lindex $rp_template_range [ranges_pblock@ SLICE_Y]]]
			    set_property LOC SLICE_X[expr [lindex $rp_range [ranges_pblock@ SLICE_X]] + $normalized_SLICE_X]Y[expr [lindex $rp_range [ranges_pblock@ SLICE_Y]] + $normalized_SLICE_Y] [get_cells $new_leafcell]
			    #place_cell $new_leafcell SLICE_X[expr [lindex $rp_range [ranges_pblock@ SLICE_X]] + $normalized_SLICE_X]Y[expr [lindex $rp_range [ranges_pblock@ SLICE_Y]] + $normalized_SLICE_Y]
		    }
		
		    foreach leafcell [get_cells -hierarchical -filter "NAME =~ *$rp_template_name* && PRIMITIVE_GROUP !~  LUT && PRIMITIVE_GROUP !~  FLOP_LATCH && PRIMITIVE_GROUP !~  DMEM && PRIMITIVE_GROUP !~  MUXFX && PRIMITIVE_GROUP !~  CARRY && PRIMITIVE_TYPE != OTHERS.others.GND && PRIMITIVE_TYPE != OTHERS.others.VCC" ] {
			    regsub -all $rp_template_name $leafcell $rp_name new_leafcell
			    set master_LOC [get_property LOC [get_cells $leafcell]]
			    set locations [regexp -inline -all -- {\d+} $master_LOC]
			    if {[regexp {RAMB36} $master_LOC]} {
				    set normalized_RAMB36_X [expr [lindex $locations 1] - [lindex $rp_template_range [ranges_pblock@ RAMB36_X]]]
				    set normalized_RAMB36_Y [expr [lindex $locations 2] - [lindex $rp_template_range [ranges_pblock@ RAMB36_Y]]]
				    set_property LOC RAMB36_X[expr [lindex $rp_range [ranges_pblock@ RAMB36_X]] + $normalized_RAMB36_X]Y[expr [lindex $rp_range [ranges_pblock@ RAMB36_Y]] + $normalized_RAMB36_Y] [get_cells $new_leafcell]
			    }
			    if {[regexp {RAMB18} $master_LOC]} {
				    set normalized_RAMB18_X [expr [lindex $locations 1] - [lindex $rp_template_range [ranges_pblock@ RAMB18_X]]]
				    set normalized_RAMB18_Y [expr [lindex $locations 2] - [lindex $rp_template_range [ranges_pblock@ RAMB18_Y]]]
				    set_property LOC RAMB18_X[expr [lindex $rp_range [ranges_pblock@ RAMB18_X]] + $normalized_RAMB18_X]Y[expr [lindex $rp_range [ranges_pblock@ RAMB18_Y]] + $normalized_RAMB18_Y] [get_cells $new_leafcell]
			    }
			    if {[regexp {DSP48} $master_LOC]} {
				    set normalized_DSP48_X [expr [lindex $locations 1] - [lindex $rp_template_range [ranges_pblock@ DSP48_X]]]
				    set normalized_DSP48_Y [expr [lindex $locations 2] - [lindex $rp_template_range [ranges_pblock@ DSP48_Y]]]
				    set_property LOC DSP48_X[expr [lindex $rp_range [ranges_pblock@ DSP48_X]] + $normalized_DSP48_X]Y[expr [lindex $rp_range [ranges_pblock@ DSP48_Y]] + $normalized_DSP48_Y] [get_cells $new_leafcell]
			    }
			    if {[regexp {SLICE} $master_LOC]} {
				    set normalized_SLICE_X [expr [lindex $locations 0] - [lindex $rp_template_range [ranges_pblock@ SLICE_X]]]
				    set normalized_SLICE_Y [expr [lindex $locations 1] - [lindex $rp_template_range [ranges_pblock@ SLICE_Y]]]
                    set template_slice $master_LOC
				    set template_slice_clk_region [get_property CLOCK_REGION [get_sites $template_slice]]
				    set template_which_tile [findTile CLOCKREGION_$template_slice_clk_region $template_slice]
                    set destination_slice SLICE_X[expr [lindex $rp_range [ranges_pblock@ SLICE_X]] + $normalized_SLICE_X]Y[expr [lindex $rp_range [ranges_pblock@ SLICE_Y]] + $normalized_SLICE_Y]
				    set slice_clk_region [get_property CLOCK_REGION [get_sites $destination_slice]]
				    set which_tile [findTile CLOCKREGION_$slice_clk_region $destination_slice]
                    if {[regexp -nocase {clem} $which_tile] && [regexp -nocase {clel} $template_which_tile]} {
                        set normalized_SLICE_X [expr $normalized_SLICE_X + 1]
                    }
				    set_property LOC SLICE_X[expr [lindex $rp_range [ranges_pblock@ SLICE_X]] + $normalized_SLICE_X]Y[expr [lindex $rp_range [ranges_pblock@ SLICE_Y]] + $normalized_SLICE_Y] [get_cells $new_leafcell]
			    }
		    }
	    }
    }

    proc copy_con_partition {} {
puts "your are now in the copy_con_partition proc"
	    set rp_wrapper_template_name [lindex $::rp_wrapper_template_region [region@ Name]]
	    set rp_wrapper_template_range [lindex $::rp_wrapper_template_region [region@ Range]]
		
		if {[string match -nocase "*uplus" $::product_family]} {
			set search_filter "NAME =~ *$rp_wrapper_template_name* && PRIMITIVE_SUBGROUP =~  LUT && PBLOCK =~ *pblock_PR_0_CP*"
		} else {
			set search_filter "NAME =~ *$rp_wrapper_template_name* && PRIMITIVE_GROUP =~  LUT && PBLOCK =~ *pblock_PR_0_CP*"
		}
	    foreach rp_wrapper_region $::rp_wrapper_regions {
		    set rp_wrapper_name [lindex $rp_wrapper_region [region@ Name]]
		    set rp_wrapper_range [lindex $rp_wrapper_region [region@ Range]]
			foreach leafcell [get_cells -hierarchical -filter $search_filter ] {
			    regsub -all $rp_wrapper_template_name $leafcell $rp_wrapper_name new_leafcell
			    set master_BEL [get_property BEL [get_cells $leafcell]]
			    set_property BEL $master_BEL [get_cells $new_leafcell] 
			    set master_LOC [get_property LOC [get_cells $leafcell]]
			    set locations [regexp -inline -all -- {\d+} $master_LOC]
			    set normalized_SLICE_X [expr [lindex $locations 0] - [lindex $rp_wrapper_template_range [ranges_pblock@ SLICE_X]]]
			    set normalized_SLICE_Y [expr [lindex $locations 1] - [lindex $rp_wrapper_template_range [ranges_pblock@ SLICE_Y]]]
			    set_property LOC SLICE_X[expr [lindex $rp_wrapper_range [ranges_pblock@ SLICE_X]] + $normalized_SLICE_X]Y[expr [lindex $rp_wrapper_range [ranges_pblock@ SLICE_Y]] + $normalized_SLICE_Y] [get_cells $new_leafcell]
		    }
	    }
    }

    proc copy_partition_pins {} {
puts "your are now in the copy_partition_pins proc"
        global product_family
	global clk_re_with_clk_tiles

	set rp_template_name [lindex $::rp_template_region [region@ Name]]
	set rp_template_range [lindex $::rp_template_region [region@ Range]]
	foreach rp_region $::rp_regions {
	    set rp_name [lindex $rp_region [region@ Name]]
	    set rp_range [lindex $rp_region [region@ Range]]
	    foreach pin [get_pins -hierarchical -filter "NAME =~ *$rp_template_name*" ] {
		    regsub -all $rp_template_name $pin $rp_name new_pin
		    set LOC [ get_property HD.PARTPIN_LOCS [get_pins $pin]]
        	    if {[string match -nocase "*uplus" $product_family]} { 
                    	if {($LOC != "")} {
                    	    if {[string match -nocase "int*" $LOC]} {
		            	set tile "INT_X"
		            	set start_pblock_slice_template "SLICE_X[lindex $rp_template_range [ranges_pblock@ SLICE_X]]Y[lindex $rp_template_range [ranges_pblock@ SLICE_Y]]"
			    	set slice_clk_region_template [get_property CLOCK_REGION [get_sites $start_pblock_slice_template]]
			        set start_pblock_tile_template [findTile CLOCKREGION_$slice_clk_region_template $start_pblock_slice_template] 
			    	set tile_locations_template [regexp -inline -all -- {\d+} $start_pblock_tile_template]
			    	set LOC_locations_template [regexp -inline -all -- {\d+} $LOC]

			    	set start_pblock_slice "SLICE_X[lindex $rp_range [ranges_pblock@ SLICE_X]]Y[lindex $rp_range [ranges_pblock@ SLICE_Y]]"
			    	set slice_clk_region [get_property CLOCK_REGION [get_sites $start_pblock_slice]]
			    	set start_pblock_tile [findTile CLOCKREGION_$slice_clk_region $start_pblock_slice] 
			    	set tile_locations [regexp -inline -all -- {\d+} $start_pblock_tile]

			        set normalized_SLICE_X [expr [lindex $LOC_locations_template 0] - [lindex $tile_locations_template 0]]
			        set normalized_SLICE_Y [expr [lindex $LOC_locations_template 1] - [lindex $tile_locations_template 1]]

			        set_property HD.PARTPIN_LOCS ${tile}[expr [lindex $tile_locations 0] + $normalized_SLICE_X]Y[expr [lindex $tile_locations 1] + $normalized_SLICE_Y] [get_pins $new_pin]
			    } elseif {[string match -nocase "rclk*" $LOC]} {
				foreach clk_re [dict keys $clk_re_with_clk_tiles] {
					set row_number [dict keys [dict get $clk_re_with_clk_tiles $clk_re]]
					if {[lsearch [dict get $clk_re_with_clk_tiles $clk_re $row_number] $LOC] != -1} {
						# remove the clk tile which is already assign to the clk partition pin of the template RP
						set idx [lsearch [dict get $clk_re_with_clk_tiles $clk_re $row_number] $LOC]
						set new_clk_tile_array [lreplace [dict get $clk_re_with_clk_tiles $clk_re $row_number] $idx $idx]
						# choose the next clk tile to assign it to the clk partition pin of the destination RP
						set new_tile [lindex $new_clk_tile_array 0]

						set_property HD.PARTPIN_LOCS $new_tile [get_pins $new_pin]
						break
					}
				}
			   }					    
                    }
                } else {
		            if { ($LOC != "") } {                     
                        if {[regexp {INT_R} $LOC]} {
					        set tile "INT_R_X"
				        }
				        if {[regexp {INT_L} $LOC]} {
					        set tile "INT_L_X"
				        }
if {[string match -nocase "hclk*" $LOC]} {
    set coordinate [regexp -inline -all -- {[X,Y]\d+} $LOC]
    set split_loc [split $LOC "_"]
    set coordinate_pos [lsearch $split_loc "[lindex $coordinate 0][lindex $coordinate 1]"]
    set tile [lindex $split_loc 0]
    if {$coordinate_pos != "1"} {
	    for {set i 1} {$i < [expr [llength $split_loc] -1]} {incr i} {
		    append tile "_[lindex $split_loc $i]"
	    }
    }
    append tile "_X"
}

					    set start_pblock_slice_template "SLICE_X[lindex $rp_template_range [ranges_pblock@ SLICE_X]]Y[lindex $rp_template_range [ranges_pblock@ SLICE_Y]]"
					    set slice_clk_region_template [get_property CLOCK_REGION [get_sites $start_pblock_slice_template]]
					    set start_pblock_tile_template [findTile CLOCKREGION_$slice_clk_region_template $start_pblock_slice_template] 
					    set tile_locations_template [regexp -inline -all -- {\d+} $start_pblock_tile_template]
					    set LOC_locations_template [regexp -inline -all -- {\d+} $LOC]

					    set start_pblock_slice "SLICE_X[lindex $rp_range [ranges_pblock@ SLICE_X]]Y[lindex $rp_range [ranges_pblock@ SLICE_Y]]"
					    set slice_clk_region [get_property CLOCK_REGION [get_sites $start_pblock_slice]]
					    set start_pblock_tile [findTile CLOCKREGION_$slice_clk_region $start_pblock_slice] 
					    set tile_locations [regexp -inline -all -- {\d+} $start_pblock_tile]

				        set normalized_SLICE_X [expr [lindex $LOC_locations_template 0] - [lindex $tile_locations_template 0]]
				        set normalized_SLICE_Y [expr [lindex $LOC_locations_template 1] - [lindex $tile_locations_template 1]]

if {[string match -nocase "hclk*" $tile] } {
    set_property HD.PARTPIN_LOCS ${tile}[expr [lindex $tile_locations 0] + $normalized_SLICE_X]Y[expr [lindex $tile_locations 1] + $normalized_SLICE_Y + 2] [get_pins $new_pin]
} else {
				        set_property HD.PARTPIN_LOCS ${tile}[expr [lindex $tile_locations 0] + $normalized_SLICE_X]Y[expr [lindex $tile_locations 1] + $normalized_SLICE_Y] [get_pins $new_pin]
}
                    }
                }
		    }
	    }
    }

    proc copy_pins {} {
puts "your are now in the copy_pins proc"
	    global product_family
	    set rp_template_name [lindex $::rp_template_region [region@ Name]]

	    foreach rp_region $::rp_regions {
		    set rp_name [lindex $rp_region [region@ Name]]
		    if {[string match -nocase "*uplus" $product_family]} {
			set search_filter "NAME =~ *$rp_template_name* && PRIMITIVE_SUBGROUP =~  LUT && PRIMITIVE_LEVEL == LEAF"
		    } else {
			set search_filter "NAME =~ *$rp_template_name* && PRIMITIVE_GROUP =~  LUT && PRIMITIVE_LEVEL == LEAF"
		    }
			

		    foreach leafcell [get_cells -hierarchical -filter "$search_filter" ] {
			    regsub -all $rp_template_name $leafcell $rp_name new_leafcell
			    set lock_pins "set_property LOCK_PINS {"
			    foreach pin [get_pins -of [get_cell $leafcell]] {
				    #Ignore the output pin, this will give errors and there is only one possible output
				    if {[lindex [split $pin /] end] != "O" } { 
					    append lock_pins "[lindex [split $pin /] end]:[lindex [split [get_bel_pins -of [get_pins $pin]] /] end] "
				    }
			    }
			    append lock_pins "} \[get_cells $new_leafcell\]"
			    eval $lock_pins
		    }	
	    }
    }

    proc copy_nets {} {
puts "your are now in the copy_nets proc"
	    set rp_template_name [lindex $::rp_template_region [region@ Name]]
		#at this point only nets should be routed which are between CP and RP
		set net_filter "ROUTE_STATUS == ROUTED && NAME =~ *$rp_template_name*"
	
	    foreach rp_region $::rp_regions {
		    set rp_name [lindex $rp_region [region@ Name]]
#		    set rp_path [lindex $rp_region [region@ Path]]
 	
		    foreach net [get_nets -hierarchical -filter $net_filter] {
			    regsub -all $rp_template_name $net $rp_name new_net
			    set_property ROUTE [get_property ROUTE [get_nets $net]] [get_nets $new_net]
		    }
	    }
puts "Make identical phase is finish"
    }

