---@class ControllerModule
---@field get_all_files fun(): Db_Song[]
---@field update_files fun(): AsyncThunk<nil>
---@field sync_local_playlists fun(): AsyncThunk<nil>
---@field sync_playlist fun(): AsyncThunk<nil>
---@field insert_new_song_to_mpv fun(original_files: Db_Song[]): AsyncThunk<Db_Song>
local M = {}

-- note: MODULES

---@type AsyncModule
local async = require("yt-playlist.async")
local local_state = require("yt-playlist.local_state")

---@type GlobalStateModule
local global_state = require("yt-playlist.global-state")

---@type UtilModule
local util = require("yt-playlist.util")

---@type DbModule
local db = require("yt-playlist.db")

---@type ConstantsModule
local constants = require("yt-playlist.constants")

---@type PlaylistModule
local playlist = require("yt-playlist.playlist")

---@type MpvModule
local mpv = require("yt-playlist.mpv")

-- note: EXPORT FUNCTIONS
function M.get_all_files()
	---@type string[]
	local all_files = {}

	for _, ext in ipairs(constants.MUSIC_EXTENSIONS) do
		local music_files = vim.glob.to_lpeg
				and vim.fs.find(function(name)
					return name:match("%." .. ext .. "$")
				end, {
					path = constants.MUSIC_PATH,
					type = "file",
					limit = math.huge,
				})
			or {}

		vim.list_extend(all_files, music_files)
	end

	local result = {}

	for _, file in ipairs(all_files) do
		table.insert(result, util.get_song_file(file))
	end

	return result
end

function M.update_files()
	return async.sync(function()
		global_state.files = {}

		local all_songs = db.load_songs() or {}

		-- if no songs are saved in db -> insert all by once
		if #all_songs == 0 then
			local all_files = M.get_all_files()
			local songs = {}

			for _, file in ipairs(all_files) do
				table.insert(songs, file)
			end

			db.insert_songs(songs)

			all_songs = songs

			global_state.current_playlist = "All" -- init
		end

		local songs = {}

		if global_state.current_playlist == "All" then
			songs = all_songs
		else
			songs = playlist.get_playlist_songs(global_state.current_playlist)
		end

		for _, song in ipairs(songs) do
			table.insert(global_state.files, song)
		end
	end)
end

function M.sync_local_playlists()
	-- todo: may add here
end

function M.sync_playlist()
	return async.sync(function()
		local is_random = global_state.player_state.mode == "random"

		if is_random then
			async.wait(mpv.mpv_cmd({ "playlist-unshuffle" }))
		end

		local mpv_playlist = async.wait(mpv.get_playlist()) or {}

		local songs = {}

		local current_playlist = local_state.load_state().current_playlist

		if not current_playlist or current_playlist == "All" then
			songs = db.load_songs()
		else
			songs = playlist.get_playlist_songs(current_playlist)
		end

		-- init
		if #mpv_playlist == 0 then
			for _, song in ipairs(songs) do
				async.wait(mpv.mpv_cmd({ "loadfile", song.path, "append" }))
			end
		elseif #mpv_playlist > #songs then -- deletion
			local files_norm = {}

			for _, song in ipairs(songs) do
				files_norm[song.path] = true
			end

			for i, song in ipairs(mpv_playlist) do
				if not files_norm[song.filename] then
					async.wait(mpv.mpv_cmd({ "playlist-remove", i - 1 })) -- 0-based
				end
			end
		else -- addition
			local mpv_playlist_norm = {}

			for _, item in ipairs(mpv_playlist) do
				mpv_playlist_norm[item.filename] = true
			end

			for index, song in ipairs(songs) do
				if not mpv_playlist_norm[song.path] then
					async.wait(mpv.mpv_cmd({ "loadfile", song.path, "insert-at", index - 1 }))
				end
			end
		end

		if is_random then
			async.wait(mpv.mpv_cmd({ "playlist-shuffle" }))
		end
	end)
end

function M.insert_new_song_to_mpv(original_files)
	return async.sync(function()
		local current_files = M.get_all_files()

		local is_random = global_state.player_state.mode == "random"

		local original_files_norm = {}

		for _, file in ipairs(original_files) do
			original_files_norm[file.fullname] = true
		end

		for _, file in ipairs(current_files) do
			-- new song found
			if not original_files_norm[file.fullname] then
				if is_random then
					async.wait(mpv.mpv_cmd({ "playlist-unshuffle" }))
					async.wait(mpv.mpv_cmd({ "loadfile", file.path, "append" }))
					async.wait(mpv.mpv_cmd({ "playlist-shuffle" }))
				else
					async.wait(mpv.mpv_cmd({ "loadfile", file.path, "append" }))
				end

				return file
			end
		end
	end)
end

return M
