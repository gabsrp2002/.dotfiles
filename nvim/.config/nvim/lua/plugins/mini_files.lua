return {
  "echasnovski/mini.files",
  version = "*",
  lazy = false,
  opts = {
    mappings = {
      close = "q",
      go_in = "",
      go_in_plus = "<cr>",
      go_out = "",
      go_out_plus = "<bs>",
      reset = "#",
      reveal_cwd = "@",
      show_help = "g?",
      synchronize = "=",
      trim_left = "<",
      trim_right = ">",
    },
  },
  keys = {
    {
      "-",
      function()
        require("mini.files").open(vim.api.nvim_buf_get_name(0), false)
      end,
      { noremap = true, silent = true },
    },
  },
}
