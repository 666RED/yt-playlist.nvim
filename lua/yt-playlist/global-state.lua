---@class GlobalStateModule
---@field state YtPlaylistState
---@field timer YtPlaylistTimer
---@field info_ns integer
---@field playlist_ns integer
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
M.playlist_ns = vim.api.nvim_create_namespace("yt_playlist")

return M
