-- JAGO AI - BANJIR CUAN | Fish It Alert System v3

local TextChatService = game:GetService("TextChatService")
local StarterGui      = game:GetService("StarterGui")
local HttpService     = game:GetService("HttpService")
local TweenService    = game:GetService("TweenService")
local Players         = game:GetService("Players")
local PlayerGui       = Players.LocalPlayer:WaitForChild("PlayerGui")

-- ══════════════════════════════════════
--  RESPONSIVE SCALE
-- ══════════════════════════════════════
local VP    = workspace.CurrentCamera.ViewportSize
local Scale = math.clamp(math.min(VP.X, VP.Y) / 600, 0.6, 1.0)
local function S(n) return math.floor(n * Scale) end

-- ══════════════════════════════════════
--  WEBHOOK (kosong, diisi lewat UI)
-- ══════════════════════════════════════
local WEBHOOK_URL = ""
local lastSent    = 0
local COOLDOWN    = 2

-- ══════════════════════════════════════
--  DATABASE GAMBAR IKAN
-- ══════════════════════════════════════
local FishImages = {}
local function LoadDatabase()
    local ok, db = pcall(function()
        return loadstring(game:HttpGet(
            "https://raw.githubusercontent.com/Rckyusuf/fishit-bot/main/fish_database.lua"
        ))()
    end)
    if ok and db then FishImages = db end
end
LoadDatabase()

-- Auto reload setiap 10 menit
task.spawn(function()
    while task.wait(600) do LoadDatabase() end
end)

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
local FilterGemstoneRuby = true

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
    if string.find(raw, "rgb(255, 24, 24)",   1, true) then return "MYTHIC",    0xFF1818 end
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
    if WEBHOOK_URL == "" then return end
    local mutation, cleanFish = SplitMutation(fish)
    local isGemstoneRuby = (mutation == "GEMSTONE" and cleanFish:lower() == "ruby")
    if not Filter[rarity] and not (FilterGemstoneRuby and isGemstoneRuby) then return end

    local now = os.time()
    if now - lastSent < COOLDOWN then return end
    lastSent = now

    local title = mutation
        and "✨ Mutation " .. rarity .. " Terdeteksi!"
        or  "🎣 Tangkapan " .. rarity .. " Terdeteksi!"

    local isShiny   = cleanFish:sub(1, 6):lower() == "shiny "
    local lookupKey = isShiny and cleanFish:sub(7) or cleanFish
    local imgUrl    = FishImages[lookupKey]

    local embed = {
        title       = title,
        description = "_ _",
        color       = color,
        fields      = {
            { name = "👤 Player",    value = "**"..user.."**",              inline = true },
            { name = "🐟 Fish Name", value = "**"..cleanFish.."**",         inline = true },
            { name = "⭐ Rarity",    value = "**"..rarity.."**",            inline = true },
            { name = "⚖️ Weigh",     value = "**"..weight.."**",            inline = true },
            { name = "🎲 Chance",    value = "**1 in "..chance.."**",       inline = true },
            { name = "🔬 Mutation",  value = "**"..(mutation or "-").."**", inline = true },
        },
        footer    = { text = "Metaverse Infinity Store" },
        timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
    }
    if imgUrl then embed.thumbnail = { url = imgUrl } end

    local payload = HttpService:JSONEncode({
        username   = "MetaverseInfinity Assistant",
        avatar_url = "https://cdn.discordapp.com/attachments/1417502912120225902/1483757910365438143/20260120_1758_Image_Generation_simple_compose_01kfdgvazmfyhtj8x29hz580h9.png?ex=69bbc0bc&is=69ba6f3c&hm=64648ef4e7bf76a0c325483b1e9d559823aa68b412af19bb4511056d5e9f50ff&",
        embeds     = { embed }
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
--  UI SETUP
-- ══════════════════════════════════════
local isMinimized = false

-- Ukuran panel responsif
local PW  = S(210)
local PHM = S(34)  -- tinggi header (minimized)

-- Total rows: 5 rarity + 1 gemstone + 1 webhook = 7
-- Setiap row = S(44), ditambah header section & padding
local PH_FILTER  = S(34) + (5 * S(44)) + S(56)  -- filter section
local PH_WEBHOOK = S(70)                          -- webhook section
local PH = PH_FILTER + PH_WEBHOOK

local Gui = Instance.new("ScreenGui")
Gui.Name           = "BanjirCuanUI"
Gui.ResetOnSpawn   = false
Gui.IgnoreGuiInset = true
Gui.DisplayOrder   = 200
Gui.Parent         = PlayerGui

local Panel = Instance.new("Frame")
Panel.Size             = UDim2.new(0, PW, 0, PH)
Panel.Position         = UDim2.new(0, S(12), 0.5, -(PH / 2))
Panel.BackgroundColor3 = Color3.fromRGB(10, 10, 18)
Panel.BorderSizePixel  = 0
Panel.Active           = true
Panel.Draggable        = true
Panel.Parent           = Gui
Instance.new("UICorner", Panel).CornerRadius = UDim.new(0, S(8))

local PS = Instance.new("UIStroke", Panel)
PS.Color     = Color3.fromRGB(60, 55, 85)
PS.Thickness = 1

-- ── Header ──
local Header = Instance.new("Frame", Panel)
Header.Size             = UDim2.new(1, 0, 0, PHM)
Header.BackgroundColor3 = Color3.fromRGB(20, 18, 32)
Header.BorderSizePixel  = 0
Instance.new("UICorner", Header).CornerRadius = UDim.new(0, S(8))

local HFix = Instance.new("Frame", Header)
HFix.Size             = UDim2.new(1, 0, 0.5, 0)
HFix.Position         = UDim2.new(0, 0, 0.5, 0)
HFix.BackgroundColor3 = Color3.fromRGB(20, 18, 32)
HFix.BorderSizePixel  = 0

local HGrad = Instance.new("UIGradient", Header)
HGrad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0,    Color3.fromRGB(255, 195, 0)),
    ColorSequenceKeypoint.new(0.45, Color3.fromRGB(180, 100, 0)),
    ColorSequenceKeypoint.new(1,    Color3.fromRGB(20, 18, 32)),
})
HGrad.Rotation     = 90
HGrad.Transparency = NumberSequence.new({
    NumberSequenceKeypoint.new(0,   0.55),
    NumberSequenceKeypoint.new(0.4, 0.8),
    NumberSequenceKeypoint.new(1,   1),
})

local TitleLbl = Instance.new("TextLabel", Header)
TitleLbl.Size                   = UDim2.new(1, -S(40), 1, 0)
TitleLbl.Position               = UDim2.new(0, S(10), 0, 0)
TitleLbl.BackgroundTransparency = 1
TitleLbl.Text                   = "🪙 Banjir Cuan"
TitleLbl.TextColor3             = Color3.fromRGB(255, 210, 50)
TitleLbl.TextSize               = S(13)
TitleLbl.Font                   = Enum.Font.GothamBold
TitleLbl.TextXAlignment         = Enum.TextXAlignment.Left
TitleLbl.ZIndex                 = 2

local MinBtn = Instance.new("TextButton", Header)
MinBtn.Size             = UDim2.new(0, S(22), 0, S(22))
MinBtn.Position         = UDim2.new(1, -S(28), 0.5, -S(11))
MinBtn.BackgroundColor3 = Color3.fromRGB(35, 32, 50)
MinBtn.BorderSizePixel  = 0
MinBtn.Text             = "—"
MinBtn.TextColor3       = Color3.fromRGB(160, 155, 185)
MinBtn.TextSize         = S(11)
MinBtn.Font             = Enum.Font.GothamBold
MinBtn.AutoButtonColor  = false
MinBtn.ZIndex           = 3
Instance.new("UICorner", MinBtn).CornerRadius = UDim.new(1, 0)

-- ── Content ──
local Content = Instance.new("Frame", Panel)
Content.Size             = UDim2.new(1, 0, 1, -PHM)
Content.Position         = UDim2.new(0, 0, 0, PHM)
Content.BackgroundTransparency = 1
Content.Visible          = true

-- Divider atas
local Div = Instance.new("Frame", Content)
Div.Size             = UDim2.new(1, -S(16), 0, 1)
Div.Position         = UDim2.new(0, S(8), 0, S(5))
Div.BackgroundColor3 = Color3.fromRGB(45, 40, 65)
Div.BorderSizePixel  = 0

-- Label filter
local FLbl = Instance.new("TextLabel", Content)
FLbl.Size             = UDim2.new(1, -S(16), 0, S(16))
FLbl.Position         = UDim2.new(0, S(8), 0, S(12))
FLbl.BackgroundTransparency = 1
FLbl.Text             = "FILTER RARITY"
FLbl.TextColor3       = Color3.fromRGB(90, 85, 115)
FLbl.TextSize         = S(10)
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
    local yPos = S(34) + (i - 1) * S(44)

    local Row = Instance.new("Frame", Content)
    Row.Size             = UDim2.new(1, -S(16), 0, S(36))
    Row.Position         = UDim2.new(0, S(8), 0, yPos)
    Row.BackgroundColor3 = Color3.fromRGB(16, 14, 26)
    Row.BorderSizePixel  = 0
    Instance.new("UICorner", Row).CornerRadius = UDim.new(0, S(6))

    local RS = Instance.new("UIStroke", Row)
    RS.Color        = r.color
    RS.Thickness    = 1
    RS.Transparency = 0.45

    local Accent = Instance.new("Frame", Row)
    Accent.Size             = UDim2.new(0, S(3), 1, -S(8))
    Accent.Position         = UDim2.new(0, S(4), 0, S(4))
    Accent.BackgroundColor3 = r.color
    Accent.BorderSizePixel  = 0
    Instance.new("UICorner", Accent).CornerRadius = UDim.new(1, 0)

    local Lbl = Instance.new("TextLabel", Row)
    Lbl.Size             = UDim2.new(0.6, 0, 1, 0)
    Lbl.Position         = UDim2.new(0, S(14), 0, 0)
    Lbl.BackgroundTransparency = 1
    Lbl.Text             = r.label
    Lbl.TextColor3       = Color3.fromRGB(200, 195, 215)
    Lbl.TextSize         = S(11)
    Lbl.Font             = Enum.Font.GothamSemibold
    Lbl.TextXAlignment   = Enum.TextXAlignment.Left

    local Tog = Instance.new("TextButton", Row)
    Tog.Size             = UDim2.new(0, S(44), 0, S(22))
    Tog.Position         = UDim2.new(1, -S(52), 0.5, -S(11))
    Tog.BackgroundColor3 = r.color
    Tog.BorderSizePixel  = 0
    Tog.Text             = "ON"
    Tog.TextColor3       = Color3.fromRGB(10, 8, 18)
    Tog.TextSize         = S(10)
    Tog.Font             = Enum.Font.GothamBold
    Tog.AutoButtonColor  = false
    Instance.new("UICorner", Tog).CornerRadius = UDim.new(1, 0)

    Tog.MouseButton1Click:Connect(function()
        Filter[r.name] = not Filter[r.name]
        if Filter[r.name] then
            TweenService:Create(Tog, TweenInfo.new(0.15), {BackgroundColor3 = r.color}):Play()
            Tog.Text        = "ON"
            Tog.TextColor3  = Color3.fromRGB(10, 8, 18)
            RS.Transparency = 0.45
            Accent.BackgroundColor3 = r.color
        else
            TweenService:Create(Tog, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(30, 28, 42)}):Play()
            Tog.Text        = "OFF"
            Tog.TextColor3  = Color3.fromRGB(100, 95, 120)
            RS.Transparency = 0.85
            Accent.BackgroundColor3 = Color3.fromRGB(45, 42, 60)
        end
    end)
end

-- ── GEMSTONE Ruby ──
local gemY = S(34) + #rarities * S(44) + S(6)

local GemDiv = Instance.new("Frame", Content)
GemDiv.Size             = UDim2.new(1, -S(16), 0, 1)
GemDiv.Position         = UDim2.new(0, S(8), 0, gemY - S(4))
GemDiv.BackgroundColor3 = Color3.fromRGB(45, 40, 65)
GemDiv.BorderSizePixel  = 0

local GemRow = Instance.new("Frame", Content)
GemRow.Size             = UDim2.new(1, -S(16), 0, S(36))
GemRow.Position         = UDim2.new(0, S(8), 0, gemY + S(2))
GemRow.BackgroundColor3 = Color3.fromRGB(16, 14, 26)
GemRow.BorderSizePixel  = 0
Instance.new("UICorner", GemRow).CornerRadius = UDim.new(0, S(6))

local GemStroke = Instance.new("UIStroke", GemRow)
GemStroke.Color        = Color3.fromRGB(80, 220, 255)
GemStroke.Thickness    = 1
GemStroke.Transparency = 0.3

local GemAccent = Instance.new("Frame", GemRow)
GemAccent.Size             = UDim2.new(0, S(3), 1, -S(8))
GemAccent.Position         = UDim2.new(0, S(4), 0, S(4))
GemAccent.BackgroundColor3 = Color3.fromRGB(80, 220, 255)
GemAccent.BorderSizePixel  = 0
Instance.new("UICorner", GemAccent).CornerRadius = UDim.new(1, 0)

local GemLbl = Instance.new("TextLabel", GemRow)
GemLbl.Size             = UDim2.new(0.6, 0, 1, 0)
GemLbl.Position         = UDim2.new(0, S(14), 0, 0)
GemLbl.BackgroundTransparency = 1
GemLbl.Text             = "💎  Gemstone Ruby"
GemLbl.TextColor3       = Color3.fromRGB(200, 195, 215)
GemLbl.TextSize         = S(11)
GemLbl.Font             = Enum.Font.GothamSemibold
GemLbl.TextXAlignment   = Enum.TextXAlignment.Left

local GemTog = Instance.new("TextButton", GemRow)
GemTog.Size             = UDim2.new(0, S(44), 0, S(22))
GemTog.Position         = UDim2.new(1, -S(52), 0.5, -S(11))
GemTog.BackgroundColor3 = Color3.fromRGB(80, 220, 255)
GemTog.BorderSizePixel  = 0
GemTog.Text             = "ON"
GemTog.TextColor3       = Color3.fromRGB(10, 8, 18)
GemTog.TextSize         = S(10)
GemTog.Font             = Enum.Font.GothamBold
GemTog.AutoButtonColor  = false
Instance.new("UICorner", GemTog).CornerRadius = UDim.new(1, 0)

GemTog.MouseButton1Click:Connect(function()
    FilterGemstoneRuby = not FilterGemstoneRuby
    if FilterGemstoneRuby then
        TweenService:Create(GemTog, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(80, 220, 255)}):Play()
        GemTog.Text        = "ON"
        GemTog.TextColor3  = Color3.fromRGB(10, 8, 18)
        GemStroke.Transparency = 0.3
        GemAccent.BackgroundColor3 = Color3.fromRGB(80, 220, 255)
    else
        TweenService:Create(GemTog, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(30, 28, 42)}):Play()
        GemTog.Text        = "OFF"
        GemTog.TextColor3  = Color3.fromRGB(100, 95, 120)
        GemStroke.Transparency = 0.85
        GemAccent.BackgroundColor3 = Color3.fromRGB(45, 42, 60)
    end
end)

-- ══════════════════════════════════════
--  WEBHOOK INPUT SECTION
-- ══════════════════════════════════════
local whY = gemY + S(46)  -- posisi Y section webhook

-- Divider webhook
local WhDiv = Instance.new("Frame", Content)
WhDiv.Size             = UDim2.new(1, -S(16), 0, 1)
WhDiv.Position         = UDim2.new(0, S(8), 0, whY - S(4))
WhDiv.BackgroundColor3 = Color3.fromRGB(45, 40, 65)
WhDiv.BorderSizePixel  = 0

-- Label webhook
local WhLbl = Instance.new("TextLabel", Content)
WhLbl.Size             = UDim2.new(1, -S(16), 0, S(16))
WhLbl.Position         = UDim2.new(0, S(8), 0, whY + S(2))
WhLbl.BackgroundTransparency = 1
WhLbl.Text             = "WEBHOOK"
WhLbl.TextColor3       = Color3.fromRGB(90, 85, 115)
WhLbl.TextSize         = S(10)
WhLbl.Font             = Enum.Font.GothamBold
WhLbl.TextXAlignment   = Enum.TextXAlignment.Left

-- Status indicator
local WhStatus = Instance.new("TextLabel", Content)
WhStatus.Size             = UDim2.new(0, S(60), 0, S(16))
WhStatus.Position         = UDim2.new(1, -S(68), 0, whY + S(2))
WhStatus.BackgroundTransparency = 1
WhStatus.Text             = "● Kosong"
WhStatus.TextColor3       = Color3.fromRGB(180, 80, 80)
WhStatus.TextSize         = S(9)
WhStatus.Font             = Enum.Font.GothamSemibold
WhStatus.TextXAlignment   = Enum.TextXAlignment.Right

-- TextBox input webhook
local WhBox = Instance.new("TextBox", Content)
WhBox.Size             = UDim2.new(1, -S(16), 0, S(28))
WhBox.Position         = UDim2.new(0, S(8), 0, whY + S(20))
WhBox.BackgroundColor3 = Color3.fromRGB(18, 16, 28)
WhBox.BorderSizePixel  = 0
WhBox.Text             = ""
WhBox.PlaceholderText  = "Paste webhook URL..."
WhBox.PlaceholderColor3 = Color3.fromRGB(70, 65, 90)
WhBox.TextColor3       = Color3.fromRGB(200, 195, 215)
WhBox.TextSize         = S(9)
WhBox.Font             = Enum.Font.Gotham
WhBox.TextXAlignment   = Enum.TextXAlignment.Left
WhBox.ClearTextOnFocus = false
WhBox.ClipsDescendants = true
Instance.new("UICorner", WhBox).CornerRadius = UDim.new(0, S(6))
Instance.new("UIStroke", WhBox).Color        = Color3.fromRGB(50, 45, 70)

local WhPad = Instance.new("UIPadding", WhBox)
WhPad.PaddingLeft  = UDim.new(0, S(6))
WhPad.PaddingRight = UDim.new(0, S(6))

-- Tombol Save webhook
local WhSave = Instance.new("TextButton", Content)
WhSave.Size             = UDim2.new(1, -S(16), 0, S(26))
WhSave.Position         = UDim2.new(0, S(8), 0, whY + S(52))
WhSave.BackgroundColor3 = Color3.fromRGB(30, 100, 60)
WhSave.BorderSizePixel  = 0
WhSave.Text             = "💾  Simpan Webhook"
WhSave.TextColor3       = Color3.fromRGB(200, 240, 215)
WhSave.TextSize         = S(11)
WhSave.Font             = Enum.Font.GothamBold
WhSave.AutoButtonColor  = false
Instance.new("UICorner", WhSave).CornerRadius = UDim.new(0, S(6))

WhSave.MouseButton1Click:Connect(function()
    local input = WhBox.Text:match("^%s*(.-)%s*$")  -- trim whitespace
    if input == "" then
        WhStatus.Text      = "● Kosong"
        WhStatus.TextColor3 = Color3.fromRGB(180, 80, 80)
        return
    end

    -- Validasi format webhook Discord
    if not string.find(input, "discord.com/api/webhooks/", 1, true) then
        WhStatus.Text      = "● Invalid"
        WhStatus.TextColor3 = Color3.fromRGB(220, 160, 40)
        return
    end

    WEBHOOK_URL = input

    -- Test kirim ke webhook
    local ok2, _ = pcall(function()
        request({
            Url     = WEBHOOK_URL,
            Method  = "POST",
            Headers = { ["Content-Type"] = "application/json" },
            Body    = HttpService:JSONEncode({
                username = "Banjir Cuan Bot",
                content  = "✅ Webhook terhubung! Banjir Cuan aktif."
            })
        })
    end)

    if ok2 then
        WhStatus.Text      = "● Aktif"
        WhStatus.TextColor3 = Color3.fromRGB(60, 220, 120)
        TweenService:Create(WhSave, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(20, 130, 70)}):Play()
    else
        WhStatus.Text      = "● Gagal"
        WhStatus.TextColor3 = Color3.fromRGB(220, 80, 80)
    end
end)

-- ── Minimize ──
MinBtn.MouseButton1Click:Connect(function()
    isMinimized = not isMinimized
    TweenService:Create(Panel, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {
        Size = UDim2.new(0, PW, 0, isMinimized and PHM or PH)
    }):Play()
    task.wait(0.05)
    Content.Visible = not isMinimized
    MinBtn.Text     = isMinimized and "▢" or "—"
end)

-- ══════════════════════════════════════
--  NOTIFIKASI AWAL
-- ══════════════════════════════════════
StarterGui:SetCore("SendNotification", {
    Title = "✅ Webhook Metaverse Aktiv",
    Text  = "Masukkan webhook di panel kiri.",
    Duration = 5
})
