--
-- wayland clients are 'special, the event response from shared/fsrv
-- would not work with the policies enforced by the protocol, so we need
-- some specific overrides here
--
local wl_factory, wl_connection = system_load("builtin/wayland.lua")()

-- wayland / xwayland clients need a whole lot of special sauce
local wl_config = {
	log = print,
	fmt = string.format
}

function wl_config.focus(wnd)
-- if the row has input focus, let the window have it, respond with wnd:focus
	if not wnd then
		return
	end
	wnd:focus()
end

function wl_config.configure(wnd, typestr)
--	local w, h = pipeworld_preferred_size(res, "toplevel")
	local _, _, hw, hh = wnd.wm.cell.row:cell_size()
	return hw, hh, 0, 0
end

local function wlwnd_on_focus(cell)
-- grab and 'wnd_input_table'
	cell.wnd:focus()

	cell.cfg.input_grab(cell,
	function(iotbl)
		if not iotbl then
			return
		end
		cell.wnd:input_table(iotbl)
	end)
end

local function wlwnd_on_unfocus(cell)
	cell.wnd:unfocus()
end

local function wlwnd_setup(wnd, cell)
-- content needs an indirection as base might well delete it and the meta-wm
-- wants to own the lifespan of all wayland resources
	local ref = null_surface(1, 1)
	image_sharestorage(wnd.vid, ref)

	hide_image(wnd.vid)
	cell:set_content(ref, nil, wnd)
	image_tracetag(ref, "wl_wnd_proxy")
	cell.mouse_proxy = wnd
	cell.wnd = wnd

	local of = cell.focus
	cell.focus =
	function(...)
		wlwnd_on_focus(cell)
		return of(...)
	end

	local ouf = cell.unfocus
	cell.unfocus =
	function(...)
		wlwnd_on_unfocus(cell)
		return ouf(...)
	end
end

function wl_config.mapped(wnd, wtype)
	local new_cell =
		wnd.wm.cell.row:add_cell(
		function(row, cfg)
			res = pipeworld_cell_template("wayland_client", row, cfg)
			wlwnd_setup(wnd, res)
			return res
		end
	)

	if not new_cell then
		wnd.cell.row:destroy(wnd.cell)
-- this will practically override whatever 'configure' request we had
	else
		wnd:fullscreen()
	end
end

function wl_config.destroy(wnd)
	if not wnd.cell or not wnd.cell.row then
		return
	end
	wnd.cell.row:destroy(wnd.cell)
end

-- these can't really 'move'
function wl_config.move(wnd, x, y)
	return 0, 0
end

function wl_config.state_change(wnd, state)
	if not state then
		wnd:revert()
	end

-- really don't matter here
	if state == "maximize" then
		wnd:maximize()

	elseif state == "fullscreen" then
		wnd:fullscreen()

	elseif state == "realized" then
		hide_image(wnd.vid)
	end
end

function wl_config.decorate()
-- no 'real' decorations
end

local function wl_client(cell, source, status)
	local wlcfg = table.copy_shallow(wl_config)
	wlcfg.width = cell.cfg.x11_wl_size[1]
	wlcfg.height = cell.cfg.x11_wl_size[2]

	local cl = wl_factory(source, status, wlcfg)
	if not cl then
		return
	end

-- we defer creation until the first time it is mapped
	cl.cell = cell
	link_image(source, cell.row.bg)

-- since wayland have an internal window management scheme tied to the protocol
	return cl
end

return function(cell, source, status)
-- should linking the bridge node be a temporary matter?
-- this has implications for swapping / merging rows where we'd need to relink
	image_tracetag(source, "wayland_bridge")

-- wl_connection REPLACES the handler to [source] and treats it as the pseudo-
-- factory 'wl-bridge' - whenever the proper surface has been created the 2nd
-- argument is invoked, we forward this through the wl_client
	wl_connection(source,
		function(...)
			wl_client(cell, ...)
		end, wl_config
	)
end
