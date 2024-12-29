return {
  "nvim-lualine/lualine.nvim",
  dependencies = { "kyazdani42/nvim-web-devicons", opt = true },
  config = function()
    local lualine = require("lualine")

    local colors = require("catppuccin.palettes").get_palette("mocha")
    local conditions = {
      buffer_not_empty = function()
        return vim.fn.empty(vim.fn.expand("%:t")) ~= 1
      end,
      hide_in_width = function()
        return vim.fn.winwidth(0) > 80
      end,
      check_git_workspace = function()
        local filepath = vim.fn.expand("%:p:h")
        local gitdir = vim.fn.finddir(".git", filepath .. ";")
        return gitdir and #gitdir > 0 and #gitdir < #filepath
      end,
      start_up_dashboard = function()
        local buf_ft = vim.api.nvim_buf_get_option(0, "filetype")
        return buf_ft ~= "snacks_dashboard"
      end,
    }

    local mode_color = {
      n = colors.red,
      i = colors.green,
      v = colors.blue,
      [""] = colors.blue,
      V = colors.blue,
      c = colors.pink,
      no = colors.red,
      s = colors.yellow,
      S = colors.yellow,
      [""] = colors.yellow,
      ic = colors.yellow,
      R = colors.teal,
      Rv = colors.teal,
      cv = colors.red,
      ce = colors.red,
      r = colors.sky,
      rm = colors.sky,
      ["r?"] = colors.sky,
      ["!"] = colors.red,
      t = colors.blue,
    }
    local mode_name = {
      n = "NORMAL",
      i = "INSERT",
      v = "VIRTUAL",
      [""] = "VIRTUAL",
      V = "VIRTUAL",
      c = "COMMAND",
      s = "SELECT",
      S = "SELECT",
      [""] = "SELECT",
      ic = "INSERT",
      R = "REPLACE",
      Rv = "REPLACE",
      ["!"] = "SHELL",
      t = "TERMINAL",
    }

    -- Config
    local catppuccin_mocha_theme = require("lualine.themes.catppuccin-mocha")
    catppuccin_mocha_theme.normal.c.bg = nil
    catppuccin_mocha_theme.inactive.c.bg = nil
    local config = {
      options = {
        -- Disable sections and component separators
        component_separators = "",
        section_separators = "",
        theme = catppuccin_mocha_theme,
        globalstatus = true,
      },
      sections = {
        -- these are to remove the defaults
        lualine_a = {},
        lualine_b = {},
        lualine_y = {},
        lualine_z = {},
        -- These will be filled later
        lualine_c = {},
        lualine_x = {},
      },
      inactive_sections = {
        -- these are to remove the defaults
        lualine_a = {},
        lualine_b = {},
        lualine_y = {},
        lualine_z = {},
        lualine_c = {},
        lualine_x = {},
      },
    }

    -- Inserts a component in lualine_c at left section
    local function ins_left(component)
      table.insert(config.sections.lualine_c, component)
    end

    -- Inserts a component in lualine_x ot right section
    local function ins_right(component)
      table.insert(config.sections.lualine_x, component)
    end

    ins_left({
      -- mode component
      function()
        -- auto change color according to neovims mode
        vim.api.nvim_command("hi! LualineMode guifg=#000000 guibg=" .. mode_color[vim.fn.mode()])
        return mode_name[vim.fn.mode()]
      end,
      color = "LualineMode",
      padding = { right = 1, left = 1 },
      cond = conditions.start_up_dashboard
    })

    -- ins_left({
    --   -- filesize component
    --   "filesize",
    --   cond = conditions.buffer_not_empty,
    --   padding = { left = 1 },
    -- })

    -- ins_left({
    --   function()
    --     return vim.fn.expand("%")
    --   end,
    --   cond = conditions.buffer_not_empty,
    --   color = { fg = colors.pink, gui = "bold" },
    --   padding = { left = 1 },
    -- })

    -- ins_left({ "location", padding = { left = 1 } })

    ins_left({
      "progress",
      color = { fg = colors.text, gui = "bold" },
      padding = { left = 1 },
      cond = conditions.start_up_dashboard
    })

    ins_left({
      function()
        return vim.t.maximized and "  " or ""
      end,
    })

    ins_left({
      "diagnostics",
      sources = { "nvim_diagnostic" },
      symbols = { Error = " ", Warn = " ", Hint = " ", Info = " " },
      diagnostics_color = {
        color_error = { fg = colors.red },
        color_warn = { fg = colors.yellow },
        color_info = { fg = colors.sky },
      },
      padding = { left = 1 },
    })

    -- Insert mid section. You can make any number of sections in neovim :)
    -- for lualine it's any number greater then 2
    ins_left({
      function()
        return "%="
      end,
      padding = { right = 1 },
    })

    ins_left({
      -- Lsp server name .
      function()
        local msg = "No Active Lsp"
        local buf_ft = vim.api.nvim_buf_get_option(0, "filetype")
        local clients = vim.lsp.get_clients()
        if next(clients) == nil then
          return msg
        end

        -- Get active clients for current buffer
        local function is_in(array, element)
          for _, item in ipairs(array) do
            if item == element then
              return true
            end
          end

          return false
        end
        local curr_buf_clients = {}
        for _, client in ipairs(clients) do
          local filetypes = client.config.filetypes
          if filetypes and vim.fn.index(filetypes, buf_ft) ~= -1 then
            if not is_in(curr_buf_clients, client.name) then
              table.insert(curr_buf_clients, client.name)
            end
          end
        end
        if next(curr_buf_clients) == nil then
          return msg
        end
        return "[" .. table.concat(curr_buf_clients, " ") .. "]"
      end,
      icon = " LSP:",
      color = { fg = "#ffffff", gui = "bold" },
      cond = conditions.start_up_dashboard
    })

    -- Add components to right sections
    -- ins_right({
    --   "o:encoding",
    --   fmt = string.upper,
    --   cond = conditions.hide_in_width,
    --   color = { fg = colors.green, gui = "bold" },
    -- })

    -- ins_right({
    --   "fileformat",
    --   fmt = string.upper,
    --   icons_enabled = false,
    --   color = { fg = colors.green, gui = "bold" },
    -- })

    ins_right({
      "branch",
      icon = "",
      color = { fg = colors.teal, gui = "bold" },
    })

    ins_right({
      "diff",
      -- Is it me or the symbol for modified us really weird
      symbols = { added = " ", modified = " ", removed = " " },
      diff_color = {
        added = { fg = colors.green },
        modified = { fg = colors.blue },
        removed = { fg = colors.red },
      },
      cond = conditions.hide_in_width,
    })

    ins_right({
      function()
        -- auto change color according to neovims mode
        vim.api.nvim_command("hi! LualineEndMode guifg=" .. mode_color[vim.fn.mode()])
        return "▊"
      end,
      color = "LualineEndMode",
      padding = { left = 0 },
      cond = conditions.start_up_dashboard
    })

    -- Now don't forget to initialize lualine
    lualine.setup(config)
  end,
}
