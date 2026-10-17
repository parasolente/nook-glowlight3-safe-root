local Client = dofile("koreader/nookarchive.koplugin/client.lua")
local function eq(actual, expected) assert(actual == expected, tostring(actual) .. " ~= " .. tostring(expected)) end
eq(Client.origin(" annas-archive.gl "), "https://annas-archive.gl")
eq(Client.origin("https://ANNAS-ARCHIVE.GL/"), "https://annas-archive.gl")
for _, invalid in ipairs({"http://annas-archive.gl", "https://a.gl/path", "https://a.gl:443", "https://key@a.gl", "https://a..gl", "https://-a.gl", "https://a-.gl", "localhost"}) do
    eq(Client.origin(invalid), nil)
end
eq(Client.hostname_matches("annas-archive.gl", "annas-archive.gl"), true)
eq(Client.hostname_matches("files.example.org", "*.example.org"), true)
eq(Client.hostname_matches("a.files.example.org", "*.example.org"), false)
eq(Client.hostname_matches("example.org", "*.example.org"), false)
eq(Client.hostname_matches("attacker.org", "*.org"), false)
eq(Client.hostname_matches("annas-archive.gl", "annas-archive.gl\0.attacker.org"), false)
eq(Client.encode("a&key=x /"), "a%26key%3Dx%20%2F")
local id = string.rep("a", 32)
eq(Client.md5(id), true)
eq(Client.md5(id .. "a"), false)
eq(Client.md5(string.rep("z", 32)), false)
local html = '<a href="/md5/' .. id .. '"><img src="x"></a>'
    .. '<a class="title" href="/md5/' .. id .. '"><div data-content="Example">Ignored</div></a>'
    .. '<a href="/md5/' .. id .. '">Duplicate</a>'
local books = Client.results(html)
eq(#books, 1)
eq(books[1].md5, id)
eq(books[1].title, "Example")

package.loaded["socket.url"] = { absolute = function(base, destination)
    if destination:sub(1, 1) == "/" then return "https://annas-archive.gl" .. destination end
    return destination
end }
local redirected, requests = Client.new("test-ca.pem"), 0
function redirected:request(address)
    requests = requests + 1
    if requests == 1 then return {code=302, headers={location="/search/?q=test"}} end
    eq(address, "https://annas-archive.gl/search/?q=test")
    return {code=200, headers={}, body="result"}
end
eq(redirected:public_request("https://annas-archive.gl", "https://annas-archive.gl/search?q=test").body, "result")
requests = 0
function redirected:request()
    requests = requests + 1
    return {code=302, headers={location="https://annas-archive.gl.attacker.org/search"}}
end
eq(redirected:public_request("https://annas-archive.gl", "https://annas-archive.gl/search"), nil)
eq(requests, 1)

-- Verify chain validation is requested and a bad DNS SAN fails before HTTP.
local closed, verified = false, false
local fake_socket = { settimeout = function() return 1 end, connect = function() return 1 end,
    close = function() closed = true end }
local fake_tls = { settimeout = function() return 1 end, sni = function() return 1 end,
    dohandshake = function() return 1 end, close = function() closed = true end,
    getpeercertificate = function() return { extensions = function()
        return { ["2.5.29.17"] = { dNSName = {"attacker.org"} } }
    end } end }
package.loaded.socket = { tcp = function() return fake_socket end }
package.loaded.ssl = { wrap = function(_, options)
    verified = options.verify == "peer" and options.cafile == "test-ca.pem"
    return fake_tls
end }
local connection = Client.new("test-ca.pem"):connection("annas-archive.gl")
local connected = connection:connect("annas-archive.gl", 443)
eq(connected, nil)
eq(verified, true)
eq(closed, true)
print("NOOK Archive: URL, redirect, certificate hostname, parser and TLS adapter checks passed")
