local function map(mode, lhs, rhs, opts)
  local options = vim.tbl_extend("force", { buffer = true, silent = true }, opts or {})
  vim.keymap.set(mode, lhs, rhs, options)
end

vim.opt_local.tabstop = 2
vim.opt_local.shiftwidth = 2
vim.opt_local.softtabstop = 2

map("n", "<leader>rr", ":w | split | res 8 | terminal gcc -std=c99 -Wall -Wvla -Werror -g -lm *.c -o %:r && ./%:r<CR>")
map("n", "<leader>cc", ":w | split | res 8 | terminal gcc -std=c99 -Wall -Wvla -Werror -g -lm *.c -o %:r<CR>i")
