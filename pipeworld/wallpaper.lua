local wallpaper
local wallpaper_sp

local function update_fit(wp, cfg, w, h)
	resize_image(wallpaper, w, h)
end

-- we have no easy/clean way to animate texture coordinates for the time
-- being, so have to deal with it by either hooking the frame updates and
-- synching every frame (expensive) or running a timer.
local function update_pan(cfg, anchor, w, h)
	local sp = image_storage_properties(wallpaper)
	local ofs = image_surface_properties(anchor)
	resize_image(wallpaper, w, h)

-- calculate 'cropped' region and center, this will only clamp/stretch if
-- source is too small - should consider at least repeat or clamp-to-edge
	local rw = math.clamp(w / sp.width, 0.0, 1.0)
	local rh = math.clamp(h / sp.height, 0.0, 1.0)

	local sw = 0.0
	local sh = 0.0

	sw = (ofs.x * 1.0 / sp.width) * cfg.pan_damp[1]
	sh = (ofs.y * 1.0 / sp.height) * cfg.pan_damp[2]

	if sw < 0.0 then
		sw = 0.0
	end

	if sh < 0.0 then
		sh = 0.0
	end

	if sw + rw > 1.0 then
		sw = 1.0 - rw
	end

	if sh + rh > 1.0 then
		sh = 1.0 - rh
	end

	image_set_txcos(wallpaper, {
		sw, sh,
		sw + rw, sh,
		sw + rw, sh + rh,
		sw, sh + rh
	});
end

return
function(wm, cfg)
	local res = cfg.wallpaper

	if res == nil then
		return
	end

-- "fit" : just resize
-- "pan" : scale if too small for screen, otherwise move with the cursor
-- "parallax" : use cursor distance from center to calculate wallpaper offset

	if cfg.wallpaper_pan == "pan" then
		local anchor = cfg.world_anchor
		cfg.wallpaper_update =
		function()
		end

		timer_add_periodic("pan_synch", 1, false,
			function()
				update_pan(cfg, anchor, wm.w, wm.h)
			end, false
		)
	elseif cfg.wallpaper_pan == "parallax" then
	else
		cfg.wallpaper_update = update_fit
	end

	wallpaper = null_surface(wm.w, wm.h)
	image_mask_set(wallpaper, MASK_UNPICKABLE)
	image_tracetag(wallpaper, "wallpaper")

	if string.sub(res, 1, 8) == "shaders/" then
-- need the suppl_load_shader
	else
		local vid = load_image(res)
		if not valid_vid(vid) then
			vid = fill_surface(32, 32, 32, 32, 32)
		end

		image_sharestorage(vid, wallpaper)
		delete_image(vid)
		cfg.wallpaper_update(wallpaper, cfg, wm.w, wm.h)
	end

	return wallpaper
end
