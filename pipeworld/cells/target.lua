-- start as a normal input cell that mutates into whatever type on initial 'registered'
local input_factory = system_load("cells/shared/input.lua")()
local apply_fsrv_cell = system_load("cells/shared/fsrv.lua")()

return
function(row, wmcfg, target, cfgname)
	local cell = input_factory("target", row, wmcfg)

	if type(target) ~= "string" then
		warning("target-cell, invalid target argument")
		return
	end

	local vid
	if not cfgname then
		vid = launch_target(target, pipeworld_segment_handler(cell, {}))
	else
		vid = launch_target(target, cfgname, pipeworld_segment_handler(cell, {}))
	end

-- mutate into whatever is appropriate for the type
	cell.on_child =
	function(cell, source, kind)
		return cell.row.wm:replace_cell(cell, cell.row.wm.types[kind] and kind or "adopt", source)
	end

-- failed to launch, indicate that
	if not valid_vid(vid) then
		cell:force_str(string.format("Target(%s%s) failed", target, config and config or ""))
	end

	return cell
end
