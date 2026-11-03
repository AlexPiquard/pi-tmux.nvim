---@class Merge
local M = {}

local Buffer = require("pi-tmux.buffer")

local uv = vim.uv or vim.loop

local MAX_LINES = 20000

---@type table<integer, string[]|false|nil>
local base = {}
local initialized = false

local function is_binary(path)
	local fd = uv.fs_open(path, "r", 438)
	if not fd then
		return false
	end
	local data = uv.fs_read(fd, 8192, 0)
	uv.fs_close(fd)
	return data ~= nil and data:find("\0", 1, true) ~= nil
end

local function read_file(path)
	if is_binary(path) then
		return nil
	end

	local ok, lines = pcall(vim.fn.readfile, path)
	if not ok or #lines > MAX_LINES then
		return nil
	end
	return lines
end

local function record_buffer(buf)
	if not Buffer.is_file_buffer(buf) then
		base[buf] = nil
		return
	end

	if is_binary(Buffer.get_path(buf)) then
		base[buf] = false
		return
	end

	local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
	base[buf] = #lines > MAX_LINES and false or lines
end

local function record_disk(buf)
	if not Buffer.is_file_buffer(buf) then
		base[buf] = nil
		return
	end
	base[buf] = read_file(Buffer.get_path(buf)) or false
end

local function forget(buf)
	base[buf] = nil
end

local function display(path)
	return vim.fn.fnamemodify(path, ":~:.")
end

---@param buf integer
---@return boolean handled
function M.merge(buf)
	local path = Buffer.get_path(buf)
	if not path then
		return false
	end

	local base_lines = base[buf]
	if not base_lines then
		vim.notify(
			string.format("Pi-tmux: no merge base for %s (binary, too large or unreadable); buffer kept", display(path)),
			vim.log.levels.WARN
		)
		return false
	end

	local local_lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
	local remote_lines = read_file(path)
	if not remote_lines then
		vim.notify(
			string.format("Pi-tmux: cannot read %s (binary or too large); buffer kept", display(path)),
			vim.log.levels.WARN
		)
		return false
	end

	if vim.deep_equal(local_lines, remote_lines) then
		base[buf] = remote_lines
		return true
	end

	if vim.fn.executable("git") ~= 1 then
		vim.notify("Pi-tmux: git not found; buffer kept", vim.log.levels.WARN)
		return false
	end

	local tmpdir = vim.fn.tempname()
	if vim.fn.mkdir(tmpdir, "p") == 0 then
		vim.notify("Pi-tmux: cannot create temporary directory; buffer kept", vim.log.levels.WARN)
		return false
	end

	local p_local = tmpdir .. "/local"
	local p_base = tmpdir .. "/base"
	local p_remote = tmpdir .. "/remote"

	local function cleanup()
		pcall(vim.fn.delete, tmpdir, "rf")
	end

	local wrote = pcall(vim.fn.writefile, local_lines, p_local)
		and pcall(vim.fn.writefile, base_lines, p_base)
		and pcall(vim.fn.writefile, remote_lines, p_remote)
	if not wrote then
		cleanup()
		vim.notify("Pi-tmux: cannot write temporary merge files; buffer kept", vim.log.levels.WARN)
		return false
	end

	local result = vim.system({
		"git",
		"merge-file",
		"-L",
		"nvim (local)",
		"-L",
		"base",
		"-L",
		"pi (disk)",
		p_local,
		p_base,
		p_remote,
	}, { text = true }):wait()

	local code = result.code
	if code == nil or code < 0 or code >= 128 then
		cleanup()
		local detail = result.stderr and vim.trim(result.stderr) or ""
		vim.notify("Pi-tmux: git merge-file failed" .. (detail ~= "" and (": " .. detail) or ""), vim.log.levels.WARN)
		return false
	end

	local ok, merged = pcall(vim.fn.readfile, p_local)
	cleanup()
	if not ok then
		vim.notify("Pi-tmux: cannot read merge result; buffer kept", vim.log.levels.WARN)
		return false
	end

	local views = Buffer.save_views(buf)

	-- Reload first so nvim records the new on-disk mtime and won't warn on the
	-- next write. The merged content is then applied on top.
	vim.api.nvim_buf_call(buf, function()
		vim.cmd("silent! edit!")
	end)
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, merged)

	Buffer.restore_views(views)

	base[buf] = remote_lines

	return true
end

function M.setup()
	if initialized then
		return
	end

	local group = vim.api.nvim_create_augroup("PiTmuxMerge", { clear = true })

	vim.api.nvim_create_autocmd("BufReadPost", {
		group = group,
		callback = function(args)
			record_buffer(args.buf)
		end,
	})

	vim.api.nvim_create_autocmd("BufWritePost", {
		group = group,
		callback = function(args)
			record_buffer(args.buf)
		end,
	})

	vim.api.nvim_create_autocmd({ "BufUnload", "BufWipeout" }, {
		group = group,
		callback = function(args)
			forget(args.buf)
		end,
	})

	initialized = true

	for _, buf in ipairs(vim.api.nvim_list_bufs()) do
		if Buffer.is_file_buffer(buf) then
			record_disk(buf)
		end
	end
end

function M.stop()
	pcall(vim.api.nvim_del_augroup_by_name, "PiTmuxMerge")
	base = {}
	initialized = false
end

return M
