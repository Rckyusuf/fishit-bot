-- JAGO AI - BANJIR CUAN | Fish It Alert System v3

local TextChatService = game:GetService("TextChatService")
local StarterGui      = game:GetService("StarterGui")
local HttpService     = game:GetService("HttpService")
local TweenService    = game:GetService("TweenService")
local Players         = game:GetService("Players")
local PlayerGui       = Players.LocalPlayer:WaitForChild("PlayerGui")

local WEBHOOK_URL = "WEBHOOK_URL_DISINI"
local lastSent    = 0
local COOLDOWN    = 2

-- ══════════════════════════════════════
--  DATABASE GAMBAR IKAN (load dari GitHub)
-- ══════════════════════════════════════
local FishImages = {}
local ok_db, db = pcall(function()
    return loadstring(game:HttpGet(
        "https://raw.githubusercontent.com/Rckyusuf/fishit-bot/main/fish_database.lua"
    ))()
end)
if ok_db and db then
    FishImages = db
end

-- ══════════════════════════════════════
--  FILTER STATE
-- ══════════════════════════════════════
local Filter = {
    FORGOTTEN = true,
    SECRET    = true,
    MYTHIC    = true,
    LEGENDARY = true,
    EPIC      = true,
}
local FilterGemstoneRuby = true  -- filter khusus GEMSTONE Ruby

-- ══════════════════════════════════════
--  UTILITY
-- ══════════════════════════════════════
local function StripTags(str)
    return str:gsub("<[^>]+>", "")
end

local function DetectRarity(raw)
    if string.find(raw, "rgb(0, 0, 0)",       1, true) then return "FORGOTTEN", 0x555555 end
    if string.find(raw, "rgb(24, 255, 152)",  1, true) then return "SECRET",    0x18FF98 end
    if string.find(raw, "#ff1c95",            1, true) then return "SECRET",    0xFF1C95 end
    if string.find(raw, "rgb(255, 24, 24)",     1, true) then return "MYTHIC",    0xFF0000 end
    if string.find(raw, "rgb(255, 185, 43)",  1, true) then return "LEGENDARY", 0xFFB92B end
    if string.find(raw, "rgb(179, 115, 248)", 1, true) then return "EPIC",      0xB373F8 end
    return nil, nil
end

local function ParseGeneral(text)
    local clean = StripTags(text)
    local user, fish, weight, chance =
        clean:match("%[Server%]:%s*(%S+)%s+obtained%s+a[n]?%s+(.-)%s+%(([%d%.KM]+%s*kg)%)%s+with%s+a%s+1%s+in%s+([%d%.KM]+)%s+chance")
    return user or "?", fish or "?", weight or "?", chance or "?"
end

local function SplitMutation(fishName)
    local mutation, cleanFish = fishName:match("^([A-Z][A-Z]+)%s+(.+)$")
    if mutation then return mutation, cleanFish end
    return nil, fishName
end

local function SendWebhook(rarity, color, user, fish, weight, chance)
    local mutation, cleanFish = SplitMutation(fish)

    -- Cek apakah ini GEMSTONE Ruby
    local isGemstoneRuby = (mutation == "GEMSTONE" and cleanFish:lower() == "ruby")

    -- Kirim jika: filter rarity ON, atau filter GEMSTONE Ruby ON
    if not Filter[rarity] and not (FilterGemstoneRuby and isGemstoneRuby) then return end

    local now = os.time()
    if now - lastSent < COOLDOWN then return end
    lastSent = now

    local title = mutation
        and "✨ Mutation " .. rarity .. " Terdeteksi!"
        or  "🎣 Tangkapan " .. rarity .. " Terdeteksi!"

    -- Strip "Shiny " dari nama ikan untuk lookup database
    local isShiny   = cleanFish:sub(1, 6):lower() == "shiny "
    local lookupKey = isShiny and cleanFish:sub(7) or cleanFish

    -- Ambil gambar dari database
    local imgUrl = FishImages[lookupKey]

    local embed = {
        title       = title,
        description = "_ _",  -- garis pemisah kosong di bawah judul
        color       = color,
        fields      = {
            { name = "👤 Pemain",    value = "**"..user.."**",              inline = true },
            { name = "🐟 Nama Ikan", value = "**"..cleanFish.."**",         inline = true },
            { name = "⭐ Rarity",    value = "**"..rarity.."**",            inline = true },
            { name = "⚖️ Berat",     value = "**"..weight.."**",            inline = true },
            { name = "🎲 Chance",    value = "**1 in "..chance.."**",       inline = true },
            { name = "🔬 Mutation",  value = "**"..(mutation or "-").."**", inline = true },
        },
        footer    = { text = "Jago AI • Banjir Cuan" },
        timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
    }

    -- Gambar di kanan seperti referensi
    if imgUrl then
        embed.thumbnail = { url = imgUrl }
    end

    local payload = HttpService:JSONEncode({
        username = "Banjir Cuan Bot",
        avatar_url = "https://cdn.discordapp.com/attachments/1438789446097961111/1483690995877941429/20260120_1811_Image_Generation_simple_compose_01kfdhkdvnf66vv5wdjrtntaj4.png?ex=69bb826b&is=69ba30eb&hm=3f9fc16bc4d2ca68ba95ebb7ab2766a46fd27e829f0afee66a5e6beaee5af50a&",
        embeds   = { embed }
    })

    pcall(function()
        request({
            Url     = WEBHOOK_URL,
            Method  = "POST",
            Headers = { ["Content-Type"] = "application/json" },
            Body    = payload
        })
    end)
end

-- ══════════════════════════════════════
--  MONITOR GENERAL CHAT
-- ══════════════════════════════════════
local channels = TextChatService:WaitForChild("TextChannels", 10)
local ok, generalCh = pcall(function()
    return channels:WaitForChild("RBXGeneral", 10)
end)
if ok and generalCh then
    generalCh.MessageReceived:Connect(function(msg)
        local rarity, color = DetectRarity(msg.Text)
        if not rarity then return end
        local user, fish, weight, chance = ParseGeneral(msg.Text)
        SendWebhook(rarity, color, user, fish, weight, chance)
    end)
end

-- ══════════════════════════════════════
--  UI PANEL
-- ══════════════════════════════════════
local isMinimized = false
local PW  = 195
local PH  = 282
local PHM = 34

local Gui = Instance.new("ScreenGui")
Gui.Name              = "BanjirCuanUI"
Gui.ResetOnSpawn      = false
Gui.IgnoreGuiInset    = true
Gui.DisplayOrder      = 200
Gui.Parent            = PlayerGui

-- Panel utama — TIDAK pakai ClipsDescendants agar tidak terpotong
local Panel = Instance.new("Frame")
Panel.Name             = "Panel"
Panel.Size             = UDim2.new(0, PW, 0, PH)
Panel.Position         = UDim2.new(0, 12, 0.5, -(PH / 2))
Panel.BackgroundColor3 = Color3.fromRGB(10, 10, 18)
Panel.BorderSizePixel  = 0
Panel.Active           = true
Panel.Draggable        = true
Panel.Parent           = Gui
Instance.new("UICorner", Panel).CornerRadius = UDim.new(0, 8)
local PS = Instance.new("UIStroke", Panel)
PS.Color     = Color3.fromRGB(60, 55, 85)
PS.Thickness = 1

-- ── Header ──
local Header = Instance.new("Frame", Panel)
Header.Name             = "Header"
Header.Size             = UDim2.new(1, 0, 0, PHM)
Header.Position         = UDim2.new(0, 0, 0, 0)
Header.BackgroundColor3 = Color3.fromRGB(20, 18, 32)
Header.BorderSizePixel  = 0
Instance.new("UICorner", Header).CornerRadius = UDim.new(0, 8)

-- Fix sudut bawah header
local HFix = Instance.new("Frame", Header)
HFix.Size             = UDim2.new(1, 0, 0.5, 0)
HFix.Position         = UDim2.new(0, 0, 0.5, 0)
HFix.BackgroundColor3 = Color3.fromRGB(20, 18, 32)
HFix.BorderSizePixel  = 0

local HGrad = Instance.new("UIGradient", Header)
HGrad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0,   Color3.fromRGB(255, 195, 0)),
    ColorSequenceKeypoint.new(0.45, Color3.fromRGB(180, 100, 0)),
    ColorSequenceKeypoint.new(1,   Color3.fromRGB(20, 18, 32)),
})
HGrad.Rotation     = 90
HGrad.Transparency = NumberSequence.new({
    NumberSequenceKeypoint.new(0,   0.55),
    NumberSequenceKeypoint.new(0.4, 0.8),
    NumberSequenceKeypoint.new(1,   1),
})

local TitleLbl = Instance.new("TextLabel", Header)
TitleLbl.Size                  = UDim2.new(1, -40, 1, 0)
TitleLbl.Position              = UDim2.new(0, 10, 0, 0)
TitleLbl.BackgroundTransparency = 1
TitleLbl.Text                  = "🪙 Banjir Cuan"
TitleLbl.TextColor3            = Color3.fromRGB(255, 210, 50)
TitleLbl.TextSize              = 13
TitleLbl.Font                  = Enum.Font.GothamBold
TitleLbl.TextXAlignment        = Enum.TextXAlignment.Left
TitleLbl.ZIndex                = 2

local MinBtn = Instance.new("TextButton", Header)
MinBtn.Size             = UDim2.new(0, 22, 0, 22)
MinBtn.Position         = UDim2.new(1, -28, 0.5, -11)
MinBtn.BackgroundColor3 = Color3.fromRGB(35, 32, 50)
MinBtn.BorderSizePixel  = 0
MinBtn.Text             = "—"
MinBtn.TextColor3       = Color3.fromRGB(160, 155, 185)
MinBtn.TextSize         = 11
MinBtn.Font             = Enum.Font.GothamBold
MinBtn.AutoButtonColor  = false
MinBtn.ZIndex           = 3
Instance.new("UICorner", MinBtn).CornerRadius = UDim.new(1, 0)

-- ── Content ──
local Content = Instance.new("Frame", Panel)
Content.Name             = "Content"
Content.Size             = UDim2.new(1, 0, 1, -PHM)
Content.Position         = UDim2.new(0, 0, 0, PHM)
Content.BackgroundTransparency = 1
Content.Visible          = true

-- Divider
local Div = Instance.new("Frame", Content)
Div.Size             = UDim2.new(1, -16, 0, 1)
Div.Position         = UDim2.new(0, 8, 0, 5)
Div.BackgroundColor3 = Color3.fromRGB(45, 40, 65)
Div.BorderSizePixel  = 0

-- Label filter
local FLbl = Instance.new("TextLabel", Content)
FLbl.Size             = UDim2.new(1, -16, 0, 16)
FLbl.Position         = UDim2.new(0, 8, 0, 12)
FLbl.BackgroundTransparency = 1
FLbl.Text             = "FILTER RARITY"
FLbl.TextColor3       = Color3.fromRGB(90, 85, 115)
FLbl.TextSize         = 10
FLbl.Font             = Enum.Font.GothamBold
FLbl.TextXAlignment   = Enum.TextXAlignment.Left

-- ── Toggle Buttons ──
local rarities = {
    { name = "FORGOTTEN", color = Color3.fromRGB(120, 115, 140), label = "⬛  Forgotten" },
    { name = "SECRET",    color = Color3.fromRGB(24, 220, 130),  label = "💚  Secret"    },
    { name = "MYTHIC",    color = Color3.fromRGB(255, 70, 70),   label = "🔴  Mythic"    },
    { name = "LEGENDARY", color = Color3.fromRGB(255, 185, 43),  label = "🟡  Legendary" },
    { name = "EPIC",      color = Color3.fromRGB(179, 115, 248), label = "🟣  Epic"      },
}

for i, r in ipairs(rarities) do
    local yPos = 34 + (i - 1) * 44

    local Row = Instance.new("Frame", Content)
    Row.Size             = UDim2.new(1, -16, 0, 36)
    Row.Position         = UDim2.new(0, 8, 0, yPos)
    Row.BackgroundColor3 = Color3.fromRGB(16, 14, 26)
    Row.BorderSizePixel  = 0
    Instance.new("UICorner", Row).CornerRadius = UDim.new(0, 6)

    local RS = Instance.new("UIStroke", Row)
    RS.Color        = r.color
    RS.Thickness    = 1
    RS.Transparency = 0.45

    -- Garis warna kiri
    local Accent = Instance.new("Frame", Row)
    Accent.Size             = UDim2.new(0, 3, 1, -8)
    Accent.Position         = UDim2.new(0, 4, 0, 4)
    Accent.BackgroundColor3 = r.color
    Accent.BorderSizePixel  = 0
    Instance.new("UICorner", Accent).CornerRadius = UDim.new(1, 0)

    local Lbl = Instance.new("TextLabel", Row)
    Lbl.Size             = UDim2.new(0.6, 0, 1, 0)
    Lbl.Position         = UDim2.new(0, 14, 0, 0)
    Lbl.BackgroundTransparency = 1
    Lbl.Text             = r.label
    Lbl.TextColor3       = Color3.fromRGB(200, 195, 215)
    Lbl.TextSize         = 11
    Lbl.Font             = Enum.Font.GothamSemibold
    Lbl.TextXAlignment   = Enum.TextXAlignment.Left

    local Tog = Instance.new("TextButton", Row)
    Tog.Size             = UDim2.new(0, 44, 0, 22)
    Tog.Position         = UDim2.new(1, -52, 0.5, -11)
    Tog.BackgroundColor3 = r.color
    Tog.BorderSizePixel  = 0
    Tog.Text             = "ON"
    Tog.TextColor3       = Color3.fromRGB(10, 8, 18)
    Tog.TextSize         = 10
    Tog.Font             = Enum.Font.GothamBold
    Tog.AutoButtonColor  = false
    Instance.new("UICorner", Tog).CornerRadius = UDim.new(1, 0)

    Tog.MouseButton1Click:Connect(function()
        Filter[r.name] = not Filter[r.name]
        if Filter[r.name] then
            TweenService:Create(Tog, TweenInfo.new(0.15), {BackgroundColor3 = r.color}):Play()
            Tog.Text       = "ON"
            Tog.TextColor3 = Color3.fromRGB(10, 8, 18)
            RS.Transparency = 0.45
            Accent.BackgroundColor3 = r.color
        else
            TweenService:Create(Tog, TweenInfo.new(0.15), {
                BackgroundColor3 = Color3.fromRGB(30, 28, 42)
            }):Play()
            Tog.Text       = "OFF"
            Tog.TextColor3 = Color3.fromRGB(100, 95, 120)
            RS.Transparency = 0.85
            Accent.BackgroundColor3 = Color3.fromRGB(45, 42, 60)
        end
    end)
end

-- ── GEMSTONE Ruby Special Filter ──
local gemY = 34 + #rarities * 44 + 6

local GemDiv = Instance.new("Frame", Content)
GemDiv.Size             = UDim2.new(1, -16, 0, 1)
GemDiv.Position         = UDim2.new(0, 8, 0, gemY - 4)
GemDiv.BackgroundColor3 = Color3.fromRGB(45, 40, 65)
GemDiv.BorderSizePixel  = 0

local GemRow = Instance.new("Frame", Content)
GemRow.Size             = UDim2.new(1, -16, 0, 36)
GemRow.Position         = UDim2.new(0, 8, 0, gemY + 2)
GemRow.BackgroundColor3 = Color3.fromRGB(16, 14, 26)
GemRow.BorderSizePixel  = 0
Instance.new("UICorner", GemRow).CornerRadius = UDim.new(0, 6)

local GemStroke = Instance.new("UIStroke", GemRow)
GemStroke.Color        = Color3.fromRGB(80, 220, 255)
GemStroke.Thickness    = 1
GemStroke.Transparency = 0.3

local GemAccent = Instance.new("Frame", GemRow)
GemAccent.Size             = UDim2.new(0, 3, 1, -8)
GemAccent.Position         = UDim2.new(0, 4, 0, 4)
GemAccent.BackgroundColor3 = Color3.fromRGB(80, 220, 255)
GemAccent.BorderSizePixel  = 0
Instance.new("UICorner", GemAccent).CornerRadius = UDim.new(1, 0)

local GemLbl = Instance.new("TextLabel", GemRow)
GemLbl.Size             = UDim2.new(0.6, 0, 1, 0)
GemLbl.Position         = UDim2.new(0, 14, 0, 0)
GemLbl.BackgroundTransparency = 1
GemLbl.Text             = "💎  Gemstone Ruby"
GemLbl.TextColor3       = Color3.fromRGB(200, 195, 215)
GemLbl.TextSize         = 11
GemLbl.Font             = Enum.Font.GothamSemibold
GemLbl.TextXAlignment   = Enum.TextXAlignment.Left

local GemTog = Instance.new("TextButton", GemRow)
GemTog.Size             = UDim2.new(0, 44, 0, 22)
GemTog.Position         = UDim2.new(1, -52, 0.5, -11)
GemTog.BackgroundColor3 = Color3.fromRGB(80, 220, 255)
GemTog.BorderSizePixel  = 0
GemTog.Text             = "ON"
GemTog.TextColor3       = Color3.fromRGB(10, 8, 18)
GemTog.TextSize         = 10
GemTog.Font             = Enum.Font.GothamBold
GemTog.AutoButtonColor  = false
Instance.new("UICorner", GemTog).CornerRadius = UDim.new(1, 0)

GemTog.MouseButton1Click:Connect(function()
    FilterGemstoneRuby = not FilterGemstoneRuby
    if FilterGemstoneRuby then
        TweenService:Create(GemTog, TweenInfo.new(0.15), {
            BackgroundColor3 = Color3.fromRGB(80, 220, 255)
        }):Play()
        GemTog.Text       = "ON"
        GemTog.TextColor3 = Color3.fromRGB(10, 8, 18)
        GemStroke.Transparency = 0.3
        GemAccent.BackgroundColor3 = Color3.fromRGB(80, 220, 255)
    else
        TweenService:Create(GemTog, TweenInfo.new(0.15), {
            BackgroundColor3 = Color3.fromRGB(30, 28, 42)
        }):Play()
        GemTog.Text       = "OFF"
        GemTog.TextColor3 = Color3.fromRGB(100, 95, 120)
        GemStroke.Transparency = 0.85
        GemAccent.BackgroundColor3 = Color3.fromRGB(45, 42, 60)
    end
end)

-- Update panel height to fit new row
Panel.Size = UDim2.new(0, PW, 0, PH + 46)

-- ── Minimize logic ──
MinBtn.MouseButton1Click:Connect(function()
    isMinimized = not isMinimized
    TweenService:Create(Panel, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {
        Size = UDim2.new(0, PW, 0, isMinimized and PHM or (PH + 46))
    }):Play()
    task.wait(0.05)
    Content.Visible = not isMinimized
    MinBtn.Text     = isMinimized and "▢" or "—"
end)

-- ══════════════════════════════════════
--  NOTIFIKASI AWAL (hanya sekali)
-- ══════════════════════════════════════
StarterGui:SetCore("SendNotification", {
    Title = "✅ Banjir Cuan Aktif",
    Text  = "Panel filter tersedia di kiri layar.",
    Duration = 5
})
