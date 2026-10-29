local Helpers = require("spec_helpers")

local function install(options)
	options = options or {}

	local Pane = require("pi-tmux.pane")
	local dimensions = "80 24\n"
	if options.dimensions ~= nil then
		dimensions = options.dimensions or nil
	end
	local state = {
		pane = options.pane == nil and "%1" or options.pane,
		dimensions = dimensions,
		send_ok = options.send_ok ~= false,
		sent = {},
		calls = {},
		invalidated = false,
	}

	Pane.get_cached_pi_pane = function()
		return state.pane
	end

	Pane.invalidate = function()
		state.invalidated = true
	end

	Pane.cmd = function(args)
		table.insert(state.calls, table.concat(args, " "))

		if args[2] == "display-message" then
			return state.dimensions
		end

		if args[2] == "send-keys" then
			table.insert(state.sent, args[6])
			if not state.send_ok then
				return nil
			end
			return ""
		end
	end

	local Scroll = require("pi-tmux.scroll")
	return Scroll, state
end

describe("scroll", function()
	before_each(Helpers.reset)

	it("sends a centered wheel-up event to the cached pane", function()
		local Scroll, state = install()

		Scroll.scroll_up()

		assert(#state.sent == 1)
		assert(state.sent[1] == "\27[<64;40;12M")
		assert(state.calls[1]:find("pane_width", 1, true) ~= nil)
		assert(state.invalidated == false)
	end)

	it("repeats wheel events according to count", function()
		local Scroll, state = install()

		Scroll.scroll_down(3)

		assert(#state.sent == 1)
		assert(state.sent[1] == string.rep("\27[<65;40;12M", 3))
	end)

	it("defaults to one event and clamps invalid counts", function()
		local Scroll, state = install()

		Scroll.scroll_down()
		Scroll.scroll_up(0)
		Scroll.scroll_up(-5)

		assert(#state.sent == 3)
		assert(state.sent[1] == "\27[<65;40;12M")
		assert(state.sent[2] == "\27[<64;40;12M")
		assert(state.sent[3] == "\27[<64;40;12M")
	end)

	it("does nothing without a pane", function()
		local Scroll, state = install({ pane = false })

		Scroll.scroll_up()

		assert(#state.calls == 0)
		assert(state.invalidated == false)
	end)

	it("invalidates the cache when send-keys fails", function()
		local Scroll, state = install({ send_ok = false })

		Scroll.scroll_down()

		assert(#state.sent == 1)
		assert(state.invalidated == true)
	end)

	it("falls back to the top-left position when pane size is unavailable", function()
		local Scroll, state = install({ dimensions = false })

		Scroll.scroll_up()

		assert(state.sent[1] == "\27[<64;1;1M")
	end)
end)
