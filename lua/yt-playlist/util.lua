math.randomseed(vim.loop.hrtime())

---@class UtilModule
---@field norm fun(path: string): string
---@field to_set fun(list: string[]): table<string, boolean>
---@field get_filename fun(path: string): string
---@field remove_extension fun(path: string): string
---@field format_time fun(date?: number): string
---@field get_song_file fun(file: string): Db_Song
---@field set_win_opts fun(win: integer): nil
---@field get_playlist_name fun(path: string): string
---@field uuid fun(): string
---@field file_exists fun(name:string): boolean
---@field ensure_file fun(path: string): nil
local M = {}

function M.norm(path)
	-- return full path
	return vim.fn.fnamemodify(path, ":p")
end

function M.to_set(list)
	local set = {}

	for _, v in ipairs(list) do
		set[M.norm(v)] = true
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
	local fullname = file:match("([^/]+)$")
	local filename = fullname:match("(.+)%.[^.]+$")
	local ext = fullname:match("[^.]+$")
	local path = file
	return { fullname = fullname, filename = filename, extension = ext, path = path }
end

function M.set_win_opts(win)
	vim.wo[win].signcolumn = "no"
	vim.wo[win].foldcolumn = "0"
	vim.wo[win].spell = false
	vim.wo[win].list = false -- disable listchars (tabs, trailing spaces markers)
	vim.wo[win].wrap = false
	vim.wo[win].cursorcolumn = false
end

function M.get_playlist_name(path)
	return path:match("([^/]+)%.m3u$")
end

function M.uuid()
	local template = "xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx"

	return (
		string.gsub(template, "[xy]", function(c)
			local v = (c == "x") and math.random(0, 0xf) or math.random(8, 0xb)

			return string.format("%x", v)
		end)
	)
end

function M.file_exists(name)
	local f = io.open(name, "r")
	if f ~= nil then
		io.close(f)
		return true
	else
		return false
	end
end

function M.ensure_file(path)
	-- ensure directory exists
	local dir = vim.fn.fnamemodify(path, ":h")

	if vim.fn.isdirectory(dir) == 0 then
		vim.fn.mkdir(dir, "p")
	end

	-- ensure file exists
	if vim.fn.filereadable(path) == 0 then
		io.open(path, "w"):close()
	end
end

return M
