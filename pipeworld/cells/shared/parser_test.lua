-- fake arcan utf8 support
--
function string.utf8forward(src, ofs)
	if (ofs <= string.len(src)) then
		ofs = ofs + 1;
	end

	return ofs;
end

local parse, types = require('parser')()

local expr = {
	"21",
	"a1",
	"a1()",
	'strrep("hi", 4)',
	"max(1,2,5,3,2)",
	"max(max(1,2),1,3)",
	"max(1, max(1, 2), 3) + 4 * 5 / 20",
	"a1+a1",
	'reverse("there")',
	'concat("hi", "there")',
	'concat("hi", reverse("there"))',
	'concat(concat("apples", "oranges"), concat("bananas", a1, "kiwis"))',
	'max(tonumber("1"), 2, a1)',
	"variadic()",
	"variadic(1,2)",
	"concat(a1.clipboard, a1)",
	"minarg(1)",
	"minarg(1,2)",
-- this one does not work atm. a1.clipboard + 4",
}

local err_expr = {
	"1+2=14", -- = is an invalid operator
	"max + 1", -- fcall without (
	"+-2", -- unbalanced ops
}

local function symlookup(name, dtype, sub)
	if name == "a1" then
		if sub and sub == "clipboard" then
			if dtype == types.STRING then
				return "(clipboard.str)", types.STRING
			elseif dtype == types.NUMBER or not dtype then
				return 123, types.NUMBER
			end
		elseif dtype == types.NUMBER then
			return 666, types.NUMBER
		elseif dtype == types.STRING then
			return "hithere", types.STRING
		else
			return "default", types.STRING
		end
	end
	return nil, types.NIL
end

local function calc_max(...)
	local arg = {...}
	local max = arg[1]

	for i=2,#arg do
		if arg[i] > max then
			max = arg[i]
		end
	end

	return max
end

local function variadic(...)
	local arg = {...}
	print("eval variadic", #arg)
	if not arg[1] then
		return function()
			print("empty")
		end, {types.VARARG}
	end

	return arg[1]
end

local function concat(...)
	local arg = {...}
	return table.concat(arg, "")
end

local function reverse(a)
	local b = {}
	for i=#a,1,-1 do
		table.insert(b, string.sub(a, i, i))
	end
	return table.concat(b, "")
end

local function tonum(instr)
	return tonumber(instr)
end

local function strrep(instr, times)
	return string.rep(instr, times)
end

local function minarg(n1, n2)
	if n2 then
		return n1 + n2
	else
		return n1
	end
end

local function flookup(name)
	if name == "max" then
		return calc_max, {types.NUMBER, types.NUMBER,types.VARARG}, 1
-- the 'anything goes' signature
	elseif name == "concat" then
		return concat, {types.STRING, types.STRING, types.VARARG}, 2
	elseif name == "reverse" then
		return reverse, {types.STRING, types.STRING}, 1
	elseif name == "variadic" then
		return variadic, {types.VARTYPE, types.VARTYPE, types.VARARG}, 1
	elseif name == "tonumber" then
		return tonum, {types.NUMBER, types.STRING}, 1
	elseif name == "strrep" then
		return strrep, {types.STRING, types.STRING, types.NUMBER}, 2
	elseif name == "minarg" then
		return minarg, {types.STRING, types.NUMBER, types.NUMBER}, 1
	else
		return nil, "unknown function"
	end
end

local function perror(err, ofs, msg)
	print(err, "at", ofs, msg)
end

local function runexpr(v)
	print("run: ", v)
	local res = parse(v, symlookup, flookup, perror)
	if type(res) ~= "function" then
		print("failed to parse:", i, v)
		return false
	else
		local act, kind, val = res()
		print(string.format("execution (%s):", v))
		if kind == types.NUMBER then
			print("=> number: ", val)
		elseif kind == types.STRING then
			print("=> string", val)
		else
			print("=> unhandled:", kind, act, val)
		end
		return true
	end
end

if arg[1] then
	runexpr(arg[1])
	return
end

for i,v in ipairs(expr) do
	runexpr(v)
end
