local function map(mode, lhs, rhs, opts)
	local options = { noremap = true }
	if opts then
		options = vim.tbl_extend("force", options, opts)
	end
	vim.api.nvim_set_keymap(mode, lhs, rhs, options)
end

-- Compile and preview tex file
map("n", "<leader>pp", ":w <CR> :split<CR> :res 8<CR> :terminal latexmk -pdf -pv -bibtex %<CR>")
map("n", "<leader>pl", ":w <CR> :split<CR> :res 8<CR> :terminal latexmk -pdf -pvc -bibtex %<CR><ESC>:q<CR>")
map("n", "<leader>cc", ":w <CR> :split<CR> :res 8<CR> :terminal latexmk -pdf -bibtex %<CR><ESC>:q<CR>")
