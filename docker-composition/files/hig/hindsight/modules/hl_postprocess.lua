--[[

# Utility to postprocess a message with the following tasks:

  - try a list of regex rules to rewrite message fields
  - annotate message fields based on uuid matching

-- postprocess cfg should look like:

postprocess_cfg = {

  rewrite = {
    <measurement> = {  -- e.g. "trserver"
      <uuid> = {
        <rules>
      },
      ...
      defaults = {
        <rules>
      },
    },
    ...
    defaults = {
        <uuid> = {
          <rules>
        },
        ...
        defaults = {
          <rules>
        },
    }
  },

  annotate = {
    <uuid> = {
      _tag = value,
      .hidden = value
    },
    defaults = {
      <annotations>
    },
    notfound = {
      <annotations>
    }
  }
}

--]]

local ipairs = ipairs
local pairs = pairs
local type = type
local string = require "string"
local mi = require "heka.msg_interpolate"

local M = {}
setfenv(1, M) -- Remove external access to contain everything in the module.


function array2hash_fields(fields)
    local newfields = {}
    for i, field in ipairs(fields or {}) do
        newfields[field.name] = field.value[1]
    end
    return newfields
end


function process_rewrite_rules(rules, key, scale)
    if type(key) ~= 'string' then return key, false, scale end
    for _, rule in ipairs(rules or {}) do
        if rule.delete then
            if string.find(key, rule.pattern) ~= nil then
                return nil, false, scale
            end
        else
            local newkey, n = string.gsub(
                key, rule.pattern, rule.replacement)
            if n > 0 then
                key = newkey
                if rule.scale then scale = rule.scale * (scale or 1) end
                if not rule.continue then
                    return key, false, scale
                end
            end
        end
    end
    return key, true, scale
end


function rewrite_fields(fields, ...)
    local arg = {...} -- arg is an array of rules config objects
    local newfields = {}
    -- parse global tag fields
    for key, value in pairs(fields or {}) do
        local scale = nil
        if string.sub(key, 1, 1) ~= '_' then  -- FIXME: why not also process tag/hidden fields?
            local continue = true
            for _, rules in ipairs(arg or {}) do
                if rules and key and continue then
                    key, continue, scale = process_rewrite_rules(rules, key, scale)
                end
            end
        end
        if key ~= nil then
            if scale and type(value) == 'number' then
                value = value * scale
            end
            newfields[key] = value
        end
    end
    return newfields
end


function rewrite_msg(msg, cfg, uuid)
    if not cfg then
        return msg
    end
    uuid = uuid or msg.Fields._uuid or msg.Hostname
    local measurement = msg.Payload
    local mcfg = cfg[measurement] or {}
    local dcfg = cfg.defaults or {}
    msg.Fields = rewrite_fields(msg.Fields,
                           mcfg[uuid] or false,
                           dcfg[uuid] or false,
                           mcfg.defaults or false,
                           dcfg.defaults or false)
    return msg
end


-- annotate_msg requires msg.Fields to be hash based (not array based)
function annotate_msg(msg, cfg, uuid)
    if not cfg then
        return msg
    end
    uuid = uuid or msg.Fields._uuid or msg.Hostname
    for k, v in pairs(cfg.defaults or {}) do
        msg.Fields[k] = mi.interpolate(v)
    end
    for k, v in pairs(cfg[uuid] or cfg.notfound or {}) do
        msg.Fields[k] = mi.interpolate(v)
    end
    return msg
end


function postprocess_msg(msg, cfg, uuid)
    if cfg and (cfg.rewrite or cfg.annotate) then
        if msg.Fields[1] ~= nil then
            msg.Fields = array2hash_fields(msg.Fields)
        end
        uuid = uuid or msg.Fields._uuid or msg.Hostname
        msg = rewrite_msg(msg, cfg.rewrite, uuid)
        msg = annotate_msg(msg, cfg.annotate, uuid)
    end
    return msg
end


return M
