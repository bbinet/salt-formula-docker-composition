local string = require "string"
local postprocess_msg = require "hl_postprocess".postprocess_msg

local postprocess_cfg = read_config("postprocess_cfg")


-- TODO: implement 2 separate caches for global and uuid rules

-- TODO: add support for counting number of replacement and log keys that have
--       been replaced (so that we can fix the naming upstream)


function process_message()
    local msg = postprocess_msg(
        decode_message(read_message("raw")), postprocess_cfg)
    inject_message(msg)
    return 0
end

function timer_event(ns)
end
