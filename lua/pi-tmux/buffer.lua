local M = {}

---@param buf integer
---@return string|nil
function M.get_path(buf)
	local name = vim.api.nvim_buf_get_name(buf)
	if name == "" or name:match("^%a[%w+.-]*://") then
		return nil
	end
	return name
end

---@param buf integer
---@return boolean
function M.is_file_buffer(buf)
	if not vim.api.nvim_buf_is_valid(buf) or not vim.api.nvim_buf_is_loaded(buf) then
		return false
	end
	if vim.bo[buf].buftype ~= "" then
		return false
	end
	return M.get_path(buf) ~= nil
end

---@param buf integer
---@return table<integer, table>
function M.save_views(buf)
	local views = {}
	for _, win in ipairs(vim.fn.win_findbuf(buf)) do
		views[win] = vim.api.nvim_win_call(win, function()
			return vim.fn.winsaveview()
		end)
	end
	return views
end

---@param views table<integer, table>
function M.restore_views(views)
	for win, view in pairs(views) do
		if vim.api.nvim_win_is_valid(win) then
			vim.api.nvim_win_call(win, function()
				vim.fn.winrestview(view)
			end)
		end
	end
end

---@param buf integer
function M.reload(buf)
	local views = M.save_views(buf)
	vim.api.nvim_buf_call(buf, function()
		vim.cmd("silent! edit!")
	end)
	M.restore_views(views)
end

return M
