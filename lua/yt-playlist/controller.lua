---@class ControllerModule
---@field get_all_files fun(): DbSong[]
---@field update_files fun(): AsyncThunk<nil>
---@field sync_local_playlists fun(): AsyncThunk<nil>
---@field sync_playlist fun(): AsyncThunk<nil>
---@field insert_new_song_to_mpv fun(original_files: DbSong[]): AsyncThunk<nil>
---@field download_song fun(): nil
---@field get_new_song fun(original_files: DbSong[]): DbSong|nil
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

---@type CommonModule
local common = require("yt-playlist.common")

-- note: LOCAL FUNCTIONS

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

---@param url string
---@param opts any
local function build_cmd(url, opts)
	local cmd = {
		"yt-dlp",
		"--extract-audio",
		"--audio-format",
		opts.format,
		"--audio-quality",
		opts.quality,
		"--no-keep-video",
		"-o",
		opts.name ~= "" and constants.MUSIC_PATH .. "/" .. opts.name .. ".%(ext)s"
			or constants.MUSIC_PATH .. "/%(title)s.%(ext)s",
	}

	table.insert(cmd, url)
	return cmd
end

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
			end
		end
	end)
end

function M.download_song()
	return async.sync(function()
		local original_files = M.get_all_files()

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
			elseif is_repeated_name(vim.trim(name)) then
				vim.notify(name .. " already existed", vim.log.levels.WARN)
			else
				song_name = name
				is_name_valid = true
			end
		end

		local is_add_to_playlist = false

		-- add to current playlist directly
		if global_state.current_playlist ~= "All" then
			local select = async.wrap(vim.ui.select)

			local result = async.wait(
				select({ "No", "Yes" }, { prompt = 'Add song to "' .. global_state.current_playlist .. '" directly?' })
			)

			if not result then
				vim.notify("Cancelled")
				return
			end

			if result == "Yes" then
				is_add_to_playlist = true
			end
		end

		local cmd = build_cmd(url, { format = format, quality = quality, name = song_name })

		local stderr_lines = {}

		local jobstart = function(cmd, opts)
			return function(step)
				opts = opts or {}
				opts.detach = true

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
					elseif line:match("%[ExtractAudio%]") then
						vim.schedule(function()
							vim.notify("Extracting audio... Please wait for a while", vim.log.levels.INFO)
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

		local local_current_playlist = local_state.load_state().current_playlist

		if local_current_playlist == "All" or local_current_playlist == global_state.current_playlist then
			async.wait(M.insert_new_song_to_mpv(original_files))
		end

		-- get newly added song
		local new_file = M.get_new_song(original_files)

		if new_file then
			db.insert_song(new_file)
		end

		if is_add_to_playlist and new_file then
			local new_song = db.get_song_by_filename(new_file.filename)

			if new_song then
				async.wait(common.add_song_to_playlist(new_song.id))
			end
		end

		vim.schedule(function()
			vim.notify("Download completed!")
		end)
	end)
end

function M.get_new_song(original_files)
	local current_files = M.get_all_files()

	local original_files_norm = {}

	for _, file in ipairs(original_files) do
		original_files_norm[file.filename] = true
	end

	for _, file in ipairs(current_files) do
		-- new song found
		if not original_files_norm[file.filename] then
			return file
		end
	end

	return nil
end

return M
