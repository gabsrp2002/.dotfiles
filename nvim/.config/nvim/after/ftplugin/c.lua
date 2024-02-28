local function map(mode, lhs, rhs, opts)
	local options = { noremap = true }
	if opts then
		options = vim.tbl_extend("force", options, opts)
	end
	vim.api.nvim_set_keymap(mode, lhs, rhs, options)
end

vim.opt.tabstop = 2
vim.opt.shiftwidth = 2
vim.opt.softtabstop = 2

map("n", "<leader>rr", ":w <bar> :split <bar> :res 8 <bar> :terminal gcc -std=c99 -Wall -Wvla -Werror -g -lm *.c -o %:r && ./%:r<CR>")
map("n", "<leader>cc", ":w <bar> :split<CR> :res 8<CR> :terminal gcc -std=c99 -Wall -Wvla -Werror -g -lm *.c -o %:r <CR>i")
