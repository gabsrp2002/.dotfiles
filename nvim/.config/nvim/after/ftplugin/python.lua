local function map(mode, lhs, rhs, opts)
  local options = vim.tbl_extend("force", { buffer = true, silent = true }, opts or {})
  vim.keymap.set(mode, lhs, rhs, options)
end

map("n", "<leader>rr", ":w | split | res 8 | terminal python3 %<CR>")
