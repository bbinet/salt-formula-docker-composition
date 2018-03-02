-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at http://mozilla.org/MPL/2.0/.

--[[
# InfluxDB TCP Output

## Sample Configuration
```lua
filename        = "influxdb_tcp.lua"
message_matcher = "Type == 'hlmetric' && Fields[.db] == 'metricsdb'"
ticker_interval = 60 -- flush every 60 seconds or flush_count (50000) messages
memory_limit    = 200e6

address             = "127.0.0.1"
port                = 8086
timeout             = 15
flush_count         = 5000
flush_on_shutdown   = true
preserve_data       = not flush_on_shutdown  -- in most cases this should be the inverse of flush_on_shutdown

db                  = "metricsdb"
user                = "user"
password            = "pass"
```
--]]

require "table"
require "rjson"
require "string"
require "math"

local mime      = require "mime"
local ltn12     = require "ltn12"
local time      = require "os".time
local socket    = require "socket"
local http      = require("socket.http")
local mkdir_p   = require "hl_utils".mkdir_p

local address   = read_config("address") or "127.0.0.1"
local port      = read_config("port") or 8086
local timeout   = read_config("timeout") or 15

local flush_on_shutdown = read_config("flush_on_shutdown")
local ticker_interval   = read_config("ticker_interval")
local flush_count       = read_config("flush_count") or 5000
local last_flush        = time()

local db = read_config("database") or error("database config is required")
local user = read_config("user") or error("user config is required")
local password = read_config("password") or error("password config is required")

local error_dir = read_config("error_dir") or string.format(
    "%s/errors/%s", read_config("output_path"), read_config("Logger"))

local batch_dir = string.format(
    "%s/output.influxdb_tcp", read_config("output_path"))
mkdir_p(batch_dir)
local batch_file = string.format(
    "%s/%s.batch", batch_dir, read_config("Logger"))
local batch_count = 0
local retry = false
local batch = assert(io.open(batch_file, "a+"))

local _encoders = {
    int = function(key, value) return string.format('%s=%di', key, value) end,
    bool = function(key, value) return string.format('%s=%s', key, not not value) end,
}
local encoders = {}
for measurement, mencoders in pairs(read_config("encoders") or {}) do
    encoders[measurement] = {}
    for key, cast in pairs(mencoders) do
        encoders[measurement][key] = _encoders[cast]
    end
end

local function encode_field(measurement, key, value)
    local mencoders = encoders[measurement]
    if mencoders == nil then
        mencoders = {}
        encoders[measurement] = mencoders
    end
    local encoder = mencoders[key]
    if encoder ~= nil then
        return encoder(key, value)
    end
    return key .. '=' .. value
end

local client
local function create_client()
    local client = http.open(address, port)
    client.c:setoption("tcp-nodelay", true)
    client.c:setoption("keepalive", true)
    client.c:settimeout(timeout)
    return client
end
local pcreate_client = socket.protect(create_client);


local req_headers = {
    ["user-agent"]      = http.USERAGENT,
    ["content-length"]  = 0,
    ["host"]            = address .. ":" .. port,
    ["accept"]          = "*/*",
    ["content-type"]    = "text/plain",
    ["connection"]      = "keep-alive",
    ["authorization"]  = "Basic " .. mime.b64(user .. ":" .. password),
}

local function save_error_batch(code)
    mkdir_p(error_dir)
    error_file = string.format("%s/%d_%d.batch", error_dir, code, time())
    if ltn12.pump.all(
        ltn12.source.file(assert(io.open(batch_file, "r"))),
        ltn12.sink.file(assert(io.open(error_file, "w")))
        ) then
        retry = false
        batch_count = 0
        batch:close()
        batch = assert(io.open(batch_file, "w"))
        return true
    end
end

local function send_request() -- hand coded since socket.http doesn't support keep-alive connections
    local fh = assert(io.open(batch_file, "r"))
    req_headers["content-length"] = fh:seek("end")
    client:sendrequestline("POST", "/write?precision=s&db=" .. db)
    client:sendheaders(req_headers)
    fh:seek("set")
    client:sendbody(req_headers, ltn12.source.file(fh, "invalid file handle"))
    local code = client:receivestatusline()
    local headers
    while code == 100 do -- ignore any 100-continue messages
        headers = client:receiveheaders()
        code = client:receivestatusline()
    end
    print(">>> InfluxDB response status:", code)
    headers = client:receiveheaders()
    local ok, err, ret = true, nil, 0
    if code ~= 204 and code ~= 304 and not (code >= 100 and code < 200) then
        if string.match(headers["content-type"], "^application/json") then
            local body = {}
            local sink = ltn12.sink.table(body)
            client:receivebody(headers, sink)
            local response = table.concat(body)
            local ok, doc = pcall(rjson.parse, response)
            if ok then
                if doc:value(doc:find("error")) then
                    ret = -1
                    err = string.format("InfluxDB server reported errors processing the submission: %s", doc:value(doc:find("error")))
                end
            else
                ret = -1
                err = string.format(
                    "HTTP response didn't contain valid JSON. Status: %d. err: %s",
                    code, tostring(doc))
            end
        else
            client:receivebody(headers, ltn12.sink.null())
        end

        if code > 304 then
            if not err then
                ret = -1
                err = string.format("HTTP response error. Status: %d", code)
            end
            if not save_error_batch(code) then
                print('>>> save_error_batch failed...')
                ret = -3
            end
        end
    end

    if headers.connection == "close" then
        client:close()
        client = nil
    end

    return true, err, ret
end
local psend_request = socket.protect(function(client) return send_request(client) end)


local function send_batch()
    local err
    if not client then
        client, err = pcreate_client()
    end
    if err then
        print('>>> pcreate_client failed...', err)
        return -3, err
    end -- retry indefinitely

    batch:flush()
    local ok, err, ret = psend_request(client)
    if not ok then -- network error
        print('>>> psend_request failed...', err)
        client = nil
        return -3, err
    end
    last_flush = time()
    return ret, err
end

function process_message()
    if not retry then
        local ok, msg = pcall(decode_message, read_message("raw"))
        if not ok then
            return -1, string.format("decode_message failure: %s", tostring(msg))
        end
        if msg.Payload and msg.Fields then
            local tags = {}
            local fields = {}
            for i, field in ipairs(msg.Fields) do
                local key = field.name
                local firstchar = string.sub(key, 1, 1)
                local value = field.value[1]
                if firstchar == '.' then
                    -- ignore hidden fields
                elseif firstchar == '_' then
                    tags[#tags+1] = key .. '=' .. value
                    -- tags[#tags+1] = string.sub(key, 2, -1) .. '=' .. value
                else
                    fields[#fields+1] = encode_field(msg.Payload, key, value)
                end
            end
            if #fields > 0 then
                table.sort(tags)
                table.insert(tags, 1, msg.Payload)
                batch_count = batch_count + 1
                batch:write(table.concat({
                    table.concat(tags, ','),
                    table.concat(fields, ','),
                    math.floor(msg.Timestamp/1e9)
                }, ' ') .. '\n')
            end
        end
    end

    if batch_count == flush_count then
        local ret, err = send_batch()
        if ret == 0  then
            retry = false
            batch_count = 0
            batch:close()
            batch = assert(io.open(batch_file, "w"))
        elseif ret == -3 then
            retry = true
            client = nil
        end
        return ret, err
    end
    return 0
end


function timer_event(ns, shutdown)
    -- flush on shutdown to prevent partial writes
    if shutdown then batch:flush() end

    local timedout = (ns / 1e9 - last_flush) >= ticker_interval
    if (timedout or (shutdown and flush_on_shutdown)) and batch_count > 0 then
        local ret, err = send_batch()
        if ret == 0 then
            retry = false
            batch_count = 0
            batch:close()
            batch = assert(io.open(batch_file, "w"))
            if shutdown then
                -- will empty the batch file if send_batch was successfull
                batch:close()
            end
        end
    end
end
