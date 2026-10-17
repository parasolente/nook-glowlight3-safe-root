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

eq(Client.session_cookie("other=x; Path=/, aa_account_id2=session-value; Expires=Wed, 21 Oct 2030 07:28:00 GMT; HttpOnly"), "aa_account_id2=session-value")
eq(Client.session_cookie({"aa_account_id2=one; Path=/", "aa_other=two; Secure"}), "aa_account_id2=one; aa_other=two")
eq(Client.session_cookie("unrelated=value; Path=/"), nil)
eq(Client.session_cookie('aa_account_id2="unsafe"; Path=/'), nil)
eq(Client.new("test-ca.pem"):request("https://outside.example/", nil, {
    origin="https://annas-archive.gl", cookie="aa_account_id2=example-session",
}), nil)

package.loaded.util = { htmlEntitiesToUtf8 = function(s) return s end }
local authenticated, logins, searches = Client.new("test-ca.pem"), 0, 0
function authenticated:request(address, sink, options)
    eq(address:find("test%+key", 1, true), nil)
    if address == "https://annas-archive.gl/account/" then
        logins = logins + 1
        eq(options.body, "key=test%2Bkey")
        eq(options.cookie, nil)
        return {code=302, headers={["set-cookie"]="aa_account_id2=account-session"}, body=""}
    end
    eq(options.origin, "https://annas-archive.gl")
    eq(options.cookie, "aa_account_id2=account-session")
    searches = searches + 1
    return {code=200, headers={}, body=html}
end
eq(#authenticated:search("https://annas-archive.gl", "example", "epub", 1, "test+key"), 1)
eq(#authenticated:search("https://annas-archive.gl", "example", "epub", 2, "test+key"), 1)
eq(logins, 1)
eq(searches, 2)
eq(authenticated.session.key, nil)
authenticated:clear_session()
eq(authenticated.session, nil)

local expired, renewals, attempts = Client.new("test-ca.pem"), 0, 0
function expired:request(address, sink, options)
    if address:match("/account/$") then
        renewals = renewals + 1
        return {code=302, headers={["set-cookie"]="aa_account_id2=session" .. renewals}, body=""}
    end
    attempts = attempts + 1
    if attempts == 1 then return {code=403, headers={}, body="DDoS-Guard"} end
    eq(options.cookie, "aa_account_id2=session2")
    return {code=200, headers={}, body=html}
end
eq(#expired:search("https://annas-archive.gl", "example", "epub", 1, "test-key"), 1)
eq(renewals, 2)
eq(attempts, 2)

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
print("NOOK Archive: URL, redirect, session, cookie isolation, parser and TLS checks passed")
