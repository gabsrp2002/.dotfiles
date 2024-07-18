return {
  "NeogitOrg/neogit",
  dependencies = {
    "nvim-lua/plenary.nvim",
    "sindrets/diffview.nvim",
  },
  commit = "d6b80dc",
  cmd = { "Neogit" },
  keys = {
    { "<leader>ng", ":Neogit cwd=%:h<cr>", { silent = true, noremap = true } },
  },
  opts = {
    integrations = {
      telescope = true,
      diffview = true,
    },
  },
  init = function()
    local group = vim.api.nvim_create_augroup("MyCustomNeogitEvents", { clear = true })
    vim.api.nvim_create_autocmd("User", {
      pattern = "NeogitPushComplete",
      group = group,
      callback = function()
        require("neogit").close()
      end,
    })
  end,
}
