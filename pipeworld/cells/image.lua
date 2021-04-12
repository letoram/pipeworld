return
function(row, cfg, img)
	local res = pipeworld_cell_template("image", row, cfg)
	local vid = fill_surface(32, 32, 127, 0, 0)
	if not valid_vid(vid) then
		res:destroy()
		return
	end

	if type(img) == "string" and (resource(img)) then
		load_image_asynch(img,
		function(source, status)
			if valid_vid(vid) and status.kind == "loaded" then
				image_sharestorage(source, vid)
				res.row:invalidate()
			end
			delete_image(source)
		end
	)
	elseif valid_vid(img) then
		image_sharestorage(img, vid)
		delete_image(img)
	end

	image_mask_set(vid, MASK_UNPICKABLE)

	res:set_content(vid)
	res.types = {
		{},
		{"video_buffer_handle"}
	}

	return res
end
