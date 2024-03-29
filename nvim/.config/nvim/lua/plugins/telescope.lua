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
      { "<leader>tf", ":Telescope find_files<CR>", { noremap = true, silent = true } },
      { "<leader>tr", ":Telescope oldfiles<CR>", { noremap = true, silent = true } },
      { "<leader>bb", ":Telescope buffers<CR>", { noremap = true, silent = true } },
      { "<leader>gb", ":Telescope git_branches<CR>", { noremap = true, silent = true } },
      { "<leader>gs", ":Telescope git_status<CR>", { noremap = true, silent = true } },
      {
        "<leader>dd",
        ":Telescope diagnostics bufnr=0<CR>",
        { noremap = true, silent = true },
      },
      { "gd", ":Telescope lsp_definitions<CR>", { noremap = true, silent = true } },
      { "gi", ":Telescope lsp_implementations<CR>", { noremap = true, silent = true } },
      { "gr", ":Telescope lsp_references<CR>", { noremap = true, silent = true } },
      { "gt", ":Telescope lsp_type_definitions<CR>", { noremap = true, silent = true } },
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
      })
      require("telescope").load_extension("ui-select")
      require("telescope").load_extension("fzf")
    end,
  },
}
