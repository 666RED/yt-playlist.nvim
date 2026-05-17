---@class CommonModule
---@field update_player_state fun(data: PlayerState): nil
---@field get_current_song_and_update_ui fun(): AsyncThunk<nil>
---@field reset_player_state fun(): nil
---@field add_song_to_playlist fun(song_id: string): AsyncThunk<nil>
local M = {}

-- note: MODULE

---@type GlobalStateModule
local global_state = require("yt-playlist.global-state")

---@type UtilModule
local util = require("yt-playlist.util")

---@type AsyncModule
local async = require("yt-playlist.async")

---@type LocalStateModule
local local_state = require("yt-playlist.local_state")

-- note: EXPORT FUNCTIONS
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
	local music = require("yt-playlist.music")
	local ui = require("yt-playlist.ui")

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

function M.add_song_to_playlist(song_id)
	local playlist = require("yt-playlist.playlist")
	local controller = require("yt-playlist.controller")
	local ui = require("yt-playlist.ui")

	return async.sync(function()
		playlist.add_song(global_state.current_playlist, song_id)

		local local_current_playlist = local_state.load_state().current_playlist

		-- add song to mpv playlist if it is current playlist
		if local_current_playlist == global_state.current_playlist then
			async.wait(controller.insert_new_song_to_mpv(global_state.files))
		end

		global_state.files = playlist.get_playlist_songs(global_state.current_playlist)
		playlist.set_playlists()
		async.wait(ui.update_playlist_buf())
	end)
end

return M
