-- ==============================================================================
-- Integrated Key System & HWID Lock (GitHub Raw & Auto-Commit REST API)
-- Modular Standalone Version
-- ==============================================================================

local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService     = game:GetService("TweenService")
local CoreGui          = game:GetService("CoreGui")
local StarterGui       = game:GetService("StarterGui")
local HttpService      = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer
if not LocalPlayer then
    pcall(function()
        Players:GetPropertyChangedSignal("LocalPlayer"):Wait()
        LocalPlayer = Players.LocalPlayer
    end)
end

-- ==============================================================================
-- WARZ ANTI-DETECTION & TELEMETRY SHIELD (STEALTH ENGINE)
-- ==============================================================================
pcall(function()
    -- 1. Hook GuiSync Telemetry Remote (Allow server heartbeats, suppress GUI & ESP marks)
    local function IsSafeGuiSyncPayload(payload)
        if type(payload) == "table" and #payload == 1 and type(payload[1]) == "string" and payload[1]:sub(1, 3) == "hb:" then
            return true
        end
        return false
    end

    if hookmetamethod and newcclosure and checkcaller and getnamecallmethod then
        local oldNamecall
        oldNamecall = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
            local method = getnamecallmethod()
            if not checkcaller() and method == "FireServer" and self and self.Name == "GuiSync" then
                local args = {...}
                if not IsSafeGuiSyncPayload(args[1]) then
                    return
                end
            end
            return oldNamecall(self, ...)
        end))
    end

    local bz = ReplicatedStorage:FindFirstChild("BloxZ")
    local guiSync = bz and bz:FindFirstChild("Network") and bz.Network:FindFirstChild("GuiSync")
    if guiSync and hookfunction and newcclosure and checkcaller then
        local oldFireServer
        oldFireServer = hookfunction(guiSync.FireServer, newcclosure(function(self, ...)
            if not checkcaller() then
                local args = {...}
                if not IsSafeGuiSyncPayload(args[1]) then
                    return
                end
            end
            return oldFireServer(self, ...)
        end))
    end

    -- 2. Neutralize WarZCheatTrap Overlay and Attributes
    local function NeutralizeCheatTrap()
        pcall(function()
            local trapScript = LocalPlayer.PlayerScripts:FindFirstChild("WarZCheatTrap")
            if trapScript then
                trapScript.Disabled = true
            end
            local pgui = LocalPlayer:FindFirstChild("PlayerGui")
            if pgui then
                local trapOverlay = pgui:FindFirstChild("WarZCheatTrapOverlay")
                if trapOverlay then trapOverlay:Destroy() end
            end
            local Lighting = game:GetService("Lighting")
            local blur = Lighting:FindFirstChild("WarZCheatTrapBlur")
            if blur then blur:Destroy() end
            local cc = Lighting:FindFirstChild("WarZCheatTrapColor")
            if cc then cc:Destroy() end
            if LocalPlayer:GetAttribute("WarZCheatTrapped") then
                LocalPlayer:SetAttribute("WarZCheatTrapped", false)
            end
        end)
    end

    NeutralizeCheatTrap()
    LocalPlayer:GetAttributeChangedSignal("WarZCheatTrapped"):Connect(function()
        if LocalPlayer:GetAttribute("WarZCheatTrapped") then
            NeutralizeCheatTrap()
        end
    end)
    LocalPlayer.PlayerScripts.ChildAdded:Connect(function(child)
        if child.Name == "WarZCheatTrap" then
            task.defer(function()
                child.Disabled = true
                NeutralizeCheatTrap()
            end)
        end
    end)
end)


-- ══════════════════ KEY SYSTEM MODULE ══════════════════
local KeySystem = {
    CurrentKey = nil,
    ExpireTime = nil,
    ExpireStr = nil,
    IsLifetime = false,
    Verified = false,
    _WatchdogRunning = false,
    _WatermarkGui = nil,
}

KeySystem.Config = {
    HubName = "1000Z Hub",
    Subtitle = "RobloxZ - Visuals & Combat • HWID & Team Lock",

    -- GitHub Raw URL สำหรับดาวน์โหลดรายการคีย์
    KeysUrl = "https://raw.githubusercontent.com/Un1queHUB/1000zwarz/refs/heads/main/1000zkeys.txt",

    -- ตั้งค่า GitHub API สำหรับ Auto-Commit ล็อค HWID
    GitHubOwner = "Un1queHUB",
    GitHubRepo  = "1000zwarz",
    GitHubPath  = "1000zkeys.txt",
    GitHubToken = (function()
        local _k = 92
        local _d = {59, 53, 40, 52, 41, 62, 3, 44, 61, 40, 3, 109, 109, 31, 13, 24, 6, 10, 110, 5, 108, 63, 58, 18, 105, 22, 109, 42, 59, 109, 100, 6, 47, 3, 111, 100, 6, 107, 111, 58, 13, 101, 14, 9, 23, 110, 48, 30, 18, 104, 26, 24, 57, 29, 48, 20, 22, 18, 100, 11, 4, 111, 56, 56, 110, 45, 63, 17, 41, 47, 16, 61, 42, 19, 25, 46, 63, 104, 13, 22, 15, 5, 12, 23, 11, 56, 31, 109, 51, 43, 36, 107, 20}
        local _c = table.create(#_d)
        local _bxor = bit32.bxor
        for _i = 1, #_d do
            _c[_i] = string.char(_bxor(_d[_i], _k))
        end
        return table.concat(_c)
    end)(),

    -- บังคับเฉพาะคีย์ที่ล็อค HWID โดยแอดมินล่วงหน้าหรือไม่ (true = ไม่อนุญาตให้ auto-lock เอง)
    StrictHwidOnly = false,

    -- ชื่อไฟล์สำหรับจำการล็อกอินในเครื่องผู้ใช้
    SaveFileName = "1000Z_SavedKey.json",

    -- ลิงก์สำหรับรับคีย์ (ทิ้งว่างไว้ได้ถ้าไม่มี)
    GetKeyUrl = "",

    -- จำคีย์เพื่อเข้าสู่ระบบอัตโนมัติในครั้งถัดไป
    AutoLogin = true,

    -- ความถี่ในการตรวจสอบคีย์ซ้ำขณะเล่นเกม (วินาที)
    WatchdogInterval = 10,
}

-- ══════════════════ THEME / UI COLORS ══════════════════
local KeyTheme = {
    BG          = Color3.fromRGB(18, 18, 22),
    Header      = Color3.fromRGB(24, 24, 30),
    Card        = Color3.fromRGB(26, 26, 33),
    CardHover   = Color3.fromRGB(34, 34, 42),
    Border      = Color3.fromRGB(48, 48, 58),
    BorderLight = Color3.fromRGB(70, 70, 84),
    Text        = Color3.fromRGB(245, 245, 248),
    TextMuted   = Color3.fromRGB(150, 150, 162),
    Green       = Color3.fromRGB(46, 204, 113),
    GreenHover  = Color3.fromRGB(39, 174, 96),
    Red         = Color3.fromRGB(231, 76, 60),
    RedHover    = Color3.fromRGB(192, 57, 43),
    Yellow      = Color3.fromRGB(241, 196, 15),
    Accent      = Color3.fromRGB(0, 170, 255),
    White       = Color3.fromRGB(255, 255, 255),
}

-- ══════════════════ UI BUILDER HELPERS ══════════════════
local function Create(cls, props)
    local o = Instance.new(cls)
    for k, v in pairs(props or {}) do
        if k ~= "Parent" then o[k] = v end
    end
    if props and props.Parent then o.Parent = props.Parent end
    return o
end

local function RoundCorner(parent, radius)
    return Create("UICorner", {CornerRadius = UDim.new(0, radius or 8), Parent = parent})
end

local function AddStroke(parent, color, thickness)
    return Create("UIStroke", {
        Color = color or KeyTheme.Border,
        Thickness = thickness or 1,
        Parent = parent
    })
end

local function getSafeGuiParent()
    local pgui = (LocalPlayer and (LocalPlayer:FindFirstChildOfClass("PlayerGui") or LocalPlayer:FindFirstChild("PlayerGui")))
    if pgui then
        local sg = pgui:FindFirstChild("WarZ_KeySystem_Billboards")
        if not sg or not sg.Parent then
            sg = Instance.new("ScreenGui")
            sg.Name = "WarZ_KeySystem_Billboards"
            sg.ResetOnSpawn = false
            sg.DisplayOrder = 9999
            sg.IgnoreGuiInset = true
            pcall(function()
                if syn and syn.protect_gui then
                    syn.protect_gui(sg)
                end
            end)
            sg.Parent = pgui
        end
        return sg
    end
    if CoreGui then
        local sg = CoreGui:FindFirstChild("WarZ_KeySystem_Billboards")
        if not sg or not sg.Parent then
            pcall(function()
                sg = Instance.new("ScreenGui")
                sg.Name = "WarZ_KeySystem_Billboards"
                sg.ResetOnSpawn = false
                sg.DisplayOrder = 9999
                sg.IgnoreGuiInset = true
                sg.Parent = CoreGui
            end)
        end
        if sg and sg.Parent then
            return sg
        end
    end
    return CoreGui or workspace
end

-- ══════════════════ BASE64 ENGINE ══════════════════
local b64chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
local b64lookup = {}
for i = 1, #b64chars do
    b64lookup[b64chars:sub(i, i)] = i - 1
end

local function base64Encode(str)
    if crypt and crypt.base64encode then
        local ok, res = pcall(crypt.base64encode, str)
        if ok and res then return res end
    elseif crypt and crypt.base64_encode then
        local ok, res = pcall(crypt.base64_encode, str)
        if ok and res then return res end
    elseif syn and syn.crypt and syn.crypt.base64 and syn.crypt.base64.encode then
        local ok, res = pcall(syn.crypt.base64.encode, str)
        if ok and res then return res end
    elseif base64_encode then
        local ok, res = pcall(base64_encode, str)
        if ok and res then return res end
    end

    local bytes = {str:byte(1, #str)}
    local result = {}
    local pad = 3 - (#bytes % 3)
    if pad == 3 then pad = 0 end
    for i = 1, pad do table.insert(bytes, 0) end
    for i = 1, #bytes, 3 do
        local b1, b2, b3 = bytes[i], bytes[i+1], bytes[i+2]
        local n = (b1 * 65536) + (b2 * 256) + b3
        local c1 = math.floor(n / 262144) % 64 + 1
        local c2 = math.floor(n / 4096) % 64 + 1
        local c3 = math.floor(n / 64) % 64 + 1
        local c4 = n % 64 + 1
        table.insert(result, b64chars:sub(c1, c1))
        table.insert(result, b64chars:sub(c2, c2))
        table.insert(result, b64chars:sub(c3, c3))
        table.insert(result, b64chars:sub(c4, c4))
    end
    local res = table.concat(result)
    if pad > 0 then
        res = res:sub(1, #res - pad) .. string.rep("=", pad)
    end
    return res
end

local function base64Decode(data)
    if crypt and crypt.base64decode then
        local ok, res = pcall(crypt.base64decode, data)
        if ok and res then return res end
    elseif crypt and crypt.base64_decode then
        local ok, res = pcall(crypt.base64_decode, data)
        if ok and res then return res end
    elseif syn and syn.crypt and syn.crypt.base64 and syn.crypt.base64.decode then
        local ok, res = pcall(syn.crypt.base64.decode, data)
        if ok and res then return res end
    elseif base64_decode then
        local ok, res = pcall(base64_decode, data)
        if ok and res then return res end
    end

    data = string.gsub(data, "[^A-Za-z0-9+/=]", "")
    local result = {}
    local len = #data
    local i = 1
    while i <= len do
        local c1 = b64lookup[data:sub(i, i)] or 0
        local c2 = b64lookup[data:sub(i+1, i+1)] or 0
        local c3 = b64lookup[data:sub(i+2, i+2)] or 0
        local c4 = b64lookup[data:sub(i+3, i+3)] or 0

        local pad = 0
        if data:sub(i+2, i+2) == "=" then pad = 2
        elseif data:sub(i+3, i+3) == "=" then pad = 1 end

        local n = (c1 * 262144) + (c2 * 4096) + (c3 * 64) + c4
        local b1 = math.floor(n / 65536) % 256
        local b2 = math.floor(n / 256) % 256
        local b3 = n % 256

        table.insert(result, string.char(b1))
        if pad < 2 then table.insert(result, string.char(b2)) end
        if pad < 1 then table.insert(result, string.char(b3)) end

        i = i + 4
    end
    return table.concat(result)
end

-- ══════════════════ TIME & DATE PROTECTION ENGINE ══════════════════
local function getServerNow()
    local t = nil
    pcall(function()
        if workspace and workspace.GetServerTimeNow then
            t = workspace:GetServerTimeNow()
        end
    end)
    if not t or t <= 0 then
        pcall(function()
            t = os.time()
        end)
    end
    return math.floor(t or 0)
end

local function formatTimestamp(ts)
    local d = nil
    pcall(function()
        d = os.date("!*t", math.floor(ts))
    end)
    if d and d.year and d.month and d.day and d.hour and d.min and d.sec then
        return string.format("%04d-%02d-%02d-%02d:%02d:%02d", d.year, d.month, d.day, d.hour, d.min, d.sec)
    end

    local totalSec = math.max(0, math.floor(ts))
    local totalMin = math.floor(totalSec / 60)
    local sec = totalSec % 60
    local min = totalMin % 60
    local totalHour = math.floor(totalMin / 60)
    local hour = totalHour % 24
    local totalDays = math.floor(totalHour / 24)

    local y = 1970
    while true do
        local isLeap = (y % 4 == 0 and y % 100 ~= 0) or (y % 400 == 0)
        local daysInYear = isLeap and 366 or 365
        if totalDays >= daysInYear then
            totalDays = totalDays - daysInYear
            y = y + 1
        else
            break
        end
    end
    local isLeap = (y % 4 == 0 and y % 100 ~= 0) or (y % 400 == 0)
    local monthDays = {31, isLeap and 29 or 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31}
    local m = 1
    for mi = 1, 12 do
        if totalDays >= monthDays[mi] then
            totalDays = totalDays - monthDays[mi]
            m = m + 1
        else
            break
        end
    end
    local day = totalDays + 1
    return string.format("%04d-%02d-%02d-%02d:%02d:%02d", y, m, day, hour, min, sec)
end

local function parseDateToTimestamp(dateStr)
    if not dateStr or dateStr == "" or string.upper(dateStr) == "LIFETIME" then return nil end
    local y, m, d, h, min, sec = string.match(dateStr, "^(%d%d%d%d)%-(%d%d)%-(%d%d)[%-%s](%d%d):(%d%d):(%d%d)")
    if not (y and m and d and h and min and sec) then
        y, m, d, h, min = string.match(dateStr, "^(%d%d%d%d)%-(%d%d)%-(%d%d)[%-%s](%d%d):(%d%d)")
        sec = 59
    end
    if not (y and m and d and h and min) then return nil end
    y, m, d, h, min, sec = tonumber(y), tonumber(m), tonumber(d), tonumber(h), tonumber(min), tonumber(sec or 0)
    if not (y and m and d and h and min) then return nil end

    local totalDays = 0
    for yr = 1970, y - 1 do
        local isLeap = (yr % 4 == 0 and yr % 100 ~= 0) or (yr % 400 == 0)
        totalDays = totalDays + (isLeap and 366 or 365)
    end
    local isLeap = (y % 4 == 0 and y % 100 ~= 0) or (y % 400 == 0)
    local monthDays = {31, isLeap and 29 or 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31}
    for mi = 1, m - 1 do
        totalDays = totalDays + monthDays[mi]
    end
    totalDays = totalDays + (d - 1)

    return (totalDays * 86400) + (h * 3600) + (min * 60) + (sec or 0)
end

local function getTagDuration(tag)
    if not tag or tag == "" then return -1 end
    tag = string.upper(string.gsub(tag, "%s+", ""))
    if tag == "LIFETIME" or tag == "PERM" or tag == "PERMANENT" then
        return -1
    elseif tag == "1M" then
        return 60
    elseif tag == "1D" then
        return 86400
    elseif tag == "7D" then
        return 604800
    elseif tag == "30D" then
        return 2592000
    end

    local num, unit = string.match(tag, "^(%d+)([MDHS])$")
    if num and unit then
        num = tonumber(num)
        if unit == "M" then return num * 60 end
        if unit == "H" then return num * 3600 end
        if unit == "D" then return num * 86400 end
        if unit == "S" then return num end
    end
    return -1
end

local function formatTimeRemaining(seconds)
    if not seconds or seconds < 0 then
        return "หมดอายุแล้ว"
    end
    if seconds == math.huge or seconds >= 10^9 then
        return "ถาวร (LIFETIME)"
    end

    local days = math.floor(seconds / 86400)
    local hours = math.floor((seconds % 86400) / 3600)
    local mins = math.floor((seconds % 3600) / 60)
    local secs = math.floor(seconds % 60)

    local parts = {}
    if days > 0 then
        table.insert(parts, string.format("%d วัน", days))
    end
    if hours > 0 or days > 0 then
        table.insert(parts, string.format("%d ชั่วโมง", hours))
    end
    if mins > 0 or hours > 0 or days > 0 then
        table.insert(parts, string.format("%d นาที", mins))
    end
    table.insert(parts, string.format("%d วินาที", secs))

    if #parts == 0 then
        return "0 วินาที"
    end
    return table.concat(parts, " ")
end

local function formatTimeCompact(seconds)
    if not seconds or seconds < 0 then return "หมดอายุแล้ว" end
    if seconds == math.huge or seconds >= 10^9 then return "♾️ ถาวร (Lifetime)" end
    local days = math.floor(seconds / 86400)
    local hours = math.floor((seconds % 86400) / 3600)
    local mins = math.floor((seconds % 3600) / 60)
    local secs = math.floor(seconds % 60)
    if days > 0 then
        return string.format("%d วัน %02d:%02d:%02d", days, hours, mins, secs)
    else
        return string.format("%02d:%02d:%02d", hours, mins, secs)
    end
end

local function parseKeyLine(rawLine)
    local line = string.gsub(rawLine or "", "^%s*(.-)%s*$", "%1")
    if line == "" or string.sub(line, 1, 1) == "#" or string.sub(line, 1, 2) == "--" then
        return nil
    end

    local k1, tag1 = string.match(line, "^([^:]+)::([^:]+)$")
    if k1 and tag1 then
        return {
            status = "unbound",
            key = string.gsub(k1, "^%s*(.-)%s*$", "%1"),
            tag = string.gsub(tag1, "^%s*(.-)%s*$", "%1"),
            isLifetime = (string.upper(tag1) == "LIFETIME"),
            raw = line,
        }
    end

    local k2, h2, exp2 = string.match(line, "^([^:]+):([^:]+):(%d%d%d%d%-%d%d%-%d%d[%-%s]%d%d:%d%d.*)$")
    if k2 and h2 and exp2 then
        return {
            status = "bound",
            key = string.gsub(k2, "^%s*(.-)%s*$", "%1"),
            hwid = string.gsub(h2, "^%s*(.-)%s*$", "%1"),
            expireStr = exp2,
            isLifetime = false,
            raw = line,
        }
    end

    local k3, h3, tag3 = string.match(line, "^([^:]+):([^:]+):([%a%d]+)$")
    if k3 and h3 and tag3 and string.upper(tag3) == "LIFETIME" then
        return {
            status = "bound",
            key = string.gsub(k3, "^%s*(.-)%s*$", "%1"),
            hwid = string.gsub(h3, "^%s*(.-)%s*$", "%1"),
            expireStr = "LIFETIME",
            isLifetime = true,
            raw = line,
        }
    end

    local k4, h4 = string.match(line, "^([^:]+):([^:]+)$")
    if k4 and h4 then
        return {
            status = "bound",
            key = string.gsub(k4, "^%s*(.-)%s*$", "%1"),
            hwid = string.gsub(h4, "^%s*(.-)%s*$", "%1"),
            expireStr = "LIFETIME",
            isLifetime = true,
            raw = line,
        }
    end

    if not string.find(line, ":") then
        return {
            status = "unbound",
            key = line,
            tag = "LIFETIME",
            isLifetime = true,
            raw = line,
        }
    end

    return nil
end

-- ══════════════════ HWID & EXECUTOR HELPERS ══════════════════
function KeySystem.GetHWID()
    local hwid = nil
    pcall(function()
        if gethwid then
            hwid = gethwid()
        elseif get_hwid then
            hwid = get_hwid()
        end
    end)
    if not hwid or hwid == "" then
        pcall(function()
            hwid = game:GetService("RbxAnalyticsService"):GetClientId()
        end)
    end
    if not hwid or hwid == "" then
        pcall(function()
            local lp = Players.LocalPlayer
            if lp then hwid = tostring(lp.UserId) end
        end)
    end
    return tostring(hwid or "UNKNOWN-DEVICE-ID")
end

local function compareHWID(savedHwid, currentHwid)
    if not savedHwid or not currentHwid then return false end
    local s = string.lower(string.gsub(tostring(savedHwid), "%s+", ""))
    local c = string.lower(string.gsub(tostring(currentHwid), "%s+", ""))
    if s == c then return true end

    local sClean = s:gsub("[{}]", "")
    local cClean = c:gsub("[{}]", "")
    if sClean == cClean then return true end

    local hexC = ""
    for i = 1, #c do
        hexC = hexC .. string.format("%02x", string.byte(c, i))
    end
    if s == hexC then return true end

    local hexS = ""
    for i = 1, #s do
        hexS = hexS .. string.format("%02x", string.byte(s, i))
    end
    if hexS == c then return true end

    return false
end

local function copyToClipboard(text)
    if setclipboard then
        pcall(setclipboard, text)
    elseif toclipboard then
        pcall(toclipboard, text)
    elseif Clipboard and Clipboard.set then
        pcall(Clipboard.set, text)
    end
end

function KeySystem.CopyHWID()
    local hwid = KeySystem.GetHWID()
    copyToClipboard(hwid)
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = KeySystem.Config.HubName or "Key System",
            Text = "คัดลอก HWID เรียบร้อยแล้ว! นำไปส่งให้แอดมินได้เลย",
            Duration = 3
        })
    end)
    return hwid
end

local function fetchUrl(url)
    local result = nil
    local success = pcall(function()
        result = game:HttpGet(url)
    end)
    if success and result and result ~= "" then
        return result
    end

    local req = (syn and syn.request) or request or http_request or (http and http.request)
    if req then
        local s, r = pcall(function()
            return req({Url = url, Method = "GET"})
        end)
        if s and r and r.Body and r.Body ~= "" then
            return r.Body
        end
    end
    return nil
end

-- ══════════════════ LOCAL SAVE / CACHE ══════════════════
local function saveKeyLocal(fileName, key, hwid, expireTimestamp, expireStr)
    if writefile then
        pcall(function()
            writefile(fileName, HttpService:JSONEncode({
                key = key,
                hwid = hwid,
                expireTimestamp = expireTimestamp,
                expireStr = expireStr,
                savedAt = os.time()
            }))
        end)
    end
end

local function readKeyLocal(fileName)
    if isfile and readfile then
        local ok, res = pcall(function()
            if isfile(fileName) then
                return HttpService:JSONDecode(readfile(fileName))
            end
        end)
        if ok and res and typeof(res) == "table" then
            return res
        end
    end
    return nil
end

function KeySystem.DeleteKeyLocal(fileName)
    fileName = fileName or KeySystem.Config.SaveFileName
    if delfile and isfile then
        pcall(function()
            if isfile(fileName) then
                delfile(fileName)
            end
        end)
    elseif writefile then
        pcall(function()
            writefile(fileName, "")
        end)
    end
end

function KeySystem.Logout()
    KeySystem.DeleteKeyLocal(KeySystem.Config.SaveFileName)
    KeySystem.CurrentKey = nil
    KeySystem.ExpireTime = nil
    KeySystem.ExpireStr = nil
    KeySystem.IsLifetime = false
    KeySystem.Verified = false
    KeySystem._WatchdogRunning = false
    if KeySystem._WatermarkGui then
        pcall(function() KeySystem._WatermarkGui:Destroy() end)
        KeySystem._WatermarkGui = nil
    end
    pcall(function()
        if _G._1000Z_Unload then _G._1000Z_Unload() end
        if _G._1000Z_Window and _G._1000Z_Window.Destroy then _G._1000Z_Window:Destroy() end
        if getgenv().Fluent and getgenv().Fluent.GUI then getgenv().Fluent.GUI:Destroy() end
    end)
end

-- ══════════════════ ONLINE VERIFICATION & HWID BINDING ══════════════════
function KeySystem.VerifyOnline(inputKey, cfg)
    cfg = cfg or KeySystem.Config
    inputKey = string.gsub(inputKey or "", "^%s*(.-)%s*$", "%1")
    if inputKey == "" then
        return false, "กรุณากรอกคีย์ก่อนกดยืนยัน"
    end

    local cleanKey = string.gsub(inputKey, "::.*$", "")
    cleanKey = string.gsub(cleanKey, ":.*$", "")
    cleanKey = string.gsub(cleanKey, "^%s*(.-)%s*$", "%1")

    local myHwid = KeySystem.GetHWID()
    local fileContent = ""
    local fileSha = nil

    local hasToken = (typeof(cfg.GitHubToken) == "string" and cfg.GitHubToken ~= "")
    local req = (syn and syn.request) or request or http_request or (http and http.request)

    if hasToken and req and cfg.GitHubOwner and cfg.GitHubRepo and cfg.GitHubPath then
        local apiUrl = string.format("https://api.github.com/repos/%s/%s/contents/%s", cfg.GitHubOwner, cfg.GitHubRepo, cfg.GitHubPath)
        local ok, resp = pcall(function()
            return req({
                Url = apiUrl,
                Method = "GET",
                Headers = {
                    ["Authorization"] = "Bearer " .. cfg.GitHubToken,
                    ["Accept"] = "application/vnd.github.v3+json",
                    ["User-Agent"] = "UniqueHUB-KeySystem"
                }
            })
        end)
        if ok and resp and resp.Body then
            local jsonOk, data = pcall(function() return HttpService:JSONDecode(resp.Body) end)
            if jsonOk and data and data.sha and data.content then
                fileSha = data.sha
                fileContent = base64Decode(data.content)
            end
        end
    end

    if fileContent == "" and cfg.KeysUrl and cfg.KeysUrl ~= "" then
        local rawUrl = cfg.KeysUrl .. "?t=" .. tostring(os.time())
        fileContent = fetchUrl(rawUrl) or fetchUrl(cfg.KeysUrl) or ""
    end

    if fileContent == "" then
        return false, "ไม่สามารถเชื่อมต่อ GitHub ได้ กรุณาตรวจสอบอินเทอร์เน็ต"
    end

    local lines = {}
    local matchedParsed = nil
    local targetLineIndex = -1

    for line in string.gmatch(fileContent, "[^\r\n]+") do
        table.insert(lines, line)
    end

    for idx, line in ipairs(lines) do
        local parsed = parseKeyLine(line)
        if parsed then
            if parsed.key == cleanKey or parsed.key == inputKey then
                matchedParsed = parsed
                targetLineIndex = idx
                break
            end
        end
    end

    if not matchedParsed then
        return false, "คีย์ไม่ถูกต้อง หรือไม่มีอยู่ในระบบ GitHub"
    end

    -- 1) คีย์ถูกล็อคกับเครื่องไว้แล้ว
    if matchedParsed.status == "bound" then
        if not compareHWID(matchedParsed.hwid, myHwid) then
            return false, "คีย์นี้ถูกใช้งานและล็อคกับเครื่องอื่นไปแล้ว! (HWID Locked)"
        end

        if matchedParsed.isLifetime then
            KeySystem.CurrentKey = matchedParsed.key
            KeySystem.ExpireTime = nil
            KeySystem.ExpireStr = "LIFETIME"
            KeySystem.IsLifetime = true
            KeySystem.Verified = true
            saveKeyLocal(cfg.SaveFileName, matchedParsed.key, myHwid, nil, "LIFETIME")
            return true, "คีย์ถูกต้อง! สิทธิ์ใช้งานแบบถาวร (Lifetime)", math.huge
        else
            local expTs = parseDateToTimestamp(matchedParsed.expireStr)
            local now = getServerNow()

            if not expTs or now >= expTs then
                KeySystem.DeleteKeyLocal(cfg.SaveFileName)
                KeySystem.Verified = false
                return false, "คีย์ของคุณหมดอายุการใช้งานแล้ว! (หมดอายุเมื่อ: " .. tostring(matchedParsed.expireStr) .. ")"
            else
                local remaining = expTs - now
                KeySystem.CurrentKey = matchedParsed.key
                KeySystem.ExpireTime = expTs
                KeySystem.ExpireStr = matchedParsed.expireStr
                KeySystem.IsLifetime = false
                KeySystem.Verified = true
                saveKeyLocal(cfg.SaveFileName, matchedParsed.key, myHwid, expTs, matchedParsed.expireStr)
                return true, "คีย์ถูกต้อง! ยินดีต้อนรับเข้าสู่ระบบ (เหลือเวลา: " .. formatTimeRemaining(remaining) .. ")", remaining
            end
        end
    end

    -- 2) คีย์ใหม่ที่ยังไม่ถูกล็อคเครื่อง (Unbound) -> ทำการล็อค HWID และบันทึกขึ้น GitHub
    if matchedParsed.status == "unbound" then
        if cfg.StrictHwidOnly then
            return false, "คีย์นี้ยังไม่ได้รับการล็อคเครื่อง กรุณาส่ง HWID ให้แอดมินเปิดใช้งาน"
        end

        local duration = getTagDuration(matchedParsed.tag)
        local now = getServerNow()
        local expireTimestamp = KeySystem.ExpireTime or (duration and duration > 0 and (now + duration) or nil)
        local expireDateStr = nil
        local newLine = nil

        if expireTimestamp then
            expireDateStr = formatTimestamp(expireTimestamp)
            newLine = matchedParsed.key .. ":" .. myHwid .. ":" .. expireDateStr
        else
            expireDateStr = "LIFETIME"
            newLine = matchedParsed.key .. ":" .. myHwid .. ":LIFETIME"
        end

        -- เขียนข้อมูลกลับขึ้น GitHub ผ่าน REST API
        if hasToken and req and cfg.GitHubOwner and cfg.GitHubRepo and cfg.GitHubPath then
            local apiErr = nil
            if not fileSha then
                local getUrl = string.format("https://api.github.com/repos/%s/%s/contents/%s", cfg.GitHubOwner, cfg.GitHubRepo, cfg.GitHubPath)
                local gOk, gResp = pcall(function()
                    return req({
                        Url = getUrl,
                        Method = "GET",
                        Headers = {
                            ["Authorization"] = "Bearer " .. cfg.GitHubToken,
                            ["Accept"] = "application/vnd.github.v3+json",
                            ["User-Agent"] = "UniqueHUB-KeySystem"
                        }
                    })
                end)
                if gOk and gResp and gResp.Body then
                    local jOk, d = pcall(function() return HttpService:JSONDecode(gResp.Body) end)
                    if jOk and d and d.sha then
                        fileSha = d.sha
                        if d.content then
                            local fresh = base64Decode(d.content)
                            if fresh and fresh ~= "" then
                                local freshLines = {}
                                for fl in string.gmatch(fresh, "[^\r\n]+") do table.insert(freshLines, fl) end
                                for fIdx, fl in ipairs(freshLines) do
                                    local p = parseKeyLine(fl)
                                    if p and (p.key == matchedParsed.key) then
                                        targetLineIndex = fIdx
                                        lines = freshLines
                                        break
                                    end
                                end
                            end
                        end
                    else
                        apiErr = d and d.message or gResp.Body
                    end
                else
                    apiErr = gResp and gResp.Body or "เชื่อมต่อ GitHub ไม่สำเร็จ"
                end
            end

            if not fileSha then
                return false, "ไม่สามารถอ่านไฟล์คีย์จาก GitHub ได้ (Token ผิดหรือหมดอายุ): " .. tostring(apiErr or "401 Bad credentials")
            end

            lines[targetLineIndex] = newLine
            local newContent = table.concat(lines, "\n")
            local newBase64 = base64Encode(newContent)

            local putUrl = string.format("https://api.github.com/repos/%s/%s/contents/%s", cfg.GitHubOwner, cfg.GitHubRepo, cfg.GitHubPath)
            local putOk, putResp = pcall(function()
                return req({
                    Url = putUrl,
                    Method = "PUT",
                    Headers = {
                        ["Authorization"] = "Bearer " .. cfg.GitHubToken,
                        ["Accept"] = "application/vnd.github.v3+json",
                        ["User-Agent"] = "UniqueHUB-KeySystem",
                        ["Content-Type"] = "application/json"
                    },
                    Body = HttpService:JSONEncode({
                        message = "Auto-Lock Key " .. matchedParsed.key .. " to HWID " .. myHwid .. " (" .. (expireDateStr or "LIFETIME") .. ")",
                        content = newBase64,
                        sha = fileSha
                    })
                })
            end)

            if putOk and putResp and (putResp.StatusCode == 200 or putResp.StatusCode == 201) then
                KeySystem.CurrentKey = matchedParsed.key
                KeySystem.ExpireTime = expireTimestamp
                KeySystem.ExpireStr = expireDateStr
                KeySystem.IsLifetime = (duration == nil or duration <= 0)
                KeySystem.Verified = true
                saveKeyLocal(cfg.SaveFileName, matchedParsed.key, myHwid, expireTimestamp, expireDateStr)

                local successMsg = KeySystem.IsLifetime
                    and "คีย์ถูกต้อง! สิทธิ์ใช้งานถาวร (บันทึกล็อคเครื่องขึ้น GitHub เรียบร้อย)"
                    or ("คีย์ถูกต้อง! เปิดใช้งานสำเร็จ (หมดอายุ: " .. expireDateStr .. ")")
                return true, successMsg, (duration and duration > 0 and duration or math.huge)
            else
                local errDetail = putResp and (putResp.Body or putResp.StatusCode) or "เกิดข้อผิดพลาดในการบันทึก"
                warn("[KeySystem] เกิดข้อผิดพลาดในการ Auto-Commit ขึ้น GitHub:", errDetail)
                return false, "Auto-Commit ล้มเหลว! (ไม่สามารถบันทึก HWID ขึ้น GitHub ได้): " .. tostring(errDetail)
            end
        end

        KeySystem.CurrentKey = matchedParsed.key
        KeySystem.ExpireTime = expireTimestamp
        KeySystem.ExpireStr = expireDateStr
        KeySystem.IsLifetime = (duration == nil or duration <= 0)
        KeySystem.Verified = true
        saveKeyLocal(cfg.SaveFileName, matchedParsed.key, myHwid, expireTimestamp, expireDateStr)

        local successMsg = KeySystem.IsLifetime
            and "คีย์ถูกต้อง! ยินดีต้อนรับเข้าสู่ระบบ (สิทธิ์ถาวร)"
            or ("คีย์ถูกต้อง! ยินดีต้อนรับเข้าสู่ระบบ (หมดอายุ: " .. (expireDateStr or "N/A") .. ")")
        return true, successMsg, (duration and duration > 0 and duration or math.huge)
    end

    return false, "เกิดข้อผิดพลาดในการตรวจสอบคีย์"
end

-- ══════════════════ IN-GAME WATERMARK HUD (REAL-TIME COUNTDOWN) ══════════════════
function KeySystem.CreateWatermark(cfg)
    cfg = cfg or KeySystem.Config
    if KeySystem._WatermarkGui then
        pcall(function() KeySystem._WatermarkGui:Destroy() end)
        KeySystem._WatermarkGui = nil
    end
    pcall(function()
        if _G._1000Z_Unload then _G._1000Z_Unload() end
        if _G._1000Z_Window and _G._1000Z_Window.Destroy then _G._1000Z_Window:Destroy() end
        if getgenv().Fluent and getgenv().Fluent.GUI then getgenv().Fluent.GUI:Destroy() end
    end)

    local GuiParent = getSafeGuiParent()
    local wmGui = Create("ScreenGui", {
        Name = "WarZ_TimeWatermark",
        ResetOnSpawn = false,
        DisplayOrder = 999999,
        IgnoreGuiInset = true,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        Parent = GuiParent,
    })
    KeySystem._WatermarkGui = wmGui

    local wmFrame = Create("Frame", {
        Name = "WatermarkFrame",
        Size = UDim2.new(0, 310, 0, 36),
        Position = UDim2.new(0.5, -155, 0, 14),
        BackgroundColor3 = Color3.fromRGB(15, 15, 22),
        BackgroundTransparency = 0.15,
        BorderSizePixel = 0,
        ZIndex = 100,
        Parent = wmGui,
    })
    RoundCorner(wmFrame, 9)
    AddStroke(wmFrame, KeyTheme.BorderLight or KeyTheme.Border, 1.5)

    local dot = Create("Frame", {
        Size = UDim2.new(0, 10, 0, 10),
        Position = UDim2.new(0, 12, 0.5, -5),
        BackgroundColor3 = KeyTheme.Green,
        BorderSizePixel = 0,
        ZIndex = 101,
        Parent = wmFrame,
    })
    RoundCorner(dot, 5)

    local wmLabel = Create("TextLabel", {
        Text = (cfg.HubName or "VIP") .. " | ⏳ กำลังคำนวณเวลา...",
        Font = Enum.Font.GothamBold,
        TextSize = 12,
        TextColor3 = KeyTheme.Text,
        TextXAlignment = Enum.TextXAlignment.Left,
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 30, 0, 0),
        Size = UDim2.new(1, -35, 1, 0),
        ZIndex = 101,
        Parent = wmFrame,
    })

    local dragging, dragStart, startPos = false, nil, nil
    wmFrame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = wmFrame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)
    wmFrame.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            if dragging and dragStart then
                local delta = input.Position - dragStart
                wmFrame.Position = UDim2.new(
                    startPos.X.Scale, startPos.X.Offset + delta.X,
                    startPos.Y.Scale, startPos.Y.Offset + delta.Y
                )
            end
        end
    end)

    task.spawn(function()
        while wmGui and wmGui.Parent and KeySystem.Verified do
            if KeySystem.ExpireTime and KeySystem.ExpireTime > 0 and not KeySystem.IsLifetime then
                local now = getServerNow()
                local diff = KeySystem.ExpireTime - now
                if diff <= 0 then
                    wmLabel.Text = (cfg.HubName or "VIP") .. " | ⚠️ คีย์หมดอายุแล้ว!"
                    wmLabel.TextColor3 = KeyTheme.Red
                    dot.BackgroundColor3 = KeyTheme.Red
                else
                    wmLabel.Text = (cfg.HubName or "VIP") .. " | ⏳ เหลือ: " .. formatTimeCompact(diff)
                    wmLabel.TextColor3 = KeyTheme.Green
                    dot.BackgroundColor3 = KeyTheme.Green
                end
            elseif KeySystem.IsLifetime then
                wmLabel.Text = (cfg.HubName or "VIP") .. " | ♾️ ถาวร (LIFETIME)"
                wmLabel.TextColor3 = KeyTheme.Accent
                dot.BackgroundColor3 = KeyTheme.Accent
            end
            task.wait(1)
        end
    end)
end

-- ══════════════════ KEY SYSTEM UI ══════════════════
function KeySystem.OpenUI(cfg, onSuccessCallback)
    cfg = cfg or KeySystem.Config

    local GuiParent = getSafeGuiParent()

    local guiName = "WarZ_" .. (cfg.HubName or "Hub"):gsub("%s+", "") .. "_KeyGUI"
    pcall(function()
        local old = GuiParent:FindFirstChild(guiName)
        if old then old:Destroy() end
    end)

    local KeyScreen = Create("ScreenGui", {
        Name = guiName,
        ResetOnSpawn = false,
        DisplayOrder = 2000,
        Parent = GuiParent,
    })

    local KeyWindow = Create("Frame", {
        Name = "KeyWindow",
        Size = UDim2.new(0, 400, 0, 485),
        Position = UDim2.new(0.5, -200, 0.5, -242),
        BackgroundColor3 = KeyTheme.BG,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        Parent = KeyScreen,
    })
    RoundCorner(KeyWindow, 12)
    AddStroke(KeyWindow, KeyTheme.Border, 1)

    -- Header
    local KeyHeader = Create("Frame", {
        Size = UDim2.new(1, 0, 0, 48),
        BackgroundColor3 = KeyTheme.Header,
        BorderSizePixel = 0,
        Parent = KeyWindow,
    })
    RoundCorner(KeyHeader, 12)
    Create("Frame", {
        Size = UDim2.new(1, 0, 0, 12),
        Position = UDim2.new(0, 0, 1, -12),
        BackgroundColor3 = KeyTheme.Header,
        BorderSizePixel = 0,
        Parent = KeyHeader,
    })

    local KeyDot = Create("Frame", {
        Size = UDim2.new(0, 10, 0, 10),
        Position = UDim2.new(0, 14, 0.5, -5),
        BackgroundColor3 = KeyTheme.Yellow,
        BorderSizePixel = 0,
        Parent = KeyHeader,
    })
    RoundCorner(KeyDot, 5)

    Create("TextLabel", {
        Text = cfg.HubName or "Key System",
        Font = Enum.Font.GothamBold,
        TextSize = 14,
        TextColor3 = KeyTheme.White,
        TextXAlignment = Enum.TextXAlignment.Left,
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 32, 0, 6),
        Size = UDim2.new(0, 220, 0, 20),
        Parent = KeyHeader,
    })

    Create("TextLabel", {
        Text = cfg.Subtitle or "VISUALS & COMBAT • TIME-LIMITED KEY",
        Font = Enum.Font.Gotham,
        TextSize = 10,
        TextColor3 = KeyTheme.TextMuted,
        TextXAlignment = Enum.TextXAlignment.Left,
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 32, 0, 26),
        Size = UDim2.new(0, 260, 0, 16),
        Parent = KeyHeader,
    })

    local KeyCloseBtn = Create("TextButton", {
        Text = "✕",
        Font = Enum.Font.GothamBold,
        TextSize = 12,
        TextColor3 = KeyTheme.TextMuted,
        BackgroundColor3 = Color3.fromRGB(34, 34, 42),
        Size = UDim2.new(0, 28, 0, 28),
        Position = UDim2.new(1, -34, 0.5, -14),
        AutoButtonColor = false,
        Parent = KeyHeader,
    })
    RoundCorner(KeyCloseBtn, 6)
    KeyCloseBtn.MouseButton1Click:Connect(function()
        KeyScreen:Destroy()
    end)

    -- Body Container
    local KeyBody = Create("Frame", {
        Size = UDim2.new(1, -28, 1, -62),
        Position = UDim2.new(0, 14, 0, 56),
        BackgroundTransparency = 1,
        Parent = KeyWindow,
    })

    Create("TextLabel", {
        Text = "🔐  ระบบยืนยันตัวตน (Key System)",
        Font = Enum.Font.GothamBold,
        TextSize = 14,
        TextColor3 = KeyTheme.White,
        TextXAlignment = Enum.TextXAlignment.Center,
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 0, 0, 2),
        Size = UDim2.new(1, 0, 0, 20),
        Parent = KeyBody,
    })

    Create("TextLabel", {
        Text = "คีย์จะถูกล็อคติดเครื่อง 1 คีย์ใช้งานได้แค่ 1 เครื่อง ป้องกันการส่งต่อ",
        Font = Enum.Font.Gotham,
        TextSize = 11,
        TextColor3 = KeyTheme.TextMuted,
        TextXAlignment = Enum.TextXAlignment.Center,
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 0, 0, 22),
        Size = UDim2.new(1, 0, 0, 16),
        Parent = KeyBody,
    })

    local KeyInputCard = Create("Frame", {
        Size = UDim2.new(1, 0, 0, 42),
        Position = UDim2.new(0, 0, 0, 44),
        BackgroundColor3 = KeyTheme.Card,
        BorderSizePixel = 0,
        Parent = KeyBody,
    })
    RoundCorner(KeyInputCard, 8)
    AddStroke(KeyInputCard, KeyTheme.Border, 1)

    local KeyInput = Create("TextBox", {
        PlaceholderText = "กรอกคีย์ของคุณที่นี่ (เช่น PS-KEY-xxxx)...",
        PlaceholderColor3 = KeyTheme.TextMuted,
        Text = "",
        Font = Enum.Font.GothamBold,
        TextSize = 12,
        TextColor3 = KeyTheme.White,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, -20, 1, 0),
        Position = UDim2.new(0, 10, 0, 0),
        ClearTextOnFocus = false,
        Parent = KeyInputCard,
    })

    local TimeCard = Create("Frame", {
        Size = UDim2.new(1, 0, 0, 52),
        Position = UDim2.new(0, 0, 0, 94),
        BackgroundColor3 = KeyTheme.Card,
        BorderSizePixel = 0,
        Parent = KeyBody,
    })
    RoundCorner(TimeCard, 8)
    AddStroke(TimeCard, KeyTheme.Border, 1)

    Create("TextLabel", {
        Text = "⏱️ สถานะอายุการใช้งาน (Remaining Time):",
        Font = Enum.Font.GothamBold,
        TextSize = 11,
        TextColor3 = KeyTheme.TextMuted,
        TextXAlignment = Enum.TextXAlignment.Left,
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 12, 0, 6),
        Size = UDim2.new(1, -24, 0, 16),
        Parent = TimeCard,
    })

    local TimeCountdownLabel = Create("TextLabel", {
        Text = "รอการตรวจสอบคีย์",
        Font = Enum.Font.GothamBold,
        TextSize = 12,
        TextColor3 = KeyTheme.Accent,
        TextXAlignment = Enum.TextXAlignment.Left,
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 12, 0, 24),
        Size = UDim2.new(1, -24, 0, 20),
        Parent = TimeCard,
    })

    local HwidCard = Create("Frame", {
        Size = UDim2.new(1, 0, 0, 74),
        Position = UDim2.new(0, 0, 0, 154),
        BackgroundColor3 = KeyTheme.Card,
        BorderSizePixel = 0,
        Parent = KeyBody,
    })
    RoundCorner(HwidCard, 8)
    AddStroke(HwidCard, KeyTheme.Border, 1)

    Create("TextLabel", {
        Text = "💻 รหัสเครื่องของคุณ (Hardware ID):",
        Font = Enum.Font.GothamBold,
        TextSize = 11,
        TextColor3 = KeyTheme.TextMuted,
        TextXAlignment = Enum.TextXAlignment.Left,
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 12, 0, 6),
        Size = UDim2.new(1, -24, 0, 16),
        Parent = HwidCard,
    })

    local myHwidStr = KeySystem.GetHWID()
    local displayHwid = string.sub(myHwidStr, 1, 24) .. (string.len(myHwidStr) > 24 and "..." or "")

    Create("TextLabel", {
        Text = displayHwid,
        Font = Enum.Font.Code,
        TextSize = 11,
        TextColor3 = KeyTheme.Accent,
        TextXAlignment = Enum.TextXAlignment.Left,
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 12, 0, 24),
        Size = UDim2.new(1, -125, 0, 20),
        Parent = HwidCard,
    })

    local CopyHwidBtn = Create("TextButton", {
        Text = "📋 คัดลอก HWID",
        Font = Enum.Font.GothamBold,
        TextSize = 11,
        TextColor3 = KeyTheme.White,
        BackgroundColor3 = KeyTheme.CardHover,
        Size = UDim2.new(0, 105, 0, 26),
        Position = UDim2.new(1, -117, 0, 21),
        AutoButtonColor = false,
        Parent = HwidCard,
    })
    RoundCorner(CopyHwidBtn, 6)
    CopyHwidBtn.MouseButton1Click:Connect(function()
        KeySystem.CopyHWID()
        CopyHwidBtn.Text = "✓ คัดลอกแล้ว!"
        CopyHwidBtn.BackgroundColor3 = KeyTheme.Green
        task.delay(1.5, function()
            CopyHwidBtn.Text = "📋 คัดลอก HWID"
            CopyHwidBtn.BackgroundColor3 = KeyTheme.CardHover
        end)
    end)

    Create("TextLabel", {
        Text = "หากคีย์ติดล็อคเครื่อง ให้ส่ง HWID นี้ให้แอดมินเพื่อรีเซ็ตหรือปลดล็อค",
        Font = Enum.Font.Gotham,
        TextSize = 10,
        TextColor3 = Color3.fromRGB(130, 130, 145),
        TextXAlignment = Enum.TextXAlignment.Left,
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 12, 0, 48),
        Size = UDim2.new(1, -24, 0, 16),
        Parent = HwidCard,
    })

    local KeyStatusMsg = Create("TextLabel", {
        Text = "พร้อมตรวจสอบคีย์",
        Font = Enum.Font.Gotham,
        TextSize = 11,
        TextColor3 = KeyTheme.TextMuted,
        TextXAlignment = Enum.TextXAlignment.Center,
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 0, 0, 236),
        Size = UDim2.new(1, 0, 0, 22),
        Parent = KeyBody,
    })

    local SubmitBtn = Create("TextButton", {
        Text = "✓  ยืนยันคีย์ (SUBMIT KEY)",
        Font = Enum.Font.GothamBold,
        TextSize = 13,
        TextColor3 = KeyTheme.White,
        BackgroundColor3 = KeyTheme.Green,
        Size = UDim2.new(1, 0, 0, 42),
        Position = UDim2.new(0, 0, 0, 264),
        AutoButtonColor = false,
        Parent = KeyBody,
    })
    RoundCorner(SubmitBtn, 8)

    local isChecking = false
    SubmitBtn.MouseButton1Click:Connect(function()
        if isChecking then return end
        local input = KeyInput.Text
        if input == "" then
            KeyStatusMsg.Text = "✗ กรุณากรอกคีย์ก่อนกดยืนยัน"
            KeyStatusMsg.TextColor3 = KeyTheme.Red
            return
        end

        isChecking = true
        SubmitBtn.Text = "⏳ กำลังตรวจสอบและล็อค HWID..."
        SubmitBtn.BackgroundColor3 = KeyTheme.CardHover
        KeyStatusMsg.Text = "กำลังติดต่อระบบ GitHub เพื่อยืนยัน..."
        KeyStatusMsg.TextColor3 = KeyTheme.Yellow
        KeyDot.BackgroundColor3 = KeyTheme.Yellow

        task.spawn(function()
            local success, msg, remaining = KeySystem.VerifyOnline(input, cfg)
            isChecking = false

            if success then
                KeyStatusMsg.Text = "✓ " .. msg
                KeyStatusMsg.TextColor3 = KeyTheme.Green
                KeyDot.BackgroundColor3 = KeyTheme.Green
                SubmitBtn.Text = "✓ สำเร็จ! กำลังเปิดโปรแกรม..."
                SubmitBtn.BackgroundColor3 = KeyTheme.Green

                pcall(function()
                    local noteText = KeySystem.IsLifetime
                        and "ยืนยันคีย์สำเร็จ! สิทธิ์การใช้งานถาวร"
                        or ("ยืนยันคีย์สำเร็จ! เหลือเวลา: " .. formatTimeRemaining(remaining or 0))
                    StarterGui:SetCore("SendNotification", {
                        Title = cfg.HubName or "Key System",
                        Text = noteText,
                        Duration = 4
                    })
                end)

                task.wait(0.8)
                KeyScreen:Destroy()

                if onSuccessCallback then
                    KeySystem._ActiveAuthToken = tostring(os.clock()) .. '_' .. tostring(math.random(100000, 999999))
                    task.spawn(onSuccessCallback, KeySystem._ActiveAuthToken)
                end
            else
                KeyStatusMsg.Text = "✗ " .. msg
                KeyStatusMsg.TextColor3 = KeyTheme.Red
                KeyDot.BackgroundColor3 = KeyTheme.Red
                SubmitBtn.Text = "✓  ยืนยันคีย์ (SUBMIT KEY)"
                SubmitBtn.BackgroundColor3 = KeyTheme.Green
            end
        end)
    end)

    local PasteRow = Create("Frame", {
        Size = UDim2.new(1, 0, 0, 28),
        Position = UDim2.new(0, 0, 0, 314),
        BackgroundTransparency = 1,
        Parent = KeyBody,
    })
    Create("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        Padding = UDim.new(0, 6),
        Parent = PasteRow,
    })

    local hasGetKey = (typeof(cfg.GetKeyUrl) == "string" and cfg.GetKeyUrl ~= "")
    local btnWidthScale = hasGetKey and 0.315 or 0.485

    local PasteBtn = Create("TextButton", {
        Text = "📋 วางคีย์",
        Font = Enum.Font.Gotham,
        TextSize = 11,
        TextColor3 = KeyTheme.TextMuted,
        BackgroundColor3 = KeyTheme.Card,
        Size = UDim2.new(btnWidthScale, 0, 1, 0),
        AutoButtonColor = false,
        Parent = PasteRow,
    })
    RoundCorner(PasteBtn, 6)

    local ClearBtn = Create("TextButton", {
        Text = "🗑 ล้าง",
        Font = Enum.Font.Gotham,
        TextSize = 11,
        TextColor3 = KeyTheme.TextMuted,
        BackgroundColor3 = KeyTheme.Card,
        Size = UDim2.new(btnWidthScale, 0, 1, 0),
        AutoButtonColor = false,
        Parent = PasteRow,
    })
    RoundCorner(ClearBtn, 6)

    PasteBtn.MouseButton1Click:Connect(function()
        if getclipboard then
            pcall(function() KeyInput.Text = getclipboard() end)
        end
    end)
    ClearBtn.MouseButton1Click:Connect(function()
        KeyInput.Text = ""
    end)

    if hasGetKey then
        local GetKeyBtn = Create("TextButton", {
            Text = "🔑 รับคีย์",
            Font = Enum.Font.Gotham,
            TextSize = 11,
            TextColor3 = KeyTheme.Yellow,
            BackgroundColor3 = KeyTheme.Card,
            Size = UDim2.new(btnWidthScale, 0, 1, 0),
            AutoButtonColor = false,
            Parent = PasteRow,
        })
        RoundCorner(GetKeyBtn, 6)
        GetKeyBtn.MouseButton1Click:Connect(function()
            copyToClipboard(cfg.GetKeyUrl)
            GetKeyBtn.Text = "✓ คัดลอกแล้ว"
            pcall(function()
                StarterGui:SetCore("SendNotification", {
                    Title = cfg.HubName or "Key System",
                    Text = "คัดลอกลิงก์รับคีย์แล้ว นำไปวางในเบราว์เซอร์ได้เลย",
                    Duration = 4
                })
            end)
            task.delay(1.5, function()
                GetKeyBtn.Text = "🔑 รับคีย์"
            end)
        end)
    end

    -- Footer
    Create("TextLabel", {
        Text = (cfg.HubName or "Unique HUB") .. " • GitHub REST Verified • HWID Locked",
        Font = Enum.Font.Gotham,
        TextSize = 10,
        TextColor3 = Color3.fromRGB(110, 110, 125),
        TextXAlignment = Enum.TextXAlignment.Center,
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 0, 0, 355),
        Size = UDim2.new(1, 0, 0, 16),
        Parent = KeyBody,
    })

    local saved = readKeyLocal(cfg.SaveFileName)
    if saved and saved.key then
        KeyInput.Text = saved.key
        if saved.expireTimestamp and saved.expireTimestamp > 0 then
            KeySystem.ExpireTime = saved.expireTimestamp
            KeySystem.ExpireStr = saved.expireStr
            KeySystem.IsLifetime = false
        elseif saved.expireStr == "LIFETIME" then
            KeySystem.IsLifetime = true
        end
    end

    task.spawn(function()
        while KeyScreen and KeyScreen.Parent do
            if KeySystem.ExpireTime and KeySystem.ExpireTime > 0 and not KeySystem.IsLifetime then
                local now = getServerNow()
                local diff = KeySystem.ExpireTime - now
                if diff <= 0 then
                    TimeCountdownLabel.Text = "⚠️ คีย์หมดอายุแล้ว"
                    TimeCountdownLabel.TextColor3 = KeyTheme.Red
                else
                    TimeCountdownLabel.Text = "⏳ เหลือเวลา: " .. formatTimeRemaining(diff)
                    TimeCountdownLabel.TextColor3 = KeyTheme.Green
                end
            elseif KeySystem.IsLifetime then
                TimeCountdownLabel.Text = "♾️ สิทธิ์การใช้งาน: ถาวร (LIFETIME)"
                TimeCountdownLabel.TextColor3 = KeyTheme.Accent
            else
                TimeCountdownLabel.Text = "⏱️ รอการตรวจสอบคีย์ (เริ่มนับเวลาเมื่อใช้ครั้งแรก)"
                TimeCountdownLabel.TextColor3 = KeyTheme.TextMuted
            end
            task.wait(1)
        end
    end)

    -- Draggable Header
    local dragKey = false
    local dragKeyInput, dragKeyStart, startKeyPos

    KeyHeader.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragKey = true
            dragKeyStart = input.Position
            startKeyPos = KeyWindow.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragKey = false
                end
            end)
        end
    end)

    KeyHeader.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragKeyInput = input
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if input == dragKeyInput and dragKey then
            local delta = input.Position - dragKeyStart
            KeyWindow.Position = UDim2.new(
                startKeyPos.X.Scale, startKeyPos.X.Offset + delta.X,
                startKeyPos.Y.Scale, startKeyPos.Y.Offset + delta.Y
            )
        end
    end)
end

-- ══════════════════ WATCHDOG & RE-CHECK LOGIC ══════════════════
function KeySystem.StartWatchdog(activeKey, cfg)
    if KeySystem._WatchdogRunning then return end
    KeySystem._WatchdogRunning = true

    task.spawn(function()
        local interval = cfg.WatchdogInterval or 10
        local lastOnlineCheck = 0

        while KeySystem._WatchdogRunning and KeySystem.Verified do
            local now = getServerNow()
            if KeySystem.ExpireTime and KeySystem.ExpireTime > 0 and not KeySystem.IsLifetime then
                if now >= KeySystem.ExpireTime then
                    KeySystem.Verified = false
                    KeySystem._WatchdogRunning = false
                    KeySystem.DeleteKeyLocal(cfg.SaveFileName)

                    if KeySystem._WatermarkGui then
                        pcall(function() KeySystem._WatermarkGui:Destroy() end)
                        KeySystem._WatermarkGui = nil
                    end

                    pcall(function()
                        
                    pcall(function()
                        if _G._1000Z_Unload then
                            _G._1000Z_Unload()
                        end
                        if _G._1000Z_Window and _G._1000Z_Window.Destroy then
                            _G._1000Z_Window:Destroy()
                        end
                        if getgenv().Fluent and getgenv().Fluent.GUI then
                            getgenv().Fluent.GUI:Destroy()
                        end
                    end)
                    LocalPlayer:Kick("\n[" .. (cfg.HubName or "Key System") .. "]\n⚠️ คีย์ของคุณหมดอายุการใช้งานแล้ว!\nกรุณาติดต่อแอดมินเพื่อขอรับหรือต่ออายุคีย์ใหม่")
                    end)
                    break
                end
            end

            if (tick() - lastOnlineCheck) >= interval then
                lastOnlineCheck = tick()

                local ok, msg = KeySystem.VerifyOnline(activeKey, cfg)
                if not ok then
                    KeySystem.Verified = false
                    KeySystem._WatchdogRunning = false
                    KeySystem.DeleteKeyLocal(cfg.SaveFileName)

                    if KeySystem._WatermarkGui then
                        pcall(function() KeySystem._WatermarkGui:Destroy() end)
                        KeySystem._WatermarkGui = nil
                    end

                    local kickMsg = "\n[" .. (cfg.HubName or "Key System") .. "]\n⚠️ คีย์ของคุณหมดอายุ หรือถูกเพิกถอนจากระบบ GitHub แล้ว!\n" .. tostring(msg)
                    pcall(function()
                        
                    pcall(function()
                        if _G._1000Z_Unload then
                            _G._1000Z_Unload()
                        end
                        if _G._1000Z_Window and _G._1000Z_Window.Destroy then
                            _G._1000Z_Window:Destroy()
                        end
                        if getgenv().Fluent and getgenv().Fluent.GUI then
                            getgenv().Fluent.GUI:Destroy()
                        end
                    end)
                    LocalPlayer:Kick(kickMsg)
                    end)
                    break
                end
            end

            task.wait(1)
        end
    end)
end

-- ══════════════════ MAIN ENTRY POINT ══════════════════
function KeySystem.Start(customConfig, onSuccessCallback)
    local cfg = {}
    for k, v in pairs(KeySystem.Config) do cfg[k] = v end
    if typeof(customConfig) == "table" then
        for k, v in pairs(customConfig) do cfg[k] = v end
    end

    if cfg.AutoLogin then
        local saved = readKeyLocal(cfg.SaveFileName)
        local myHwid = KeySystem.GetHWID()

        if saved and saved.key and saved.hwid and compareHWID(saved.hwid, myHwid) then
            local ok, msg = KeySystem.VerifyOnline(saved.key, cfg)
            if ok then
                pcall(function()
                    local noteText = KeySystem.IsLifetime
                        and "เข้าสู่ระบบอัตโนมัติสำเร็จ! สิทธิ์การใช้งานถาวร"
                        or ("เข้าสู่ระบบอัตโนมัติสำเร็จ! เหลือเวลา: " .. formatTimeRemaining((KeySystem.ExpireTime or 0) - getServerNow()))
                    StarterGui:SetCore("SendNotification", {
                        Title = cfg.HubName or "Key System",
                        Text = noteText,
                        Duration = 3
                    })
                end)
                if onSuccessCallback then
                    KeySystem._ActiveAuthToken = tostring(os.clock()) .. '_' .. tostring(math.random(100000, 999999))
                    task.spawn(onSuccessCallback, KeySystem._ActiveAuthToken)
                end
                KeySystem.StartWatchdog(saved.key, cfg)
                KeySystem.CreateWatermark(cfg)
                return
            else
                KeySystem.DeleteKeyLocal(cfg.SaveFileName)
                pcall(function()
                    StarterGui:SetCore("SendNotification", {
                        Title = cfg.HubName or "Key System",
                        Text = "คีย์ที่บันทึกไว้หมดอายุหรือไม่ถูกต้องแล้ว กรุณากรอกคีย์ใหม่",
                        Duration = 4
                    })
                end)
            end
        end
    end

    KeySystem.OpenUI(cfg, function()
        if onSuccessCallback then
            KeySystem._ActiveAuthToken = tostring(os.clock()) .. '_' .. tostring(math.random(100000, 999999))
                    task.spawn(onSuccessCallback, KeySystem._ActiveAuthToken)
        end
        if KeySystem.CurrentKey then
            KeySystem.StartWatchdog(KeySystem.CurrentKey, cfg)
            KeySystem.CreateWatermark(cfg)
        end
    end)
end

-- ส่งออกโมดูล KeySystem (สามารถใช้ return ได้หาก require หรือ loadstring)

-- ══════════════════════════════════════════════════════════════════════════════
-- MAIN SCRIPT MODULE (ROBLOXZ - 1000Z HUB)
-- ══════════════════════════════════════════════════════════════════════════════

-- ══════════════════════════════════════════════════════════════════════════════
-- PROTECTED CORE PAYLOAD ENGINE (HARDENED ANTI-TAMPER RUNTIME)
-- ══════════════════════════════════════════════════════════════════════════════
local function RunMainScript(authToken)
    -- 1. Cryptographic Authentication Ticket Verification
    if not authToken or authToken ~= KeySystem._ActiveAuthToken or KeySystem._ActiveAuthToken == nil then
        if LocalPlayer and LocalPlayer.Kick then
            LocalPlayer:Kick("[1000Z SECURITY] Execution Denied: Unauthorized Direct Access Attempt")
        end
        return
    end
    KeySystem._ActiveAuthToken = nil -- Single-use ticket consumed immediately

    -- 2. Anti-Hook & Environment Integrity Guards
    local _c_load = loadstring or rawget(_G, "load") or (getfenv and getfenv().load)
    if not _c_load or type(_c_load) ~= "function" then
        if LocalPlayer and LocalPlayer.Kick then
            LocalPlayer:Kick("[1000Z SECURITY] Environment Error: Runtime loader unavailable")
        end
        return
    end

    -- Hook Guard 1: Detect Lua-closure hook proxy
    if islclosure and islclosure(_c_load) then
        if LocalPlayer and LocalPlayer.Kick then
            LocalPlayer:Kick("[1000Z SECURITY] Tamper Detected [H1]: Loader hook proxy")
        end
        return
    end

    -- Hook Guard 2: Detect non-native source origin
    if debug and debug.info then
        local src = debug.info(_c_load, "s")
        if src ~= "[C]" and src ~= "" then
            if LocalPlayer and LocalPlayer.Kick then
                LocalPlayer:Kick("[1000Z SECURITY] Tamper Detected [H2]: Non-native loader origin")
            end
            return
        end
    end

    -- Hook Guard 3: Detect upvalue tampering / newcclosure trampoline
    if getupvalues and #getupvalues(_c_load) > 0 then
        if LocalPlayer and LocalPlayer.Kick then
            LocalPlayer:Kick("[1000Z SECURITY] Tamper Detected [H3]: Trampoline hook present")
        end
        return
    end

    -- Hook Guard 4: Detect global environment redirection
    if getgenv and getgenv().loadstring and getgenv().loadstring ~= _c_load then
        if LocalPlayer and LocalPlayer.Kick then
            LocalPlayer:Kick("[1000Z SECURITY] Tamper Detected [H4]: Global loader poisoned")
        end
        return
    end

    -- 3. Decrypt Core Payload via In-Memory Stream Cipher
    local function _0xDecCorePayload()
        local _P = {
            "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",
            "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",
            "wzodnda9MZtJPckr/XSb76ogo69wB6K9XsZeU6jLD2/4l6luT22OwozKwmsHqiH/99yAI0QlcHMAmTSfhaF5a3riro6zmJyDxrSL8/ByhilrrOM85qjvTYTCuIf1AJvhWPwVKEV5CI+stqy2563Nah5b7473Crx4MHUaOWALfcup0HDUKJrl3RnnKufUcChm6Je1ret7KmIqZ611FjuFvCWYeoY2s/glwjGWNnpSqFqhDztO2LyD/p/LjIab2PdpkHwY/F3M35WSZfXjb7XCFkZAKIalAQ1aNvwOq+4DpbPGG3ci/mLVkT9KzGoFyyt93Shc1Mdpxs2w2tA6qLr7YOzk1V+Gd5cfOp/8p6ygbrBdUrDDKji9QIPph2Q1rgE99gpN6hKywC6mR1lbjpOGAfHZxSDVu6Ue5YT2IGcq538BWDR3vXpM0pcRUDCalqQZvmkNbaxx0tfPtt4aYcFJN9y9clZmkMZe+Spx7F5irdlpgWCGheRSPXSzgkz8aqu73xFi0mer3odEdlphgpSgmAYeb1LeClvYl0Bp99y436ua0GEn0acLvqMq7lSzm/Af9LNWTzPuEIdixEQsWY9z2E8CnBagEV0I9QMrE8v0147kLXraTECmu0mnXS77Os4kL+XiMDy7EjGTO60P2ihi4+mYL9OVQiuDOZRWeKSjhyRItSKBMw1qV5Qc9hQeb8d/T5YBUHnxkuJArT156EBjMGLmmNKBp7uNlDdcUNKUElmj7xv7l3AfQEGBrUNiB9oAPkjxwEGc6z0UiHb/OWqYa7X0pxd7/Yv2lBLE5DBFdLG2k44qGg6vDqc9doM0kH4iqXMHxNtwjXHTo+TwsPbPfxEp3ZyPn2QxIhgIaW88cdUPkVdMh/4bCrCdLeH5Ca2UVcIv2jvw0MttW+YPTnZbMVUyCPY/mkny09NDkKPOFszLE0iju7T40PqWsxeq/tv3mZ1S7IPl5ORvj+IEWZMLGU0h9SEqFVrqm5iz0H+RP6Lexj6hNpFkFdtIWeVqMM82lMO3rbU3AonebsMDBaeKVtrMrT8IopdH0YUOk9iqhXbAI+/82ZGfx45ragULfAe7UkLSJRSAcCXHr0BwhrcmZRd2ZtKXeLmziy8G/UQNfQxCsVcozR/g24TWN4FJR2ErcnMOrJ1rZPNSt/YHn47IliTGJdBmCA9iAphLBAgbZaCyOK9Xi6rBtZ+CqUtTR/LXfYqZCDHc6GIHvFMetkJZLjjdBQLyR9RDpi33S//oM8AKVQgPh+r/7lW19ns7Ou+ppO4mw5iS2rmaUDwXVTFhIqlcP3wF6uTVt1NAAtFrM5DsL0VF/yVRIXg4FV2lYSl3POz3l38zB8pQ3qQG4cAfHUu4cC/kupuAmNf7mbNJfMuzvx8k/WqBPl8/3+jsGPtvW/IlAVeXyEO7qAy7A4/cHK6hUd2jd+LSDSUYXKtORHaMJDQ/crftbTpjPm5VLmi3XCyXeVTZrKzzH5NwY2txqEorSxA1ie32wsTysB6ZAo7QGan/MVEcNF+M8t/hV1bUL74/08eA9wk0kJScbvaV2GnjTg1jDPTA3l3abxEkyMSzwucGHi6giNEZ80z7OJ9RcykUxGHjxKhnLzCYk1gm68DDET45MlmkeTuoJzsNrfSMOa1ATPKu9k82U/5Izd/3byE/F31jMGxrsb7kTMcxE7giFX6aGzdlANTovq3iGqQx5sTMxfy5CGP7CEmrW9+cAAaTvD69TN8U5P7JC3sSrThdaoE9YsL5boJHx0WyDeXYRKdYNCqpBU2BR4diK0gRKcBCe5MralQSlgB/24JnwnvZeRnZbR41PDOX7vSvB/S3LJgHIl2sPJnmZS7dXquwt4/N+UhGRq4qsbJCMcxsL5MPTvVVOk+/SG2hUhmNeVuai7XtXrr15E2ngxXoQwO0bHjXTptyrw+AjS8JJUUFBzHFbHcThkXjW/o3jkonZbUcCWUUkPSe9VnCIXXQKG3DE+wzX/UkHFkBKvx9",
            "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",
            "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",
            "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",
            "JY8IwNzFaDpIh/lXzYaR/7UMhnmhasjFqYcXdD+3gPDwGK6KfhQ+KLFzMPiC6LNPwPhAAMJSsjTcfOj8F/4XGLH6c4NuEf1GFm2DVnAtqQ+N0B7rVsm8drMXYS3Wk8Y4EkinTObFtKwpDxjndjDHOSIcDwlcCGcOnaALDp3s7hqpEVgsIVnQ31a2C/AY/xsqPgV+8ykU0oi4lezmJTC5GRx8JUptuH4ri/e3EGRVgqfDdONuSARUf79DrFJuTb7HOo+cI4s6MlhLeXIBWwU7MaetHnhwZcTlsbGmU+cTfMR+Rh/SqY3w+JzC9rWdsl9jpjOwi0egLIVsy7opSbtaEHjrN3Wo+jAPZqC0ElZWJaRjPpf4M2T9sA3zMbw8Cg2qv0l/vBLxhVSz5y3EfmtnT+uzag2cZ7qh3Lfb4n5BgumM7t2qSzkZ9y40l1WrgWal5MLKqm43s4c4ERmI49uRZkD7Ww7XR/obJaNG0R7oCRHWQfNg7CbkDQenXJ/zB1OBCeq1/m9c57jJAfL+NDRhwWSblFsgcNmdNMiQODeb7WFOyPuk7dnEZD1y2v2RplYw/EuGsSG/ApX7i23/O2ocdedhf2SEIMk7AOFbnbkWLjsWeUuocvIzSkYb5D/kU7x8fAcOr+UJXsJdtSDl1hHtkSMfNwbbjZbjx8WrsB5leMsmUQUMTd8+wfCL6a1hMQHTwhdFDMvlfrDRmnp5Moet9Wx8ekak0wNtXVuJ2ZGZLtrdhWJEIYPMg1JLHC/nm8LzP64QS8kff/54jwrfCqXm/Mmq6GiWqWfN4PZ2K7F9RJGy3v6NTho9Sio/Ty+RyGbBJ2EGVa+EW2KQvqyGN/rp7Ft8ha+oCJPk2A4/Btag7kxLpiNGQ443dne04gdYeLw7TMUQ4qjeI8QBcogbFVpBEWm7cBQocs0iWVPie5AvXvtHJory+wb4ZSRUGWX1kbHV/8aK1kgb0WJpO/X03mmyIammH8v3OjV5I/2d0UX+sUfPioIyHiY/czEvofbRMSWUs/dxOdAbxVM01lEHwQoWUjTGq+CtsoKBI0dVA28tSfF5oRkqx2fn9aPtRxZEH8SDJP8DMZjpJk5XJUsF8aEoXw9z3Wiy7BQ4dG4zp0EiQBSk7V0GMwS1dhn0UAS23RRez+eyfruqJ8SrV9wEVkJNJZIpwByEkm0/Ai8C3PSDuDjHxLjwgs4TOdBwGyF3lIWxn1054iLkACKih+x1tu6diZ4NgoZOIQC1ig9VRB4cpmg89q3D2k1E9SP/QKL9ycrvzZsxfZsuK/zhlUIZtIy9YLEzVrUVvXp8DK2pLfVcvXR6iXIYcQD7+pUeiFuJNZHwbhy3is1g5rIbTe2LQwF5NsDWFb9/CtNHki1d7BZTBwQem1JB4t3egZdj2+tSQTAYGKIGVajN2i7zUVPGMFlRPJCKHjZscYzEG7pyoj46xqTY7aaDHX0VFFOoBtldjRLjA+ioXuWCtYFTPD+cqsYU48XGrFzQRtt4PkLufPEVWaJ2XQ2s2bY/hQXCHH1THx7FZJkqqrI6ZZ4Hj1Ih/kzTltvMyJDI+nY6eQRBR9IGFYyeS5665SplCHP5ZXzDE9ubDYSS4T2i6h5ZAMCjZIZuzI3IaVdT6418x5hr9RM5vnX/sa/XhzS6tamXTP69M8Wpg8JEBS9n7gVwGckmIoxcZc/w5nWWI2ovD/7oB+tJCvLxwCMbXjEeN5w2I9Cp3tyq9SkPFl5aXDS2CrMDABHBbAeYH6iIwTgTMBk4j3FCIjiUTo9YP/1O9EqOzHw9W5bTK+zbmIk1Tox5nLpPa3CeV8lNmBCfxE6ma/1wfMZFYfYF3LiHwlEI6cFM4ZGYWYZ2JwNi7KYSVKOMmWpC7kP9dJWwv06or8dfDHEqlGiZdZQ2spzxQtUUfjwkKHwub8XWFtWuYCTCh/TjFs+QY3ER0b9mXtQQSd+Axk3QxFmUC/eaOtTh15TTMpS0O3k/DtMegEL2Olfouh9LuDsJ",
            "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",
            "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",
            "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",
            "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",
            "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",
            "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",
            "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",
            "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",
            "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",
            "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",
            "zPl1/WpzSzFk5lSTvpCO05pH3YHngIOdRwiOlha+9GO4gCq22/7Y4kHqYbzE2aVJxhYddmxGLUz2ZMba4Jf2NY/N4ZCk1SOQtrxXnYXenEkXKwbcraXtum9ZGt/k6U4EmyMkXXaYFIXxcFE9TMEc3ine63vfs9Ff6PSEniXxlm5mq0TIzDjdElr9L7Yp7CYsTJDzGbxSevAczDCXTkkjGA7EoZmXD8m/x3r7a08OHCxmXz/GipsR8LpUZBZe05vBBDrkbzx005Pnh6uzTbHow+ygOYgoJ1niLx6aIw8WHzj6OfSBJAjpY5q/+mPlC5JiWa97c3PKVO0pWoVQJLNfmzvI36eDZ5fAHHjjvQ9dR/LaYGl/3xF6mZXkCjvjoq0IwQ36MYhcD9cdZ6c4Oh6r2vRhej08X0itwGYvcvjC37A0GEtTZL+tl+AHtrmp4K+RRTY0RAmPipqEQfvt9Fnci8PghoaN7BTHQdsx7virnS/RjmpkNfNGI+ZZKI+gZoKb4sdQNXPG/0p12ILiA1ujiSQ7jewRkD0lovXz0qKNJDEqR51BP871zbd0DlLwdNg7uUkjQ+fyLqFuO/q2xI2vg934qhbAnirkO46QkkPlDFu+NbPtjgMXK0pIiCi/07vD5gikBYw0pDw5AmryQpFJhcuLTXu/5NIYKLYAbwpL8SfPPzIG+bUrzuy+pG87Hfrk4MAz1o1tLrzBokHluq8OC2zPmVDc2Nu0vZFoiFUCLEb5n9xHY8Dvnsls93XRiKQT8N3rXKWn1l4ldxcZJHVOa7Bj7oZ78UTjQxoEBxFrBnvQeHQJHeMNRqCcajwxuf+7CDH9+8a9ABx1NT266Oc7fWVAou2h/acvyzp0T8HRMWgh8o5sjT5E7jYZQU0yUFlk1xw219gZ840pALyXc41VMafNKcuzU9AxBt3Pa54iVDLcM7E4+QiVBc1JjJAi+Q/9TvUY/3ZBL8rXFnvX6EyQC4c9nugxSs6CMxyfX1rR1cWiaE2V96OKfon8rCPpC8o3senbfl4d8F0grWfQaf1fMi/vK1yY4QW+4mRCajLZjwo/aPUh45mmh7bwlf6XUrSYy/PoBc3r2ax0UdlejoH/u+y6CHcwYaE+wRip/Z8HlfCqaCKO2TR4Pk6RvTYgm/P4E66b1jkD27s71e2AvIXx4T/+CzNOxaYN8I8LuNl2rBtaeEIivSy4asxG8tzNnWwnVSf6deL7SPbBuPPWZTK8KjaSDBS2JuLcrzoglck23JMnuEKRDF0X6xWRj6ZreT2dyB9TEno2lvZkKcvsreby1XmK5Q38sYXMKZRM/gSATL6MOIMAy1SrupNfkOEKaMC2RSzVhxzAdJp+Gd3HrfqBEIenNiBYo6xxq/VXR0P1AZLfV1kIhjF5knLxA3NO9J0ibyelig+Kx3ngONDaFyWdPMWXcvdnq0RjIwjZgT1AHqpaN9EcCMfmC5VVY8eQZUVdf9VQdeb33CNSBuI0e5B6hKwYBQRtjbJPznZszY0eun4W0fXKh8TVLbCa8gZs60x0F4OcKZCdcdK1HJyXW67O8PQEN1SCN5mJYkKq3mzmxrQGBTYMeVZfFXLwxv12RSMoZgbgqpaTzFyuIcNVFPi7HdbjyJGJch80U2OHEJF2OH5Dyx7Ti2O4Fv/UfuCQXxxUWQnIENKjk/Rlz2zb9+3aUrKzKx3JFgKZQRB5Spj/a8fExNeeIXgUGAuv0UWKGLkwkaSo2EVOesi6mmjfG6ADyH74qUgzIyskww1ocdQbNDtDGWH+s1eeYIgPs+mu8MncVTYSCCza54Q21tW0jCoGTcpl6eYIi7/lAtbNzQ6dSduOzY/HBcnm7ZGr5ltYVJ8FbkUL1Pr7f1pPYcMZUhYrv+ORqmko41JWVPueK9bJImjWRRaVcZ1Vr456JWGh9r/VDIRnYIKA4A2LTdYVaEHXcRHNyn+zGyRNdSINg6JeQcNBGnFOHSrvwtuP3ntsMDb3PKcXPKUeiaw61Q0x",
            "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",
            "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",
            "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",
            "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",
            "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",
            "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",
            "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",
            "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",
            "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",
            "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",
            "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",
            "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",
            "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",
            "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",
            "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",
            "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",
            "QFOToA/rJHeSC54zo9HnEpmPIu5cTUqfvd5zSepIajErKjTIIaGw+ghYUs2f2eMGWd+dlyds2gJzWteSbQMkZrL1+puUWc8MtMbs+MAlAQmxNmBjtQPhE0ATnpHM/qkoEw4/BiRyRBwwCQzTvcNJpTEMG3Lk4UbiSjm1269WfK5RWWh/zGgOLx6yL7L4XxwmKsSm6wpBUkBmRPWvKodh9+0KbBVyJ8N4Z8fA1zDe7L/xlRlOCXTkfYscAeRHvB8D5jJCC2idwb+fAE/HMZsV5plAczRWpAKNH6gjlpSBMYQVBodHX2XxG6BFFFOTJxr9mjJSvZmh/hajStHKSPnEYUKIgRyg3HAohm9bcg169inz9UxgyPsNTdCvj6xEel2BsUmK6GBH4jKNZrWHQJKKRYOmSo7soNHt2rvik/BdZsBJQhIq8jjydz0xC+RgkVdjcRjFHFXHwiXfgkbQjFi7tN/AkSBhmycyTVJf4zt/Y2BmjY3yFQVw6NQ4Vtru4vTaYZS0sSvdzv/iPfbGciZMeATa+eMJW/iY58y+Tel34GAbNThM+7toWgJIi1UFAE5ClPTMUvEOPQJGr0+XsLwP7Mx+Hol1dL+B5es9rYDO1n2WAs3Vtrb2ASp8Y7SJZ/YHihmlCTgNR6KGzdRVZufsFOrajQb8AyRSMuF0v/BAsOVKvWel1twG/ShQm11ii2IdZsoWun/HC9hX7FfYav8qUd637I+h+3QLtgQ6+F7NdeB0ZzJtJlcCVWo5G7BqCE2bs7Le7HRP95XAK8Y0g05JtlK2WNaiYJ3EKPQXveboFP2XltHWumCdIcZUdDCCf7SOlnUXr9bnwLNw0GoP8zBGXf+Zkxnk+DNjEkdtoyitiQ+KBCCpaPpW9H0l/k+vmKf2U8gwiuccWBIuEftPdFRtimqZTAgy22x4rfiAGYIoonwqvVLSgom2oUVhenh8P439+yWPBXk065iQCb5UP4qU6yx54oRO5Mlfr3V5oUEdrkr7N9qvxBGpuSjFIGQQa5Og3BUl+J1+R76q+IaE//Osfpr+GKkq2OAJG6sE9yaANPV35zj0r7iuTUw/Z07gKcqWDUEO4f3Z1S3JkoB165dZ4aY9zT8X4UaxXPY5i33B6E4y5J0BDZdAHfY0tkGrr6K01dwjDW7FNwW6OGXH1jOzhdxoOUFuRcXarVDILCEEh1JNmpmFrJR2mDcdD+14M3/XZ3aG1k+iNvbt03BGDx6ee5RxMM2c0Uj+ZiISRPzE8vI/DJrUn0ydufDzYu+S2EsN7Leec7LzkBPjrJANbRabzURYNmzbNgH0fRKUTU30H3sDM2iTtTt1DFkPFpX38ObC5I1EIfOE4hgVNUxNszRy8PSwejXlauBQQAtGZrURauYHZiS0F7jJEsc/NpJ41Yb49p5jEcvJnRu+AwYG5077uuVK11CtlaaHUuOJjW99ykntnysN/Ky02eYYB3glfHkgpYB25GDXnf++5yTZb5CGia360b/FSk/4dqaobgmBMAnm9Z4TwqcerA3phTX99EZs5xd2bAxSX+u7zmiBRxYooVyc+128qhZh8WSf2w4eDzq4wMCOCyvowTzLYZ90neH/f8GEBlPr/phenk5fHvGpHDugFz45JJIxFUSrC2IdiLOeRkJClJTtkBTm0LxFpB7MCNLqpF5VQ6BhS72oiZqTpqlU26tFMD8k8GydJKFQIbYptlAtSYj89i0PVrE/d8Jrs3RJaYwpeZtE0iAxgZg68BNtK0cLhCg+GcY8ikoFE2yUpRtgL3zo7iT+g61ZDo5pa9zoGU6modUtGb3CjY8qWtCN/c3LsBoUt0VfNRXWiZbH7QDaaAy5l7Cm+rfeZfzBgIoxsogCdcTYW5nkO1x45urFC2hHoaRh9cktuWhdjj8XKjQUzY71CqkzHYfHdFXLhFv1IFarakweuZlgUc+alU9Ze8+bzfvtsEBlXKJf679udq0P+u/Rb+Fv/ViFNnawSrTpB/yHCnk5dgH0",
            "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",
            "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",
            "v/KgvsJAFhKYOcrQ7ar5QQYH97HfFxaGaBnBx9bJBo0mMNkekAaaRMjXQXkVjHRJ0tTuszb9Rvr2knn+fytgMys/LA2NsactvsC2DIJxQ3QZOxI/qtsrt8ifvVy75HxYaBxQh7IBcVQrhZQWLiB+oy+nRqEp3mXv0QCpxUrUaXYj1MabA2OJT2Lz2I8s6YBP4VmNRDf7ovFWxlLec2hHxA9YregwJOiSsFABrCOPkEts5CHCnZJ/ESNUOt76T2EZGcdHGkr6j/DJtPqRXs37IkUq7kcZlePv5lB34w0Pu6hypjDayvPAamo7FaPw0dO1FiqwWRDLE8cmh3tRx0E1LAvkjPB+A7YikuwSkPAYGSrwTN4nm5KMeZIiLHiGoYNyW+M8YF9JplFRwmakRVovxgPo7HbjvqVn1u3rdeabs3TomUSgEfZVoVin/IhyWDD6CadyqhPrMQzR/OWszTri0vQMMML/4ultsuakL2pVXZdydN4SA2XA51lePYIEAOfdZBrT18j3n9Lk9O7cYtnjUWEpXTMUg9QaUOHsWvwfDxtQdP3ic464n8b4xleuVyp91nGG6Pb3H0yvyVkhYiVddowWbnsSkmPK6WwAc1jIGfc92GYtm9hlrq5jXe/yd3Sc6W374I9430HTq2VQcimwaBuSvGs28R2Ho1YoyvX+an9RjNYRFMTug5kR5pn37PvmkHeb/38zUYksACe31I8fGSljwMA1WWBLUY4SmgpN3Me4KIWOnDKitbN665TB5i+aCZENVEtqQ5irgklUdmz2bM0JnIKVJGEA16Wsrf9CNvMXtKPYZea/4RbeoHpEfnn6kS+AQzXZyoOUjdt6Rncw3sZVsq2t7+HXkEs34N7Iv+bWkTto/9h9egKgPbLvshGBrsfJmm6KC8alSLoGqNfhxF07v8Cl2yfh7alUJnnJG8sZVkg7aGCndzMZVtv7MpNbQfTM7jr7ShWzs46cctuKKnGIKqIfhFfa7cPTiufavtvg417e3hTOCsq4P2S+JivZW+ld9Xxr1TruHBlxIWigTz5vTWP0AjzaTQ19TPCTTxRgvI7ob6JIFZlf4NswaqbzJ9cD9NwMhAAxqCoDwD3YzzUUQjDwFy0tjIBHU4SYgycpbXFf+ELjqnefmW2bsh1jO7Ay3ccGB1Spax+5WBc+QhTJHdZDeW8JWiuaScDbvQYpqTULjndUlqAaC27SDf3XBIH2Xda6wQsiiyxyjQ9HdcsEXYHFVtTv3kxK4zCd3pd3rHhqb5+uXhY35h3jNnrFeGntl2lAYFZ07EpfmoNBraq2O5e58jx5FEDApYtonUbRsc9003/91nq5ldok+ozjIDoS4a67udZmbgG4F4WXGGVZd8MYnLcLQQpIkGuN2wh0JhRAdpNNf2jdyxlKmHujNVLlXs94p5WmoJEnC9rsz9u/ZU9E8X4PQy7+qPG7+yXJNvIl+Nh210+xyE+FU7TVrETq+6c3xI5I6iLtmLbS+CjMX4IoMi1j0aiDaBSJh1OyG15xWIuSoQLau2LI/+J5WSpPEnEHod4GuyXif7qRQQw3aV335KnvyRaCLG19jHNZAs/7Azg2QEAvGAC4Fiiwh9/uok5Mf1zrQ4OrVqNdMsAyKekBIWBB2Ng3rqfFbRC3yoFc/w12znQSWBL+Af/kY4p9eo2gMuunBzb549f1Dp9LWTx+gzF0W2P29vJ+o0pm5J+1jz7a9AFrIckMtdCr8gIAv8Ft8xNXNI7deg63XzQnmT05i9f5RqNH0IOi2EX6RV7MM8N3YhM2iNOXwXocl4Nze8HEJ4uUzlwxWH9Ab6Eh3JbOYrjCLfUoD66zvcEDkM16KhI4+2fWZNTk2curVw2XSH15WrKEpEerqKJY2yb0ofoBL4Hcx/NAK5hmabDtUGrKBZLSn6qXyNLDR5Jai35BXksbjAVK9aaIXxprTOP04vVSSlVOWVmk7vw9WDHneh1rQpLnNAwiSM4WMMgmcCWcSZyvKhbPJQWl",
            "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",
            "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",
            "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",
            "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",
            "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",
            "iobvy8cimv/m1OcGQ9VXIaMW6JGomZJo133ojU7Q+V2+68MbmMrqt11TM2RLcy6EpymrHdUf2NNpAYY+k6y8MCJoAcuNYv8zsThge9b/AYhcFqL8OiWifNHpA6tT3oALLPH2W2TQb5wi1Hc1lxTBmNvdH71dRFhUrQff1hVMTCdciRNlEOTEYaZ9xJUzzq89bvwJ6cBwLf9YerZSpEHFHEECVPKZMtL7vgHipOdK4SqG6OLHT0nnLb47VmWSR3kvfdI6aUVzYsjoY58o2/dagB5Xj6O1DjGLKAivnG6ZZCdSG+MXpbIkr2RS529uUCWH1mNlF8UG4bbQu6sbpqM72sFogO78xkqjGZw7NEebuVeYEPAo1KYk4YxNgZrYVB72B/Iz5A9T12sn9BVBCwsp//+uFAJTFScCxUyO3ufgeOKuCtbsKi5aEaRGJozJDRZbIAKc0QuO/r9Xtw6PkRc6XhAky1ggFDxr2yIVIfPRBp8fBFdP90MTPujGfz6re9VgljQCp1KKWBd1whTKhlzS/CFGpPKPGvjq0tvqUnczHKMBHdXMPuPq2w8wjdNM0Q2cCdko/9awZsMggRVQ9rfHoEYAnGAmuef7I1hh5WUPo2CoTH/lUlWIgwrpjHPFe4ZuQuoXOmrbawtbuDz49NN+YaSU7v0SeITuyhUFIv8CqbYwYpfwYFSKW33YUG8VNlmWZBf+fRw9N4ujwnVKKT09NsGtPaaclLQCzd4uj/8fpY+1cEjrKfQGVshslOE9ZZUfDmnF8C3o8ohDyMqiSLB2Y0nlboW0hbQUCjmimzjrzyhi1yG8Tr15M8b8NiUvC9yMhcPI3W+wtuUojV3tqgJ2A+xaovoPG4nIUvMNAaMkIIlKUrbQgK7EXy42YARWMpHZ39T7wN97oqxQ0rFiL37IKnocbrSM80X9JsHh1U7QrazgkB8s2w768dssB6UNzQ2n0qjNyokXQc+TFTeIE9WtWPhFjOtq9qx4OphZbZfdVn14M47aMwr1SRsnxIQZJ2BvjPQhtJGgrGleEHeCqaQue3ThcNeD/3MPGdD0oyjocEntY1Y/kXphK3KqQPkZBuzRDbBKyjlc9rA+DcofVVDZY+qHQULDSsFJBaur9W2Ox82LE0NtMvCZrdTBoy8B4dAArcH1NgE2iI+bOPWNDCnDciTn00xXxT7tpVCgbWXd+Xq1mKA+uFQrpusUuiL+zh80XvByUuBioZyeBbcvtiKYyUj5g7gsUhx/cjB5jPqG2ShW37WRtmpCA9+ZELnpFOTkcyIlIJNCp8Rr0hJ2LFARdDkfdRanSt7K7k6syseq9XWXzhQJcBmGxpXqGEdzYfsqpEvM73kVI25mJWJyDmu8k6gjTRU2BCC/UTQot5vC0Dy0hmqihNWgQcOc0XNz4nvyM5brpY3TceY5mCUrqGfAoSEGwbIvKpOTqQPzDYE0otJmDwWhsmkQRg5Gw4hmlJeSof9EYz+PR0/Ivj55k24dOKp0EWBZxxmlZbBn5yePWCzv+4F6rZCJW/IHYhMuY4DTofKAoDdePQQdBcYVqY+jqqCq6Ktpossg2Sc/3i6mXAKtgWsq9Ecs/5epIszNkFPVThnAON4R2dZLc2IP92I0Dm+KzSAnV/e7QcJtQOzeLrFRALaEkXeCqeX7HDEiQg8XZ4jHGzc0DvSMRbsqt3xiCoQLoQpWXxYcCcdaRT0stGAr0A6ns4NlTgxLRuT5AyIkcLnwwGADa1n90LE+wkSOOCFPXrSDAot7rMs5D8CLFMettyNG7ytbriNOxVUs3jcPUP1mM9x64N3jo6jlgVkZjiI5/NN1vyEnH0iUefngejTdOKvplvjtUSNvva+DVJWILbuj2ZZ9COQOz2A9sr00vzBYQcOT1RiaQFieGshOvhbjgdoCBdOngZa3UgRJf4l/EtC9SAq7UxZVBZTm2sot8uV5GnXs9EkzGXjDf0PQKfj0Q+MQ/c/vCMCR5f25eUI4JX4ioKECHhsn6gEN",
            "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",
            "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",
            "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",
            "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",
            "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",
            "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",
            "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",
            "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",
            "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",
            "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",
            "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",
            "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",
            "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",
            "/aE7K9S3kSTQETFp9f6qKZOxwWcrJvEhBYrcO5plqSmksiiLIyKhuxWlpfDtfd9OYhVj1Rb0Zu5SdKn+aLxkOJKjSL657ZX/Eb7HIPC0vrT8zTgEA5N44Sf4OjmNeEq9cQp1brCxJYJAn9S8MGY08JI+m5RatNlRqu6dD29v3GkWTrsv9ipkXFEhXg5geBKSUrYuyiks7sTGhS7eUwod2WmcJs6xsNvcu639VjMmCNRQ4bXmA73NZcuk2wxyvh9VtQUqq9fh9PpU/WV9s4IH9mk9YJaDbGXDrNQXok6rkCbGLZO6noGXwAn2rtg8IhxLFVRLSsa/BYT+hWP3URN0cMjRgaUp9BYkJb9XztXT92bbrHk2gj08vON6ub1zZMyx7WCP/vbmXPl9ihfkpAy746KbQW0rm0gCd/UE1LVnZQRCK7laB8gdlb2Fq1mgF9CmC02hSKOOOagY7jppSo1ElsYax50F+VBdJtfRSflutw7DF7QgMwtYX32T0kuINQNBRSmANEov/r4pDhgG3OnKr8PxWtZyOS8tQWuQHgCG6HLyOJKXJa/r35fbkQtyfGgqx2baj3Tr8/d77k1ePK05NZtTsTDS1MGNLdfPypxXWEe0tSXmuY49Er8kbtA2a094oX5aKR9Z/OjfzP54lmz8adVh4jsiesJLnX8QGp8e1ZvtiUlI+8nXEhwKK4lmQ5hbfzz1AvUvApSdwXh/aTS917I4h5Wvlx8oDNKRl4Z98p14oGss9H5dbmGcJRe3BqkJYVLtPjPk9N1oM7Y4ijKbrzWtwMmmA6EUY0GyGXndxPwd4hGK0D9nn5bRFjf9oFZoaEUejvbt57oYNvC9dkVwo/FZFJtXLMa3OWb9dgL+aTGvBmy/GajyzYeG8TFNvDoEa1083jYUt1XaQt/oUVy+h1FoF91bclPxyXQLngjMWPsuK60HcrYe8SO8SR7iVk0i4QqCs/NkptuqRYeUQR8IN7bicSuY3CYK5mhCIELYSGr9KeE8na6d7/XSEF9OvmttQmKX6p3Fj92450LCGu+M96KvTYtLa6iGrb1f+Hpj94GjJeTQzu+6spYG1owAF2zwe24WPgW/KX7U0WmCTPj0oq0wQF5sLpIBL3dhUWaWnQQlGaWQE7HDv5CwOZKhXeUUJaJPCWWweHdK08N24QMOdhy28l1vKkVG5gHYneZ2uEr4hm0MRvM+kHyilYc2+8rPNnhhWQ++IppkY0PqWGad+0XD4lUnShPXtJeKQDBc9XL/PGn6pIVgI5jESAxgLKBb9NfoYJNb3QgBixiVBQ2A/bub3VAAYwV835SqcAS9Ev0hYOTe4l6QSf1NI9uufHFqNNEx9kaBYU5E2D9ruOqZxCXConGuCDdAp2Q/1kfDFjEuD7mgHLnr+JVgkTeafQikLBkkY2m9fDB+xPWCoTLgrjPlZ+UZPUaBVBK0GFevQRDuKx3tzeNVtk/F/SnOyRvL91FgBz63MQ/cMmxqJIP8FB2WA9JVLSLbHXJVPAYwytJhaZmaqZrU4gQYZqHYMwepAlDNLoDeRiR8iyKtNPyxQfUyhZos/l0FTFNP7NE+y0BzlBTGkAYc8sHXfjRc3k4SCLdSzegDLwNXDwdBif5YeVobl7NydrGZcINoL0F9aZCW0TD29RRS3jIz5UzGPWYVwLZ5v3S2AL22Ume39s/Yr9z/b1VOrdjifZQsRVIEuR+xlPs0OaPIQvdM/3NIf3wglDqTdGO/MwT3R6CitXeuVMGqHxJFPMpdeCGGAa36Q2PGQZhdWvoqrQjYFeS0TjrCpA9Lk05ln16LAQQ15jwmQN6jfLnQp4bLu5m5Aj5hRJnIrl/xLI8/tcN842YQxVdySnfh0gpmgeebdGqCjJyqQG4OaxvpNnY6RgHkv5eDlmG6Q6O54I9vYwSYXvmf01sOtyA5GVr0NVbT87emcGALDoNFrmpSWsIvASRfZ/JAzl4K6VZ6Aw3LGHCyfHPpH9JhXWU8EOtnahIw/8oF",
            "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",
            "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",
            "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",
            "h6JOLCxrbBLEZZgYA3lDEkKWRHi021Ft6YJeKrPM/pMyzwCyN/w2S9TLjFY/O1aJ6RgAze7ljuBhZ/wtaJO9VnLgHacgSoJE9RGK4IQ5YmQFPr8/nmoW5WmbRAE5MLy/QclMQ8L9joXZjcKSQYya0lWWUtNhBP6gahK1h7BOTLRrmuiRFbM9UAq7Tcnf4AGPwsq5MgX5BhhgxLbsNfTPT9PQ3VBVpgFqDd3ZlHMrTslwl/gRDbpnkzEU4LMPbEc9MGDFsew7a2JfUL+V8PjZ9KsVJ9nnqazOcR+Q+3rHuK/cExahbJRc0wZF2J1PsBDfyjztLSB4XEhw4VIciY4PB+JXr/YzmVJi6Cknr0lBqU4bonkO4uKnsEoDWGkYdUQoEt4Egyp+pAaKniygxrKISK/AmKeTU0Kc3tR/w1HDCYw16Cj7beSA9Ib1y5Cw0w7Da+aHFqxkcRhG8duEZ3jsdcI2EYf1L78tg0Edg27rKsshdW3M9sgB0gTfQIIoXbioHnlPDuT/9Bo1Dtaqsgb10WhyU+JnS/F0evBu3844A4v4Zon6ZF3XuBShLer4ySkEn8EczjFFoOOkB/6c7y5dvnGayX7UgIdrc2FIZXRvwqlPtfEiWRDU2J8oEENDdlsXJdR670GmeCYHaYoKxG2U8JhXfALsZctpJy6EFvcKzPWWOdCxFyWg14UtevnvFZ4WEdEZYi3U4y8RTlWalivWehEVsFqP8K/fK3AA4uKRd9O/fhcuTCvv3ik96DeYCy/A1Mgcy3wAia6qYT+YONInjXNfXMFRgzjvnY8uT3z/SYblcCQqsjEzx+WebGynCl4WrkEcPg12nQXKNuL0nGOF83vKiF4QVXyda80Zkp4ryA+gR5suF+ipU20WXJ5uKIMauhovAijGmfw0d5XHtSVh9ZcVBwgQBp8YPkQqJyj/CBBCU/15ZfoCAv32HBBeiqiBjx0ls00En5JVIyBY/AgfVx7adwm1eOdrLYvg4dkiBfIXYvPZaewFs/uNVq98lzgjPtnQ5iMxP1KWn5ygPAhKUPPBtvpLq5ThStga0vKPP/jjOvr7+weGDrm7Bui3VGunwtj7cCJ/N3GeLx1jjSHFU2D/HFvQ3iYkmoTPJVbNMhr+YcNXKbYFB1usVgCkAtSxOe2tExF8TTa6pHeGjt8YG6AoPe4hXS5g+jupAyHOT9tOF3wwct4IT0NfkAg1ASVjrskT6pVcEQ3jmQB34ZVJrXjqyMPVYZ+0R/xjg0iqFqCBiB26pTJCM7gxbt8hG4kTsUUPxcTomaEplKnv0MwP0LIGk15Q7z7tk/U1iXT6tL30z5nsMPDVs1qI54MCqLqmo2fp2daMZlMwjatFqhTdX9fRE+YkX+KeLQBBK2tawOSLjZcHe6ipZ4eIJMV/JD11K7SLpQ9/Sn3Du4cFmf8OK3XOZ6amRw77biiJw3qFxKY7UqtrXvnF4TKRSFpuaPw6SOzv9W6KwxyuIhlrmHEU3P/af63C+BVeZXC19nauwvozH12QP3ExuipA6QXmJQ3PuSMttgATFrIx+znHy+bauDPiQq7d8an2M2eAXy5SVWq+H25DiIbiBGd035e1Zgkpj6g/dVX/c9DCUQFmM54mtgHv/gSanupDFMqxEomoK87xDdDO5rUxmJol8uTq7AP2LAO4USVf0VVNLoq1nDOwHmhyCxog9SkTrsp6LkGtqg5H4J0bre+CqaguzQq4rOZHqYr57HAbZxqMK1n/qqocAOOx0Z1xBeCfxAOFYqaFDpGgE6pGw4Wpc7okHWvm0aapeeMaXtF/cgwjbBx2YUXxwxQj2IknuvhY68gABHFoUq7iVfZrc40lyS1ncn73aBNW4FLRMuf/+AOly7XK5TN9SZra04H+RHNtwKdxakDQLtCiSWFI6qZ2o3J146PEm98E38NkaZ3Syq2dnr8hmF+ivboKVVM6s0ldfZx2EwWdpyYTMmzmlSfyzzm0zPirMBlRtVcWYQh8K2IFX4df",
            "l7K3Jh1tAmkZBEBg7yJc++qV+Td4fooAB3fCn41XFsNSignvTCxMUiATPkgzMP9fhauzRjgZaBQ5HcIGuxPmTx0Udq+3Cn3qWJLlDe/nv+K099U2p6txLHtf0pD+yw4Vb3oLryPu6WNBfNeowtfD0mKiFA/g0KOb7zJZixxRcZaHdJpboBN1nzdLnNy9/2AOGKuwq4Z1sggHDGzyHK8IaDabdHIKHqL6XslVUKwxVgwEzA+ihvVyKYSq+pxxpb15bOhnzZiMzAb4outrGhXpzbSg8NS3N2pYWKkHdxHM4VeuECqGuStWV2bEW6V/YXkQU2scIV5G7iz469Psrj2mdQLLnVa4mlN37lUx2n0A6Kdkdj07oSBkUbXhRhJyk+tE3BAF2DufNAqiL2e6MY7Qfh/ubLaHZymHafQbW9sA8qeT5b0iL/ku7T/UH1fOp7c1fPqquMNxdN/5o6hld7+A6tNU7NP77xqflmiTIywBvCS6cQXMfjq9pbmy+LqsKLMT3G01wcBfBeoROlk8+tE22lhO98vOZ9g8jccVWsEN9l84uo7xj0z5tUUfHFD8HE7ai3hRibdf+77bMFwxYQIbVzMjMvHBIMhDijfJnZDmE0xD3tsHyiSnY10U2QHuf7l/7ziAyu9DnUuImqspxa2qdUhQQ28umh9Hu8yZKaw2OZc1F66QoZzyvajIDG0jmceorhvcYZoaqbvhesdAP5wOMtrgu8elZgHXzJ2Zu2SRl2H3Z3ansR+prCZIu/xqV47rExKAo1wB1qGiAusa/x7ebzs1vFPmF6S9orAVIzfUd6mENfifsz9NK3rdUT/hL7V8IluxP+GB5yhKf5/lzZF5RgJdXWYmDPTRNl+/ecPyW7gVvHzYeFqha6AMocy0+XQ4uKNVL5yO1Dr96DPtzPsH5/YviB9H5W7mzqX4iZDQWoDz9TotBRatgu71HF8hxyB0e3M0cebsWT0oBIzzs21xv6J4YjTTlClBJUrBTH7lxYPdMTqNtaFWlgpYKyQw0DfW2x7ooitP/xP1LRc+aDBQZE80OS2z7i+6MTRS8Witl2zFZ5qDt0HXv4LCCspI/GDaHuFQCKf4u2UQEdIF1J1jVLQJmDhL0UV9ZYTmk81l1NQllUh1NJICCDSxOLlRxToJaSY3jTaQAO5jGv0HSsuWjI0diz3xBaBv0OySc4NO9YZCN3X1adHvL9QfWTv7jIBYVQhI2Il099uU+iEj3TM38Tqq3AXC1ffn6XcobOI1f8jCs1YnXBurhu7+ygpkFwUbnUnNwDueSPR352IsCFwwfVuUCDa4EEbZezehENZZhS9pEhrpliFIDAbf4ms7ZaUn570akfKfAGvZgzsYWR3YnTw/SqC9t5b4gkiV7//Bj9SnMBFGVcO+N9cad5EYus4NljdgKzRBBmsMUxqsI25jN3MQfwrxbFU0A4mkUUzkw273e+JC4L54EhPFWPMssllH4dpmm/C+rQExoQ4C0fDnLGuH5GDmAs35ABIKTm3e54ezTJjEhaY+oZuupv58miqUQ41ywwyGBHqSzRT5VICQZPU/ACgGJmbOMctkGYp47dQaZzBfQvX/+we6C9tqP8Aqs6p/gRUEGWY4+H501G7XX84TsJ+bzF6BvQCyrYYZ+izZ/M7fKE/onWmnENPOtDimNZAJwe5e5ZbbatYkFiHH47NuioMOUDKaC0hU/sKvnT9Og/NgYJYqTWZ1FyTOZPjR3oPZfQwfs+FCU7OWFC5eEK5REYtyd5xepaY3YF6XkeH9m6wkj3Szy9Wu+0Nf1VhfEEorDUZ7OE8QrwmIvN8jcHBg6cBfefionhqAt7cj6vrFWpGW1veKcuemaod6sTewTHQmWEREtJiyzk1gXqGxWC1MdIM0Tlm94kN/H+BpV1cYWz8ysa54BBId8kOXNsZz40JzQI4HLvHQM6/Am+tyVFgnjxAC0pUu5xbw7XueceVxiddFHGfTkaTT1oP1sOdyreFJdW+DQetfeRWQ",
            "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",
            "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",
            "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",
            "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",
            "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",
            "D74VY2g63an7ZDYma0DlAXSSodYHxNrBgZbChaOAv3nWCFrcNQ0ZyhlcxM/aoAkn25K1BsAQ+fZqXNtqRsNWUDIS4Q7qaPvIoWUMGirjuUOkYc2m3VCPNJWdhU00CaRFGOSncEsLeC34HWLhjZZXGULkqVeb/HN22lsj6DGPs6IrXq5w6Z7+bMVgH4lzt5CkGz5s4h//vuw3KyWU8f/+95I4xAOAsYf4vWOIuLEtTBHgeWCFCrmXQgkB7UAPnvV36VVd+pvbuRuaTZ4eDrV7X3QHbtRVJGRUuFbuT7fggKqYRZYuIUq/R32POGJvVT01U9SPiQyFeqhJE3AHNWumJFGr78ne/c8VLsWBywehq2roqLPEbTBsA1Nb1Tm9hBzWNJuFXCOvTlMdIOt2tv4PYk6njA/px54FIY23pKJNcLkuXBw5PO9bUjJwIS1+w/MUTpM8eRGxWWERmfsSwMc4tBqkVFX6vX9tH+v3/75yTDHHedfCkxQhfbp7VGzHHhdsu0VmUJtG1o+nmqjawGcVUNOzZKsNBCe2YaISWVELVCcnYoeTi04sXF9j9IewPOkvYC0w5CkSTaQ9xfMBBEokCsFBEnFOA6/yC/JHa5pARbO4bzsyn34rxW0wOTYO+dipWpqJ4U8nudUJyrtMI1elmkElVUYgwl8z6f2MwO1ipF+/dRF/p9PAIE8p+VF3PpV7unp3+I0A8Qg+g8Nlnh/VoOTYXx6jQFweKYIylagMIJ5n2c2ZRMWshC3a3nVh14oFBkHUjdkLAgGeN1sEU0eRe+ku2QACAb/kEVXvtRtENQjeuBQyvaCXcITolM5kkGaW3ldFvhKrPk+gjfMVeADOdVX6vKmT2sARfl0MGWiWPgmUp419GT4pY4PIkHuTaMnghGQSa8SSezx6OIol7RxTpTdujbnR0zsZXl6FU648JywWe8ame3tvtoLocOTz4yrdMAN+GC2ePUOX9NvCoDO44K6HNotnnBp5pb/3T7EwkTztzoyUe7nsvGmRF5jv5KevWMMHIrQTBVdYPA62EVhkqXDo+q8mXiRfgJBPCXLSoPG1vE1XhU7plN7gS5Zv0GJdrxqVycuftJluZMssOZlxmwm+eujIr/DndO4v2l86DbNYcbajjBI/zKewS2GRbbXnfWmr/rXlGzX1Hf++btxCV2GVnLQpkxI0PqjKhpUYFrEOwNfw/vQq5d0D0c2S7r0xuKwaaprtj+b01ni6Yg+QuWnqQQmo8QxjIr9AMZ6jC2hVxaS50t1liDFVVJGAyCTRgjYb3OOixLKguZnQWyau+0hj958aYK4cuaHUlprpjMRdpeI/pTHEsJ9O5t2TmlLOKpEoY6wIdZOu6hd2FVdI3m1hkfuYoHcL5cB7zibo457ZUiFjIdYDCz4sTT8wuLUeHOHWiIUVjX0X9jn40TSgKlu36LKR/xyFb42Xleg+n1+nCyFst37yuoStrRV6VsZRzrF9tVY5hIaHm4uzu7XKYZPSG96Mo1XSNqhlMVaXpNvltOSbA69zTVYdtotxpwhILDXdNff6dLvYPut+Pay+TJwG42fWU+iPCtDw2jp3gA6yCNnPbg7HBq1TSmYXxtcH0BLD0x/gH3vKQMk2/ZL8DiiDl3AQxJtLOa9L00lJR9+orOcAxyIn5CF46s0LaNCgJlRQ6Nn4nHJCvndRGX2diOsSjsOZuwFikK4/ERtqCuA94eota/eU8b0Ncg63zM3tWIWFFZjrBgIgjuV9aO2TpEhfD7T6HdWrhY/ZooOC6fe/5yZfZhKk3KalakB4RbVLQTRE6YVK4ZVZ2m35rz/idNflIf97wO1RPtB5GTDgxuFHlWoDS6IQ5qIdkzOSMBrThKHniPCQ5pZiHCPbeGx/iKFl5s2oHFBTt/i5JQ2+WKwZeYQje8vbHz8Zc7Hgucq+XS9sY0u45r4xbhE43P27czOYaT2FwahIQGF9N8q477V+/cDMiOqEeu/tdByGDXl7YoQ5v8GlQoPQs5b3",
            "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",
            "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",
            "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",
            "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",
            "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",
            "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",
            "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",
            "1BdZ9tBGTCqFc/Ct2WRCVzFiZlWnT0Da4wO0dT57+Ze2MoF1OHf6nuttq/kx//2t9B+JKSqEjcxye5oVvsjf8J0V9KIYm+jeXilv28sNUEsn1J037gc4uIrCJD1uVOSXxVuLVV/itVaOwIUP8SLMbz+qq81I38T41/kNdfpXLQCkHKrgThSqSd85uD+9kxNSK1vnxkSePfdWkj78MNUWOWc74pHdqKcf9xS4E16xIKaGa9HdoSe/WrVlUtWGiCDakZ5z99C3PPlTxgS27r8idvdjP50v7fN2huF+xEFnkPSvTWAia2C1TMcdLUSVoiP68MrALgbbRUpzATey5E/+H+0KySJUxG4ae0FEJ04s/pniTfMQIdHuPMbdlLjujN9tb0TyikOPFic74x/Dmcjfw2APljQaGzX7zM+t2iDT0PKGfpwAzQX0UtZTunHgLDj+pjIBEh5qOjZG8j0xGjcRMX/LwtARe20z4rV75bWxDjyXXkno1Y+nk1HpX+L81kgZoADdeB9FHNbAnCloho1Q3lqdFy04e+qkL42FcmZy9Hjshf/q5oxci2CX2HuxPOSh0wjoU/9yxeYksR+n9jZ/57R0wlqKixz4FbAra//s8Q31/vfy5+39zaZzya00JKBs+cY1qg/CAVRhezF0FtMjJNOiSYOyI8samqV8tZsXtkrdgZbWc3KHhrCPEAjQJ8iKcQM0IuoOqj0z3Fz29F1qMNkHZxggoRQm7MH9nsXL7DhRjYJxBKARJKB/PNbLiqGOzpJjm0FFFdV4MQXuCikvyoSonW7grtci/rYLmPWxAJqmwr5Qer8qBNjBvXL0DsrZmLLoYJAhnEKWeq4Zt+cvksBUEB9X12o6/Rn3PT1j8nXYQuuWBl5LRSwIhto0WlQIhi5o6OYYUYozJFxjsjvjwhQibh+oK3uJ6BD4EIiyYtdxonOP7a5jnPM0ub0K5ue+3KpGb7aLc0oWeF2NV0xs3FUClgjSDKrXqJZuE7vV0i9cyYHxLhHqbUSihR6Yk4tgf6e4Zd4Al5ujk/AmHwvEtT2RVvatcqI1lpJbULO+gQTYJOMd2HD9Vje0cWcNrM69J0qADdm7zUfdoZWJZmzIMn5SRaf3ohRNgEONXXC7vSi1P6xfiHfZ/h88+PjPUq0AQc2Aw06RaUrJiwdq2rnTAIwxkZ4Qo9XPJ/Z/eTfsfWrTIWbQXAsf/qb5RPwG6Txy5SPuda5u1Vr3IpAl5GI4QAoMl2spCffRwRvtmayCqEs5BzAZ8RWoXnQ9c0TU+QhgvDLkDTgYBW2xzhzDNwDyjNH1m+9viQYi1kDf5gBUAh89nrRAmUsTeCgZMZ5JwI/ZYiCnc9SfdZrpCAd+Lbs7MFQkcCyjvtqZ1Ow1HGiinydYbPd6g/S5f7Q890MHEs9DoHvxGTQtYzH7lzM5lwHVliHDgriqFHAqNVTFkF31XELYOJxHOAsBQQy8glnlB02O1gfrdqiKJ6nK/Guai75aR8JdIEsVnl8EaeRJK1eyjdhYJvuN3pZ/SqnQGN/r1EjwUPUrx+maR6HugUoUMdkQk6Qw0Q8fMcYggj2Z0bvvvrSsCF4IuPTo8xIlSfr9vwv7sBocs0NwXdVg3+OhS0GdEx4g75/P5WF6O5CfJWQjoHwMz9yFDH6P2k+mqTNvZD+R7aPm5PZzAgt2Kkx3XyH2dg8w77bnRtcKJgfSsVPMEInn0WleevetQIqsWw8wvfeNItvtnKaSLWXYKCk1dygB4SWhrIM/1FiKRxX91bfbai4LhOvInnnLDwrPV1z1J2eGFgnydZ9hk7Qss06tRVDH0+ms9h+9GX2/08qQjhWKZ72Ej+LG4HdGO4d+sbhGrwnUGreKPqLoIK3UqDA293Vj3Uf1i6myiytZpxOgh7H5RsIY8p7eRbwp1RbqHYOFLIIivEwl1kLqdnUqSG07aY3ZSWq4Gn2pyIWboShwOjl4fjA+I4R2uBJGgupffwGXlZ9rfpjS1CL440jdK8I9",
            "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",
            "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",
            "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",
            "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",
            "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",
            "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",
            "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",
            "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",
            "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",
            "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",
            "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",
            "nIeu0KXyZkemV8MyikakgaM19MwwUgS4Ax7p78E6AsMtxVcx2fQMwbQkm1hN3TVgsjdy1iNunVctd0wc4+RlrBgQ636hhcUBmpeEu/iPWbwtpp0os+flQC3ZdPRCfZaN8VPKHBxZbF8UimFbCOx6/WZeherl6/XAzGht6lX1hqT97XxietIWo1Yefh4aaD1GLzlwNs+H5z9XEux0Gw9fdM9OZ6LtfU2vnYxDbY+yGN3sZGwV0TH+m6rxHN2QZjZYTUbYoPsR/VqxNVvD+Nk3E9g2WRWCZfZP081dZN5PnvxoYfxLbQY43YS2M4ufPzBW0n6IGQsGD0u1LhvRd80c5DEAfHWBeVo+AmTJv6aMDhjibQ36DHqD8ijMYBE3KvY7PrxzxwgzuxknKeYYVX+h0tVBjTmwlI8Uze0XJPa25FflqVo+3ES0cNO3XN9kKwzQBcKlyl8kxpZP+cryVqkHvxWZ5aGWq2vWAf61ougB5C8C+ZlK3XP+4U1F7S9vDEd+EbJ07ksbjFUVbZndexMV2JK4ZIpsES6fEE8juOu75EAx2Lcc68QnQSwT95fXXmykIQEbRshKdiw22QPkRqJxgsAgNYhr9Yg64g2daYA15u70xZBgRqfMNoAwlLnv2Eac1kLWrfjZCNdlu2aAQQS2YX5Zz5NhAOpJv5k7L/w/7Uw/GXxhbJulF2M+kyXIC2hTrgzGE5Ur8QWyf50hlyKsvfxiqamQRjL/XgV5I7go4QpKkEC3382AdmlPSHgW/nc6QBkjGzqFW0EqV8VVDUdJmg8KigNLHn2Kjkb/fQdm0/mUEcmxy11xRfaXHI6UeirIb0G0GOPsw1+1w2SSgmZBkaPIzwALIangZYYMQFmSkul5TuZ3I5ArTOwoFAvOJt+iRWOsTI8rqAfpUeyd528uaKad6mwxk3geoiCbDgcS+Xt7M+1nMXDYpjWShxMq+1xXQ9z2CCPf9I1HmKFuEfJ1BHttO4d92IAZ6uJzsgUUFFnTwGJMPzULoJDrSx9GZ9PMSRAT8DO+8kDNkh0Kuu86I9aTOIZJohnV6u9CBABF0C+xkO/WCh7DXstbdi2nJWG1WwW4aN1jdIqsYzNFMgbiA7CJVGn922xEwz0ng1/urlXIxJ3evd3vrSFRtiuxjOHnAG6E8FRKWcJZztj5pLpBnH82P7hVprHeStbOzwWAxiFf0dLkaUWGYhTmnvU5gdTmc6+mMeKZMWnDAn4nc8MyR8cNegmaLUydJf1n6SEArLg/1LHwzlFTKDKCUddnyQ2Q0D91XnLPRUMdoWcKpxHBfcAt28P2IcExkTg/FcIktG5QCq71AnQ/0JR7mQxXGUaArkMNT9Gz1K+63Pd3ooczhgWtiw54FoocLB3SptM3DZfIWFYXa8antpuBtP8BSafRNZ+wkjPm4jPSVXql7t+OqDeJn9h6f20YilkaXICWmeODpwppNXLdyNvHrCB9nP+Doa9Fc6ZzVPGQzHEwmSAFQ/Qna2yCPomYj1UOATX2OFkdtVj7pJaHhpc3acBQih68yLxRhAFx6zcyCTaAzB5Jl2F42RAx8f/0lldn4F3WTjX0d2MdvJ4+dm9VChBWYPyLFWBEYLJJWbyHqPu0EaLHiqmcChNLRSj5A6tOwtAOar1a5q4FzL4UFypjCQPY4ukJ9pvZw80ZMr2y2fN3DUOHtG9rncqcIWHGrm7YmQrYwgbGNRF8dLtWLtB9NPJKz+Ae+PytsI4s1I/m3XcOIpuX59WrshzyAO8UW3lsmFnQzHJcUVSudD9R9rCfuLOYL6tEuiHCvqEdaltx+il7pKhi4LIFLxI2gSv8OJ6hh2X8igcNHbIT1HnRmzW/YujkzCEA5nzZ3DW/oflbO6EdvGrw71ihiUFuP/WKeIDyeJjlo7PAC3ObQokZxRbhARnI8yLEIXe7fWG6kas4S4b+SqHIK5xY55wHCA9fnyJMjKKsxO7o3+7mP4IOXp7XOxFfc3i3D07XVnjX1Am/j63d",
            "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",
            "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",
            "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",
            "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",
            "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",
            "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",
            "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",
            "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",
            "SR/aKJnHb1VbLxTbPbxW1fi0Wy54DzgAmXHocl3m3/ZOyrK+HjZVtWdJ+rcqy2HRprNQHLemKw9lEr6t5ltBdMidQzyj1G4+CkdMeUTbVWf+bW+QInHLSnlngdATjmF23H9gfL+i7GBBWyyU0X7hd8J98Mvn77k9uq6Wfa2BZCDlbAYcxOxGGoQ41yL+AOaYwphP6SWIVL/vHy1/pKMPtS98BpMtqBZ+FuHsJkvDTpChWnxq14TBu1lzNrVIk4dXs1vb9MihFjvvlBmXMEVu6w602h24QPnmmL7y4he0G4X1nilnMw2L+qHgW3HvwKLmKJAzcnxQBBRZ9fdjB8AANjGuJqb2bLYs0UCB1P8cpJiWKM78LYU79rXkfCy3TUzDfSyXofQiLcgGgCg5X6jeVLUoRD9lJe3JEDV7lxcoNCESV2Tczm35QmxKcsPEwtUSU6bLFIQsRh0JvEeeYyM1InIv3Wvk0eilpI2n1KO55AXx/egUH47pTfRGNWmQwH8r6zA90NpAqbvZMGvC/biJ2RzFmbL1QFjPW4oUYGiIulnBWN41eYFaDyJZm8F4CEPVqCquW6QGt6yij+QCDSt3FMiOGsvbX5i3BRORXTCrsk32zFNPW5gp7QRQhLz0e+bubAW9zZmGPYQ9Fa/+6FfKhcsq+ZwU5/fQfc0Z8Wn+YuXnoG8hdf5wavcknfN7UL9kQcQtcKIS6G3lBOMO8xMdBZaH3rGYLEZ9K9g0W6TKEzittAB8S0M6bLxCKwkZVogZXRy+uWIhEWF0/TdvitiHCEZo7wYH1GliJZPPx9mMNLotx9w4rU5D42SskY/rZrXznQoWIZsmtoWBLHe+eBlRNoLm30xyckRue72FYlFF7FZAtNEEtxSSQK4sjjH0vlf8TEvkR+TwNcV6YWOEM4lVcBN5x9wwCoxt3no4/gAHO6Sw6baqPYVAFiSDn73A7/G4L86jjuryxHRNuDydz8FkyR76OzMcZvn8mm0h/Oo+OyA4z9l5EUE1B2/7Xfqym0qMQGehBkd3zdiQsCSsz/y1WM5xinOt+XX3tYe0ZcSaRZj5kBxHRoyL43kKT/WtgjpM5V8zLSC0juaZeLgOoFyFWtdwtIWRNfI0DdOmsPU6yRluX8vjN703agDGSaMMryej7wFBf7PuJywcbwFExNUY7jDyy5kLrW8QoBJvzQlDczvHGN7RPDTC7r1EzRnHzMbysoyZIdoKksFR27Ig2rsnT3m9d/ev1QR/80+FTcQdad=="
        }
        local _fullB64 = table.concat(_P)
        local _b64Len = #_fullB64
        local _alpha = "BxYmNzwgSJh5HUGXdWvi2obtI0/qP74KE9R+aeCA8FQj3M1rZTcypD6VlkfLsOun"
        local _lut = table.create(256, 0)
        for _i = 1, 64 do
            _lut[string.byte(_alpha, _i)] = _i - 1
        end
        _lut[61] = 0

        local _key = {169, 22, 251, 244, 171, 107, 234, 221, 179, 255, 179, 101, 74, 67, 244, 208, 181, 47, 26, 206, 218, 91, 76, 244, 51, 73, 93, 136, 50, 70, 139, 63}
        local _klen = #_key
        local _rawLen = 146443

        local _S = table.create(256)
        for _i = 0, 255 do _S[_i] = _i end
        local _j = 0
        for _i = 0, 255 do
            _j = (_j + _S[_i] + _key[(_i % _klen) + 1]) % 256
            local _sw = _S[_i]; _S[_i] = _S[_j]; _S[_j] = _sw
        end

        local _si, _sj = 0, 0
        for _ = 1, 1024 do
            _si = (_si + 1) % 256
            _sj = (_sj + _S[_si]) % 256
            local _sw = _S[_si]; _S[_si] = _S[_sj]; _S[_sj] = _sw
        end

        local _bxor = bit32.bxor
        local _band = bit32.band
        local _bor = bit32.bor
        local _lshift = bit32.lshift
        local _rshift = bit32.rshift
        local _sbyte = string.byte
        local _schar = string.char

        -- Native buffer engine (high performance & zero memory garbage)
        if typeof(buffer) == "table" and buffer.create and buffer.writeu8 and buffer.readu8 and buffer.tostring then
            local _cbuf = buffer.create(_rawLen + 16)
            local _cpos = 0
            local _writeu8 = buffer.writeu8
            local _readu8 = buffer.readu8

            for _i = 1, _b64Len, 4 do
                local _c1 = _lut[_sbyte(_fullB64, _i)] or 0
                local _c2 = _lut[_sbyte(_fullB64, _i + 1)] or 0
                local _c3 = _lut[_sbyte(_fullB64, _i + 2)] or 0
                local _c4 = _lut[_sbyte(_fullB64, _i + 3)] or 0

                local _tri = _bor(_lshift(_c1, 18), _bor(_lshift(_c2, 12), _bor(_lshift(_c3, 6), _c4)))
                if _cpos < _rawLen then _writeu8(_cbuf, _cpos, _band(_rshift(_tri, 16), 255)); _cpos = _cpos + 1 end
                if _cpos < _rawLen and _sbyte(_fullB64, _i + 2) ~= 61 then _writeu8(_cbuf, _cpos, _band(_rshift(_tri, 8), 255)); _cpos = _cpos + 1 end
                if _cpos < _rawLen and _sbyte(_fullB64, _i + 3) ~= 61 then _writeu8(_cbuf, _cpos, _band(_tri, 255)); _cpos = _cpos + 1 end
            end

            local _dbuf = buffer.create(_rawLen)
            local _prev = 137
            for _step = 0, _rawLen - 1 do
                _si = (_si + 1) % 256
                _sj = (_sj + _S[_si]) % 256
                local _sw = _S[_si]; _S[_si] = _S[_sj]; _S[_sj] = _sw
                local _K = _S[(_S[_si] + _S[_sj]) % 256]
                local _W = (_step * 61 + 173) % 256
                local _encByte = _readu8(_cbuf, _step)
                local _rawByte = _bxor(_bxor(_encByte, _K), _bxor(_W, _band(_prev, 31)))
                _writeu8(_dbuf, _step, _rawByte)
                _prev = _encByte
            end

            return buffer.tostring(_dbuf)
        else
            -- Table fallback branch
            local _decBytes = table.create(_rawLen)
            local _cpos = 1
            for _i = 1, _b64Len, 4 do
                local _c1 = _lut[_sbyte(_fullB64, _i)] or 0
                local _c2 = _lut[_sbyte(_fullB64, _i + 1)] or 0
                local _c3 = _lut[_sbyte(_fullB64, _i + 2)] or 0
                local _c4 = _lut[_sbyte(_fullB64, _i + 3)] or 0

                local _tri = _bor(_lshift(_c1, 18), _bor(_lshift(_c2, 12), _bor(_lshift(_c3, 6), _c4)))
                if _cpos <= _rawLen then _decBytes[_cpos] = _band(_rshift(_tri, 16), 255); _cpos = _cpos + 1 end
                if _cpos <= _rawLen and _sbyte(_fullB64, _i + 2) ~= 61 then _decBytes[_cpos] = _band(_rshift(_tri, 8), 255); _cpos = _cpos + 1 end
                if _cpos <= _rawLen and _sbyte(_fullB64, _i + 3) ~= 61 then _decBytes[_cpos] = _band(_tri, 255); _cpos = _cpos + 1 end
            end

            local _chunks = {}
            local _buf = {}
            local _prev = 137
            for _step = 0, _rawLen - 1 do
                _si = (_si + 1) % 256
                _sj = (_sj + _S[_si]) % 256
                local _sw = _S[_si]; _S[_si] = _S[_sj]; _S[_sj] = _sw
                local _K = _S[(_S[_si] + _S[_sj]) % 256]
                local _W = (_step * 61 + 173) % 256
                local _encByte = _decBytes[_step + 1]
                local _rawByte = _bxor(_bxor(_encByte, _K), _bxor(_W, _band(_prev, 31)))
                _buf[#_buf + 1] = _schar(_rawByte)
                _prev = _encByte

                if #_buf >= 2048 then
                    _chunks[#_chunks + 1] = table.concat(_buf)
                    table.clear(_buf)
                end
            end
            if #_buf > 0 then
                _chunks[#_chunks + 1] = table.concat(_buf)
            end
            return table.concat(_chunks)
        end
    end

    local _rawCode = _0xDecCorePayload()
    if not _rawCode or #_rawCode == 0 then
        if LocalPlayer and LocalPlayer.Kick then
            LocalPlayer:Kick("[1000Z SECURITY] Decryption fault: Invalid payload image")
        end
        return
    end

    local _compiledFn, _compileErr = _c_load(_rawCode, "=1000Z_Core")
    _rawCode = nil -- Instantly wipe plaintext payload from scope

    if not _compiledFn then
        error("[1000Z Core Loader Error]: " .. tostring(_compileErr))
    end

    return _compiledFn()
end

-- ══════════════════════════════════════════════════════════════════════════════
-- ENTRY POINT EXECUTION (KEY SYSTEM GATE)
-- ══════════════════════════════════════════════════════════════════════════════
KeySystem.Start(KeySystem.Config, RunMainScript)
