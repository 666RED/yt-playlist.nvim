local M = {}

M.MUSIC_PATH = vim.fn.expand("~/Music/YtPlayList")
M.MUSIC_EXTENSIONS = { "m4a", "mp3", "opus", "flac" }

M.TOTAL_WIDTH = vim.o.columns
M.TOTAL_HEIGHT = vim.o.lines - vim.o.cmdheight - 1
M.UPPER_HEIGHT = math.floor(M.TOTAL_HEIGHT * 0.55)
M.LOWER_HEIGHT = M.TOTAL_HEIGHT - M.UPPER_HEIGHT - 1
M.INFO_WIDTH = math.floor(M.TOTAL_WIDTH * 0.85)
M.VOLUME_WIDTH = math.floor(M.TOTAL_WIDTH * 0.14)

return M
