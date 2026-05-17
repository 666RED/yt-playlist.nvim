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

---@type LocalStateModule
local local_state = require("yt-playlist.local_state")

---@type PlaylistModule
local playlist = require("yt-playlist.playlist")

---@type GlobalStateModule
local global_state = require("yt-playlist.global-state")

---@type DbModule
local db = require("yt-playlist.db")

---@type ControllerModule
local controller = require("yt-playlist.controller")

---@type MpvModule
local mpv = require("yt-playlist.mpv")

local snacks = require("snacks")

-- note: LOCAL FUNCTIONS

---@param line string
---@return AsyncThunk<nil>
local function remove_song(line)
	-- remove song in Music directory
	if global_state.current_playlist == "All" then
		return async.sync(function()
			local select = async.wrap(vim.ui.select)

			local result = async.wait(select({ "No", "Yes" }, { prompt = "Delete " .. line .. "?" }))

			if not result or result == "No" then
				vim.notify("Cancelled")
				return
			end

			local song = music.get_db_song_file(line)

			if not song then
				vim.notify("Song not found", vim.log.levels.WARN)
				return
			end

			db.delete_song(song.id) -- 1. remove song from db.json

			-- if deleted song is in current playlist
			local current_songs = global_state.files

			for _, s in ipairs(current_songs) do
				if s.filename == line then
					async.wait(music.delete_song_from_mpv(s)) -- 2. remove song from mpv (if it is playing in mpv playlist)
					break
				end
			end

			async.wait(music.delete_song_from_directory(song)) -- 3. remove song in Music directory
			playlist.remove_song_in_all_playlists(song.id) -- 4. remove song in all playlists
			-- note: do not need to update ui since fs_event will handle that
		end)
	else -- remove song in playlist
		return async.sync(function()
			local select = async.wrap(vim.ui.select)

			local result = async.wait(select({ "No", "Yes" }, { prompt = "Remove " .. line .. " from playlist?" }))

			if not result or result == "No" then
				vim.notify("Cancelled")
				return
			end

			local song = music.get_db_song_file(line)

			if not song then
				vim.notify("Song not found", vim.log.levels.WARN)
				return
			end

			playlist.remove_song_from_playlist(global_state.current_playlist, song.id) -- 1. remove song from playlist

			local local_current_playlist = local_state.load_state().current_playlist

			if local_current_playlist and local_current_playlist == global_state.current_playlist then
				async.wait(music.delete_song_from_mpv(song)) -- 2. remove song from mpv (if it is playing in mpv playlist)
			end

			async.sync(function()
				async.wait(controller.update_files()) -- 3. update global_state.files
				playlist.set_playlists()

				async.wait(common.get_current_song_and_update_ui()) -- 4. update ui
			end)()

			vim.schedule(function()
				vim.notify(line .. " removed from playlist") -- 5. display success message
			end)
		end)
	end
end

---@param name string
---@return AsyncThunk<nil>
local function remove_playlist(name)
	return async.sync(function()
		-- note:
		-- 1. conformation prompt
		-- 2. remove playlist in playlists.json
		-- 3. If it is currently loaded playlist (local_state.current_playlist)
		--  - i. switch current playlist to All
		--  - ii. clear mpv playlist
		-- 4. update global_state
		-- 5. update ui

		local select = async.wrap(vim.ui.select)

		local result = async.wait(select({ "No", "Yes" }, { prompt = "Remove playlist (" .. name .. ")?" }))

		if not result or result == "No" then
			vim.notify("Cancelled")
			return
		end

		playlist.remove_playlist(name)

		playlist.set_playlists() -- udpate global_state.playlists

		-- if deleted playlist is global_state.curernt_playlist
		if global_state.current_playlist == name then
			local local_current_playlist = local_state.load_state().current_playlist

			-- if mpv playlist == local current playlist -> clear mpv playlist
			if local_current_playlist and local_current_playlist == global_state.current_playlist then
				async.wait(mpv.clear_playlist())
			end

			global_state.current_playlist = "All" -- switch to All

			async.wait(controller.update_files())
		end

		async.wait(ui.update_ui())

		vim.schedule(function()
			vim.notify("Removed " .. name)
		end)
	end)
end

-- note: SETUP
function M.setup()
	vim.schedule(function()
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

		vim.api.nvim_create_user_command("SetVolume", function(opts)
			local volume = opts.args

			music.set_volume(tonumber(volume))()
		end, { desc = "Set volume", nargs = "*" })
	end)

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
		DeletePlaylist = function(name)
			return async.sync(function()
				if name == "All" then
					vim.notify("All playlist cannot be removed", vim.log.levels.WARN)
					return
				end

				async.wait(remove_playlist(name))
			end)
		end,
		DeleteSong = function(line)
			return remove_song(line)
		end,
		Download = function()
			return controller.download_song()
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
		SwitchTab = function()
			return ui.switch_tab()
		end,
		AddNew = function()
			local current_playlist = global_state.current_playlist
			local current_tab = global_state.current_tab

			if current_tab == "Playlists" then -- add new playlist
				return async.sync(function()
					local is_name_unique = false
					local playlist_name = ""

					while not is_name_unique do
						local name_input = async.wrap(vim.ui.input)
						local name = async.wait(name_input({ prompt = "Playlist name: " }))

						if not name or name == "" then
							vim.notify("Cancelled")
							return
						elseif playlist.is_repeated_name(vim.trim(name)) then
							vim.notify('Playlist "' .. name .. '" existed', vim.log.levels.WARN)
						else
							playlist_name = name
							is_name_unique = true
						end
					end

					async.wait(playlist.create_playlist(playlist_name))

					vim.notify("Created playlist: " .. playlist_name)

					playlist.set_playlists()
					ui.update_playlist_buf()()
				end)
			else -- add new song (skip for "All")
				if current_playlist == "All" then
					vim.schedule(function()
						vim.notify("Use [A-d] to download song instead", vim.log.levels.WARN)
					end)
					return -- todo: handle here
				else
					snacks.picker.pick({
						title = "Add song to playlist",
						show_empty = true,
						finder = function()
							local songs = playlist.get_not_added_playlist_songs(global_state.current_playlist)
							local items = {}

							for _, song in ipairs(songs) do
								table.insert(
									items,
									vim.tbl_extend("force", song, {
										text = song.filename,
									})
								)
							end

							return items
						end,
						format = function(item)
							local ret = {}
							ret[#ret + 1] = { item.filename }

							return ret
						end,
						layout = {
							layout = {
								backdrop = false,
								width = 0.7,
								min_width = 70,
								height = 0.7,
								border = "none",
								box = "vertical",
								{
									box = "vertical",
									border = true,
									title = "{title} {live} {flags}",
									title_pos = "center",
									{ win = "input", height = 1, border = "bottom" },
									{ win = "list", border = "none" },
								},
							},
						},
						confirm = function(picker, item)
							-- note:
							-- 1. add song to playlist
							-- 2. update global_state.files
							-- 3. update playlist_buf ui

							if not item then
								return
							end

							async.wait(common.add_song_to_playlist(item.id))

							picker:close()
							vim.schedule(function()
								vim.api.nvim_set_current_win(global_state.state.playlist_win)
							end)
						end,
					})
				end
			end
		end,
	}
end

return M
