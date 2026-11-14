local function map(mode, lhs, rhs, opts)
  local options = vim.tbl_extend("force", { buffer = true, silent = true }, opts or {})
  vim.keymap.set(mode, lhs, rhs, options)
end

map("n", "<leader>f", ":!npx prisma db push && npx prisma format --schema %:p<CR>")

vim.opt_local.tabstop = 2
vim.opt_local.shiftwidth = 2
vim.opt_local.softtabstop = 2
