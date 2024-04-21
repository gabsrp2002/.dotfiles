return {
  "echasnovski/mini.files",
  version = "*",
  lazy = true,
  opts = {
    mappings = {
      close = "q",
      go_in = "",
      go_in_plus = "<cr>",
      go_out = "",
      go_out_plus = "-",
      reset = "<bs>",
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
        require("mini.files").open(vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0), ":p:h"), false)
      end,
      { noremap = true, silent = true },
    },
  },
}
