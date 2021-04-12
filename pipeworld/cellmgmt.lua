local row_mgmt = system_load("wm.lua")()           -- 'mini-WM'

system_load("cells/shared/base.lua")()              -- basic interface for a cell

return
function(anchor, conf)
	local ctx = row_mgmt(anchor, conf)

	ctx:add_cell_type("cli", system_load("cells/cli.lua")())
	ctx:add_cell_type("terminal", system_load("cells/term.lua")())
	ctx:add_cell_type("image", system_load("cells/image.lua")())
	ctx:add_cell_type("expression", system_load("cells/expression.lua")())
	ctx:add_cell_type("capture", system_load("cells/capture.lua")())
	ctx:add_cell_type("compose", system_load("cells/compose.lua")())
	ctx:add_cell_type("listen", system_load("cells/listen.lua")())
	ctx:add_cell_type("debug", system_load("cells/debug.lua")())
	ctx:add_cell_type("target", system_load("cells/target.lua")())
	ctx:add_cell_type("adopt", system_load("cells/adopt.lua")())

	return ctx
end
