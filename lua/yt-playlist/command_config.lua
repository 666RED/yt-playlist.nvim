local M = {}

---@type MusicModule
local music = require("yt-playlist.music")

---@type CommonModule
local common = require("yt-playlist.common")

---@type UiModule
local ui = require("yt-playlist.ui")

---@type DataModule
local local_state = require("yt-playlist.data")

local music_commands = require("yt-playlist.music_commands")

function M.setup()
	vim.api.nvim_create_user_command(music_commands.PlayPause, function()
		music.pause_or_resume(function(data)
			common.update_player_state({ paused = data.paused })
			vim.schedule(function()
				ui.update_ui()
			end)
		end)
	end, { desc = "Play or pause the music" })

	return {
		PlayPause = function()
			music.pause_or_resume(function(data)
				common.update_player_state({ paused = data.paused })
				vim.schedule(function()
					ui.update_ui()
				end)
			end)
		end,
		NextSong = function()
			music.next_song()
		end,
		PrevSong = function()
			music.prev_song()
		end,
		SkipForward = function()
			music.forward()
		end,
		SkipBack = function()
			music.rewind()
		end,
		Delete = function(line)
			music.delete_song(line)
		end,
		Download = function()
			music.download_song()
		end,
		SwitchMode = function()
			music.switch_mode(function(mode)
				vim.schedule(function()
					local_state.save_mode(mode)
				end)

				common.update_player_state({ mode = mode })

				vim.schedule(function()
					ui.update_info_buf()
				end)
			end)
		end,
		IncreaseVolume = function()
			music.increase_volume()
		end,
		DecreaseVolume = function()
			music.decrease_volume()
		end,
	}
end

return M
