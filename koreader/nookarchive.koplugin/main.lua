-- Independent NOOK integration; MIT license. No browser or root required.
local UIManager = require("ui/uimanager")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local InfoMessage = require("ui/widget/infomessage")
local InputDialog = require("ui/widget/inputdialog")
local ConfirmBox = require("ui/widget/confirmbox")
local Menu = require("ui/widget/menu")
local TextViewer = require("ui/widget/textviewer")
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
    self.client:clear_session()
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

function Archive:download_test()
    self:run("Descargando EPUB de prueba sin token…", function()
        if not util.directoryExists(self.options.directory) then util.makePath(self.options.directory) end
        return self.client:download(
            "https://raw.githubusercontent.com/parasolente/nook-glowlight3-safe-root/main/fixtures/nook-archive-test.epub",
            self.options.directory, "e8bb100969e37eb2036eabaf0751de73", "epub")
    end, function(path)
        UIManager:show(ConfirmBox:new{
            text = "Prueba completada. Archivo descargado y MD5 verificado.\nNo se usó el token ni una descarga de tu cuenta.",
            ok_text = "Abrir EPUB", cancel_text = "Cerrar",
            ok_callback = function() require("apps/reader/readerui"):showReader(path) end,
        })
    end)
end

function Archive:search(query, page)
    if not query or query:match("^%s*$") then return end
    self.last_query = query
    self:run("Buscando en Anna’s Archive…", function()
        return self.client:search(self.options.origin, query, self.options.extension, page, self.key)
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
    self:run("Consultando la edición…", function()
        return self.client:details(self.options.origin, book.md5, self.key)
    end, function(details)
        book.title = details.title or book.title
        book.extension = details.extension
        local lines = { book.title }
        for _, field in ipairs({
            {"Autor", details.author}, {"Idioma", details.language}, {"Editorial", details.publisher},
            {"Año", details.year}, {"Edición", details.edition}, {"ISBN-13", details.isbn13},
            {"ISBN-10", details.isbn10}, {"Formato", details.extension ~= "" and details.extension:upper() or nil},
            {"Tamaño", details.bytes and string.format("%.2f MiB", details.bytes / 1048576) or nil},
            {"Páginas", details.pages},
        }) do
            lines[#lines + 1] = field[1] .. ": " .. (field[2] or "No disponible")
        end
        lines[#lines + 1] = "\nSinopsis:\n" .. (details.description or "No disponible en el catálogo.")
        lines[#lines + 1] = "\nDatos proporcionados por el catálogo; comprueba la edición."
        local dialog
        dialog = TextViewer:new{
            title = "Ficha del libro", text = table.concat(lines, "\n"),
            buttons_table = {{
                { text = "Cerrar", callback = function() UIManager:close(dialog) end },
                { text = "Descargar", callback = function()
                    UIManager:close(dialog)
                    self:confirm_download(book)
                end },
            }},
        }
        UIManager:show(dialog)
    end)
end

function Archive:confirm_download(book)
    local extension = book.extension
    if not ({epub=true, pdf=true, mobi=true})[extension] then
        message("Formato no compatible con esta descarga: " .. tostring(extension or "desconocido")); return
    end
    if not self.key then
        message("Las descargas rápidas requieren un token con membresía activa.\nIntrodúcelo en Anna’s Archive → Token de miembro.")
        return
    end
    local target = self.options.directory .. "/" .. book.md5 .. "." .. extension
    if require("libs/libkoreader-lfs").attributes(target) then
        UIManager:show(ConfirmBox:new{
            text = "Este archivo ya está descargado.", ok_text = "Abrir", cancel_text = "Cerrar",
            ok_callback = function() require("apps/reader/readerui"):showReader(target) end,
        })
        return
    end
    UIManager:show(ConfirmBox:new{
        text = book.title .. "\n\n¿Usar una descarga rápida de tu membresía y guardar en\n" .. self.options.directory .. "?",
        ok_text = "Descargar", cancel_text = "Cancelar",
        ok_callback = function()
            self:run("Descargando y verificando el archivo…", function()
                if not util.directoryExists(self.options.directory) then util.makePath(self.options.directory) end
                if require("libs/libkoreader-lfs").attributes(target .. ".partial") then
                    return nil, "Ya existe una descarga parcial de este archivo."
                end
                local address, err = self.client:fast_url(self.options.origin, book.md5, self.key)
                if not address then return nil, err end
                return self.client:download(address, self.options.directory, book.md5, extension)
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
                { text = "Probar descarga sin token", callback = function() self:download_test() end },
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
