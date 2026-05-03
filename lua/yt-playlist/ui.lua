---@class UiModule
---@field update_info_buf fun(): nil
local M = {}

-- note: MODULES

---@type StateModule
local global_state = require("yt-playlist.state")

---@type UtilModule
local util = require("yt-playlist.util")

return M
