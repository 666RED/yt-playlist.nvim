local M = {}

-- note: MODULES

---@type AsyncModule
local async = require("yt-playlist.async")
local controller = require("yt-playlist.controller")

---@type GlobalStateModule
local global_state = require("yt-playlist.global-state")

---@type MusicModule
local music = require("yt-playlist.music")

---@type PlaylistModule
local playlist = require("yt-playlist.playlist")

---@type CommonModule
local common = require("yt-playlist.common")

---@type UiModule
local ui = require("yt-playlist.ui")

---@type LocalStateModule
local local_state = require("yt-playlist.local_state")

---@type DbModule
local db = require("yt-playlist.db")

---@type MpvModule
local mpv = require("yt-playlist.mpv")

function M.setup()
	vim.schedule(function()
		vim.api.nvim_buf_set_keymap(global_state.state.playlist_buf, "n", "<CR>", "", {
			callback = function()
				local cursor = vim.api.nvim_win_get_cursor(0)

				-- skip when clicking on header
				if cursor[1] <= 2 then
					return
				end

				-- Songs
				if global_state.current_tab == "Songs" then
					async.sync(function()
						local file = vim.api.nvim_get_current_line()
						local state = local_state.load_state()

						-- if clicks on the same song in same playlist -> do nothing
						if
							state.current_playlist == global_state.current_playlist
							and file == global_state.player_state.title
						then
							return nil
						end

						-- enter another playlist
						if state.current_playlist ~= global_state.current_playlist then
							local_state.save_state({ current_playlist = global_state.current_playlist })
							async.wait(mpv.clear_playlist())
							async.wait(controller.update_files())
						end

						async.wait(music.play_song(file))

						local player_state = async.wait(music.get_current_song())

						common.update_player_state(player_state)

						async.wait(ui.update_ui())
					end)()
				else
					-- Playlists
					async.sync(function()
						local current_playlist = vim.api.nvim_get_current_line()

						local songs = {}

						if current_playlist == "All" then
							songs = db.load_songs()
						else
							songs = playlist.get_playlist_songs(current_playlist)
						end

						-- get songs from db.json
						global_state.files = songs

						global_state.current_playlist = current_playlist
						global_state.current_tab = "Songs"

						vim.api.nvim_win_set_config(global_state.state.playlist_win, {
							title = current_playlist,
						})

						async.wait(ui.update_playlist_buf())
					end)()
				end
			end,
		})

		local actions = require("yt-playlist.command_config").setup()

		local mappings = {
			p = actions.PlayPause,
			k = actions.PrevSong,
			j = actions.NextSong,
			h = actions.SkipBack,
			l = actions.SkipForward,
			d = actions.Download,
			m = actions.SwitchMode,
			t = actions.SwitchTab,
			["-"] = actions.DecreaseVolume,
			["="] = actions.IncreaseVolume,
			a = actions.AddNew,
		}

		local buf = global_state.state.playlist_buf

		if not buf then
			return
		end

		vim.api.nvim_buf_set_keymap(buf, "n", "<M-x>", "", {
			callback = function()
				async.sync(function()
					local current_line = vim.api.nvim_get_current_line()

					async.wait(actions.Delete(current_line))
				end)()
			end,
		})

		local keymap = nil

		for key, fn in pairs(mappings) do
			if key == "-" or key == "=" then
				keymap = key
			else
				keymap = "<M-" .. key .. ">"
			end

			vim.api.nvim_buf_set_keymap(buf, "n", keymap, "", {
				callback = function()
					local thunk = fn()

					if type(thunk) == "function" then
						thunk()
					end
				end,
			})
		end
	end)
end

return M
