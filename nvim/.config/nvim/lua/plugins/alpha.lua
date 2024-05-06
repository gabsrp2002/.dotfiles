return {
  "goolord/alpha-nvim",
  dependencies = { "kyazdani42/nvim-web-devicons" },
  config = function()
    vim.keymap.set("n", "<leader>in", ":Alpha<cr>", { noremap = true, silent = true })
    local alpha = require("alpha")
    local dashboard = require("alpha.themes.dashboard")

    local function pick_color()
      return "Keyword"
    end

    local function footer()
      local total_plugins = vim.fn.len(vim.fn.globpath("~/.local/share/nvim/lazy", "*", 0, 1))
      local version = vim.version()
      local nvim_version_info = "   v" .. version.major .. "." .. version.minor .. "." .. version.patch

      return "󰰅 " .. total_plugins .. " plugins" .. nvim_version_info
    end

    dashboard.section.header.opts.hl = pick_color()

    dashboard.section.buttons.val = {
      dashboard.button("r", "󱋡  Recent files", ":Telescope oldfiles<cr>"),

      dashboard.button("s", "󰈞  Search file", ":Telescope find_files<cr>"),

      dashboard.button("u", "󰚰  Sync plugins", ":Lazy sync<cr>"),

      dashboard.button(
        "vv",
        "  Neovim config",
        ":lua require(\"mini.files\").open(\"~/.config/nvim/lua\", false)<cr>"
      ),

      dashboard.button(
        "vf",
        "󰈮  Filetypes config",
        ":lua require(\"mini.files\").open(\"~/.config/nvim/after/ftplugin\", false)<cr>"
      ),

      dashboard.button("q", "  Quit", ":qa<cr>"),
    }

    dashboard.section.footer.val = footer()
    dashboard.section.footer.opts.hl = "Constant"

    alpha.setup(dashboard.opts)

    vim.cmd([[ autocmd FileType alpha setlocal nofoldenable ]])
  end,
}
