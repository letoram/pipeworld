local function reject()
	return false
end

local function set_broken(cell)
	local vid = random_surface(64, 64)
	resize_image(vid, 1, 1)
	cell.types = {{}, {}}
	cell:set_content(vid)
	cell.row:invalidate()
end

local function set_dead(cell, source, status)
	set_broken(cell)
	if #status.last_words > 0 then
		cell:set_error(status.last_words)
	end

	return false
end

return
function(row, cfg, identifier)
	local argstr = "capture"

	if type(identifier) == "number" then
		argstr = "no_uvc:capture:device=" .. tostring(identifier)
	elseif type(identifier) == "string" then
		argstr = "capture:" .. identifier
	end

	local res = pipeworld_cell_template("image", row, cfg)
	local vid, aid = launch_avfeed(argstr, "decode",
		pipeworld_segment_handler(res,
			{
				segment_request = reject,
				registered = reject,
				terminated = set_dead
			}
		)
	)

	if valid_vid(vid) then
		res.types = {{"video_buffer_handle", "audio_buffer_handle"}}
		res:set_content(vid, aid)
	else
		set_broken(res)
	end

	return res
end
