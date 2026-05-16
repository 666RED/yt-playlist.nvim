---@type GlobalStateModule
local global_state = require("yt-playlist.global-state")

---@type UiModule
local ui = require("yt-playlist.ui")

vim.api.nvim_create_autocmd("QuitPre", {
	buffer = global_state.state.playlist_buf,
	callback = function()
		if global_state.state.info_buf ~= nil and vim.api.nvim_win_is_valid(global_state.state.info_win) then
			ui.hide_playlist()
			return
		end
	end,
})
