-- todo: add rename feature
-- todo: remember to update info buf ui after deleting song / pause song / play next song / play previous song
-- todo: modify render playlist buf feature -> update ui after adding / removing song
local M = {}

---@type Song_Info

-- note: MODULES

---@type StateModule
local global_state = require("yt-playlist.state")

---@type MpvModule
local mpv = require("yt-playlist.mpv")

---@type MusicModule
local music = require("yt-playlist.music")

local constants = require("yt-playlist.constants")

function M.setup()
	-- todo: applied this on play list buffer
	require("yt-playlist.command_config").setup()

	vim.api.nvim_create_user_command("YtPlayList", function()
		music.setup()

		global_state.toggle_ui()

		mpv.ensure_mpv(function(result)
			if result then
				vim.print("Connected to mpv")

				global_state.get_current_song_and_update_ui()
			end
		end)

		-- Enter song
		vim.api.nvim_buf_set_keymap(global_state.state.playlist_buf, "n", "<CR>", "", {
			callback = function()
				local file = vim.api.nvim_get_current_line()

				music.play_song(file, function(song)
					if song.duration and song.position and song.title then
						global_state.player_state.duration = song.duration
						global_state.player_state.position = song.position
						global_state.player_state.title = song.title
						global_state.player_state.paused = song.paused

						vim.schedule(function()
							global_state.update_info_buf()
						end)
					end
				end)
			end,
		})

		global_state.start_position_timer()

		-- handle add && remove song from the folder to update ui
		vim.loop.new_fs_event():start(
			vim.fn.expand(constants.MUSIC_PATH),
			{},
			vim.schedule_wrap(function(err, _, _)
				if err then
					return
				end

				-- cancel previous pending call
				if global_state.timer.fs_event_timer then
					global_state.timer.fs_event_timer:stop()
					global_state.timer.fs_event_timer:close()
					global_state.timer.fs_event_timer = nil
				end

				-- only fire after 500ms of no events
				global_state.timer.fs_event_timer = vim.loop.new_timer()
				global_state.timer.fs_event_timer:start(
					500,
					0,
					vim.schedule_wrap(function()
						global_state.timer.fs_event_timer:stop()
						global_state.timer.fs_event_timer:close()
						global_state.timer.fs_event_timer = nil

						-- update ui
						global_state.render()
					end)
				)
			end)
		)
	end, {})
end

return M
