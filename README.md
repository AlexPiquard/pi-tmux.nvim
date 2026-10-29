# pi-tmux.nvim

Send text from Neovim to a [pi](https://pi.dev) session running in a tmux pane,
and automatically reload files modified by pi.

## Features

- Use tmux to communicate with `pi` in another pane or window
- Automatically reload files modified by `pi`
- Merge with unsaved buffer changes
- Scroll the pi window directly from Neovim
- Zero dependencies on the `pi` side: no sockets, no background services, just tmux

## Requirements

- Neovim >= 0.10
- tmux
- `pi` running in a tmux pane; the current window is preferred when searching
- `git` for the default merge mode

The plugin does not start `pi`.

## Installation

[lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  "AlexPiquard/pi-tmux.nvim",
  opts = {},
  keys = {
    -- Example keybinding
    {
      "<leader>a",
      function()
        require("pi-tmux").ask()
      end,
      mode = {"n", "x"},
      desc = "Ask Pi",
    }
  }
}
```

<details>
<summary><a href="https://neovim.io/doc/user/pack/#vim.pack">vim.pack</a></summary>

```lua
vim.pack.add({
  {
    src = "https://github.com/AlexPiquard/pi-tmux.nvim",
  },
})

require("pi-tmux").setup({
  -- Opts here
})

-- Example keybinding
vim.keymap.set({ "n", "x" }, "<leader>pa", function() require("pi-tmux").ask() end, { desc = "Ask Pi" })
```

</details>

## Usage

```vim
:PiTmuxAsk [prompt]
```

Without a prompt, `vim.ui.input` is opened. In visual mode, the current
selection is sent; otherwise, the current line is used.

Keymap example:

```lua
vim.keymap.set({ "n", "x" }, "<leader>pa", function()
  require("pi-tmux").ask()
end, { desc = "Ask pi" })
```

## Configuration

Defaults:

```lua
require("pi-tmux").setup({
  ask = {
    prompt = "Ask Pi",
  },
  reload = {
    auto_reload = true,
    reload_debounce_ms = 150,
    reload_on_conflict = "merge",
  },
})
```

`reload_on_conflict`:

- `"merge"`: merge pi changes into the unsaved buffer;
- `"force"`: reload the file even if the buffer has unsaved changes;
- `"notify"`: keep the buffer and show a warning.

## License

[MIT](./LICENSE)
