local function tag_cell(tag)
	local cell = eval_scope.cell

-- remove existing
	if cell.tag then
		cell.row.wm.tags[tag] = nil
	end

-- complain on collision
	if cell.row.wm.tags[tag] then
		cell:set_error("name collision, tag: " .. tag .. " must be unique.")
		return
	end

-- replace / invalidate
	cell.tag = tag
	cell.row.wm.tags[tag] = cell
	cell.row:invalidate()
end

return function(types)
	return {
		handler = tag_cell,
		args = {types.NIL, types.STRING},
		argc = 1,
		names = {"tag"},
		help = "Change the cell tag attribute to another valid identifier.",
		type_helper = {}
	}
end
