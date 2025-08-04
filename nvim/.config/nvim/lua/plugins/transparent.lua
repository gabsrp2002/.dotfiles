return {
  "xiyaowong/transparent.nvim",
  event = "VimEnter",
  config = function()
    require("transparent").setup({
      groups = {
        "Normal",
        "NormalNC",
        "Comment",
        "Constant",
        "Special",
        "Identifier",
        "Statement",
        "PreProc",
        "Type",
        "Underlined",
        "Todo",
        "String",
        "Function",
        "Conditional",
        "Repeat",
        "Operator",
        "Structure",
        "LineNr",
        "NonText",
        "SignColumn",
        "CursorLine",
        "CursorLineNr",
        "StatusLine",
        "StatusLineNC",
        "EndOfBuffer",
      },
      extra_groups = { "NormalFloat", "FloatBorder", "TabLineFill" },
      exclude_groups = {},
    })
    require("transparent").clear_prefix("BufferLine")
  end,
}
