-- helper functions for string and table manipulation
--
-- this acts as an incumbator or so, the more used functions eventually
-- move into upstream arcan/builtin and shared with others (durden etc.)
--

function suppl_size_lut(graphical, media)
	if graphical then
		if media then
			return
			{
				["480p"] = {852, 480},
				["720p"] = {1280, 720},
				["1080p"] = {1920, 1080},
				["1440p"] = {2560, 1440},
				["2k"] = {2048, 1080},
				["4k"] = {3840, 2160},
			}
		end
		return
		{
			["640x480"] = {640, 480},
			["800x600"] = {800, 600},
			["852x480"] = {852, 480},
			["1920x1080"] = {1920, 1080},
		}
	end

	return
	{
		["50x1"] = {50, 1},
		["80x24"] = {80, 24},
		["80x25"] = {80, 25},
		["132x24"] = {132, 24},
		["132x43"] = {132, 43}
	}
end

function math.clamp(val, low, high)
	if (low and val < low) then
		return low;
	end
	if (high and val > high) then
		return high;
	end
	return val;
end

function table.copy_shallow(t)
	local res = {}
	for k,v in pairs(t) do
		res[k] = v
	end
	return res
end

function table.linearize(tbl, sort, prefix)
	local res = {}
	for k,v in pairs(tbl) do
		if not prefix or string.match(k, prefix) then
			table.insert(res, {k, v})
		end
	end
	if sort then
		table.sort(res,
		function(a, b)
			return a[1] <= b[1]
		end)
	end
	return res
end

function table.force_find_i(t, ref)
	for i,v in ipairs(t) do
		if v == ref then
			return i
		end
	end
	error("required reference not in table")
end

function table.wipe(t)
	local set = {}
	for k,v in pairs(t) do
		table.insert(set, k)
	end
	for _,v in ipairs(set) do
		t[v] = nil
	end
end

function math.sign(val)
	return (val < 0 and -1) or 1;
end

function table.ensure_defaults(dst, ref)
	for k,v in pairs(ref) do
		if not dst[k] then
			dst[k] = v
		elseif type(dst[k]) ~= type(v) then
			warning("ensure_defaults, type conflict on key " .. k)
			dst[k] = v
		end
	end
	return dst
end

-- send a color table
function suppl_tgt_color(vid, tbl)
	assert(valid_vid(vid), "invalid vid to suppl_color")
	for i=1,36 do
		local v = tbl[i]
		if v and #v > 0 then
			target_graphmode(vid, i + 1, v[1], v[2], v[3])
			if #v == 6 then
				target_graphmode(vid, bit.bor(i + 1, 256), v[4], v[5], v[6])
			end
		end
	end
	target_graphmode(vid, 0)
end

function suppl_load_script_tbl(base, name)
	local fn = base .. name .. ".lua"
	if not resource(fn) then
		return false, string.format("missing script: %s", fn)
	end

	local tbl, msg = system_load(fn, false)
	if not(tbl) then
		return false, (string.format("couldn't parse %s: %s", fn, msg))
	end

	local ok, tbl = pcall(tbl)
	if not ok or type(tbl) ~= "table" then
		return false, (string.format("%s didn't return a table", fn))
	end
	return tbl
end

function suppl_gsub_cb(instr, ptn, lookup)
	local pos, stop = string.find(instr, ptn)
	if not pos then
		return instr
	end

	local res = {}
	local start = pos
	if pos ~= 1 then
		table.insert(res, string.sub(instr, 1, pos-1))
	end

	while pos do
		local ch = string.sub(instr, pos, stop)
		local exp = lookup(ch)

		table.insert(res, string.sub(instr, start, pos-1))

		if exp then
			table.insert(res, exp)
		end

		start = stop + 1
		pos, stop = string.find(instr, ptn, start)
	end

	table.insert(res, string.sub(instr, start))
	return res
end

function suppl_string_to_keyboard(str, kbd)
-- not utf-8 correct
	local res = {}

	for i=1,#str do
		local ch = string.sub(str, i, i)
		local sub = string.byte(ch)
		local tbl = {
			kind = "digital",
			translated = true,
			digital = true,
			active = true,
			utf8 = ch,
			devid = 0,
			subid = sub,
			keysym = sub,
			modifiers = 0,
			number = sub
		}
		table.insert(res, tbl)
		tbl = table.copy_shallow(tbl)
		tbl.active = false
		table.insert(res, tbl)
	end

	return res
end

-- register a prefix_debug_listener function to attach/define a
-- new debug listener, and return a local queue function to append
-- to the log without exposing the table in the global namespace
local prefixes = {
};
function suppl_add_logfn(prefix)
	if (prefixes[prefix]) then
		return prefixes[prefix][1], prefixes[prefix][2];
	end

-- nest one level so we can pull the scope down with us
	local logscope =
	function()
		local queue = {};
		local handler = nil;

		prefixes[prefix] =
		{
			function(msg)
				local exp_msg = CLOCK .. ":" .. msg .. "\n";
				if (handler) then
					handler(exp_msg);
				else
					table.insert(queue, exp_msg);
					if (#queue > 200) then
						table.remove(queue, 1);
					end
				end
			end,
-- return a formatter as well so we can nop-out logging when not needed
			string.format,
		};

-- and register a global function that can be used to set the singleton
-- that the queue flush to or messages gets immediately forwarded to
		_G[prefix .. "_debug_listener"] =
		function(newh)
			if (newh and type(newh) == "function") then
				handler = newh;
				for i,v in ipairs(queue) do
					newh(v);
				end
			else
				handler = nil;
			end
			queue = {};
		end
	end

	logscope();
	return prefixes[prefix][1], prefixes[prefix][2];
end
