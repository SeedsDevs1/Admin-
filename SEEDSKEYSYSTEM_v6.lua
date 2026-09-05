--[[
  ╔══════════════════════════════════════════════════╗
  ║            SEEDS KEY SYSTEM + ADMIN v6            ║
  ║  /open · /t · /spin · /g · /enter · Notes · Gifts     ║
  ║──────────────────────────────────────────────────║
  ║  v6 KEY SYSTEM REDESIGN:                         ║
  ║  • Compact UI: 480 × 170                         ║
  ║  • Player Avatar frame (left)                    ║
  ║  • Live FPS + Ping (Ms) display                  ║
  ║  • X button → minimize key system                ║
  ║  • Top square button → restore key system        ║
  ║  • Smarter anti-cheat / key security             ║
  ║  • Polished buttons + smooth animations          ║
  ║  • Same content (GET KEY / SUBMIT) kept          ║
  ║  ─────────────────────────────────────────────── ║
  ║  REMOTE BACKEND SETUP (cross-device broadcast):  ║
  ║  1. firebase.google.com → new project            ║
  ║  2. Build → Realtime Database → Create (test)    ║
  ║  3. Rules: { ".read":true, ".write":true }       ║
  ║  4. Copy DB URL → paste in REMOTE_BACKEND_URL    ║
  ╚══════════════════════════════════════════════════╝
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")
local TextChatService = game:GetService("TextChatService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

-- ═══════════════════════════════════════════════════════════════════
-- REMOTE BACKEND CONFIG  *** REQUIRED for cross-game / other players ***
-- ─────────────────────────────────────────────────────────────────
-- Kung EMPTY ito: Codes / Notes / Gifts ay LOCAL LANG (ikaw lang makakakita).
-- Para makita ng IBANG players (iba game / iba executor / phone):
--   1. Pumunta sa https://console.firebase.google.com → Create project
--   2. Build → Realtime Database → Create Database → Start in TEST mode
--   3. Rules tab → ilagay:
--        { "rules": { ".read": true, ".write": true } }
--      → Publish
--   4. Data tab → kopyahin ang URL (hal. https://xxx-default-rtdb.firebaseio.com/)
--   5. I-paste SA LOOB ng quotes sa baba (dapat may / sa dulo):
local REMOTE_BACKEND_URL = "https://seeds-28529-default-rtdb.firebaseio.com/"
-- ═══════════════════════════════════════════════════════════════════

local LocalPlayer = Players.LocalPlayer
local PlayerKey = tostring(LocalPlayer.UserId)
local DATA_FILE = "NovaKeyData.json"
local executionWaitStart = os.time()

local T = {
    bg = Color3.fromRGB(10, 12, 16),
    card = Color3.fromRGB(16, 18, 24),
    card2 = Color3.fromRGB(22, 25, 32),
    input = Color3.fromRGB(28, 32, 40),
    accent = Color3.fromRGB(0, 210, 160),
    accent2 = Color3.fromRGB(0, 160, 255),
    warn = Color3.fromRGB(255, 90, 90),
    ok = Color3.fromRGB(0, 230, 140),
    text = Color3.fromRGB(245, 245, 250),
    muted = Color3.fromRGB(130, 140, 155),
    orange = Color3.fromRGB(255, 150, 40),
    purple = Color3.fromRGB(150, 80, 255),
}

local function getGuiParent()
    local ok, r = pcall(function() if gethui then return gethui() end end)
    if ok and r then return r end
    ok, r = pcall(function() if get_hidden_gui then return get_hidden_gui() end end)
    if ok and r then return r end
    return CoreGui
end

local function protectAndParent(gui)
    pcall(function()
        if syn and syn.protect_gui then syn.protect_gui(gui)
        elseif protect_gui then protect_gui(gui) end
    end)
    gui.Parent = getGuiParent()
end

local function loadData()
    local d = {
        MainOwner = "Johnzen_gamer6",
        Admins = { ["Johnzen_gamer6"] = true },
        DailyKeys = {"KEYPASS1", "KEYPASS2", "KEYPASS3", "SEEDSDEVS"},
        ActiveCodes = {}, UsedCodes = {}, BoundKeys = {},
        Feedbacks = {}, Logs = {}, PlayerSpins = {},
        UserAccess = {}, PendingGifts = {},
        ScriptOnline = {}, -- [userId] = lastHeartbeat timestamp
        PendingResets = {}, -- [userId] = {Reason, Time}
        Broadcasts = {}, -- shared notes: {Id, Message, Sender, SenderId, Time}
        PlayerGifts = {}, -- [userId] = list of claimable gifts
        SkipTimer = {}, -- [userId] = {Name, AddedAt, AddedBy}
    }
    if isfile and readfile and isfile(DATA_FILE) then
        pcall(function()
            local dec = HttpService:JSONDecode(readfile(DATA_FILE))
            if type(dec) == "table" then for k, v in pairs(dec) do d[k] = v end end
        end)
    end
    return d
end

-- ── Remote HTTP helpers (cross-game / cross-executor sync) ───────────────────
-- Syncs: ActiveCodes, PlayerGifts, Broadcasts(Notes) via Firebase Realtime DB
local function remoteEnabled()
    return type(REMOTE_BACKEND_URL) == "string" and #REMOTE_BACKEND_URL > 12
end

local function _execRequest(method, url, bodyData)
    local body = bodyData and HttpService:JSONEncode(bodyData) or nil
    local opts = { Url = url, Method = method,
        Headers = { ["Content-Type"] = "application/json" }, Body = body }
    local ok, res = pcall(function()
        if syn and syn.request   then return syn.request(opts)
        elseif request           then return request(opts)
        elseif http_request      then return http_request(opts)
        elseif http and http.request then
            return http.request({ url=url, method=method, headers=opts.Headers, body=body })
        end
        if method == "GET" then
            local b = game:HttpGet(url, false)
            return { Body = b, StatusCode = 200 }
        end
    end)
    if not ok or not res then return nil end
    return res.Body
end

local function remoteGet(path)
    if not remoteEnabled() then return nil end
    local url = REMOTE_BACKEND_URL .. path
    if not path:find("%.json") then url = url .. ".json" end
    local ok, raw = pcall(_execRequest, "GET", url)
    if not ok or not raw or raw == "" or raw == "null" then return nil end
    local jok, data = pcall(function() return HttpService:JSONDecode(raw) end)
    return jok and data or nil
end

local function remotePut(path, data)
    if not remoteEnabled() then return end
    local url = REMOTE_BACKEND_URL .. path
    if not path:find("%.json") then url = url .. ".json" end
    task.spawn(function() pcall(_execRequest, "PUT", url, data) end)
end

local function remotePatch(path, data)
    if not remoteEnabled() then return end
    local url = REMOTE_BACKEND_URL .. path
    if not path:find("%.json") then url = url .. ".json" end
    task.spawn(function() pcall(_execRequest, "PATCH", url, data) end)
end

local function remoteDelete(path)
    if not remoteEnabled() then return end
    local url = REMOTE_BACKEND_URL .. path
    if not path:find("%.json") then url = url .. ".json" end
    task.spawn(function() pcall(_execRequest, "DELETE", url, nil) end)
end

-- Sanitize code name for Firebase path key
local function remoteKey(s)
    s = tostring(s or ""):gsub("[%.%#%$%[%]]", "_")
    if #s < 1 then s = "x" end
    return s
end

-- ── Push helpers ────────────────────────────────────────────────────────────
local function pushRemoteCodes()
    if not remoteEnabled() then return end
    -- Push full ActiveCodes + UsedCodes snapshot so other clients can redeem
    remotePut("nova_codes.json", {
        Active = SystemData.ActiveCodes or {},
        Used = SystemData.UsedCodes or {},
        Bound = SystemData.BoundKeys or {},
        T = os.time(),
    })
end

local function pushRemoteCodeOne(name, data)
    if not remoteEnabled() or not name then return end
    remotePut("nova_codes/Active/" .. remoteKey(name) .. ".json", data)
end

local function pushRemoteBroadcast(msg, sender, id, senderId)
    if not remoteEnabled() then return end
    local key = "b_" .. tostring(os.time()) .. "_" .. tostring(math.random(10000, 99999))
    remotePut("nova_bc/" .. key .. ".json", {
        Id = id or 0, Msg = msg, By = sender or "ADMIN",
        Uid = senderId or (LocalPlayer and LocalPlayer.UserId) or 0,
        T = os.time(),
    })
end

local function pushRemoteGift(pk, gift)
    if not remoteEnabled() or type(gift) ~= "table" then return end
    local gid = remoteKey(gift.Id or (tostring(os.time()) .. "_" .. math.random(1000,9999)))
    remotePut("nova_gifts/" .. remoteKey(pk) .. "/" .. gid .. ".json", gift)
end

local function deleteRemoteGift(pk, giftId)
    if not remoteEnabled() then return end
    remoteDelete("nova_gifts/" .. remoteKey(pk) .. "/" .. remoteKey(giftId) .. ".json")
end

-- ── Poll / merge from remote ────────────────────────────────────────────────
getgenv().NovaRemoteBcTime = getgenv().NovaRemoteBcTime or 0
getgenv().NovaRemoteCodeT = getgenv().NovaRemoteCodeT or 0

local function pollRemoteCodes()
    if not remoteEnabled() then return end
    local data = remoteGet("nova_codes.json")
    if type(data) ~= "table" then return end
    local changed = false
    -- Merge Active codes (remote wins for newer CreatedAt)
    if type(data.Active) == "table" then
        SystemData.ActiveCodes = SystemData.ActiveCodes or {}
        for name, cdata in pairs(data.Active) do
            if type(cdata) == "table" then
                local localC = SystemData.ActiveCodes[name]
                local remoteT = tonumber(cdata.CreatedAt) or 0
                local localT = type(localC) == "table" and (tonumber(localC.CreatedAt) or 0) or 0
                if not localC or remoteT >= localT then
                    -- merge UsedBy
                    if type(localC) == "table" and type(localC.UsedBy) == "table" and type(cdata.UsedBy) == "table" then
                        for uid, v in pairs(localC.UsedBy) do
                            if v then cdata.UsedBy[uid] = true end
                        end
                    end
                    SystemData.ActiveCodes[name] = cdata
                    changed = true
                elseif type(localC) == "table" and type(cdata.UsedBy) == "table" then
                    localC.UsedBy = localC.UsedBy or {}
                    for uid, v in pairs(cdata.UsedBy) do
                        if v and not localC.UsedBy[uid] then
                            localC.UsedBy[uid] = true
                            changed = true
                        end
                    end
                end
            end
        end
    end
    if type(data.Used) == "table" then
        SystemData.UsedCodes = SystemData.UsedCodes or {}
        for k, v in pairs(data.Used) do
            if v and not SystemData.UsedCodes[k] then
                SystemData.UsedCodes[k] = v
                changed = true
            end
        end
    end
    if type(data.Bound) == "table" then
        SystemData.BoundKeys = SystemData.BoundKeys or {}
        for k, v in pairs(data.Bound) do
            if v and not SystemData.BoundKeys[k] then
                SystemData.BoundKeys[k] = v
                changed = true
            end
        end
    end
    if changed then
        getgenv().SystemData = SystemData
    end
end

local function pollRemoteGifts()
    if not remoteEnabled() then return end
    local data = remoteGet("nova_gifts/" .. remoteKey(PlayerKey) .. ".json")
    if type(data) ~= "table" then return end
    SystemData.PlayerGifts = SystemData.PlayerGifts or {}
    SystemData.PlayerGifts[PlayerKey] = SystemData.PlayerGifts[PlayerKey] or {}
    local list = SystemData.PlayerGifts[PlayerKey]
    local byId = {}
    for _, g in ipairs(list) do
        if type(g) == "table" and g.Id then byId[tostring(g.Id)] = g end
    end
    local claimedMap = (getgenv().NovaState and getgenv().NovaState.claimedGiftIds) or {}
    local added = false
    for _, g in pairs(data) do
        if type(g) == "table" and g.Id and not g.Claimed then
            local id = tostring(g.Id)
            if claimedMap[id] or byId[id] then
                -- skip
            else
                -- also skip near-duplicate Type+Amount within 30s
                local dup = false
                local gAmt = tonumber(g.Amount) or 0
                local gT = tonumber(g.Time) or 0
                for _, existing in ipairs(list) do
                    if type(existing) == "table" and not existing.Claimed
                        and tostring(existing.Type) == tostring(g.Type)
                        and tonumber(existing.Amount) == gAmt
                        and math.abs((tonumber(existing.Time) or 0) - gT) <= 30 then
                        dup = true
                        break
                    end
                end
                if not dup then
                    table.insert(list, g)
                    byId[id] = g
                    added = true
                end
            end
        end
    end
    if added then
        SystemData.PlayerGifts[PlayerKey] = list
        getgenv().SystemData = SystemData
        if refreshGiftsUI then pcall(refreshGiftsUI) end
        if getgenv().NovaUpdateGiftsBadge then pcall(getgenv().NovaUpdateGiftsBadge) end
    end
end

local function pollRemoteBroadcasts()
    if not remoteEnabled() then return end
    local data = remoteGet("nova_bc.json")
    if type(data) ~= "table" then return end
    local latest = getgenv().NovaRemoteBcTime or 0
    local added = false
    SystemData.Broadcasts = SystemData.Broadcasts or {}
    for _, b in pairs(data) do
        if type(b) == "table" and type(b.T) == "number" then
            if b.T > latest then latest = b.T end
            local exists = false
            for _, existing in ipairs(SystemData.Broadcasts) do
                if type(existing) == "table" and existing.Time == b.T
                    and tostring(existing.Message) == tostring(b.Msg or "") then
                    exists = true; break
                end
            end
            if not exists then
                local newId = 1
                for _, existing in ipairs(SystemData.Broadcasts) do
                    if type(existing) == "table" and type(existing.Id) == "number" and existing.Id >= newId then
                        newId = existing.Id + 1
                    end
                end
                table.insert(SystemData.Broadcasts, {
                    Id = newId,
                    Message = tostring(b.Msg or ""),
                    Sender = "SEEDS",
                    SenderId = tonumber(b.Uid) or 0,
                    Time = b.T,
                })
                added = true
                -- Side toast if note is recent (<= 20s)
                if type(b.T) == "number" and (os.time() - b.T) <= 20 and showBroadcast then
                    pcall(showBroadcast, tostring(b.Msg or ""), "SEEDS", 6, tonumber(b.Uid) or 0)
                end
            end
        end
    end
    getgenv().NovaRemoteBcTime = math.max(getgenv().NovaRemoteBcTime or 0, latest)
    if added then
        while #SystemData.Broadcasts > 50 do table.remove(SystemData.Broadcasts, 1) end
        getgenv().SystemData = SystemData
        if refreshNotesUI then pcall(refreshNotesUI) end
    end
end

-- Full remote poll (codes + gifts + notes)
local function pollAllRemote()
    if not remoteEnabled() then return end
    pcall(pollRemoteCodes)
    pcall(pollRemoteGifts)
    pcall(pollRemoteBroadcasts)
end

getgenv().SystemData = loadData()
local SystemData = getgenv().SystemData

-- Persistent client state (survives re-execute → no broadcast/gift spam)
getgenv().NovaState = getgenv().NovaState or {
    lastBroadcastId = 0,
    seenGifts = {},
    seenResets = {},
    instanceId = 0,
}
getgenv().NovaState.instanceId = (getgenv().NovaState.instanceId or 0) + 1
local MY_INSTANCE = getgenv().NovaState.instanceId

local function saveData()
    getgenv().SystemData = SystemData
    if writefile then pcall(function() writefile(DATA_FILE, HttpService:JSONEncode(SystemData)) end) end
end

-- Reload shared data from disk so admin actions reach players in OTHER games.
-- Merge carefully so we never wipe other clients' heartbeats.
local function reloadSharedData()
    if not (isfile and readfile and isfile(DATA_FILE)) then return end
    local ok, dec = pcall(function() return HttpService:JSONDecode(readfile(DATA_FILE)) end)
    if not ok or type(dec) ~= "table" then return end

    local myHb = (SystemData.ScriptOnline or {})[PlayerKey]

    for _, key in ipairs({
        "UserAccess", "PendingGifts", "PendingResets", "PlayerSpins",
        "ActiveCodes", "UsedCodes", "BoundKeys", "Admins", "DailyKeys",
        "Feedbacks", "Logs", "Broadcasts", "SkipTimer"
    }) do
        if type(dec[key]) == "table" then
            SystemData[key] = dec[key]
        end
    end
    -- PlayerGifts: MERGE per-user lists (never wipe local un-saved gifts)
    if type(dec.PlayerGifts) == "table" then
        SystemData.PlayerGifts = SystemData.PlayerGifts or {}
        for uid, glist in pairs(dec.PlayerGifts) do
            if type(glist) == "table" then
                local cur = SystemData.PlayerGifts[tostring(uid)] or {}
                local byId = {}
                for _, g in ipairs(cur) do
                    if type(g) == "table" and g.Id then byId[tostring(g.Id)] = g end
                end
                for _, g in ipairs(glist) do
                    if type(g) == "table" and g.Id then
                        local id = tostring(g.Id)
                        local existing = byId[id]
                        -- keep claimed if either side is claimed
                        if existing then
                            if g.Claimed or existing.Claimed then
                                existing.Claimed = true
                            end
                        else
                            byId[id] = g
                        end
                    end
                end
                local merged = {}
                for _, g in pairs(byId) do table.insert(merged, g) end
                table.sort(merged, function(a, b)
                    return (tonumber(a.Time) or 0) < (tonumber(b.Time) or 0)
                end)
                SystemData.PlayerGifts[tostring(uid)] = merged
            end
        end
    end
    if type(dec.MainOwner) == "string" then SystemData.MainOwner = dec.MainOwner end

    -- ScriptOnline: merge by max timestamp (keep fresher heartbeats)
    SystemData.ScriptOnline = SystemData.ScriptOnline or {}
    if type(dec.ScriptOnline) == "table" then
        for uid, t in pairs(dec.ScriptOnline) do
            local cur = SystemData.ScriptOnline[uid]
            if type(t) == "number" and (type(cur) ~= "number" or t > cur) then
                SystemData.ScriptOnline[uid] = t
            end
        end
    end
    if myHb then
        local cur = SystemData.ScriptOnline[PlayerKey]
        if type(cur) ~= "number" or myHb > cur then
            SystemData.ScriptOnline[PlayerKey] = myHb
        end
    end

    getgenv().SystemData = SystemData
end

-- Secret /enter code (grants admin panel for this session)
local ENTER_ACCESS_CODE = "095143"

local function isAdmin(p)
    if not p then return false end
    -- Session grant via /enter code
    local st = getgenv().NovaEnterAccess
    if type(st) == "table" and st.ok == true and tostring(st.uid) == tostring(p.UserId) then
        return true
    end
    for n, e in pairs(SystemData.Admins or {}) do
        if e and string.lower(tostring(n)) == string.lower(p.Name) then return true end
    end
    return false
end

local function isSkipTimerUser(uid)
    uid = tostring(uid or PlayerKey)
    local st = SystemData.SkipTimer
    return type(st) == "table" and type(st[uid]) == "table"
end

-- Normalize code string (trim + lower for matching)
local function normalizeCode(s)
    if type(s) ~= "string" then return "" end
    return (s:match("^%s*(.-)%s*$") or ""):lower()
end

-- Count UsedBy entries safely
local function countUsedBy(usedBy)
    local n = 0
    if type(usedBy) ~= "table" then return 0 end
    for _, v in pairs(usedBy) do
        if v then n = n + 1 end
    end
    return n
end

-- Remove exhausted / fully-consumed codes so they can be recreated cleanly
local function cleanupDeadCodes()
    SystemData.ActiveCodes = SystemData.ActiveCodes or {}
    SystemData.UsedCodes = SystemData.UsedCodes or {}
    SystemData.BoundKeys = SystemData.BoundKeys or {}
    local removed = {}
    for name, data in pairs(SystemData.ActiveCodes) do
        if type(data) ~= "table" then
            SystemData.ActiveCodes[name] = nil
            table.insert(removed, name)
        elseif data.MaxUses and data.MaxUses > 0 then
            data.UsedBy = data.UsedBy or {}
            if countUsedBy(data.UsedBy) >= data.MaxUses then
                SystemData.ActiveCodes[name] = nil
                SystemData.UsedCodes[name] = nil
                SystemData.BoundKeys[name] = nil
                table.insert(removed, name)
            end
        elseif data.Consumed then
            -- single-use codes marked consumed after redeem
            SystemData.ActiveCodes[name] = nil
            table.insert(removed, name)
        end
    end
    if #removed > 0 then saveData() end
    return removed
end

-- Rate-limit redeem attempts (anti brute-force)
local redeemAttempts = {} -- [PlayerKey] = {count, windowStart}
local function allowRedeemAttempt()
    local now = os.time()
    local slot = redeemAttempts[PlayerKey]
    if not slot or (now - (slot.windowStart or 0)) > 30 then
        redeemAttempts[PlayerKey] = {count = 1, windowStart = now}
        return true
    end
    if slot.count >= 12 then
        return false
    end
    slot.count = slot.count + 1
    return true
end

local function addLog(msg)
    SystemData.Logs = SystemData.Logs or {}
    table.insert(SystemData.Logs, os.date("[%X] ") .. msg)
    if #SystemData.Logs > 200 then table.remove(SystemData.Logs, 1) end
    saveData()
end

local function copyClip(t)
    if setclipboard then setclipboard(t)
    elseif syn and syn.write_clipboard then syn.write_clipboard(t) end
end

if not SystemData.PlayerSpins[PlayerKey] then
    SystemData.PlayerSpins[PlayerKey] = {Spins = 1, Luck = 0, LastSpin = 0}
    saveData()
end

-- Mark this client as running Nova script (for Active Key filter)
SystemData.ScriptOnline = SystemData.ScriptOnline or {}
SystemData.ScriptOnline[PlayerKey] = os.time()
saveData()

-- Track last broadcast we already showed (persisted across re-execute)
local lastBroadcastId = getgenv().NovaState.lastBroadcastId or 0
local lastKnownExpire = 0
do
    local list = SystemData.Broadcasts or {}
    for _, b in ipairs(list) do
        if type(b) == "table" and type(b.Id) == "number" and b.Id > lastBroadcastId then
            lastBroadcastId = b.Id
        end
    end
    -- On (re)load: mark every existing broadcast as already seen so they never re-pop
    getgenv().NovaState.lastBroadcastId = lastBroadcastId
    local raw0 = SystemData.UserAccess and SystemData.UserAccess[PlayerKey]
    if raw0 then
        local e0 = type(raw0) == "table" and raw0.Expire or raw0
        if type(e0) == "number" then lastKnownExpire = e0 end
    end
end

-- Only the newest script instance keeps polling (kills old loops on re-execute)
task.spawn(function()
    local dirty = false
    while true do
        task.wait(3)
        -- Stop if a newer execute replaced us
        if getgenv().NovaState.instanceId ~= MY_INSTANCE then
            return
        end
        SystemData = getgenv().SystemData or SystemData
        dirty = false

        -- 1) Pull latest admin writes from shared file (cross-game on same PC/executor)
        pcall(reloadSharedData)

        local now = os.time()
        SystemData.ScriptOnline = SystemData.ScriptOnline or {}
        SystemData.ScriptOnline[PlayerKey] = now

        -- cleanup stale heartbeats (>90s — allow other games some lag)
        for uid, t in pairs(SystemData.ScriptOnline) do
            if type(t) == "number" and now - t > 90 then
                SystemData.ScriptOnline[uid] = nil
                dirty = true
            end
        end

        -- 2) Pending gifts (Give Timer notice, Gift Spin/Luck/Key, etc.)
        pcall(function()
            if checkPendingGifts then checkPendingGifts() end
        end)

        -- 3) Pending resets (dedupe by token so re-execute never re-shows)
        pcall(function()
            local pr = SystemData.PendingResets and SystemData.PendingResets[PlayerKey]
            if pr and type(pr) == "table" then
                local token = tostring(pr.Time or 0) .. ":" .. tostring(pr.Reason or "")
                if not getgenv().NovaState.seenResets[token] then
                    getgenv().NovaState.seenResets[token] = true
                    SystemData.PendingResets[PlayerKey] = nil
                    SystemData.UserAccess[PlayerKey] = nil
                    SystemData.PlayerSpins[PlayerKey] = nil
                    saveData()
                    if showResetNotice then showResetNotice(pr.Reason or "Reset by admin") end
                else
                    -- already handled this reset — just clear leftover entry
                    SystemData.PendingResets[PlayerKey] = nil
                    dirty = true
                end
            end
        end)

        -- 4) Remote broadcasts (cross-device: Firebase polling for different PCs/phones)
        pcall(pollRemoteBroadcasts)

        -- 4b) Local shared notes (same PC/executor, file-based) — no popup, Notes page only
        pcall(function()
            local list = SystemData.Broadcasts or {}
            local advanced = false
            for _, b in ipairs(list) do
                if type(b) == "table" and type(b.Id) == "number" and b.Id > lastBroadcastId then
                    lastBroadcastId = b.Id
                    advanced = true
                end
            end
            if advanced then
                getgenv().NovaState.lastBroadcastId = lastBroadcastId
                if refreshNotesUI then pcall(refreshNotesUI) end
            end
            if #list > 50 then
                while #SystemData.Broadcasts > 50 do table.remove(SystemData.Broadcasts, 1) end
                dirty = true
            end
            if refreshGiftsUI then pcall(refreshGiftsUI) end
        end)

        -- 5) Live timer extend if admin updated our UserAccess from another game
        pcall(function()
            local raw = SystemData.UserAccess and SystemData.UserAccess[PlayerKey]
            if raw and unlockSystem then
                local exp = type(raw) == "table" and raw.Expire or raw
                local typ = type(raw) == "table" and (raw.Type or "Admin") or "Admin"
                if type(exp) == "number" and exp > now and exp > lastKnownExpire then
                    lastKnownExpire = exp
                    unlockSystem(exp - now, false, typ)
                elseif type(exp) == "number" and exp > now then
                    lastKnownExpire = math.max(lastKnownExpire, exp)
                end
            end
        end)

        -- 6) Refresh spin UI if spins/luck changed remotely
        pcall(function()
            if updateSpinUI then updateSpinUI() end
        end)

        -- 7) Auto-remove exhausted stock / consumed codes
        pcall(cleanupDeadCodes)

        -- Always write heartbeat so other clients can see us online
        saveData()
    end
end)

local function corner(o, r) local c = Instance.new("UICorner", o) c.CornerRadius = UDim.new(0, r or 10) return c end
local function stroke(o, col, th) local s = Instance.new("UIStroke", o) s.Color = col or T.accent s.Thickness = th or 1.2 return s end
local function tween(o, props, t, style)
    return TweenService:Create(o, TweenInfo.new(t or 0.25, style or Enum.EasingStyle.Quint, Enum.EasingDirection.Out), props)
end

local function makeDraggable(frame, handle)
    handle = handle or frame
    local drag, start, pos
    handle.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            drag = true; start = i.Position; pos = frame.Position
            i.Changed:Connect(function() if i.UserInputState == Enum.UserInputState.End then drag = false end end)
        end
    end)
    UserInputService.InputChanged:Connect(function(i)
        if drag and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
            local d = i.Position - start
            frame.Position = UDim2.new(pos.X.Scale, pos.X.Offset + d.X, pos.Y.Scale, pos.Y.Offset + d.Y)
        end
    end)
end

local function btn(parent, text, color, size, pos)
    local b = Instance.new("TextButton", parent)
    local btnColor = color or T.accent  -- FIX: capture once so hover never nil-crashes
    b.Size = size or UDim2.new(1, 0, 0, 40)
    b.Position = pos or UDim2.new(0, 0, 0, 0)
    b.BackgroundColor3 = btnColor
    b.Text = text
    b.TextColor3 = T.text
    b.Font = Enum.Font.GothamBold
    b.TextSize = 13
    b.AutoButtonColor = false
    corner(b, 10)
    b.MouseEnter:Connect(function() tween(b, {BackgroundColor3 = btnColor:Lerp(Color3.new(1,1,1), 0.12)}, 0.12):Play() end)
    b.MouseLeave:Connect(function() tween(b, {BackgroundColor3 = btnColor}, 0.12):Play() end)
    return b
end

local function input(parent, ph, size, pos)
    local t = Instance.new("TextBox", parent)
    t.Size = size or UDim2.new(1, 0, 0, 38)
    t.Position = pos or UDim2.new(0, 0, 0, 0)
    t.BackgroundColor3 = T.input
    t.PlaceholderText = ph or ""
    t.PlaceholderColor3 = T.muted
    t.Text = ""
    t.TextColor3 = T.text
    t.Font = Enum.Font.Gotham
    t.TextSize = 13
    t.ClearTextOnFocus = false
    corner(t, 10)
    return t
end

local function label(parent, text, size, pos, color, font, ts)
    local l = Instance.new("TextLabel", parent)
    l.Size = size or UDim2.new(1, 0, 0, 16)
    l.Position = pos or UDim2.new(0, 0, 0, 0)
    l.BackgroundTransparency = 1
    l.Text = text
    l.TextColor3 = color or T.muted
    l.Font = font or Enum.Font.GothamMedium
    l.TextSize = ts or 11
    l.TextXAlignment = Enum.TextXAlignment.Left
    return l
end

local unlockSystem, updateSpinUI, showBroadcast, checkPendingGifts, forceShowTimer, doSpin, showResetNotice
local OverlayGui, switchOv, refreshNotesUI, refreshGiftsUI
local KeyGui, KeyBg, processCode, KeyBox, SubmitBtn, getWaitRemaining, StatusMini
local AdminGui, refreshActive, refreshLogs
local enqueueBroadcast, pushPlayerGift
local KEY_CYCLE, WAIT_TIME = 15000, 90  -- 1 min 30 sec wait before key access
-- Key security state (shared with Submit handler outside Key UI scope)
local lastGetKeyAt, lastSubmitAt, keyFailStreak, keyLockUntil = 0, 0, 0, 0
local function secureHash(s)
    s = tostring(s or "")
    local h = 2166136261
    for i = 1, #s do
        h = (h + string.byte(s, i) * (i + 13)) % 4294967291
        h = (h * 16777619) % 4294967291
    end
    return string.format("%08X", h)
end

-- Returns the ONE currently-active daily key (rotates every KEY_CYCLE seconds)
-- This ensures only 1 key is valid at any moment — previous keys are expired
local function getCurrentDailyKey()
    local keys = SystemData.DailyKeys or {}
    if #keys == 0 then return nil end
    local idx = (math.floor(os.time() / KEY_CYCLE) % #keys) + 1
    return keys[idx]
end
local autoHideSpinOverlay = false -- set true by /spin so panel closes after result

-- ═══════════════════════════════════════
-- CLEAN OLD
-- ═══════════════════════════════════════
pcall(function()
    local p = getGuiParent()
    for _, n in ipairs({"NovaKeyUI","NovaAdminUI","NovaOverlay","NovaTimerHUD","NovaBroadcast","NovaQuickBtns","NovaAdminToggle","NovaResetNotice","NovaStockViewer"}) do
        if p:FindFirstChild(n) then p[n]:Destroy() end
        if CoreGui:FindFirstChild(n) then CoreGui[n]:Destroy() end
    end
end)

-- ═══════════════════════════════════════
-- KEY SYSTEM (main lock screen) — v6 compact 480×170
do
-- ═══════════════════════════════════════
KeyGui = Instance.new("ScreenGui")
KeyGui.Name = "NovaKeyUI"
KeyGui.ResetOnSpawn = false
KeyGui.DisplayOrder = 100
KeyGui.IgnoreGuiInset = true
protectAndParent(KeyGui)

KeyBg = Instance.new("Frame", KeyGui)
KeyBg.Size = UDim2.new(1, 0, 1, 0)
KeyBg.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
KeyBg.BackgroundTransparency = 0.22
KeyBg.BorderSizePixel = 0
KeyBg.Visible = true
KeyBg.ZIndex = 1

-- ── Compact Card 480 × 170 ──
local Card = Instance.new("Frame", KeyBg)
Card.Name = "KeyCard"
Card.Size = UDim2.new(0, 480, 0, 170)
Card.Position = UDim2.new(0.5, 0, 0.5, 0)
Card.AnchorPoint = Vector2.new(0.5, 0.5)
Card.BackgroundColor3 = T.card
Card.ClipsDescendants = true
Card.ZIndex = 2
Card.Visible = true
corner(Card, 14)
stroke(Card, Color3.fromRGB(0, 200, 160), 1.6)
-- soft pop-in (safe — no hang if tween fails)
do
    Card.Size = UDim2.new(0, 0, 0, 0)
    pcall(function()
        tween(Card, {Size = UDim2.new(0, 480, 0, 170)}, 0.35, Enum.EasingStyle.Quint):Play()
    end)
    task.delay(0.4, function()
        if Card and Card.Parent then
            Card.Size = UDim2.new(0, 480, 0, 170)
            Card.Visible = true
        end
    end)
end

-- accent gradient bar (top)
local accentBar = Instance.new("Frame", Card)
accentBar.Size = UDim2.new(1, 0, 0, 3)
accentBar.BackgroundColor3 = T.accent
accentBar.BorderSizePixel = 0
accentBar.ZIndex = 3
local ag = Instance.new("UIGradient", accentBar)
ag.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, T.accent2),
    ColorSequenceKeypoint.new(0.5, T.accent),
    ColorSequenceKeypoint.new(1, T.accent2),
})

-- ── LEFT: Avatar frame ──
local AvFrame = Instance.new("Frame", Card)
AvFrame.Size = UDim2.new(0, 64, 0, 64)
AvFrame.Position = UDim2.new(0, 14, 0.5, -32)
AvFrame.BackgroundColor3 = T.card2
AvFrame.ZIndex = 3
corner(AvFrame, 32)
stroke(AvFrame, T.accent, 2)

local AvImg = Instance.new("ImageLabel", AvFrame)
AvImg.Size = UDim2.new(1, -4, 1, -4)
AvImg.Position = UDim2.new(0, 2, 0, 2)
AvImg.BackgroundTransparency = 1
AvImg.ZIndex = 4
corner(AvImg, 30)
pcall(function()
    AvImg.Image = Players:GetUserThumbnailAsync(LocalPlayer.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
end)

local NameLbl = label(Card, LocalPlayer.Name, UDim2.new(0, 90, 0, 14), UDim2.new(0, 8, 0, 148), T.muted, Enum.Font.GothamMedium, 9)
NameLbl.TextXAlignment = Enum.TextXAlignment.Center
NameLbl.TextTruncate = Enum.TextTruncate.AtEnd
NameLbl.ZIndex = 3

-- ── TITLE + STATUS ──
local TitleLbl = label(Card, "SEEDS KEY SYSTEM", UDim2.new(0, 220, 0, 20), UDim2.new(0, 92, 0, 12), T.text, Enum.Font.GothamBlack, 15)
TitleLbl.ZIndex = 3

local TimerLbl = label(Card, "PLS WAIT...", UDim2.new(0, 220, 0, 16), UDim2.new(0, 92, 0, 34), T.warn, Enum.Font.GothamBold, 11)
TimerLbl.ZIndex = 3

-- ── LIVE FPS + PING ──
local StatsFrame = Instance.new("Frame", Card)
StatsFrame.Size = UDim2.new(0, 130, 0, 18)
StatsFrame.Position = UDim2.new(0, 92, 0, 52)
StatsFrame.BackgroundTransparency = 1
StatsFrame.ZIndex = 3

local FpsLbl = label(StatsFrame, "FPS: --", UDim2.new(0.5, -2, 1, 0), UDim2.new(0, 0, 0, 0), T.ok, Enum.Font.GothamBold, 10)
FpsLbl.ZIndex = 4
local PingLbl = label(StatsFrame, "MS: --", UDim2.new(0.5, -2, 1, 0), UDim2.new(0.5, 2, 0, 0), T.accent2, Enum.Font.GothamBold, 10)
PingLbl.ZIndex = 4

-- Live FPS + Ping updater (fully pcall-safe)
task.spawn(function()
    local frames, last = 0, os.clock()
    local fpsConn
    pcall(function()
        fpsConn = RunService.RenderStepped:Connect(function()
            frames = frames + 1
            local now = os.clock()
            if now - last >= 0.5 then
                local fps = math.floor(frames / (now - last) + 0.5)
                frames = 0
                last = now
                pcall(function()
                    if FpsLbl and FpsLbl.Parent then
                        FpsLbl.Text = "FPS: " .. tostring(fps)
                        if fps >= 50 then FpsLbl.TextColor3 = T.ok
                        elseif fps >= 30 then FpsLbl.TextColor3 = T.orange
                        else FpsLbl.TextColor3 = T.warn end
                    end
                end)
            end
        end)
    end)
    while KeyGui and KeyGui.Parent do
        local ping = 0
        pcall(function()
            local stats = game:GetService("Stats")
            if stats then
                local okItem, item = pcall(function()
                    return stats.Network.ServerStatsItem["Data Ping"]
                end)
                if okItem and item then
                    local okVal, val = pcall(function() return item:GetValue() end)
                    if okVal and type(val) == "number" then
                        ping = math.floor(val + 0.5)
                    end
                end
            end
        end)
        if ping <= 0 then ping = 1 end
        pcall(function()
            if PingLbl and PingLbl.Parent then
                PingLbl.Text = "MS: " .. tostring(ping)
                if ping <= 80 then PingLbl.TextColor3 = T.ok
                elseif ping <= 150 then PingLbl.TextColor3 = T.orange
                else PingLbl.TextColor3 = T.warn end
            end
        end)
        task.wait(0.6)
    end
    pcall(function() if fpsConn then fpsConn:Disconnect() end end)
end)

-- ── KEY INPUT ──
KeyBox = input(Card, "ENTER KEY...", UDim2.new(0, 220, 0, 34), UDim2.new(0, 92, 0, 78))
KeyBox.ZIndex = 3
KeyBox.TextSize = 13
KeyBox.Font = Enum.Font.GothamMedium
stroke(KeyBox, Color3.fromRGB(50, 60, 75), 1)

-- ── BUTTONS (GET KEY + SUBMIT) ──
local GetKeyBtn = btn(Card, "GET KEY", T.ok, UDim2.new(0, 100, 0, 34), UDim2.new(0, 92, 0, 122))
GetKeyBtn.ZIndex = 3
GetKeyBtn.TextSize = 12
SubmitBtn = btn(Card, "SUBMIT", T.accent2, UDim2.new(0, 110, 0, 34), UDim2.new(0, 202, 0, 122))
SubmitBtn.ZIndex = 3
SubmitBtn.TextSize = 12

-- small status under buttons
StatusMini = label(Card, "Thank you for using SEEDS", UDim2.new(0, 220, 0, 14), UDim2.new(0, 320, 0, 148), T.muted, Enum.Font.Gotham, 9)
StatusMini.TextXAlignment = Enum.TextXAlignment.Right
StatusMini.ZIndex = 3

-- ── RIGHT SIDE info panel ──
local InfoPanel = Instance.new("Frame", Card)
InfoPanel.Size = UDim2.new(0, 140, 0, 100)
InfoPanel.Position = UDim2.new(1, -152, 0, 28)
InfoPanel.BackgroundColor3 = T.card2
InfoPanel.ZIndex = 3
corner(InfoPanel, 10)
stroke(InfoPanel, Color3.fromRGB(40, 50, 60), 1)

label(InfoPanel, "STATUS", UDim2.new(1, -12, 0, 14), UDim2.new(0, 8, 0, 6), T.muted, Enum.Font.GothamBold, 9).ZIndex = 4
local SecLbl = label(InfoPanel, "Secure Mode ON", UDim2.new(1, -12, 0, 14), UDim2.new(0, 8, 0, 24), T.ok, Enum.Font.GothamMedium, 11)
SecLbl.ZIndex = 4
local HintLbl = label(InfoPanel, "1 active key only.\nAnti-spam protected.", UDim2.new(1, -12, 0, 40), UDim2.new(0, 8, 0, 46), T.muted, Enum.Font.Gotham, 10)
HintLbl.TextWrapped = true
HintLbl.TextYAlignment = Enum.TextYAlignment.Top
HintLbl.ZIndex = 4

-- ── X button (minimize) ──
local CloseKey = btn(Card, "X", T.warn, UDim2.new(0, 28, 0, 28), UDim2.new(1, -36, 0, 8))
CloseKey.ZIndex = 5
CloseKey.TextSize = 13
CloseKey.Font = Enum.Font.GothamBlack

-- ── Restore button (top square) — hidden until minimized ──
local RestoreBtn = Instance.new("TextButton", KeyGui)
RestoreBtn.Name = "KeyRestore"
RestoreBtn.Size = UDim2.new(0, 36, 0, 36)
RestoreBtn.Position = UDim2.new(0.5, -18, 0, 10)
RestoreBtn.BackgroundColor3 = T.card
RestoreBtn.Text = "K"
RestoreBtn.TextSize = 16
RestoreBtn.Font = Enum.Font.GothamBlack
RestoreBtn.TextColor3 = T.accent
RestoreBtn.Visible = false
RestoreBtn.ZIndex = 50
RestoreBtn.AutoButtonColor = false
corner(RestoreBtn, 10)
stroke(RestoreBtn, T.accent, 1.8)
pcall(function() makeDraggable(RestoreBtn) end)

local function minimizeKeyUI()
    if not Card or not Card.Parent then return end
    pcall(function()
        tween(Card, {Size = UDim2.new(0, 0, 0, 0)}, 0.22, Enum.EasingStyle.Quint):Play()
    end)
    task.delay(0.22, function()
        if KeyBg then KeyBg.Visible = false end
        if RestoreBtn then
            RestoreBtn.Visible = true
            RestoreBtn.Size = UDim2.new(0, 36, 0, 36)
        end
    end)
end

local function restoreKeyUI()
    if not KeyBg then return end
    if RestoreBtn then RestoreBtn.Visible = false end
    KeyBg.Visible = true
    if Card then
        Card.Visible = true
        Card.Size = UDim2.new(0, 480, 0, 170)
        pcall(function()
            Card.Size = UDim2.new(0, 0, 0, 0)
            tween(Card, {Size = UDim2.new(0, 480, 0, 170)}, 0.3, Enum.EasingStyle.Quint):Play()
        end)
        task.delay(0.35, function()
            if Card and Card.Parent then
                Card.Size = UDim2.new(0, 480, 0, 170)
            end
        end)
    end
end

CloseKey.MouseButton1Click:Connect(function()
    pcall(minimizeKeyUI)
end)
RestoreBtn.MouseButton1Click:Connect(function()
    pcall(restoreKeyUI)
end)

RestoreBtn.MouseEnter:Connect(function()
    pcall(function() tween(RestoreBtn, {BackgroundColor3 = T.card2}, 0.12):Play() end)
end)
RestoreBtn.MouseLeave:Connect(function()
    pcall(function() tween(RestoreBtn, {BackgroundColor3 = T.card}, 0.12):Play() end)
end)

-- ── Wait / timer logic (same content) ──
getWaitRemaining = function()
    if isSkipTimerUser(PlayerKey) then return 0 end
    return math.max(0, WAIT_TIME - (os.time() - executionWaitStart))
end

task.spawn(function()
    while KeyGui.Parent do
        pcall(function()
            pcall(reloadSharedData)
        end)
        if isSkipTimerUser(PlayerKey) then
            TimerLbl.Text = "BYPASS ACTIVE · SEEDS"
            TimerLbl.TextColor3 = T.ok
        else
            local rem = getWaitRemaining()
            if rem > 0 then
                TimerLbl.Text = string.format("Wait Access: %02d:%02d", math.floor(rem/60), rem%60)
                TimerLbl.TextColor3 = T.warn
            else
                local r = KEY_CYCLE - (os.time() % KEY_CYCLE)
                TimerLbl.Text = string.format("Next Reset: %02dH %02dM %02dS", math.floor(r/3600), math.floor((r%3600)/60), r%60)
                TimerLbl.TextColor3 = T.ok
            end
        end
        task.wait(1)
    end
end)

-- ── SMARTER SECURITY for key redeem (vars declared above) ──
GetKeyBtn.MouseButton1Click:Connect(function()
    local okBtn, errBtn = pcall(function()
        local now = os.clock()
        if now - (lastGetKeyAt or 0) < 1.2 then
            GetKeyBtn.Text = "SLOW DOWN"
            task.wait(0.8)
            GetKeyBtn.Text = "GET KEY"
            return
        end
        lastGetKeyAt = now

        local rem = getWaitRemaining and getWaitRemaining() or 0
        if rem > 0 then
            GetKeyBtn.Text = string.format("WAIT %02d:%02d", math.floor(rem/60), rem%60)
            task.wait(1.2)
            GetKeyBtn.Text = "GET KEY"
            return
        end
        local currentKey = getCurrentDailyKey and getCurrentDailyKey() or nil
        if not currentKey then
            GetKeyBtn.Text = "NO KEYS!"
            task.wait(1.2)
            GetKeyBtn.Text = "GET KEY"
            return
        end
        copyClip(currentKey)
        GetKeyBtn.Text = "COPIED!"
        if StatusMini then
            StatusMini.Text = "Key copied to clipboard"
            StatusMini.TextColor3 = T.ok
        end
        task.wait(1.5)
        GetKeyBtn.Text = "GET KEY"
        if StatusMini then
            StatusMini.Text = "Thank you for using SEEDS"
            StatusMini.TextColor3 = T.muted
        end
    end)
    if not okBtn then
        warn("[NOVA] GetKey error: " .. tostring(errBtn))
        pcall(function() GetKeyBtn.Text = "GET KEY" end)
    end
end)

-- ═══════════════════════════════════════
-- UNLOCK + TIMER HUD
-- ═══════════════════════════════════════
local currentTimerTask
local MAIN_SCRIPT_URL = "https://raw.githubusercontent.com/SeedsDevs1/SEEDS/refs/heads/main/TheMainScript.lua"

local function fetchMainSource()
    -- Try multiple HTTP methods (PC + mobile executors)
    local methods = {}
    table.insert(methods, function()
        return game:HttpGet(MAIN_SCRIPT_URL, true)
    end)
    table.insert(methods, function()
        local opts = { Url = MAIN_SCRIPT_URL, Method = "GET" }
        local res
        if syn and syn.request then res = syn.request(opts)
        elseif http_request then res = http_request(opts)
        elseif request then res = request(opts)
        elseif http and http.request then res = http.request({url = MAIN_SCRIPT_URL, method = "GET"})
        end
        if type(res) == "table" then
            return res.Body or res.body
        end
        return nil
    end)
    for _, fn in ipairs(methods) do
        local ok, body = pcall(fn)
        if ok and type(body) == "string" and #body > 50 then
            return body
        end
    end
    return nil
end

local function loadMainScript()
    if getgenv().NovaMainLoaded then return true end
    if getgenv().NovaMainLoading then return false end
    getgenv().NovaMainLoading = true

    task.spawn(function()
        local lastErr = "unknown"
        for attempt = 1, 3 do
            local src = fetchMainSource()
            if not src then
                lastErr = "HttpGet failed (attempt " .. attempt .. ")"
                warn("[NOVA] " .. lastErr)
                task.wait(1.2)
            else
                local fn, compileErr = loadstring(src)
                if not fn then
                    lastErr = "loadstring compile error: " .. tostring(compileErr)
                    warn("[NOVA] " .. lastErr)
                    task.wait(1)
                else
                    local ok, runErr = pcall(fn)
                    if ok then
                        getgenv().NovaMainLoaded = true
                        getgenv().NovaMainLoading = false
                        print("SUCCESSFUL LOADED")
                        return
                    else
                        lastErr = "runtime error: " .. tostring(runErr)
                        warn("[NOVA] Main script runtime error: " .. tostring(runErr))
                        task.wait(1)
                    end
                end
            end
        end
        getgenv().NovaMainLoading = false
        warn("[NOVA] Main script FAILED after 3 tries: " .. tostring(lastErr))
        pcall(function()
            if showBroadcast then
                showBroadcast("Main script failed to load. Re-execute key system.", "SEEDS", 6)
            end
        end)
    end)
    return false
end

unlockSystem = function(duration, isNew, accessType, isExtend)
    -- Fully hide key system + restore button when access granted
    if KeyBg then KeyBg.Visible = false end
    pcall(function()
        local r = KeyGui and KeyGui:FindFirstChild("KeyRestore")
        if r then r.Visible = false end
    end)

    -- Load main script when player gets / restores access
    loadMainScript()

    local dur = duration or 7200
    if isNew then
        if isExtend and SystemData.UserAccess[PlayerKey] then
            local raw = SystemData.UserAccess[PlayerKey]
            local cur = type(raw) == "table" and raw.Expire or raw
            if type(cur) ~= "number" or cur < os.time() then cur = os.time() end
            SystemData.UserAccess[PlayerKey] = {Expire = cur + dur, Type = accessType or "Key"}
        else
            SystemData.UserAccess[PlayerKey] = {Expire = os.time() + dur, Type = accessType or "Daily"}
        end
        saveData()
    end
    local raw = SystemData.UserAccess[PlayerKey]
    local expire = type(raw) == "table" and raw.Expire or (os.time() + dur)
    if type(expire) == "number" then lastKnownExpire = math.max(lastKnownExpire or 0, expire) end

    pcall(function()
        local parent = getGuiParent()
        if parent:FindFirstChild("NovaTimerHUD") then parent.NovaTimerHUD:Destroy() end
    end)
    if currentTimerTask then pcall(function() task.cancel(currentTimerTask) end) end

    local tg = Instance.new("ScreenGui")
    tg.Name = "NovaTimerHUD"; tg.ResetOnSpawn = false; tg.DisplayOrder = 200
    protectAndParent(tg)
    local tf = Instance.new("Frame", tg)
    tf.Size = UDim2.new(0, 210, 0, 36)
    tf.Position = UDim2.new(0.5, -105, 0, 12)
    tf.BackgroundColor3 = T.card
    corner(tf, 10); stroke(tf, T.accent, 1.5)
    local tt = Instance.new("TextLabel", tf)
    tt.Size = UDim2.new(1,0,1,0); tt.BackgroundTransparency = 1
    tt.Text = "Active | 00:00:00"; tt.TextColor3 = T.text
    tt.Font = Enum.Font.GothamBold; tt.TextSize = 12

    -- /t command: force-show timer HUD for full 5 seconds (loop must respect this)
    local forceShowUntil = 0
    forceShowTimer = function()
        if not (tg and tg.Parent and tf) then return false end
        forceShowUntil = os.time() + 5
        tf.Visible = true
        return true
    end

    currentTimerTask = task.spawn(function()
        local nextPop, hideAt = os.time() + 600, os.time() + 5
        while true do
            local rem = expire - os.time()
            if rem <= 0 then
                SystemData.UserAccess[PlayerKey] = nil; saveData()
                tg:Destroy()
                if KeyBg then
                    KeyBg.Visible = true
                    pcall(function()
                        local card = KeyBg:FindFirstChild("KeyCard")
                        if card then card.Size = UDim2.new(0, 480, 0, 170) end
                        local r = KeyGui and KeyGui:FindFirstChild("KeyRestore")
                        if r then r.Visible = false end
                    end)
                end
                break
            end
            -- live update expire if extended while running
            local raw2 = SystemData.UserAccess[PlayerKey]
            if type(raw2) == "table" and raw2.Expire then expire = raw2.Expire end
            tt.Text = string.format("Active | %02dH %02dM %02dS", math.floor(rem/3600), math.floor((rem%3600)/60), rem%60)
            local now = os.time()
            -- /t force-show takes priority for full 5 seconds
            if now < forceShowUntil then
                tf.Visible = true
            elseif now < hideAt then
                tf.Visible = true
            elseif now >= nextPop then
                tf.Visible = true; hideAt = now + 5; nextPop = now + 600
            else
                tf.Visible = false
            end
            task.wait(1)
        end
    end)
end

-- Fallback if timer not yet created (no access yet)
if not forceShowTimer then
    forceShowTimer = function()
        return false
    end
end

-- ═══════════════════════════════════════
-- CODE REDEEM (shared)
-- ═══════════════════════════════════════
end -- end Key UI scope
local function setStatus(statusLbl, text, ok)
    if not statusLbl then return end
    if statusLbl:IsA("TextBox") then
        statusLbl.Text = ""
        statusLbl.PlaceholderText = text
    else
        statusLbl.TextColor3 = ok and T.ok or T.warn
        statusLbl.Text = text
    end
end

processCode = function(code, statusLbl, mode)
    -- mode: "any" | "spinluck" | "keyprem"
    if not allowRedeemAttempt() then
        setStatus(statusLbl, "Too many attempts! Wait 30s", false)
        return
    end

    pcall(cleanupDeadCodes)
    pcall(reloadSharedData)
    -- Pull latest codes from remote so other-game codes are visible
    pcall(pollRemoteCodes)

    local raw = type(code) == "string" and code or ""
    local entered = normalizeCode(raw)
    if #entered < 2 then
        setStatus(statusLbl, "INVALID CODE!", false)
        return
    end

    -- Find matching active code (case-insensitive)
    local matched = nil
    for c, data in pairs(SystemData.ActiveCodes or {}) do
        if type(data) == "table" and normalizeCode(c) == entered then
            matched = c
            break
        end
    end

    if not matched then
        setStatus(statusLbl, "INVALID / EXPIRED CODE!", false)
        return
    end

    local data = SystemData.ActiveCodes[matched]
    if type(data) ~= "table" then
        setStatus(statusLbl, "INVALID CODE!", false)
        return
    end
    local typ = data.Type

    -- Game-win / bound codes: only the winner can redeem
    if data.BoundTo and tostring(data.BoundTo) ~= PlayerKey then
        setStatus(statusLbl, "This code is not for you!", false)
        return
    end

    if mode == "spinluck" then
        if typ ~= "SpinAmount" and typ ~= "Luck" then
            setStatus(statusLbl, "Not a Spin/Luck code!", false)
            return
        end
    elseif mode == "keyprem" then
        if typ ~= "Key" and typ ~= "Premium" and typ ~= "Admin" and typ ~= "Spin" then
            setStatus(statusLbl, "Not a Key/Premium code!", false)
            return
        end
    end

    -- ── STOCK codes (MaxUses): 1x per player, limited total ──
    if data.MaxUses and tonumber(data.MaxUses) and tonumber(data.MaxUses) > 0 then
        local maxU = tonumber(data.MaxUses)
        data.UsedBy = data.UsedBy or {}
        -- already used by this player?
        if data.UsedBy[PlayerKey] == true or data.UsedBy[PlayerKey] == PlayerKey then
            setStatus(statusLbl, "Already redeemed!", false)
            return
        end
        local used = countUsedBy(data.UsedBy)
        if used >= maxU then
            -- exhaust + delete so it cannot be reused
            SystemData.ActiveCodes[matched] = nil
            SystemData.UsedCodes[matched] = nil
            SystemData.BoundKeys[matched] = nil
            saveData()
            setStatus(statusLbl, "STOCK EXHAUSTED!", false)
            return
        end
        -- lock this player first, then save BEFORE granting reward
        data.UsedBy[PlayerKey] = true
        used = used + 1
        if used >= maxU then
            -- last stock unit — mark for removal after grant
            data._exhaustAfter = true
        end
        saveData()
    else
        -- ── Single-use / bound codes ──
        -- If already consumed or bound to someone else → block
        if data.Consumed then
            SystemData.ActiveCodes[matched] = nil
            saveData()
            setStatus(statusLbl, "Already redeemed!", false)
            return
        end
        local bound = SystemData.UsedCodes[matched]
        if bound then
            if tostring(bound) ~= PlayerKey then
                setStatus(statusLbl, "Already redeemed by another!", false)
                return
            end
            setStatus(statusLbl, "Already redeemed!", false)
            return
        end
        SystemData.UsedCodes[matched] = PlayerKey
        data.Consumed = true
        saveData()
    end

    -- Grant reward
    if typ == "Key" or typ == "Premium" or typ == "Admin" or typ == "Spin" then
        if not data.MaxUses then SystemData.BoundKeys[matched] = PlayerKey end
        local dur = data.Duration or data.Value or 7200
        local hasAccess = SystemData.UserAccess[PlayerKey]
        local stillValid = false
        if hasAccess then
            local exp = type(hasAccess) == "table" and hasAccess.Expire or hasAccess
            stillValid = type(exp) == "number" and exp > os.time()
        end
        if stillValid then
            unlockSystem(dur, true, typ, true)
            setStatus(statusLbl, "Timer extended!", true)
        else
            unlockSystem(dur, true, typ, false)
            setStatus(statusLbl, "Key activated!", true)
        end
    elseif typ == "SpinAmount" then
        local p = SystemData.PlayerSpins[PlayerKey] or {Spins=0,Luck=0,LastSpin=0}
        SystemData.PlayerSpins[PlayerKey] = p
        p.Spins = (p.Spins or 0) + (tonumber(data.Value) or 1)
        updateSpinUI()
        setStatus(statusLbl, "+" .. tostring(data.Value) .. " Spins!", true)
    elseif typ == "Luck" then
        local p = SystemData.PlayerSpins[PlayerKey] or {Spins=0,Luck=0,LastSpin=0}
        SystemData.PlayerSpins[PlayerKey] = p
        p.Luck = (p.Luck or 0) + (tonumber(data.Value) or 1)
        updateSpinUI()
        setStatus(statusLbl, "+" .. tostring(data.Value) .. "% Luck!", true)
    else
        setStatus(statusLbl, "Unknown code type!", false)
    end

    -- Auto-delete exhausted stock / consumed single-use so list stays clean
    if data._exhaustAfter or data.Consumed then
        SystemData.ActiveCodes[matched] = nil
        if data.Consumed then
            -- keep UsedCodes so anti-share still works if somehow recreated without cleanup
            -- but admin create will clear UsedCodes when making a fresh code of same name
        end
    end
    -- Always purge dead codes after redeem
    pcall(cleanupDeadCodes)
    saveData()
    pcall(pushRemoteCodes) -- sync redeem state to other games/executors
    addLog(LocalPlayer.Name .. " redeemed: " .. matched)
end

if SubmitBtn then
SubmitBtn.MouseButton1Click:Connect(function()
    local okSub, errSub = pcall(function()
    if not KeyBox then return end
    local now = os.clock()
    local function setMini(txt, col)
        if StatusMini then
            StatusMini.Text = txt or ""
            if col then StatusMini.TextColor3 = col end
        end
    end
    -- Anti-spam / lockout
    if now < (keyLockUntil or 0) then
        local left = math.ceil(keyLockUntil - now)
        KeyBox.Text = ""
        KeyBox.PlaceholderText = "LOCKED " .. left .. "s"
        setMini("Too many fails — wait", T.warn)
        task.wait(1.0)
        KeyBox.PlaceholderText = "ENTER KEY..."
        return
    end
    if now - (lastSubmitAt or 0) < 0.85 then
        setMini("Slow down...", T.orange)
        return
    end
    lastSubmitAt = now

    local rawEntered = tostring(KeyBox.Text or "")
    local entered = normalizeCode(rawEntered)
    if #entered < 3 then
        KeyBox.Text = ""
        KeyBox.PlaceholderText = "TOO SHORT!"
        keyFailStreak = (keyFailStreak or 0) + 1
        task.wait(1.0)
        KeyBox.PlaceholderText = "ENTER KEY..."
        return
    end

    pcall(reloadSharedData)
    pcall(pollRemoteCodes)

    -- Prefer active codes first (stock/admin/premium)
    local matched
    for c in pairs(SystemData.ActiveCodes or {}) do
        if normalizeCode(c) == entered then matched = c; break end
    end
    if matched then
        processCode(matched, KeyBox, "any")
        keyFailStreak = 0
        return
    end

    local rem = getWaitRemaining()
    if rem > 0 then
        KeyBox.Text = ""
        KeyBox.PlaceholderText = string.format("WAIT %02d:%02d", math.floor(rem/60), rem%60)
        setMini("Wait timer still active", T.warn)
        task.wait(1.2)
        KeyBox.PlaceholderText = "ENTER KEY..."
        return
    end

    -- Only accept the ONE currently-active daily key (hash check for anti-tamper)
    local currentKey = getCurrentDailyKey()
    local okDaily = false
    if currentKey then
        local nCur = normalizeCode(currentKey)
        if nCur == entered then
            okDaily = true
        elseif secureHash and secureHash(nCur) == secureHash(entered) then
            okDaily = true
        end
    end

    if okDaily then
        keyFailStreak = 0
        KeyBox.Text = ""
        KeyBox.PlaceholderText = "SUCCESS!"
        setMini("Key accepted · unlocking", T.ok)
        unlockSystem(KEY_CYCLE - (os.time() % KEY_CYCLE), true, "Daily")
    else
        keyFailStreak = (keyFailStreak or 0) + 1
        KeyBox.Text = ""
        KeyBox.PlaceholderText = "INVALID KEY!"
        setMini("Wrong key · try again", T.warn)
        if keyFailStreak >= 6 then
            keyLockUntil = os.clock() + 25
            keyFailStreak = 0
            setMini("Locked 25s (anti-brute)", T.warn)
        end
        task.wait(1.2)
        KeyBox.PlaceholderText = "ENTER KEY..."
        setMini("Thank you for using SEEDS", T.muted)
    end
    end) -- end pcall
    if not okSub then
        warn("[NOVA] Submit error: " .. tostring(errSub))
    end
end)
end -- if SubmitBtn

-- restore access
if SystemData.UserAccess[PlayerKey] then
    local raw = SystemData.UserAccess[PlayerKey]
    local exp = type(raw) == "table" and raw.Expire or raw
    local at = type(raw) == "table" and (raw.Type or "Daily") or "Daily"
    if type(exp) == "number" and os.time() < exp then
        -- restore ANY valid access type (Admin / Key / Premium / Spin / Daily)
        unlockSystem(exp - os.time(), false, at)
    else
        SystemData.UserAccess[PlayerKey] = nil
        saveData()
        if KeyBg then KeyBg.Visible = true end
        pcall(function()
            local card = KeyBg and KeyBg:FindFirstChild("KeyCard")
            if card then card.Size = UDim2.new(0, 480, 0, 170); card.Visible = true end
        end)
    end
else
    if KeyBg then KeyBg.Visible = true end
    pcall(function()
        local card = KeyBg and KeyBg:FindFirstChild("KeyCard")
        if card then card.Size = UDim2.new(0, 480, 0, 170); card.Visible = true end
    end)
end

-- ═══════════════════════════════════════
do
-- /open OVERLAY — multi page
-- ═══════════════════════════════════════
OverlayGui = Instance.new("ScreenGui")
OverlayGui.Name = "NovaOverlay"
OverlayGui.Enabled = false
OverlayGui.ResetOnSpawn = false
OverlayGui.DisplayOrder = 110
protectAndParent(OverlayGui)

local Ov = Instance.new("Frame", OverlayGui)
Ov.Size = UDim2.new(0, 400, 0, 460)
Ov.Position = UDim2.new(0.5, -200, 0.5, -230)
Ov.BackgroundColor3 = T.card
corner(Ov, 14); stroke(Ov, T.accent2, 1.5)

local OvHead = Instance.new("Frame", Ov)
OvHead.Size = UDim2.new(1,0,0,40); OvHead.BackgroundColor3 = T.card2
corner(OvHead, 14)
local ohf = Instance.new("Frame", OvHead); ohf.Size = UDim2.new(1,0,0,12); ohf.Position = UDim2.new(0,0,1,-12); ohf.BackgroundColor3 = T.card2; ohf.BorderSizePixel = 0
label(OvHead, "YOUR PANEL", UDim2.new(0.7,0,1,0), UDim2.new(0.04,0,0,0), T.text, Enum.Font.GothamBold, 13)
local OvX = btn(OvHead, "X", T.warn, UDim2.new(0,28,0,28), UDim2.new(1,-36,0.5,-14))
OvX.TextSize = 12
OvX.MouseButton1Click:Connect(function() OverlayGui.Enabled = false end)
makeDraggable(Ov, OvHead)

local OvNav = Instance.new("ScrollingFrame", Ov)
OvNav.Size = UDim2.new(0.94,0,0,30); OvNav.Position = UDim2.new(0.03,0,0,48)
OvNav.BackgroundTransparency = 1; OvNav.ScrollBarThickness = 2
OvNav.CanvasSize = UDim2.new(0, 520, 0, 0); OvNav.ScrollingDirection = Enum.ScrollingDirection.X
local ovNavLay = Instance.new("UIListLayout", OvNav)
ovNavLay.FillDirection = Enum.FillDirection.Horizontal; ovNavLay.Padding = UDim.new(0,4)

local OvPages = Instance.new("Frame", Ov)
OvPages.Size = UDim2.new(0.94,0,0,360); OvPages.Position = UDim2.new(0.03,0,0,86); OvPages.BackgroundTransparency = 1

local ovPages, ovTabs = {}, {}
local function ovPage(name)
    local p = Instance.new("Frame", OvPages)
    p.Size = UDim2.new(1,0,1,0); p.BackgroundTransparency = 1; p.Visible = false
    ovPages[name] = p; return p
end
switchOv = function(n)
    for k, p in pairs(ovPages) do p.Visible = (k == n) end
    for k, b in pairs(ovTabs) do
        b.BackgroundColor3 = (k == n) and T.accent2 or T.card2
        b.TextColor3 = (k == n) and T.text or T.muted
    end
    if n == "notes" and refreshNotesUI then pcall(refreshNotesUI) end
    if n == "gifts" and refreshGiftsUI then pcall(refreshGiftsUI) end
end
local function ovTab(title, page)
    local b = Instance.new("TextButton", OvNav)
    b.Size = UDim2.new(0, 72, 1, 0)
    b.BackgroundColor3 = T.card2; b.Text = title; b.TextColor3 = T.muted
    b.Font = Enum.Font.GothamMedium; b.TextSize = 10; b.AutoButtonColor = false; corner(b, 7)
    ovTabs[page] = b
    b.MouseButton1Click:Connect(function() switchOv(page) end)
end

local OP_Codes = ovPage("codes")
local OP_Key = ovPage("key")
local OP_Spin = ovPage("spin")
local OP_Notes = ovPage("notes")
local OP_Gifts = ovPage("gifts")
local OP_Feed = ovPage("feed")
OP_Codes.Visible = true
ovTab("Codes", "codes"); ovTab("Key", "key"); ovTab("Spin", "spin")
ovTab("Notes", "notes"); ovTab("Gifts", "gifts"); ovTab("Feed", "feed")
ovTabs["codes"].BackgroundColor3 = T.accent2; ovTabs["codes"].TextColor3 = T.text

-- Blue notification dot on Gifts tab (visible only when there are unclaimed gifts)
local giftsBadge = Instance.new("Frame")
giftsBadge.Name = "GiftsBadge"
giftsBadge.Size = UDim2.new(0, 8, 0, 8)
giftsBadge.Position = UDim2.new(1, -8, 0, 2)
giftsBadge.AnchorPoint = Vector2.new(0.5, 0.5)
giftsBadge.BackgroundColor3 = Color3.fromRGB(0, 160, 255) -- blue
giftsBadge.BorderSizePixel = 0
giftsBadge.Visible = false
giftsBadge.ZIndex = 5
corner(giftsBadge, 4)
if ovTabs["gifts"] then
    giftsBadge.Parent = ovTabs["gifts"]
end

local function countUnclaimedGifts()
    SystemData = getgenv().SystemData or SystemData
    local list = (SystemData.PlayerGifts or {})[PlayerKey] or {}
    local claimedMap = (getgenv().NovaState and getgenv().NovaState.claimedGiftIds) or {}
    local n = 0
    for _, g in ipairs(list) do
        if type(g) == "table" and not g.Claimed then
            local gid = tostring(g.Id or "")
            if gid == "" or not claimedMap[gid] then
                n = n + 1
            end
        end
    end
    return n
end

local function updateGiftsBadge()
    if not giftsBadge or not giftsBadge.Parent then return end
    local n = 0
    pcall(function() n = countUnclaimedGifts() end)
    giftsBadge.Visible = (n > 0)
end
getgenv().NovaUpdateGiftsBadge = updateGiftsBadge

-- Codes page (Spin / Luck only)
label(OP_Codes, "REDEEM SPIN / LUCK CODES", nil, UDim2.new(0,0,0,4))
local OC_Box = input(OP_Codes, "ENTER CODES...", nil, UDim2.new(0,0,0,28))
local OC_Btn = btn(OP_Codes, "REDEEM", T.purple, nil, UDim2.new(0,0,0,78))
local OC_Stat = label(OP_Codes, "", UDim2.new(1,0,0,30), UDim2.new(0,0,0,128), T.warn, Enum.Font.Gotham, 12)
OC_Stat.TextXAlignment = Enum.TextXAlignment.Center
OC_Btn.MouseButton1Click:Connect(function() processCode(OC_Box.Text, OC_Stat, "spinluck") end)

-- Code Key page (Key / Premium — extend timer)
label(OP_Key, "REDEEM KEY CODES", nil, UDim2.new(0,0,0,4))
local OK_Box = input(OP_Key, "ENTER CODES...", nil, UDim2.new(0,0,0,28))
local OK_Btn = btn(OP_Key, "REDEEM", T.accent2, nil, UDim2.new(0,0,0,78))
local OK_Stat = label(OP_Key, "", UDim2.new(1,0,0,40), UDim2.new(0,0,0,128), T.warn, Enum.Font.Gotham, 12)
OK_Stat.TextXAlignment = Enum.TextXAlignment.Center
OK_Stat.TextWrapped = true
OK_Btn.MouseButton1Click:Connect(function() processCode(OK_Box.Text, OK_Stat, "keyprem") end)

-- Spin the Wheel page
local SpinInfo = label(OP_Spin, "Spins: 1  |  Luck: +0%  |  Chance: 0.5%", UDim2.new(1,0,0,20), UDim2.new(0,0,0,0), T.text, Enum.Font.GothamBold, 12)
SpinInfo.TextXAlignment = Enum.TextXAlignment.Center

-- Wheel visual
local WheelFrame = Instance.new("Frame", OP_Spin)
WheelFrame.Size = UDim2.new(0, 150, 0, 150)
WheelFrame.Position = UDim2.new(0.5, -75, 0, 28)
WheelFrame.BackgroundColor3 = T.card2
corner(WheelFrame, 75)
stroke(WheelFrame, T.orange, 3)

-- Green jackpot line (win marker on wheel)
local JackpotLine = Instance.new("Frame", WheelFrame)
JackpotLine.Size = UDim2.new(0, 4, 0, 48)
JackpotLine.Position = UDim2.new(0.5, -2, 0, 4)
JackpotLine.BackgroundColor3 = Color3.fromRGB(0, 255, 120)
JackpotLine.BorderSizePixel = 0
JackpotLine.ZIndex = 3
corner(JackpotLine, 2)
local JackpotGlow = Instance.new("Frame", WheelFrame)
JackpotGlow.Size = UDim2.new(0, 14, 0, 14)
JackpotGlow.Position = UDim2.new(0.5, -7, 0, 2)
JackpotGlow.BackgroundColor3 = Color3.fromRGB(0, 255, 120)
JackpotGlow.BorderSizePixel = 0
JackpotGlow.ZIndex = 4
corner(JackpotGlow, 7)

local WheelInner = Instance.new("Frame", WheelFrame)
WheelInner.Size = UDim2.new(0.65, 0, 0.65, 0)
WheelInner.Position = UDim2.new(0.175, 0, 0.175, 0)
WheelInner.BackgroundColor3 = T.input
WheelInner.ZIndex = 2
corner(WheelInner, 50)
stroke(WheelInner, T.accent, 2)

local WheelLabel = Instance.new("TextLabel", WheelInner)
WheelLabel.Size = UDim2.new(1,0,1,0); WheelLabel.BackgroundTransparency = 1
WheelLabel.Text = "SPIN"; WheelLabel.TextColor3 = T.orange
WheelLabel.Font = Enum.Font.GothamBold; WheelLabel.TextSize = 16
WheelLabel.ZIndex = 3

local WheelPointer = Instance.new("TextLabel", OP_Spin)
WheelPointer.Size = UDim2.new(0, 30, 0, 18)
WheelPointer.Position = UDim2.new(0.5, -15, 0, 16)
WheelPointer.BackgroundTransparency = 1
WheelPointer.Text = "▼"; WheelPointer.TextColor3 = Color3.fromRGB(0, 255, 120)
WheelPointer.Font = Enum.Font.GothamBold; WheelPointer.TextSize = 16
WheelPointer.ZIndex = 5

-- Skip checkbox (instant spin)
local SkipOn = false
local SkipRow = Instance.new("Frame", OP_Spin)
SkipRow.Size = UDim2.new(1, 0, 0, 28)
SkipRow.Position = UDim2.new(0, 0, 0, 186)
SkipRow.BackgroundTransparency = 1

local SkipBox = Instance.new("TextButton", SkipRow)
SkipBox.Size = UDim2.new(0, 22, 0, 22)
SkipBox.Position = UDim2.new(0, 0, 0.5, -11)
SkipBox.BackgroundColor3 = T.input
SkipBox.Text = ""
SkipBox.AutoButtonColor = false
corner(SkipBox, 6)
stroke(SkipBox, Color3.fromRGB(60, 65, 75), 1.5)

local SkipLbl = label(SkipRow, "SKIP", UDim2.new(1, -30, 1, 0), UDim2.new(0, 30, 0, 0), T.muted, Enum.Font.Gotham, 12)

SkipBox.MouseButton1Click:Connect(function()
    SkipOn = not SkipOn
    if SkipOn then
        SkipBox.BackgroundColor3 = Color3.fromRGB(0, 200, 120)
        stroke(SkipBox, Color3.fromRGB(0, 255, 140), 1.5).Color = Color3.fromRGB(0, 255, 140)
        local st = SkipBox:FindFirstChildOfClass("UIStroke")
        if st then st.Color = Color3.fromRGB(0, 255, 140) end
    else
        SkipBox.BackgroundColor3 = T.input
        local st = SkipBox:FindFirstChildOfClass("UIStroke")
        if st then st.Color = Color3.fromRGB(60, 65, 75) end
    end
end)

local SpinBtn = btn(OP_Spin, "SPIN THE WHEEL", T.orange, UDim2.new(1,0,0,38), UDim2.new(0,0,0,222))
local SpinResult = label(OP_Spin, "Base 0.5% + Luck% = win chance  |  Luck used once then resets", UDim2.new(1,0,0,36), UDim2.new(0,0,0,268), T.muted, Enum.Font.Gotham, 11)
SpinResult.TextXAlignment = Enum.TextXAlignment.Center
SpinResult.TextWrapped = true

updateSpinUI = function()
    local p = SystemData.PlayerSpins[PlayerKey]
    if p then
        local luck = p.Luck or 0
        -- Base 0.5% + luck as percent points (100 luck = 100.5% = always win)
        local chancePct = 0.5 + luck
        if chancePct > 100 then chancePct = 100 end
        SpinInfo.Text = string.format("Spins: %d  |  Luck: +%d%%  |  Chance: %.1f%%", p.Spins, luck, chancePct)
    end
end
updateSpinUI()

local spinning = false

local function resolveSpin(luck)
    -- Base 5/1000 = 0.5%. Each 1 luck = +10/1000 = +1% chance
    -- 100 luck = 5+1000 = 1005/1000 = always win
    local chance = 5 + math.floor((luck or 0) * 10)
    local roll = math.random(1, 1000)
    if roll <= chance then
        local key = "SeedsPogi" .. math.random(100000, 999999)
        SystemData.ActiveCodes[key] = {Type = "Spin", Value = 7200, Duration = 86400}
        copyClip(key)
        SpinResult.TextColor3 = T.ok
        SpinResult.Text = "GREAT🤑\nKey: " .. key .. " (Copied)"
        WheelLabel.Text = "WIN!"
        addLog(LocalPlayer.Name .. " won spin: " .. key)
        return true
    else
        SpinResult.TextColor3 = T.warn
        SpinResult.Text = string.format("FAILED (rolled %d / need <= %d)\nBetter luck next time!", roll, chance)
        WheelLabel.Text = "FAIL"
        return false
    end
end

local function finishSpinAndMaybeHide()
    WheelLabel.Text = "SPIN"
    spinning = false
    if autoHideSpinOverlay then
        autoHideSpinOverlay = false
        task.delay(1.8, function()
            if OverlayGui then OverlayGui.Enabled = false end
        end)
    end
end

doSpin = function()
    if spinning then return end
    local p = SystemData.PlayerSpins[PlayerKey]
    if not p then
        SystemData.PlayerSpins[PlayerKey] = {Spins = 1, Luck = 0, LastSpin = 0}
        p = SystemData.PlayerSpins[PlayerKey]
        saveData()
    end
    local now = os.time()
    if (now - (p.LastSpin or 0)) < 86400 and p.Spins <= 0 then
        local r = 86400 - (now - p.LastSpin)
        SpinResult.TextColor3 = T.warn
        SpinResult.Text = "Cooldown: " .. math.floor(r/3600) .. "h " .. math.floor((r%3600)/60) .. "m"
        if autoHideSpinOverlay then
            task.delay(2.2, function()
                autoHideSpinOverlay = false
                if OverlayGui then OverlayGui.Enabled = false end
            end)
        end
        return
    end
    if p.Spins <= 0 and (now - (p.LastSpin or 0)) >= 86400 then p.Spins = 1 end
    if p.Spins <= 0 then
        SpinResult.TextColor3 = T.warn; SpinResult.Text = "No spins left!"
        if autoHideSpinOverlay then
            task.delay(2.2, function()
                autoHideSpinOverlay = false
                if OverlayGui then OverlayGui.Enabled = false end
            end)
        end
        return
    end

    spinning = true
    p.Spins = p.Spins - 1
    p.LastSpin = now
    local luck = p.Luck or 0
    p.Luck = 0 -- used once, then gone
    saveData(); updateSpinUI()

    if SkipOn then
        -- Instant result
        resolveSpin(luck)
        task.delay(1.2, finishSpinAndMaybeHide)
        return
    end

    -- Animate wheel — MUST land on green (top) if win
    local startRot = WheelFrame.Rotation
    local spinsN = math.random(5, 8)
    local chance = 5 + math.floor(luck * 10)
    local willWin = math.random(1, 1000) <= chance
    -- Green jackpot is at rotation mod 360 == 0 (top under pointer)
    local curMod = startRot % 360
    local targetMod = willWin and math.random(-4, 4) or math.random(50, 310)
    local delta = (targetMod - curMod + 360) % 360
    local endRot = startRot + spinsN * 360 + delta
    local t0 = os.clock()
    local dur = 2.8
    local conn
    conn = RunService.RenderStepped:Connect(function()
        local a = math.clamp((os.clock() - t0) / dur, 0, 1)
        local e = 1 - (1 - a) ^ 3
        WheelFrame.Rotation = startRot + (endRot - startRot) * e
        if a >= 1 then
            conn:Disconnect()
            if willWin then
                local key = "SeedsPogi" .. math.random(100000, 999999)
                SystemData.ActiveCodes[key] = {Type = "Spin", Value = 7200, Duration = 86400}
                copyClip(key)
                SpinResult.TextColor3 = T.ok
                SpinResult.Text = "GREAT🤑\nKey: " .. key .. " (Copied)"
                WheelLabel.Text = "WIN!"
                addLog(LocalPlayer.Name .. " won spin: " .. key)
            else
                SpinResult.TextColor3 = T.warn
                SpinResult.Text = string.format("FAILED (chance was %.1f%%)\nBetter luck next time!", math.min(100, 0.5 + luck))
                WheelLabel.Text = "FAIL"
            end
            task.delay(1.5, finishSpinAndMaybeHide)
        end
    end)
end
SpinBtn.MouseButton1Click:Connect(doSpin)

-- Feedback page
label(OP_Feed, "SEND FEEDBACK", nil, UDim2.new(0,0,0,4))
local OF_Box = input(OP_Feed, "WRITE BUG&NOT WORKING", UDim2.new(1,0,0,100), UDim2.new(0,0,0,28))
OF_Box.TextYAlignment = Enum.TextYAlignment.Top; OF_Box.TextWrapped = true
local OF_Btn = btn(OP_Feed, "SEND", T.ok, nil, UDim2.new(0,0,0,144))
OF_Btn.MouseButton1Click:Connect(function()
    if OF_Box.Text ~= "" then
        table.insert(SystemData.Feedbacks, {User = LocalPlayer.Name, UserId = LocalPlayer.UserId, Message = OF_Box.Text})
        addLog("Feedback from " .. LocalPlayer.Name); saveData(); OF_Box.Text = ""
        OF_Btn.Text = "SENT!"; task.wait(1.5); OF_Btn.Text = "SEND"
    end
end)

-- ═══════════════════════════════════════
-- NOTES page (admin broadcasts history)
-- ═══════════════════════════════════════
label(OP_Notes, "SEEDS NOTES", nil, UDim2.new(0,0,0,0))
local NotesScroll = Instance.new("ScrollingFrame", OP_Notes)
NotesScroll.Size = UDim2.new(1,0,1,-24)
NotesScroll.Position = UDim2.new(0,0,0,22)
NotesScroll.BackgroundColor3 = T.card2
NotesScroll.BorderSizePixel = 0
NotesScroll.ScrollBarThickness = 3
NotesScroll.CanvasSize = UDim2.new(0,0,0,0)
corner(NotesScroll, 10)
local NotesLay = Instance.new("UIListLayout", NotesScroll)
NotesLay.Padding = UDim.new(0,8)
NotesLay.SortOrder = Enum.SortOrder.LayoutOrder
local NotesPad = Instance.new("UIPadding", NotesScroll)
NotesPad.PaddingTop = UDim.new(0,8); NotesPad.PaddingLeft = UDim.new(0,8); NotesPad.PaddingRight = UDim.new(0,8)
NotesLay:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    NotesScroll.CanvasSize = UDim2.new(0,0,0, NotesLay.AbsoluteContentSize.Y + 16)
end)

refreshNotesUI = function()
    for _, c in ipairs(NotesScroll:GetChildren()) do
        if c:IsA("Frame") then c:Destroy() end
    end
    pcall(reloadSharedData)
    pcall(pollRemoteBroadcasts)
    SystemData = getgenv().SystemData or SystemData
    local list = SystemData.Broadcasts or {}
    -- ONLY the latest note
    local latest = nil
    for _, b in ipairs(list) do
        if type(b) == "table" then
            if not latest or (tonumber(b.Time) or 0) > (tonumber(latest.Time) or 0) then
                latest = b
            end
        end
    end
    if not latest then
        local empty = Instance.new("Frame", NotesScroll)
        empty.Size = UDim2.new(1,-4,0,60)
        empty.BackgroundColor3 = T.input
        corner(empty, 10)
        label(empty, "No notes from SEEDS yet", UDim2.new(1,0,1,0), nil, T.muted, Enum.Font.Gotham, 12).TextXAlignment = Enum.TextXAlignment.Center
    else
        local b = latest
        local card = Instance.new("Frame", NotesScroll)
        card.Size = UDim2.new(1,-4,0,120)
        card.BackgroundColor3 = T.input
        corner(card, 12)
        stroke(card, T.accent, 1.2)

        local av = Instance.new("ImageLabel", card)
        av.Size = UDim2.new(0,52,0,52)
        av.Position = UDim2.new(0,12,0,14)
        av.BackgroundColor3 = T.card2
        corner(av, 26)
        stroke(av, T.accent, 2)
        local sid = tonumber(b.SenderId) or 0
        if sid > 0 then
            pcall(function()
                av.Image = Players:GetUserThumbnailAsync(sid, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size420x420)
            end)
        end

        -- Always brand as SEEDS
        label(card, "SEEDS", UDim2.new(0.55,0,0,18), UDim2.new(0,76,0,12), T.accent, Enum.Font.GothamBold, 14)
        local when = type(b.Time) == "number" and os.date("%m/%d/%Y  %H:%M:%S", b.Time) or "?"
        label(card, when, UDim2.new(0.55,0,0,14), UDim2.new(0,76,0,32), T.muted, Enum.Font.Gotham, 10)
        local msg = label(card, tostring(b.Message or ""), UDim2.new(1,-88,0,52), UDim2.new(0,76,0,54), T.text, Enum.Font.Gotham, 12)
        msg.TextWrapped = true
        msg.TextYAlignment = Enum.TextYAlignment.Top
    end
    task.defer(function()
        NotesScroll.CanvasSize = UDim2.new(0,0,0, NotesLay.AbsoluteContentSize.Y + 16)
    end)
end

-- ═══════════════════════════════════════
-- GIFTS page (claim admin gifts / extends)
-- ═══════════════════════════════════════
label(OP_Gifts, "CLAIM. YOUR GIFT FROM SEEDS🎊", nil, UDim2.new(0,0,0,0))
local GiftsScroll = Instance.new("ScrollingFrame", OP_Gifts)
GiftsScroll.Size = UDim2.new(1,0,1,-24)
GiftsScroll.Position = UDim2.new(0,0,0,22)
GiftsScroll.BackgroundColor3 = T.card2
GiftsScroll.BorderSizePixel = 0
GiftsScroll.ScrollBarThickness = 3
GiftsScroll.CanvasSize = UDim2.new(0,0,0,0)
corner(GiftsScroll, 10)
local GiftsLay = Instance.new("UIListLayout", GiftsScroll)
GiftsLay.Padding = UDim.new(0,8)
GiftsLay.SortOrder = Enum.SortOrder.LayoutOrder
local GiftsPad = Instance.new("UIPadding", GiftsScroll)
GiftsPad.PaddingTop = UDim.new(0,8); GiftsPad.PaddingLeft = UDim.new(0,8); GiftsPad.PaddingRight = UDim.new(0,8)
GiftsLay:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    GiftsScroll.CanvasSize = UDim2.new(0,0,0, GiftsLay.AbsoluteContentSize.Y + 16)
end)

-- Persist claimed gift IDs so re-load / double-click never re-grants
getgenv().NovaState.claimedGiftIds = getgenv().NovaState.claimedGiftIds or {}
local claimingLock = {} -- [giftId] = true while claim in progress

local function removeGiftById(gid)
    SystemData.PlayerGifts = SystemData.PlayerGifts or {}
    local list = SystemData.PlayerGifts[PlayerKey]
    if type(list) ~= "table" then return end
    for i = #list, 1, -1 do
        local g = list[i]
        if type(g) == "table" and tostring(g.Id) == tostring(gid) then
            table.remove(list, i)
        end
    end
    SystemData.PlayerGifts[PlayerKey] = list
end

local function claimGift(gift)
    if not gift or type(gift) ~= "table" then return false end
    local gid = tostring(gift.Id or "")
    if gid == "" then return false end
    -- already claimed (memory or flag)
    if getgenv().NovaState.claimedGiftIds[gid] or gift.Claimed then
        removeGiftById(gid)
        saveData()
        return false
    end
    -- anti double-click / concurrent claim
    if claimingLock[gid] then return false end
    claimingLock[gid] = true

    -- lock + remove FIRST before granting reward
    gift.Claimed = true
    getgenv().NovaState.claimedGiftIds[gid] = true
    removeGiftById(gid)
    saveData()
    pcall(deleteRemoteGift, PlayerKey, gid)

    local typ = tostring(gift.Type or "")
    local amt = tonumber(gift.Amount) or 0
    local ok = true
    if typ == "Spin" then
        local p = SystemData.PlayerSpins[PlayerKey] or {Spins=0,Luck=0,LastSpin=0}
        SystemData.PlayerSpins[PlayerKey] = p
        p.Spins = (p.Spins or 0) + math.max(1, amt)
        if updateSpinUI then updateSpinUI() end
    elseif typ == "Luck" then
        local p = SystemData.PlayerSpins[PlayerKey] or {Spins=0,Luck=0,LastSpin=0}
        SystemData.PlayerSpins[PlayerKey] = p
        p.Luck = (p.Luck or 0) + math.max(1, amt)
        if updateSpinUI then updateSpinUI() end
    elseif typ == "Key" then
        local secs = math.max(60, amt)
        if unlockSystem then unlockSystem(secs, true, "Admin", false) end
    elseif typ == "Extend" then
        local secs = math.max(60, amt)
        if unlockSystem then unlockSystem(secs, true, "Admin", true) end
    else
        ok = false
    end
    if ok then
        saveData()
        addLog(LocalPlayer.Name .. " claimed gift: " .. typ .. " (" .. gid .. ")")
    end
    claimingLock[gid] = nil
    return ok
end

refreshGiftsUI = function()
    for _, c in ipairs(GiftsScroll:GetChildren()) do
        if c:IsA("Frame") then c:Destroy() end
    end
    pcall(reloadSharedData)
    SystemData = getgenv().SystemData or SystemData
    SystemData.PlayerGifts = SystemData.PlayerGifts or {}
    local list = SystemData.PlayerGifts[PlayerKey] or {}
    -- Clear legacy PendingGifts without re-adding claimable spam
    if SystemData.PendingGifts and SystemData.PendingGifts[PlayerKey] then
        SystemData.PendingGifts[PlayerKey] = nil
        saveData()
    end

    -- Purge already-claimed from list (file may still have them)
    local claimedMap = getgenv().NovaState.claimedGiftIds or {}
    local cleaned = {}
    local changed = false
    for _, g in ipairs(list) do
        if type(g) == "table" then
            local gid = tostring(g.Id or "")
            if g.Claimed or (gid ~= "" and claimedMap[gid]) then
                changed = true
            else
                table.insert(cleaned, g)
            end
        end
    end
    if changed then
        SystemData.PlayerGifts[PlayerKey] = cleaned
        list = cleaned
        saveData()
    end

    local sorted = {}
    for _, g in ipairs(list) do
        if type(g) == "table" and not g.Claimed then
            table.insert(sorted, g)
        end
    end
    table.sort(sorted, function(a, b)
        return (tonumber(a.Time) or 0) > (tonumber(b.Time) or 0)
    end)

    local order = 0
    if #sorted == 0 then
        local empty = Instance.new("Frame", GiftsScroll)
        empty.Size = UDim2.new(1,-4,0,50)
        empty.BackgroundColor3 = T.input
        corner(empty, 10)
        label(empty, "No gifts to claim", UDim2.new(1,0,1,0), nil, T.muted, Enum.Font.Gotham, 12).TextXAlignment = Enum.TextXAlignment.Center
    else
        for _, g in ipairs(sorted) do
            order = order + 1
            local card = Instance.new("Frame", GiftsScroll)
            card.Size = UDim2.new(1,-4,0,86)
            card.BackgroundColor3 = T.input
            card.LayoutOrder = order
            corner(card, 10)
            local av = Instance.new("ImageLabel", card)
            av.Size = UDim2.new(0,44,0,44)
            av.Position = UDim2.new(0,10,0,12)
            av.BackgroundColor3 = T.card2
            corner(av, 22)
            stroke(av, T.purple, 1.2)
            local sid = tonumber(g.SenderId)
            if sid and sid > 0 then
                pcall(function()
                    av.Image = Players:GetUserThumbnailAsync(sid, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size420x420)
                end)
            end
            local sender = tostring(g.Sender or "ADMIN")
            label(card, sender, UDim2.new(0.5,0,0,16), UDim2.new(0,64,0,8), T.purple, Enum.Font.GothamBold, 12)
            local when = type(g.Time) == "number" and os.date("%m/%d/%Y  %H:%M:%S", g.Time) or "?"
            label(card, when, UDim2.new(0.5,0,0,14), UDim2.new(0,64,0,26), T.muted, Enum.Font.Gotham, 10)
            local msg = label(card, tostring(g.Message or g.Type or "Gift"), UDim2.new(1,-120,0,28), UDim2.new(0,64,0,46), T.text, Enum.Font.Gotham, 11)
            msg.TextWrapped = true
            msg.TextYAlignment = Enum.TextYAlignment.Top

            local cb = btn(card, "CLAIM", T.ok, UDim2.new(0,64,0,28), UDim2.new(1,-74,0.5,-14))
            cb.TextSize = 11
            local giftRef = g
            local clicked = false
            cb.MouseButton1Click:Connect(function()
                if clicked then return end
                clicked = true
                cb.Text = "..."
                cb.Active = false
                if claimGift(giftRef) then
                    cb.Text = "OK!"
                    -- remove card immediately
                    pcall(function() card:Destroy() end)
                    task.defer(function()
                        if refreshGiftsUI then refreshGiftsUI() end
                    end)
                else
                    cb.Text = "DONE"
                    pcall(function() card:Destroy() end)
                    task.defer(function()
                        if refreshGiftsUI then refreshGiftsUI() end
                    end)
                end
            end)
        end
    end
    task.defer(function()
        GiftsScroll.CanvasSize = UDim2.new(0,0,0, GiftsLay.AbsoluteContentSize.Y + 16)
    end)
    -- Blue dot on Gifts tab
    if getgenv().NovaUpdateGiftsBadge then pcall(getgenv().NovaUpdateGiftsBadge) end
end

-- Helper: admin pushes a claimable gift to a player (1x only, anti-duplicate)
getgenv().NovaGiftSeq = getgenv().NovaGiftSeq or 0
pushPlayerGift = function(pk, giftType, amount, message)
    pk = tostring(pk)
    SystemData.PlayerGifts = SystemData.PlayerGifts or {}
    SystemData.PlayerGifts[pk] = SystemData.PlayerGifts[pk] or {}
    local list = SystemData.PlayerGifts[pk]
    local amt = tonumber(amount) or 0
    local now = os.time()
    -- Same Type+Amount unclaimed within 20s → do NOT send again
    for _, g in ipairs(list) do
        if type(g) == "table" and not g.Claimed
            and tostring(g.Type) == tostring(giftType)
            and tonumber(g.Amount) == amt
            and type(g.Time) == "number" and (now - g.Time) <= 20 then
            return nil
        end
    end
    getgenv().NovaGiftSeq = (getgenv().NovaGiftSeq or 0) + 1
    local gift = {
        Id = tostring(now) .. "_" .. tostring(getgenv().NovaGiftSeq) .. "_" .. tostring(math.random(100, 999)),
        Type = giftType,
        Amount = amt,
        Message = tostring(message or ""),
        Sender = LocalPlayer.Name,
        SenderId = LocalPlayer.UserId,
        Time = now,
        Claimed = false,
    }
    table.insert(list, gift)
    SystemData.PlayerGifts[pk] = list
    while #SystemData.PlayerGifts[pk] > 40 do table.remove(SystemData.PlayerGifts[pk], 1) end
    pcall(pushRemoteGift, pk, gift)
    return gift
end

-- ═══════════════════════════════════════
-- BROADCAST (toast optional; primary is Notes page)
-- ═══════════════════════════════════════
-- Side announcement toast — branded SEEDS + avatar frame
showBroadcast = function(msg, username, dur, avatarUserId)
    pcall(function()
        local p = getGuiParent()
        if p:FindFirstChild("NovaBroadcast") then p.NovaBroadcast:Destroy() end
    end)
    local g = Instance.new("ScreenGui")
    g.Name = "NovaBroadcast"
    g.ResetOnSpawn = false
    g.DisplayOrder = 500
    protectAndParent(g)

    local width, height = 300, 110
    local f = Instance.new("Frame", g)
    f.Size = UDim2.new(0, width, 0, height)
    -- slide in from RIGHT side
    f.Position = UDim2.new(1, 20, 0.18, 0)
    f.BackgroundColor3 = T.card
    f.ClipsDescendants = true
    corner(f, 14)
    stroke(f, T.accent, 1.8)

    local accent = Instance.new("Frame", f)
    accent.Size = UDim2.new(0, 4, 1, 0)
    accent.BackgroundColor3 = T.accent
    accent.BorderSizePixel = 0

    local av = Instance.new("ImageLabel", f)
    av.Size = UDim2.new(0, 48, 0, 48)
    av.Position = UDim2.new(0, 18, 0, 16)
    av.BackgroundColor3 = T.card2
    corner(av, 24)
    stroke(av, T.accent, 2)
    local uid = tonumber(avatarUserId) or LocalPlayer.UserId
    pcall(function()
        av.Image = Players:GetUserThumbnailAsync(uid, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size420x420)
    end)

    label(f, "SEEDS", UDim2.new(1, -80, 0, 18), UDim2.new(0, 76, 0, 14), T.accent, Enum.Font.GothamBold, 14)
    local m = label(f, tostring(msg or ""), UDim2.new(1, -90, 0, 52), UDim2.new(0, 76, 0, 36), T.text, Enum.Font.GothamMedium, 12)
    m.TextWrapped = true
    m.TextYAlignment = Enum.TextYAlignment.Top
    m.TextXAlignment = Enum.TextXAlignment.Left

    -- animate in from right
    tween(f, {Position = UDim2.new(1, -width - 16, 0.18, 0)}, 0.4, Enum.EasingStyle.Quint):Play()

    task.delay(dur or 6, function()
        local t = tween(f, {Position = UDim2.new(1, 20, 0.18, 0)}, 0.35, Enum.EasingStyle.Quint)
        t:Play()
        t.Completed:Connect(function()
            pcall(function() g:Destroy() end)
        end)
    end)
end

-- Gifts are claimable in /open → Gifts page (no auto popup)
checkPendingGifts = function()
    if refreshGiftsUI then pcall(refreshGiftsUI) end
end
checkPendingGifts()

-- Pending RESET: big center notice then auto-rejoin after 15s
showResetNotice = function(reason)
    pcall(function()
        local p = getGuiParent()
        if p:FindFirstChild("NovaResetNotice") then p.NovaResetNotice:Destroy() end
    end)
    local g = Instance.new("ScreenGui")
    g.Name = "NovaResetNotice"
    g.DisplayOrder = 999
    protectAndParent(g)
    local bg = Instance.new("Frame", g)
    bg.Size = UDim2.new(1, 0, 1, 0)
    bg.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    bg.BackgroundTransparency = 0.35
    bg.BorderSizePixel = 0
    local box = Instance.new("Frame", bg)
    box.Size = UDim2.new(0, 340, 0, 140)
    box.Position = UDim2.new(0.5, -170, 0.5, -70)
    box.BackgroundColor3 = Color3.fromRGB(20, 12, 14)
    corner(box, 14)
    stroke(box, T.warn, 2)
    local title = Instance.new("TextLabel", box)
    title.Size = UDim2.new(1, -20, 0, 40)
    title.Position = UDim2.new(0, 10, 0, 20)
    title.BackgroundTransparency = 1
    title.Text = "YOU GOT RESET"
    title.TextColor3 = T.warn
    title.Font = Enum.Font.GothamBold
    title.TextSize = 22
    local reasonLbl = Instance.new("TextLabel", box)
    reasonLbl.Size = UDim2.new(1, -24, 0, 40)
    reasonLbl.Position = UDim2.new(0, 12, 0, 65)
    reasonLbl.BackgroundTransparency = 1
    reasonLbl.Text = tostring(reason or "No reason")
    reasonLbl.TextColor3 = T.text
    reasonLbl.Font = Enum.Font.Gotham
    reasonLbl.TextSize = 14
    reasonLbl.TextWrapped = true
    local cd = Instance.new("TextLabel", box)
    cd.Size = UDim2.new(1, 0, 0, 20)
    cd.Position = UDim2.new(0, 0, 1, -28)
    cd.BackgroundTransparency = 1
    cd.Text = "Rejoining in 15s..."
    cd.TextColor3 = T.muted
    cd.Font = Enum.Font.GothamMedium
    cd.TextSize = 12
    task.spawn(function()
        for i = 15, 1, -1 do
            cd.Text = "Rejoining in " .. i .. "s..."
            task.wait(1)
        end
        pcall(function()
            game:GetService("TeleportService"):Teleport(game.PlaceId, LocalPlayer)
        end)
        task.wait(2)
        pcall(function() LocalPlayer:Kick("YOU GOT RESET - Rejoin") end)
    end)
end

local function checkPendingReset()
    SystemData = getgenv().SystemData or SystemData
    if SystemData.PendingResets and SystemData.PendingResets[PlayerKey] then
        local r = SystemData.PendingResets[PlayerKey]
        local token = tostring((type(r) == "table" and r.Time) or 0) .. ":" .. tostring((type(r) == "table" and r.Reason) or "")
        SystemData.PendingResets[PlayerKey] = nil
        saveData()
        if getgenv().NovaState.seenResets[token] then
            return -- already handled (re-execute / multi-loop)
        end
        getgenv().NovaState.seenResets[token] = true
        -- clear local access immediately
        SystemData.UserAccess[PlayerKey] = nil
        KeyBg.Visible = true
        pcall(function()
            local parent = getGuiParent()
            if parent:FindFirstChild("NovaTimerHUD") then parent.NovaTimerHUD:Destroy() end
        end)
        showResetNotice(type(r) == "table" and r.Reason or "Reset by admin")
    end
end
checkPendingReset()
task.spawn(function()
    while true do
        task.wait(2)
        if getgenv().NovaState.instanceId ~= MY_INSTANCE then return end
        checkPendingReset()
    end
end)

-- ═══════════════════════════════════════
end -- end Overlay scope

do
-- ADMIN PANEL
-- ═══════════════════════════════════════
AdminGui = Instance.new("ScreenGui")
AdminGui.Name = "NovaAdminUI"
AdminGui.Enabled = false
AdminGui.ResetOnSpawn = false
AdminGui.DisplayOrder = 120
protectAndParent(AdminGui)

local AMain = Instance.new("Frame", AdminGui)
AMain.Size = UDim2.new(0, 410, 0, 440)
AMain.Position = UDim2.new(0.5, -205, 0.5, -220)
AMain.BackgroundColor3 = T.card
corner(AMain, 14); stroke(AMain, T.warn, 1.5)

local AHead = Instance.new("Frame", AMain)
AHead.Size = UDim2.new(1,0,0,40); AHead.BackgroundColor3 = Color3.fromRGB(28,18,20)
corner(AHead, 14)
local ahf = Instance.new("Frame", AHead); ahf.Size = UDim2.new(1,0,0,12); ahf.Position = UDim2.new(0,0,1,-12); ahf.BackgroundColor3 = Color3.fromRGB(28,18,20); ahf.BorderSizePixel = 0
label(AHead, "ADMIN CONTROL", UDim2.new(0.7,0,1,0), UDim2.new(0.04,0,0,0), T.warn, Enum.Font.GothamBold, 13)
local AX = btn(AHead, "X", T.warn, UDim2.new(0,28,0,28), UDim2.new(1,-36,0.5,-14))
AX.TextSize = 12
AX.MouseButton1Click:Connect(function() AdminGui.Enabled = false end)
makeDraggable(AMain, AHead)

local ANav = Instance.new("ScrollingFrame", AMain)
ANav.Size = UDim2.new(0.94,0,0,30); ANav.Position = UDim2.new(0.03,0,0,46)
ANav.BackgroundTransparency = 1; ANav.CanvasSize = UDim2.new(8.0,0,0,0); ANav.ScrollBarThickness = 2
local aNavLay = Instance.new("UIListLayout", ANav)
aNavLay.FillDirection = Enum.FillDirection.Horizontal; aNavLay.Padding = UDim.new(0,4)

local APages = Instance.new("Frame", AMain)
APages.Size = UDim2.new(0.94,0,0,340); APages.Position = UDim2.new(0.03,0,0,84); APages.BackgroundTransparency = 1

local aPages = {}
local function aPage(n)
    local p = Instance.new("Frame", APages)
    p.Size = UDim2.new(1,0,1,0); p.BackgroundTransparency = 1; p.Visible = false
    aPages[n] = p; return p
end
local function switchA(n)
    for k, p in pairs(aPages) do p.Visible = (k == n) end
end
local function aNav(title, page)
    local b = Instance.new("TextButton", ANav)
    b.Size = UDim2.new(0, 86, 1, 0)
    b.BackgroundColor3 = T.card2; b.Text = title; b.TextColor3 = T.muted
    b.Font = Enum.Font.GothamMedium; b.TextSize = 10; b.AutoButtonColor = false; corner(b, 7)
    b.MouseButton1Click:Connect(function() switchA(page) end)
end

local PCodes = aPage("codes")
local PStock = aPage("stock")
local PBroad = aPage("broad")
local PNotesAdmin = aPage("notesadmin")
local PGiveAll = aPage("giveall")
local PTimer = aPage("timer")
local PActive = aPage("active")
local PLogs = aPage("logs")
local PGift = aPage("gift")
local PAdmin = aPage("admin")
local PFeed = aPage("feed")
local PReset = aPage("reset")
local PSkip = aPage("skip")
local PTest = aPage("test")
PCodes.Visible = true

aNav("Codes", "codes"); aNav("Stock", "stock"); aNav("Broadcast", "broad"); aNav("Notes", "notesadmin")
aNav("Give All", "giveall"); aNav("Give Timer", "timer"); aNav("Active", "active")
aNav("Logs", "logs"); aNav("Gift", "gift"); aNav("Admins", "admin")
aNav("Feedbacks", "feed"); aNav("Reset", "reset")
aNav("Skip Timer", "skip"); aNav("Testing", "test")

-- ── Admin: Codes (H/M/S for Admin Key, Months for Premium) ──
label(PCodes, "CREATE KEY CODE", nil, UDim2.new(0,0,0,2))
local CName = input(PCodes, "Code name...", nil, UDim2.new(0,0,0,22))
local CType = "Admin"
local TimeRow, CSingle
local function updateCodeFields()
    if not TimeRow or not CSingle then return end
    if CType == "Admin" then
        TimeRow.Visible = true; CSingle.Visible = false
    else
        TimeRow.Visible = false; CSingle.Visible = true
        if CType == "Premium" then CSingle.PlaceholderText = "Months (1 = 30 days)"
        elseif CType == "Spin" then CSingle.PlaceholderText = "Spins amount"
        else CSingle.PlaceholderText = "Luck amount (+%)" end
    end
end
local cRow = Instance.new("Frame", PCodes); cRow.Size = UDim2.new(1,0,0,28); cRow.Position = UDim2.new(0,0,0,68); cRow.BackgroundTransparency = 1
local ctl = Instance.new("UIListLayout", cRow); ctl.FillDirection = Enum.FillDirection.Horizontal; ctl.Padding = UDim.new(0,5)
local cBtns = {}
for _, t in ipairs({"Admin", "Premium", "Spin", "Luck"}) do
    local b = Instance.new("TextButton", cRow)
    b.Size = UDim2.new(0, 78, 1, 0); b.Text = t; b.Font = Enum.Font.GothamBold; b.TextSize = 11
    b.BackgroundColor3 = t=="Admin" and T.accent or T.card2
    b.TextColor3 = t=="Admin" and T.text or T.muted
    b.AutoButtonColor = false; corner(b, 7); cBtns[t] = b
    b.MouseButton1Click:Connect(function()
        CType = t
        for k, bb in pairs(cBtns) do
            bb.BackgroundColor3 = (k==t) and T.accent or T.card2
            bb.TextColor3 = (k==t) and T.text or T.muted
        end
        updateCodeFields()
    end)
end

TimeRow = Instance.new("Frame", PCodes)
TimeRow.Size = UDim2.new(1,0,0,36); TimeRow.Position = UDim2.new(0,0,0,106); TimeRow.BackgroundTransparency = 1
local function tBox(ph, x)
    local t = Instance.new("TextBox", TimeRow)
    t.Size = UDim2.new(0.31,0,1,0); t.Position = UDim2.new(x,0,0,0)
    t.BackgroundColor3 = T.input; t.PlaceholderText = ph; t.PlaceholderColor3 = T.muted
    t.Text = ""; t.TextColor3 = T.text; t.Font = Enum.Font.Gotham; t.TextSize = 12
    corner(t, 9); return t
end
local CHrs = tBox("Hours", 0)
local CMins = tBox("Mins", 0.345)
local CSecs = tBox("Secs", 0.69)

CSingle = input(PCodes, "Months (1 = 30 days) or Spins/Luck amount", nil, UDim2.new(0,0,0,106))
CSingle.Visible = false
updateCodeFields()

local CCreate = btn(PCodes, "CREATE CODE", T.ok, nil, UDim2.new(0,0,0,156))
CCreate.MouseButton1Click:Connect(function()
    local name = (CName.Text or ""):match("^%s*(.-)%s*$") or ""
    if name == "" or #name < 2 then
        CCreate.Text = "NAME TOO SHORT!"; task.wait(1.2); CCreate.Text = "CREATE CODE"; return
    end
    -- Security: block overly simple codes
    if #name < 3 then
        CCreate.Text = "MIN 3 CHARS!"; task.wait(1.2); CCreate.Text = "CREATE CODE"; return
    end
    local val, dur, typ = 1, 0, CType
    if CType == "Admin" then
        local h = tonumber(CHrs.Text) or 0
        local m = tonumber(CMins.Text) or 0
        local s = tonumber(CSecs.Text) or 0
        dur = h*3600 + m*60 + s
        if dur <= 0 then dur = 7200 end
        val = dur
    elseif CType == "Premium" then
        local months = tonumber(CSingle.Text) or 1
        dur = months * 30 * 86400 -- 1 month = 30 days
        val = dur; typ = "Premium"
    elseif CType == "Spin" then
        val = tonumber(CSingle.Text) or 1; typ = "SpinAmount"
    else
        val = tonumber(CSingle.Text) or 1; typ = "Luck"
    end
    -- Clear old redeem history so same name can be reused as a FRESH code
    SystemData.UsedCodes[name] = nil
    SystemData.BoundKeys[name] = nil
    -- Also clear any case-variant leftovers
    for k in pairs(SystemData.UsedCodes or {}) do
        if normalizeCode(k) == normalizeCode(name) then SystemData.UsedCodes[k] = nil end
    end
    for k in pairs(SystemData.BoundKeys or {}) do
        if normalizeCode(k) == normalizeCode(name) then SystemData.BoundKeys[k] = nil end
    end
    for k in pairs(SystemData.ActiveCodes or {}) do
        if normalizeCode(k) == normalizeCode(name) then SystemData.ActiveCodes[k] = nil end
    end
    SystemData.ActiveCodes[name] = {
        Type = typ, Value = val, Duration = dur,
        CreatedAt = os.time(), CreatedBy = LocalPlayer.Name,
        Consumed = false,
    }
    addLog("Code: " .. name .. " [" .. typ .. "]"); saveData()
    pcall(pushRemoteCodes)
    CCreate.Text = "CREATED!"; task.wait(1.2); CCreate.Text = "CREATE CODE"
    CName.Text = ""
end)

-- ── Stock ──
label(PStock, "STOCK CODE (limited uses, 1x per player)", nil, UDim2.new(0,0,0,2))
local SName = input(PStock, "Code name...", nil, UDim2.new(0,0,0,22))
local SMax = input(PStock, "Max players (stock)", nil, UDim2.new(0,0,0,68))
local SType = "Spin"
local SAmt, STimeRow -- forward decl (used inside button clicks)
local sRow = Instance.new("Frame", PStock); sRow.Size = UDim2.new(1,0,0,28); sRow.Position = UDim2.new(0,0,0,114); sRow.BackgroundTransparency = 1
local stl = Instance.new("UIListLayout", sRow); stl.FillDirection = Enum.FillDirection.Horizontal; stl.Padding = UDim.new(0,5)
local sBtns = {}
for _, t in ipairs({"Key","Spin","Luck"}) do
    local b = Instance.new("TextButton", sRow)
    b.Size = UDim2.new(0,90,1,0); b.Text = t; b.Font = Enum.Font.GothamBold; b.TextSize = 11
    b.BackgroundColor3 = t=="Spin" and T.accent or T.card2
    b.TextColor3 = t=="Spin" and T.text or T.muted
    b.AutoButtonColor = false; corner(b, 7); sBtns[t] = b
    b.MouseButton1Click:Connect(function()
        SType = t
        for k, bb in pairs(sBtns) do
            bb.BackgroundColor3 = (k==t) and T.accent or T.card2
            bb.TextColor3 = (k==t) and T.text or T.muted
        end
        if STimeRow then STimeRow.Visible = (t == "Key") end
        if SAmt then SAmt.Visible = (t ~= "Key") end
    end)
end
SAmt = input(PStock, "Spins / Luck amount", nil, UDim2.new(0,0,0,150))
STimeRow = Instance.new("Frame", PStock)
STimeRow.Size = UDim2.new(1,0,0,36); STimeRow.Position = UDim2.new(0,0,0,150); STimeRow.BackgroundTransparency = 1; STimeRow.Visible = false
local function sBox(ph, x)
    local t = Instance.new("TextBox", STimeRow)
    t.Size = UDim2.new(0.31,0,1,0); t.Position = UDim2.new(x,0,0,0)
    t.BackgroundColor3 = T.input; t.PlaceholderText = ph; t.PlaceholderColor3 = T.muted
    t.Text = ""; t.TextColor3 = T.text; t.Font = Enum.Font.Gotham; t.TextSize = 12; corner(t, 9)
    return t
end
local SHrs, SMins, SSecs = sBox("Hours", 0), sBox("Mins", 0.345), sBox("Secs", 0.69)
local SCreate = btn(PStock, "CREATE STOCK CODE", T.ok, UDim2.new(0.62,0,0,36), UDim2.new(0,0,0,200))
local SViewBtn = btn(PStock, "VIEW STOCK", T.accent2, UDim2.new(0.35,0,0,36), UDim2.new(0.65,0,0,200))
SViewBtn.TextSize = 11

SCreate.MouseButton1Click:Connect(function()
    local name = (SName.Text or ""):match("^%s*(.-)%s*$") or ""
    if name == "" or #name < 3 then
        SCreate.Text = "MIN 3 CHARS!"; task.wait(1.2); SCreate.Text = "CREATE STOCK CODE"; return
    end
    local maxU = tonumber(SMax.Text) or 1
    if maxU < 1 then maxU = 1 end
    if maxU > 10000 then maxU = 10000 end
    local val, dur, typ = 1, 0, SType
    if SType == "Key" then
        local h = tonumber(SHrs.Text) or 0
        local m = tonumber(SMins.Text) or 0
        local s = tonumber(SSecs.Text) or 0
        dur = h*3600 + m*60 + s
        if dur <= 0 then dur = 7200 end
        val = dur
    elseif SType == "Spin" then
        val = tonumber(SAmt.Text) or 1; typ = "SpinAmount"
    else
        val = tonumber(SAmt.Text) or 1; typ = "Luck"
    end
    -- Fresh code: clear old redeem history for this name
    SystemData.UsedCodes[name] = nil
    SystemData.BoundKeys[name] = nil
    for k in pairs(SystemData.UsedCodes or {}) do
        if normalizeCode(k) == normalizeCode(name) then SystemData.UsedCodes[k] = nil end
    end
    for k in pairs(SystemData.BoundKeys or {}) do
        if normalizeCode(k) == normalizeCode(name) then SystemData.BoundKeys[k] = nil end
    end
    for k in pairs(SystemData.ActiveCodes or {}) do
        if normalizeCode(k) == normalizeCode(name) then SystemData.ActiveCodes[k] = nil end
    end
    SystemData.ActiveCodes[name] = {
        Type = typ, Value = val, Duration = dur,
        MaxUses = maxU, UsedBy = {},
        CreatedAt = os.time(), CreatedBy = LocalPlayer.Name,
        Consumed = false,
    }
    addLog("STOCK: " .. name .. " x" .. maxU); saveData()
    pcall(pushRemoteCodes)
    SCreate.Text = "CREATED!"; task.wait(1.2); SCreate.Text = "CREATE STOCK CODE"
    SName.Text = ""
end)

-- ── Stock Viewer (own UI) ──
local function openStockViewer()
    pcall(function()
        local p = getGuiParent()
        if p:FindFirstChild("NovaStockViewer") then p.NovaStockViewer:Destroy() end
    end)
    pcall(cleanupDeadCodes)
    pcall(reloadSharedData)

    local sg = Instance.new("ScreenGui")
    sg.Name = "NovaStockViewer"
    sg.ResetOnSpawn = false
    sg.DisplayOrder = 140
    protectAndParent(sg)

    local dim = Instance.new("Frame", sg)
    dim.Size = UDim2.new(1,0,1,0)
    dim.BackgroundColor3 = Color3.fromRGB(0,0,0)
    dim.BackgroundTransparency = 0.45
    dim.BorderSizePixel = 0

    local box = Instance.new("Frame", sg)
    box.Size = UDim2.new(0, 340, 0, 0)
    box.Position = UDim2.new(0.5, -170, 0.5, -160)
    box.BackgroundColor3 = T.card
    box.ClipsDescendants = true
    corner(box, 14)
    stroke(box, T.accent2, 1.6)

    local head = Instance.new("Frame", box)
    head.Size = UDim2.new(1,0,0,40)
    head.BackgroundColor3 = T.card2
    corner(head, 14)
    local hf = Instance.new("Frame", head)
    hf.Size = UDim2.new(1,0,0,12); hf.Position = UDim2.new(0,0,1,-12)
    hf.BackgroundColor3 = T.card2; hf.BorderSizePixel = 0
    label(head, "STOCK VIEWER", UDim2.new(0.7,0,1,0), UDim2.new(0.04,0,0,0), T.accent2, Enum.Font.GothamBold, 13)
    local xBtn = btn(head, "X", T.warn, UDim2.new(0,28,0,28), UDim2.new(1,-36,0.5,-14))
    xBtn.TextSize = 12
    xBtn.MouseButton1Click:Connect(function()
        local t = tween(box, {Size = UDim2.new(0,340,0,0)}, 0.22)
        t:Play(); t.Completed:Connect(function() pcall(function() sg:Destroy() end) end)
    end)
    makeDraggable(box, head)

    local scroll = Instance.new("ScrollingFrame", box)
    scroll.Size = UDim2.new(1,-16,1,-52)
    scroll.Position = UDim2.new(0,8,0,46)
    scroll.BackgroundColor3 = T.card2
    scroll.BorderSizePixel = 0
    scroll.ScrollBarThickness = 3
    scroll.CanvasSize = UDim2.new(0,0,0,0)
    corner(scroll, 10)
    local lay = Instance.new("UIListLayout", scroll)
    lay.Padding = UDim.new(0,6)
    lay.SortOrder = Enum.SortOrder.LayoutOrder
    local pad = Instance.new("UIPadding", scroll)
    pad.PaddingTop = UDim.new(0,6); pad.PaddingLeft = UDim.new(0,6); pad.PaddingRight = UDim.new(0,6)

    local function refresh()
        for _, c in ipairs(scroll:GetChildren()) do
            if c:IsA("Frame") then c:Destroy() end
        end
        pcall(cleanupDeadCodes)
        pcall(reloadSharedData)
        local any = false
        local order = 0
        for name, data in pairs(SystemData.ActiveCodes or {}) do
            if type(data) == "table" and data.MaxUses and tonumber(data.MaxUses) and tonumber(data.MaxUses) > 0 then
                local maxU = tonumber(data.MaxUses)
                local used = countUsedBy(data.UsedBy or {})
                local left = math.max(0, maxU - used)
                if left <= 0 then
                    SystemData.ActiveCodes[name] = nil
                else
                    any = true
                    order = order + 1
                    local card = Instance.new("Frame", scroll)
                    card.Size = UDim2.new(1,-4,0,58)
                    card.BackgroundColor3 = T.input
                    card.LayoutOrder = order
                    corner(card, 10)
                    label(card, tostring(name), UDim2.new(0.7,0,0,18), UDim2.new(0,10,0,6), T.text, Enum.Font.GothamBold, 12)
                    local typ = tostring(data.Type or "?")
                    label(card, typ .. "  ·  left " .. left .. " / " .. maxU, UDim2.new(0.7,0,0,16), UDim2.new(0,10,0,28), T.muted, Enum.Font.Gotham, 11)
                    local del = btn(card, "DEL", T.warn, UDim2.new(0,48,0,24), UDim2.new(1,-56,0.5,-12))
                    del.TextSize = 10
                    del.MouseButton1Click:Connect(function()
                        SystemData.ActiveCodes[name] = nil
                        SystemData.UsedCodes[name] = nil
                        SystemData.BoundKeys[name] = nil
                        addLog("Stock deleted: " .. name)
                        saveData()
                        refresh()
                    end)
                end
            end
        end
        if not any then
            local empty = Instance.new("Frame", scroll)
            empty.Size = UDim2.new(1,-4,0,40)
            empty.BackgroundColor3 = T.input
            corner(empty, 8)
            label(empty, "No active stock codes", UDim2.new(1,0,1,0), nil, T.muted, Enum.Font.Gotham, 12).TextXAlignment = Enum.TextXAlignment.Center
        end
        saveData()
        task.defer(function()
            scroll.CanvasSize = UDim2.new(0,0,0, lay.AbsoluteContentSize.Y + 16)
        end)
    end
    lay:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        scroll.CanvasSize = UDim2.new(0,0,0, lay.AbsoluteContentSize.Y + 16)
    end)
    refresh()
    tween(box, {Size = UDim2.new(0,340,0,320)}, 0.3):Play()

    task.spawn(function()
        while sg.Parent do
            task.wait(3)
            if sg.Parent then refresh() end
        end
    end)
end

SViewBtn.MouseButton1Click:Connect(openStockViewer)

-- ── Broadcast (SIDE toast only — SEEDS branded) ──
label(PBroad, "SIDE BROADCAST — appears on players' screen edge", nil, UDim2.new(0,0,0,2))
local BInput = input(PBroad, "Broadcast message...", UDim2.new(1,0,0,90), UDim2.new(0,0,0,22))
BInput.TextYAlignment = Enum.TextYAlignment.Top; BInput.TextWrapped = true
local BSend = btn(PBroad, "SEND SIDE BROADCAST", T.orange, nil, UDim2.new(0,0,0,128))

-- Shared note/broadcast queue (also used by Notes page)
enqueueBroadcast = function(msg, sender)
    msg = tostring(msg or "")
    if msg == "" then return end
    local giftSnap = SystemData.PlayerGifts
    pcall(reloadSharedData)
    if type(giftSnap) == "table" then
        SystemData.PlayerGifts = SystemData.PlayerGifts or {}
        for uid, glist in pairs(giftSnap) do
            if type(glist) == "table" then
                local cur = SystemData.PlayerGifts[tostring(uid)] or {}
                local byId = {}
                for _, g in ipairs(cur) do
                    if type(g) == "table" and g.Id then byId[tostring(g.Id)] = g end
                end
                for _, g in ipairs(glist) do
                    if type(g) == "table" and g.Id then
                        byId[tostring(g.Id)] = byId[tostring(g.Id)] or g
                    end
                end
                local merged = {}
                for _, g in pairs(byId) do table.insert(merged, g) end
                SystemData.PlayerGifts[tostring(uid)] = merged
            end
        end
    end
    SystemData.Broadcasts = SystemData.Broadcasts or {}
    local newId = (lastBroadcastId or 0) + 1
    for _, b in ipairs(SystemData.Broadcasts) do
        if type(b) == "table" and type(b.Id) == "number" and b.Id >= newId then
            newId = b.Id + 1
        end
    end
    lastBroadcastId = newId
    getgenv().NovaState.lastBroadcastId = newId
    -- Always brand as SEEDS
    table.insert(SystemData.Broadcasts, {
        Id = newId,
        Message = msg,
        Sender = "SEEDS",
        SenderId = LocalPlayer.UserId,
        Time = os.time(),
    })
    while #SystemData.Broadcasts > 50 do table.remove(SystemData.Broadcasts, 1) end
    saveData()
    pushRemoteBroadcast(msg, "SEEDS", newId, LocalPlayer.UserId)
    if refreshNotesUI then pcall(refreshNotesUI) end
end

BSend.MouseButton1Click:Connect(function()
    if BInput.Text ~= "" then
        local msg = BInput.Text
        -- Side toast only (does NOT change Notes unless you also use Notes page)
        showBroadcast(msg, "SEEDS", 6, LocalPlayer.UserId)
        -- Also push remote so other devices can show side toast via poll
        enqueueBroadcast(msg, "SEEDS")
        addLog("Side Broadcast: " .. msg)
        BInput.Text = ""
        BSend.Text = "SENT!"; task.wait(1.2); BSend.Text = "SEND SIDE BROADCAST"
    end
end)

-- ── Admin Notes (editable — shows in player /open → Notes) ──
label(PNotesAdmin, "EDIT NOTE — players see this in /open → Notes", nil, UDim2.new(0,0,0,2))
local NPreview = label(PNotesAdmin, "Current: (none)", UDim2.new(1,0,0,16), UDim2.new(0,0,0,22), T.muted, Enum.Font.Gotham, 11)
NPreview.TextTruncate = Enum.TextTruncate.AtEnd
local NInput = input(PNotesAdmin, "Write / edit note text here...", UDim2.new(1,0,0,100), UDim2.new(0,0,0,44))
NInput.TextYAlignment = Enum.TextYAlignment.Top
NInput.TextWrapped = true
local NSave = btn(PNotesAdmin, "UPDATE NOTE", T.ok, UDim2.new(0.48,0,0,40), UDim2.new(0,0,0,156))
local NClear = btn(PNotesAdmin, "CLEAR NOTE", T.warn, UDim2.new(0.48,0,0,40), UDim2.new(0.52,0,0,156))

local function loadCurrentNoteToAdmin()
    pcall(reloadSharedData)
    pcall(pollRemoteBroadcasts)
    local list = SystemData.Broadcasts or {}
    local latest = nil
    for _, b in ipairs(list) do
        if type(b) == "table" then
            if not latest or (tonumber(b.Time) or 0) > (tonumber(latest.Time) or 0) then
                latest = b
            end
        end
    end
    if latest then
        NInput.Text = tostring(latest.Message or "")
        local when = type(latest.Time) == "number" and os.date("%m/%d %H:%M", latest.Time) or "?"
        NPreview.Text = "Current: " .. when .. " — " .. tostring(latest.Message or ""):sub(1, 40)
    else
        NInput.Text = ""
        NPreview.Text = "Current: (none)"
    end
end

NSave.MouseButton1Click:Connect(function()
    local msg = (NInput.Text or ""):match("^%s*(.-)%s*$") or ""
    if msg == "" then
        NSave.Text = "EMPTY!"; task.wait(1); NSave.Text = "UPDATE NOTE"; return
    end
    enqueueBroadcast(msg, "SEEDS")
    -- optional local toast for admin
    showBroadcast(msg, "SEEDS", 4, LocalPlayer.UserId)
    addLog("Note updated: " .. msg)
    loadCurrentNoteToAdmin()
    NSave.Text = "UPDATED!"; task.wait(1.2); NSave.Text = "UPDATE NOTE"
end)

NClear.MouseButton1Click:Connect(function()
    SystemData.Broadcasts = {}
    saveData()
    -- clear remote notes by writing empty marker
    if remoteEnabled() then
        pcall(function()
            remotePut("nova_bc.json", { cleared = os.time() })
        end)
    end
    NInput.Text = ""
    NPreview.Text = "Current: (none)"
    if refreshNotesUI then pcall(refreshNotesUI) end
    NClear.Text = "CLEARED!"; task.wait(1); NClear.Text = "CLEAR NOTE"
end)

PNotesAdmin:GetPropertyChangedSignal("Visible"):Connect(function()
    if PNotesAdmin.Visible then loadCurrentNoteToAdmin() end
end)

-- ── Give All ──
label(PGiveAll, "GIVE TO ALL ONLINE PLAYERS", nil, UDim2.new(0,0,0,2))
local GAType = "Spin"
local GAAmt, GATimeRow -- forward decl
local gaRow = Instance.new("Frame", PGiveAll); gaRow.Size = UDim2.new(1,0,0,28); gaRow.Position = UDim2.new(0,0,0,24); gaRow.BackgroundTransparency = 1
local gal = Instance.new("UIListLayout", gaRow); gal.FillDirection = Enum.FillDirection.Horizontal; gal.Padding = UDim.new(0,5)
local gaBtns = {}
for _, t in ipairs({"Key","Spin","Luck"}) do
    local b = Instance.new("TextButton", gaRow)
    b.Size = UDim2.new(0,90,1,0); b.Text = t; b.Font = Enum.Font.GothamBold; b.TextSize = 11
    b.BackgroundColor3 = t=="Spin" and T.accent or T.card2
    b.TextColor3 = t=="Spin" and T.text or T.muted
    b.AutoButtonColor = false; corner(b, 7); gaBtns[t] = b
    b.MouseButton1Click:Connect(function()
        GAType = t
        for k, bb in pairs(gaBtns) do
            bb.BackgroundColor3 = (k==t) and T.accent or T.card2
            bb.TextColor3 = (k==t) and T.text or T.muted
        end
        if GATimeRow then GATimeRow.Visible = (t == "Key") end
        if GAAmt then GAAmt.Visible = (t ~= "Key") end
    end)
end
GAAmt = input(PGiveAll, "Spins / Luck amount", nil, UDim2.new(0,0,0,64))
GATimeRow = Instance.new("Frame", PGiveAll)
GATimeRow.Size = UDim2.new(1,0,0,36); GATimeRow.Position = UDim2.new(0,0,0,64); GATimeRow.BackgroundTransparency = 1; GATimeRow.Visible = false
local function gaBox(ph, x)
    local t = Instance.new("TextBox", GATimeRow)
    t.Size = UDim2.new(0.31,0,1,0); t.Position = UDim2.new(x,0,0,0)
    t.BackgroundColor3 = T.input; t.PlaceholderText = ph; t.PlaceholderColor3 = T.muted
    t.Text = ""; t.TextColor3 = T.text; t.Font = Enum.Font.Gotham; t.TextSize = 12; corner(t, 9)
    return t
end
local GAHrs, GAMins, GASecs = gaBox("Hours", 0), gaBox("Mins", 0.345), gaBox("Secs", 0.69)
local GABtn = btn(PGiveAll, "GIVE TO EVERYONE", T.ok, nil, UDim2.new(0,0,0,114))
local gaBusy = false
GABtn.MouseButton1Click:Connect(function()
    if gaBusy then return end
    if not pushPlayerGift then
        GABtn.Text = "ERR: no gift fn"; task.wait(1.2); GABtn.Text = "GIVE TO EVERYONE"; return
    end
    gaBusy = true
    GABtn.Text = "SENDING..."
    pcall(reloadSharedData)
    local targets = {}
    targets[PlayerKey] = true
    for _, p in ipairs(Players:GetPlayers()) do
        targets[tostring(p.UserId)] = true
    end
    for uid, t in pairs(SystemData.ScriptOnline or {}) do
        if type(t) == "number" and (os.time() - t) <= 120 then
            targets[tostring(uid)] = true
        end
    end

    local sent = 0
    if GAType == "Spin" then
        local amt = tonumber(GAAmt.Text) or 1
        for pk in pairs(targets) do
            if pushPlayerGift(pk, "Spin", amt, "You got +" .. amt .. " spin(s) from admin!") then
                sent = sent + 1
            end
        end
        saveData()
        addLog("Give All [Spin] x" .. amt .. " → " .. sent .. " players")
    elseif GAType == "Luck" then
        local amt = tonumber(GAAmt.Text) or 1
        for pk in pairs(targets) do
            if pushPlayerGift(pk, "Luck", amt, "You got +" .. amt .. "% luck from admin!") then
                sent = sent + 1
            end
        end
        saveData()
        addLog("Give All [Luck] x" .. amt .. " → " .. sent .. " players")
    else
        local h = tonumber(GAHrs.Text) or 0
        local m = tonumber(GAMins.Text) or 0
        local sec = tonumber(GASecs.Text) or 0
        local secs = h*3600 + m*60 + sec
        if secs <= 0 then secs = 7200 end
        for pk in pairs(targets) do
            if pushPlayerGift(pk, "Key", secs, string.format("You got %dh %dm %ds access from admin!", h, m, sec)) then
                sent = sent + 1
            end
        end
        saveData()
        addLog("Give All [Key] " .. secs .. "s → " .. sent .. " players")
    end
    saveData()
    if refreshGiftsUI then pcall(refreshGiftsUI) end
    GABtn.Text = "SENT x" .. tostring(sent)
    task.wait(1.5)
    GABtn.Text = "GIVE TO EVERYONE"
    gaBusy = false
end)

-- ── Give Timer (NEW) ──
label(PTimer, "EXTEND TIMER — User or All", nil, UDim2.new(0,0,0,2))
local GTMode = "User"
local gtRow = Instance.new("Frame", PTimer); gtRow.Size = UDim2.new(1,0,0,28); gtRow.Position = UDim2.new(0,0,0,24); gtRow.BackgroundTransparency = 1
local gtl = Instance.new("UIListLayout", gtRow); gtl.FillDirection = Enum.FillDirection.Horizontal; gtl.Padding = UDim.new(0,5)
local gtUserBtn = Instance.new("TextButton", gtRow)
gtUserBtn.Size = UDim2.new(0,100,1,0); gtUserBtn.Text = "User"; gtUserBtn.Font = Enum.Font.GothamBold; gtUserBtn.TextSize = 12
gtUserBtn.BackgroundColor3 = T.accent; gtUserBtn.TextColor3 = T.text; gtUserBtn.AutoButtonColor = false; corner(gtUserBtn, 7)
local gtAllBtn = Instance.new("TextButton", gtRow)
gtAllBtn.Size = UDim2.new(0,100,1,0); gtAllBtn.Text = "All Online"; gtAllBtn.Font = Enum.Font.GothamBold; gtAllBtn.TextSize = 12
gtAllBtn.BackgroundColor3 = T.card2; gtAllBtn.TextColor3 = T.muted; gtAllBtn.AutoButtonColor = false; corner(gtAllBtn, 7)
gtUserBtn.MouseButton1Click:Connect(function()
    GTMode = "User"; gtUserBtn.BackgroundColor3 = T.accent; gtUserBtn.TextColor3 = T.text
    gtAllBtn.BackgroundColor3 = T.card2; gtAllBtn.TextColor3 = T.muted
end)
gtAllBtn.MouseButton1Click:Connect(function()
    GTMode = "All"; gtAllBtn.BackgroundColor3 = T.accent; gtAllBtn.TextColor3 = T.text
    gtUserBtn.BackgroundColor3 = T.card2; gtUserBtn.TextColor3 = T.muted
end)

local GTUser = input(PTimer, "Username (if User mode)...", nil, UDim2.new(0,0,0,62))
local GTTime = Instance.new("Frame", PTimer)
GTTime.Size = UDim2.new(1,0,0,36); GTTime.Position = UDim2.new(0,0,0,108); GTTime.BackgroundTransparency = 1
local function gtBox(ph, x)
    local t = Instance.new("TextBox", GTTime)
    t.Size = UDim2.new(0.31,0,1,0); t.Position = UDim2.new(x,0,0,0)
    t.BackgroundColor3 = T.input; t.PlaceholderText = ph; t.PlaceholderColor3 = T.muted
    t.Text = ""; t.TextColor3 = T.text; t.Font = Enum.Font.Gotham; t.TextSize = 12; corner(t, 9)
    return t
end
local GTHrs = gtBox("Hours", 0)
local GTMins = gtBox("Mins", 0.345)
local GTSecs = gtBox("Secs", 0.69)
local GTBtn = btn(PTimer, "EXTEND TIMER", T.accent2, nil, UDim2.new(0,0,0,160))
local gtBusy = false
GTBtn.MouseButton1Click:Connect(function()
    if gtBusy then return end
    if not pushPlayerGift then
        GTBtn.Text = "ERR: no gift fn"; task.wait(1.2); GTBtn.Text = "EXTEND TIMER"; return
    end
    gtBusy = true
    local h = tonumber(GTHrs.Text) or 0
    local m = tonumber(GTMins.Text) or 0
    local s = tonumber(GTSecs.Text) or 0
    local add = h*3600 + m*60 + s
    if add <= 0 then add = 3600 end
    local msg = string.format("Timer extend +%dh %dm %ds from admin — claim in Gifts!", h, m, s)

    if GTMode == "All" then
        pcall(reloadSharedData)
        local targets = {}
        targets[PlayerKey] = true
        for _, p in ipairs(Players:GetPlayers()) do targets[tostring(p.UserId)] = true end
        for uid, t in pairs(SystemData.ScriptOnline or {}) do
            if type(t) == "number" and (os.time() - t) <= 120 then
                targets[tostring(uid)] = true
            end
        end
        local count = 0
        for pk in pairs(targets) do
            pushPlayerGift(pk, "Extend", add, msg)
            count = count + 1
        end
        saveData() -- SAVE before broadcast reload
        enqueueBroadcast("Admin sent timer extend gift to everyone — claim in /open Gifts", LocalPlayer.Name)
        addLog("Give Timer ALL +" .. add .. "s → " .. count .. " players")
        saveData()
        if refreshGiftsUI then pcall(refreshGiftsUI) end
        GTBtn.Text = "SENT x" .. tostring(count); task.wait(1.4); GTBtn.Text = "EXTEND TIMER"
        gtBusy = false
    else
        local name = GTUser.Text
        if name == "" then gtBusy = false; return end
        local uid
        for _, p in ipairs(Players:GetPlayers()) do
            if string.lower(p.Name) == string.lower(name) then uid = p.UserId; name = p.Name; break end
        end
        if not uid then pcall(function() uid = Players:GetUserIdFromNameAsync(name) end) end
        if not uid then
            GTBtn.Text = "NOT FOUND!"; task.wait(1.2); GTBtn.Text = "EXTEND TIMER"; gtBusy = false; return
        end
        pushPlayerGift(tostring(uid), "Extend", add, msg)
        saveData()
        addLog("Give Timer " .. name .. " +" .. add .. "s (claimable)")
        if tostring(uid) == PlayerKey and refreshGiftsUI then pcall(refreshGiftsUI) end
        GTBtn.Text = "SENT TO GIFTS!"; task.wait(1.2); GTBtn.Text = "EXTEND TIMER"
        gtBusy = false
    end
end)

-- ── Active ──
local ActScroll = Instance.new("ScrollingFrame", PActive)
ActScroll.Size = UDim2.new(1,0,1,0); ActScroll.BackgroundColor3 = T.card2
ActScroll.CanvasSize = UDim2.new(0,0,0,0); ActScroll.ScrollBarThickness = 3; corner(ActScroll, 8)
local ActLay = Instance.new("UIListLayout", ActScroll); ActLay.Padding = UDim.new(0,5)
-- FIX: auto-resize canvas based on content
ActLay:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    ActScroll.CanvasSize = UDim2.new(0,0,0, ActLay.AbsoluteContentSize.Y + 12)
end)

refreshActive = function()
    for _, c in ipairs(ActScroll:GetChildren()) do if c:IsA("Frame") then c:Destroy() end end
    local now = os.time()
    pcall(reloadSharedData)
    SystemData = getgenv().SystemData or SystemData
    local online = {}
    for _, p in ipairs(Players:GetPlayers()) do online[tostring(p.UserId)] = p end
    local scriptUsers = SystemData.ScriptOnline or {}
    local any = false
    local order = 0
    -- Collect all valid access entries (not only same-server)
    local rows = {}
    for uid, acc in pairs(SystemData.UserAccess or {}) do
        local exp = type(acc) == "table" and acc.Expire or acc
        local typ = type(acc) == "table" and (acc.Type or "?") or "Legacy"
        if type(exp) == "number" and exp > now then
            table.insert(rows, {uid = tostring(uid), exp = exp, typ = typ})
        end
    end
    table.sort(rows, function(a, b) return a.exp > b.exp end)

    for _, row in ipairs(rows) do
        any = true
        order = order + 1
        local uid = row.uid
        local exp, typ = row.exp, row.typ
        local rem = exp - now
        local hb = scriptUsers[uid]
        local isScript = type(hb) == "number" and (now - hb) <= 90
        local plr = online[uid]
        local displayName = plr and plr.Name or ("User " .. uid)
        -- try cached name from SkipTimer / gifts
        if not plr then
            local st = SystemData.SkipTimer and SystemData.SkipTimer[uid]
            if type(st) == "table" and st.Name then displayName = tostring(st.Name) end
        end
        local status = plr and "IN SERVER" or (isScript and "SCRIPT ON" or "OFFLINE")
        local statusCol = plr and T.ok or (isScript and T.accent2 or T.muted)

        local card = Instance.new("Frame", ActScroll)
        card.Size = UDim2.new(1, -6, 0, 70)
        card.BackgroundColor3 = T.input
        card.LayoutOrder = order
        corner(card, 10)

        local av = Instance.new("ImageLabel", card)
        av.Size = UDim2.new(0, 42, 0, 42)
        av.Position = UDim2.new(0, 8, 0.5, -21)
        av.BackgroundColor3 = T.card2
        corner(av, 21)
        stroke(av, statusCol, 1.4)
        local idNum = tonumber(uid)
        if idNum then
            pcall(function()
                av.Image = Players:GetUserThumbnailAsync(idNum, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size420x420)
            end)
        end

        label(card, displayName, UDim2.new(0.5, 0, 0, 16), UDim2.new(0, 60, 0, 6), T.text, Enum.Font.GothamBold, 12)
        label(card, "Key: " .. typ .. "  ·  " .. status, UDim2.new(0.55, 0, 0, 14), UDim2.new(0, 60, 0, 26), statusCol, Enum.Font.Gotham, 10)
        label(card, string.format("%02dh %02dm %02ds left", math.floor(rem/3600), math.floor((rem%3600)/60), rem%60),
            UDim2.new(0.55, 0, 0, 14), UDim2.new(0, 60, 0, 44), T.ok, Enum.Font.GothamMedium, 10)

        local eb = btn(card, "EXPIRE", T.warn, UDim2.new(0, 64, 0, 24), UDim2.new(1, -74, 0.5, -12))
        eb.TextSize = 10
        local tUid, tName = uid, displayName
        eb.MouseButton1Click:Connect(function()
            SystemData.UserAccess[tUid] = nil
            addLog("Expired " .. tName)
            saveData()
            refreshActive()
        end)
    end

    if not any then
        local e = Instance.new("Frame", ActScroll)
        e.Size = UDim2.new(1, -6, 0, 40)
        e.BackgroundColor3 = T.input
        corner(e, 8)
        label(e, "No active keys found", UDim2.new(1, 0, 1, 0), nil, T.muted, Enum.Font.Gotham, 11).TextXAlignment = Enum.TextXAlignment.Center
    end
    task.defer(function()
        ActScroll.CanvasSize = UDim2.new(0, 0, 0, ActLay.AbsoluteContentSize.Y + 12)
    end)
end
task.spawn(function()
    while AdminGui.Parent do
        if AdminGui and AdminGui.Enabled and aPages and aPages.active and aPages.active.Visible then
            pcall(refreshActive)
        end
        task.wait(2)
    end
end)

-- ── Logs ──
local LogScroll = Instance.new("ScrollingFrame", PLogs)
LogScroll.Size = UDim2.new(1,0,1,-44); LogScroll.BackgroundColor3 = T.card2
LogScroll.CanvasSize = UDim2.new(0,0,0,0); LogScroll.ScrollBarThickness = 3; corner(LogScroll, 8)
local LogLay = Instance.new("UIListLayout", LogScroll); LogLay.Padding = UDim.new(0,2)
-- FIX: auto-resize
LogLay:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    LogScroll.CanvasSize = UDim2.new(0,0,0, LogLay.AbsoluteContentSize.Y + 10)
end)
refreshLogs = function()
    for _, c in ipairs(LogScroll:GetChildren()) do if c:IsA("TextLabel") then c:Destroy() end end
    for _, m in ipairs(SystemData.Logs or {}) do
        local t = Instance.new("TextLabel", LogScroll)
        t.Size = UDim2.new(1,-8,0,16); t.BackgroundTransparency = 1
        t.Text = m; t.TextColor3 = T.ok; t.Font = Enum.Font.Code; t.TextSize = 10
        t.TextXAlignment = Enum.TextXAlignment.Left
    end
    -- FIX: update canvas after rebuild
    task.defer(function()
        LogScroll.CanvasSize = UDim2.new(0,0,0, LogLay.AbsoluteContentSize.Y + 10)
    end)
end
local ClearLog = btn(PLogs, "CLEAR LOG", T.warn, UDim2.new(1,0,0,36), UDim2.new(0,0,1,-40))
ClearLog.MouseButton1Click:Connect(function() SystemData.Logs = {}; saveData(); refreshLogs() end)
PLogs:GetPropertyChangedSignal("Visible"):Connect(function() if PLogs.Visible then refreshLogs() end end)

-- ── Gift single ──
label(PGift, "GIFT ONE PLAYER", nil, UDim2.new(0,0,0,2))
local GTarget = input(PGift, "Username...", nil, UDim2.new(0,0,0,22))
local GType = "Spin"
local GAmt, GTimeRow -- forward decl (fixes nil Visible error)
local gRow = Instance.new("Frame", PGift); gRow.Size = UDim2.new(1,0,0,28); gRow.Position = UDim2.new(0,0,0,68); gRow.BackgroundTransparency = 1
local grl = Instance.new("UIListLayout", gRow); grl.FillDirection = Enum.FillDirection.Horizontal; grl.Padding = UDim.new(0,5)
local gBtns = {}
for _, t in ipairs({"Spin","Luck","Key"}) do
    local b = Instance.new("TextButton", gRow)
    b.Size = UDim2.new(0,90,1,0); b.Text = t; b.Font = Enum.Font.GothamBold; b.TextSize = 11
    b.BackgroundColor3 = t=="Spin" and T.accent or T.card2
    b.TextColor3 = t=="Spin" and T.text or T.muted
    b.AutoButtonColor = false; corner(b, 7); gBtns[t] = b
    b.MouseButton1Click:Connect(function()
        GType = t
        for k, bb in pairs(gBtns) do
            bb.BackgroundColor3 = (k==t) and T.accent or T.card2
            bb.TextColor3 = (k==t) and T.text or T.muted
        end
        if GTimeRow then GTimeRow.Visible = (t == "Key") end
        if GAmt then GAmt.Visible = (t ~= "Key") end
    end)
end
GAmt = input(PGift, "Spins / Luck amount", nil, UDim2.new(0,0,0,106))
GTimeRow = Instance.new("Frame", PGift)
GTimeRow.Size = UDim2.new(1,0,0,36); GTimeRow.Position = UDim2.new(0,0,0,106); GTimeRow.BackgroundTransparency = 1; GTimeRow.Visible = false
local function gBox(ph, x)
    local t = Instance.new("TextBox", GTimeRow)
    t.Size = UDim2.new(0.31,0,1,0); t.Position = UDim2.new(x,0,0,0)
    t.BackgroundColor3 = T.input; t.PlaceholderText = ph; t.PlaceholderColor3 = T.muted
    t.Text = ""; t.TextColor3 = T.text; t.Font = Enum.Font.Gotham; t.TextSize = 12; corner(t, 9)
    return t
end
local GHrs, GMins, GSecs = gBox("Hours", 0), gBox("Mins", 0.345), gBox("Secs", 0.69)
local GSend = btn(PGift, "SEND GIFT", T.orange, nil, UDim2.new(0,0,0,156))
GSend.MouseButton1Click:Connect(function()
    local name = GTarget.Text; if name == "" then return end
    local uid
    for _, p in ipairs(Players:GetPlayers()) do
        if string.lower(p.Name) == string.lower(name) then uid = p.UserId; name = p.Name; break end
    end
    if not uid then pcall(function() uid = Players:GetUserIdFromNameAsync(name) end) end
    if not uid then return end
    local tk = tostring(uid)
    local msg = ""
    if GType == "Spin" then
        local amt = tonumber(GAmt.Text) or 1
        msg = "You got +" .. amt .. " spin(s)!"
        pushPlayerGift(tk, "Spin", amt, msg)
    elseif GType == "Luck" then
        local amt = tonumber(GAmt.Text) or 1
        msg = "You got +" .. amt .. "% luck!"
        pushPlayerGift(tk, "Luck", amt, msg)
    else
        local h = tonumber(GHrs.Text) or 0
        local m = tonumber(GMins.Text) or 0
        local s = tonumber(GSecs.Text) or 0
        local secs = h*3600 + m*60 + s
        if secs <= 0 then secs = 7200 end
        msg = string.format("You got %dh %dm %ds access!", h, m, s)
        pushPlayerGift(tk, "Key", secs, msg)
    end
    addLog("Gift " .. GType .. " to " .. name .. " (claimable)")
    saveData()
    if tk == PlayerKey and refreshGiftsUI then pcall(refreshGiftsUI) end
    GSend.Text = "SENT TO GIFTS!"; task.wait(1.2); GSend.Text = "SEND GIFT"
end)

-- ── Admins ──
label(PAdmin, "ADD ADMIN", nil, UDim2.new(0,0,0,2))
local AUser = input(PAdmin, "Username...", UDim2.new(0.65,0,0,36), UDim2.new(0,0,0,22))
local AAdd = btn(PAdmin, "ADD", T.ok, UDim2.new(0.32,0,0,36), UDim2.new(0.68,0,0,22))
local AdminList = Instance.new("ScrollingFrame", PAdmin)
AdminList.Size = UDim2.new(1,0,0,240); AdminList.Position = UDim2.new(0,0,0,68)
AdminList.BackgroundColor3 = T.card2; AdminList.CanvasSize = UDim2.new(0,0,0,0); AdminList.ScrollBarThickness = 3; corner(AdminList, 8)
local AL = Instance.new("UIListLayout", AdminList); AL.Padding = UDim.new(0,4)
-- FIX: auto-resize
AL:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    AdminList.CanvasSize = UDim2.new(0,0,0, AL.AbsoluteContentSize.Y + 10)
end)
local function refreshAdmins()
    for _, c in ipairs(AdminList:GetChildren()) do if c:IsA("Frame") then c:Destroy() end end
    for n, _ in pairs(SystemData.Admins or {}) do
        local card = Instance.new("Frame", AdminList)
        card.Size = UDim2.new(1,-6,0,36); card.BackgroundColor3 = T.input; corner(card, 8)
        label(card, n, UDim2.new(0.6,0,1,0), UDim2.new(0,10,0,0), T.text, Enum.Font.GothamBold, 12)
        local ub = btn(card, "REMOVE", T.warn, UDim2.new(0,70,0,24), UDim2.new(1,-80,0.5,-12))
        ub.TextSize = 10
        ub.MouseButton1Click:Connect(function()
            if string.lower(n) == string.lower(SystemData.MainOwner) then return end
            SystemData.Admins[n] = nil; addLog("Unranked " .. n); saveData(); refreshAdmins()
        end)
    end
    -- FIX: update canvas after rebuild
    task.defer(function()
        AdminList.CanvasSize = UDim2.new(0,0,0, AL.AbsoluteContentSize.Y + 10)
    end)
end
AAdd.MouseButton1Click:Connect(function()
    if AUser.Text ~= "" then
        SystemData.Admins[AUser.Text] = true
        addLog("Admin: " .. AUser.Text); saveData(); AUser.Text = ""; refreshAdmins()
    end
end)
PAdmin:GetPropertyChangedSignal("Visible"):Connect(function() if PAdmin.Visible then refreshAdmins() end end)

-- ── Feedbacks view ──
local FeedScroll = Instance.new("ScrollingFrame", PFeed)
FeedScroll.Size = UDim2.new(1,0,1,-44); FeedScroll.BackgroundColor3 = T.card2
FeedScroll.CanvasSize = UDim2.new(0,0,0,0); FeedScroll.ScrollBarThickness = 3; corner(FeedScroll, 8)
local FeedLay = Instance.new("UIListLayout", FeedScroll); FeedLay.Padding = UDim.new(0,4)
-- FIX: auto-resize
FeedLay:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    FeedScroll.CanvasSize = UDim2.new(0,0,0, FeedLay.AbsoluteContentSize.Y + 10)
end)
local function refreshFeeds()
    for _, c in ipairs(FeedScroll:GetChildren()) do if c:IsA("Frame") then c:Destroy() end end
    for _, fb in ipairs(SystemData.Feedbacks or {}) do
        local card = Instance.new("Frame", FeedScroll)
        card.Size = UDim2.new(1,-6,0,50); card.BackgroundColor3 = T.input; corner(card, 8)
        label(card, tostring(fb.User), UDim2.new(1,-10,0,16), UDim2.new(0,8,0,4), T.accent, Enum.Font.GothamBold, 11)
        local msg = label(card, tostring(fb.Message), UDim2.new(1,-16,0,28), UDim2.new(0,8,0,20), T.text, Enum.Font.Gotham, 10)
        msg.TextWrapped = true
    end
    -- FIX: update canvas after rebuild
    task.defer(function()
        FeedScroll.CanvasSize = UDim2.new(0,0,0, FeedLay.AbsoluteContentSize.Y + 10)
    end)
end
local ClearFeed = btn(PFeed, "CLEAR FEEDBACKS", T.warn, UDim2.new(1,0,0,36), UDim2.new(0,0,1,-40))
ClearFeed.MouseButton1Click:Connect(function() SystemData.Feedbacks = {}; saveData(); refreshFeeds() end)
PFeed:GetPropertyChangedSignal("Visible"):Connect(function() if PFeed.Visible then refreshFeeds() end end)

-- ── Reset ──
label(PReset, "RESET USER DATA", nil, UDim2.new(0,0,0,2))
local RUser = input(PReset, "Username...", nil, UDim2.new(0,0,0,22))
local RReason = input(PReset, "Reason...", UDim2.new(1,0,0,60), UDim2.new(0,0,0,68))
RReason.TextYAlignment = Enum.TextYAlignment.Top
local RBtn = btn(PReset, "RESET DATA", T.warn, nil, UDim2.new(0,0,0,144))
RBtn.MouseButton1Click:Connect(function()
    local name = RUser.Text; if name == "" then return end
    local uid
    for _, p in ipairs(Players:GetPlayers()) do
        if string.lower(p.Name) == string.lower(name) then uid = p.UserId; name = p.Name; break end
    end
    if not uid then pcall(function() uid = Players:GetUserIdFromNameAsync(name) end) end
    if uid then
        local tk = tostring(uid)
        local reason = (RReason.Text ~= "" and RReason.Text) or "No reason provided"
        SystemData.UserAccess[tk] = nil
        SystemData.PlayerSpins[tk] = nil
        SystemData.PendingGifts[tk] = nil
        SystemData.PendingResets = SystemData.PendingResets or {}
        SystemData.PendingResets[tk] = {Reason = reason, Time = os.time()}
        addLog("Reset " .. name .. " | " .. reason)
        saveData()
        RBtn.Text = "RESET!"; task.wait(1.5); RBtn.Text = "RESET DATA"
        RUser.Text = ""; RReason.Text = ""
    end
end)

-- ── Skip Timer ──
label(PSkip, "SKIP TIMER — bypass key wait", nil, UDim2.new(0,0,0,2))
local SKUser = input(PSkip, "Username to add...", UDim2.new(0.65,0,0,36), UDim2.new(0,0,0,22))
local SKAdd = btn(PSkip, "ADD", T.ok, UDim2.new(0.32,0,0,36), UDim2.new(0.68,0,0,22))
local SKScroll = Instance.new("ScrollingFrame", PSkip)
SKScroll.Size = UDim2.new(1,0,0,250)
SKScroll.Position = UDim2.new(0,0,0,68)
SKScroll.BackgroundColor3 = T.card2
SKScroll.CanvasSize = UDim2.new(0,0,0,0)
SKScroll.ScrollBarThickness = 3
corner(SKScroll, 8)
local SKLay = Instance.new("UIListLayout", SKScroll)
SKLay.Padding = UDim.new(0,6)
SKLay.SortOrder = Enum.SortOrder.LayoutOrder
local SKPad = Instance.new("UIPadding", SKScroll)
SKPad.PaddingTop = UDim.new(0,6); SKPad.PaddingLeft = UDim.new(0,6); SKPad.PaddingRight = UDim.new(0,6)

local function refreshSkipList()
    for _, c in ipairs(SKScroll:GetChildren()) do
        if c:IsA("Frame") then c:Destroy() end
    end
    SystemData.SkipTimer = SystemData.SkipTimer or {}
    local order = 0
    local any = false
    for uid, info in pairs(SystemData.SkipTimer) do
        if type(info) == "table" then
            any = true
            order = order + 1
            local card = Instance.new("Frame", SKScroll)
            card.Size = UDim2.new(1,-8,0,56)
            card.BackgroundColor3 = T.input
            card.LayoutOrder = order
            corner(card, 10)
            local av = Instance.new("ImageLabel", card)
            av.Size = UDim2.new(0,40,0,40)
            av.Position = UDim2.new(0,8,0.5,-20)
            av.BackgroundColor3 = T.card2
            corner(av, 20)
            stroke(av, T.accent, 1.2)
            local idNum = tonumber(uid)
            if idNum then
                pcall(function()
                    av.Image = Players:GetUserThumbnailAsync(idNum, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size420x420)
                end)
            end
            local uname = tostring(info.Name or uid)
            label(card, uname, UDim2.new(0.55,0,0,18), UDim2.new(0,56,0,6), T.text, Enum.Font.GothamBold, 12)
            local when = type(info.AddedAt) == "number" and os.date("%m/%d %H:%M", info.AddedAt) or "?"
            label(card, "Added: " .. when, UDim2.new(0.55,0,0,16), UDim2.new(0,56,0,28), T.muted, Enum.Font.Gotham, 10)
            local rm = btn(card, "REMOVE", T.warn, UDim2.new(0,64,0,24), UDim2.new(1,-72,0.5,-12))
            rm.TextSize = 10
            local tUid = tostring(uid)
            rm.MouseButton1Click:Connect(function()
                SystemData.SkipTimer[tUid] = nil
                addLog("SkipTimer removed: " .. uname)
                saveData()
                refreshSkipList()
            end)
        end
    end
    if not any then
        local empty = Instance.new("Frame", SKScroll)
        empty.Size = UDim2.new(1,-8,0,36)
        empty.BackgroundColor3 = T.input
        corner(empty, 8)
        label(empty, "No users on Skip Timer", UDim2.new(1,0,1,0), nil, T.muted, Enum.Font.Gotham, 11).TextXAlignment = Enum.TextXAlignment.Center
    end
    task.defer(function()
        SKScroll.CanvasSize = UDim2.new(0,0,0, SKLay.AbsoluteContentSize.Y + 14)
    end)
end
SKLay:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    SKScroll.CanvasSize = UDim2.new(0,0,0, SKLay.AbsoluteContentSize.Y + 14)
end)

SKAdd.MouseButton1Click:Connect(function()
    local name = (SKUser.Text or ""):match("^%s*(.-)%s*$") or ""
    if name == "" then return end
    local uid
    for _, p in ipairs(Players:GetPlayers()) do
        if string.lower(p.Name) == string.lower(name) then
            uid = p.UserId; name = p.Name; break
        end
    end
    if not uid then pcall(function() uid = Players:GetUserIdFromNameAsync(name) end) end
    if not uid then
        SKAdd.Text = "NOT FOUND!"; task.wait(1.2); SKAdd.Text = "ADD"; return
    end
    SystemData.SkipTimer = SystemData.SkipTimer or {}
    SystemData.SkipTimer[tostring(uid)] = {
        Name = name,
        AddedAt = os.time(),
        AddedBy = LocalPlayer.Name,
    }
    addLog("SkipTimer + " .. name)
    saveData()
    SKUser.Text = ""
    SKAdd.Text = "ADDED!"; task.wait(1.0); SKAdd.Text = "ADD"
    refreshSkipList()
end)
PSkip:GetPropertyChangedSignal("Visible"):Connect(function()
    if PSkip.Visible then refreshSkipList() end
end)

-- ── Testing (admin feature simulator) ──
label(PTest, "TESTING — simulate player features", nil, UDim2.new(0,0,0,2))
local TestScroll = Instance.new("ScrollingFrame", PTest)
TestScroll.Size = UDim2.new(1,0,1,-28)
TestScroll.Position = UDim2.new(0,0,0,24)
TestScroll.BackgroundTransparency = 1
TestScroll.CanvasSize = UDim2.new(0,0,0,0)
TestScroll.ScrollBarThickness = 3
local TestLay = Instance.new("UIListLayout", TestScroll)
TestLay.Padding = UDim.new(0,8)
TestLay.SortOrder = Enum.SortOrder.LayoutOrder
-- FIX: auto-resize canvas
TestLay:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    TestScroll.CanvasSize = UDim2.new(0,0,0, TestLay.AbsoluteContentSize.Y + 16)
end)
local function testBtn(text, color, fn)
    local b = btn(TestScroll, text, color or T.accent, UDim2.new(1,0,0,36), UDim2.new(0,0,0,0))
    b.LayoutOrder = TestLay.AbsoluteContentSize.Y
    b.MouseButton1Click:Connect(function()
        local ok, err = pcall(fn)
        if not ok then
            b.Text = "ERR"; warn("[NOVA TEST] " .. tostring(err))
            task.wait(1.2); b.Text = text
        else
            b.Text = "OK!"; task.wait(1.0); b.Text = text
        end
    end)
    return b
end

testBtn("Test Broadcast (local)", T.orange, function()
    showBroadcast("Test broadcast from Testing page", "TEST", 5)
end)
testBtn("Test Gift Notice (self)", T.purple, function()
    SystemData.PendingGifts[PlayerKey] = {
        Message = "Test gift notice!",
        Sender = "TEST", Time = os.time(),
    }
    -- force unseen so it always shows for test
    getgenv().NovaState.seenGifts = getgenv().NovaState.seenGifts or {}
    for k in pairs(getgenv().NovaState.seenGifts) do
        if tostring(k):find("Test gift") then getgenv().NovaState.seenGifts[k] = nil end
    end
    saveData()
    checkPendingGifts()
end)
testBtn("Test Unlock +5 min", T.ok, function()
    unlockSystem(300, true, "Admin", false)
end)
testBtn("Test Extend +2 min", T.accent2, function()
    unlockSystem(120, true, "Admin", true)
end)
testBtn("Test +1 Spin (self)", T.orange, function()
    local p = SystemData.PlayerSpins[PlayerKey] or {Spins=0,Luck=0,LastSpin=0}
    SystemData.PlayerSpins[PlayerKey] = p
    p.Spins = (p.Spins or 0) + 1
    saveData(); updateSpinUI()
end)
testBtn("Test +10 Luck (self)", T.purple, function()
    local p = SystemData.PlayerSpins[PlayerKey] or {Spins=0,Luck=0,LastSpin=0}
    SystemData.PlayerSpins[PlayerKey] = p
    p.Luck = (p.Luck or 0) + 10
    saveData(); updateSpinUI()
end)
testBtn("Test Open Player Menu", T.accent, function()
    OverlayGui.Enabled = true
    switchOv("codes")
    updateSpinUI()
end)
testBtn("Test Create Temp Stock Code", T.ok, function()
    local name = "teststock" .. tostring(math.random(100,999))
    SystemData.ActiveCodes[name] = {
        Type = "SpinAmount", Value = 1, Duration = 0,
        MaxUses = 2, UsedBy = {}, CreatedAt = os.time(), CreatedBy = "TEST",
    }
    saveData()
    copyClip(name)
    showBroadcast("Temp stock code copied: " .. name, "TEST", 5)
end)
testBtn("Test Cleanup Dead Codes", T.warn, function()
    local r = cleanupDeadCodes()
    showBroadcast("Cleaned " .. tostring(#(r or {})) .. " dead code(s)", "TEST", 4)
end)
testBtn("Test Add Self to Skip Timer", T.ok, function()
    SystemData.SkipTimer = SystemData.SkipTimer or {}
    SystemData.SkipTimer[PlayerKey] = {
        Name = LocalPlayer.Name, AddedAt = os.time(), AddedBy = "TEST",
    }
    saveData()
end)
testBtn("Test Remove Self from Skip Timer", T.warn, function()
    SystemData.SkipTimer = SystemData.SkipTimer or {}
    SystemData.SkipTimer[PlayerKey] = nil
    saveData()
end)

-- ═══════════════════════════════════════
end -- end Admin scope

-- ═══════════════════════════════════════
-- /g  SEED TRIAL — earn free time (hard, anti-cheat)
-- ═══════════════════════════════════════
do
    -- Mode base prize (level 1). Then +50s, then that bonus doubles each level.
    -- Special: if total hits exactly 5:00, next bonus resets to +50s (then doubles again).
    local MODE_BASE = {
        easy = 60,       -- 1 min
        medium = 120,    -- 2 min
        hard = 150,      -- 2 min 30s
        extreme = 180,   -- 3 min
    }
    local MODE_DIFF = {
        easy =    { seqAdd = 0, flashMul = 1.30, gapMul = 1.35, timeMul = 1.40, decoyFrom = 99 },
        medium =  { seqAdd = 0, flashMul = 1.00, gapMul = 1.00, timeMul = 1.00, decoyFrom = 6 },
        hard =    { seqAdd = 1, flashMul = 0.72, gapMul = 0.68, timeMul = 0.78, decoyFrom = 4 },
        extreme = { seqAdd = 2, flashMul = 0.52, gapMul = 0.48, timeMul = 0.62, decoyFrom = 2 },
    }
    local TILE_COLORS = {
        Color3.fromRGB(0, 210, 160),
        Color3.fromRGB(0, 160, 255),
        Color3.fromRGB(255, 90, 90),
        Color3.fromRGB(255, 150, 40),
        Color3.fromRGB(150, 80, 255),
        Color3.fromRGB(255, 220, 60),
        Color3.fromRGB(80, 220, 255),
        Color3.fromRGB(255, 80, 170),
        Color3.fromRGB(120, 255, 100),
    }
    local TILE_IDLE = Color3.fromRGB(28, 32, 40)

    getgenv().NovaGameG = getgenv().NovaGameG or {
        level = 1,
        pendingLevel = 0,
        lastStart = 0,
        wins = 0,
        mode = "medium",
    }
    local GSave = getgenv().NovaGameG
    if not GSave.mode then GSave.mode = "medium" end

    local function getMode()
        local m = string.lower(tostring(GSave.mode or "medium"))
        if not MODE_BASE[m] then m = "medium" end
        return m
    end

    -- L1 = base. L2 = base+50. Then the +bonus doubles each level (50→100→200…).
    -- If total lands on exactly 5:00 (300s), next bonus resets to +50 then doubles again.
    local function rewardFor(lv, mode)
        lv = math.max(1, tonumber(lv) or 1)
        mode = mode or getMode()
        local base = MODE_BASE[mode] or 120
        if lv <= 1 then return base end
        local total = base
        local inc = 50
        for i = 2, lv do
            total = total + inc
            if total == 300 then
                inc = 50
            else
                inc = inc * 2
            end
        end
        return total
    end

    local function fmtDur(sec)
        sec = math.max(0, math.floor(tonumber(sec) or 0))
        local h = math.floor(sec / 3600)
        local m = math.floor((sec % 3600) / 60)
        local ss = sec % 60
        if h > 0 then
            if m > 0 and ss > 0 then return string.format("%dh %dm %ds", h, m, ss) end
            if m > 0 then return string.format("%dh %dm", h, m) end
            if ss > 0 then return string.format("%dh %ds", h, ss) end
            return h .. "h"
        end
        if m > 0 and ss > 0 then return string.format("%dm %ds", m, ss) end
        if m > 0 then return m .. "m" end
        return ss .. "s"
    end

    local function levelCfg(lv, mode)
        lv = math.max(1, tonumber(lv) or 1)
        mode = mode or getMode()
        local d = MODE_DIFF[mode] or MODE_DIFF.medium
        local seqLen = math.min(3 + lv + (d.seqAdd or 0), 16)
        local flash = math.max(0.10, (0.52 - lv * 0.038) * (d.flashMul or 1))
        local gap = math.max(0.04, (0.20 - lv * 0.014) * (d.gapMul or 1))
        local inputTime = math.max(3.2, (9.5 - lv * 0.50) * (d.timeMul or 1))
        local decoy = lv >= (d.decoyFrom or 6)
        return seqLen, flash, gap, inputTime, decoy
    end
    local function simpleHash(s)
        s = tostring(s or "")
        local h = 2166136261
        for i = 1, #s do
            h = (h + string.byte(s, i) * (i + 17)) % 4294967291
            h = (h * 16777619) % 4294967291
        end
        return string.format("%08X", h)
    end
    local function genWinCodeName(lv)
        local a = string.format("%X", (os.time() + math.random(1000, 9999)) % 1048575)
        local b = string.format("%X", math.random(4096, 65535))
        return "G" .. tostring(lv) .. "-" .. a .. b
    end

    -- Destroy leftover UI from previous execute
    pcall(function()
        local parent = getGuiParent()
        if parent and parent:FindFirstChild("NovaGameG") then parent.NovaGameG:Destroy() end
        if CoreGui:FindFirstChild("NovaGameG") then CoreGui.NovaGameG:Destroy() end
    end)

    local GameGui = Instance.new("ScreenGui")
    GameGui.Name = "NovaGameG"
    GameGui.ResetOnSpawn = false
    GameGui.Enabled = false
    GameGui.DisplayOrder = 140
    GameGui.IgnoreGuiInset = true
    protectAndParent(GameGui)

    local Dim = Instance.new("Frame", GameGui)
    Dim.Size = UDim2.new(1, 0, 1, 0)
    Dim.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    Dim.BackgroundTransparency = 0.45
    Dim.BorderSizePixel = 0
    Dim.ZIndex = 1

    -- Compact card: scale to screen so X + START always fit on mobile
    local Card = Instance.new("Frame", GameGui)
    Card.Name = "TrialCard"
    Card.AnchorPoint = Vector2.new(0.5, 0.5)
    Card.Position = UDim2.new(0.5, 0, 0.5, 0)
    Card.Size = UDim2.new(0.92, 0, 0.78, 0)
    Card.BackgroundColor3 = T.card
    Card.BorderSizePixel = 0
    Card.ZIndex = 2
    Card.ClipsDescendants = false
    corner(Card, 14)
    stroke(Card, T.accent, 1.6)
    local cardLimit = Instance.new("UISizeConstraint", Card)
    cardLimit.MaxSize = Vector2.new(300, 400)
    cardLimit.MinSize = Vector2.new(240, 320)
    local cardAspect = Instance.new("UIAspectRatioConstraint", Card)
    cardAspect.AspectRatio = 0.78
    cardAspect.DominantAxis = Enum.DominantAxis.Height

    local Head = Instance.new("Frame", Card)
    Head.Size = UDim2.new(1, 0, 0.1, 0)
    Head.BackgroundColor3 = T.card2
    Head.BorderSizePixel = 0
    Head.ZIndex = 4
    corner(Head, 14)
    local hf = Instance.new("Frame", Head)
    hf.Size = UDim2.new(1, 0, 0.4, 0)
    hf.Position = UDim2.new(0, 0, 0.6, 0)
    hf.BackgroundColor3 = T.card2
    hf.BorderSizePixel = 0
    hf.ZIndex = 4
    label(Head, "SEED TRIAL", UDim2.new(0.7, 0, 1, 0), UDim2.new(0.04, 0, 0, 0), T.accent, Enum.Font.GothamBlack, 13).ZIndex = 5
    makeDraggable(Card, Head)

    -- X sits on the ScreenGui (not clipped) — always visible on mobile
    local CloseG = btn(GameGui, "X", T.warn, UDim2.new(0, 36, 0, 36), UDim2.new(0.5, 118, 0.5, -188))
    CloseG.AnchorPoint = Vector2.new(0.5, 0.5)
    CloseG.ZIndex = 20
    CloseG.TextSize = 16
    CloseG.Font = Enum.Font.GothamBlack
    local function placeClose()
        -- pin X to top-right of the card
        local abs = Card.AbsolutePosition
        local asz = Card.AbsoluteSize
        CloseG.Position = UDim2.new(0, abs.X + asz.X - 6, 0, abs.Y + 6)
        CloseG.AnchorPoint = Vector2.new(1, 0)
    end
    Card:GetPropertyChangedSignal("AbsolutePosition"):Connect(placeClose)
    Card:GetPropertyChangedSignal("AbsoluteSize"):Connect(placeClose)
    GameGui:GetPropertyChangedSignal("Enabled"):Connect(function()
        if GameGui.Enabled then task.defer(placeClose) end
    end)
    task.defer(placeClose)

    local LvlLbl = label(Card, "LEVEL 1", UDim2.new(0.92, 0, 0.055, 0), UDim2.new(0.04, 0, 0.105, 0), T.text, Enum.Font.GothamBold, 14)
    LvlLbl.TextXAlignment = Enum.TextXAlignment.Center
    LvlLbl.ZIndex = 3
    local RewLbl = label(Card, "Redeem now: 2m   Next: 5m", UDim2.new(0.92, 0, 0.045, 0), UDim2.new(0.04, 0, 0.155, 0), T.muted, Enum.Font.Gotham, 10)
    RewLbl.TextXAlignment = Enum.TextXAlignment.Center
    RewLbl.ZIndex = 3
    local HintLbl = label(Card, "Watch the pattern. Repeat it.", UDim2.new(0.92, 0, 0.04, 0), UDim2.new(0.04, 0, 0.195, 0), T.muted, Enum.Font.Gotham, 10)
    HintLbl.TextWrapped = true
    HintLbl.TextXAlignment = Enum.TextXAlignment.Center
    HintLbl.ZIndex = 3

    -- Difficulty mode row (locked once a round starts)
    local ModeRow = Instance.new("Frame", Card)
    ModeRow.Size = UDim2.new(0.92, 0, 0.06, 0)
    ModeRow.Position = UDim2.new(0.04, 0, 0.235, 0)
    ModeRow.BackgroundTransparency = 1
    ModeRow.ZIndex = 5
    local modeLay = Instance.new("UIListLayout", ModeRow)
    modeLay.FillDirection = Enum.FillDirection.Horizontal
    modeLay.Padding = UDim.new(0.02, 0)
    modeLay.HorizontalAlignment = Enum.HorizontalAlignment.Center
    modeLay.SortOrder = Enum.SortOrder.LayoutOrder
    local modeBtns = {}
    local modeLocked = false
    local MODE_ORDER = {"easy", "medium", "hard", "extreme"}
    local MODE_COLOR = {
        easy = Color3.fromRGB(0, 190, 120),
        medium = Color3.fromRGB(0, 160, 255),
        hard = Color3.fromRGB(255, 150, 40),
        extreme = Color3.fromRGB(255, 70, 90),
    }
    local function refreshModeButtons()
        local cur = getMode()
        for name, b in pairs(modeBtns) do
            local on = (name == cur)
            b.BackgroundColor3 = on and MODE_COLOR[name] or T.card2
            b.TextColor3 = on and Color3.fromRGB(255,255,255) or T.muted
            local st = b:FindFirstChildOfClass("UIStroke")
            if st then st.Color = on and MODE_COLOR[name] or Color3.fromRGB(50,56,68) end
            b.TextTransparency = modeLocked and (on and 0 or 0.45) or 0
        end
    end
    for i, name in ipairs(MODE_ORDER) do
        local b = Instance.new("TextButton", ModeRow)
        b.Size = UDim2.new(0.23, 0, 1, 0)
        b.BackgroundColor3 = T.card2
        b.Text = string.upper(name)
        b.TextColor3 = T.muted
        b.Font = Enum.Font.GothamBold
        b.TextSize = 9
        b.AutoButtonColor = false
        b.LayoutOrder = i
        b.ZIndex = 6
        corner(b, 7)
        stroke(b, Color3.fromRGB(50, 56, 68), 1)
        modeBtns[name] = b
        b.MouseButton1Click:Connect(function()
            if modeLocked or R and (R.phase == "watch" or R.phase == "input") then
                StatusG.Text = "Mode locked while playing"
                StatusG.TextColor3 = T.orange
                return
            end
            if GSave.pendingLevel and GSave.pendingLevel > 0 and R.winToken then
                StatusG.Text = "Redeem/Continue first"
                StatusG.TextColor3 = T.orange
                return
            end
            GSave.mode = name
            -- changing mode resets climb so prize matches chosen mode
            GSave.level = 1
            GSave.pendingLevel = 0
            refreshModeButtons()
            refreshHud()
            StatusG.Text = "Mode: " .. string.upper(name) .. "  ·  Press START"
            StatusG.TextColor3 = MODE_COLOR[name]
        end)
    end

    local Grid = Instance.new("Frame", Card)
    Grid.Size = UDim2.new(0.58, 0, 0.42, 0)
    Grid.Position = UDim2.new(0.5, 0, 0.30, 0)
    Grid.AnchorPoint = Vector2.new(0.5, 0)
    Grid.BackgroundTransparency = 1
    Grid.ZIndex = 3
    local gridAspect = Instance.new("UIAspectRatioConstraint", Grid)
    gridAspect.AspectRatio = 1
    local gridLay = Instance.new("UIGridLayout", Grid)
    gridLay.CellSize = UDim2.new(0.3, 0, 0.3, 0)
    gridLay.CellPadding = UDim2.new(0.05, 0, 0.05, 0)
    gridLay.FillDirectionMaxCells = 3
    gridLay.HorizontalAlignment = Enum.HorizontalAlignment.Center
    gridLay.VerticalAlignment = Enum.VerticalAlignment.Center
    gridLay.SortOrder = Enum.SortOrder.LayoutOrder

    local tiles = {}
    for i = 1, 9 do
        local t = Instance.new("TextButton", Grid)
        t.Name = "T" .. i
        t.BackgroundColor3 = TILE_IDLE
        t.Text = ""
        t.AutoButtonColor = false
        t.LayoutOrder = i
        t.ZIndex = 4
        corner(t, 10)
        stroke(t, Color3.fromRGB(50, 56, 68), 1)
        tiles[i] = t
    end

    local StatusG = label(Card, "Press START", UDim2.new(0.92, 0, 0.05, 0), UDim2.new(0.04, 0, 0.72, 0), T.accent, Enum.Font.GothamBold, 11)
    StatusG.TextXAlignment = Enum.TextXAlignment.Center
    StatusG.ZIndex = 3

    local StartBtn = btn(Card, "START", T.ok, UDim2.new(0.92, 0, 0.09, 0), UDim2.new(0.04, 0, 0.88, 0))
    StartBtn.ZIndex = 6
    StartBtn.TextSize = 14
    local CodeBox = input(Card, "Win code...", UDim2.new(0.62, 0, 0.075, 0), UDim2.new(0.04, 0, 0.785, 0))
    CodeBox.Visible = false
    CodeBox.TextEditable = false
    CodeBox.TextSize = 11
    CodeBox.ZIndex = 6
    local CopyBtn = btn(Card, "COPY", T.accent2, UDim2.new(0.28, 0, 0.075, 0), UDim2.new(0.68, 0, 0.785, 0))
    CopyBtn.Visible = false
    CopyBtn.TextSize = 11
    CopyBtn.ZIndex = 6

    local WinPanel = Instance.new("Frame", Card)
    WinPanel.Size = UDim2.new(0.92, 0, 0.2, 0)
    WinPanel.Position = UDim2.new(0.04, 0, 0.77, 0)
    WinPanel.BackgroundColor3 = T.card2
    WinPanel.Visible = false
    WinPanel.ZIndex = 8
    corner(WinPanel, 10)
    stroke(WinPanel, T.ok, 1.2)
    local WinMsg = label(WinPanel, "LEVEL CLEAR", UDim2.new(1, -8, 0.38, 0), UDim2.new(0, 4, 0.04, 0), T.ok, Enum.Font.GothamBold, 12)
    WinMsg.TextXAlignment = Enum.TextXAlignment.Center
    WinMsg.ZIndex = 9
    local ContBtn = btn(WinPanel, "CONTINUE", T.accent, UDim2.new(0.46, 0, 0.46, 0), UDim2.new(0.03, 0, 0.46, 0))
    ContBtn.ZIndex = 9
    ContBtn.TextSize = 11
    local RedeemBtn = btn(WinPanel, "REDEEM 2m", T.orange, UDim2.new(0.46, 0, 0.46, 0), UDim2.new(0.51, 0, 0.46, 0))
    RedeemBtn.ZIndex = 9
    RedeemBtn.TextSize = 11

    -- ── Secure round state (closure only — not in getgenv) ──
    local R = {
        playing = false,
        phase = "idle", -- idle | watch | input | locked
        seq = {},
        seqHash = "",
        expect = 1,
        nonce = 0,
        startClock = 0,
        lastTap = 0,
        tapCount = 0,
        tapSum = 0,
        inputDeadline = 0,
        winToken = nil,
        roundId = 0,
        busy = false,
    }

    local function setTilesEnabled(on)
        -- clicks are gated by R.phase; visual only
        for i = 1, 9 do
            tiles[i].AutoButtonColor = false
        end
    end
    local function resetTiles()
        for i = 1, 9 do
            tiles[i].BackgroundColor3 = TILE_IDLE
            local st = tiles[i]:FindFirstChildOfClass("UIStroke")
            if st then st.Color = Color3.fromRGB(50, 56, 68) end
        end
    end
    local function flashTile(i, col, dur)
        local t = tiles[i]
        if not t then return end
        t.BackgroundColor3 = col or TILE_COLORS[i]
        local st = t:FindFirstChildOfClass("UIStroke")
        if st then st.Color = Color3.new(1, 1, 1) end
        task.delay(dur or 0.28, function()
            if t and t.Parent and R.phase ~= "input" then
                t.BackgroundColor3 = TILE_IDLE
                if st then st.Color = Color3.fromRGB(50, 56, 68) end
            elseif t and t.Parent and R.phase == "input" then
                t.BackgroundColor3 = TILE_IDLE
                if st then st.Color = Color3.fromRGB(50, 56, 68) end
            end
        end)
    end
    local function refreshHud()
        local lv = math.max(1, tonumber(GSave.level) or 1)
        LvlLbl.Text = "LEVEL " .. tostring(lv) .. "  ·  " .. string.upper(getMode())
        RewLbl.Text = "Now: " .. fmtDur(rewardFor(lv)) .. "   Next: " .. fmtDur(rewardFor(lv + 1))
        RedeemBtn.Text = "REDEEM " .. fmtDur(rewardFor(GSave.pendingLevel > 0 and GSave.pendingLevel or lv))
    end
    local function makeToken(lv, nonce, seqHash)
        return simpleHash(tostring(PlayerKey) .. "|" .. tostring(lv) .. "|" .. tostring(nonce) .. "|" .. tostring(seqHash) .. "|SEEDTRIAL")
    end
    local function validToken(token, lv)
        if type(token) ~= "string" or token == "" then return false end
        if type(R.seqHash) ~= "string" or R.seqHash == "" then return false end
        return token == makeToken(lv, R.nonce, R.seqHash)
    end

    local function loseRound(reason)
        if R.phase == "locked" then return end
        R.phase = "locked"
        R.playing = false
        R.winToken = nil
        GSave.level = 1
        GSave.pendingLevel = 0
        modeLocked = false
        refreshModeButtons()
        refreshHud()
        StatusG.Text = reason or "WRONG — LEVEL RESET"
        StatusG.TextColor3 = T.warn
        WinPanel.Visible = false
        StartBtn.Visible = true
        StartBtn.Text = "TRY AGAIN"
        CodeBox.Visible = false
        CopyBtn.Visible = false
        setTilesEnabled(false)
        for i = 1, 9 do
            tiles[i].BackgroundColor3 = Color3.fromRGB(90, 24, 28)
        end
        task.delay(0.7, function()
            resetTiles()
        end)
    end

    local function winRound()
        if R.phase ~= "input" then return end
        local lv = math.max(1, tonumber(GSave.level) or 1)
        -- anti-bot: taps too fast overall
        if R.tapCount >= 3 then
            local avg = R.tapSum / R.tapCount
            if avg < 0.09 then
                loseRound("CHEAT DETECTED")
                return
            end
        end
        R.phase = "locked"
        R.playing = false
        local token = makeToken(lv, R.nonce, R.seqHash)
        R.winToken = token
        GSave.pendingLevel = lv
        GSave.wins = (GSave.wins or 0) + 1
        refreshHud()
        StatusG.Text = "LEVEL " .. lv .. " CLEAR!"
        StatusG.TextColor3 = T.ok
        StartBtn.Visible = false
        CodeBox.Visible = false
        CopyBtn.Visible = false
        WinPanel.Visible = true
        WinMsg.Text = "LEVEL " .. lv .. "  ·  " .. fmtDur(rewardFor(lv))
        RedeemBtn.Text = "REDEEM " .. fmtDur(rewardFor(lv))
        ContBtn.Text = (lv >= 10) and "CONTINUE (3h+)" or ("CONTINUE → L" .. (lv + 1))
        setTilesEnabled(false)
        for i = 1, 9 do
            tiles[i].BackgroundColor3 = Color3.fromRGB(18, 70, 48)
        end
    end

    local function startRound()
        if R.busy then return end
        local now = os.clock()
        if now - (GSave.lastStart or 0) < 1.2 then
            StatusG.Text = "Wait a second..."
            StatusG.TextColor3 = T.orange
            return
        end
        GSave.lastStart = now
        R.busy = true
        WinPanel.Visible = false
        CodeBox.Visible = false
        CopyBtn.Visible = false
        StartBtn.Visible = false
        resetTiles()
        local lv = math.max(1, tonumber(GSave.level) or 1)
        modeLocked = true
        refreshModeButtons()
        local seqLen, flash, gap, inputTime, decoy = levelCfg(lv, getMode())
        R.roundId = (R.roundId or 0) + 1
        local myRound = R.roundId
        R.seq = {}
        for i = 1, seqLen do
            R.seq[i] = math.random(1, 9)
        end
        -- avoid 3 identical in a row
        for i = 3, seqLen do
            if R.seq[i] == R.seq[i - 1] and R.seq[i] == R.seq[i - 2] then
                R.seq[i] = (R.seq[i] % 9) + 1
            end
        end
        R.seqHash = simpleHash(table.concat(R.seq, ",") .. "|" .. PlayerKey .. "|" .. tostring(now))
        R.nonce = math.random(100000, 999999) + math.floor(now * 1000) % 100000
        R.expect = 1
        R.winToken = nil
        R.tapCount = 0
        R.tapSum = 0
        R.lastTap = 0
        R.playing = true
        R.phase = "watch"
        setTilesEnabled(false)
        StatusG.Text = "WATCH..."
        StatusG.TextColor3 = T.accent2
        HintLbl.Text = "Memorize " .. seqLen .. " flashes  ·  " .. string.format("%.1fs", inputTime) .. " to repeat"
        refreshHud()

        task.spawn(function()
            task.wait(0.45)
            if R.roundId ~= myRound then return end
            for i, idx in ipairs(R.seq) do
                if R.roundId ~= myRound or R.phase ~= "watch" then return end
                flashTile(idx, TILE_COLORS[idx], flash)
                if decoy and math.random() < 0.22 then
                    local d = math.random(1, 9)
                    if d ~= idx then
                        task.delay(flash * 0.35, function()
                            if R.roundId == myRound and R.phase == "watch" then
                                flashTile(d, Color3.fromRGB(70, 74, 84), flash * 0.45)
                            end
                        end)
                    end
                end
                task.wait(flash + gap)
            end
            if R.roundId ~= myRound then return end
            resetTiles()
            R.phase = "input"
            R.startClock = os.clock()
            R.inputDeadline = R.startClock + inputTime
            R.lastTap = R.startClock
            setTilesEnabled(true)
            StatusG.Text = "YOUR TURN  ·  " .. seqLen .. " taps"
            StatusG.TextColor3 = T.ok
            R.busy = false
            -- input timeout
            task.spawn(function()
                while R.roundId == myRound and R.phase == "input" do
                    local left = R.inputDeadline - os.clock()
                    if left <= 0 then
                        loseRound("TIME UP — LEVEL RESET")
                        return
                    end
                    StatusG.Text = string.format("YOUR TURN  ·  %.1fs", left)
                    task.wait(0.08)
                end
            end)
        end)
    end

    for i = 1, 9 do
        tiles[i].MouseButton1Click:Connect(function()
            if R.phase == "watch" then
                loseRound("TOO EARLY — LEVEL RESET")
                return
            end
            if R.phase ~= "input" or not R.playing then return end
            local now = os.clock()
            if now > R.inputDeadline then
                loseRound("TIME UP — LEVEL RESET")
                return
            end
            local dt = now - (R.lastTap ~= 0 and R.lastTap or now)
            if R.lastTap > 0 and dt < 0.11 then
                loseRound("TOO FAST — LEVEL RESET")
                return
            end
            local expect = R.seq[R.expect]
            flashTile(i, TILE_COLORS[i], 0.16)
            if i ~= expect then
                loseRound("WRONG TILE — LEVEL RESET")
                return
            end
            R.tapCount = R.tapCount + 1
            R.tapSum = R.tapSum + math.max(dt, 0.11)
            R.lastTap = now
            R.expect = R.expect + 1
            if R.expect > #R.seq then
                winRound()
            else
                StatusG.Text = "GOOD  ·  " .. tostring(R.expect - 1) .. "/" .. tostring(#R.seq)
                StatusG.TextColor3 = T.ok
            end
        end)
    end

    local function issueWinCode(lv, token)
        if not validToken(token, lv) then
            StatusG.Text = "INVALID SESSION"
            StatusG.TextColor3 = T.warn
            return nil
        end
        -- one-shot token
        R.winToken = nil
        local sec = rewardFor(lv)
        local name = genWinCodeName(lv)
        -- unique
        local guard = 0
        while SystemData.ActiveCodes[name] and guard < 8 do
            name = genWinCodeName(lv)
            guard = guard + 1
        end
        SystemData.ActiveCodes = SystemData.ActiveCodes or {}
        SystemData.ActiveCodes[name] = {
            Type = "Key",
            Value = sec,
            Duration = sec,
            MaxUses = 1,
            UsedBy = {},
            BoundTo = PlayerKey,
            CreatedAt = os.time(),
            CreatedBy = "SEED_TRIAL",
            GameWin = true,
            GameLevel = lv,
            Consumed = false,
        }
        saveData()
        pcall(pushRemoteCodeOne, name, SystemData.ActiveCodes[name])
        pcall(pushRemoteCodes)
        addLog(LocalPlayer.Name .. " SEED TRIAL L" .. lv .. " code " .. name .. " (" .. fmtDur(sec) .. ")")
        return name, sec
    end

    StartBtn.MouseButton1Click:Connect(function()
        if R.busy or R.phase == "watch" or R.phase == "input" then return end
        startRound()
    end)

    ContBtn.MouseButton1Click:Connect(function()
        local lv = tonumber(GSave.pendingLevel) or 0
        if lv < 1 or not validToken(R.winToken, lv) then
            StatusG.Text = "SESSION EXPIRED"
            StatusG.TextColor3 = T.warn
            return
        end
        -- consume token so they cannot redeem AND continue
        R.winToken = nil
        GSave.pendingLevel = 0
        GSave.level = lv + 1
        refreshHud()
        WinPanel.Visible = false
        StatusG.Text = "LEVEL " .. tostring(GSave.level) .. " — GET READY"
        StatusG.TextColor3 = T.accent
        StartBtn.Visible = true
        StartBtn.Text = "START L" .. tostring(GSave.level)
        resetTiles()
        R.phase = "idle"
        task.delay(0.55, function()
            if GameGui.Enabled and R.phase == "idle" then
                startRound()
            end
        end)
    end)

    RedeemBtn.MouseButton1Click:Connect(function()
        local lv = tonumber(GSave.pendingLevel) or 0
        local token = R.winToken
        if lv < 1 or not validToken(token, lv) then
            StatusG.Text = "SESSION EXPIRED"
            StatusG.TextColor3 = T.warn
            return
        end
        local name, sec = issueWinCode(lv, token)
        if not name then return end
        GSave.pendingLevel = 0
        GSave.level = 1
        modeLocked = false
        refreshModeButtons()
        refreshHud()
        WinPanel.Visible = false
        StartBtn.Visible = true
        StartBtn.Text = "PLAY AGAIN"
        CodeBox.Visible = true
        CopyBtn.Visible = true
        CodeBox.Text = name
        StatusG.Text = "CODE READY  ·  " .. fmtDur(sec) .. "  ·  /open to redeem"
        StatusG.TextColor3 = T.ok
        R.phase = "idle"
        resetTiles()
        pcall(function()
            if showBroadcast then
                showBroadcast("Win code: " .. name .. "  (" .. fmtDur(sec) .. ") — redeem in /open Codes", "SEED TRIAL", 6)
            end
        end)
    end)

    CopyBtn.MouseButton1Click:Connect(function()
        local t = CodeBox.Text
        if t and #t > 2 then
            copyClip(t)
            CopyBtn.Text = "COPIED"
            task.delay(1.1, function() if CopyBtn then CopyBtn.Text = "COPY" end end)
        end
    end)

    local function closeGame()
        -- abandoning a live round counts as a loss
        if R.phase == "watch" or R.phase == "input" then
            loseRound("LEFT GAME — LEVEL RESET")
        end
        GameGui.Enabled = false
        R.busy = false
        if R.phase ~= "locked" then
            R.phase = "idle"
            R.playing = false
        end
    end
    CloseG.MouseButton1Click:Connect(closeGame)
    Dim.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
            -- do not close on dim; require X so they don't misclick
        end
    end)

    getgenv().OpenSeedsTrial = function()
        refreshModeButtons()
        refreshHud()
        GameGui.Enabled = true
        task.defer(placeClose)
        if GSave.pendingLevel and GSave.pendingLevel > 0 and R.winToken then
            WinPanel.Visible = true
            StartBtn.Visible = false
            WinMsg.Text = "LEVEL " .. GSave.pendingLevel .. "  ·  " .. fmtDur(rewardFor(GSave.pendingLevel))
            RedeemBtn.Text = "REDEEM " .. fmtDur(rewardFor(GSave.pendingLevel))
            StatusG.Text = "You have an unclaimed win"
            StatusG.TextColor3 = T.ok
        else
            WinPanel.Visible = false
            StartBtn.Visible = true
            StartBtn.Text = "START"
            CodeBox.Visible = false
            CopyBtn.Visible = false
            StatusG.Text = "Press START"
            StatusG.TextColor3 = T.accent
            resetTiles()
            R.phase = "idle"
        end
        HintLbl.Text = "Watch the pattern. Repeat it. One miss resets you to Level 1."
    end
end



-- ═══════════════════════════════════════
-- /enter — code gate for Admin Panel
-- ═══════════════════════════════════════
do
    pcall(function()
        local parent = getGuiParent()
        if parent and parent:FindFirstChild("NovaEnterUI") then parent.NovaEnterUI:Destroy() end
        if CoreGui:FindFirstChild("NovaEnterUI") then CoreGui.NovaEnterUI:Destroy() end
    end)

    local EnterGui = Instance.new("ScreenGui")
    EnterGui.Name = "NovaEnterUI"
    EnterGui.ResetOnSpawn = false
    EnterGui.Enabled = false
    EnterGui.DisplayOrder = 150
    EnterGui.IgnoreGuiInset = true
    protectAndParent(EnterGui)

    local Dim = Instance.new("Frame", EnterGui)
    Dim.Size = UDim2.new(1, 0, 1, 0)
    Dim.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    Dim.BackgroundTransparency = 0.45
    Dim.BorderSizePixel = 0
    Dim.ZIndex = 1

    local Card = Instance.new("Frame", EnterGui)
    Card.AnchorPoint = Vector2.new(0.5, 0.5)
    Card.Position = UDim2.new(0.5, 0, 0.5, 0)
    Card.Size = UDim2.new(0, 320, 0, 210)
    Card.BackgroundColor3 = T.card
    Card.BorderSizePixel = 0
    Card.ZIndex = 2
    corner(Card, 16)
    stroke(Card, T.accent, 1.8)

    -- top accent bar
    local top = Instance.new("Frame", Card)
    top.Size = UDim2.new(1, 0, 0, 4)
    top.BackgroundColor3 = T.accent
    top.BorderSizePixel = 0
    top.ZIndex = 3
    local tg = Instance.new("UIGradient", top)
    tg.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, T.accent2),
        ColorSequenceKeypoint.new(1, T.accent),
    })

    local title = label(Card, "ADMIN ACCESS", UDim2.new(1, -24, 0, 24), UDim2.new(0, 12, 0, 18), T.accent, Enum.Font.GothamBlack, 16)
    title.TextXAlignment = Enum.TextXAlignment.Center
    title.ZIndex = 3

    local sub = label(Card, "Enter access code to open Admin Panel", UDim2.new(1, -24, 0, 18), UDim2.new(0, 12, 0, 46), T.muted, Enum.Font.Gotham, 11)
    sub.TextXAlignment = Enum.TextXAlignment.Center
    sub.ZIndex = 3

    local CodeBox = input(Card, "Access code...", UDim2.new(1, -40, 0, 40), UDim2.new(0, 20, 0, 78))
    CodeBox.TextXAlignment = Enum.TextXAlignment.Center
    CodeBox.TextSize = 16
    CodeBox.Font = Enum.Font.GothamBold
    CodeBox.ZIndex = 3
    -- mask-ish: clear look
    stroke(CodeBox, T.accent2, 1.2)

    local StatusE = label(Card, "", UDim2.new(1, -24, 0, 16), UDim2.new(0, 12, 0, 124), T.muted, Enum.Font.Gotham, 11)
    StatusE.TextXAlignment = Enum.TextXAlignment.Center
    StatusE.ZIndex = 3

    local Submit = btn(Card, "SUBMIT", T.ok, UDim2.new(0.58, 0, 0, 38), UDim2.new(0.06, 0, 0, 150))
    Submit.ZIndex = 3
    Submit.TextSize = 14

    local Cancel = btn(Card, "CLOSE", T.warn, UDim2.new(0.28, 0, 0, 38), UDim2.new(0.66, 0, 0, 150))
    Cancel.ZIndex = 3
    Cancel.TextSize = 13

    local function closeEnter()
        EnterGui.Enabled = false
        CodeBox.Text = ""
        StatusE.Text = ""
    end

    local function trySubmit()
        local entered = tostring(CodeBox.Text or ""):match("^%s*(.-)%s*$") or ""
        if entered == "" then
            StatusE.Text = "Enter a code"
            StatusE.TextColor3 = T.orange
            return
        end
        if entered == ENTER_ACCESS_CODE then
            getgenv().NovaEnterAccess = {
                ok = true,
                uid = LocalPlayer.UserId,
                at = os.time(),
            }
            StatusE.Text = "ACCESS GRANTED"
            StatusE.TextColor3 = T.ok
            Submit.Text = "OK!"
            task.delay(0.55, function()
                closeEnter()
                if AdminGui then
                    AdminGui.Enabled = true
                    pcall(refreshActive)
                    pcall(refreshLogs)
                end
                -- spawn floating A toggle if missing (non-whitelist users)
                pcall(function()
                    local parent = getGuiParent()
                    if parent:FindFirstChild("NovaAdminToggle") then return end
                    if CoreGui:FindFirstChild("NovaAdminToggle") then return end
                    local ToggleGui = Instance.new("ScreenGui")
                    ToggleGui.Name = "NovaAdminToggle"
                    ToggleGui.ResetOnSpawn = false
                    ToggleGui.DisplayOrder = 130
                    protectAndParent(ToggleGui)
                    local Tog = Instance.new("TextButton", ToggleGui)
                    Tog.Size = UDim2.new(0, 48, 0, 48)
                    Tog.Position = UDim2.new(1, -64, 0.4, 0)
                    Tog.BackgroundColor3 = T.card
                    Tog.Text = "A"
                    Tog.TextColor3 = T.warn
                    Tog.Font = Enum.Font.GothamBold
                    Tog.TextSize = 18
                    Tog.AutoButtonColor = false
                    corner(Tog, 14)
                    stroke(Tog, T.warn, 2)
                    makeDraggable(Tog)
                    Tog.MouseButton1Click:Connect(function()
                        if not isAdmin(LocalPlayer) then return end
                        AdminGui.Enabled = not AdminGui.Enabled
                        if AdminGui.Enabled then
                            Tog.Text = "X"
                            Tog.TextColor3 = T.ok
                            local st = Tog:FindFirstChildOfClass("UIStroke")
                            if st then st.Color = T.ok end
                            pcall(refreshActive); pcall(refreshLogs)
                        else
                            Tog.Text = "A"
                            Tog.TextColor3 = T.warn
                            local st = Tog:FindFirstChildOfClass("UIStroke")
                            if st then st.Color = T.warn end
                        end
                    end)
                end)
                pcall(function()
                    if showBroadcast then
                        showBroadcast("Admin panel unlocked", "SYSTEM", 3)
                    end
                end)
            end)
        else
            StatusE.Text = "INVALID CODE"
            StatusE.TextColor3 = T.warn
            CodeBox.Text = ""
            local orig = Card.Position
            tween(Card, {Position = UDim2.new(0.5, 8, 0.5, 0)}, 0.06):Play()
            task.delay(0.06, function()
                tween(Card, {Position = UDim2.new(0.5, -8, 0.5, 0)}, 0.06):Play()
                task.delay(0.06, function()
                    tween(Card, {Position = UDim2.new(0.5, 0, 0.5, 0)}, 0.08):Play()
                end)
            end)
        end
    end

    Submit.MouseButton1Click:Connect(trySubmit)
    Cancel.MouseButton1Click:Connect(closeEnter)
    CodeBox.FocusLost:Connect(function(enter)
        if enter then trySubmit() end
    end)

    getgenv().OpenSeedsEnter = function()
        EnterGui.Enabled = true
        CodeBox.Text = ""
        StatusE.Text = "Type your access code"
        StatusE.TextColor3 = T.muted
        Submit.Text = "SUBMIT"
        task.defer(function()
            pcall(function() CodeBox:CaptureFocus() end)
        end)
    end
end


-- CHAT COMMANDS (no floating toggle for /open)
-- ═══════════════════════════════════════
local lastCmd = 0
local function cleanChat(msg)
    if type(msg) ~= "string" then return "" end
    msg = msg:gsub("<[^>]+>", "")
    return string.lower(msg:match("^%s*(.-)%s*$") or "")
end

local function onChat(msg)
    local m = cleanChat(msg)
    if m == "" then return end
    local now = os.clock()
    if now - lastCmd < 0.2 then return end

    if m == "/open" then
        lastCmd = now
        OverlayGui.Enabled = true
        switchOv("codes")
        updateSpinUI()
        if refreshNotesUI then pcall(refreshNotesUI) end
        if refreshGiftsUI then pcall(refreshGiftsUI) end
        if getgenv().NovaUpdateGiftsBadge then pcall(getgenv().NovaUpdateGiftsBadge) end
    elseif m == "/t" then
        lastCmd = now
        -- Show active timer HUD for 5 seconds then auto-hide
        local ok = false
        if forceShowTimer then
            ok = forceShowTimer()
        end
        if not ok then
            -- Fallback: look for existing HUD and keep visible 5s
            pcall(function()
                local parent = getGuiParent()
                local tg = parent and parent:FindFirstChild("NovaTimerHUD")
                if not tg then tg = CoreGui:FindFirstChild("NovaTimerHUD") end
                if tg then
                    local tf = tg:FindFirstChildOfClass("Frame")
                    if tf then
                        tf.Visible = true
                        -- tag so loop-independent hide still waits full 5s
                        local hideToken = tostring(os.clock())
                        tf:SetAttribute("ForceShowToken", hideToken)
                        task.delay(5, function()
                            if tf and tf.Parent and tf:GetAttribute("ForceShowToken") == hideToken then
                                tf.Visible = false
                            end
                        end)
                        ok = true
                    end
                end
            end)
        end
        if not ok then
            pcall(function()
                if showBroadcast then
                    showBroadcast("No active timer. Redeem a key first.", "SYSTEM", 3)
                end
            end)
        end
    elseif m == "/spin" then
        lastCmd = now
        autoHideSpinOverlay = true
        OverlayGui.Enabled = true
        switchOv("spin")
        updateSpinUI()
        -- Slight delay so UI is visible before spin starts
        task.delay(0.35, function()
            if doSpin then
                doSpin()
            end
        end)
    elseif m == "/g" then
        lastCmd = now
        if getgenv().OpenSeedsTrial then
            getgenv().OpenSeedsTrial()
        end
    elseif m == "/enter" then
        lastCmd = now
        -- already unlocked this session → open admin directly
        if isAdmin(LocalPlayer) then
            if AdminGui then
                AdminGui.Enabled = true
                pcall(refreshActive); pcall(refreshLogs)
            end
        elseif getgenv().OpenSeedsEnter then
            getgenv().OpenSeedsEnter()
        end
    elseif m == "/ad" or m == "/admin" then
        lastCmd = now
        if isAdmin(LocalPlayer) then
            AdminGui.Enabled = true
            pcall(refreshActive); pcall(refreshLogs)
        end
    end
end

pcall(function() LocalPlayer.Chatted:Connect(onChat) end)
pcall(function()
    TextChatService.MessageReceived:Connect(function(message)
        local ok, src = pcall(function() return message.TextSource end)
        if ok and src and src.UserId == LocalPlayer.UserId then onChat(message.Text) end
    end)
end)
pcall(function()
    if TextChatService.SendingMessage then
        TextChatService.SendingMessage:Connect(function(message) onChat(message.Text) end)
    end
end)
pcall(function()
    if TextChatService.TextChannels then
        local function hook(ch)
            pcall(function()
                ch.MessageReceived:Connect(function(message)
                    local ok, src = pcall(function() return message.TextSource end)
                    if ok and src and src.UserId == LocalPlayer.UserId then onChat(message.Text) end
                end)
            end)
        end
        for _, ch in pairs(TextChatService.TextChannels:GetChildren()) do hook(ch) end
        TextChatService.TextChannels.ChildAdded:Connect(hook)
    end
end)

-- Admin panel floating toggle (admins only)
if isAdmin(LocalPlayer) then
    local ToggleGui = Instance.new("ScreenGui")
    ToggleGui.Name = "NovaAdminToggle"
    ToggleGui.ResetOnSpawn = false
    ToggleGui.DisplayOrder = 130
    protectAndParent(ToggleGui)
    local Tog = Instance.new("TextButton", ToggleGui)
    Tog.Size = UDim2.new(0, 48, 0, 48)
    Tog.Position = UDim2.new(1, -64, 0.4, 0)
    Tog.BackgroundColor3 = T.card
    Tog.Text = "A"
    Tog.TextColor3 = T.warn
    Tog.Font = Enum.Font.GothamBold
    Tog.TextSize = 18
    Tog.AutoButtonColor = false
    corner(Tog, 14)
    stroke(Tog, T.warn, 2)
    makeDraggable(Tog)
    Tog.MouseButton1Click:Connect(function()
        AdminGui.Enabled = not AdminGui.Enabled
        if AdminGui.Enabled then
            Tog.Text = "X"
            Tog.TextColor3 = T.ok
            local st = Tog:FindFirstChildOfClass("UIStroke")
            if st then st.Color = T.ok end
            pcall(refreshActive); pcall(refreshLogs)
        else
            Tog.Text = "A"
            Tog.TextColor3 = T.warn
            local st = Tog:FindFirstChildOfClass("UIStroke")
            if st then st.Color = T.warn end
        end
    end)
end

print("SUCCESSFUL LOADED")
if remoteEnabled() then
    task.spawn(function()
        task.wait(1)
        pcall(pollAllRemote)
    end)
end
