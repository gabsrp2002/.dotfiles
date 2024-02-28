return {
  "gbprod/substitute.nvim",
  keys = {
    { "cx", nil },
    { "cxx", nil },
    { "X", nil, mode = "v" },
    { "cxc", nil },
  },
  config = function()
    require("substitute").setup()
    vim.keymap.set("n", "cx", require("substitute.exchange").operator, { noremap = true })
    vim.keymap.set("n", "cxx", require("substitute.exchange").line, { noremap = true })
    vim.keymap.set("v", "X", require("substitute.exchange").visual, { noremap = true })
    vim.keymap.set("n", "cxc", require("substitute.exchange").cancel, { noremap = true })
  end,
}
