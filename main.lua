-- Terminal Táctil REAL para Monitores CC: Tweaked
-- Terminal completamente funcional con shell.execute()

local monitor = peripheral.find("monitor")
if not monitor then
    print("Error: No se encontró monitor")
    return
end

monitor.setTextScale(0.5)
local w, h = monitor.getSize()

-- Variables del sistema
local input = ""
local outputLines = {}
local scrollPos = 0
local maxLines = h - 6
local shift = false
local ctrl = false
local currentDir = shell.dir()

-- Keyboard layout mejorado
local keyboard = {
    {"1","2","3","4","5","6","7","8","9","0","-","="},
    {"q","w","e","r","t","y","u","i","o","p","[","]"},
    {"a","s","d","f","g","h","j","k","l",";","'","\\"},
    {"z","x","c","v","b","n","m",",",".","/"}
}

-- Calcular posiciones automáticamente
local keyWidth = 3
local keySpacing = 1
local startX = 2
local keyboardHeight = 4

local specialKeys = {
    {name="SHIFT", x=1, y=h-1, w=8, color=colors.gray},
    {name="CTRL", x=10, y=h-1, w=6, color=colors.red},
    {name="SPACE", x=17, y=h-1, w=20, color=colors.lightGray},
    {name="ENTER", x=38, y=h-1, w=8, color=colors.green},
    {name="BACK", x=47, y=h-1, w=6, color=colors.orange},
    {name="CTRL+T", x=54, y=h-1, w=7, color=colors.purple}
}

-- Función para ejecutar comandos REALES con shell.execute()
function captureOutput(command)
    -- Redirigir term para capturar output
    local oldTerm = term.current()
    local output = {}
    
    -- Crear mock terminal para capturar
    local mockTerm = {}
    for k, v in pairs(oldTerm) do
        mockTerm[k] = v
    end
    
    -- Sobrescribir funciones de escritura
    mockTerm.write = function(text)
        table.insert(output, tostring(text))
    end
    
    mockTerm.print = function(...)
        local args = {...}
        local line = ""
        for i = 1, #args do
            line = line .. tostring(args[i])
            if i < #args then line = line .. "\t" end
        end
        table.insert(output, line)
    end
    
    mockTerm.blit = function(text, textColors, bgColors)
        table.insert(output, text)
    end
    
    -- Usar el mock terminal
    term.redirect(mockTerm)
    
    -- Ejecutar comando REAL
    local success = shell.execute(command)
    
    -- Restaurar terminal original
    term.redirect(oldTerm)
    
    return output, success
end

-- Función para agregar líneas al output
function addToOutput(lines)
    if type(lines) == "string" then
        lines = {lines}
    end
    
    for _, line in ipairs(lines) do
        -- Dividir líneas largas
        while #line > w do
            table.insert(outputLines, line:sub(1, w))
            line = line:sub(w + 1)
        end
        table.insert(outputLines, line)
    end
    
    -- Mantener un máximo de líneas en memoria
    while #outputLines > 1000 do
        table.remove(outputLines, 1)
    end
    
    -- Auto-scroll al final
    scrollPos = math.max(0, #outputLines - maxLines)
end

-- Función para dibujar tecla mejorada
function drawKey(x, y, key, pressed)
    local bg = pressed and colors.white or colors.lightGray
    local fg = pressed and colors.black or colors.black
    monitor.setBackgroundColor(bg)
    monitor.setTextColor(fg)
    
    -- Dibujar tecla con espacio alrededor
    monitor.setCursorPos(x, y)
    monitor.write("   ")
    monitor.setCursorPos(x + 1, y)
    monitor.write(key:upper())
end

-- Función para dibujar tecla especial
function drawSpecialKey(key, pressed)
    local bg = pressed and colors.white or key.color
    local fg = pressed and colors.black or colors.white
    monitor.setBackgroundColor(bg)
    monitor.setTextColor(fg)
    monitor.setCursorPos(key.x, key.y)
    monitor.write(string.rep(" ", key.w))
    monitor.setCursorPos(key.x + math.floor((key.w - #key.name) / 2), key.y)
    monitor.write(key.name)
end

-- Función para obtener prompt
function getPrompt()
    local user = "user"
    local hostname = "computer"
    return user .. "@" .. hostname .. ":" .. currentDir .. "$ "
end

-- Función para ejecutar comando REAL con shell.execute()
function executeCommand(cmd)
    local prompt = getPrompt()
    addToOutput(prompt .. cmd)
    
    if cmd:trim() == "" then
        return true
    end
    
    -- Comando exit especial
    if cmd == "exit" then
        addToOutput("Cerrando terminal...")
        sleep(1)
        monitor.clear()
        return false
    end
    
    -- Comando clear especial  
    if cmd == "clear" then
        outputLines = {}
        return true
    end
    
    -- Ejecutar comando REAL con shell.execute()
    local output, success = captureOutput(cmd)
    
    -- Mostrar output capturado
    if output and #output > 0 then
        addToOutput(output)
    else
        if success then
            addToOutput("Comando ejecutado")
        else
            addToOutput("Error: No se pudo ejecutar el comando")
        end
    end
    
    -- Actualizar directorio actual
    currentDir = shell.dir()
    
    return true
end
    -- Actualizar directorio actual después de cd
    currentDir = shell.dir()
    
    return true
end

-- Función para dibujar la interfaz
function drawInterface()
    monitor.setBackgroundColor(colors.black)
    monitor.clear()
    
    -- Área de output con scroll
    monitor.setTextColor(colors.white)
    local startLine = scrollPos + 1
    local endLine = math.min(scrollPos + maxLines, #outputLines)
    
    for i = startLine, endLine do
        local line = outputLines[i] or ""
        monitor.setCursorPos(1, i - scrollPos)
        monitor.write(line:sub(1, w))
    end
    
    -- Línea de input actual
    local inputY = math.min(#outputLines - scrollPos + 2, maxLines + 1)
    monitor.setCursorPos(1, inputY)
    monitor.setTextColor(colors.lime)
    local prompt = getPrompt()
    local fullInput = prompt .. input
    
    if #fullInput <= w then
        monitor.write(fullInput)
        -- Cursor
        monitor.setCursorPos(#fullInput + 1, inputY)
        monitor.setTextColor(colors.white)
        monitor.write("_")
    else
        -- Input muy largo, hacer scroll horizontal
        local visibleInput = fullInput:sub(-(w-1))
        monitor.write(visibleInput)
        monitor.setCursorPos(w, inputY)
        monitor.setTextColor(colors.white)
        monitor.write("_")
    end
    
    -- Línea separadora
    monitor.setBackgroundColor(colors.gray)
    monitor.setTextColor(colors.white)
    for x = 1, w do
        monitor.setCursorPos(x, h - 6)
        monitor.write(" ")
    end
    
    -- Info en separador
    monitor.setCursorPos(2, h - 6)
    monitor.write("Terminal - Dir: " .. currentDir:sub(1, 15) .. " - Líneas: " .. #outputLines)
    
    -- Resetear fondo para teclado
    monitor.setBackgroundColor(colors.black)
    
    -- Dibujar teclado con mejor espaciado
    for row = 1, #keyboard do
        local keys = keyboard[row]
        local keyY = h - 5 + row
        local totalKeys = #keys
        local availableWidth = w - 4
        local keySpacing = math.floor(availableWidth / totalKeys)
        
        for i, key in ipairs(keys) do
            local keyX = 2 + (i - 1) * keySpacing
            local displayKey = shift and key:upper() or key
            drawKey(keyX, keyY, displayKey, false)
        end
    end
    
    -- Dibujar teclas especiales
    for _, key in ipairs(specialKeys) do
        local pressed = (key.name == "SHIFT" and shift) or (key.name == "CTRL" and ctrl)
        drawSpecialKey(key, pressed)
    end
end

-- Función principal
function main()
    addToOutput("Terminal CC: Tweaked v2.0 - Real Shell Interface")
    addToOutput("Directorio actual: " .. shell.dir())
    addToOutput("Escriba 'help' para comandos o cualquier comando del sistema")
    addToOutput("Comandos disponibles: ls, cd, edit, delete, copy, move, etc.")
    addToOutput("")
    
    while true do
        drawInterface()
        
        local event, side, x, y = os.pullEvent("monitor_touch")
        
        local clicked = false
        
        -- Detectar scroll en área de output
        if y <= maxLines then
            if y < maxLines / 2 then
                -- Scroll up
                scrollPos = math.max(0, scrollPos - 3)
            else
                -- Scroll down
                scrollPos = math.min(#outputLines - maxLines, scrollPos + 3)
            end
            clicked = true
        end
        
        -- Teclas normales con detección mejorada
        if not clicked then
            for row = 1, #keyboard do
                local keys = keyboard[row]
                local keyY = h - 5 + row
                local totalKeys = #keys
                local availableWidth = w - 4
                local keySpacing = math.floor(availableWidth / totalKeys)
                
                for i, key in ipairs(keys) do
                    local keyX = 2 + (i - 1) * keySpacing
                    
                    -- Detectar click en área de tecla (3 chars de ancho)
                    if x >= keyX and x < keyX + 3 and y == keyY then
                        local char = shift and key:upper() or key
                        input = input .. char
                        clicked = true
                        break
                    end
                end
                if clicked then break end
            end
        end
        
        -- Teclas especiales
        if not clicked then
            for _, key in ipairs(specialKeys) do
                if x >= key.x and x < key.x + key.w and y == key.y then
                    if key.name == "SHIFT" then
                        shift = not shift
                    elseif key.name == "CTRL" then
                        ctrl = not ctrl
                    elseif key.name == "SPACE" then
                        input = input .. " "
                    elseif key.name == "ENTER" then
                        if input:trim() ~= "" then
                            if not executeCommand(input) then
                                return
                            end
                        else
                            addToOutput(getPrompt())
                        end
                        input = ""
                    elseif key.name == "BACK" then
                        if #input > 0 then
                            input = input:sub(1, -2)
                        end
                    elseif key.name == "CTRL+T" then
                        addToOutput("^C")
                        input = ""
                    end
                    clicked = true
                    break
                end
            end
        end
        
        -- Reset modificadores mejorado
        if clicked and not (x >= 1 and x <= 8 and y == h-1) then
            shift = false
        end
        if clicked and not (x >= 10 and x <= 15 and y == h-1) then
            ctrl = false
        end
        
        sleep(0.05)
    end
end

-- String helper
string.trim = function(s)
    return s:match("^%s*(.-)%s*$")
end

-- Iniciar terminal
main()
