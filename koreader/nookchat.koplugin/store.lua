-- Only app-private Android storage; never G_reader_settings/shared storage.
local Store = {}

function Store.path()
    local ok, android = pcall(require, "android")
    if ok and type(android.dir) == "string" and android.dir:match("^/data/") then
        return android.dir .. "/nookchat-private.json"
    end
end

function Store.read()
    local path = Store.path()
    if not path then return nil end
    local file = io.open(path, "rb")
    if not file then return nil end
    local raw = file:read(16385)
    file:close()
    if not raw or #raw > 16384 then return nil end
    local ok, value = pcall(require("json").decode, raw)
    if ok and type(value) == "table" then return value end
end

function Store.write(config)
    local path = Store.path()
    if not path then return nil end
    local raw = require("json").encode(config)
    local tmp = path .. ".tmp"
    local file = io.open(tmp, "wb")
    if not file then return nil end
    local ffi = require("ffi")
    pcall(ffi.cdef, "int chmod(const char *path, unsigned int mode);")
    local ok, result = pcall(function() return ffi.C.chmod(tmp, 384) end)
    if not ok or result ~= 0 then file:close(); os.remove(tmp); return nil end
    local written, closed = file:write(raw), file:close()
    if not written or not closed then os.remove(tmp); return nil end
    if not os.rename(tmp, path) then os.remove(tmp); return nil end
    return true
end

return Store
