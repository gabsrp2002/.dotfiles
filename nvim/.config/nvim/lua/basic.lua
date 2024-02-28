-- Tab config
vim.opt.expandtab = true
vim.opt.smarttab = true
vim.opt.tabstop = 4
vim.opt.shiftwidth = 4
vim.opt.softtabstop = 4

-- Set the scroll offset
vim.opt.so = 7

-- Sets path for pynvim
vim.g.python3_host_prog = "/opt/homebrew/bin/python3.11"

-- Copys to clipboard
vim.opt.clipboard = "unnamedplus"

-- Sets leader
vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- wild menu
vim.opt.wildmenu = true
vim.opt.wildignore = { "*.o", "*.pyc", "*/.git/*", "*/.DS_Store" }

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

vim.o.undofile = true

-- Go to previous location when editing a file
vim.api.nvim_create_autocmd("BufRead", {
  pattern = "",
  command = 'silent! normal `"',
})

-- Setup lazy plugin to load plugins
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable", -- latest stable release
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

require("lazy").setup("plugins")

-- LSP signs
local signs = { Error = " ", Warn = " ", Hint = " ", Info = " " }
for type, icon in pairs(signs) do
  local hl = "DiagnosticSign" .. type
  vim.fn.sign_define(hl, { text = icon, texthl = hl, numhl = hl })
end
