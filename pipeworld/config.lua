return
{
-- not used by default as it has conflicts with other devices
	blocked_tools = {"3dnav"},

-- for more advanced coloring, just use a shader
-- r(0..255), g(0..255), b(0..255), a(0..1)
	colors = {
		background = {64, 64, 64, 1},
		rowlbl_hl = {160, 218, 169, 0.4},
		popup_bg = {64, 64, 64},

-- active hits the row that is currently active, passive applies to all other
		active =
		{
			opacity = 1.0,
			caret = {245, 223, 77, 1}, -- 'illuminating'
			row_bg = {64, 64, 64, 1},
			row_border = {0xdc, 0xb2, 0xb3, 1},
			cell_dead = {128, 32, 32, 1},
			cell_passive = {32, 32, 32, 1},
			cell_processing = {0x50, 0xfa, 0x7b, 1}, -- 'green ash'
			cell_alert = {210, 56, 108, 1}, -- 'raspberry sorbet'
			cell_completed = {210, 56, 108, 1},
			cell_selected = {0xcc, 0xa2, 0xa3, 1},
			input_background = {0, 0, 0, 0.5},
			selection_bg = {155, 183, 212, 1} -- 'cerulean'
		},

		passive =
		{
			opacity = 1.0,
			row_bg = {64, 64, 64, 1},
			row_border = {0, 0, 0, 1},
			cell_passive = {36, 36, 36, 1},
			cell_dead = {0, 0, 0, 1},
			cell_processing = {0, 0, 0, 1}, -- 'mint'
			cell_alert = {210, 56, 108, 1}, -- 'raspberry sorbet'
			cell_selected = {96, 96, 96, 1},
			cell_completed = {64, 64, 64, 1},
			input_background = {0, 0, 0, 0.5},
			selection_bg = {64, 64, 64, 1}
		},

		cursor_outline_bright = {32, 32, 32},
		cursor_outline_dark   = {164, 164, 164}
	},

-- [cell_name _ colorscheme].lua will be loaded from colorschemes/
-- (if present) and sent to the client on preroll
	cli_colorscheme = "dracula",
	terminal_colorscheme = "dracula",
	tui_colorscheme = "dracula",

-- will match a group/name/key entry in shaders/
	shader_overrides = {
		["ui_popup"] = {
			bg_color = {0x28 / 255, 0x2a / 255, 0x36/ 255},
			border_color = {0xdc / 255, 0xb2 / 255, 0xb3 / 255},
		}
	},

-- set to override the background color with a wallpaper or a shader
	wallpaper = "backgrounds/evening.jpg",

-- options are fit, pan, parallax
	wallpaper_pan = "pan",
	pan_damp = {0.05, 0.05},

	animation_speed = 15,
	animation_tween = INTERP_SMOOTHSTEP,

-- when a relayout is queued, wait (at most) this many ticks before being
-- acted upon, this and the animation_cooldown are to prevent 'storms' of
-- animations from individual cell resizes causing jerkyness
	row_animation_delay = 1,

-- when a row has been relayouted, wait at least this many ticks before
-- trying again
	row_animation_cooldown = 1,

-- pan-speed is for a full-screen pan, scaled based on distance-delta
	pan_speed = 30,

-- number of ticks before a pan operation until it is activated, then
-- animation_speed will be used as cooldown before the next is triggered
	pan_inertia = 2,

-- leave this amount of room when calculating the distance to hop
-- (-x, -y, +x, +y)
	pan_fit_margin = {10, 30, 10, 10},

-- only attempt repanning at % n of current clock
	repan_period = 10,

	row_shader = "row",
	cell_shader = "cell",

-- set to > 0 (speed) for a flash when an externally bound cell is reset
-- uses the alert color as a blended overlay
	ext_reset_flash = 10,

-- when keyboard shifts mouse focus, the mouse cursor jumps to the last
-- known mouse position within the selection
	mouse_warp = true,

-- number of ticks before the mouse cursor hides itself (0 disable)
	mouse_autohide = 200,

-- visible scale below a certain value? then just drop forwarding
	mouse_block_scale = 0.5,

-- for each new cell, height is determined by current row state
	min_w = 240,

-- default zoom and scale factors
	scale_factor = {1, 1},
	scale_step = {0.1, 0.1},
	hint_factor = {1, 1},

-- row height sets the default base for the content of each cell in a
-- a new row, then controls to modify the actual size or scale it.
	row_height = 20,

-- padding between each new row
	row_spacing = 18,

-- against left border of the screen (or new columns if multi-column)
	row_margin = 8,

-- border (px) around the entire row region
	row_border = 0,

-- padding (tldr) after the border
	row_pad = {4, 4, 4, 4},

-- border (px) around each cell within the row
	cell_border = 2,

-- against the next cell
	cell_spacing = 8,

-- client suggested background alpha on focus/normal, 0..255 scale
	cell_alpha_hint = 210,
	cell_alpha_hint_unfocus = 120,

	font = "monoOne.otf",
	font_sz = 12,
	font_hint = 2,
	input_format = "\\f%s,%d\\#fff5df",

	popup_text_valid = "\\f,0\\#dcb2b3",
	popup_text_invalid = "\\f,0\\#dcb2b3",

	label_format = "\\fmonoOne.otf,12\\#dcb2b3",
	label_maximized_format = "\\fmonoOne.otf,14\\#ffffff",
	label_unfocus_format = "\\fmonoOne.otf,12\\#000647",

-- defined in suppl.lua (suppl_ptn_expand)
-- %a = address, %t = tag, %T title, if a % does not exist, the previous
-- and subsequent character is dropped, ASCII format, UTF-8 output.
	label_ptn = "[%a:%t] %T",

-- wrap action when selection moves beyond the end of the row / column
	overflow_row = "/select/first",
	overflow_column = "/select/first_row",

-- if a cell has a new error message, defer destroying it until this amount
-- of time has elapsed
	error_timeout = 75,

-- custom cell options
--
-- this determines default pipeline order and visual positioning, with 'last'
-- the new cell is attached at the end of the chain, with 'first' the cell is
-- attached at the beginning
	cli_cell_insertion = "first",
	cli_size = {50, 1},

-- set to nil or empty to disable the autoscale behavior in vertical mode
	cli_vertical_autoscale = {0.5, 0.5, 0.25, 0.25, 0.10},

-- set cell selection wrap right behavior
	cell_wrap = "/select/down",
	row_wrap = "/insert/row/expression",

-- default terminal dimensions (in cells) used for a newly spawned
-- terminal or for a lash style cli
	terminal_size = {80, 25},

-- default resolution (pixels) for generic media/vm/game/... contents
	media_size = {1280, 720},

-- default 'output' size for fullscreened wayland / x11 windows
	x11_wl_size = {1280, 720},

-- set to empty for builtin/bitmap, additional fonts will be used for fallback
-- when a glyph is missing, mainly symbols/emoji/...
	terminal_font = {"monoOne.otf"},
	terminal_font_sz = 10,
	terminal_font_hint = 2,

-- see ARCAN_ARG=help afsrv_terminal
	terminal_arg = "",

-- allow each terminal to spawn new clients
	terminal_listen = true,

-- configurable option for the expression cell
	expression_history = 100, -- remember last n expressions
	expression_unfocus_reset = true, -- update expression contents on focus change

-- configurable options for the compose cell
	compose_policy = "ro_bin",
	compose_default_wh = {1280, 720}
}
