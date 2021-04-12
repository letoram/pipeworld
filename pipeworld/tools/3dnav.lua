-- changes:
--
-- since device is normalized we also need to change weights based on current window aspect for it to feel 'right'
-- need to kill animation speed on scaling / relayout
-- need to have a switch to use 'stepper nav'
--

local navcfg = {
	axis_map = {-1, 1, 1},
	axis_scale = {5, 5, 3},

-- when at the extremes we also get input on the z-axis, so interpret that accordingly
	z_fact = 1,
	highpass = 0.1,
	lowpass = 0.01,

	range = {
		{-1, 1},
		{-1, 1},
		{-1, 1}
	},

-- pan XOR zoom
	motion_cd = 50,
	motion_x = false,
	motion_y = false,
	zoom_cd = 10,

	motion_inertia_x = 2,
	motion_inertia_y = 2,
	motion_acc_x = 0,
	motion_acc_y = 0,

-- current values
	in_motion = 0,
	in_zoom = 0,
}

local buttons = {
	[1]   = "/global/input/keyboard/symbol/escape", -- ESC
	[8]   = "", -- Alt
	[9]   = "", -- Shift
	[10]  = "", -- Control
	[11]  = "", -- spin
	[256] = "/global", -- Menu
	[268] = "/global/input/mouse/buttons/1", -- 1
	[269] = "/global/input/mouse/buttons/2", -- 2
	[270] = "/global/input/mouse/buttons/3", -- 3
	[281] = "", -- 4
	[257] = "/target", -- fit
	[258] = "", -- top
	[260] = "", -- right
	[261] = "", -- front
	[264] = "", -- roll
}

local function xpan(wm, cfg, io)
end

local function ypan(wm, cfg, io)
end

local function range_sample(val, ind)
	if val < 0 then
		if val < navcfg.range[ind][1] then
			navcfg.range[ind][1] = val
		end
		return val * (1 / (-navcfg.range[ind][1]))
	elseif val > 0 then
		if val > navcfg.range[ind][2] then
			navcfg.range[ind][2] = val
		end
		return val * (1 / navcfg.range[ind][2])
	end
end

local function gengame_handler(wm, cfg, io)
-- rx
	if io.subid == 0 and navcfg.in_zoom == 0 then
		local cs = navcfg.axis_scale[1] *
			range_sample(io.samples[1] * navcfg.axis_map[1], 1)
		local acs = math.abs(cs)

		navcfg.motion_acc_x = navcfg.motion_acc_x + cs
		if math.abs(navcfg.motion_acc_x) < navcfg.motion_inertia_x then
			return
		end

		if acs < navcfg.lowpass then
			navcfg.motion_x = false
			if not navcfg.motion_x and not navcfg.motion_y then
				navcfg.in_motion = navcfg.motion_cd
				return
			end
		else
			navcfg.motion_x = true
		end

-- if the sample drops beneath the deadzone floor, remove this from the motion state
		navcfg.in_motion = navcfg.motion_cd
		local dx = cs * navcfg.z_fact
		nudge_image(wm.anchor, dx, 0)

-- ry
	elseif io.subid == 1 and navcfg.in_zoom == 0 then
		local cs = navcfg.axis_scale[2] *
			range_sample(io.samples[1] * navcfg.axis_map[2], 1)
		local acs = math.abs(cs)

		navcfg.motion_acc_y = navcfg.motion_acc_y + cs
		if math.abs(navcfg.motion_acc_y) < navcfg.motion_inertia_y then
			return
		end

		if acs < navcfg.lowpass then
			navcfg.motion_y = false
			if not navcfg.motion_x and not navcfg.motion_y then
				navcfg.in_motion = navcfg.motion_cd
				return
			end
		else
			navcfg.motion_y = true
		end

		navcfg.in_motion = navcfg.motion_cd
		local dy = cs * navcfg.z_fact
		nudge_image(wm.anchor, 0, dy)

-- zaxis, filter heavier as it is both costly and 'annoying'
	elseif io.subid == 2 then
		local cs = navcfg.axis_scale[3] *
			range_sample(io.samples[1] * navcfg.axis_map[3], 1)
		local acs = math.abs(cs)

		if acs > navcfg.highpass and navcfg.in_motion == 0 then
			navcfg.in_zoom = navcfg.zoom_cd
			navcfg.motion_acc_x = 0
			navcfg.motion_acc_y = 0

			local cmd = "/scale/all/" .. (cs > 0 and "increment" or "decrement")
			cfg.actions(cmd, 0.01)
			wm:invalidate(true, true)

-- re-emit z-axis as contributing to the current motion vector
		else
			if navcfg.in_motion > 0 then
				navcfg.z_fact = 1.0 + acs;
			end
		end
	elseif io.subid == 3 then
	end
end

local function tick()
	if navcfg.in_motion > 0 then
		navcfg.in_motion = navcfg.in_motion - 1
		if navcfg.in_motion == 0 then
			navcfg.motion_acc_x = 0
			navcfg.motion_acc_y = 0
		end
	end

	if navcfg.in_zoom > 0 then
		navcfg.in_zoom = navcfg.in_zoom - 1
	end
end

return
function(cfg)
	arcantarget_hint("input_label", {
		labelhint = "pan_x",
		description = "pan the world anchor in the x axis",
		datatype = "analog",
	})

-- mainly deal with the specific devices, but also allow the generic- n_m
--	pipeworld_input_hook_label("pan_x", "analog", xpan)
--	pipeworld_input_hook_label("pan_y", "analog", ypan)

	pipeworld_input_hook_device(
		"3Dconnexion SpaceMouse Pro", rawdevice_handler)

	pipeworld_input_hook_device("analog", gengame_handler)

	timer_add_periodic("3dnav", 1, false, tick, true)
end
