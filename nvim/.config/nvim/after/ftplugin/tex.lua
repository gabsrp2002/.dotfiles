local function run_latexmk(args, auto_close)
  vim.cmd("write")
  local file = vim.fn.shellescape(vim.fn.expand("%"))
  vim.cmd("split | resize 8 | terminal latexmk " .. args .. " " .. file)
  if auto_close then
    local term_buf = vim.api.nvim_get_current_buf()
    vim.api.nvim_create_autocmd("TermClose", {
      buffer = term_buf,
      once = true,
      callback = function(ev)
        if vim.v.event.status == 0 and vim.api.nvim_buf_is_valid(ev.buf) then
          vim.schedule(function()
            if vim.api.nvim_buf_is_valid(ev.buf) then
              vim.api.nvim_buf_delete(ev.buf, { force = true })
            end
          end)
        end
      end,
    })
  end
end

vim.keymap.set("n", "<leader>pp", function()
  run_latexmk("-pdf -pv -bibtex", false)
end, { buffer = true, silent = true, desc = "LaTeX compile and preview" })

vim.keymap.set("n", "<leader>pl", function()
  run_latexmk("-pdf -pvc -bibtex", false)
end, { buffer = true, silent = true, desc = "LaTeX continuous preview" })

vim.keymap.set("n", "<leader>cc", function()
  run_latexmk("-pdf -bibtex", true)
end, { buffer = true, silent = true, desc = "LaTeX compile" })
