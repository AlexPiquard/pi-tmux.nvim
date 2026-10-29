local M = {}

---@type { pane: string, window: string }|nil
local cached

function M.cmd(args)
	local out = vim.fn.system(args)
	if vim.v.shell_error ~= 0 then
		return nil
	end
	return out
end

local function get_current_tmux_window()
	local out = M.cmd({ "tmux", "display-message", "-p", "#{window_id}" })
	if not out then
		return nil
	end
	out = vim.trim(out)
	return out ~= "" and out or nil
end

local function valid_cached_pane()
	if not cached then
		return nil
	end

	local out =
		M.cmd({ "tmux", "display-message", "-p", "-t", cached.pane, "#{pane_id} #{window_id} #{pane_current_command}" })
	if not out then
		return nil
	end

	local pane_id, window_id, cmd = vim.trim(out):match("^(%S+)%s+(%S+)%s+(%S+)")
	if pane_id == cached.pane and cmd and cmd:match("pi") then
		cached.window = window_id
		return cached.pane
	end

	return nil
end

local function search_pi_pane(current_window_id)
	local out = M.cmd({ "tmux", "list-panes", "-a", "-F", "#{window_id} #{pane_id} #{pane_current_command}" })
	if not out then
		return nil
	end

	local fallback_pane, fallback_window
	for line in out:gmatch("[^\r\n]+") do
		local pane_window_id, pane_id, cmd = line:match("^(%S+)%s+(%S+)%s+(%S+)")
		if cmd and cmd:match("pi") then
			if pane_window_id == current_window_id then
				cached = { pane = pane_id, window = pane_window_id }
				return pane_id
			end

			if not fallback_pane then
				fallback_pane = pane_id
				fallback_window = pane_window_id
			end
		end
	end

	if fallback_pane then
		cached = { pane = fallback_pane, window = fallback_window }
		return fallback_pane
	end

	vim.notify("Pi-tmux: Couldn't find a Tmux pane running 'pi'!", vim.log.levels.WARN)
	return nil
end

function M.find_pi_pane()
	local pane_id = valid_cached_pane()
	if pane_id then
		return pane_id
	end

	cached = nil

	local current_window_id = get_current_tmux_window()
	if not current_window_id then
		return nil
	end

	return search_pi_pane(current_window_id)
end

function M.get_cached_pi_pane()
	if cached then
		return cached.pane
	end

	return M.find_pi_pane()
end

function M.invalidate()
	cached = nil
end

function M.pane_in_mode(pane)
	local out = M.cmd({ "tmux", "display-message", "-p", "-t", pane, "#{pane_in_mode}" })
	return out ~= nil and vim.trim(out) == "1"
end

return M
