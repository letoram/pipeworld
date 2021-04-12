local function get_key_host_port(dst)
	local key, rest = string.split_first(dst, "@")
	local port

	if key and #key > 0 then
		key = string.gsub(key, ":", "\t")
	end

	local host, rest = string.split_first(rest, ":")
	if host then
		port = rest and tonumber(rest) or nil
		host = host
	else
		host = rest
	end

	return key, host, port
end

local function handle_input(cell, source, iotbl)
-- if the output is valid external, just forward
	if valid_vid(cell.vid, TYPE_FRAMESERVER) then
		target_input(cell.vid, iotbl)
	end
-- otherwise we need to get creative, compose_cell etc.
end

local function def_rectgt(dst, ...)
	local opts = {
		no_audio = true,
		encoder = ""
	}
	local cell = eval_scope.cell

-- map the variable options into the table
	local encoder_suffix = ""
	local rest = {...}

	for _,v in ipairs(rest) do
		if v == "allow_input" then
			opts.input =
			function(source, iotbl)
				handle_input(cell, source, iotbl)
			end
		end
	end

	local proto, dst = string.split_first(dst, "://")
	if not proto then
		cell:set_error("missing protocol (protocol://)")
		return
	end

-- This 'pushes' the composited output as a regular client to an a12 session
	if proto == "a12" then
		opts.encoder = "protocol=a12"
		dst = string.sub(dst, 7)

-- Fetch connection data from keystore, safest option
		if string.sub(dst, #dst) == "@" then
			opts.encoder = opts.encoder .. ":outkey=" .. string.sub(dst, 7, -2)
		else
			local key, host, port = get_key_host_port(dst)
			if not host then
				cell:set_error("a12:// bad format, expected key@host:port")
				return
			end
			opts.encoder = opts.encoder .. ":outhost=" .. host
			if key then
				opts.encoder = opts.encoder .. ":authk=" .. key
			end
			if port then
				opts.encoder = opts.encoder .. ":port=" .. tostring(port)
			end
		end

-- this listens-in using an optional shared secret
	elseif proto == "a12-in" then
		dst = string.sub(dst, 10)
		local key, host, port = get_key_host_port(dst)
		opts.encoder = "protocol=a12"

		if key then
			opts.encoder = opts.encoder .. ":authk=" .. key
		end

		if port then
			opts.encoder = opts.encoder .. ":port=" .. tostring(port)
		end

-- vnc only has an incoming form, secret@ host:port
	elseif proto == "vnc" then
		opts.encoder = "protocol=vnc"
		local key, host, port = get_key_host_port(dst)

		if port then
			opts.encoder = opts.encoder .. ":port=" .. tostring(port)
		end
		if key then
			opts.encoder = opts.encoder .. ":pass=" .. key
		end
	else
		cell:set_error("unknown protocol: " .. proto)
		return
	end

	opts.encoder = opts.encoder .. encoder_suffix

-- First argument here is a bit weird, it's used for streaming to another cell or
-- recording to a file or set of files. Since we do desktop sharing here, there is
-- no need.
	local res, msg = cell:add_encoder("", opts)
	if not res then
		cell:set_error(msg)
		return
	end
end

local function dest_helper()
-- arcan-net still doesn't have a way to enumerate known keystore tags, otherwise
-- that would be a good helper
	return
	{
		"a12://tag@",
		"a12://secret@host:port",
		"a12-in://secret@[listen]:port",
		"vnc://secret@[listen]:port",
	}
end

local function fmt_helper()
-- these depend on the destination argument, since the helpers have no way of synching
-- between each-other yet, we will have to make do with an approximation
	return
	{
		"vcodec=h264",
		"vcodec=raw",
		"allow_input",
		"audio"
	}
end

return function(types)
	return {
		handler = def_rectgt,
		args = {types.NIL, types.STRING, types.STRING, types.VARARG},
		names = {"destination", "options"},
		type_helper = {dest_helper, fmt_helper},
		argc = 1,
		help = "Share cell contents over a network connection.",
	}
end
