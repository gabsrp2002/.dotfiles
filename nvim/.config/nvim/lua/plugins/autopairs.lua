return {
    "windwp/nvim-autopairs",
    dependencies = { "hrsh7th/nvim-cmp" },
    event = "InsertEnter",
    config = function()
      local Rule = require("nvim-autopairs.rule")
      local npairs = require("nvim-autopairs")
      local cond = require("nvim-autopairs.conds")
      local ts_conds = require("nvim-autopairs.ts-conds")
      npairs.setup({
        disable_filetype = { "TelescopePrompt", "vim", "alpha", "netrw", "oil" },
        ignored_next_char = "[%w%.]",
        check_ts = true,
        ts_config = {
          lua = { "string", "comment" },
          python = { "string", "comment" },
          javascript = { "template_string" },
        },
      })

      -- Adds pair for tex file
      local textypes = { "tex", "latex", "plaintex" }
      npairs.add_rules({
        Rule("$", "$", textypes)
          -- add a pair if it's not already in an inline_formula (example 2)
          :with_pair(
            ts_conds.is_not_ts_node({ "inline_formula" })
          )
          -- move right when repeating $
          :with_move(cond.done())
          -- disable adding a newline when you press <cr>
          :with_cr(cond.none()),
        Rule("\\[", "\\]", textypes):with_cr(cond.none()):with_pair(ts_conds.is_not_ts_node({ "comment" })),
        Rule("\\(", "\\)", textypes):with_cr(cond.none()):with_pair(ts_conds.is_not_ts_node({ "comment" })),
        npairs.get_rule("{"):replace_endpair(function(opts)
          -- Checks if current filetype is a tex one
          local is_tex = false
          for _, value in pairs(textypes) do
            if value == vim.bo.filetype then
              is_tex = true
              break
            end
          end

          if not is_tex then
            return "}"
          end

          if string.find(opts.text, "\\begin%{$") then
            return ""
          end

          return "}"
        end),
        Rule("\\begin%{[^{]*}$", "", textypes)
          :replace_endpair(function(opts)
            local env_name = string.match(opts.text, "%{[^{]*}$")

            return "\\end" .. env_name
          end)
          :use_regex(cond.done())
          :with_cr(cond.done())
          :with_pair(ts_conds.is_not_ts_node({ "comment" })),
      })

      -- Make <CR> works fine with cmp
      local cmp_autopairs = require("nvim-autopairs.completion.cmp")
      local cmp = require("cmp")
      cmp.event:on("confirm_done", cmp_autopairs.on_confirm_done())
    end,
  }
