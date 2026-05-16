---@class MusicModule
---@field get_current_song fun(): AsyncThunk<PlayerState>
---@field get_db_song_file fun(file: string): Db_Song
---@field play_song fun(file: string): AsyncThunk<nil>
---@field pause_or_resume fun(): AsyncThunk<boolean>
---@field next_song fun(): AsyncThunk<nil>
---@field prev_song fun(): AsyncThunk<nil>
---@field rewind fun(): AsyncThunk<nil>
---@field forward fun(): AsyncThunk<nil>
---@field increase_volume fun(volume?: integer): AsyncThunk<nil>
---@field decrease_volume fun(volume?: integer): AsyncThunk<nil>
---@field download_song fun(): nil
---@field delete_song_from_directory fun(song: Db_Song): AsyncThunk<nil>
---@field delete_song_from_mpv fun(song: Db_Song): AsyncThunk<nil>
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

---@type DbModule
local db = require("yt-playlist.db")

-- note: LOCAL FUNCTIONS

local function build_cmd(url, opts)
	local cmd = {
		"yt-dlp",
		"--extract-audio",
		"--audio-format",
		opts.format,
		"--audio-quality",
		opts.quality,
		"-o",
		opts.name ~= "" and constants.MUSIC_PATH .. "/" .. opts.name .. ".%(ext)s"
			or constants.MUSIC_PATH .. "/%(title)s.%(ext)s",
	}

	table.insert(cmd, url)
	return cmd
end

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

---@param name string
---@return boolean
local function is_repeated_name(name)
	local files = global_state.files

	for _, file in ipairs(files) do
		if file.filename == name then
			return true
		end
	end

	return false
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

function M.download_song()
	return async.sync(function()
		local url_input = async.wrap(vim.ui.input)
		local url = async.wait(url_input({ prompt = "Youtube vidoe url: " }))

		if not url then
			vim.notify("Cancelled")
			return
		end

		local is_valid = url:match("^https?://")

		if not is_valid then
			vim.notify("Invalid URL", vim.log.levels.ERROR)
			return
		end

		local format_select = async.wrap(vim.ui.select)
		local format = async.wait(format_select({ "mp3", "m4a", "opus", "flac" }, { prompt = "Select audio format:" }))

		if not format or format == "" then
			vim.notify("Cancelled")
			return
		end

		local quality_select = async.wrap(vim.ui.select)
		local quality = async.wait(quality_select({ "128k", "192k", "256k", "320k" }, { prompt = "Select quality:" }))

		if not quality or quality == "" then
			vim.notify("Cancelled")
			return
		end

		local is_name_valid = false
		local song_name = ""

		while not is_name_valid do
			local name_input = async.wrap(vim.ui.input)
			local name = async.wait(name_input({ prompt = "Name (optional): " }))

			if not name then
				vim.notify("Cancelled")
				return
			elseif is_repeated_name(name) then
				vim.notify(name .. " already existed", vim.log.levels.WARN)
			else
				song_name = name
				is_name_valid = true
			end
		end

		local cmd = build_cmd(url, { format = format, quality = quality, name = song_name })

		local stderr_lines = {}

		local jobstart = function(_, opts)
			return function(step)
				opts = opts or {}

				local old_exit = opts.on_exit

				opts.on_exit = function(job_id, exit_code, event)
					if old_exit then
						old_exit(job_id, exit_code, event)
					end

					step(exit_code)
				end

				vim.fn.jobstart(cmd, opts)
			end
		end

		local exit_code = async.wait(jobstart(cmd, {
			on_stdout = function(_, data, _)
				for _, line in ipairs(data) do
					if line:match("%[download%]") then
						vim.schedule(function()
							vim.notify(line) -- display download progress
						end)
					end
				end
			end,

			on_stderr = function(_, data, _)
				for _, line in ipairs(data) do
					if line ~= "" then
						table.insert(stderr_lines, line)
					end
				end
			end,
		}))

		if exit_code ~= 0 then
			vim.notify("Download failed")
			return
		end

		-- todo: may add song to playlist directly (prompt to ask user)
		if global_state.current_playlist == "All" then
			local new_file = async.wait(controller.insert_new_song_to_mpv(global_state.files))
			db.insert_song(new_file)
		end

		vim.schedule(function()
			vim.notify("Download completed!")
		end)
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
