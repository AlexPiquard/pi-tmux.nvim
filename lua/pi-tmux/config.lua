local M = {}

---@class PiTmux.Opts
---@field ask? PiTmux.Prompt.Opts Prompt opts
---@field reload? PiTmux.Reload.Opts Auto-reload opts

---@type PiTmux.Opts
M.defaults = {
	ask = {
		prompt = "Ask Pi",
		snacks = {
			enabled = true,
			icon = "󰚩 ",
			win = {
				title_pos = "left",
				relative = "cursor",
				row = -3, -- Row above the cursor
				col = 0, -- Align with the cursor
				keys = {
					i_cr = {
						desc = "submit",
					},
				},
			},
		},
	},
	reload = {
		auto_reload = true,
		reload_debounce_ms = 150,
		reload_on_conflict = "merge",
	},
}

---@type PiTmux.Opts
M.opts = M.defaults

---@generic O
---@param ... O|string|nil
---@return O
function M.get(...)
	local ret = {}
	local default = false
	for _, item in ipairs({ ... }) do
		if type(item) == "table" then
			ret = vim.tbl_deep_extend("force", ret, item)
		elseif type(item) == "string" then
			if M.opts and M.opts[item] then
				ret = vim.tbl_deep_extend("force", ret, M.defaults[item])
				default = true
			end
		end
	end

	if not default then
		ret = vim.tbl_deep_extend("force", M.defaults, ret)
	end

	return ret
end

---@param opts? PiTmux.Opts
function M.setup(opts)
	M.opts = M.get(opts)
end

return M
