-- Independent implementation. MIT license; see repository LICENSE.
local Client = {}
Client.__index = Client

function Client.origin(value)
    value = tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", ""):lower()
    if not value:find("://", 1, true) then value = "https://" .. value end
    local host = value:match("^https://([a-z0-9%.%-]+)/?$")
    if not host or not host:find("%.") or #host > 253 then return nil end
    for label in (host .. "."):gmatch("(.-)%.") do
        if #label < 1 or #label > 63 or not label:match("^[a-z0-9].*[a-z0-9]$") and not label:match("^[a-z0-9]$") then return nil end
    end
    return "https://" .. host
end

function Client.hostname_matches(host, pattern)
    host, pattern = host:lower(), pattern:lower()
    if pattern:find("%z") then return false end
    if host == pattern then return true end
    local suffix = pattern:match("^%*%.(.+)$")
    if not suffix or not suffix:find("%.") then return false end
    local first, rest = host:match("^([^.]+)%.(.+)$")
    return first ~= nil and rest == suffix
end

function Client.encode(text)
    return (text:gsub("([^A-Za-z0-9_%.~%-])", function(c) return string.format("%%%02X", c:byte()) end))
end

function Client.md5(value)
    return type(value) == "string" and #value == 32 and value:match("^%x+$") ~= nil
end

function Client.results(html, decode)
    decode = decode or function(s) return s end
    local results, found = {}, {}
    for attrs, body in html:gmatch("<a%s+([^>]+)>(.-)</a>") do
        local id = attrs:match('href=["\']/md5/(%x+)["\']')
        if Client.md5(id) then
            id = id:lower()
            local title = body:match('data%-content="([^"]+)"')
                or body:gsub("<[^>]+>", " "):gsub("%s+", " ")
            title = decode(title):gsub("^%s+", ""):gsub("%s+$", "")
            if title ~= "" and not found[id] then
                found[id] = true
                results[#results + 1] = { md5 = id, title = title }
            end
        end
    end
    return results
end

function Client.new(ca_file)
    return setmetatable({ ca_file = ca_file }, Client)
end

-- LuaSec validates the chain; this adapter additionally verifies the DNS SAN
-- before LuaSocket can send an HTTP request (including a member key).
function Client:connection(expected_host)
    local socket, ssl = require("socket"), require("ssl")
    local conn = { sock = assert(socket.tcp()) }
    function conn:settimeout(timeout)
        return self.sock:settimeout(math.min(timeout or 12, 12))
    end
    function conn:connect(host, port)
        if host:lower() ~= expected_host then return nil, "Unexpected TLS host" end
        local ok, err = self.sock:connect(host, port)
        if not ok then return nil, err end
        local secured
        secured, err = ssl.wrap(self.sock, {
            mode = "client", protocol = "any", verify = "peer",
            cafile = self.ca_file,
            options = { "all", "no_sslv2", "no_sslv3", "no_tlsv1", "no_tlsv1_1" },
        })
        if not secured then self.sock:close(); return nil, err end
        self.sock = secured
        secured:sni(host)
        secured:settimeout(12)
        ok, err = secured:dohandshake()
        if not ok then secured:close(); return nil, err end
        local cert = secured:getpeercertificate()
        local names = cert and cert:extensions()["2.5.29.17"]
        for _, name in ipairs(names and names.dNSName or {}) do
            if Client.hostname_matches(host, name) then return 1 end
        end
        secured:close()
        return nil, "TLS certificate hostname mismatch"
    end
    conn.ca_file = self.ca_file
    for _, name in ipairs({ "send", "receive", "close", "getfd", "dirty" }) do
        local method = name
        conn[method] = function(self, ...) return self.sock[method](self.sock, ...) end
    end
    return conn
end

function Client:request(address, sink)
    local host = address:match("^https://([a-z0-9%.%-]+)/")
    if not host then return nil, "HTTPS URL required" end
    local http, socketutil = require("socket.http"), require("socketutil")
    local chunks, bytes, start = {}, 0, os.time()
    local function bounded_sink(chunk, err)
        if os.time() - start > 45 then return nil, "Request timeout" end
        if chunk then
            bytes = bytes + #chunk
            if bytes > (sink and 512 * 1024 * 1024 or 4 * 1024 * 1024) then return nil, "Response too large" end
        end
        if sink then return sink(chunk, err) end
        if chunk then chunks[#chunks + 1] = chunk end
        return 1
    end
    socketutil:set_timeout(12, 45)
    local ok, result, code, headers = pcall(http.request, {
        url = address, method = "GET", redirect = false,
        headers = { ["User-Agent"] = "NOOKArchive/0.1 KOReader", ["Accept-Encoding"] = "identity" },
        create = function() return self:connection(host) end,
        sink = bounded_sink,
    })
    socketutil:reset_timeout()
    if not ok or not result then return nil, "HTTPS request failed; check connection or certificate." end
    return { code = tonumber(code), headers = headers or {}, body = table.concat(chunks), bytes = bytes }
end

function Client:search(origin, query, extension, page)
    local url = origin .. "/search?q=" .. Client.encode(query)
        .. "&page=" .. tostring(page or 1)
    if extension ~= "all" then url = url .. "&ext=" .. extension end
    local response, err = self:request(url)
    if not response then return nil, err end
    if response.code ~= 200 then return nil, "Search returned HTTP " .. tostring(response.code) .. "." end
    local lower = response.body:lower()
    if lower:find("/cdn%-cgi/challenge") or lower:find("cf%-chl%-") or lower:find("ddos%-guard") then
        return nil, "The site requires browser verification; no results were downloaded."
    end
    return Client.results(response.body, require("util").htmlEntitiesToUtf8)
end

function Client:fast_url(origin, id, key)
    if not Client.md5(id) or not key or key == "" then return nil, "A member token and valid MD5 are required." end
    -- Do not log this URL or attach the member key to any other request.
    local response, err = self:request(origin .. "/dyn/api/fast_download.json?md5="
        .. id .. "&key=" .. Client.encode(key))
    if not response then return nil, err end
    local ok, data = pcall(require("json").decode, response.body)
    if not ok or type(data) ~= "table" then return nil, "The member API did not return JSON." end
    if response.code ~= 200 or type(data.download_url) ~= "string" then
        return nil, "The member API did not provide a download. Check membership and download allowance."
    end
    if not data.download_url:match("^https://[a-z0-9%.%-]+/") then return nil, "The API did not provide an HTTPS download." end
    return data.download_url
end

function Client:download(address, directory, id, extension)
    local lfs, MD5 = require("libs/libkoreader-lfs"), require("ffi/MD5")
    if not Client.md5(id) or not ({ epub = true, pdf = true, mobi = true })[extension] then
        return nil, "Choose EPUB, PDF or MOBI before downloading."
    end
    local target = directory .. "/" .. id .. "." .. extension
    local partial = target .. ".partial"
    if lfs.attributes(target) or lfs.attributes(partial) then return nil, "The file or its partial download already exists." end
    local function fail(message) os.remove(partial); return nil, message end
    for _ = 1, 5 do
        local file = io.open(partial, "wb")
        if not file then return nil, "Cannot write in the download directory." end
        local response, err = self:request(address, function(chunk)
            if chunk then
                if not file:write(chunk) then return nil, "Storage write failed" end
            end
            return 1
        end)
        local closed = file:close()
        if not response or not closed then return fail(err or "Storage write failed") end
        if response.code == 200 then
            if response.bytes == 0 then return fail("The download is empty.") end
            if MD5.sumFile(partial) ~= id:lower() then return fail("The file does not match the selected MD5; it was discarded.") end
            if lfs.attributes(target) then return fail("Destination appeared during download; nothing was replaced.") end
            if not os.rename(partial, target) then return fail("Cannot finish saving the file.") end
            return target
        end
        local location = response.headers.location
        if not ({ [301] = true, [302] = true, [303] = true, [307] = true, [308] = true })[response.code] or not location then
            return fail("Download returned HTTP " .. tostring(response.code) .. ".")
        end
        address = require("socket.url").absolute(address, location)
        if not address:match("^https://[a-z0-9%.%-]+/") then return fail("An insecure download redirect was refused.") end
    end
    return fail("Too many download redirects.")
end

return Client
