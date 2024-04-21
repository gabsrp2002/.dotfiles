return {
  "mhartington/formatter.nvim",

  config = function()
    local util = require("formatter.util")

    local clang_formatter = function()
      return {
        exe = "clang-format",
        args = {
          "-assume-filename",
          util.escape_path(util.get_current_buffer_file_name()),
          "-style",
          "Google",
        },
        stdin = true,
        try_node_modules = true,
      }
    end
    require("formatter").setup({
      -- Enable or disable logging
      logging = true,
      -- Set the log level
      log_level = vim.log.levels.WARN,
      -- All formatter configurations are opt-in
      filetype = {
        lua = {
          function()
            return {
              exe = "stylua",
              args = {
                "--search-parent-directories",
                "--stdin-filepath",
                util.escape_path(util.get_current_buffer_file_path()),
                "--indent-type=Spaces",
                "--indent-width=2",
                "--",
                "-",
              },
              stdin = true,
            }
          end,
        },
        python = {
          function()
            return {
              exe = "black",
              args = { "--line-length", "79", "-q", "-" },
              stdin = true,
            }
          end,
        },
        c = {
          clang_formatter,
        },
        cpp = {
          clang_formatter,
        },
        html = {
          require("formatter.filetypes.html").prettier,
        },
        javascript = {
          require("formatter.filetypes.javascript").prettier,
        },
        css = {
          require("formatter.filetypes.css").prettier,
        },
        typescript = {
          require("formatter.filetypes.typescript").prettier,
        },
        typescriptreact = {
          require("formatter.filetypes.typescriptreact").prettier,
        },
        markdown = {
          require("formatter.filetypes.markdown").prettier,
        },
        json = {
          require("formatter.filetypes.json").fixjson,
        },
        jsonc = {
          require("formatter.filetypes.json").fixjson,
        },
        tex = {
          function()
            return {
              exe = "latexindent",
              args = {
                "-l",
                "-m",
                '-y="modifyLineBreaks:textWrapOptions:columns: 120,defaultIndent: \'    \'"',
              },
              stdin = true,
            }
          end,
        },
        go = {
          require("formatter.filetypes.go").gofmt,
        },
        ["*"] = {
          require("formatter.filetypes.any").remove_trailing_whitespace,
          require("formatter.filetypes.any").trim_whitespace,
        },
      },
    })
  end,
  keys = {
    { "<leader>f", ":Format<CR>", silent = true, noremap = true },
  },
}
