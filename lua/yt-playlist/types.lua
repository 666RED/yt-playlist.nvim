---@class Song_File
---@field full_name string
---@field filename string
---@field extension string
---@field mpv_id integer | nil

---@class Song_File_With_Index: Song_File
---@field index integer

---@class Song_Opts
---@field format string
---@field quality string
---@field name string

-- note: State

---@class YtPlaylistState
---@field playlist_win integer | nil
---@field info_win integer | nil
---@field playlist_buf integer | nil
---@field info_buf integer | nil
---@field volume_buf integer | nil
---@field volume_win integer | nil
---@field is_open boolean

---@class YtPlaylistTimer
---@field position_timer uv.uv_timer_t | nil
---@field fs_event_timer uv.uv_timer_t | nil
---@field fs_event uv.uv_fs_event_t | nil
---@field mpv_listener uv.uv_pipe_t | nil
---
---@alias PlayMode "normal" | "loop" | "random"

---@class PlayerState
---@field title string|nil
---@field duration integer|nil
---@field paused boolean|nil
---@field position integer|nil
---@field mode PlayMode|nil
---@field volume integer|nil

---@class StateData
---@field mode? PlayMode
---@field playlist? string

---@alias Async<T> fun(callback: fun(result: T))
