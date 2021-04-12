local apply_fsrv_cell = system_load("cells/shared/fsrv.lua")()

-- this cell type is special, it should not really be invoked manually
-- but as a part of a factory chain from crash recovery like behavior
return
function(row, cfg, vid, segkind)
	if not valid_vid(vid, TYPE_FRAMESERVER) then
		warning("adopt_cell() - called without valid frameserver")
		return
	end

	local res = pipeworld_cell_template("adopt", row, cfg)

	apply_fsrv_cell(res, vid)
	return res
end
