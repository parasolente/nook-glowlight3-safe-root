-- Developer-only, one-shot device provisioning/test bridge. NOT a plugin file.
-- Invoke explicitly from a temporary main.lua copy after Chat:init(), passing
-- a fresh random nonce. Reach only through `adb forward tcp:0 tcp:43851`.
-- No key is embedded in source, shared storage, command-line arguments or logs.
return function(chat, root, nonce)
    local UIManager = require("ui/uimanager")
    local json = require("json")
    local Store = dofile(root .. "store.lua")
    local Client = dofile(root .. "client.lua")
    local result_path = "/sdcard/koreader/nookchat-device-check.json"
    local function report(value)
        local file = io.open(result_path, "wb")
        if file then file:write(json.encode(value)); file:close() end
    end
    UIManager:scheduleIn(0.5, function()
        local listener = require("socket").bind("127.0.0.1", 43851)
        if not listener then report{ok=false,stage="bind"}; return end
        listener:settimeout(30)
        local peer = listener:accept()
        listener:close() -- One attempt, never a persistent service.
        if not peer then report{ok=false,stage="accept"}; return end
        peer:settimeout(10)
        local supplied_nonce = peer:receive(#nonce)
        local length = peer:receive(5)
        length = tonumber(length)
        if supplied_nonce ~= nonce or not length or length < 1 or length > 16000 then peer:close(); return end
        local raw = peer:receive(length)
        local valid, config = pcall(json.decode, raw or "")
        if not valid or type(config) ~= "table" or Client.base_url(config.base_url) ~= config.base_url
            or not Client.valid_model(config.model) or not Client.valid_key(config.key) then
            peer:close(); report{ok=false,stage="input"}; return
        end
        local saved = Store.write{base_url=config.base_url,model=config.model,key=config.key}
        local check = Store.read()
        if not saved or not check or check.key ~= config.key then peer:close(); report{ok=false,stage="save"}; return end
        chat.config = check
        local permissions = require("libs/libkoreader-lfs").attributes(Store.path(), "permissions")
        peer:send("OK\n"); peer:close()
        require("ui/trapper"):wrap(function()
            local completed, reply, err = require("ui/trapper"):dismissableRunInSubprocess(function()
                local ok, value, failure = pcall(chat.client.chat, chat.client, chat.config, {},
                    "Responde en español, en dos frases breves: ¿qué es la tinta electrónica?")
                if not ok then return nil, "Native request failed" end
                return value, failure
            end, "Probando el asistente IA por HTTPS…")
            if not completed or not reply then report{ok=false,stage="chat",error=err}; return end
            chat.history = {
                {role="user",content="¿Qué es la tinta electrónica?"},
                {role="assistant",content=reply.text},
            }
            report{ok=true,stage="chat",permissions=permissions,reply_bytes=#reply.text,truncated=reply.truncated}
            chat:show_chat()
        end)
    end)
end
