local Pane = require("pi-tmux.pane")

local M = {}

local function pane_center(pane)
	local out = Pane.cmd({ "tmux", "display-message", "-p", "-t", pane, "#{pane_width} #{pane_height}" })
	local width, height
	if out then
		width, height = out:match("(%d+)%s+(%d+)")
	end
	if not width or not height then
		return 1, 1
	end

	return math.max(1, math.floor(tonumber(width) / 2)), math.max(1, math.floor(tonumber(height) / 2))
end

local function scroll(button, count)
	---@cast count integer
	count = math.max(1, math.floor(count or 1))

	local pane = Pane.get_cached_pi_pane()
	if not pane then
		return
	end

	local x, y = pane_center(pane)
	local event = string.format("\27[<%d;%d;%dM", button, x, y)
	if not Pane.cmd({ "tmux", "send-keys", "-t", pane, "-l", string.rep(event, count) }) then
		Pane.invalidate()
	end
end

---@param count? integer
function M.scroll_down(count)
	scroll(65, count)
end

---@param count? integer
function M.scroll_up(count)
	scroll(64, count)
end

return M
