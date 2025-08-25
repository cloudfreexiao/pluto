local skynet = require("skynet")
local cosocket = require("skynet.cosocket")
local http2 = require("http2.init")

local host = "127.0.0.1"
local port = 8080
local sock = cosocket.tcp()
local ok, err = sock:connect(host, port)
if not ok then
    skynet.error("failed to connect ", host, ":", port, ": ", err)
    return
end

local headers = {
    { name = ":authority", value = "test.com" },
    { name = ":method", value = "GET" },
    { name = ":path", value = "/index.html" },
    { name = ":scheme", value = "http" },
    { name = "accept-encoding", value = "gzip" },
    { name = "user-agent", value = "example/client" },
}

local on_headers_reach = function(ctx, headers)
    -- Process the response headers
end

local on_data_reach = function(ctx, data)
    -- Process the response body
end


local opts = {
    ctx = sock,
    recv = sock.receive,
    send = sock.send,
}

local client, err = http2.new(opts)
if not client then
    skynet.error("failed to create HTTP/2 client: ", err)
    return
end

local ok, err = client:request(headers, nil, on_headers_reach, on_data_reach)
if not ok then
    skynet.error("client:process() failed: ", err)
    return
end

sock:close()
sock = nil