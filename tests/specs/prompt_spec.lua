local Helpers = require("spec_helpers")

local function install(pane)
	local Pane = require("pi-tmux.pane")
	local state = {
		pane = pane,
		find_calls = 0,
		commands = {},
		sent = nil,
	}

	Pane.find_pi_pane = function()
		state.find_calls = state.find_calls + 1
		return state.pane
	end

	Pane.cmd = function(args)
		table.insert(state.commands, args)
		return ""
	end

	local Prompt = require("pi-tmux.prompt")
	return Prompt, state
end

describe("prompt", function()
	before_each(Helpers.reset)

	it("sends a prompt through the tmux buffer and validates it", function()
		local Prompt, state = install("%1")

		Prompt.send_to_pi("hello")

		assert(state.find_calls == 1)
		assert(#state.commands == 3)
		assert(vim.deep_equal(state.commands[1], { "tmux", "set-buffer", "--", "hello" }))
		assert(vim.deep_equal(state.commands[2], { "tmux", "paste-buffer", "-t", "%1" }))
		assert(vim.deep_equal(state.commands[3], { "tmux", "send-keys", "-t", "%1", "Enter" }))
	end)

	it("does nothing when no pi pane is found", function()
		local Prompt, state = install(nil)

		Prompt.send_to_pi("hello")

		assert(state.find_calls == 1)
		assert(#state.commands == 0)
	end)

	it("does not send an empty prompt", function()
		local Prompt, state = install("%1")

		Prompt.send_to_pi("")

		assert(state.find_calls == 1)
		assert(#state.commands == 0)
	end)

	it("prefixes the current line when asking with a selection", function()
		local file = Helpers.temp_file({ "first", "second", "third" })
		vim.api.nvim_win_set_cursor(0, { 2, 0 })

		local Prompt, state = install("%1")
		Prompt.send_to_pi = function(text)
			state.sent = text
		end

		Prompt.ask(true, "Explain", {})
		assert(state.sent:find(":L2", 1, true) ~= nil)
		assert(state.sent:find(vim.fs.basename(file.path), 1, true) ~= nil)
		assert(state.sent:find("Explain", 1, true) ~= nil)
	end)

	it("uses vim.ui.input when no prompt is provided", function()
		local old_input = vim.ui.input
		vim.ui.input = function(_, callback)
			callback("hello")
		end

		local Prompt, state = install("%1")
		Prompt.send_to_pi = function(text)
			state.sent = text
		end

		local ok, err = pcall(Prompt.ask, false, nil, { prompt = "Ask", snacks = { enabled = false } })
		vim.ui.input = old_input

		assert(ok, err)
		assert(state.sent == "hello")
	end)
end)
