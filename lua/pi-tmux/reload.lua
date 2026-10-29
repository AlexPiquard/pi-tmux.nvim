---@class PiTmux.Reload
local M = {}

local Merge = require("pi-tmux.merge")
local Buffer = require("pi-tmux.buffer")

local uv = vim.uv or vim.loop

---@class PiTmux.Reload.Opts
---@field auto_reload? boolean Automatically reload the buffer when pi modifies the file
---@field reload_debounce_ms? integer Debounce time in milliseconds between reloads
---@field reload_on_conflict? "merge"|"force"|"notify" What to do when there is a conflict between local buffer and pi's editions

---@class PiTmux.Reload.Watcher
---@field handle userdata
---@field dir string
---@field bufs table<integer, boolean>
---@field timer userdata?

---@type table<string, PiTmux.Reload.Watcher>
local watchers = {}
---@type table<integer, string>
local buf_dir = {}
---@type table<integer, { size: integer, sec: integer, nsec: integer }|false|nil>
local cache = {}
---@type table<integer, boolean>
local notified = {}
---@type table<string, boolean>
local failed = {}
local initialized = false

local function normalize(path)
	return uv.fs_realpath(path) or path
end

local function read_stat(path)
	local st = uv.fs_stat(path)
	if not st then
		return nil
	end

	local mtime = st.mtime
	return {
		size = st.size,
		sec = mtime.sec or mtime,
		nsec = mtime.nsec or 0,
	}
end

local function same_stat(a, b)
	if not a or not b then
		return false
	end
	return a.size == b.size and a.sec == b.sec and a.nsec == b.nsec
end

local function stop_watcher(dir)
	local state = watchers[dir]
	if not state then
		return
	end
	watchers[dir] = nil

	if state.timer then
		pcall(function()
			state.timer:stop()
		end)
	end
	pcall(function()
		state.handle:stop()
	end)
	pcall(function()
		state.handle:close()
	end)
end

---@param opts PiTmux.Reload.Opts
local function check_buf(buf, dir, opts)
	if not vim.api.nvim_buf_is_valid(buf) or not vim.api.nvim_buf_is_loaded(buf) then
		M.unwatch(buf)
		return
	end

	local path = vim.api.nvim_buf_get_name(buf)
	if path == "" or normalize(vim.fs.dirname(path)) ~= dir then
		M.unwatch(buf)
		M.watch(buf)
		return
	end

	local st = read_stat(path)
	if not st then
		if cache[buf] ~= false then
			cache[buf] = false
		end
		return
	end

	if same_stat(st, cache[buf]) then
		return
	end
	cache[buf] = st
	notified[buf] = nil

	if vim.bo[buf].modified then
		if opts.reload_on_conflict == "merge" then
			Merge.merge(buf)
			return
		end

		if opts.reload_on_conflict ~= "force" then
			if not notified[buf] then
				notified[buf] = true
				vim.notify(
					string.format(
						"Pi-tmux: %s changed on disk, buffer kept (unsaved changes). Use :edit! to reload.",
						vim.fn.fnamemodify(path, ":~:.")
					),
					vim.log.levels.WARN
				)
			end
			return
		end
	end

	Buffer.reload(buf)
	cache[buf] = read_stat(path) or st
end

---@param buf integer
function M.watch(buf)
	local opts = require("pi-tmux.config").opts.reload or {}

	if not opts.auto_reload or not Buffer.is_file_buffer(buf) then
		return
	end

	local path = vim.api.nvim_buf_get_name(buf)
	local raw_dir = vim.fs.dirname(path)
	if not raw_dir or raw_dir == "" then
		return
	end
	local dir = normalize(raw_dir)

	if buf_dir[buf] == dir and watchers[dir] then
		return
	end
	if buf_dir[buf] then
		M.unwatch(buf)
	end

	local state = watchers[dir]
	if not state then
		local handle = uv.new_fs_event()
		if not handle then
			return
		end

		local ok, err = handle:start(dir, {}, function(fs_err)
			if fs_err then
				return
			end

			vim.schedule(function()
				local watcher = watchers[dir]
				if not watcher then
					return
				end

				if watcher.timer then
					pcall(function()
						watcher.timer:stop()
					end)
				end

				watcher.timer = vim.defer_fn(function()
					watcher.timer = nil
					if watchers[dir] ~= watcher then
						return
					end
					for b in pairs(watcher.bufs) do
						check_buf(b, dir, opts)
					end
				end, opts.reload_debounce_ms)
			end)
		end)

		if not ok then
			pcall(function()
				handle:close()
			end)
			if not failed[dir] then
				failed[dir] = true
				vim.notify(string.format("Pi-tmux: cannot watch %s: %s", dir, tostring(err)), vim.log.levels.WARN)
			end
			return
		end

		failed[dir] = nil
		state = { handle = handle, dir = dir, bufs = {} }
		watchers[dir] = state
	end

	buf_dir[buf] = dir
	state.bufs[buf] = true
	cache[buf] = read_stat(path)
end

---@param buf integer
function M.unwatch(buf)
	local dir = buf_dir[buf]
	buf_dir[buf] = nil
	cache[buf] = nil
	notified[buf] = nil

	if not dir then
		return
	end

	local state = watchers[dir]
	if not state then
		return
	end

	state.bufs[buf] = nil
	if next(state.bufs) == nil then
		stop_watcher(dir)
	end
end

function M.stop()
	for _, buf in ipairs(vim.tbl_keys(buf_dir)) do
		M.unwatch(buf)
	end
	for dir in pairs(watchers) do
		stop_watcher(dir)
	end
end

function M.setup()
	local opts = require("pi-tmux.config").opts.reload or {}

	if not opts.auto_reload then
		M.stop()
		Merge.stop()
		if initialized then
			pcall(vim.api.nvim_del_augroup_by_name, "PiTmuxReload")
			initialized = false
		end
		return
	end

	if opts.reload_on_conflict == "merge" then
		Merge.setup()
	else
		Merge.stop()
	end

	if not initialized then
		local group = vim.api.nvim_create_augroup("PiTmuxReload", { clear = true })

		vim.api.nvim_create_autocmd({ "BufReadPost", "BufEnter" }, {
			group = group,
			callback = function(args)
				M.watch(args.buf)
			end,
		})

		vim.api.nvim_create_autocmd("BufWritePost", {
			group = group,
			callback = function(args)
				local buf = args.buf
				if not opts.auto_reload then
					return
				end
				if buf_dir[buf] then
					cache[buf] = read_stat(vim.api.nvim_buf_get_name(buf))
					notified[buf] = nil
				else
					M.watch(buf)
				end
			end,
		})

		vim.api.nvim_create_autocmd({ "BufUnload", "BufWipeout" }, {
			group = group,
			callback = function(args)
				M.unwatch(args.buf)
			end,
		})

		initialized = true
	end

	for _, buf in ipairs(vim.api.nvim_list_bufs()) do
		if vim.api.nvim_buf_is_loaded(buf) then
			M.watch(buf)
		end
	end
end

return M
