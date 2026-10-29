local Helpers = require("spec_helpers")

describe("config", function()
	before_each(Helpers.reset)

	it("has merge as the default conflict mode", function()
		local config = require("pi-tmux.config")

		assert(config.defaults.reload.auto_reload == true)
		assert(config.defaults.reload.reload_debounce_ms == 150)
		assert(config.defaults.reload.reload_on_conflict == "merge")
		assert(config.defaults.ask.prompt == "Ask Pi")
		assert(config.defaults.ask.snacks.enabled == true)
	end)

	it("deep-merges custom options with defaults", function()
		local config = require("pi-tmux.config")

		config.setup({ reload = { reload_on_conflict = "notify" } })

		assert(config.opts.reload.reload_on_conflict == "notify")
		assert(config.opts.reload.auto_reload == true)
		assert(config.opts.reload.reload_debounce_ms == 150)
	end)

	it("returns a section merged with per-call overrides", function()
		local config = require("pi-tmux.config")
		config.setup()

		local ask = config.get("ask")
		assert(ask.prompt == "Ask Pi")

		local override = config.get("ask", { prompt = "Custom prompt" })
		assert(override.prompt == "Custom prompt")
		assert(override.snacks.enabled == true)
	end)

	it("returns all defaults when called without arguments", function()
		local config = require("pi-tmux.config")
		config.setup({ reload = { auto_reload = false } })

		local opts = config.get()
		assert(opts.reload.auto_reload == true)
		assert(opts.ask.prompt == "Ask Pi")
	end)
end)
