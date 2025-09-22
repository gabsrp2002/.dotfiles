return {
  {
    "hrsh7th/nvim-cmp",
    event = { "InsertEnter", "CmdlineEnter" },
    dependencies = {
      "neovim/nvim-lspconfig",
      "hrsh7th/cmp-nvim-lsp",
      "hrsh7th/cmp-buffer",
      "hrsh7th/cmp-path",
      "hrsh7th/cmp-cmdline",
      "hrsh7th/cmp-nvim-lua",
      "kdheepak/cmp-latex-symbols",
      "SirVer/ultisnips",
      "quangnguyen30192/cmp-nvim-ultisnips",
    },
    config = function()
      local cmp = require("cmp")
      local kind_icons = {
        Text = "",
        Method = "󰆧",
        Function = "󰊕",
        Constructor = "",
        Field = "󰇽",
        Variable = "󰂡",
        Class = "󰠱",
        Interface = "",
        Module = "",
        Property = "󰜢",
        Unit = "",
        Value = "󰎠",
        Enum = "",
        Keyword = "󰌋",
        Snippet = "",
        Color = "󰏘",
        File = "󰈙",
        Reference = "",
        Folder = "󰉋",
        EnumMember = "",
        Constant = "󰏿",
        Struct = "",
        Event = "",
        Operator = "󰆕",
        TypeParameter = "󰅲",
      }

      cmp.setup({
        snippet = {
          expand = function(args)
            vim.fn["UltiSnips#Anon"](args.body)
          end,
        },
        window = {
          completion = cmp.config.window.bordered(),
          documentation = cmp.config.window.bordered(),
        },
        mapping = cmp.mapping.preset.insert({
          ["<C-p>"] = cmp.mapping(cmp.mapping.select_prev_item(), { "i", "c" }),
          ["<C-n>"] = cmp.mapping(cmp.mapping.select_next_item(), { "i", "c" }),
          ["<CR>"] = cmp.mapping.confirm({ select = false }),
        }),
        sources = cmp.config.sources({
          { name = "lazydev", group_index = 0 },
          { name = "nvim_lsp" },
          { name = "ultisnips" },
          { name = "path" },
          {
            name = "latex_symbols",
            option = {
              strategy = 0, -- mixed
            },
          },
        }, {
          { name = "buffer" },
        }),
        formatting = {
          format = function(entry, vim_item)
            vim_item.kind = string.format("%s %s", kind_icons[vim_item.kind], vim_item.kind)
            vim_item.menu = ({
              buffer = "[Buffer]",
              nvim_lsp = "[LSP]",
              ultisnips = "[Snip]",
              path = "[Path]",
              nvim_lua = "[Lua]",
              latex_symbols = "[LaTeX]",
            })[entry.source.name]
            return vim_item
          end,
        },
      })

      cmp.setup.cmdline("/", {
        sources = {
          { name = "buffer" },
        },
      })

      cmp.setup.cmdline(":", {
        sources = cmp.config.sources({
          { name = "path" },
        }, {
          { name = "cmdline" },
        }),
      })
    end,
  },
  {
    "folke/lazydev.nvim",
    ft = "lua",
    opts = {
      library = {
        { path = "${3rd}/luv/library", words = { "vim%.uv" } },
      },
    },
  },
  {
    "neovim/nvim-lspconfig",
    dependencies = { "hrsh7th/cmp-nvim-lsp" },
    event = { "BufReadPre", "BufNewFile" },
    config = function()
      local root_pattern = function(root_markers, single_file_support)
        return function(bufnr, on_dir)
          local project_root = vim.fs.root(bufnr, root_markers)

          if project_root then
            on_dir(project_root)
            return
          end

          if single_file_support then
            print("Single file support enabled for " .. bufnr)
            on_dir(vim.fn.getcwd())
          end
        end
      end
      local capabilities = require("cmp_nvim_lsp").default_capabilities()
      local servers = {
        "pyright",
        "clangd",
        "texlab",
        "cssls",
        "svlangserver",
        "html",
        "gopls",
      }

      for _, server in ipairs(servers) do
        vim.lsp.config(server, { capabilities = capabilities })
        vim.lsp.enable(server)
      end

      vim.lsp.config("lua_ls", {
        capabilities = capabilities,
        settings = {
          Lua = {
            diagnostics = {
              globals = { "vim", "use", "Snacks" },
            },
          },
        },
      })

      vim.lsp.config("sourcekit", {
        cmd = { "sourcekit-lsp" },
        root_dir = root_pattern({ "Package.swift", ".git" }),
        capabilities = {
          workspace = {
            didChangeWatchedFiles = {
              dynamicRegistration = true,
            },
          },
          textDocument = {
            diagnostic = {
              dynamicRegistration = true,
              relatedDocumentSupport = true,
            },
          },
        },
      })

      vim.lsp.config("denols", {
        capabilities = capabilities,
        root_dir = root_pattern({ "deno.json", "deno.jsonc" }),
      })

      vim.lsp.config("ts_ls", {
        capabilities = capabilities,
        root_dir = root_pattern({ "package-lock.json", "yarn.lock", "pnpm-lock.yaml", "bun.lockb", "bun.lock" }),
      })

      vim.lsp.enable({ "lua_ls", "sourcekit", "denols", "ts_ls" })
    end,
  },
  {
    "SirVer/ultisnips",
    lazy = true,
    cmd = { "UltiSnipsEdit", "UltiSnipsAddFiletypes" },
    init = function()
      vim.g.UltiSnipsEditSplit = "vertical"
      vim.g.UltiSnipsExpandTrigger = "<c-k>"
      vim.g.UltiSnipsJumpForwardTrigger = "<c-k>"
      vim.g.UltiSnipsJumpBackwardTrigger = "<c-j>"
    end,
  },
}
