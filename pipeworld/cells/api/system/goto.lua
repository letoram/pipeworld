local function goto_cell(cell, ignore_scale)
	cell.row.wm:drop_popup()
	cell.row:focus()
	cell.row:select_cell(cell)

	if ignore_scale and not cell.scale_ignore then
		cell:ignore_scale()
	end

	cell.row.wm:pan_fit(cell, true)
end

return function(types)
	return {
		handler = goto_cell,
		args = {types.NIL, types.CELL, types.BOOLEAN},
		type_helper = {},
		argc = 1,
		names = {"target", "maximize"},
		help = "Pan/move selection to the specified cell.",
	}
end
