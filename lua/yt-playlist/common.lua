---@class CommonModule
---@field update_player_state fun(data: PlayerState): nil
---@field get_current_song_and_update_ui fun(): AsyncThunk
---@field reset_player_state fun(): nil
local M = {}

-- note: MODULE

---@type GlobalStateModule
local global_state = require("yt-playlist.global-state")

---@type UtilModule
local util = require("yt-playlist.util")

---@type AsyncModule
local async = require("yt-playlist.async")

---@type MusicModule
local music = require("yt-playlist.music")

---@type UiModule
local ui = require("yt-playlist.ui")

function M.update_player_state(info)
	for key, value in pairs(info) do
		if not key then
			global_state.player_state[key] = nil
		else
			if key == "title" then
				global_state.player_state.title = util.remove_extension(value)
			else
				global_state.player_state[key] = value
			end
		end
	end
end

function M.get_current_song_and_update_ui()
	return async.sync(function()
		local info = async.wait(music.get_current_song())

		M.update_player_state(info)

		async.wait(ui.update_ui())

		vim.schedule(function()
			vim.bo[global_state.state.info_buf].modifiable = false
		end)
	end)
end

function M.reset_player_state()
	global_state.player_state = {
		duration = nil,
		mode = nil,
		paused = nil,
		position = nil,
		title = nil,
		volume = nil,
	}
end

return M
