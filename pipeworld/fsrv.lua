local scheme_cache = {}
local apply_default_cell = system_load("cells/shared/fsrv.lua")()
local apply_wl_cell = system_load("cells/shared/wayland.lua")()
local clipboard = system_load("builtin/clipboard.lua")()

function pipeworld_clipboard()
	return clipboard
end

local function ensure_colorscheme(scheme, vid)
	if not scheme_cache[scheme] then
		local stat, msg =
			suppl_load_script_tbl("devmaps/colorschemes/", scheme)
		if not stat then
			return stat, msg
		end
		scheme_cache[scheme] = stat
	end

	suppl_tgt_color(vid, scheme_cache[scheme])
	return true
end

function pipeworld_send_colors(cell, scheme)
	return ensure_colorscheme(scheme, cell.vid)
end

function pipeworld_preferred_font(cell, vid, kind)
	local font, font_sz, hint

	if kind == "terminal" or kind == "tui" then
		font = cell.cfg.terminal_font
		font_sz = cell.cfg.terminal_font_sz
		hint = cell.cfg.terminal_font_hint
	else
		font = cell.cfg.font
		font_sz = cell.cfg.font_sz
		hint = cell.cfg.font_hint
	end

	if type(font) == "string" then
		font = {font}
	end

	for i=1,#font do
		local fh, a, b = target_fonthint(vid, font[i], font_sz * FONT_PT_SZ, hint, i ~= 1)
		if i == 1 then
			cell.fonthint_wh = {a, b}
		end
	end
end

function pipeworld_preferred_size(cell, kind, cw, ch)
	local _, _, w, h = cell.row:cell_size()

	if kind == "terminal" or kind == "tui" then
		local sz_cm = cell.row.cfg.terminal_font_sz * FONT_PT_SZ / 10

-- let cell type override dimensions
		tsz = cell.terminal_size and cell.terminal_size or cell.cfg.terminal_size

		if not cw or cw <= 0 then
			if cell.fonthint_wh then
				cw = cell.fonthint_wh[1]
			else
				cw = math.ceil(sz_cm * HPPCM)
			end
		end

		if not ch or ch <= 0 then
			if cell.fonthint_wh then
				ch = cell.fonthint_wh[2]
			else
				ch = math.ceil(sz_cm * VPPCM)
			end
		end

		w = math.ceil(cw * tsz[1])
		h = math.ceil(ch * tsz[2])
	else
		pxsz = cell.media_size and cell.media_size or cell.cfg.media_size
		w = pxsz[1]
		h = pxsz[2]
	end

	return w, h
end

local allowed = {}

local function segreq_to_cell(cell, source, status, ...)
-- don't need to create a new cell for a new primary connection
	local w, h = pipeworld_preferred_size(cell, status.segkind)
	local vid

-- comes from handover -> registered
	if status.kind == "registered" then
		vid = source
-- comes from segment_request
	else
		local w, h = pipeworld_preferred_size(cell, status.segkind)

-- handler will be replaced by caller into something with the right type
		vid = accept_target(w, h, function() end)
		if not valid_vid(vid) then
			return
		end
	end

-- cell might still want to administer custom attachment / wm actions, note
-- that the segkind forwarding here means that there is possible namespace
-- collision between our cell type names and the external set of possible
-- types.
	local res
	if cell.on_child then
		res = cell:on_child(vid, status.segkind)
	else
-- allocation might fail when adding the cell itself, if there is an on_child
-- handler it will be responsible, otherwise it is done here
		res = cell.row:add_cell(
		function(row, cfg)
			local res = pipeworld_cell_template(status.segkind, row, cfg)
			return res
		end
		)
		if not res then
			delete_image(vid)
			return
		end
	end

	return res, vid
end

local function handle_clipboard(cell, source, status, ...)
	if valid_vid(cell.clipboard, TYPE_FRAMESERVER) then
		delete_image(cell.clipboard)
	end

	cell.clipboard = accept_target()
	if not valid_vid(cell.clipboard) then
		return
	end

-- we can have a per-cell history here, but there is no table type or
-- array qualifier in the type model yet
	cell.suffix_handler.export["clipboard"] =
	function(cell, outtype)
		if outtype == "text/plain" then
			return clipboard:list_local(cell.clipboard)[1], outtype
		end
	end

	target_updatehandler(cell.clipboard,
	function(source, status)
		if status.kind == "terminated" then
			delete_image(source)
			return
		elseif status.kind == "message" then
			clipboard:add(source, status.message, status.multipart)
		end
	end)
end

local function basic_client(cell, source, status, ...)
	local new, vid = segreq_to_cell(cell, source, status, ...)
	if not new then
		return
	end

-- need some tracking to deal with unregistering clipboard
	local od = new.destroy
	new.destroy = function(cell, ...)
		if valid_vid(cell.clipboard) then
			delete_image(cell.clipboard)
		end

		clipboard:lost(source)
		return od(cell, ...)
	end

	apply_default_cell(new, vid)
	target_updatehandler(vid, pipeworld_segment_handler(new, {}))
	new:unfocus()

	return new
end

local function wl_client(cell, source, status, ...)
	local new, vid = segreq_to_cell(cell, source, status, ...)
	if not new then
		return
	end

-- these need some special jacking in to handle clipboard and dnd
	apply_wl_cell(new, vid)
	return new
end

local block_primary = {
	"clipboard", "widget", "popup", "handover", "debug"
}

-- this defer actual configuration until we have the 'registered' type
local function handover_client(cell, source, status, ...)
	local tgt = accept_target(32, 32,
		function(source, status)
			if status.kind == "terminated" then
				delete_image(source)
				warning("handover-client died during connection negotiation")
				return
			end
			if status.kind == "registered" then
				if table.find_i(block_primary, status.segkind) then
					warning("handover to blocked primary " .. status.segkind)
					delete_image(source)
					return
				end

				local hnd = allowed[status.segkind]
				if not hnd then
					warning("blocking primary with unhandled type " .. status.segkind)
					delete_image(source)
					return
				end

				local res = hnd(cell, source, status)
				if res then
					target_updatehandler(source, pipeworld_segment_handler(res, {}))
				end
			end
		end
	)
-- for life-span, will get relinked when mutated into a cell
	link_image(tgt, cell.bg)
end

allowed = {
	["terminal"] = basic_client,
	["tui"] = basic_client,
	["lightweight arcan"] = basic_client,
	["handover"] = handover_client,
	["bridge-wayland"] = wl_client,
	["bridge-x11"] = basic_client,
	["multimedia"] = basic_client,
	["application"] = basic_client,
	["game"] = basic_client,
	["vm"] = basic_client,
	["browser"] = basic_client,
	["debug"] = basic_client,
-- missing:
	["clipboard"] = handle_clipboard,
	["widget"] = handle_widget,
	["popup"] = handle_popup,
-- doesn't make sense here at all:
-- hmd-r, hmd-sbs-lr, hmd-l, sensor, service
}

local function fsrv_segreq(cell, source, status)
	if not allowed[status.segkind] then
		return false
	end

	return allowed[status.segkind](cell, source, status)
end

local function fsrv_registered(cell, source, status)
	if not allowed[status.segkind] then
		warning("block unallowed " .. status.segkind)
		delete_image(source)
	end

	if table.find_i(block_primary, status.segkind) then
		warning("connection attempt from blocked primary " .. status.segkind)
		cell:set_state("dead")
		return
	end

	return allowed[status.segkind](cell, source, status)
end

local function fsrv_dead(cell, source, status)
	cell:set_state("dead")

	if #status.last_words > 0 then
		cell:set_error(status.last_words)
	end

	if cell.autodelete or cell.row.autodelete then
		cell.row:delete_cell(cell)
	end
end

local function fsrv_ident(cell, source, status)
	cell.title = status.message
	cell.row:invalidate()
end

local function fsrv_resized(cell, source, status)
	cell.row:invalidate(nil, true)
	cell.fsrv_size = {status.width, status.height}

	if status.origo_ll then
		image_set_txcos_default(source, status.origo_ll)
	end

-- resize might cause us to overflow, in those cases re-calculate
-- panning so that it still fits
	local focused, _, in_cell = cell.row:focused()
	if in_cell == cell then
		cell:focus()
	end
end

local function fsrv_cstate(cell, source, status)
	cell.content = status

	if status.max_w == 0 or status.max_h == 0 then
			return
		end

	target_displayhint(source, status.max_w, status.max_h, TD_HINT_UNCHANGED)
end

local function fsrv_preroll(cell, source, status)
	cell.segkind = status.segkind

	local scheme = cell.cfg[cell.name .. "_colorscheme"]
	if scheme then
		local ok, msg = ensure_colorscheme(scheme, source)
		if not ok then
			warning(msg)
		end
	end

-- send the displayhint in advance to probe/get the size
	pipeworld_preferred_font(cell, source, cell.segkind)
	local cw, ch = target_displayhint(source, 0, 0, TD_HINT_UNFOCUSED, WORLDID)

-- these will just accumulate throughout preroll so it doesn't matter
	local w, h = pipeworld_preferred_size(cell, cell.segkind, cw, ch)
	target_displayhint(source, w, h, TD_HINT_UNFOCUSED, WORLDID)
end

local function fsrv_labelhint(cell, source, status)
-- reset?
	if #(status.labelhint) == 0 then
		cell.input_labels = {}
		cell.input_syms = {}
		return
	end

-- analog/touch/... mapping not supported atm.
	if not status.datatype == "digital" then
		return
	end

	cell.input_labels[status.labelhint] = status

-- convert keysym and modifiers to string
	if status.initial > 0 then
		local lbl = cell.cfg.keyboard[status.initial]
		if lbl then
			cell.input_syms[decode_modifiers(status.modifiers, "_") .. lbl] = status.labelhint
		end
	end
end

local function fsrv_streamstat(cell, source, status)
	if status.completion < 0.9999999 then
		cell:set_state("processing")
		cell:recolor()
	else
		cell:set_state("completed")
		cell:recolor()
	end
end

local handlers =
{
	["terminated"] = fsrv_dead,
	["ident"] = fsrv_ident,
	["resized"] = fsrv_resized,
	["segment_request"] = fsrv_segreq,
	["content_state"] = fsrv_cstate,
	["preroll"] = fsrv_preroll,
	["streamstatus"] = fsrv_streamstat,
	["registered"] = fsrv_registered,
	["input_label"] = fsrv_labelhint,
	["failure"] = nil, -- special case of alert
	["alert"] = nil,
	["state_size"] = nil, -- should dynamically change the set of cell inputs/outputs
	["viewport"] = nil,
	["clock"] = nil,
	["cursor"] = nil, -- should have cursor-sets (and a default in distr)
	["bchunkstate"] = nil,
	["message"] = nil, -- type specific hacks
	["mask_input"] = nil, -- uninteresting
	["ramp_update"] = nil, -- clients are not allowed display controls
	["coreopt"] = nil, -- should probably support
	["framestatus"] = nil, -- should enable if we have some clock event chain
	["streaminfo"] = nil, -- type specific, should add stream selection controls
	["proto_update"] = nil,
}

-- Factory for an external event handler, overrides contain any events
-- that should replace the default implementation.
function pipeworld_segment_handler(cell, overrides, segoverride)
	return
	function(source, status, ...)
-- chain died, block input waiting for the user to destroy it,
-- but since we are inactive we can't rerun the pipeline anymore
	if overrides[status.kind] then
		return overrides[status.kind](cell, source, status, handlers[status.kind], ...)
	end

-- allow the default segment handler to be used
	if (status.kind == "segment_request" or status.kind == "registered") and
		segoverride and segoverride[status.segkind] then
		return segoverride[status.segkind](cell, source, status)
	end

	local hnd = handlers[status.kind]
	if hnd then
		return hnd(cell, source, status)
	end

	if DEBUGLEVEL > 0 then
		print("unhandled", status.kind)
	end
	end
end
