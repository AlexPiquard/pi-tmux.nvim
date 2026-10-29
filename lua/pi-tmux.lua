---@class PiTmux
local M = {}

---@param opts? PiTmux.Opts
M.setup = function(opts)
	require("pi-tmux.config").setup(opts)
	require("pi-tmux.reload").setup()
end

---@param prompt? string The prompt opts overriding the default ones for this call 
---@param opts? PiTmux.Prompt.Opts The opts overriding the default one for this call
function M.ask(prompt, opts)
	opts = require("pi-tmux.config").get("ask", opts)
	require("pi-tmux.prompt").ask(true, prompt, opts)
end

---@param count? integer
function M.scroll_down(count)
	require("pi-tmux.scroll").scroll_down(count)
end

---@param count? integer
function M.scroll_up(count)
	require("pi-tmux.scroll").scroll_up(count)
end

return M
