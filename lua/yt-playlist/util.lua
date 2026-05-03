---@class UtilModule
---@field norm fun(path: string): string
---@field to_set fun(list: string[]): table<string, boolean>
---@field get_filename fun(path: string): string
---@field remove_extension fun(path: string): string
---@field format_time fun(date?: number): string
---@field get_song_file fun(file: string): Song_File
---@field set_win_opts fun(win: integer): nil
local M = {}

local function norm(path)
	-- return full path
	return vim.fn.fnamemodify(path, ":p")
end

function M.to_set(list)
	local set = {}

	for _, v in ipairs(list) do
		set[norm(v)] = true
	end

	return set
end

function M.get_filename(path)
	return path:match("([^/]+)$")
end

function M.remove_extension(path)
	return path:match("([^/]+)%.[^.]+$")
end

function M.format_time(date)
	if not date then
		return "--:--"
	end

	return string.format("%02d:%02d", math.floor(date / 60), math.floor(date % 60))
end

function M.get_song_file(file)
	local filename = file:match("([^/]+)$")
	local name = filename:match("(.+)%.[^.]+$")
	local ext = filename:match("[^.]+$")
	return { full_name = filename, filename = name, extension = ext }
end

function M.set_win_opts(win)
	vim.wo[win].signcolumn = "no"
	vim.wo[win].foldcolumn = "0"
	vim.wo[win].spell = false
	vim.wo[win].list = false -- disable listchars (tabs, trailing spaces markers)
	vim.wo[win].wrap = false
	vim.wo[win].cursorcolumn = false
end

M.norm = norm

return M
