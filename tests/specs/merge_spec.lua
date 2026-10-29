local Helpers = require("spec_helpers")

local function setup(lines)
	local file = Helpers.temp_file(lines)
	local Merge = require("pi-tmux.merge")
	Merge.setup()
	return Merge, file
end

local function edit_line(buf, line, text)
	vim.api.nvim_buf_set_lines(buf, line - 1, line, false, { text })
end

describe("merge", function()
	local notify

	before_each(Helpers.reset)

	before_each(function()
		notify = Helpers.capture_notify()
	end)

	after_each(function()
		notify.restore()
	end)

	it("merges non-overlapping pi changes into an unsaved buffer", function()
		local Merge, file = setup({ "one", "two", "three" })
		edit_line(file.buf, 1, "local-one")

		Helpers.writefile(file.path, { "one", "two", "remote-three" })
		assert(Merge.merge(file.buf) == true)

		assert(vim.deep_equal(Helpers.lines(file.buf), { "local-one", "two", "remote-three" }))
		assert(vim.bo[file.buf].modified == true)
		assert(#notify.notes == 0)
	end)

	it("writes conflict markers for overlapping changes", function()
		local Merge, file = setup({ "one", "two", "three" })
		edit_line(file.buf, 2, "local-two")

		Helpers.writefile(file.path, { "one", "remote-two", "three" })
		assert(Merge.merge(file.buf) == true)

		local lines = Helpers.lines(file.buf)
		assert(Helpers.contains(lines, "<<<<<<< nvim (local)"))
		assert(Helpers.contains(lines, "local-two"))
		assert(Helpers.contains(lines, "======="))
		assert(Helpers.contains(lines, "remote-two"))
		assert(Helpers.contains(lines, ">>>>>>> pi (disk)"))
		assert(#notify.notes == 0, "conflict notifications must stay silent")
	end)

	it("keeps accumulating pi writes after a conflict", function()
		local Merge, file = setup({ "A", "B", "C", "D", "E" })
		edit_line(file.buf, 2, "B_local")

		Helpers.writefile(file.path, { "A", "B_pi1", "C", "D", "E" })
		assert(Merge.merge(file.buf) == true)
		assert(Helpers.contains(Helpers.lines(file.buf), "<<<<<<< nvim (local)"))

		Helpers.writefile(file.path, { "A", "B_pi1", "C", "D", "E_pi2" })
		assert(Merge.merge(file.buf) == true)
		assert(Helpers.contains(Helpers.lines(file.buf), "E_pi2"))
		assert(Helpers.contains(Helpers.lines(file.buf), "<<<<<<< nvim (local)"))

		Helpers.writefile(file.path, { "A", "B_pi3", "C", "D", "E_pi2" })
		assert(Merge.merge(file.buf) == true)
		assert(Helpers.contains(Helpers.lines(file.buf), "B_pi3"))

		for _, note in ipairs(notify.notes) do
			assert(not note.msg:find("unresolved", 1, true))
			assert(not note.msg:find("Resolve", 1, true))
			assert(not note.msg:find("not merged", 1, true))
		end
	end)

	it("does nothing when the buffer already matches disk", function()
		local Merge, file = setup({ "one", "two" })

		assert(Merge.merge(file.buf) == true)
		assert(vim.deep_equal(Helpers.lines(file.buf), { "one", "two" }))
		assert(#notify.notes == 0)
	end)

	it("preserves the cursor position", function()
		local Merge, file = setup({ "one", "two", "three", "four" })
		edit_line(file.buf, 1, "local-one")
		vim.api.nvim_win_set_cursor(0, { 3, 0 })

		Helpers.writefile(file.path, { "one", "two", "three", "remote-four" })
		assert(Merge.merge(file.buf) == true)

		assert(vim.api.nvim_win_get_cursor(0)[1] == 3)
	end)

	it("refreshes the file mtime so the merged buffer can be saved", function()
		local Merge, file = setup({ "one", "two", "three" })
		edit_line(file.buf, 2, "local-two")
		Helpers.writefile(file.path, { "one", "remote-two", "three" })

		assert(Merge.merge(file.buf) == true)
		local ok = pcall(vim.cmd, "silent write")
		assert(ok, "write should not warn after a merge")
		assert(vim.deep_equal(Helpers.readfile(file.path), Helpers.lines(file.buf)))
	end)

	it("uses the saved buffer as the next merge base", function()
		local Merge, file = setup({ "A", "B", "C" })
		edit_line(file.buf, 2, "B_local")
		Helpers.writefile(file.path, { "A", "B_pi", "C" })
		assert(Merge.merge(file.buf) == true)

		vim.api.nvim_buf_set_lines(file.buf, 0, -1, false, { "A", "B_resolved", "C" })
		vim.cmd("silent write")

		Helpers.writefile(file.path, { "A", "B_resolved", "C_pi" })
		assert(Merge.merge(file.buf) == true)
		assert(vim.deep_equal(Helpers.lines(file.buf), { "A", "B_resolved", "C_pi" }))
		assert(not Helpers.contains(Helpers.lines(file.buf), "<<<<<<< nvim (local)"))
	end)

	it("refuses to merge without a valid base", function()
		local lines = {}
		for index = 1, 20001 do
			lines[index] = "line " .. index
		end
		local Merge, file = setup(lines)

		Helpers.writefile(file.path, { "changed" })
		assert(Merge.merge(file.buf) == false)
		assert(Helpers.has_notify(notify, "no merge base"))
	end)

	it("refuses to merge when the disk file cannot be read", function()
		local Merge, file = setup({ "one", "two" })
		edit_line(file.buf, 1, "local-one")
		vim.fn.delete(file.path)

		assert(Merge.merge(file.buf) == false)
		assert(Helpers.has_notify(notify, "cannot read"))
	end)

	it("refuses to merge when git is unavailable", function()
		local Merge, file = setup({ "one", "two" })
		edit_line(file.buf, 1, "local-one")
		Helpers.writefile(file.path, { "remote-one", "two" })

		local old_path = vim.env.PATH
		vim.env.PATH = Helpers.tempdir()
		local ok, result = pcall(Merge.merge, file.buf)
		vim.env.PATH = old_path

		assert(ok)
		assert(result == false)
		assert(Helpers.has_notify(notify, "git not found"))
	end)
end)
