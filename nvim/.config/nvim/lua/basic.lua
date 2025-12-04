-- Tab config
vim.opt.expandtab = true
vim.opt.smarttab = true
vim.opt.tabstop = 4
vim.opt.shiftwidth = 4
vim.opt.softtabstop = 4

-- Auto update when file changes
vim.opt.autoread = true

-- Set the scroll offset
vim.opt.so = 7

vim.g.python3_host_prog = vim.fn.expand('$HOME/.config/nvim/venv/bin/python')

vim.g.loaded_perl_provider = 0

-- Copys to clipboard
vim.schedule(function()
  vim.opt.clipboard = "unnamedplus"
end)

-- Sets leader
vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- Better spliting
vim.opt.splitbelow = true
vim.opt.splitright = true

-- Set numbers
vim.opt.nu = true
vim.opt.rnu = true

-- Doesn't show mode
vim.opt.showmode = false

-- Set encoding
vim.opt.encoding = "UTF-8"

-- Disable mouse
vim.opt.mouse = ""

-- Case-insensitive searching
vim.opt.ignorecase = true
vim.opt.smartcase = true

-- Preview substitutions in a split window
vim.opt.inccommand = "split"

-- Decrease updatetime
vim.opt.updatetime = 250

-- keep cursor in the same indent level
vim.opt.breakindent = true

-- Set undofile
vim.opt.undofile = true

-- Highlight when yanking (copying) text
vim.api.nvim_create_autocmd("TextYankPost", {
  desc = "Highlight when yanking (copying) text",
  group = vim.api.nvim_create_augroup("highlight-yank", { clear = true }),
  callback = function()
    vim.hl.on_yank({ higroup = "IncSearch", timeout = 300 })
  end,
})

-- Setup lazy plugin to load plugins
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.uv.fs_stat(lazypath) then
  vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable",
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

require("lazy").setup({ spec = "plugins", change_detection = { notify = false } })

-- LSP signs
vim.diagnostic.config({
  signs = {
    text = {
      [vim.diagnostic.severity.ERROR] = " ",
      [vim.diagnostic.severity.WARN] = " ",
      [vim.diagnostic.severity.HINT] = " ",
      [vim.diagnostic.severity.INFO] = " ",
    },
  },
})
