-- Independent NOOK integration; MIT license. No browser or root required.
local UIManager = require("ui/uimanager")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local InfoMessage = require("ui/widget/infomessage")
local InputDialog = require("ui/widget/inputdialog")
local ConfirmBox = require("ui/widget/confirmbox")
local Menu = require("ui/widget/menu")
local NetworkMgr = require("ui/network/manager")
local util = require("util")
local json = require("json")
local root = debug.getinfo(1, "S").source:gsub("^@", ""):match("^(.*)/") .. "/"
local Client = dofile(root .. "client.lua")
local Archive = WidgetContainer:extend{ name = "nookarchive", is_doc_only = false }

local function message(text)
    UIManager:show(InfoMessage:new{ text = text })
end

function Archive:init()
    self.client = Client.new(root .. "cacert.pem")
    self.options = G_reader_settings:readSetting("nookarchive") or {
        origin = "https://annas-archive.gl",
        directory = "/storage/spsd/NOOK/Books/Downloads",
        extension = "epub",
    }
    self.options.origin = Client.origin(self.options.origin) or "https://annas-archive.gl"
    -- Android's app-private directory; never put the member key on shared storage.
    local ok, android = pcall(require, "android")
    if ok and type(android.dir) == "string" and android.dir:match("^/data/") then
        self.key_path = android.dir .. "/nookarchive-member.json"
        local file = io.open(self.key_path, "rb")
        if file then
            local valid, data = pcall(json.decode, file:read(65536))
            file:close()
            if valid and type(data) == "table" and data.origin == self.options.origin then self.key = data.key end
        end
    end
    self.ui.menu:registerToMainMenu(self)
end

function Archive:save_options()
    G_reader_settings:saveSetting("nookarchive", self.options)
    G_reader_settings:flush()
end

function Archive:set_key(key)
    self.key = key ~= "" and key or nil
    if not self.key then
        if self.key_path then os.remove(self.key_path) end
        return true
    end
    if not self.key_path then return nil end
    local file = io.open(self.key_path, "wb")
    if not file then return nil end
    local written = file:write(json.encode{ origin = self.options.origin, key = self.key })
    local closed = file:close()
    local ffi = require("ffi")
    pcall(ffi.cdef, "int chmod(const char *path, unsigned int mode);")
    local ok, result = pcall(function() return ffi.C.chmod(self.key_path, 384) end)
    if not written or not closed or not ok or result ~= 0 then os.remove(self.key_path); return nil end
    return true
end

function Archive:input(title, initial, callback, secret)
    local dialog
    dialog = InputDialog:new{
        title = title, input = initial or "", text_type = secret and "password" or nil,
        buttons = {{
            { text = "Cancelar", id = "close", callback = function() UIManager:close(dialog) end },
            { text = "Aceptar", is_enter_default = true, callback = function()
                local value = dialog:getInputText()
                UIManager:close(dialog)
                callback(value)
            end },
        }},
    }
    UIManager:show(dialog)
    dialog:onShowKeyboard()
end

function Archive:run(text, operation, completed)
    NetworkMgr:runWhenConnected(function()
        local waiting = InfoMessage:new{ text = text }
        UIManager:show(waiting)
        UIManager:scheduleIn(0.2, function()
            -- Error details and URLs may contain signed download parameters.
            -- Deliberately do not print/log them, even when verbose logging is on.
            local ok, value, err = pcall(operation)
            UIManager:close(waiting)
            if not ok then message("No se pudo completar la operación de red.")
            elseif not value then message(err or "No se pudo completar la operación.")
            else completed(value) end
        end)
    end)
end

function Archive:connection_test()
    self:run("Comprobando HTTPS…", function()
        return self.client:request(self.options.origin .. "/dyn/api/fast_download.json")
    end, function(response)
        message("Dominio: " .. self.options.origin .. "\nHTTPS verificado. HTTP " .. tostring(response.code)
            .. "\nRecibidos: " .. response.bytes .. " bytes.\nEsta prueba no envía el token.")
    end)
end

function Archive:search(query, page)
    if not query or query:match("^%s*$") then return end
    self.last_query = query
    self:run("Buscando en Anna’s Archive…", function()
        return self.client:search(self.options.origin, query, self.options.extension, page)
    end, function(results)
        if #results == 0 then message("Sin resultados. La página también puede haber cambiado de formato."); return end
        local items = {}
        for _, result in ipairs(results) do
            local book = result
            items[#items + 1] = { text = book.title, callback = function() self:choose(book) end }
        end
        items[#items + 1] = { text = "Página siguiente →", callback = function()
            UIManager:close(self.result_menu)
            self:search(query, (page or 1) + 1)
        end }
        self.result_menu = Menu:new{ title = query .. " · " .. tostring(page or 1), item_table = items }
        UIManager:show(self.result_menu)
    end)
end

function Archive:choose(book)
    if self.options.extension == "all" then message("Selecciona EPUB o PDF en los ajustes antes de descargar."); return end
    if not self.key then
        message("Las descargas rápidas requieren un token con membresía activa.\nIntrodúcelo en Anna’s Archive → Token de miembro.\nLa búsqueda no requiere token.")
        return
    end
    UIManager:show(ConfirmBox:new{
        text = book.title .. "\n\n¿Usar una descarga rápida de tu membresía y guardar en\n" .. self.options.directory .. "?",
        ok_text = "Descargar", cancel_text = "Cancelar",
        ok_callback = function()
            self:run("Descargando y verificando el archivo…", function()
                if not util.directoryExists(self.options.directory) then util.makePath(self.options.directory) end
                local address, err = self.client:fast_url(self.options.origin, book.md5, self.key)
                if not address then return nil, err end
                return self.client:download(address, self.options.directory, book.md5, self.options.extension)
            end, function(path)
                UIManager:show(ConfirmBox:new{
                    text = "Descarga completa. MD5 verificado.\n" .. path,
                    ok_text = "Abrir", cancel_text = "Cerrar",
                    ok_callback = function() require("apps/reader/readerui"):showReader(path) end,
                })
            end)
        end,
    })
end

function Archive:addToMainMenu(menu_items)
    menu_items.nookarchive = {
        text = "Anna’s Archive (NOOK)", sorting_hint = "search",
        sub_item_table_func = function()
            return {
                { text = "Buscar libros", callback = function()
                    self:input("Título, autor o ISBN", self.last_query, function(q) self:search(q, 1) end)
                end },
                { text = "Formato: " .. self.options.extension:upper(), callback = function()
                    local next_format = { epub = "pdf", pdf = "all", all = "epub" }
                    self.options.extension = next_format[self.options.extension] or "epub"
                    self:save_options()
                    message("Formato seleccionado: " .. self.options.extension:upper())
                end },
                { text = "Dominio: " .. self.options.origin, callback = function()
                    self:input("Dominio HTTPS · cambiarlo elimina el token", self.options.origin, function(value)
                        local origin = Client.origin(value)
                        if not origin then message("Escribe un dominio HTTPS sin ruta, puerto ni usuario."); return end
                        if origin ~= self.options.origin then self:set_key("") end
                        self.options.origin = origin
                        self:save_options()
                    end)
                end },
                { text = "Carpeta de descargas", callback = function()
                    self:input("Carpeta absoluta para libros", self.options.directory, function(path)
                        if not path:match("^/") or path:find("%z") or (path .. "/"):find("/%.%./") then
                            message("Usa una ruta absoluta sin segmentos '..'."); return
                        end
                        self.options.directory = path:gsub("/+$", "")
                        self:save_options()
                    end)
                end },
                { text = self.key and "Token de miembro: configurado" or "Token de miembro: sin configurar", callback = function()
                    self:input("Token de Anna’s Archive · vacío para borrarlo", "", function(value)
                        value = value:gsub("^%s+", ""):gsub("%s+$", "")
                        local saved = self:set_key(value)
                        if not self.key then message("Token borrado.")
                        elseif saved then message("Token guardado en el directorio privado de KOReader para este dominio.")
                        else message("Token disponible solo durante esta sesión; no se pudo guardar de forma privada.") end
                    end, true)
                end },
                { text = "Comprobar conexión HTTPS", callback = function() self:connection_test() end },
                { text = "Descargar con MD5 conocido", callback = function()
                    self:input("MD5 del enlace /md5/… de Anna’s Archive", "", function(id)
                        id = id:match("/md5/(%x+)") or id:gsub("%s", "")
                        if not Client.md5(id) then message("Se necesitan 32 caracteres hexadecimales."); return end
                        self:choose{ md5 = id:lower(), title = "Archivo " .. id }
                    end)
                end },
            }
        end,
    }
end

return Archive
