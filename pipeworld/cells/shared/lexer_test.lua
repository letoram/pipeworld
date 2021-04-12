local tokenize, types = require('lexer')()

-- fake arcan utf8 support
--
function string.utf8forward(src, ofs)
	if (ofs <= string.len(src)) then
		ofs = ofs + 1;
	end

	return ofs;
end

local type_str = {}
type_str[types.STRING] = "string"
type_str[types.NUMBER] = "number"
type_str[types.NIL] = "null"
type_str[types.VARTYPE] = "dynamic"
type_str[types.BOOLEAN] = "boolean"
type_str[types.OPERATOR] = "operator"
type_str[types.VARARG] = "variadic"
type_str[types.IMAGE] = "image"
type_str[types.AUDIO] = "audio"
type_str[types.VIDEO] = "video"
type_str[types.SYMBOL] = "symbol"
type_str[types.FCALL] = "function-call"
type_str[types.CELL] = "cell"

local function dump_tokens(printer, list)
	local find = function(val)
		for k,v in pairs(types) do
			if v == val then
				return k
			end
		end
	end

	for _,v in ipairs(list) do
		if v[1] == types.OPERATOR then
			printer("operator", find(v[2]))
		else
			printer(find(v[1]), v[2])
		end
	end
end

local valid = {
	"+- */%()", -- operators
	"123.456 123 -321 .123 0xff 0b0111", -- numbers
	"+-2", -- op+lit
	"test.test", -- namespaced symbol
	"\"some\\\"string\\\" yes why \"   \"not plain\"", -- literals
	"sym1 $-1 $+2 $1 $-1.test", -- symbols and relative symbols
	"a = b+\"hi\" there(1,-,(,),*) pim\"pmob\\\\ile\"", -- complex
}

local fail = {
-- errors
	"+- ! -+", -- invalid operator
	"123.456.789", -- invalid number
	"\"unterminated" -- unterminated string
}

for i,v in ipairs(valid) do
	print(string.format("valid input (%d): %s", i , v))

	local tok, err, pos = tokenize(v)
	if err then
		print("valid input failed:", err, "at ", pos)
	else
		print("pass")
	end

	dump_tokens(print, tok)
	print("----------")
end

for i,v in ipairs(fail) do
	print(string.format("invalid input (%d): %s", i , v))
	local tok, err, pos = tokenize(v)
	if not err then
		print("fail: tokenize ok on invalid input")
	else
		print("pass")
	end
	print("----------")
end
