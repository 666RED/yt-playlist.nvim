---@class DbModule
---@field load_songs fun(): Db_Song[]
---@field insert_song fun(song: Db_Song): nil
---@field insert_songs fun(songs: Db_Song[]): nil
---@field update_song fun(song: Db_Song): nil
---@field get_song fun(id: integer): Db_Song|nil
---@field delete_song fun(id: string): nil
---@field sync_db fun(songs: Db_Song[]): nil
---@field setup fun(): AsyncThunk<nil>
local M = {}

-- note: MODULES

---@type UtilModule
local util = require("yt-playlist.util")

---@type ConstantsModule
local constants = require("yt-playlist.constants")

---@type AsyncModule
local async = require("yt-playlist.async")

-- note: LOCAL VARIABLES
local DB_FILE = constants.DB_FILE

-- note: LOCAL FUNCTIONS

---@param songs Db_Song[]
---@return nil
local function save_songs(songs)
	local f = io.open(DB_FILE, "w")

	if not f then
		return
	end

	f:write(vim.json.encode({ songs = songs }))
	f:close()
end

-- note: EXPORT FUNCTIONS
function M.load_songs()
	local f = io.open(DB_FILE, "r")

	if not f then
		return {}
	end

	local content = f:read("*a")

	f:close()

	if content == "" or content == nil then
		return {}
	end

	local ok, data = pcall(vim.json.decode, content)

	return ok and data.songs or {}
end

function M.insert_song(song)
	local songs = M.load_songs()

	for _, s in ipairs(songs) do
		if s.filename == song.filename then
			vim.notify("This song already in All playlist")
			return
		end
	end

	song.id = util.uuid()
	table.insert(songs, song)

	save_songs(songs)
end

function M.insert_songs(songs)
	local db = M.load_songs()

	for _, song in ipairs(songs) do
		song.id = util.uuid()
		table.insert(db, song)
	end

	save_songs(db)
end

function M.update_song(song)
	local songs = M.load_songs()

	for i, s in ipairs(songs) do
		if s.id == song.id then
			songs[i] = s
			save_songs(songs)
			return
		end
	end
end

function M.get_song(id)
	local songs = M.load_songs()

	for _, song in ipairs(songs) do
		if song.id == id then
			return song
		end
	end
	return nil
end

-- delete a song
function M.delete_song(id)
	local songs = M.load_songs()

	for i, song in ipairs(songs) do
		if song.id == id then
			table.remove(songs, i)
		end
	end

	save_songs(songs)
end

function M.sync_db(songs)
	local db_songs = M.load_songs()

	-- build lookup tables
	---@type table<string, Db_Song>
	local db_songs_norm = {}

	for _, song in ipairs(db_songs) do
		db_songs_norm[song.path] = song -- key by path, not id (new files have no id)
	end

	---@type table<string, boolean>
	local fs_songs_norm = {}

	for _, song in ipairs(songs) do
		fs_songs_norm[song.path] = true
	end

	-- deletion: in db but not on filesystem anymore
	for path, song in pairs(db_songs_norm) do
		if not fs_songs_norm[path] then
			M.delete_song(song.id)
		end
	end

	-- addition: on filesystem but not in db
	for _, song in ipairs(songs) do
		if not db_songs_norm[song.path] then
			M.insert_song(song)
		end
	end
end

function M.setup()
	return async.sync(function()
		util.ensure_file(DB_FILE)
	end)
end

return M
