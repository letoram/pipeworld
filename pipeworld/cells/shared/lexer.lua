--
-- returns parse-function, token-table, precendence table
--
-- parse-function takes a string and returns a table of tokens
-- where each token is a tuple with [1] being a token from the
-- token-table, [2] any associated value and [3] the message
-- byte offset of the token start.
--
local tokens = {
-- basic data types
	SYMBOL   = 1,
	FCALL    = 2,
	OPERATOR = 3,
	STRING   = 4,
	NUMBER   = 5,
	BOOLEAN  = 6,
	IMAGE    = 7,
	AUDIO    = 8,
	VIDEO    = 9,  -- (dynamic image and all external frameservers)
	NIL      = 10, -- for F(,,) argument passing
	CELL     = 11, -- reference to a cell
	FACTORY  = 12, -- cell 'producer' (arguments are type + type arguments)
	VARTYPE  = 13, -- dynamically typed, function validates on call
	VARARG   = 14, -- a variable number of arguments of the previous type,
	               -- combine with VARTYPE for completely dynamic

-- permitted operators, match to operator table below
	OP_ADD   = 20,
	OP_SUB   = 21,
	OP_DIV   = 22,
	OP_MUL   = 23,
	OP_LPAR  = 24,
	OP_RPAR  = 25,
	OP_MOD   = 26,
	OP_ASS   = 27,
	OP_SEP   = 28,

-- return result states
	ERROR    = 40,
	STATIC   = 41,
	DYNAMIC  = 42,

-- special actions
	FN_ALIAS = 50, -- commit entry to alias table,
	EXPREND  = 51
}

local precendence = {
	[tokens.OP_MUL] = 8,
	[tokens.OP_DIV] = 8,
	[tokens.OP_MOD] = 8,

	[tokens.OP_ADD] = 2,
	[tokens.OP_SUB] = 2,
}

local operators = {
['+'] = tokens.OP_ADD,
['-'] = tokens.OP_SUB,
['*'] = tokens.OP_MUL,
['/'] = tokens.OP_DIV,
['('] = tokens.OP_LPAR,
[')'] = tokens.OP_RPAR,
['%'] = tokens.OP_MOD,
['='] = tokens.OP_ASS,
[','] = tokens.OP_SEP
}

local constant_ascii_a = string.byte("a")
local constant_ascii_f = string.byte("f")

local function isnum(ch)
	return (string.byte(ch) >= 0x30 and string.byte(ch) <= 0x39)
end

local function add_token(state, dst, kind, value, position, data)
-- lex- level optimizations can go here
	table.insert(dst, {kind, value, position, last_position, data})
	state.last_position = position
end

local function issymch(state, ch, ofs)
-- special character '_', num allowed unless first pos
	if isnum(ch) or ch == "_" or ch == "." or ch == ":" then
		return ofs > 0
	end

-- special prefixes allowed on first pos
	if ofs == 0 then
		if ch == "$" then
			return true
		end
	end

-- numbers and +- are allowed on pos2 if we have $ at the beginning
	local byte = string.byte(ch)
	if state.buffer == "$" then
		if ch == "-" or ch == "+" then
			return true
		end
	end

	return
		(byte >= 0x41 and byte <= 0x5a) or (byte >= 0x61 and byte <= 0x7a)
end

local lex_default, lex_num, lex_symbol, lex_str, lex_err
lex_default =
function(ch, tok, state, ofs)
-- eof reached
	if not ch or #ch == 0 or ch == "\0" then
		if #state.buffer > 0 then
			state.error = "(def) unexpected end, buffer: " .. state.buffer
			state.error_ofs = ofs
			return lex_error
		end
		return lex_default
	end

-- alpha? move to symbol state
	if issymch(state, ch, 0) then
		state.buffer = ch
		return lex_symbol

-- number constant? process and switch state
	elseif isnum(ch) then
		state.number_fract = false
		state.number_hex = false
		state.number_bin = false
		state.base = 10
		return lex_num(ch, tok, state, ofs)

-- fractional number constant, set number format and continue
	elseif ch == "." then
		state.number_fract = true
		state.number_hex = false
		state.number_bin = false
		state.base = 10
		return lex_num

	elseif ch == "\"" then
		state.buffer = ""
		state.lex_str_ofs = ofs
		return lex_str

	elseif ch == " " or ch == "\t" or ch == "\n" then
-- whitespace ? ignore
		return lex_default

	elseif operators[ch] ~= nil then
-- if we have '-num' ' -num' or 'operator-num' then set state.negate
		if ch == "-" then
			if not state.last_ch or
				state.last_ch == " " or
				(#tok > 0 and tok[#tok][1] == tokens.OPERATOR) then
				state.negate = true
				state.number_fract = false
				state.number_hex = false
				state.number_bin = false
				state.base = 10
				return lex_num
			end
		end
		add_token(state, tok, tokens.OPERATOR, operators[ch], ofs)
		return lex_default
	else
-- switch to error state, won't return
		state.error = "(def) invalid token: " .. ch
		state.error_ofs = ofs
		return lex_error
	end
end

lex_error =
function()
	return lex_error
end

lex_num =
function(ch, tok, state, ofs)
	if isnum(ch) then
		if state.number_bin and (ch ~= "0" and ch ~= "1") then
			state.error = "(num) invalid binary constant (" .. ch .. ") != [01]"
			state.error_ofs = ofs
			return lex_error
		end
		state.buffer = state.buffer .. ch
		return lex_num
	end

	if ch == "." then
		if state.number_fract then
			state.error = "(num) multiple radix points in number"
			state.error_ofs = ofs
			return lex_error

		else
-- note, we need to check what the locale radix-point is or tonumber
-- will screw us up on some locales that use , for radix
			state.number_fract = true
			state.buffer = state.buffer .. ch
			return lex_num
		end

	elseif ch == "b" and not state.number_hex then
		if state.number_bin or
			#state.buffer ~= 1 or
			string.sub(state.buffer, 1, 1) ~= "0" then
			state.error = "(num) invalid binary constant (0b[01]n expected)"
			state.error_ofs = ofs
			return lex_error
		else
			state.number_bin = true
			state.base = 2
			return lex_num
		end
	elseif ch == "x" then
		if state.number_hex or
			#state.buffer ~= 1 or
			string.sub(state.buffer, 1, 1) ~= "0" then
			state.error = "(num) invalid hex constant (0x[0-9a-f]n expected)"
			state.error_ofs = ofs
			return lex_error
		else
			state.number_hex = true
			state.base = 16
			return lex_num
		end
	elseif string.byte(ch) == 0 then
	else
		if state.number_hex then
			local dch = string.byte(string.lower(ch))

			if dch >= constant_ascii_a and dch <= constant_ascii_f then
				state.buffer = state.buffer .. ch
				return lex_num
			end
-- other characters terminate
		end
	end

	local num = tonumber(state.buffer, state.base)
	if not num then
-- case: def(-) -> num(-) then other operator or non-numeric literal/symbol
-- need to revert back to default and treat as operator
		if state.negate and #state.buffer == 0 then
			state.negate = false
			add_token(state, tok, tokens.OPERATOR, tokens.OP_SUB, ofs)
			return lex_default(ch, tok, state, ofs)
		end

		state.error = string.format("(num) invalid number (%s)b%d", state.buffer, state.base)
		state.error_ofs = ofs
		return lex_error
	end

	if state.negate then
		num = num * -1
		state.negate = false
	end
	add_token(state, tok, tokens.NUMBER, num, ofs)
	state.buffer = ""
	return lex_default(ch, tok, state, ofs)
end

lex_symbol =
function(ch, tok, state, ofs)
-- sym+( => treat sym as function
	if ch == "(" and #state.buffer > 0 then
		add_token(state, tok, tokens.FCALL, string.lower(state.buffer), ofs, state.got_addr)
		state.buffer = ""
		state.got_addr = nil
		return lex_default

	elseif issymch(state, ch, #state.buffer) then
-- track namespace separately
		if ch == "." then
			if state.got_addr then
				state.error = '(str) symbol namespace selection with . only allowed once per symbol'
				state.error_ofs = state.lex_str_ofs
				return lex_error
			end

			state.got_addr = string.lower(state.buffer)
			state.buffer = ""

			return lex_symbol
		end

-- or buffer and continue
		state.buffer = state.buffer .. ch
		return lex_symbol
	else

-- we are done
		if state.got_addr then
			add_token(state, tok, tokens.SYMBOL, state.got_addr, ofs, string.lower(state.buffer))
		else
			local lc = string.lower(state.buffer)
			if lc == "true" then
				add_token(state, tok, tokens.BOOLEAN, true, ofs)
			elseif lc == "false" then
				add_token(state, tok, tokens.BOOLEAN, false, ofs)
			else
				add_token(state, tok, tokens.SYMBOL, lc, ofs)
			end
		end

		state.buffer = ""
		state.got_addr = nil
		return lex_default(ch, tok, state, ofs)
	end
end

lex_str =
function(ch, tok, state, ofs)
	if not ch or #ch == 0 or ch == "\0" then
		state.error = '"(str) unterminated string at end'
		state.error_ofs = state.lex_str_ofs
		return lex_error
	end

	if state.in_escape then
		state.buffer = state.buffer .. ch
		state.in_escape = nil

	elseif ch == "\"" then
		add_token(state, tok, tokens.STRING, state.buffer, ofs)
		state.buffer = ""
		return lex_default

	elseif ch == "\\" then
		state.in_escape = true
	else
		state.buffer = state.buffer .. ch
	end

	return lex_str
end

-- work around 'require' not allowing multiple returns
return function()

return function(msg)
	local ofs = 1
	local nofs = ofs
	local len = #msg

	local tokens = {}
	local state = { buffer = ""}
	local scope = lex_default

	local scopestr =
	function(scope)
		if scope == lex_default then
			return "default"
		elseif scope == lex_str then
			return "string"
		elseif scope == lex_num then
			return "number"
		elseif scope == lex_symbol then
			return "symbol"
		elseif scope == lex_err then
			return "error"
		else
			return "unknown"
		end
	end

	repeat
		nofs = string.utf8forward(msg, ofs)
		local ch = string.sub(msg, ofs, nofs-1)

		scope = scope(ch, tokens, state, ofs)
		ofs = nofs
		state.last_ch = ch

	until nofs > len or state.error ~= nil
	scope("\0", tokens, state, ofs)

	return tokens, state.error, state.error_ofs
end, tokens, precendence

end
