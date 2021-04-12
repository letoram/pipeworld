local apply_cli_cell = system_load("cells/shared/fsrv.lua")()

local function deploy_pipeline(monitor)
	local prev
	monitor = monitor.head

-- in build-pipe we check so that there is > 1 entry in the chain
	while monitor do
		prev = monitor
		monitor = monitor.next

-- blob transfers (blob=true) instead of state transfers
		if monitor then
			bond_target(prev.vid, monitor.vid, true, "stdout", "stdin")
			if monitor.next then
				bond_target(monitor.vid, monitor.next.vid, true, "stdout", "stdin")
			end
		end
		resume_target(prev.vid)
	end
end

local function pipe_preroll(cell, source, status, ...)
-- don't send activate until we have all
	suspend_target(source)

-- we are ready to build the i/o pipeline
	cell.monitor.pending = cell.monitor.pending - 1
	if cell.monitor.pending == 0 then
		deploy_pipeline(cell.monitor)
	end

-- forward the initial preroll handler without overrides
	return pipeworld_segment_handler(cell, {}, {})(source, status, ...)
end

local function build_pipe(...)
	local cmds = {...}
	local prev

	if #cmds == 0 then
		return
	end

-- create our new command row
	local wm = eval_scope.wm

	local monitor = {
		pending = 0
	}

-- only one command? short-circuit to terminal
	if #cmds == 1 then
		return wm:add_row("terminal", cmds[1])
	end

-- tie cmd to a terminal and append to the chain, note the view-mode
	local handler =
	function(row, cfg, cmd)
		local res = pipeworld_cell_template("cli", row, cfg)
		local arg = cfg.terminal_arg .. ":keep_alive:autofit:pipe=lf:exec=" .. cmd
		local vid = launch_avfeed(arg, "terminal",
			pipeworld_segment_handler(res, {registered = function() end, preroll = pipe_preroll}, {}))

		if not valid_vid(vid) then
			return
		end

		image_tracetag(vid, "pipe_" .. cmd)
		monitor.pending = monitor.pending + 1
		res.monitor = monitor

-- append to list
		if not monitor.head then
			monitor.head = res
			monitor.tail = res
		else
			monitor.tail.next = res
			monitor.tail = res
		end

		apply_cli_cell(res, vid)
		return res
	end

-- this assumes terminal emulators for now, but the prefix should really
-- determine what we are running so that pipelines can be built from target:
-- arcan: x11: wayland: clients as well.
	local row = wm:add_row(handler, cmds[1])

	for i=2,#cmds do
		row:add_cell(handler, cmds[i])
	end
end

return function(types)
	return {
		handler = build_pipe,
		args = {types.NIL, types.STRING, types.VARARG},
		argc = 1,
		help = "Build a processing pipeline.",
		type_helper = {}
	}
end
