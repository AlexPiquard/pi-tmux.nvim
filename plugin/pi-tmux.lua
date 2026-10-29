local PiTmux = require("pi-tmux")

vim.api.nvim_create_user_command("PiTmuxAsk", function(opts)
    local args = vim.split(opts.args, "%s+", { trimempty = true })

    local text
    if #args >= 1 then
        text = table.concat(vim.list_slice(args, 0), " ")
    end

    PiTmux.ask(text)
end, { nargs = "*", range = true })
