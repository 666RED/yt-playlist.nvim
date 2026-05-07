---@class CommonModule
---@field update_player_state fun(data: PlayerState): nil
local M = {}

-- note: MODULE

---@type GlobalStateModule
local global_state = require("yt-playlist.global-state")

function M.update_player_state(info)
	-- check if no song is in the playlist
	vim.schedule(function()
		local current_line = vim.api.nvim_get_current_line()

		if current_line == "" then
			global_state.player_state.title = nil
			global_state.player_state.position = nil
			global_state.player_state.duration = nil
			global_state.player_state.paused = nil
			return
		end
	end)

	if info.title then
		global_state.player_state.title = info.title
	end

	if info.position then
		global_state.player_state.position = info.position
	end

	if info.paused ~= nil then
		global_state.player_state.paused = info.paused
	end

	if info.duration then
		global_state.player_state.duration = info.duration
	end

	if info.mode then
		global_state.player_state.mode = info.mode
	end

	if info.volume then
		global_state.player_state.volume = info.volume
	end
end

return M
