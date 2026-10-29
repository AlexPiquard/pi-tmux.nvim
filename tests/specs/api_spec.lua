local Helpers = require("spec_helpers")

describe("public api", function()
	before_each(Helpers.reset)

	it("applies setup options", function()
		local PiTmux = require("pi-tmux")
		PiTmux.setup({ reload = { auto_reload = false, reload_on_conflict = "notify" } })

		local config = require("pi-tmux.config")
		assert(config.opts.reload.auto_reload == false)
		assert(config.opts.reload.reload_on_conflict == "notify")
	end)

	it("creates reload and merge augroups by default", function()
		local PiTmux = require("pi-tmux")
		PiTmux.setup()

		assert(pcall(vim.api.nvim_get_autocmds, { group = "PiTmuxReload" }))
		assert(pcall(vim.api.nvim_get_autocmds, { group = "PiTmuxMerge" }))
	end)

	it("delegates ask with merged prompt options", function()
		local PiTmux = require("pi-tmux")
		local captured = {}

		package.loaded["pi-tmux.prompt"] = {
			ask = function(...)
				captured = { ... }
			end,
		}

		PiTmux.ask("hello")
		assert(captured[1] == true)
		assert(captured[2] == "hello")
		assert(captured[3].prompt == "Ask Pi")

		PiTmux.ask("hello", { prompt = "Custom" })
		assert(captured[3].prompt == "Custom")
	end)

	it("delegates scroll counts", function()
		local PiTmux = require("pi-tmux")
		local calls = {}

		package.loaded["pi-tmux.scroll"] = {
			scroll_up = function(count)
				table.insert(calls, { "up", count })
			end,
			scroll_down = function(count)
				table.insert(calls, { "down", count })
			end,
		}

		PiTmux.scroll_up(3)
		PiTmux.scroll_down()

		assert(vim.deep_equal(calls[1], { "up", 3 }))
		assert(vim.deep_equal(calls[2], { "down", nil }))
	end)

	it("registers the PiTmuxAsk command", function()
		local state = { calls = 0, last = "unset" }

		package.loaded["pi-tmux"] = {
			ask = function(text)
				state.calls = state.calls + 1
				state.last = text
			end,
		}

		pcall(vim.api.nvim_del_user_command, "PiTmuxAsk")
		vim.cmd("runtime plugin/pi-tmux.lua")

		assert(vim.fn.exists(":PiTmuxAsk") == 2)

		vim.cmd("PiTmuxAsk hello world")
		assert(state.calls == 1)
		assert(state.last == "hello world")

		vim.cmd("PiTmuxAsk")
		assert(state.calls == 2)
		assert(state.last == nil)

		pcall(vim.api.nvim_del_user_command, "PiTmuxAsk")
	end)
end)
