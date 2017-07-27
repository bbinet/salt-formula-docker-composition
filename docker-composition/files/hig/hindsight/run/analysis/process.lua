local string = require "string"
local postprocess_msg = require "hl_postprocess".postprocess_msg

local postprocess_cfg = read_config("postprocess_cfg")


-- TODO: implement 2 separate caches for global and uuid rules

-- TODO: add support for counting number of replacement and log keys that have
--       been replaced (so that we can fix the naming upstream)


function process_message()
    local ok, msg_in = pcall(decode_message, read_message("raw"))
    if not ok then
        return -1, string.format("decode_message failure: %s", tostring(msg_in))
    end
    local msg_out = postprocess_msg(msg_in, postprocess_cfg)
    inject_message(msg_out)
    return 0
end

function timer_event(ns)
end
