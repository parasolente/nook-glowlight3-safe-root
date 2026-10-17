-- Independent, text-first chat for old Android/e-ink; MIT license.
local UIManager = require("ui/uimanager")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local InputDialog = require("ui/widget/inputdialog")
local InfoMessage = require("ui/widget/infomessage")
local TextViewer = require("ui/widget/textviewer")
local ConfirmBox = require("ui/widget/confirmbox")
local NetworkMgr = require("ui/network/manager")
local Trapper = require("ui/trapper")
local root = debug.getinfo(1, "S").source:gsub("^@", ""):match("^(.*)/") .. "/"
local Client = dofile(root .. "client.lua")
local Store = dofile(root .. "store.lua")
local Chat = WidgetContainer:extend{ name = "nookchat", is_doc_only = false }

local function message(text) UIManager:show(InfoMessage:new{ text = text }) end

function Chat:init()
    local saved = Store.read()
    if not saved or Client.base_url(saved.base_url) ~= saved.base_url or not Client.valid_model(saved.model)
        or type(saved.key) ~= "string" or saved.key ~= "" and not Client.valid_key(saved.key) then saved = nil end
    self.config = saved or { base_url = "https://tokenharbor.ai/v1", model = "deepseek-v4-flash", key = "" }
    self.history = {}
    self.client = Client.new(root .. "cacert.pem")
    self.ui.menu:registerToMainMenu(self)
    if self.ui.highlight then
        self.ui.highlight:addToHighlightDialog("12_nookchat", function(highlight)
            return { text = "Preguntar a IA", callback = function()
                local text = highlight.selected_text and highlight.selected_text.text or ""
                text = require("util").cleanupSelectedText(text)
                highlight:onClose()
                if #text > 8000 then message("Selecciona un fragmento más corto (máximo 8 000 bytes)."); return end
                self:compose(text)
            end }
        end)
    end
end

function Chat:input(title, initial, callback, secret, description, accept_text)
    local dialog
    dialog = InputDialog:new{
        title = title, input = initial or "", description = description,
        text_type = secret and "password" or nil, allow_newline = not secret,
        buttons = {{
            { text = "Cancelar", callback = function() UIManager:close(dialog) end },
            { text = accept_text or (secret and "Guardar" or "Aceptar"), is_enter_default = true, callback = function()
                local value = dialog:getInputText()
                UIManager:close(dialog)
                callback(value)
            end },
        }},
    }
    UIManager:show(dialog)
    dialog:onShowKeyboard()
end

function Chat:save_config(config)
    if not Store.write(config) then message("No se pudo guardar en el almacenamiento privado de KOReader."); return end
    self.config = config
    self.history = {}
    return true
end

function Chat:compose(context)
    if not Client.valid_key(self.config.key) then message("Introduce la clave en Asistente IA → Configuración → Clave API."); return end
    local initial = self.draft
    if context and context ~= self.draft_context then initial = "Explica este fragmento en español." end
    self:input(context and "Pregunta sobre la selección" or "Pregunta a la IA",
        initial,
        function(question)
            if question:match("^%s*$") then return end
            self.draft, self.draft_context = question, context
            self:send(question, context)
        end, false,
        "Se enviará al servidor configurado. Requiere Wi-Fi; puede consumir saldo API."
            .. (context and " Incluye solo el fragmento seleccionado." or ""), "Enviar")
end

function Chat:send(question, context)
    if self.busy then return end
    local prompt = context and (question .. "\n\nFragmento seleccionado:\n" .. context) or question
    local valid, err = Client.payload(self.config, self.history, prompt)
    if not valid then message(err); return end
    NetworkMgr:runWhenConnected(function()
        if self.busy then return end
        self.busy = true
        Trapper:wrap(function()
            local completed, result, failure = Trapper:dismissableRunInSubprocess(function()
                local ok, reply, detail = pcall(self.client.chat, self.client, self.config, self.history, prompt)
                if not ok then return nil, "No se pudo completar la consulta." end
                return reply, detail
            end, "Consultando IA…\nToca para cancelar la espera.\nEl proveedor puede haber recibido la consulta.")
            self.busy = false
            if not completed then return end
            if not result then message(failure or "No se recibió una respuesta."); return end
            self.history[#self.history + 1] = { role = "user", content = prompt }
            self.history[#self.history + 1] = { role = "assistant", content = result.text }
            while #self.history > 12 do table.remove(self.history, 1); table.remove(self.history, 1) end
            self.draft, self.draft_context = nil, nil
            self.truncated = result.truncated
            self:show_chat()
        end)
    end)
end

function Chat:show_chat()
    local lines = {}
    for _, item in ipairs(self.history) do
        lines[#lines + 1] = (item.role == "user" and "Tú:\n" or "IA:\n") .. item.content
    end
    if self.truncated then lines[#lines + 1] = "[La última respuesta alcanzó el límite de salida.]" end
    local dialog
    dialog = TextViewer:new{
        title = "Asistente IA · " .. self.config.model, title_multilines = true,
        text = #lines > 0 and table.concat(lines, "\n\n────────\n\n") or "Todavía no hay mensajes. Pulsa Preguntar.",
        text_font_size = 24, show_menu = false,
        buttons_table = {{
            { text = "Cerrar", callback = function() UIManager:close(dialog) end },
            { text = "Preguntar", callback = function() UIManager:close(dialog); self:compose() end },
            { text = "Nueva charla", callback = function()
                UIManager:show(ConfirmBox:new{ text = "¿Borrar esta conversación de la memoria?", ok_callback = function()
                    self.history = {}; self.truncated = nil
                    UIManager:close(dialog); self:compose()
                end })
            end },
        }},
    }
    UIManager:show(dialog)
    -- The latest answer matters most; the viewer still permits earlier pages.
    if #self.history > 2 and dialog.scroll_widget then dialog.scroll_widget:scrollToBottom() end
end

function Chat:addToMainMenu(menu_items)
    menu_items.nookchat = {
        text = "Asistente IA", sorting_hint = "search",
        sub_item_table_func = function()
            return {
                { text = "Conversación / Preguntar", callback = function() self:show_chat() end },
                { text = "Reabrir pregunta pendiente", enabled = self.draft ~= nil, callback = function()
                    self:compose(self.draft_context)
                end },
                { text = "Configuración", sub_item_table_func = function()
                    return {
                        { text = "Servidor: " .. self.config.base_url, callback = function()
                            self:input("Base URL HTTPS · cambiarla elimina la clave", self.config.base_url, function(value)
                                local base = Client.base_url(value)
                                if not base then message("Escribe una base URL HTTPS sin usuario, puerto, consulta ni fragmento."); return end
                                local key = base == self.config.base_url and self.config.key or ""
                                if self:save_config{base_url=base, model=self.config.model, key=key} then message("Servidor guardado.") end
                            end)
                        end },
                        { text = "Modelo: " .. self.config.model, callback = function()
                            self:input("Identificador del modelo", self.config.model, function(value)
                                if not Client.valid_model(value) then message("Identificador de modelo no válido."); return end
                                if self:save_config{base_url=self.config.base_url, model=value, key=self.config.key} then message("Modelo guardado.") end
                            end)
                        end },
                        { text = Client.valid_key(self.config.key) and "Clave API: guardada (cambiar / borrar)" or "Clave API: no configurada", callback = function()
                            self:input("Clave API · vacío para borrar", "", function(value)
                                value = value:gsub("^%s+", ""):gsub("%s+$", "")
                                if value ~= "" and not Client.valid_key(value) then message("La clave contiene espacios o caracteres no válidos."); return end
                                if self:save_config{base_url=self.config.base_url, model=self.config.model, key=value} then message("Configuración privada guardada.") end
                            end, true)
                        end },
                    }
                end },
                { text = "Acerca del asistente", callback = function()
                    message("Chat de texto por HTTPS, sin navegador ni root.\nSolo envía tus preguntas, los últimos mensajes y el fragmento que selecciones explícitamente.\nLa clave queda en datos privados de KOReader. La conversación solo permanece en memoria durante esta sesión. El servicio remoto puede procesar o conservar lo recibido según sus condiciones.")
                end },
            }
        end,
    }
end

return Chat
