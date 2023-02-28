local symtable = system_load("builtin/keyboard.lua")()
symtable:load_translation()
symtable:load_keymap("default.lua")
symtable:kbd_repeat()

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
	["bg_mouse_wheel_up"] = {group = {{"/scale/group/increment", 0.1}}},
	["bg_mouse_wheel_down"] = {group = {{"/scale/group/decrement", 0.1}}},
	["bg_mouse_dblclick"] = {group = {{"/scale/group/toggle"}}},
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
	["m1_m2_TAB"] = "/popup/row_menu",
	["m1_m2_h"] = "/popup/insert_row_menu",
	["m1_m2_k"] = "/popup/insert_menu",
	["m1_UP"] = {group = {"/select/up", "/pan/focus"}},
	["m2_LEFT"] = {group = {"/swap/cell/left", "/pan/focus"}},
	["m2_RIGHT"] = {group = {"/swap/cell/right", "/pan/focus"}},
	["m2_UP"] = {group = {"/swap/row/up", "/pan/focus"}},
	["m2_DOWN"] = {group = {"/swap/row/down", "/pan/focus"}},
	["m1_m2_l"] = {group = {"/append/row/expression", "/pan/focus"}},
	["m1_m2_j"] = {group = {"/insert/row/expression", "/pan/focus"}},
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
	["m1_a"] = "/popup/cursor/rowexpr",
	["m1_RETURN"] = {group = {"/insert/row/expression", "/pan/focus"}},
	["m1_r"] = "/reset/cell",
	["m1_m2_r"] = "/reset/anchor",
	["m1_m2_KP_PLUS"] = {group = {{"/scale/group/increment", 0.1}}},
	["m1_m2_KP_MINUS"] = {group = {{"/scale/group/decrement", 0.1}}},
	["m1_m2_KP_MULTIPLY"] = {group = {{"/scale/group/toggle"}}},
	["m1_c"] = "/clipboard/copy",
	["m1_v"] = "/clipboard/paste",
	["m1_z"] = "/link/row",

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
