local M = {}

-- note: MODULES

---@type MusicModule
local music = require("yt-playlist.music")

---@type CommonModule
local common = require("yt-playlist.common")

---@type UiModule
local ui = require("yt-playlist.ui")

---@type AsyncModule
local async = require("yt-playlist.async")

---@type DataModule
local local_state = require("yt-playlist.data")

function M.setup()
	vim.api.nvim_create_user_command("PlayPause", function()
		async.sync(function()
			local paused = async.wait(music.pause_or_resume())
			common.update_player_state({ paused = paused })
			async.wait(ui.update_ui())
		end)()
	end, { desc = "Play or pause the music" })

	vim.api.nvim_create_user_command("DecreaseVolume", function(opts)
		local volume = opts.args

		music.decrease_volume(tonumber(volume))()
	end, { desc = "Decrease volume (5 by default)", nargs = "*" })

	vim.api.nvim_create_user_command("IncreaseVolume", function(opts)
		local volume = opts.args

		music.increase_volume(tonumber(volume))()
	end, { desc = "Increase volume (5 by default)", nargs = "*" })

	vim.api.nvim_create_user_command("NextSong", function()
		music.next_song()()
	end, { desc = "Play next song" })

	vim.api.nvim_create_user_command("PrevSong", function()
		music.prev_song()()
	end, { desc = "Play previous song" })

	return {
		PlayPause = function()
			return async.sync(function()
				local paused = async.wait(music.pause_or_resume())
				common.update_player_state({ paused = paused })
				async.wait(ui.update_ui())
			end)
		end,
		NextSong = function()
			return music.next_song()
		end,
		PrevSong = function()
			return music.prev_song()
		end,
		SkipForward = function()
			return music.forward()
		end,
		SkipBack = function()
			return music.rewind()
		end,
		Delete = function(line)
			return music.delete_song(line)
		end,
		Download = function()
			return music.download_song()
		end,
		SwitchMode = function()
			return async.sync(function()
				local new_mode = async.wait(music.switch_mode())

				local_state.save_state({ mode = new_mode })

				common.update_player_state({ mode = new_mode })

				ui.update_info_buf()
			end)
		end,
		IncreaseVolume = function()
			return music.increase_volume()
		end,
		DecreaseVolume = function()
			return music.decrease_volume()
		end,
		SwitchPlaylist = function()
			vim.print("switch playlist")
		end,
		AddPlaylist = function()
			return local_state.add_playlist()
		end,
	}
end

return M
