local M = {}

-- note: MODULES

---@type GlobalStateModule
local global_state = require("yt-playlist.global-state")

---@type StateModule
local state = require("yt-playlist.state")

---@type MpvModule
local mpv = require("yt-playlist.mpv")

---@type MusicModule
local music = require("yt-playlist.music")

---@type TimerModule
local timer = require("yt-playlist.timer")

---@type UiModule
local ui = require("yt-playlist.ui")

---@type CommonModule
local common = require("yt-playlist.common")

function M.setup()
	vim.api.nvim_create_user_command("YtPlayList", function()
		if global_state.state.is_open then
			state.hide_playlist()
			return
		end

		require("yt-playlist.command_config").setup()

		music.setup()

		state.show_playlist()

		mpv.ensure_mpv(function(result)
			if result then
				vim.print("Connected to mpv")

				music.sync_mpv_ids()

				ui.get_current_song_and_update_ui()
			end
		end)

		local function play_song()
			local file = vim.api.nvim_get_current_line()

			if file == global_state.player_state.title then
				return
			end

			music.play_song(file, function(song)
				common.update_player_state(song)

				vim.schedule(function()
					ui.update_ui()
				end)
			end)
		end

		-- Enter song
		vim.api.nvim_buf_set_keymap(global_state.state.playlist_buf, "n", "<CR>", "", {
			callback = play_song,
		})

		timer.start_position_timer(ui.get_current_song_and_update_ui, ui.update_info_buf)

		timer.start_fs_event_timer(ui.get_current_song_and_update_ui)

		timer.start_mpv_listener()
	end, {})
end

return M
