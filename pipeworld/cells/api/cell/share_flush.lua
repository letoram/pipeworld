local function share_flush(id)
	local cell = eval_scope.cell
	cell:drop_encoder(id)
end

local function tag_helper()
-- check cell.encoders and return list from there
	local lst = {}
	for k,v in pairs(eval_scope.cell.encoders) do
		table.insert(lst, k)
	end
	table.sort(lst)
	return lst
end

return function(types)
	return {
		handler = share_flush,
		args = {types.NIL, types.STRING},
		names = {"tag"},
		type_helper = {tag_helper},
		argc = 0,
		help = "Remove one or many output sharing sessions bound to this cell.",
	}
end
