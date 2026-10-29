local M = {}

local dirs = {}
local buffers = {}

function M.tempdir()
	local dir = vim.fn.tempname()
	assert(vim.fn.mkdir(dir, "p") == 1, "cannot create temp directory")
	table.insert(dirs, dir)
	return dir
end

function M.writefile(path, lines)
	assert(vim.fn.writefile(lines, path) == 0, "cannot write " .. path)
end

function M.readfile(path)
	return vim.fn.readfile(path)
end

function M.temp_file(lines, name)
	local dir = M.tempdir()
	local path = dir .. "/" .. (name or "file.txt")
	M.writefile(path, lines)
	vim.cmd("edit " .. vim.fn.fnameescape(path))
	local buf = vim.api.nvim_get_current_buf()
	table.insert(buffers, buf)
	return { dir = dir, path = path, buf = buf }
end

function M.lines(buf)
	return vim.api.nvim_buf_get_lines(buf or 0, 0, -1, false)
end

function M.contains(list, value)
	for _, item in ipairs(list) do
		if item == value then
			return true
		end
	end
	return false
end

function M.find(list, value)
	for index, item in ipairs(list) do
		if item == value then
			return index
		end
	end
	return nil
end

function M.capture_notify()
	local original = vim.notify
	local notes = {}
	vim.notify = function(msg, level)
		table.insert(notes, { msg = msg, level = level })
	end
	return {
		notes = notes,
		restore = function()
			vim.notify = original
		end,
	}
end

function M.has_notify(capture, needle)
	for _, note in ipairs(capture.notes) do
		if note.msg:find(needle, 1, true) then
			return true
		end
	end
	return false
end

function M.wait_until(predicate, timeout)
	return vim.wait(timeout or 3000, predicate, 20)
end

function M.cleanup()
	for index = #buffers, 1, -1 do
		local buf = buffers[index]
		if vim.api.nvim_buf_is_valid(buf) then
			pcall(vim.api.nvim_buf_delete, buf, { force = true })
		end
	end
	buffers = {}

	for _, dir in ipairs(dirs) do
		pcall(vim.fn.delete, dir, "rf")
	end
	dirs = {}
end

function M.reset()
	local reload = package.loaded["pi-tmux.reload"]
	if type(reload) == "table" and reload.stop then
		pcall(reload.stop)
	end

	local merge = package.loaded["pi-tmux.merge"]
	if type(merge) == "table" and merge.stop then
		pcall(merge.stop)
	end

	M.cleanup()

	local names = {}
	for name in pairs(package.loaded) do
		if name == "pi-tmux" or name:match("^pi%-tmux%.") then
			table.insert(names, name)
		end
	end
	for _, name in ipairs(names) do
		package.loaded[name] = nil
	end

	pcall(vim.api.nvim_del_augroup_by_name, "PiTmuxReload")
	pcall(vim.api.nvim_del_augroup_by_name, "PiTmuxMerge")
	pcall(vim.api.nvim_del_user_command, "PiTmuxAsk")
end

return M
