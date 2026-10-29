local Helpers = require("spec_helpers")

describe("buffer helpers", function()
	before_each(Helpers.reset)

	it("detects file buffers and ignores special buffers", function()
		local Buffer = require("pi-tmux.buffer")
		local file = Helpers.temp_file({ "one" })

		assert(Buffer.get_path(file.buf) == file.path)
		assert(Buffer.is_file_buffer(file.buf) == true)

		vim.cmd("enew")
		local scratch = vim.api.nvim_get_current_buf()
		assert(Buffer.get_path(scratch) == nil)
		assert(Buffer.is_file_buffer(scratch) == false)

		local special = vim.api.nvim_create_buf(true, false)
		vim.api.nvim_buf_set_name(special, "term://test")
		vim.bo[special].buftype = "nofile"
		assert(Buffer.get_path(special) == nil)
		assert(Buffer.is_file_buffer(special) == false)
		vim.api.nvim_buf_delete(special, { force = true })

		assert(Buffer.is_file_buffer(999999) == false)
	end)

	it("reloads from disk and preserves the cursor", function()
		local Buffer = require("pi-tmux.buffer")
		local file = Helpers.temp_file({ "a", "b", "c", "d", "e" })
		vim.api.nvim_win_set_cursor(0, { 4, 0 })

		Helpers.writefile(file.path, { "A", "B", "C", "D", "E", "F" })
		Buffer.reload(file.buf)

		assert(vim.deep_equal(Helpers.lines(file.buf), { "A", "B", "C", "D", "E", "F" }))
		assert(vim.api.nvim_win_get_cursor(0)[1] == 4)
	end)
end)
