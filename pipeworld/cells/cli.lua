local apply_fsrv_cell = system_load("cells/shared/fsrv.lua")()

local function set_child_horizontal(cell)
	cell.insert_vertical = false
end

local function set_child_vertical(cell)
	cell.insert_vertical = true
end

local function handle_child(cell, source, kind)
	local res, vid
	local cfg = cell.cfg

-- custom handler that sets insertion index, this behavior does not make sense
-- for all types (hence why it is here) as it breaks parent-child ordering as
-- changes addresses
	local handler =
	function(row, cfg)
		res = pipeworld_cell_template(kind, row, cfg)
		row.cli_tag = cell

		local index
		if cfg.cli_cell_insertion == "first" then
			index = 2
		end

		res:unfocus()
		return res, index
	end

-- runtime dynamic config options
	if cell.insert_vertical then
		local wm = cell.row.wm
		local new = wm:add_row_at(cell.row.index, handler)
		local sf = 1.0
		local si = 1

-- and auto-delete if there is a row in the cutoff window, that should
-- only be possible once per insert
		local del_queue = {}

-- apply rescaling sequence to the set that this cli has spawned
		for i=cell.row.index-1,1,-1 do
			local row = wm.rows[i]

			if row.cli_tag ~= cell then
				break
			end

-- step scale-factor downwards until end and stay there
			row:scale(sf, sf)
			if cell.cfg.cli_vertical_autoscale[si] then
				sf = cell.cfg.cli_vertical_autoscale[si]
				si = si + 1
			end
		end

		cell.row:focus()
		cell.row.wm:pan_fit(cell, true)
	else
		cell.row:add_cell(handler)
	end

-- retain selection to cli cell unless we are supposed to detach
	if cell.detach_on_child then
		cell.row:delete_cell(cell)
	else
		cell.row:select_index(1)
	end

	return res, source
end

return
function(row, cfg, w, h, args, detach)
	local args = type(args) == "string" and args or ""
	local res = pipeworld_cell_template("cli", row, cfg)

	if (w and h) then
		res.terminal_size = {w, h}
	else
		res.terminal_size = cfg.cli_size
	end

	res.detach_on_child = detach
	res.on_child = handle_child

-- cli mode to the terminal is special, it means that the first window act as
-- prompt (so the 'shell' is fixed inside afsrv_terminal) then when a command
-- is launched we get a 'handover' segment request for the new client.
	if cfg.terminal_arg and #cfg.terminal_arg then
		args = args .. ":" .. cfg.terminal_arg .. ":cli"
	end

--
-- This pattern is recurring in other cells that want to use the builtin- set
-- of event handlers for external processes as well. For when we >know< the
-- type in advance, we shouldn't wait for 'connected -> registered -> preroll'
-- flow but build the proper cell immediately.
--
-- The complexity come from 'handover' - where a client requests a child of an
-- unknown type to give to someone else. We want to bind it to a cell
-- immediately so that there is a communication channel to attach/debug before
-- it is alive. For the cli-cell launching a command,
--
--  > debugstall
--  -> new cell appears, sends notification about pid
--  -> either :debug(new_cell) or a gdb -p pid yourself
--
-- The 'default' on_registered handler applies the cell type appropriate meta
-- handler, but we only want that for the handover allocations that we do not
-- administer ourselves.
--
	local on_registered =
	function(cell, source, status, forward)
	end

	local vid = launch_avfeed(args,
		"terminal", pipeworld_segment_handler(res, {registered = on_registered}))

	if not valid_vid(vid) then
		warning("cli_cell: couldn't spawn shell")
		res:destroy()
		return
	end

	apply_fsrv_cell(res, vid)
	return res
end,
{
	["/cli/child_horizontal"] = set_child_horizontal,
	["/cli/child_vertical"] = set_child_vertical
}
