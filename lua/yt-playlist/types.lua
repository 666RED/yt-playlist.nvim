---@class DbSong
---@field path string
---@field fullname string
---@field filename string
---@field extension string
---@field id? string
---@field index? integer

---@class SongOpts
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
---@field current_playlist? string

---@alias Async<T> fun(callback: fun(result: T))
---@alias Tab "Songs" | "Playlists"

---@class PlaylistSong
---@field id integer

---@class Playlist
---@field name string
---@field songs PlaylistSong[]

---@class DbPlaylist
---@field playlist table<string, Playlist[]>

---@class LineMetadata
---@field name string
---@field display_name string
