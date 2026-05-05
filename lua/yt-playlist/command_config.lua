local M = {}

---@type MusicModule
local music = require("yt-playlist.music")

---@type StateModule
local state = require("yt-playlist.state")

---@type UiModule
local ui = require("yt-playlist.ui")

---@type DataModule
local local_state = require("yt-playlist.data")

local music_commands = require("yt-playlist.music_commands")

function M.setup()
	vim.api.nvim_create_user_command(music_commands.PlayPause, function()
		music.pause_or_resume(function(data)
			state.update_player_state({ paused = data.paused })
			vim.schedule(function()
				ui.update_ui()
			end)
		end)
	end, { desc = "Play or pause the music" })

	return {
		PlayPause = function()
			music.pause_or_resume(function(data)
				state.update_player_state({ paused = data.paused })
				vim.schedule(function()
					ui.update_ui()
				end)
			end)
		end,
		NextSong = function()
			music.next_song(function(data)
				state.update_player_state(vim.tbl_extend("force", data, { paused = false }))
				vim.schedule(function()
					ui.update_ui()
				end)
			end)
		end,
		PrevSong = function()
			music.prev_song(function(data)
				state.update_player_state(vim.tbl_extend("force", data, { paused = false }))
				vim.schedule(function()
					ui.update_ui()
				end)
			end)
		end,
		SkipForward = function()
			music.forward(function(data)
				state.update_player_state(data)
				vim.schedule(function()
					ui.update_ui()
				end)
			end)
		end,
		SkipBack = function()
			music.rewind(function(data)
				state.update_player_state(data)
				vim.schedule(function()
					ui.update_ui()
				end)
			end)
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

				state.update_player_state({ mode = mode })

				vim.schedule(function()
					ui.update_info_buf()
				end)
			end)
		end,
		IncreaseVolume = function()
			music.increase_volume(function(volume)
				state.update_player_state(volume)
				vim.schedule(function()
					ui.update_info_buf()
				end)
			end)
		end,
		DecreaseVolume = function()
			music.decrease_volume(function(volume)
				state.update_player_state(volume)
				vim.schedule(function()
					ui.update_info_buf()
				end)
			end)
		end,
	}
end

return M
