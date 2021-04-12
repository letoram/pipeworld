--
-- Similarly to cli/term etc. this just lanches an external vid.
--
-- Ties it to a cell then handles subconnections as inserts on the
-- current row. The complex detail is that it also attempts to implement
-- a rate limit as the clients come from a less trusted context. See the
-- 'on_child' handler for some nightmare fuel.
--
local input_factory = system_load("cells/shared/input.lua")()

local function update_label(cell)
	cell:force_str(string.format("listen(%d)@%s", 1, cell.cp))
	cell.row:invalidate()
end

local on_connected
local on_terminated
local reopen

reopen =
function(cell)
	local vid = target_alloc(cell.cp,
		pipeworld_segment_handler(cell, {
			connected = on_connected,
			terminated = on_terminated
		})
	)
	link_image(vid, cell.bg)
	update_label(cell)
end

on_connected =
function(cell, source, status)
-- we don't have a cell to add the tracking to yet, that comes from 'registered'
	if cell.client_limit > 0 and #cell.client_count >= cell.client_limit then
	else
		reopen(cell)
	end
end

local function on_child(cell, vid, kind)
	if cell.client_limit > 0 and #cell.client_count >= cell.client_limit then
		delete_image(vid)
		return nil
	end

-- the tracking is complex and likely not entirely correct, as it is not set
-- if children and subsegments and handovers from the same point should track
-- towards the limit (if any) or not, and certain types here will cause alloc
-- paths that are worse (looking at you wayland).
	return
		cell.row:add_cell(
		function(row, cfg)
			local res = pipeworld_cell_template(kind, row, cfg)
			if not res then
				delete_image(vid)
				return
			end

			local old = res.destroy
			res.destroy = function(...)
				table.remove_match(res.client_count, res)
				return old(...)
			end
			return res
		end)
end

return
function(row, cfg, cp, limit)
	local args = ""
	if not cp or type(cp) ~= "string" or #cp == 0 then
		warning("listen_cell: invalid connection point")
		return
	end

-- treat it as an input cell but just provide the text behavior
	local cell = input_factory("listen", row, cfg)
	cell.maximize =
	function()
	end

-- the client count actually tracks references to all client tables, and
-- on terminated or cell destruction the 'outer' list removes any match
	cell.client_count = {}
	cell.cp = cp
	cell.read_only = true
	cell.client_limit = (limit and type(limit) == "number") and limit or 0
	cell.on_child = on_child
	hide_image(cell.caret)

-- if prefix is a12:// should go with net_listen instead but the engine
-- is currently missing that mapping so still need to arcan-net manually
	reopen(cell)

	return cell
end
