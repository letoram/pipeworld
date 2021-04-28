local function format(str)
	local res = os.date(str and str or "%Y-%m-%d %T")
	if not res then
		eval_scope.cell:set_error("invalid datetime format string")
		return
	end

	return res
end

return function(types)
	return {
		handler = format,
		args = {types.STRING, types.STRING},
		argc = 0,
		names = {
			format = 1
		},
		help = "Return the system date-time with an optional format string (strftime)",
		type_helper = {
			{
				"%Y-%m-%d - year month day",
				"%H-%M:%S - hour minute second",
			}
		}
	}
end
