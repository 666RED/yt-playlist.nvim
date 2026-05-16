---@class GlobalStateModule
---@field state YtPlaylistState
---@field timer YtPlaylistTimer
---@field info_ns integer
---@field song_ns integer
---@field playlist_ns integer
---@field playlist_tabs_ns integer
---@field tabs Tab[]
---@field current_tab Tab
---@field files Db_Song[]
---@field playlists string[]
---@field current_playlist string
local M = {}

-- note: VARIABLES

---@type YtPlaylistState
M.state = {
	playlist_win = nil,
	info_win = nil,
	playlist_buf = nil,
	info_buf = nil,
	volume_buf = nil,
	volume_win = nil,
	is_open = false,
}

---@type YtPlaylistTimer
M.timer = { position_timer = nil, fs_event_timer = nil, mpv_listener = nil }

---@type PlayerState
M.player_state = {
	title = nil,
	duration = nil,
	paused = nil,
	position = nil,
}

M.info_ns = vim.api.nvim_create_namespace("yt_info")
M.song_ns = vim.api.nvim_create_namespace("yt_songs")
M.playlist_ns = vim.api.nvim_create_namespace("yt_playlists")
M.playlist_tabs_ns = vim.api.nvim_create_namespace("yt_playlist_tabs")

M.tabs = { "Songs", "Playlists" }

M.current_tab = M.tabs[1]

M.files = {}
M.playlists = {}
M.current_playlist = ""

return M
