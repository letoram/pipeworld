local function set_opacity(act, pass)
	local act = math.clamp(act, 0.0, 1.0)
	pass = pass and (math.clamp(pass, 0.0, 1.0)) or nil

	local cell = eval_scope.cell
	if valid_vid(cell.vid, TYPE_FRAMESERVER) then
		target_graphmode(cell.vid, 1, act * 255.0, 0, 0)
		target_graphmode(cell.vid, 0)
	else
		cell.cfg.colors.active.opacity = act
	end

	if act then
		cell.cfg.colors.passive.opacity = pass
	end
end

return function(types)
	return {
		handler = set_opacity,
		args = {types.NIL, types.NUMBER, types.NUMBER},
		argc = 1,
		names = {"active", "passive"},
		help = "Change the background opacity",
		type_helper = {},
	}
end
