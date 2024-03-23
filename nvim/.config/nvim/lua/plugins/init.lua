return {

  {
    "folke/noice.nvim",
    event = "VeryLazy",
    opts = {},
    dependencies = {
      -- if you lazy-load any plugin below, make sure to add proper `module="..."` entries
      "MunifTanjim/nui.nvim",
      {
        "rcarriga/nvim-notify",
        config = function()
          vim.g.termguicolors = true
          local notify = require("notify")
          notify.setup({
            background_colour = "#000000",
          })
          vim.notify = notify
        end,
      },
    },
  },
  -- Git diff
  { "sindrets/diffview.nvim" },

  { "ggandor/lightspeed.nvim" },
  {
    "kylechui/nvim-surround",
    version = "*",
    opts = {
      keymaps = {
        insert = "<C-g>s",
        insert_line = "<C-g>S",
        normal = "ys",
        normal_cur = "yss",
        normal_line = "yS",
        normal_cur_line = "ySS",
        visual = "<leader>s",
        visual_line = "g<leader>s",
        delete = "ds",
        change = "cs",
        change_line = "cS",
      },
    },
  },
  {
    "numToStr/Comment.nvim",
    opts = {},
  },
  {
    "chrisgrieser/nvim-spider",
    keys = {
      { "w", "<cmd>lua require('spider').motion('w')<CR>", mode = { "n", "o", "x" }, { desc = "Spider-w" } },
      { "e", "<cmd>lua require('spider').motion('e')<CR>", mode = { "n", "o", "x" }, { desc = "Spider-e" } },
      { "b", "<cmd>lua require('spider').motion('b')<CR>", mode = { "n", "o", "x" }, { desc = "Spider-b" } },
      { "ge", "<cmd>lua require('spider').motion('ge')<CR>", mode = { "n", "o", "x" }, { desc = "Spider-ge" } },
    },
  },

  {
    "neovim/nvim-lspconfig",
    dependencies = { "hrsh7th/cmp-nvim-lsp", "folke/neodev.nvim" },
    config = function()
      local lspconfig = require("lspconfig")
      local capabilities = require("cmp_nvim_lsp").default_capabilities()
      local servers = { "pyright", "clangd", "texlab", "tsserver", "eslint", "cssls", "svlangserver", "html", "gopls" }
      for _, server in ipairs(servers) do
        lspconfig[server].setup({
          capabilities = capabilities,
        })
      end

      require("neodev").setup()

      lspconfig.lua_ls.setup({
        capabilities = capabilities,
        settings = {
          Lua = {
            diagnostics = {
              globals = { "vim", "use" },
            },
          },
        },
      })
    end,
  },

  -- Bufferline
  {
    "akinsho/bufferline.nvim",
    version = "v3.*",
    dependencies = { "kyazdani42/nvim-web-devicons" },
    after = "catppuccin",
    config = function()
      vim.opt.termguicolors = true
      require("bufferline").setup({
        highlights = require("catppuccin.groups.integrations.bufferline").get(),
        options = {
          mode = "buffers",
          buffer_close_icon = "",
          modified_icon = "●",
          close_icon = "",
          left_trunc_marker = "",
          right_trunc_marker = "",
        },
      })
      vim.keymap.set("n", "<leader>tc", ":BufferLinePick<CR>", { noremap = true, silent = true })
    end,
  },

  -- Markdown Preview
  {
    "toppair/peek.nvim",
    event = { "VeryLazy" },
    build = "deno task --quiet build:fast",
    config = function()
      require("peek").setup({ app = "browser" })
      -- refer to `configuration to change defaults`
      vim.api.nvim_create_user_command("PeekOpen", require("peek").open, {})
      vim.api.nvim_create_user_command("PeekClose", require("peek").close, {})
    end,
  },

  -- Moves text around
  {
    "fedepujol/move.nvim",
    keys = {
      { "J", ":MoveBlock(1)<CR>", mode = "v", { noremap = true, silent = true } },
      { "K", ":MoveBlock(-1)<CR>", mode = "v", { noremap = true, silent = true } },
      { "L", ":MoveHBlock(1)<CR>", mode = "v", { noremap = true, silent = true } },
      { "H", ":MoveHBlock(-1)<CR>", mode = "v", { noremap = true, silent = true } },
    },
  },

  -- Harpoon
  {
    "ThePrimeagen/harpoon",
    dependencies = { "nvim-lua/plenary.nvim", "nvim-telescope/telescope.nvim" },
    keys = {
      { "<leader>ha", nil },
      { "<leader>hh", nil },
      { "<C-n>", nil },
      { "<C-p>", nil },
      { "<leader>ht", nil },
    },
    config = function()
      require("harpoon").setup({
        save_on_change = false,
        enter_on_sendcmd = true,
        excluded_filetypes = { "harpoon", "alpha", "nerdtree" },
      })

      -- Maps
      local mark = require("harpoon.mark")
      local mark_ui = require("harpoon.ui")
      local cmd_ui = require("harpoon.cmd-ui")
      vim.keymap.set("n", "<leader>ha", mark.add_file, { noremap = true, silent = true })
      vim.keymap.set("n", "<leader>hh", ":Telescope harpoon marks<CR>", { noremap = true, silent = true })
      vim.keymap.set("n", "<C-n>", mark_ui.nav_next, { noremap = true, silent = true })
      vim.keymap.set("n", "<C-p>", mark_ui.nav_prev, { noremap = true, silent = true })
      vim.keymap.set("n", "<leader>ht", cmd_ui.toggle_quick_menu, { noremap = true, silent = true })
    end,
  },

  -- Focus
  {
    "nvim-focus/focus.nvim",
    config = function()
      require("focus").setup({
        enable = true, -- Enable module
        commands = true, -- Create Focus commands
        autoresize = {
          enable = true, -- Enable or disable auto-resizing of splits
          width = 0, -- Force width for the focused window
          height = 0, -- Force height for the focused window
          minwidth = 0, -- Force minimum width for the unfocused window
          minheight = 0, -- Force minimum height for the unfocused window
          height_quickfix = 10, -- Set the height of quickfix panel
        },
        split = {
          bufnew = false, -- Create blank buffer for new split windows
          tmux = false, -- Create tmux splits instead of neovim splits
        },
        ui = {
          number = false, -- Display line numbers in the focussed window only
          relativenumber = true, -- Display relative line numbers in the focussed window only
          hybridnumber = true, -- Display hybrid line numbers in the focussed window only
          absolutenumber_unfocussed = false, -- Preserve absolute numbers in the unfocussed windows

          cursorline = false, -- Display a cursorline in the focussed window only
          cursorcolumn = false, -- Display cursorcolumn in the focussed window only
          colorcolumn = {
            enable = false, -- Display colorcolumn in the foccused window only
            list = "+1", -- Set the comma-saperated list for the colorcolumn
          },
          signcolumn = true, -- Display signcolumn in the focussed window only
          winhighlight = false, -- Auto highlighting for focussed/unfocussed windows
        },
      })
      local ignore_filetypes = { "TelescopePrompt", "alpha", "oil" }
      local ignore_buftypes = { "nofile", "prompt", "popup" }

      local augroup = vim.api.nvim_create_augroup("FocusDisable", { clear = true })

      vim.api.nvim_create_autocmd("WinEnter", {
        group = augroup,
        callback = function(_)
          if vim.tbl_contains(ignore_buftypes, vim.bo.buftype) then
            vim.w.focus_disable = true
          else
            vim.w.focus_disable = false
          end
        end,
        desc = "Disable focus autoresize for BufType",
      })

      vim.api.nvim_create_autocmd("FileType", {
        group = augroup,
        callback = function(_)
          if vim.tbl_contains(ignore_filetypes, vim.bo.filetype) then
            vim.w.focus_disable = true
          else
            vim.w.focus_disable = false
          end
        end,
        desc = "Disable focus autoresize for FileType",
      })

      -- Keymaps
      vim.keymap.set("n", "<leader>l", function()
        if not vim.t.maximized then
          require("focus").split_nicely()
        end
      end, { desc = "split nicely" })
    end,
  },

  -- Maximize
  {
    "declancm/windex.nvim",
    keys = {
      {
        "<leader>m",
        function()
          require("windex").toggle_maximize()
        end,
        { desc = "toggle maximize window" },
      },
    },
    opts = {
      default_keymaps = false,
    },
  },

  -- Tree-sitter
  {
    "nvim-treesitter/nvim-treesitter",
    build = ":TSUpdate",
    dependencies = { "windwp/nvim-ts-autotag" },
    init = function()
      vim.opt.foldmethod = "expr"
      vim.opt.foldexpr = "nvim_treesitter#foldexpr()"
    end,
    main = "nvim-treesitter.configs",
    opts = {
      highlight = {
        enable = true,
      },
      indent = {
        enable = true,
      },
      autotag = {
        enable = true,
      },
    },
  },

  -- Rainbow
  {
    "hiphish/rainbow-delimiters.nvim",
    config = function()
      -- This module contains a number of default definitions
      local rainbow_delimiters = require("rainbow-delimiters")

      vim.g.rainbow_delimiters = {
        strategy = {
          [""] = rainbow_delimiters.strategy["global"],
          vim = rainbow_delimiters.strategy["local"],
        },
        query = {
          [""] = "rainbow-delimiters",
          lua = "rainbow-blocks",
          latex = "rainbow-blocks",
        },
        highlight = {
          "RainbowDelimiterRed",
          "RainbowDelimiterYellow",
          "RainbowDelimiterBlue",
          "RainbowDelimiterOrange",
          "RainbowDelimiterGreen",
          "RainbowDelimiterViolet",
          "RainbowDelimiterCyan",
        },
      }
    end,
  },

  {
    "aymericbeaumet/vim-symlink",
    dependencies = { "moll/vim-bbye" },
  },
}
