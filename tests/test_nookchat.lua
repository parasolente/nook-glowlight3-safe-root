local Client = dofile("koreader/nookchat.koplugin/client.lua")
local function eq(a, b) assert(a == b, tostring(a) .. " ~= " .. tostring(b)) end
eq(Client.base_url(" https://API.Example.org/v1/ "), "https://api.example.org/v1")
eq(Client.base_url("https://api.example.org"), "https://api.example.org")
for _, bad in ipairs({"http://api.example.org/v1", "https://key@api.example.org/v1", "https://api.example.org/v1?key=x",
    "https://api.example.org:443/v1", "https://api.example.org/v1#x", "https://api.example.org/../v1",
    "https://api..example.org/v1", "https://-api.example.org/v1", "https://api.example.org/v1\nHeader: x"}) do
    eq(Client.base_url(bad), nil)
end
eq(Client.hostname_matches("api.example.org", "*.example.org"), true)
eq(Client.hostname_matches("other.api.example.org", "*.example.org"), false)
eq(Client.hostname_matches("example.org", "*.example.org"), false)
eq(Client.hostname_matches("api.example.org", "api.example.org\0.attacker.org"), false)
eq(Client.valid_key("test-key"), true)
eq(not Client.valid_key("test\r\nHeader: x"), true)
eq(Client.valid_model("deepseek-v4-flash"), true)
eq(Client.valid_model("deepseek/model:free"), true)
eq(Client.valid_model("model\nother"), false)
local config = {base_url="https://api.example.org/v1", model="test-model", key="test-key"}
local history = {}
for i = 1, 20 do
    history[#history + 1] = {role="user", content="Question " .. i}
    history[#history + 1] = {role="assistant", content="Answer " .. i}
end
local payload = assert(Client.payload(config, history, "Next"))
eq(payload.model, "test-model")
eq(payload.stream, false)
eq(payload.max_tokens, 1024)
eq(payload.key, nil)
eq(#payload.messages, 14)
eq(payload.messages[2].content, "Question 15")
eq(payload.messages[13].content, "Answer 20")
eq(payload.messages[14].content, "Next")
eq(Client.payload(config, {}, string.rep("a",12001)), nil)
eq(Client.payload(config, {}, "   "), nil)
local huge = {{role="user", content=string.rep("q",20000)}, {role="assistant",content=string.rep("a",20000)}}
eq(#Client.payload(config, huge, "New").messages, 2)
local function decode() return {choices={{message={content="Correct answer"},finish_reason="length"}}} end
local result = assert(Client.parse_response(200, "", decode))
eq(result.text, "Correct answer")
eq(result.truncated, true)
for _, code in ipairs({301,302,401,402,403,404,429,500}) do
    local reply, err = Client.parse_response(code, "private-body-echoed-secret", decode)
    eq(reply, nil)
    eq(type(err), "string")
    eq(err:find("private",1,true), nil)
end
eq(Client.parse_response(200, "", function() error("private error") end), nil)
eq(Client.parse_response(200, "", function() return {choices={{message={content=""}}}} end), nil)

-- Inspect the actual transport boundary: bearer header only, no redirects or retries.
local calls, reset, request = 0, 0
package.loaded.json = {encode=function() return "{test-payload}" end, decode=decode}
package.loaded.ltn12 = {source={string=function(value) eq(value,"{test-payload}"); return function() end end}}
package.loaded.socketutil = {set_timeout=function() end, reset_timeout=function() reset=reset+1 end}
package.loaded["socket.http"] = {request=function(options)
    calls=calls+1; request=options
    eq(options.url,"https://api.example.org/v1/chat/completions")
    eq(options.redirect,false)
    eq(options.method,"POST")
    eq(options.headers.Authorization,"Bearer test-key")
    eq(options.url:find("test-key",1,true),nil)
    options.sink("response")
    return 1,302
end}
local reply = Client.new("ca.pem"):chat(config,{},"Hello")
eq(reply,nil); eq(calls,1); eq(reset,1)
eq(request.headers["Content-Type"],"application/json")
eq(request.sink(string.rep("a",1048577)),nil)
print("NOOK chat validation, context bounds, response handling and transport tests passed.")
