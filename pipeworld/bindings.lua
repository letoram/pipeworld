local symtable = system_load("builtin/keyboard.lua")()
symtable.meta_1_sym = "RCTRL"
symtable.meta_2_sym = "LSHIFT"

-- a single key is used for simple paths ["m1_mykey"] = "/something/simple"
-- a table is used to forward arguments ["m1_mykey"] = {"/something/less/simple", 0.1, 0.2},
-- multiple actions is a table with the key group = { } and tables of argumented actions

return
symtable,
{
-- will be substituted in for 'm1' and 'm2'
	["meta_1"] = "rctrl",
	["meta_2"] = "lshift",

-- mouse actions (invalidate/all is used to cancel animations)
--	["bg_mouse_wheel_up"] = {group = {{"/scale/all/increment", 0.1}, {"/invalidate/all"}}},
	["bg_mouse_wheel_up"] = {group = {{"/scale/all/increment", 0.1}}},
	["bg_mouse_wheel_down"] = {group = {{"/scale/all/decrement", 0.1}}},
	["bg_mouse_dblclick"] = {group = {{"/scale/all/toggle"}}},
	["spawn_anchor_click"] = "/insert/row/expression",
	["spawn_anchor_rclick"] = "/popup/insert_menu",
	["row_spawn_anchor_click"] = "/append/row/expression",
	["row_spawn_anchor_rclick"] = "/popup/insert_row_menu",
	["bg_mouse_rclick"] = "/popup/system_menu",
	["row_bg_rclick"] = "/popup/row_menu",
	["row_label_rclick"] = "/popup/cell_menu",

-- regular bindings
	["m1_TAB"] = "/popup/cell_menu",
	["m2_TAB"] = "/popup/system_menu",
	["m1_UP"] = {group = {"/select/up", "/pan/focus"}},
	["m1_k"] = {group = {"/select/up", "/pan/focus"}},
	["m1_DOWN"] = {group = {"/select/down", "/pan/focus"}},
	["m1_j"] = {group = {"/select/down", "/pan/focus"}},
	["m1_RIGHT"] = {group = {"/select/next", "/pan/focus"}},
	["m1_l"] = {group = {"/select/next", "/pan/focus"}},
	["m1_LEFT"] = {group = {"/select/previous", "/pan/focus"}},
	["m1_h"] = {group = {"/select/previous", "/pan/focus"}},
	["m1_HOME"] = {group = {"/select/first", "/pan/focus"}},
	["m1_END"] = {group = {"/select/last", "/pan/focus"}},
	["m1_BACKSPACE"] = {group = {"/delete/cell", "/pan/focus"}},
	["m1_f"] = {group = {"/maximize/cell", "/pan/focus"}},
	["m1_t"] = "/revert/cell",
	["m1_m2_q"] = "/shutdown/system",
	["m1_m2_BACKSPACE"] = "/delete/row",
	["m1_s"] = "/popup/cursor/sysexpr",
	["m1_d"] = "/popup/cursor/cellexpr",
	["m1_RETURN"] = {"/insert/row/expression"},
	["m1_r"] = "/reset/cell",
	["m1_m2_r"] = "/reset/anchor",

-- size modifies scale factor for presentation (forced)
	["m1_F1"] = {group = {{"/scale/row/set", 0.2, 0.2}}},
	["m1_F2"] = {"/scale/row/set", 1.0, 1.0},

-- hint requests content to change its allocated size (suggested)
	["m1_PLUS"] = {"/hint/cell/increment", 100, 100},
	["m1_MINUS"] = {"/hint/cell/decrement", 100, 100},

-- special events
	["row_deselect"] = {},
	["row_select"] = {}
}
