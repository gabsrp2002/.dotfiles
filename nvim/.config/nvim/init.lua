require("basic")
require("keybinds")

if vim.g.neovide then
  vim.o.guifont = "JetBrainsMono Nerd Font:h18"
  local alpha = function()
    return string.format("%x", math.floor(255 * (vim.g.transparency or 0.8)))
  end
  vim.g.neovide_opacity = 0.0
  vim.g.transparency = 0.8
  vim.g.neovide_background_color = "#1e1e2e" .. alpha()

  vim.g.neovide_hide_mouse_when_typing = true

  vim.g.neovide_cursor_vfx_mode = "sonicboom"
end
