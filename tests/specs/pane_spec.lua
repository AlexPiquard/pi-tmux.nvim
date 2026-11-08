local Helpers = require("spec_helpers")

local function install(options)
	options = options or {}

	local Pane = require("pi-tmux.pane")
	local state = {
		current_window = options.current_window or "@1",
		panes = options.panes or { { window = "@1", pane = "%1", cmd = "pi" } },
		valid = {},
		pane_in_mode = "0",
	}

	for _, pane in ipairs(state.panes) do
		if pane.cmd == "pi" then
			state.valid[pane.pane] = { window = pane.window, cmd = pane.cmd }
		end
	end

	local calls = {}
	Pane.cmd = function(args)
		table.insert(calls, table.concat(args, " "))

		if args[2] == "display-message" then
			if args[4] == "#{window_id}" then
				return state.current_window .. "\n"
			end

			if args[4] == "-t" then
				local target = args[5]
				local format = args[6] or ""
				if format:find("pane_in_mode", 1, true) then
					return state.pane_in_mode .. "\n"
				end

				local valid = state.valid[target]
				if valid then
					return target .. " " .. valid.window .. " " .. valid.cmd .. "\n"
				end
				return nil
			end
		end

		if args[2] == "list-panes" then
			local output = {}
			for _, pane in ipairs(state.panes) do
				table.insert(output, pane.window .. " " .. pane.pane .. " " .. pane.cmd)
			end
			return table.concat(output, "\n") .. "\n"
		end
	end

	return Pane, state, calls
end

local function count(calls, needle)
	local total = 0
	for _, call in ipairs(calls) do
		if call:find(needle, 1, true) then
			total = total + 1
		end
	end
	return total
end

local function reset(calls)
	for index = #calls, 1, -1 do
		calls[index] = nil
	end
end

describe("pane lookup", function()
	before_each(Helpers.reset)

	local notify

	before_each(function()
		notify = Helpers.capture_notify()
	end)

	after_each(function()
		notify.restore()
	end)

	it("finds pi and caches the pane", function()
		local Pane, _, calls = install()

		assert(Pane.find_pi_pane() == "%1")
		assert(count(calls, "list-panes") == 1)
		assert(count(calls, "display-message -p #{window_id}") == 1)
	end)

	it("validates a cached pane without scanning all panes", function()
		local Pane, _, calls = install()

		assert(Pane.find_pi_pane() == "%1")
		assert(Pane.find_pi_pane() == "%1")
		assert(count(calls, "list-panes") == 1)
		assert(count(calls, "display-message -p -t %1") == 1)
	end)

	it("keeps a valid cached pane from another window", function()
		local Pane, state, calls = install()
		assert(Pane.find_pi_pane() == "%1")

		state.current_window = "@2"
		reset(calls)

		assert(Pane.find_pi_pane() == "%1")
		assert(count(calls, "list-panes") == 0)
		assert(count(calls, "display-message -p #{window_id}") == 0)
		assert(count(calls, "display-message -p -t %1") == 1)
	end)

	it("rescans with current-window priority when the cache is invalid", function()
		local Pane, state, calls = install()
		assert(Pane.find_pi_pane() == "%1")

		state.current_window = "@2"
		state.valid["%1"] = { window = "@1", cmd = "bash" }
		state.panes = {
			{ window = "@1", pane = "%1", cmd = "bash" },
			{ window = "@2", pane = "%2", cmd = "pi" },
			{ window = "@2", pane = "%3", cmd = "pi" },
		}
		reset(calls)

		assert(Pane.find_pi_pane() == "%2")
		assert(count(calls, "list-panes") == 1)
	end)

	it("falls back to pi in another window", function()
		local Pane, _, calls = install({
			current_window = "@2",
			panes = { { window = "@1", pane = "%1", cmd = "pi" } },
		})

		assert(Pane.find_pi_pane() == "%1")
		assert(count(calls, "list-panes") == 1)
	end)

	it("notifies and returns nil when no pi pane exists", function()
		local Pane = install({
			panes = { { window = "@1", pane = "%1", cmd = "bash" } },
		})

		assert(Pane.find_pi_pane(true) == nil)
		assert(#notify.notes == 1)
		assert(Helpers.has_notify(notify, "Couldn't find"))
	end)

	it("returns the cached pane without any tmux call", function()
		local Pane, _, calls = install()
		assert(Pane.find_pi_pane() == "%1")

		reset(calls)
		assert(Pane.get_cached_pi_pane() == "%1")
		assert(#calls == 0)
	end)

	it("falls back to a lookup when there is no cached pane", function()
		local Pane, _, calls = install({ current_window = "@2", panes = {} })

		assert(Pane.get_cached_pi_pane() == nil)
		assert(count(calls, "list-panes") == 1)
	end)

	it("invalidates the cache explicitly", function()
		local Pane, _, calls = install()
		assert(Pane.find_pi_pane() == "%1")

		Pane.invalidate()
		reset(calls)

		assert(Pane.get_cached_pi_pane() == "%1")
		assert(count(calls, "list-panes") == 1)
	end)

	it("reports pane copy mode", function()
		local Pane, state = install()

		state.pane_in_mode = "1"
		assert(Pane.pane_in_mode("%1") == true)

		state.pane_in_mode = "0"
		assert(Pane.pane_in_mode("%1") == false)
	end)
end)
