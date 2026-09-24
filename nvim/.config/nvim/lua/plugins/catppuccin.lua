return {
  "catppuccin/nvim",
  name = "catppuccin",
  priority = 1000,
  config = function()
    require("catppuccin").setup(
      {
        flavour = "mocha",
        float = {
          transparent = true,
          solid = false,
        },
        transparent_background = true,
        show_end_of_buffer = false,
        term_colors = false,
        dim_inactive = {
          enabled = false,
          shade = "dark",
          percentage = 0.15,
        },
        no_italic = false,
        no_bold = false,
        no_underline = false,
        styles = {
          comments = { "italic" },
          conditionals = { "italic" },
          loops = {},
          functions = { "bold" },
          keywords = { "italic" },
          strings = { "italic" },
          variables = {},
          numbers = {},
          booleans = {},
          properties = {},
          types = {},
          operators = {},
        },
        color_overrides = {},
        custom_highlights = {},
        integrations = {
          cmp = true,
          treesitter = true,
          noice = true,
          alpha = true,
          harpoon = true,
          lightspeed = true,
          copilot_vim = true,
          telescope = true,
          rainbow_delimiters = true,
        },
      }
    )
    vim.cmd.colorscheme("catppuccin")
  end,
}
