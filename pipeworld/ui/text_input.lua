--
-- readline input type control
-- derived from suppl.lua in durden
--
-- returns a function that takes a previous state context (or nil),
-- along with the input and resolved symbol
--

local function text_input_table(ctx, io, sym)
	if not io.active then
		return;
	end

-- first check if modifier is held, and apply normal 'readline' translation
	local modstr = table.concat(decode_modifiers(io.modifiers), "_")
	local ctrl = modstr == "lctrl" or modstr == "rctrl"

	if ctrl then
		if sym == "a" then
			ctx:caret_home()
			return
		elseif sym == "e" then
			ctx:caret_end()
			return
		elseif sym == "l" then
			ctx:clear()
		end
	end

-- then check if the symbol matches our default overrides
	if sym and ctx.bindings[sym] then
		ctx.bindings[sym](ctx);
		return;
	end

-- last normal text input
	local keych = io.utf8
	if (keych == nil or keych == '') then
		return ctx;
	end

	ctx.oldmsg = ctx.msg;
	ctx.oldpos = ctx.caretpos;
	local nch
	ctx.msg, nch = string.insert(ctx.msg, keych, ctx.caretpos, ctx.nchars);

	ctx.caretpos = ctx.caretpos + nch;
	ctx:update_caret();
end

local function text_input_view(ctx)
	local rofs = string.utf8ralign(ctx.msg, ctx.chofs + ctx.ulim);
	local str = string.sub(ctx.msg, string.utf8ralign(ctx.msg, ctx.chofs), rofs-1);
	return str;
end

local function text_input_caret_str(ctx)
	return string.sub(ctx.msg, ctx.chofs, ctx.caretpos - 1);
end

-- should really be more sophisticated, i.e. a push- function that deletes
-- everything after the current undo index, a back function that moves the
-- index upwards, a forward function that moves it down, and possible hist
-- get / set.
local function text_input_undo(ctx)
	if (ctx.oldmsg) then
		ctx.msg = ctx.oldmsg;
		ctx.caretpos = ctx.oldpos;
	end
end

local function text_input_set(ctx, str)
	ctx.msg = (str and #str > 0) and str or "";
	ctx.caretpos = string.len( ctx.msg ) + 1;
	ctx.chofs = ctx.caretpos - ctx.ulim;
	ctx.chofs = ctx.chofs < 1 and 1 or ctx.chofs;
	ctx.chofs = string.utf8lalign(ctx.msg, ctx.chofs);
	ctx:update_caret();
end

-- caret index has changed to some arbitrary position,
-- make sure the visible window etc. is updated to match
local function text_input_caretalign(ctx)
	if (ctx.caretpos - ctx.chofs + 1 > ctx.ulim) then
		ctx.chofs = string.utf8lalign(ctx.msg, ctx.caretpos - ctx.ulim);
	end
end

local function text_input_chome(ctx)
	ctx.caretpos = 1;
	ctx.chofs    = 1;
	ctx:update_caret();
end

local function text_input_cend(ctx)
	ctx.caretpos = string.len( ctx.msg ) + 1;
	ctx.chofs = ctx.caretpos - ctx.ulim;
	ctx.chofs = ctx.chofs < 1 and 1 or ctx.chofs;
	ctx.chofs = string.utf8lalign(ctx.msg, ctx.chofs);
	ctx:update_caret();
end

local function text_input_cset(ctx, pos)
	ctx.caretpos = pos
	ctx.chofs = ctx.caretpos - ctx.ulim
	ctx:update_caret();
end

local function text_input_cleft(ctx)
	ctx.caretpos = string.utf8back(ctx.msg, ctx.caretpos);

	if (ctx.caretpos < ctx.chofs) then
		ctx.chofs = ctx.chofs - ctx.ulim;
		ctx.chofs = ctx.chofs < 1 and 1 or ctx.chofs;
		ctx.chofs = string.utf8lalign(ctx.msg, ctx.chofs);
	end

	ctx:update_caret();
end

local function text_input_cright(ctx)
	ctx.caretpos = string.utf8forward(ctx.msg, ctx.caretpos);

	if (ctx.chofs + ctx.ulim <= ctx.caretpos) then
		ctx.chofs = ctx.chofs + 1;
	end

	ctx:update_caret();
end

local function text_input_cdelete(ctx)
	ctx.msg = string.delete_at(ctx.msg, ctx.caretpos);
	ctx:update_caret();
end

local function text_input_cerase(ctx)
	if (ctx.caretpos < 1) then
		return;
	end

	ctx.caretpos = string.utf8back(ctx.msg, ctx.caretpos);
	if (ctx.caretpos <= ctx.chofs) then
		ctx.chofs = ctx.caretpos - ctx.ulim;
		ctx.chofs = ctx.chofs < 0 and 1 or ctx.chofs;
	end

	ctx.msg = string.delete_at(ctx.msg, ctx.caretpos);
	ctx:update_caret();
end

local function text_input_clear(ctx)
	ctx.caretpos = 1;
	ctx.msg = "";
	ctx:update_caret();
end

return function(ctx, iotbl, sym, opts)
	ctx = ctx == nil and {
		caretpos = 1,
		limit = -1,
		chofs = 1,
		ulim = 256,
		msg = "",

-- mainly internal use or for complementing render hooks via the redraw
		view_str = text_input_view,
		caret_str = text_input_caret_str,
		set_str = text_input_set,
		update_caret = text_input_caretalign,
		caret_home = text_input_chome,
		caret_end = text_input_cend,
		caret_left = text_input_cleft,
		caret_right = text_input_cright,
		caret_set = text_input_cset,
		erase = text_input_cerase,
		delete = text_input_cdel,
		clear = text_input_clear,

		undo = text_input_undo,
		input = text_input_table,
	} or ctx;

	local bindings = {
		k_left = "LEFT",
		k_right = "RIGHT",
		k_home = "HOME",
		k_end = "END",
		k_delete = "DELETE",
		k_erase = "BACKSPACE"
	};

	local flut = {
		k_left = text_input_cleft,
		k_right = text_input_cright,
		k_home = text_input_chome,
		k_end = text_input_cend,
		k_delete = text_input_cdelete,
		k_erase = text_input_cerase
	};

-- overlay any provided keybindings
	if (opts.bindings) then
		for k,v in pairs(opts.bindings) do
			if bindings[k] then
				bindings[k] = v;
			end
		end
	end

-- and build the real lut
	ctx.bindings = {};
	for k,v in pairs(bindings) do
		ctx.bindings[v] = flut[k];
	end

	ctx:input(iotbl, sym);
	return ctx;
end
