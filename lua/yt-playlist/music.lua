---@class MusicModule
---@field get_current_song fun(): AsyncThunk<PlayerState>
---@field get_db_song_file fun(file: string): DbSong
---@field play_song fun(file: string): AsyncThunk<nil>
---@field pause_or_resume fun(): AsyncThunk<boolean>
---@field next_song fun(): AsyncThunk<nil>
---@field prev_song fun(): AsyncThunk<nil>
---@field rewind fun(): AsyncThunk<nil>
---@field forward fun(): AsyncThunk<nil>
---@field increase_volume fun(volume?: integer): AsyncThunk<nil>
---@field decrease_volume fun(volume?: integer): AsyncThunk<nil>
---@field delete_song_from_directory fun(song: DbSong): AsyncThunk<nil>
---@field delete_song_from_mpv fun(song: DbSong): AsyncThunk<nil>
---@field switch_mode fun(): function
---@field set_volume fun(volume?: integer): AsyncThunk<nil>
local M = {}

---@type PlayMode[]
local modes = { "normal", "loop", "random" }

-- note: MODULES

---@type GlobalStateModule
local global_state = require("yt-playlist.global-state")

---@type ControllerModule
local controller = require("yt-playlist.controller")

---@type MpvModule
local mpv = require("yt-playlist.mpv")

---@type LocalStateModule
local local_state = require("yt-playlist.local_state")

---@type AsyncModule
local async = require("yt-playlist.async")

---@type ConstantsModule
local constants = require("yt-playlist.constants")

-- note: LOCAL FUNCTIONS

function M.get_db_song_file(file)
	for i, song in ipairs(global_state.files) do
		if song.filename == file then
			return vim.tbl_extend("force", song, { index = i })
		end
	end

	return {}
end

---@param path string
local function play_current_song(path)
	return async.sync(function()
		local playlist = async.wait(mpv.get_playlist())

		local playlist_pos = nil

		for i, song in ipairs(playlist) do
			if song.filename == path then
				playlist_pos = i - 1
			end
		end

		async.wait(mpv.mpv_cmd({ "set_property", "playlist-pos", playlist_pos }))
		async.wait(mpv.mpv_cmd({ "set_property", "pause", false }))
	end)
end

---@param current PlayMode
---@return PlayMode
local function next_mode(current)
	for i, mode in ipairs(modes) do
		if mode == current then
			return modes[i % #modes + 1]
		end
	end

	return "normal"
end

-- note: EXPORT FUNCTIONS

function M.get_current_song()
	return async.sync(function()
		local title = async.wait(mpv.mpv_cmd({ "get_property", "media-title" }))
		local time_pos = async.wait(mpv.mpv_cmd({ "get_property", "time-pos" }))
		local duration = async.wait(mpv.mpv_cmd({ "get_property", "duration" }))
		local paused = async.wait(mpv.mpv_cmd({ "get_property", "pause" }))
		local volume = async.wait(mpv.mpv_cmd({ "get_property", "volume" }))
		local state = local_state.load_state()

		---@type PlayerState
		return {
			title = title,
			position = time_pos,
			duration = duration,
			paused = paused,
			volume = volume,
			mode = (state and state.mode) or "normal",
		}
	end)
end

function M.play_song(file)
	return async.sync(function()
		local song = M.get_db_song_file(file)

		if not song then
			return
		end

		-- check if files and playlist are synced
		local mpv_playlist = async.wait(mpv.get_playlist()) or {}

		if #mpv_playlist == 0 then
			async.wait(controller.sync_playlist())

			async.wait(play_current_song(song.path))
			return
		end

		local mpv_index = nil

		for i, item in ipairs(mpv_playlist) do
			if item.filename == song.path then
				mpv_index = i - 1 -- 0-based
				break
			end
		end

		if not mpv_index then
			async.wait(controller.sync_playlist())
			async.wait(play_current_song(song.path))
			return
		end

		async.wait(play_current_song(song.path))
	end)
end

function M.pause_or_resume()
	return async.sync(function()
		async.wait(mpv.mpv_cmd({ "cycle", "pause" }))

		local paused = async.wait(mpv.mpv_cmd({ "get_property", "pause" }))
		return paused
	end)
end

function M.next_song()
	return async.sync(function()
		async.wait(mpv.mpv_cmd({ "playlist-next" }))
		async.wait(mpv.mpv_cmd({ "set_property", "pause", false }))
	end)
end

function M.prev_song()
	return async.sync(function()
		async.wait(mpv.mpv_cmd({ "playlist-prev" }))
		async.wait(mpv.mpv_cmd({ "set_property", "pause", false }))
	end)
end

function M.rewind()
	return async.sync(function()
		async.wait(mpv.mpv_cmd({ "seek", -10 }))
	end)
end

function M.forward()
	return async.sync(function()
		async.wait(mpv.mpv_cmd({ "seek", 10 }))
	end)
end

function M.increase_volume(volume)
	volume = volume or 5

	return async.sync(function()
		async.wait(mpv.mpv_cmd({ "add", "volume", volume }))
	end)
end

function M.decrease_volume(volume)
	volume = volume or 5

	return async.sync(function()
		async.wait(mpv.mpv_cmd({ "add", "volume", -volume }))
	end)
end

function M.delete_song_from_directory(song)
	return async.sync(function()
		if not song.fullname or not song.path then
			vim.schedule(function()
				vim.notify("Cannot delete: song entry is corrupted", vim.log.levels.ERROR)
			end)
			return
		end

		local fullpath = constants.MUSIC_PATH .. "/" .. song.fullname

		-- remove song in Music directory
		local ok, err = os.remove(fullpath)

		vim.schedule(function()
			if ok then
				vim.notify("Deleted: " .. song.filename)
			else
				vim.notify("Failed to delete file: " .. err)
			end
		end)
	end)
end

function M.delete_song_from_mpv(song)
	return async.sync(function()
		if not song.fullname or not song.path then
			vim.schedule(function()
				vim.notify("Cannot delete: song entry is corrupted", vim.log.levels.ERROR)
			end)
			return
		end

		local mpv_playlist = async.wait(mpv.get_playlist()) or {}

		local mpv_index = nil

		-- find song in mpv
		for i, item in ipairs(mpv_playlist) do
			if item.filename == song.path then
				mpv_index = i - 1
				break
			end
		end

		-- remove song in mpv
		if mpv_index ~= nil then
			async.wait(mpv.mpv_cmd({ "playlist-remove", mpv_index }))
		end
	end)
end

function M.switch_mode()
	return async.sync(function()
		local current_mode = local_state.load_state()
		local new_mode = next_mode(current_mode and current_mode.mode or "normal")

		if new_mode == "normal" then
			async.wait(mpv.mpv_cmd({ "set_property", "loop-file", "no" }))
			async.wait(mpv.mpv_cmd({ "playlist-unshuffle" }))
		elseif new_mode == "loop" then
			async.wait(mpv.mpv_cmd({ "set_property", "loop-file", "inf" }))
		else
			async.wait(mpv.mpv_cmd({ "set_property", "loop-file", "no" }))
			async.wait(mpv.mpv_cmd({ "playlist-shuffle" }))
		end

		local_state.save_state({ mode = new_mode })

		return new_mode
	end)
end

function M.setup()
	return async.sync(function()
		if vim.fn.isdirectory(constants.MUSIC_PATH) == 0 then
			vim.fn.mkdir(constants.MUSIC_PATH, "p")
		end
	end)
end

function M.set_volume(volume)
	return async.sync(function()
		if not volume then
			return
		end

		async.wait(mpv.mpv_cmd({ "set_property", "volume", volume }))
	end)
end

return M
