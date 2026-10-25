-- Created by: Jexster
-- Do not SELL this fucking SCRIPT IDIOT
-- Rewritten & fixed for broader Lua compatibility
-- Compatible with Lua 5.1+ environments that provide the required game API

-- Konfigurasi
local delay = 30 -- rekomendasi delay 20-50
local backgroundID = 568

-- Jangan ubah bagian ini
local itemStock = {}
local magplants = {}
local totalStock = 0
local currentMagStock = 0
local magplantChecked = 0

-- =========================
-- Helper functions
-- =========================

local function clearTable(tbl)
    if type(tbl) ~= "table" then
        return
    end

    for i = #tbl, 1, -1 do
        tbl[i] = nil
    end
end

local function formatNumber(num)
    local value = tonumber(num) or 0
    if value < 0 then
        return "-" .. formatNumber(math.abs(value))
    end

    local s = tostring(value)
    local result = ""
    local count = 0

    for i = #s, 1, -1 do
        result = s:sub(i, i) .. result
        count = count + 1

        if count % 3 == 0 and i > 1 then
            result = "," .. result
        end
    end

    return result
end

local function parseStockFromDialog(dialog)
    if type(dialog) ~= "string" or dialog == "" then
        return 0
    end

    local patterns = {
        "stock%s*:%s*(%d+)",
        "stock%s*[%:%-]?%s*(%d+)",
        "(%d+)%s*items",
        "(%d+)%s*items%s*in%s*stock"
    }

    for _, pattern in ipairs(patterns) do
        local value = dialog:match(pattern)
        if value then
            return tonumber(value) or 0
        end
    end

    return 0
end

-- =========================
-- Core movement / interaction
-- =========================

function MoveTo(x, y)
    if type(x) ~= "number" or type(y) ~= "number" then
        return false
    end

    SendPacketRaw(false, {
        type = 0,
        state = 32,
        x = x * 32,
        y = y * 32
    })

    Sleep(delay)
    return true
end

function Wrench(x, y)
    if type(x) ~= "number" or type(y) ~= "number" then
        return false
    end

    SendPacketRaw(false, {
        type = 3,
        value = 32,
        px = x,
        py = y,
        x = x * 32,
        y = y * 32
    })

    Sleep(delay)
    return true
end

-- =========================
-- Scan magplant
-- =========================

function scanMagplant()
    LogToConsole("\n`9[SYSTEM] Memulai scan Magplant...")

    clearTable(magplants)

    local count = 0
    local world = GetWorld()

    if not world then
        LogToConsole("`4[SYSTEM] World tidak tersedia!")
        return 0
    end

    for x = 0, world.width - 1 do
        for y = 0, world.height - 1 do
            local tile = GetTile(x, y)
            if tile and tile.fg == 5638 and tile.bg == backgroundID then
                table.insert(magplants, { x = x, y = y })
                count = count + 1
            end
        end
    end

    table.sort(magplants, function(a, b)
        if a.y == b.y then
            return a.x < b.x
        end
        return a.y < b.y
    end)

    LogToConsole("`2[SYSTEM] Total Magplant ditemukan: `9" .. count)
    return count
end

-- =========================
-- Hook dialog stock
-- =========================

AddHook("OnVariant", "magplant_dialog", function(var)
    if type(var) ~= "table" or #var < 2 then
        return false
    end

    if var[1] == "OnDialogRequest" then
        local dialog = var[2]

        if type(dialog) == "string" then
            local lowerDialog = dialog:lower()

            if lowerDialog:find("magplant") then
                local stock = parseStockFromDialog(dialog)

                if stock and stock > 0 then
                    currentMagStock = stock
                    totalStock = totalStock + stock
                else
                    currentMagStock = 0
                end

                return true
            end
        end
    end

    return false
end)

-- =========================
-- Check single magplant
-- =========================

function checkMagplant(magplant, index)
    if not magplant or type(magplant.x) ~= "number" or type(magplant.y) ~= "number" then
        return false
    end

    magplantChecked = index
    currentMagStock = 0

    -- Teleport ke Magplant
    MoveTo(magplant.x, magplant.y)
    Sleep(delay)

    local retries = 3
    local success = false

    for attempt = 1, retries do
        Wrench(magplant.x, magplant.y)
        Sleep(delay)

        SendPacket(2, "action|dialog_return\ndialog_name|magplant_edit\nx|" .. tostring(magplant.x) .. "\ny|" .. tostring(magplant.y))
        Sleep(delay * 8)

        if currentMagStock > 0 then
            success = true
            break
        end
    end

    if success then
        return true
    end

    currentMagStock = 0
    return false
end

-- =========================
-- Main routine
-- =========================

function main()
    LogToConsole("\n`2[SYSTEM] === SCAN MAGPLANT ===")
    LogToConsole("`2[SYSTEM] Waktu: " .. os.date("%Y-%m-%d %H:%M:%S"))

    local localPlayer = GetLocal()
    if localPlayer and localPlayer.name then
        LogToConsole("`2[SYSTEM] User: " .. localPlayer.name .. "\n")
    else
        LogToConsole("`2[SYSTEM] User: Unknown\n")
    end

    totalStock = 0
    local count = scanMagplant()

    if count == 0 then
        LogToConsole("`4[SYSTEM] Tidak ada Magplant ditemukan!")
        return false
    end

    LogToConsole("\n`9[SYSTEM] Mulai mengecek " .. count .. " Magplant...\n")

    for i, magplant in ipairs(magplants) do
        LogToConsole("`9[SYSTEM] Checking Magplant " .. i .. "/" .. count .. " @ (" .. magplant.x .. "," .. magplant.y .. ")")

        local ok = checkMagplant(magplant, i)

        if ok and currentMagStock > 0 then
            LogToConsole("`2[SYSTEM] Magplant " .. i .. " stock: `9" .. formatNumber(currentMagStock))
        else
            LogToConsole("`8[SYSTEM] Magplant " .. i .. " kosong / gagal dibaca")
        end

        Sleep(delay * 8)
    end

    LogToConsole("\n`2[SYSTEM] === HASIL SCAN ===")
    LogToConsole("`2[SYSTEM] Total Magplant: `9" .. count)
    LogToConsole("`2[SYSTEM] Total Stock: `9" .. formatNumber(totalStock))
    LogToConsole("`2[SYSTEM] Scan selesai!")

    return true
end

-- Jalankan script
main()