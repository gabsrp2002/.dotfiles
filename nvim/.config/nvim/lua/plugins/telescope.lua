return {
  {
    "nvim-telescope/telescope.nvim",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "kyazdani42/nvim-web-devicons",
      "nvim-lua/popup.nvim",
      "BurntSushi/ripgrep",
      "nvim-telescope/telescope-ui-select.nvim",
      { "nvim-telescope/telescope-fzf-native.nvim", build = "make" },
    },
    cmd = "Telescope",
    keys = {
      { "<leader>tf", ":Telescope find_files<CR>" },
      { "<leader>tr", ":Telescope oldfiles<CR>" },
      { "<leader>tk", ":Telescope keymaps<CR>" },
      { "<leader>bb", ":Telescope buffers<CR>" },
      { "<leader>tw", ":Telescope grep_string<CR>" },
      { "<leader>tg", ":Telescope live_grep<CR>" },
      {
        "<leader>dd",
        ":Telescope diagnostics<CR>",
      },
      { "gd", ":Telescope lsp_definitions<CR>" },
      { "gi", ":Telescope lsp_implementations<CR>" },
      { "gr", ":Telescope lsp_references<CR>" },
      { "gt", ":Telescope lsp_type_definitions<CR>" },
    },
    config = function()
      require("telescope").setup({
        extensions = {
          ["ui-select"] = {
            require("telescope.themes").get_dropdown(),
          },
          fzf = {
            fuzzy = true, -- false will only do exact matching
            override_generic_sorter = true, -- override the generic sorter
            override_file_sorter = true, -- override the file sorter
            case_mode = "smart_case", -- or "ignore_case" or "respect_case"
          },
        },
        defaults = {
          vimgrep_arguments = {
            "rg",
            "--hidden",
            "--color=never",
            "--no-heading",
            "--with-filename",
            "--line-number",
            "--column",
            "--smart-case",
            "-g",
            "!.git",
          },
        },
        pickers = {
          find_files = {
            find_command = { "rg", "--files", "--hidden", "-g", "!.git" },
            follow = true
          },
        },
      })
      require("telescope").load_extension("ui-select")
      require("telescope").load_extension("fzf")
    end,
  },
}
