local apply_fsrv_cell = system_load("cells/shared/fsrv.lua")()

return
function(row, cfg, ref, force_builtin)
	local args = ""

-- if no explicit is set, grab the last focused row and the last cell on that row
	if not ref then
		local src_row = row.wm.last_focus
		if not src_row then
			warning("debug_cell:no reference row to debug")
			return
		end

		if src_row.popup then
			src_row = src_row.popup
		end

		local _, _, focus_cell = src_row:focused()
		if not focus_cell then
			warning("debug_cell:no reference cell to debug")
			return
		end

		ref = focus_cell.vid
	end

	if not ref or not valid_vid(ref, TYPE_FRAMESERVER) then
		warning("debug_cell:no reference cell to debug")
		return
	end

	local res = pipeworld_cell_template("tui", row, cfg)
	local w,h = pipeworld_preferred_size(res, "tui")
	local vid = target_alloc(ref, w, h, function() end, "debug", force_builtin)

	if not valid_vid(vid) then
		res:destroy()
		warning("debug_cell:couldn't spawn debug")
		return
	end

	apply_fsrv_cell(res, vid)

	local segh = pipeworld_segment_handler(res, {registered = function() end})

-- fake a preroll as this comes from a pushed segment
	target_updatehandler(vid, segh)
	segh(vid, {kind = "preroll", segkind = "tui" })

	return res
end
