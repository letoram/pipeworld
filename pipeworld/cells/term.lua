local apply_fsrv_cell = system_load("cells/shared/fsrv.lua")()

local function gen_name()
	local res = {}
	for i=1,8 do
		res[i] = string.char(string.byte("a") + math.random(1, 10))
	end

	return table.concat(res, "")
end

local reopen
reopen =
function(cell)
	local vid = target_alloc(cell.cp,
		pipeworld_segment_handler(cell,
			{
				connected =
				function()
					reopen(cell)
				end
			}
		)
	)
	link_image(vid, cell.bg)
end

return
function(row, cfg, cmd)
	local res = pipeworld_cell_template("cli", row, cfg)
	local arg = cfg.terminal_arg and cfg.terminal_arg or ""
	local name

	if cfg.terminal_listen then
		name = "pwterm_" .. gen_name()
		arg = arg .. "env=ARCAN_CONNPATH=" .. name
	end

	if cmd and #cmd > 0 then
		arg = string.format("%skeep_alive:autofit:exec=%s", #arg > 0 and ":" or "", cmd)
	end

	local vid = launch_avfeed(arg, "terminal",
		pipeworld_segment_handler(res, {
		registered = function()
		end,
	}))
	apply_fsrv_cell(res, vid)

	if name then
		res.cp = name
		reopen(res)
	end

	return res
end
