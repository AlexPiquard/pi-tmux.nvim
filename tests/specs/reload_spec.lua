local Helpers = require("spec_helpers")

local function setup_reload(options)
	options = options or {}
	local config = require("pi-tmux.config")
	config.setup({
		reload = vim.tbl_deep_extend("force", {
			auto_reload = true,
			reload_debounce_ms = 20,
			reload_on_conflict = "merge",
		}, options),
	})

	local Reload = require("pi-tmux.reload")
	Reload.setup()
	return Reload
end

local function edit_line(buf, line, text)
	vim.api.nvim_buf_set_lines(buf, line - 1, line, false, { text })
end

describe("reload", function()
	local notify

	before_each(Helpers.reset)

	before_each(function()
		notify = Helpers.capture_notify()
	end)

	after_each(function()
		notify.restore()
	end)

	it("reloads an unmodified buffer when pi changes the file", function()
		local file = Helpers.temp_file({ "one", "two" })
		setup_reload()

		Helpers.writefile(file.path, { "one", "changed" })

		assert(Helpers.wait_until(function()
			return vim.deep_equal(Helpers.lines(file.buf), { "one", "changed" })
		end))
	end)

	it("keeps an unsaved buffer and warns in notify mode", function()
		local file = Helpers.temp_file({ "one", "two" })
		setup_reload({ reload_on_conflict = "notify" })
		edit_line(file.buf, 1, "local-one")

		Helpers.writefile(file.path, { "remote-one", "two" })

		assert(Helpers.wait_until(function()
			return Helpers.has_notify(notify, "changed on disk")
		end))
		assert(vim.deep_equal(Helpers.lines(file.buf), { "local-one", "two" }))
	end)

	it("reloads an unsaved buffer in force mode", function()
		local file = Helpers.temp_file({ "one", "two" })
		setup_reload({ reload_on_conflict = "force" })
		edit_line(file.buf, 1, "local-one")

		Helpers.writefile(file.path, { "remote-one", "two" })

		assert(Helpers.wait_until(function()
			return vim.deep_equal(Helpers.lines(file.buf), { "remote-one", "two" })
		end))
	end)

	it("merges an unsaved buffer in merge mode", function()
		local file = Helpers.temp_file({ "one", "two", "three" })
		setup_reload({ reload_on_conflict = "merge" })
		edit_line(file.buf, 2, "local-two")

		Helpers.writefile(file.path, { "one", "remote-two", "three" })

		assert(Helpers.wait_until(function()
			return Helpers.contains(Helpers.lines(file.buf), "<<<<<<< nvim (local)")
		end))
		assert(not Helpers.has_notify(notify, "Resolve"))
	end)

	it("stops reloading when auto_reload is disabled", function()
		local file = Helpers.temp_file({ "one", "two" })
		setup_reload()

		local config = require("pi-tmux.config")
		config.setup({ reload = { auto_reload = false, reload_debounce_ms = 20 } })
		require("pi-tmux.reload").setup()

		Helpers.writefile(file.path, { "one", "changed" })
		vim.wait(200)

		assert(vim.deep_equal(Helpers.lines(file.buf), { "one", "two" }))
		assert(not pcall(vim.api.nvim_get_autocmds, { group = "PiTmuxReload" }))
	end)

	it("stops watching a buffer after unwatch", function()
		local file = Helpers.temp_file({ "one", "two" })
		local Reload = setup_reload()
		Reload.unwatch(file.buf)

		Helpers.writefile(file.path, { "one", "changed" })
		vim.wait(200)

		assert(vim.deep_equal(Helpers.lines(file.buf), { "one", "two" }))
	end)

	it("warns when the watched file disappears", function()
		local file = Helpers.temp_file({ "one", "two" })
		setup_reload()

		vim.fn.delete(file.path)

		assert(Helpers.wait_until(function()
			return Helpers.has_notify(notify, "file disappeared")
		end))
		assert(vim.deep_equal(Helpers.lines(file.buf), { "one", "two" }))
	end)
end)
