local function map(mode, lhs, rhs, opts)
  local options = { noremap = true }
  if opts then
    options = vim.tbl_extend("force", options, opts)
  end
  vim.keymap.set(mode, lhs, rhs, options)
end

local opts = { silent = true }

-- Fast saving and quiting
map("n", "<leader><leader>", ":silent! w<CR>", opts)
map("n", "<leader>w", ":w !sudo tee %", opts) -- Saves with sudo
map("n", "<leader>q", ":q<CR>", opts)
map("n", "<leader>Q", ":wqall<CR>", opts)

-- Switch CWD to current directory
map("n", "<leader>cd", ":cd %:p:h<CR>:pwd<CR>")

-- Move between buffers
map("n", "<Tab>", ":bnext<CR>", opts)
map("n", "<S-Tab>", ":bprev<CR>", opts)

-- Disable highlight faster
map("n", "<Esc>", "<cmd>nohlsearch<CR>", opts)

map("n", "<leader>tt", ":silent !tmux split-window -v \\; resize-pane -D 10<CR>", opts)

-- Just for fun, makes a game ui
vim.api.nvim_create_user_command("Chill", function()
  local games = {
    { module = "cellular-automaton", name = "Game of Life" },
    { module = "cellular-automaton", name = "Make it Rain" },
    { module = "nvimesweeper", name = "Minesweeper" },
  }

  local available_games = {}

  for _, game_info in ipairs(games) do
    local ok, _ = pcall(require, game_info.module)

    if ok then
      table.insert(available_games, game_info.name)
    end
  end
  vim.ui.select(available_games, {
    prompt = "Select a way to chill!",
    format_item = function(item)
      return item
    end,
  }, function(choice)
    if not choice then
      print("Invalid game number.")
    end
    if choice == "Minesweeper" then
      vim.cmd("Nvimesweeper")
    end

    if choice == "Game of Life" then
      vim.cmd("CellularAutomaton game_of_life")
    end

    if choice == "Make it Rain" then
      vim.cmd("CellularAutomaton make_it_rain")
    end
  end)
end, { nargs = 0 })

-- Lsp keybinds
map("n", "gD", vim.lsp.buf.declaration, opts)
map("n", "K", vim.lsp.buf.hover, opts)
map("n", "<leader>do", vim.diagnostic.open_float, opts)
map("n", "<leader>ca", function()
  vim.lsp.buf.code_action({ apply = true })
end, opts)
map("n", "<leader>rn", vim.lsp.buf.rename, opts)
