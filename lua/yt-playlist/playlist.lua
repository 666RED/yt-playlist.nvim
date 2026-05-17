---@class PlaylistModule
---@field is_repeated_name fun(name: string): boolean
---@field set_playlists fun(): nil
---@field create_playlist fun(playlist_name: string): nil
---@field add_song fun(playlist_name: string, song_id: string): nil
---@field load_playlists fun(): Playlist[]
---@field remove_song_from_playlist fun(playlist_name: string, song_id: string): nil
---@field remove_song_in_all_playlists fun(id: string): nil
---@field sync_playlists fun(): nil
---@field get_playlist_songs fun(playlist_name: string): DbSong[]
---@field get_not_added_playlist_songs fun(playlist_name: string): DbSong[]
---@field remove_playlist fun(playlist_name: string): nil
local M = {}

-- note: MODULES

---@type AsyncModule
local async = require("yt-playlist.async")

---@type UtilModule
local util = require("yt-playlist.util")

---@type GlobalStateModule
local global_state = require("yt-playlist.global-state")

---@type LocalStateModule
local local_state = require("yt-playlist.local_state")

---@type ConstantsModule
local constants = require("yt-playlist.constants")

---@type DbModule
local db = require("yt-playlist.db")

-- note: LOCAL VARIABLES
local PLAYLIST_FILE = constants.PLAYLISTS_FILE

-- note: LOCAL FUNCTIONS

local function set_current_playlist()
	local state = local_state.load_state()

	if state then
		global_state.current_playlist = state.current_playlist
	end
end

---@param playlists Playlist[]
---@return nil
local function save_playlists(playlists)
	local f = io.open(PLAYLIST_FILE, "w")

	if not f then
		return -- todo: may handle this
	end

	f:write(vim.json.encode({ playlists = playlists }))
	f:close()
end

-- note: EXPORT FUNCTIONS

function M.is_repeated_name(name)
	if name == "All" then
		return true
	end

	local playlists = M.load_playlists()

	for _, playlist in ipairs(playlists) do
		if playlist.name == name then
			return true
		end
	end

	return false
end

function M.load_playlists()
	local f = io.open(constants.PLAYLISTS_FILE, "r")

	if not f then
		return {}
	end

	local content = f:read("*a")

	f:close()

	if content == "" then
		return {}
	end

	local ok, data = pcall(vim.json.decode, content)

	return ok and data.playlists or {}
end

function M.set_playlists()
	global_state.playlists = M.load_playlists()
end

function M.create_playlist(playlist_name)
	return async.sync(function()
		---@type Playlist
		local new_playlist = {
			name = playlist_name,
			songs = {},
		}

		local local_playlists = M.load_playlists()

		table.insert(local_playlists, new_playlist)

		save_playlists(local_playlists)
	end)
end
--
function M.add_song(playlist_name, song_id)
	local playlists = M.load_playlists()

	-- add song to playlist
	for _, playlist in ipairs(playlists) do
		if playlist.name == playlist_name then
			table.insert(playlist.songs, song_id)
		end
	end

	save_playlists(playlists)

	vim.schedule(function()
		vim.notify("Song added to playlist")
	end)
end

function M.remove_song_from_playlist(playlist_name, song_id)
	local playlists = M.load_playlists()

	for _, playlist in ipairs(playlists) do
		if playlist.name == playlist_name then
			for i, id in ipairs(playlist.songs) do
				if id == song_id then
					table.remove(playlist.songs, i)
					break
				end
			end

			break
		end
	end

	save_playlists(playlists)
end

function M.remove_song_in_all_playlists(id)
	local playlists = M.load_playlists()

	for _, playlist in ipairs(playlists) do
		for j = #playlist.songs, 1, -1 do
			if playlist.songs[j] == id then
				table.remove(playlist.songs, j)
			end
		end
	end

	save_playlists(playlists)
end

function M.setup()
	return async.sync(function()
		util.ensure_file(constants.PLAYLISTS_FILE)

		M.set_playlists()
		set_current_playlist()
	end)
end

function M.sync_playlists()
	local songs = db.load_songs()

	local playlists = M.load_playlists()

	local songs_norm = {}

	for _, song in ipairs(songs) do
		if song.id then
			songs_norm[song.id] = true
		end
	end

	for _, playlist in ipairs(playlists) do
		for j = #playlist.songs, 1, -1 do
			local song_id = playlist.songs[j]
			-- remove song id from playlist
			if not song_id or not songs_norm[song_id] then
				table.remove(playlist.songs, j)
			end
		end
	end

	save_playlists(playlists)
end

function M.get_playlist_songs(playlist_name)
	local all_songs = db.load_songs()
	local all_playlists = M.load_playlists()

	for _, playlist in ipairs(all_playlists) do
		if playlist.name == playlist_name then
			local song_ids = playlist.songs

			local db_songs_norm = {}

			for _, song in ipairs(all_songs) do
				db_songs_norm[song.id] = song
			end

			local songs = {}

			for _, id in ipairs(song_ids) do
				local song = db_songs_norm[id]

				if song then
					table.insert(songs, song)
				end
			end

			return songs
		end
	end

	return {}
end

function M.get_not_added_playlist_songs(playlist_name)
	local db_songs = db.load_songs()
	local playlists = M.load_playlists()

	local playlist_song_ids = {}

	-- find playlist
	for _, playlist in ipairs(playlists) do
		if playlist.name == playlist_name then
			playlist_song_ids = playlist.songs
		end
	end

	local playlist_songs_norm = {}

	for _, id in ipairs(playlist_song_ids) do
		playlist_songs_norm[id] = true
	end

	return vim.tbl_filter(function(song)
		return not playlist_songs_norm[song.id]
	end, db_songs)
end

function M.remove_playlist(playlist_name)
	local playlists = M.load_playlists()

	for i, playlist in ipairs(playlists) do
		if playlist.name == playlist_name then
			table.remove(playlists, i)
			break
		end
	end

	save_playlists(playlists)
end

return M
