-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at http://mozilla.org/MPL/2.0/.

require "io"
require "string"
require "lfs"

local mkdir_p = require "hl_utils".mkdir_p

--[[
#  Heka Protobuf Stream Output (rolled by size)

Outputs a Heka protobuf stream rolling the log file every time it reaches the `roll_size`.

## Sample Configuration
```lua
filename        = "heka_log_rolling.lua"
message_matcher = "TRUE"
ticker_interval = 0
preserve_data   = true

--location where the payload is written
output_dir      = "/tmp"
roll_size       = 1024 * 1024 * 1024
```
--]]

local output_dir    = read_config("output_dir") or string.format(
    "%s/%s", read_config("output_path"), read_config("Logger"))
mkdir_p(output_dir)
local roll_size     = read_config("roll_size") or 1e9
local fh

file_num = 0
for file in lfs.dir(output_dir) do
    local num = tonumber(string.match(file, "(%d+).log$"))
    if num and num > file_num then
        file_num = num
    end
end

function process_message()
    if not fh then
        local fn = string.format("%s/%d.log", output_dir, file_num)
        fh, err = io.open(fn, "a")
        if err then return -1, err end
    end

    local msg = read_message("framed")
    fh:write(msg)

    if fh:seek() >= roll_size  then
        fh:close()
        fh = nil
        file_num = file_num + 1
    end
    return 0
end

function timer_event(ns)
    -- no op
end
