--[[

# Various HeliosLite utilities

  - mkdir_p(dir): equivalent to 'mkdir -p dir'

--]]

local string = require "string"
local lfs = require "lfs"
local error = error

local M = {}
setfenv(1, M) -- Remove external access to contain everything in the module.


-- equivalent to 'mkdir -p dir'
function mkdir_p(dir)
    local walk = ""
    for p in string.gfind(dir, "[^/]+") do
        walk = walk .. "/" .. p
        local attr = lfs.attributes(walk)
        if not attr then
            lfs.mkdir(walk)
        elseif attr.mode ~= "directory" then
            error(string.format("%s already exists", walk))
        end
    end
end

return M
