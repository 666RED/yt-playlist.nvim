---@class ConstantsModule
---@field MUSIC_PATH string
---@field DATA_PATH string
---@field PLAYLISTS_FILE string
---@field DB_FILE string
---@field MUSIC_EXTENSIONS string[]
---@field TOTAL_WIDTH integer
---@field TOTAL_HEIGHT integer
---@field UPPER_HEIGHT integer
---@field LOWER_HEIGHT integer
---@field INFO_WIDTH integer
---@field VOLUME_WIDTH integer
local M = {}

M.MUSIC_PATH = vim.fn.expand("~/Music/YtPlayList")
M.DATA_PATH = vim.fn.stdpath("data") .. "/yt-playlists/"
M.PLAYLISTS_FILE = vim.fn.stdpath("data") .. "/yt-playlist/playlists.json"
M.DB_FILE = vim.fn.stdpath("data") .. "/yt-playlist/db.json"
M.STATE_FILE = vim.fn.stdpath("data") .. "/yt-playlist/state.json"
M.MUSIC_EXTENSIONS = { "m4a", "mp3", "opus", "flac" }

M.TOTAL_WIDTH = vim.o.columns
M.TOTAL_HEIGHT = vim.o.lines - vim.o.cmdheight - 1
M.UPPER_HEIGHT = math.floor(M.TOTAL_HEIGHT * 0.55)
M.LOWER_HEIGHT = M.TOTAL_HEIGHT - M.UPPER_HEIGHT - 1
M.INFO_WIDTH = math.floor(M.TOTAL_WIDTH * 0.85)
M.VOLUME_WIDTH = math.floor(M.TOTAL_WIDTH * 0.14)

return M
