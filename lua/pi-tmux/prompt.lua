local Pane = require("pi-tmux.pane")

---@class Prompt
local M = {}

---@class PiTmux.Prompt.Opts
---@field prompt? string Text of the prompt input
---@field default? vim.ui.input.Opts Options for default vim.ui.input
---@field snacks? snacks.input.Opts Options for [snacks.input](https://github.com/folke/snacks.nvim/blob/main/docs/input.md).

local function get_current_selection()
	local selected
	local file_path = vim.fn.expand("%:.")
	local bufnr = vim.api.nvim_get_current_buf()
	local mode = vim.fn.visualmode()

	local start_pos, end_pos
	if mode == "" then
		start_pos = vim.fn.getcurpos()
		end_pos = start_pos
	else
		start_pos = vim.fn.getpos("'<")
		end_pos = vim.fn.getpos("'>")
	end

	local end_line = vim.api.nvim_buf_get_lines(bufnr, end_pos[2] - 1, end_pos[2], false)[1] or ""
	local end_col = math.max(1, math.min(end_pos[3], #end_line))

	selected = string.format("%s:L%d", file_path, start_pos[2])
	if start_pos[2] ~= end_pos[2] then
		selected = selected .. string.format(":C%d-L%d:C%d", start_pos[3], end_pos[2], end_col)
	end

	return selected
end

---@param on_confirm fun(input?: string)
---@param opts PiTmux.Prompt.Opts The opts to use
local function input(on_confirm, opts)
	local input_opts = vim.deepcopy(opts)
	input_opts.snacks = nil
	input_opts.default = nil
	local snacks_ok, snacks = pcall(require, "snacks")
	if snacks_ok and snacks.config.get("input", {}).enabled and opts.snacks.enabled then
		input_opts = vim.tbl_deep_extend("keep", input_opts, opts.snacks)
	elseif opts.default and type(opts.default) == "table" then
		input_opts = vim.tbl_deep_extend("keep", input_opts, opts.default)
	end

	vim.ui.input(input_opts, function(msg)
		if not msg or msg == "" then
			return
		end
		on_confirm(msg)
	end)
end

--- Send a prompt text to the tmux pane where Pi is running
--- @param prompt string: The text to send to Pi
function M.send_to_pi(prompt)
	local pane_target = Pane.find_pi_pane()

	if not pane_target then
		return
	end

	if not prompt or prompt == "" then
		return
	end

	-- Copy the prompt to the tmux registry/buffer to avoid spec character issues
	Pane.cmd({ "tmux", "set-buffer", "--", prompt })

	-- Paste the contents of the tmux buffer into the Pi pane
	Pane.cmd({ "tmux", "paste-buffer", "-t", pane_target })

	-- Send the 'Enter' key to validate the prompt
	Pane.cmd({ "tmux", "send-keys", "-t", pane_target, "Enter" })
end

--- Sends the currently selected code in visual mode to Pi
---@param with_selection boolean Whether to include the current visual selection in the message
---@param prompt? string The prompt possibly already defined, otherwise it is requested via input
---@param opts PiTmux.Prompt.Opts The opts to use
function M.ask(with_selection, prompt, opts)
	local selected
	if with_selection then
		selected = get_current_selection()
	end

	local send = function(msg)
		local full_prompt
		if selected and selected ~= "" then
			full_prompt = selected .. " "
		end
		full_prompt = (full_prompt or "") .. (msg or "")
		M.send_to_pi(full_prompt)
	end

	if prompt and prompt ~= "" then
		send(prompt)
	else
		input(send, opts)
	end
end

return M
