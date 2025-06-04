return {
  "echasnovski/mini.files",
  version = "*",
  lazy = true,
  opts = {
    content = {
      filter = function(entry)
        return entry.name ~= '.DS_Store' and entry.name ~= '.git' and entry.name ~= '.direnv'
      end,
      sort = function(entries)
        local all_paths = table.concat(
          vim.tbl_map(function(entry)
            return entry.path
          end, entries),
          '\n'
        )
        local output_lines = {}
        local job_id = vim.fn.jobstart({ 'git', 'check-ignore', '--stdin' }, {
          stdout_buffered = true,
          on_stdout = function(_, data)
            output_lines = data
          end,
        })

        -- command failed to run
        if job_id < 1 then
          return entries
        end

        -- send paths via STDIN
        vim.fn.chansend(job_id, all_paths)
        vim.fn.chanclose(job_id, 'stdin')
        vim.fn.jobwait({ job_id })
        return require('mini.files').default_sort(vim.tbl_filter(function(entry)
          return not vim.tbl_contains(output_lines, entry.path)
        end, entries))
      end,
    },
    mappings = {
      close = "q",
      go_in = "",
      go_in_plus = "<cr>",
      go_out = "",
      go_out_plus = "-",
      reset = "<bs>",
      reveal_cwd = "@",
      show_help = "g?",
      synchronize = "=",
      trim_left = "<",
      trim_right = ">",
    },
  },
  keys = {
    {
      "-",
      function()
        require("mini.files").open(vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0), ":p:h"), false)
      end,
      { noremap = true, silent = true },
    },
  },
  init = function()
    vim.api.nvim_create_autocmd("BufEnter", {
      group = vim.api.nvim_create_augroup("MiniFilesStartDirectory", { clear = true }),
      desc = "Start Mini Files with directory",
      once = true,
      callback = function()
        if package.loaded["mini.files"] then
          return
        else
          if vim.fn.argc() ~= 1 then
            return
          end

          local dir_name = vim.fn.argv(0)
          if type(dir_name) ~= "string" then
            return
          end

          local stats = vim.uv.fs_stat(dir_name)
          if stats and stats.type == "directory" then
            require("mini.files").open(vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0), ":p:h"), false)
          end
        end
      end,
    })
  end,
}
