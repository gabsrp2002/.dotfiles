return {
  "nickjvandyke/opencode.nvim",
  version = "*", -- Latest stable release
  config = function()
    ---@type opencode.Opts
    vim.g.opencode_opts = {
      provider = {
        cmd = "opencode --port",
        enabled = "tmux",
        tmux = {
          options = "-h",
          focus = false,
          allow_passthrough = false,
        },
      },
    }

    vim.o.autoread = true -- Required for `opts.events.reload`

    vim.api.nvim_create_autocmd("VimLeave", {
      callback = function()
        -- Tweak to close opencode pane properly.
        if vim.fn.system("pgrep -f 'opencode.*--port'") ~= "" then
          local pane = vim.fn.system(
            "tmux list-panes -a -F '#{pane_id}:#{pane_current_command}' 2>/dev/null | grep -m1 opencode | cut -d: -f1"
          )
          if pane ~= "" then
            vim.fn.system("tmux kill-pane -t " .. pane .. " 2>/dev/null || true")
          end
        end
      end,
    })

    -- Recommended/example keymaps
    vim.keymap.set({ "n", "x" }, "<leader>oa", function()
      require("opencode").ask("@this: ", { submit = true })
    end, { desc = "Ask opencode…" })

    vim.keymap.set({ "n", "x" }, "<leader>ox", function()
      require("opencode").select()
    end, { desc = "Execute opencode action…" })

    local function toggle_opencode()
      local was_running = vim.fn.system("pgrep -f 'opencode.*--port'") ~= ""
      require("opencode").toggle()
      if was_running then
        vim.defer_fn(function()
          local pane = vim.fn.system(
            "tmux list-panes -a -F '#{pane_id}:#{pane_current_command}' 2>/dev/null | grep -m1 opencode | cut -d: -f1"
          )
          if pane ~= "" then
            vim.fn.system("tmux kill-pane -t " .. pane .. " 2>/dev/null || true")
          end
        end, 100)
      end
    end

    vim.keymap.set("n", "<leader>oo", toggle_opencode, { desc = "Toggle opencode" })

    vim.keymap.set({ "n", "x" }, "go", function()
      return require("opencode").operator("@this ")
    end, { desc = "Add range to opencode", expr = true })

    vim.keymap.set("n", "goo", function()
      return require("opencode").operator("@this ") .. "_"
    end, { desc = "Add line to opencode", expr = true })

    vim.keymap.set("n", "<leader>ou", function()
      require("opencode").command("session.half.page.up")
    end, { desc = "Scroll opencode up" })

    vim.keymap.set("n", "<leader>od", function()
      require("opencode").command("session.half.page.down")
    end, { desc = "Scroll opencode down" })
  end,
}
