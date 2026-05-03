local M = {}

---@type MusicModule
local music = require("yt-playlist.music")

function M.setup()
	local music_command = require("yt-playlist.music_commands")

	vim.api.nvim_create_user_command(music_command.PlayPause, function()
		vim.print("play pause")
	end, { desc = "Play or pause the music" })

	vim.api.nvim_create_user_command(music_command.NextSong, function()
		vim.print("next song")
	end, { desc = "Play next song" })

	vim.api.nvim_create_user_command(music_command.PrevSong, function()
		vim.print("previous song")
	end, { desc = "Play previous song" })

	vim.api.nvim_create_user_command(music_command.SkipForward, function()
		vim.print("skip forward 10 seconds")
	end, { desc = "Skip forward 10 seconds" })

	vim.api.nvim_create_user_command(music_command.SkipBack, function()
		vim.print("skip back 10 seconds")
	end, { desc = "Skip back 10 seconds" })

	vim.api.nvim_create_user_command(music_command.Shuffle, function()
		vim.print("shuffle the play list")
	end, { desc = "Shuffle play list" })

	vim.api.nvim_create_user_command(music_command.Download, function()
		music.download_song()
	end, { desc = "Download youtube music" })

	vim.api.nvim_create_user_command(music_command.Delete, function(attr)
		music.delete_song(attr.args, function() end)
	end, { desc = "Delete music", nargs = "?" }) -- 0 / 1 argument

	return {
		-- todo: here
		PlayPause = function()
			-- music.play_pause()
		end,
		NextSong = function()
			music.next_song()
		end,
		PrevSong = function()
			music.prev_song()
		end,
		SkipForward = function()
			-- music.skip_forward()
		end,
		SkipBack = function()
			-- music.skip_back()
		end,
		Shuffle = function()
			-- music.shuffle()
		end,
		Delete = function(line, cb)
			music.delete_song(line, cb)
		end,
		Download = function()
			music.download_song()
		end,
	}

	-- todo: may add here
	-- vim.api.nvim_create_user_command(music_command.Quit, function()
	-- 	vim.print("quit music player")
	-- end, { desc = "Quit music player" })
end

return M
