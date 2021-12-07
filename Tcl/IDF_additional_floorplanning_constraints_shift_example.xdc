#FIXME CP must be bigger
resize_pblock pblock_PR_0_CP -add SLICE_X44Y0:SLICE_X45Y59 -remove SLICE_X45Y0:SLICE_X45Y59 -locs keep_all
resize_pblock pblock_PR_1_CP -add SLICE_X53Y0:SLICE_X54Y59 -remove SLICE_X54Y0:SLICE_X54Y59 -locs keep_all

#FIXME find soution
create_pblock pblock_inst_static
add_cells_to_pblock [get_pblocks pblock_inst_static] [get_cells -quiet [list inst_top_shift/inst_static]]
resize_pblock [get_pblocks pblock_inst_static] -add {SLICE_X36Y65:SLICE_X55Y119 SLICE_X48Y0:SLICE_X48Y64}
resize_pblock [get_pblocks pblock_inst_static] -add {RAMB18_X6Y0:RAMB18_X6Y47}
resize_pblock [get_pblocks pblock_inst_static] -add {RAMB36_X6Y0:RAMB36_X6Y23}
resize_pblock [get_pblocks pblock_inst_static] -add {CLOCKREGION_X2Y0:CLOCKREGION_X3Y6}
resize_pblock pblock_inst_static -add {SLICE_X36Y65:SLICE_X59Y119 DSP48E2_X7Y26:DSP48E2_X11Y47 RAMB18_X5Y26:RAMB18_X7Y47 RAMB36_X5Y13:RAMB36_X7Y23} -remove SLICE_X36Y65:SLICE_X38Y119 -locs keep_all
