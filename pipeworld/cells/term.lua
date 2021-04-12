local apply_fsrv_cell = system_load("cells/shared/fsrv.lua")()

return
function(row, cfg, cmd)
	local res = pipeworld_cell_template("cli", row, cfg)
	local arg = cfg.terminal_arg and cfg.terminal_arg or ""

	if cmd and #cmd > 0 then
		arg = string.format("%skeep_alive:autofit:exec=%s", #arg > 0 and ":" or "", cmd)
	end

	local vid = launch_avfeed(arg, "terminal",
		pipeworld_segment_handler(res, {
		registered = function()
		end,
	}))
	apply_fsrv_cell(res, vid)

	return res
end
