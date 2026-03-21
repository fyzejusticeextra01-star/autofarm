-- ══════════════════════════════════════════════
--  BF Hub | Rayfield | Delta | All Seas
--  v4 — Fast attack, fixed TP, fixed farm loops
-- ══════════════════════════════════════════════

local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local VIM               = game:GetService("VirtualInputManager")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer       = Players.LocalPlayer

-- ══════════════════════════════════════════════
--  RAYFIELD LOAD
-- ══════════════════════════════════════════════
local Rayfield
pcall(function()
    Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()
end)
if not Rayfield then
    local s = function() end
    local t = {CreateToggle=s,CreateSlider=s,CreateButton=s,
               CreateDropdown=s,CreateLabel=s,CreateSection=s}
    Rayfield = {
        CreateWindow = function()
            return setmetatable({},{__index=function() return function() return t end end})
        end,
        Notify = s
    }
end

-- ══════════════════════════════════════════════
--  CORE HELPERS
-- ══════════════════════════════════════════════
local function GetChar() return LocalPlayer.Character end
local function GetHRP()
    local c = GetChar(); return c and c:FindFirstChild("HumanoidRootPart")
end
local function GetHum()
    local c = GetChar(); return c and c:FindFirstChildOfClass("Humanoid")
end
local function NoCollide()
    local c = GetChar(); if not c then return end
    for _, p in ipairs(c:GetDescendants()) do
        if p:IsA("BasePart") then p.CanCollide = false end
    end
end

-- ══════════════════════════════════════════════
--  CACHE ATTACK REMOTES ONCE (no yielding per hit)
-- ══════════════════════════════════════════════
local RegAttack, RegHit
task.spawn(function()
    local ok = pcall(function()
        local net   = ReplicatedStorage:WaitForChild("Modules", 10)
                        :WaitForChild("Net", 10)
        RegAttack   = net:WaitForChild("RE/RegisterAttack", 10)
        RegHit      = net:WaitForChild("RE/RegisterHit",    10)
    end)
    if not ok then
        -- fallback: try direct path
        pcall(function()
            RegAttack = ReplicatedStorage.Modules.Net["RE/RegisterAttack"]
            RegHit    = ReplicatedStorage.Modules.Net["RE/RegisterHit"]
        end)
    end
end)

-- ══════════════════════════════════════════════
--  STATE
-- ══════════════════════════════════════════════
local SelectWeapon  = "Melee"
local WalkSpeedVal  = 100
local WalkSpeedOn   = false
local HitboxOn      = false
local AutoHakiOn    = false
local AntiAFKOn     = false
local FruitESPOn    = false
local ESPOn         = true
local ShowName      = true
local ShowHealth    = true
local AutoAttackOn  = true
local AttackRange   = 60
local InfRange      = true

-- Farm state — every field reset explicitly on toggle
local AF = {
    Active   = false,
    Running  = false,   -- true only while task.spawn coroutine is alive
    Status   = "Idle",
}
local Mon, NameMon, NameQuest, LevelQuest, CFrameQuest, CFrameMon
local MonFarm      = ""       -- name of NPC currently being pulled
local FarmAnchor   = Vector3.new(0,0,0)  -- fixed ground point (never mutated mid-kill)
local attackTarget = nil

local World1 = game.PlaceId == 2753915549
local World2 = game.PlaceId == 4442272183
local World3 = game.PlaceId == 7449423635

-- ══════════════════════════════════════════════
--  SKY TELEPORT  (instant, glitch-free)
-- ══════════════════════════════════════════════
local EntranceZones = {
    [2753915549] = {
        {thr=1000, zone=Vector3.new(-7894.6,5547.1,-380.3),  entry=Vector3.new(-7894.6,5547.1,-380.3)},
        {thr=3000, zone=Vector3.new(61163.9,11.7,1819.8),    entry=Vector3.new(61163.9,11.7,1819.8)},
        {thr=1000, zone=Vector3.new(-4607.8,872.5,-1667.6),  entry=Vector3.new(-4607.8,872.5,-1667.6)},
    },
    [4442272183] = {
        {thr=3000, zone=Vector3.new(923.2,127.0,32852.8),    entry=Vector3.new(923.2,127.0,32852.8)},
        {thr=1000, zone=Vector3.new(-6508.6,89.0,-132.8),    entry=Vector3.new(-6508.6,89.0,-132.8)},
    },
    [7449423635] = {
        {thr=1000, zone=Vector3.new(5657.9,1013.1,-335.5),   entry=Vector3.new(5657.9,1013.1,-335.5)},
        {thr=1000, zone=Vector3.new(-5075.5,314.5,-3150.0),  entry=Vector3.new(-5075.5,314.5,-3150.0)},
    },
}

local function CheckAndEnter(destPos)
    local hrp   = GetHRP(); if not hrp then return end
    local myPos = hrp.Position
    for _, z in ipairs(EntranceZones[game.PlaceId] or {}) do
        if (destPos - z.zone).Magnitude < z.thr
        and (myPos  - z.zone).Magnitude > z.thr * 0.4 then
            pcall(function()
                ReplicatedStorage.Remotes.CommF_:InvokeServer("requestEntrance", z.entry)
            end)
            task.wait(0.7)
            return
        end
    end
end

-- SkyTP: up to Y=9999 → entrance check → land
local function SkyTP(destCF, yOffset)
    local hrp = GetHRP(); if not hrp then return end
    yOffset   = yOffset or 0
    NoCollide()
    -- 1. Jump to sky
    hrp.CFrame = CFrame.new(destCF.Position.X, 9999, destCF.Position.Z)
    task.wait(0.08)
    -- 2. Entrance portal
    CheckAndEnter(destCF.Position)
    -- 3. Land
    hrp = GetHRP(); if not hrp then return end
    NoCollide()
    hrp.CFrame = CFrame.new(
        destCF.Position.X,
        destCF.Position.Y + yOffset,
        destCF.Position.Z
    )
    task.wait(0.06)
    NoCollide()
end

-- ══════════════════════════════════════════════
--  ATTACK — fast, no cooldown, cached remotes
-- ══════════════════════════════════════════════
local function FindHits()
    local c = LocalPlayer.Character; if not c then return nil, {} end
    local origin = c:GetPivot().Position
    local range  = InfRange and 1e9 or AttackRange
    local hits, last = {}, nil
    local en = workspace:FindFirstChild("Enemies")
    if en then
        for _, e in ipairs(en:GetChildren()) do
            local hu = e:FindFirstChildOfClass("Humanoid")
            if hu and hu.Health > 0 and not e:GetAttribute("IsBoat") then
                local head = e:FindFirstChild("Head")
                if head and (origin - head.Position).Magnitude <= range then
                    table.insert(hits, {e, head})
                    last = head
                end
            end
        end
    end
    return last, hits
end

local function GetEquippedTool()
    local c = LocalPlayer.Character; if not c then return nil end
    for _, v in ipairs(c:GetChildren()) do
        if v:IsA("Tool") then return v end
    end
    return nil
end

local function AttackNoCoolDown()
    if not AutoAttackOn then return end
    if not RegAttack or not RegHit then return end
    local last, hits = FindHits()
    if not last or #hits == 0 then return end
    if not GetEquippedTool() then return end
    pcall(function() RegAttack:FireServer(1e-9) end)
    pcall(function() RegHit:FireServer(last, hits) end)
end

-- Standalone fast attack loop (runs always when AF is active)
task.spawn(function()
    while true do
        if AF.Active and AutoAttackOn then
            pcall(AttackNoCoolDown)
        end
        task.wait(0.01)   -- ~100 attacks/sec cap (server throttles but client fires fast)
    end
end)

-- ══════════════════════════════════════════════
--  MISC HELPERS
-- ══════════════════════════════════════════════
local function AutoHaki()
    pcall(function()
        local c = GetChar()
        if c and not c:FindFirstChild("HasBuso") then
            ReplicatedStorage.Remotes.CommF_:InvokeServer("Buso")
        end
    end)
end

local function GetWeaponName()
    for _, t in ipairs(LocalPlayer.Backpack:GetChildren()) do
        if t:IsA("Tool") then
            if SelectWeapon=="Melee"      and (t.ToolTip=="Melee" or t.Name=="Combat") then return t.Name end
            if SelectWeapon=="Sword"      and t.ToolTip=="Sword"       then return t.Name end
            if SelectWeapon=="Gun"        and t.ToolTip=="Gun"          then return t.Name end
            if SelectWeapon=="Blox Fruit" and t.ToolTip=="Blox Fruit"   then return t.Name end
        end
    end
end

local function EquipWeapon(name)
    if not name then return end
    local t = LocalPlayer.Backpack:FindFirstChild(name)
    if t then local h=GetHum() if h then h:EquipTool(t) end end
end

local function ApplyWalkSpeed(on)
    WalkSpeedOn = on
    pcall(function()
        local h = GetHum()
        if h then h.WalkSpeed = on and WalkSpeedVal or 16 end
    end)
end
LocalPlayer.CharacterAdded:Connect(function()
    task.wait(1)
    if WalkSpeedOn then ApplyWalkSpeed(true) end
end)

task.spawn(function()
    while true do
        if AutoHakiOn then AutoHaki() end
        task.wait(12)
    end
end)

task.spawn(function()
    while true do
        task.wait(60)
        if AntiAFKOn then
            pcall(function()
                VIM:SendKeyEvent(true,  Enum.KeyCode.W, false, game)
                task.wait(0.1)
                VIM:SendKeyEvent(false, Enum.KeyCode.W, false, game)
            end)
        end
    end
end)

-- Global hitbox expand (when HitboxOn)
RunService.Heartbeat:Connect(function()
    if not HitboxOn then return end
    pcall(function()
        local en = workspace:FindFirstChild("Enemies"); if not en then return end
        local s  = InfRange and 999 or math.max(AttackRange, 30)
        for _, e in ipairs(en:GetChildren()) do
            local hrp = e:FindFirstChild("HumanoidRootPart")
            if hrp and hrp.Size.X < s then
                hrp.Size = Vector3.new(s,s,s)
                hrp.CanCollide = false
                local head = e:FindFirstChild("Head")
                if head then head.CanCollide = false end
            end
        end
    end)
end)

-- ══════════════════════════════════════════════
--  FRUIT ESP
-- ══════════════════════════════════════════════
local FruitBBs = {}
local function MakeFruitBB(adornee, label)
    if FruitBBs[adornee] or not adornee or not adornee.Parent then return end
    local bb = Instance.new("BillboardGui")
    bb.AlwaysOnTop = true; bb.Size = UDim2.new(0,180,0,40)
    bb.StudsOffset = Vector3.new(0,6,0); bb.Adornee = adornee
    bb.Parent = game:GetService("CoreGui")
    local l = Instance.new("TextLabel", bb)
    l.BackgroundTransparency = 1; l.Size = UDim2.new(1,0,1,0)
    l.Text = "🍎 "..label; l.TextColor3 = Color3.fromRGB(255,215,0)
    l.Font = Enum.Font.GothamBold; l.TextSize = 14
    l.TextStrokeTransparency = 0.2; l.TextStrokeColor3 = Color3.new(0,0,0)
    FruitBBs[adornee] = bb
    adornee.AncestryChanged:Connect(function()
        if not adornee.Parent then
            pcall(function() bb:Destroy() end)
            FruitBBs[adornee] = nil
        end
    end)
end
local function ClearFruitBBs()
    for a, bb in pairs(FruitBBs) do
        pcall(function() bb:Destroy() end); FruitBBs[a] = nil
    end
end
local function ScanFruits()
    if not FruitESPOn then return end
    local function TryTag(obj)
        if not string.find(string.lower(obj.Name), "fruit") then return end
        local ad
        if obj:IsA("Tool")       then ad = obj:FindFirstChild("Handle") or obj.PrimaryPart
        elseif obj:IsA("Model")  then ad = obj.PrimaryPart or obj:FindFirstChildOfClass("BasePart")
        elseif obj:IsA("BasePart") then ad = obj end
        if ad then MakeFruitBB(ad, obj.Name) end
    end
    for _, o in ipairs(workspace:GetChildren()) do TryTag(o) end
    for _, f in ipairs({"Fruits","DevilFruits","DroppedFruits"}) do
        local folder = workspace:FindFirstChild(f)
        if folder then for _, o in ipairs(folder:GetChildren()) do TryTag(o) end end
    end
end
workspace.DescendantAdded:Connect(function(o)
    if FruitESPOn and o:IsA("Tool") and string.find(string.lower(o.Name),"fruit") then
        task.wait(0.1); ScanFruits()
    end
end)
task.spawn(function()
    while true do
        task.wait(3)
        if FruitESPOn then
            for a, bb in pairs(FruitBBs) do
                if not a.Parent then pcall(function() bb:Destroy() end); FruitBBs[a]=nil end
            end
            ScanFruits()
        else
            if next(FruitBBs) then ClearFruitBBs() end
        end
    end
end)

-- ══════════════════════════════════════════════
--  PLAYER ESP
-- ══════════════════════════════════════════════
local ESPObj = {}
local ESPColors = {
    NC = Color3.fromRGB(255,255,255),
    HC = Color3.fromRGB(80,255,120),
    LC = Color3.fromRGB(255,60,60),
}
local function AddESP(p)
    if p == LocalPlayer then return end
    ESPObj[p] = {}
    local function Setup()
        local ch = p.Character; if not ch then return end
        local hrp = ch:FindFirstChild("HumanoidRootPart"); if not hrp then return end
        if ESPObj[p].bb   then ESPObj[p].bb:Destroy() end
        if ESPObj[p].conn then ESPObj[p].conn:Disconnect() end
        local bb = Instance.new("BillboardGui")
        bb.AlwaysOnTop=true; bb.Size=UDim2.new(0,200,0,50)
        bb.StudsOffset=Vector3.new(0,3,0); bb.Adornee=hrp; bb.Parent=hrp
        local nl = Instance.new("TextLabel", bb)
        nl.BackgroundTransparency=1; nl.Size=UDim2.new(1,0,.5,0)
        nl.TextColor3=ESPColors.NC; nl.TextStrokeTransparency=0.5
        nl.Font=Enum.Font.GothamBold; nl.TextSize=14; nl.Text=p.Name
        local hl = Instance.new("TextLabel", bb)
        hl.BackgroundTransparency=1; hl.Size=UDim2.new(1,0,.5,0)
        hl.Position=UDim2.new(0,0,.5,0); hl.TextStrokeTransparency=0.5
        hl.Font=Enum.Font.Gotham; hl.TextSize=14
        ESPObj[p].bb = bb
        ESPObj[p].conn = RunService.RenderStepped:Connect(function()
            if not ESPOn then bb.Enabled=false; return end
            local c2 = p.Character; if not c2 then bb.Enabled=false; return end
            local h  = c2:FindFirstChild("HumanoidRootPart")
            local hu = c2:FindFirstChildOfClass("Humanoid")
            if not h or not hu then bb.Enabled=false; return end
            bb.Enabled=true; bb.Adornee=h
            nl.Visible=ShowName; nl.Text=p.Name
            hl.Visible=ShowHealth
            local hp,mx = math.floor(hu.Health), math.max(hu.MaxHealth,1)
            hl.Text = ("HP:%d/%d"):format(hp,mx)
            hl.TextColor3 = (hp/mx)>0.4 and ESPColors.HC or ESPColors.LC
        end)
    end
    if p.Character then Setup() end
    p.CharacterAdded:Connect(Setup)
end
local function RemoveESP(p)
    local d = ESPObj[p]; if not d then return end
    if d.bb   then d.bb:Destroy() end
    if d.conn then d.conn:Disconnect() end
    ESPObj[p] = nil
end
for _, p in ipairs(Players:GetPlayers()) do AddESP(p) end
Players.PlayerAdded:Connect(AddESP)
Players.PlayerRemoving:Connect(RemoveESP)

-- ══════════════════════════════════════════════
--  QUEST DATA
-- ══════════════════════════════════════════════
local function CheckQuest()
    local ok, lvl = pcall(function() return LocalPlayer.Data.Level.Value end)
    lvl = ok and lvl or 0
    if World1 then
        if     lvl<=9   then Mon="Bandit"              LevelQuest=1 NameQuest="BanditQuest1"    NameMon="Bandit"              CFrameQuest=CFrame.new(1059,15,1550)     CFrameMon=CFrame.new(1046,27,1561)
        elseif lvl<=14  then Mon="Monkey"              LevelQuest=1 NameQuest="JungleQuest"     NameMon="Monkey"              CFrameQuest=CFrame.new(-1598,35,153)     CFrameMon=CFrame.new(-1449,68,11)
        elseif lvl<=29  then Mon="Gorilla"             LevelQuest=2 NameQuest="JungleQuest"     NameMon="Gorilla"             CFrameQuest=CFrame.new(-1598,35,153)     CFrameMon=CFrame.new(-1130,40,-525)
        elseif lvl<=39  then Mon="Pirate"              LevelQuest=1 NameQuest="BuggyQuest1"     NameMon="Pirate"              CFrameQuest=CFrame.new(-1141,4,3832)     CFrameMon=CFrame.new(-1104,14,3896)
        elseif lvl<=59  then Mon="Brute"               LevelQuest=2 NameQuest="BuggyQuest1"     NameMon="Brute"               CFrameQuest=CFrame.new(-1141,4,3832)     CFrameMon=CFrame.new(-1140,15,4323)
        elseif lvl<=74  then Mon="Desert Bandit"       LevelQuest=1 NameQuest="DesertQuest"     NameMon="Desert Bandit"       CFrameQuest=CFrame.new(894,5,4392)       CFrameMon=CFrame.new(925,6,4482)
        elseif lvl<=89  then Mon="Desert Officer"      LevelQuest=2 NameQuest="DesertQuest"     NameMon="Desert Officer"      CFrameQuest=CFrame.new(894,5,4392)       CFrameMon=CFrame.new(1608,9,4371)
        elseif lvl<=99  then Mon="Snow Bandit"         LevelQuest=1 NameQuest="SnowQuest"       NameMon="Snow Bandit"         CFrameQuest=CFrame.new(1390,88,-1299)    CFrameMon=CFrame.new(1354,87,-1394)
        elseif lvl<=119 then Mon="Snowman"             LevelQuest=2 NameQuest="SnowQuest"       NameMon="Snowman"             CFrameQuest=CFrame.new(1390,88,-1299)    CFrameMon=CFrame.new(1202,145,-1550)
        elseif lvl<=149 then Mon="Chief Petty Officer" LevelQuest=1 NameQuest="MarineQuest2"    NameMon="Chief Petty Officer" CFrameQuest=CFrame.new(-5040,27,4325)    CFrameMon=CFrame.new(-4881,23,4274)
        elseif lvl<=174 then Mon="Sky Bandit"          LevelQuest=1 NameQuest="SkyQuest"        NameMon="Sky Bandit"          CFrameQuest=CFrame.new(-4840,716,-2619)  CFrameMon=CFrame.new(-4953,296,-2899)
        elseif lvl<=189 then Mon="Dark Master"         LevelQuest=2 NameQuest="SkyQuest"        NameMon="Dark Master"         CFrameQuest=CFrame.new(-4840,716,-2619)  CFrameMon=CFrame.new(-5260,391,-2229)
        elseif lvl<=209 then Mon="Prisoner"            LevelQuest=1 NameQuest="PrisonerQuest"   NameMon="Prisoner"            CFrameQuest=CFrame.new(5309,2,475)       CFrameMon=CFrame.new(5099,0,474)
        elseif lvl<=249 then Mon="Dangerous Prisoner"  LevelQuest=2 NameQuest="PrisonerQuest"   NameMon="Dangerous Prisoner"  CFrameQuest=CFrame.new(5309,2,475)       CFrameMon=CFrame.new(5655,16,866)
        elseif lvl<=274 then Mon="Toga Warrior"        LevelQuest=1 NameQuest="ColosseumQuest"  NameMon="Toga Warrior"        CFrameQuest=CFrame.new(-1580,6,-2986)    CFrameMon=CFrame.new(-1820,52,-2741)
        elseif lvl<=299 then Mon="Gladiator"           LevelQuest=2 NameQuest="ColosseumQuest"  NameMon="Gladiator"           CFrameQuest=CFrame.new(-1580,6,-2986)    CFrameMon=CFrame.new(-1293,56,-3339)
        elseif lvl<=324 then Mon="Military Soldier"    LevelQuest=1 NameQuest="MagmaQuest"      NameMon="Military Soldier"    CFrameQuest=CFrame.new(-5313,11,8515)    CFrameMon=CFrame.new(-5411,11,8454)
        elseif lvl<=374 then Mon="Military Spy"        LevelQuest=2 NameQuest="MagmaQuest"      NameMon="Military Spy"        CFrameQuest=CFrame.new(-5313,11,8515)    CFrameMon=CFrame.new(-5803,86,8829)
        elseif lvl<=399 then Mon="Fishman Warrior"     LevelQuest=1 NameQuest="FishmanQuest"    NameMon="Fishman Warrior"     CFrameQuest=CFrame.new(61123,18,1569)    CFrameMon=CFrame.new(60878,18,1544)
        elseif lvl<=449 then Mon="Fishman Commando"    LevelQuest=2 NameQuest="FishmanQuest"    NameMon="Fishman Commando"    CFrameQuest=CFrame.new(61123,18,1569)    CFrameMon=CFrame.new(61923,18,1494)
        elseif lvl<=474 then Mon="God's Guard"         LevelQuest=1 NameQuest="SkyExp1Quest"    NameMon="God's Guard"         CFrameQuest=CFrame.new(-4722,844,-1950)  CFrameMon=CFrame.new(-4710,845,-1927)
        elseif lvl<=524 then Mon="Shanda"              LevelQuest=2 NameQuest="SkyExp1Quest"    NameMon="Shanda"              CFrameQuest=CFrame.new(-7859,5544,-381)  CFrameMon=CFrame.new(-7678,5566,-497)
        elseif lvl<=549 then Mon="Royal Squad"         LevelQuest=1 NameQuest="SkyExp2Quest"    NameMon="Royal Squad"         CFrameQuest=CFrame.new(-7907,5635,-1412) CFrameMon=CFrame.new(-7624,5658,-1467)
        elseif lvl<=624 then Mon="Royal Soldier"       LevelQuest=2 NameQuest="SkyExp2Quest"    NameMon="Royal Soldier"       CFrameQuest=CFrame.new(-7907,5635,-1412) CFrameMon=CFrame.new(-7837,5646,-1791)
        elseif lvl<=649 then Mon="Galley Pirate"       LevelQuest=1 NameQuest="FountainQuest"   NameMon="Galley Pirate"       CFrameQuest=CFrame.new(5260,37,4050)     CFrameMon=CFrame.new(5551,79,3930)
        else                 Mon="Galley Captain"      LevelQuest=2 NameQuest="FountainQuest"   NameMon="Galley Captain"      CFrameQuest=CFrame.new(5260,37,4050)     CFrameMon=CFrame.new(5442,43,4950)
        end
    elseif World2 then
        if     lvl<=724  then Mon="Raider"            LevelQuest=1 NameQuest="Area1Quest"        NameMon="Raider"            CFrameQuest=CFrame.new(-430,72,1836)     CFrameMon=CFrame.new(-728,53,2346)
        elseif lvl<=774  then Mon="Mercenary"         LevelQuest=2 NameQuest="Area1Quest"        NameMon="Mercenary"         CFrameQuest=CFrame.new(-430,72,1836)     CFrameMon=CFrame.new(-1004,80,1425)
        elseif lvl<=799  then Mon="Swan Pirate"       LevelQuest=1 NameQuest="Area2Quest"        NameMon="Swan Pirate"       CFrameQuest=CFrame.new(638,72,918)       CFrameMon=CFrame.new(1069,138,1322)
        elseif lvl<=874  then Mon="Factory Staff"     LevelQuest=2 NameQuest="Area2Quest"        NameMon="Factory Staff"     CFrameQuest=CFrame.new(633,73,919)       CFrameMon=CFrame.new(73,82,-27)
        elseif lvl<=899  then Mon="Marine Lieutenant" LevelQuest=1 NameQuest="MarineQuest3"      NameMon="Marine Lieutenant" CFrameQuest=CFrame.new(-2441,72,-3216)   CFrameMon=CFrame.new(-2821,76,-3070)
        elseif lvl<=949  then Mon="Marine Captain"    LevelQuest=2 NameQuest="MarineQuest3"      NameMon="Marine Captain"    CFrameQuest=CFrame.new(-2441,72,-3216)   CFrameMon=CFrame.new(-1861,80,-3255)
        elseif lvl<=974  then Mon="Zombie"            LevelQuest=1 NameQuest="ZombieQuest"       NameMon="Zombie"            CFrameQuest=CFrame.new(-5497,48,-795)    CFrameMon=CFrame.new(-5658,79,-929)
        elseif lvl<=999  then Mon="Vampire"           LevelQuest=2 NameQuest="ZombieQuest"       NameMon="Vampire"           CFrameQuest=CFrame.new(-5497,48,-795)    CFrameMon=CFrame.new(-6038,32,-1341)
        elseif lvl<=1049 then Mon="Snow Trooper"      LevelQuest=1 NameQuest="SnowMountainQuest" NameMon="Snow Trooper"      CFrameQuest=CFrame.new(610,400,-5372)    CFrameMon=CFrame.new(549,427,-5564)
        elseif lvl<=1099 then Mon="Winter Warrior"    LevelQuest=2 NameQuest="SnowMountainQuest" NameMon="Winter Warrior"    CFrameQuest=CFrame.new(610,400,-5372)    CFrameMon=CFrame.new(1143,476,-5199)
        elseif lvl<=1124 then Mon="Lab Subordinate"   LevelQuest=1 NameQuest="IceSideQuest"      NameMon="Lab Subordinate"   CFrameQuest=CFrame.new(-6064,15,-4903)   CFrameMon=CFrame.new(-5707,16,-4513)
        elseif lvl<=1174 then Mon="Horned Warrior"    LevelQuest=2 NameQuest="IceSideQuest"      NameMon="Horned Warrior"    CFrameQuest=CFrame.new(-6064,15,-4903)   CFrameMon=CFrame.new(-6341,16,-5723)
        elseif lvl<=1199 then Mon="Magma Ninja"       LevelQuest=1 NameQuest="FireSideQuest"     NameMon="Magma Ninja"       CFrameQuest=CFrame.new(-5428,15,-5299)   CFrameMon=CFrame.new(-5450,77,-5808)
        elseif lvl<=1249 then Mon="Lava Pirate"       LevelQuest=2 NameQuest="FireSideQuest"     NameMon="Lava Pirate"       CFrameQuest=CFrame.new(-5428,15,-5299)   CFrameMon=CFrame.new(-5213,50,-4701)
        elseif lvl<=1274 then Mon="Ship Deckhand"     LevelQuest=1 NameQuest="ShipQuest1"        NameMon="Ship Deckhand"     CFrameQuest=CFrame.new(1038,125,32912)   CFrameMon=CFrame.new(1212,151,33059)
        elseif lvl<=1299 then Mon="Ship Engineer"     LevelQuest=2 NameQuest="ShipQuest1"        NameMon="Ship Engineer"     CFrameQuest=CFrame.new(1038,125,32912)   CFrameMon=CFrame.new(919,44,32780)
        elseif lvl<=1324 then Mon="Ship Steward"      LevelQuest=1 NameQuest="ShipQuest2"        NameMon="Ship Steward"      CFrameQuest=CFrame.new(969,125,33244)    CFrameMon=CFrame.new(919,130,33436)
        elseif lvl<=1349 then Mon="Ship Officer"      LevelQuest=2 NameQuest="ShipQuest2"        NameMon="Ship Officer"      CFrameQuest=CFrame.new(969,125,33244)    CFrameMon=CFrame.new(1036,181,33316)
        elseif lvl<=1374 then Mon="Arctic Warrior"    LevelQuest=1 NameQuest="FrostQuest"        NameMon="Arctic Warrior"    CFrameQuest=CFrame.new(5668,27,-6486)    CFrameMon=CFrame.new(5966,63,-6179)
        elseif lvl<=1424 then Mon="Snow Lurker"       LevelQuest=2 NameQuest="FrostQuest"        NameMon="Snow Lurker"       CFrameQuest=CFrame.new(5668,27,-6486)    CFrameMon=CFrame.new(5407,69,-6881)
        elseif lvl<=1449 then Mon="Sea Soldier"       LevelQuest=1 NameQuest="ForgottenQuest"    NameMon="Sea Soldier"       CFrameQuest=CFrame.new(-3054,236,-10143) CFrameMon=CFrame.new(-3028,65,-9775)
        else                   Mon="Water Fighter"    LevelQuest=2 NameQuest="ForgottenQuest"    NameMon="Water Fighter"     CFrameQuest=CFrame.new(-3054,236,-10143) CFrameMon=CFrame.new(-3353,285,-10535)
        end
    elseif World3 then
        if     lvl<=1524 then Mon="Pirate Millionaire"    LevelQuest=1 NameQuest="PiratePortQuest"    NameMon="Pirate Millionaire"    CFrameQuest=CFrame.new(-450,108,5951)    CFrameMon=CFrame.new(-246,47,5584)
        elseif lvl<=1574 then Mon="Pistol Billionaire"    LevelQuest=2 NameQuest="PiratePortQuest"    NameMon="Pistol Billionaire"    CFrameQuest=CFrame.new(-450,108,5951)    CFrameMon=CFrame.new(-55,84,5948)
        elseif lvl<=1599 then Mon="Dragon Crew Warrior"   LevelQuest=1 NameQuest="DragonCrewQuest"    NameMon="Dragon Crew Warrior"   CFrameQuest=CFrame.new(6750,127,-711)    CFrameMon=CFrame.new(6710,52,-1139)
        elseif lvl<=1624 then Mon="Dragon Crew Archer"    LevelQuest=2 NameQuest="DragonCrewQuest"    NameMon="Dragon Crew Archer"    CFrameQuest=CFrame.new(6750,127,-711)    CFrameMon=CFrame.new(6669,481,329)
        elseif lvl<=1649 then Mon="Hydra Enforcer"        LevelQuest=1 NameQuest="VenomCrewQuest"     NameMon="Hydra Enforcer"        CFrameQuest=CFrame.new(5206,1004,748)    CFrameMon=CFrame.new(4547,1003,334)
        elseif lvl<=1699 then Mon="Venomous Assailant"    LevelQuest=2 NameQuest="VenomCrewQuest"     NameMon="Venomous Assailant"    CFrameQuest=CFrame.new(5206,1004,748)    CFrameMon=CFrame.new(4675,1135,996)
        elseif lvl<=1724 then Mon="Marine Commodore"      LevelQuest=1 NameQuest="MarineTreeIsland"   NameMon="Marine Commodore"      CFrameQuest=CFrame.new(2481,74,-6780)    CFrameMon=CFrame.new(2577,76,-7740)
        elseif lvl<=1774 then Mon="Marine Rear Admiral"   LevelQuest=2 NameQuest="MarineTreeIsland"   NameMon="Marine Rear Admiral"   CFrameQuest=CFrame.new(2481,74,-6780)    CFrameMon=CFrame.new(3762,124,-6824)
        elseif lvl<=1799 then Mon="Fishman Raider"        LevelQuest=1 NameQuest="DeepForestIsland3"  NameMon="Fishman Raider"        CFrameQuest=CFrame.new(-10582,331,-8761) CFrameMon=CFrame.new(-10408,332,-8369)
        elseif lvl<=1824 then Mon="Fishman Captain"       LevelQuest=2 NameQuest="DeepForestIsland3"  NameMon="Fishman Captain"       CFrameQuest=CFrame.new(-10582,331,-8761) CFrameMon=CFrame.new(-10995,352,-9002)
        elseif lvl<=1849 then Mon="Forest Pirate"         LevelQuest=1 NameQuest="DeepForestIsland"   NameMon="Forest Pirate"         CFrameQuest=CFrame.new(-13234,331,-7625) CFrameMon=CFrame.new(-13274,332,-7770)
        elseif lvl<=1899 then Mon="Mythological Pirate"   LevelQuest=2 NameQuest="DeepForestIsland"   NameMon="Mythological Pirate"   CFrameQuest=CFrame.new(-13234,331,-7625) CFrameMon=CFrame.new(-13681,501,-6991)
        elseif lvl<=1924 then Mon="Jungle Pirate"         LevelQuest=1 NameQuest="DeepForestIsland2"  NameMon="Jungle Pirate"         CFrameQuest=CFrame.new(-12680,390,-9902) CFrameMon=CFrame.new(-12256,332,-10486)
        elseif lvl<=1974 then Mon="Musketeer Pirate"      LevelQuest=2 NameQuest="DeepForestIsland2"  NameMon="Musketeer Pirate"      CFrameQuest=CFrame.new(-12680,390,-9902) CFrameMon=CFrame.new(-13458,392,-9859)
        elseif lvl<=1999 then Mon="Reborn Skeleton"       LevelQuest=1 NameQuest="HauntedQuest1"      NameMon="Reborn Skeleton"       CFrameQuest=CFrame.new(-9479,141,5566)   CFrameMon=CFrame.new(-8764,166,6160)
        elseif lvl<=2024 then Mon="Living Zombie"         LevelQuest=2 NameQuest="HauntedQuest1"      NameMon="Living Zombie"         CFrameQuest=CFrame.new(-9479,141,5566)   CFrameMon=CFrame.new(-10144,139,5838)
        elseif lvl<=2049 then Mon="Demonic Soul"          LevelQuest=1 NameQuest="HauntedQuest2"      NameMon="Demonic Soul"          CFrameQuest=CFrame.new(-9517,172,6078)   CFrameMon=CFrame.new(-9506,172,6159)
        elseif lvl<=2074 then Mon="Posessed Mummy"        LevelQuest=2 NameQuest="HauntedQuest2"      NameMon="Posessed Mummy"        CFrameQuest=CFrame.new(-9517,172,6078)   CFrameMon=CFrame.new(-9582,6,6205)
        elseif lvl<=2099 then Mon="Peanut Scout"          LevelQuest=1 NameQuest="NutsIslandQuest"    NameMon="Peanut Scout"          CFrameQuest=CFrame.new(-2104,38,-10194)  CFrameMon=CFrame.new(-2143,48,-10030)
        elseif lvl<=2124 then Mon="Peanut President"      LevelQuest=2 NameQuest="NutsIslandQuest"    NameMon="Peanut President"      CFrameQuest=CFrame.new(-2104,38,-10194)  CFrameMon=CFrame.new(-1859,38,-10422)
        elseif lvl<=2149 then Mon="Ice Cream Chef"        LevelQuest=1 NameQuest="IceCreamIslandQuest" NameMon="Ice Cream Chef"       CFrameQuest=CFrame.new(-821,66,-10966)   CFrameMon=CFrame.new(-872,66,-10920)
        elseif lvl<=2199 then Mon="Ice Cream Commander"   LevelQuest=2 NameQuest="IceCreamIslandQuest" NameMon="Ice Cream Commander"  CFrameQuest=CFrame.new(-821,66,-10966)   CFrameMon=CFrame.new(-558,112,-11291)
        elseif lvl<=2224 then Mon="Cookie Crafter"        LevelQuest=1 NameQuest="CakeQuest1"         NameMon="Cookie Crafter"        CFrameQuest=CFrame.new(-2021,38,-12029)  CFrameMon=CFrame.new(-2374,38,-12125)
        elseif lvl<=2249 then Mon="Cake Guard"            LevelQuest=2 NameQuest="CakeQuest1"         NameMon="Cake Guard"            CFrameQuest=CFrame.new(-2021,38,-12029)  CFrameMon=CFrame.new(-1598,44,-12245)
        elseif lvl<=2274 then Mon="Baking Staff"          LevelQuest=1 NameQuest="CakeQuest2"         NameMon="Baking Staff"          CFrameQuest=CFrame.new(-1928,38,-12843)  CFrameMon=CFrame.new(-1888,78,-12998)
        elseif lvl<=2299 then Mon="Head Baker"            LevelQuest=2 NameQuest="CakeQuest2"         NameMon="Head Baker"            CFrameQuest=CFrame.new(-1928,38,-12843)  CFrameMon=CFrame.new(-2216,83,-12869)
        elseif lvl<=2324 then Mon="Cocoa Warrior"         LevelQuest=1 NameQuest="ChocQuest1"         NameMon="Cocoa Warrior"         CFrameQuest=CFrame.new(233,30,-12201)    CFrameMon=CFrame.new(-22,81,-12352)
        elseif lvl<=2349 then Mon="Chocolate Bar Battler" LevelQuest=2 NameQuest="ChocQuest1"         NameMon="Chocolate Bar Battler" CFrameQuest=CFrame.new(233,30,-12201)    CFrameMon=CFrame.new(583,77,-12463)
        elseif lvl<=2374 then Mon="Sweet Thief"           LevelQuest=1 NameQuest="ChocQuest2"         NameMon="Sweet Thief"           CFrameQuest=CFrame.new(151,31,-12775)    CFrameMon=CFrame.new(165,76,-12601)
        elseif lvl<=2399 then Mon="Candy Rebel"           LevelQuest=2 NameQuest="ChocQuest2"         NameMon="Candy Rebel"           CFrameQuest=CFrame.new(151,31,-12775)    CFrameMon=CFrame.new(135,77,-12877)
        elseif lvl<=2424 then Mon="Candy Pirate"          LevelQuest=1 NameQuest="CandyQuest1"        NameMon="Candy Pirate"          CFrameQuest=CFrame.new(-1150,20,-14446)  CFrameMon=CFrame.new(-1311,26,-14562)
        elseif lvl<=2449 then Mon="Snow Demon"            LevelQuest=2 NameQuest="CandyQuest1"        NameMon="Snow Demon"            CFrameQuest=CFrame.new(-1150,20,-14446)  CFrameMon=CFrame.new(-880,71,-14539)
        elseif lvl<=2474 then Mon="Isle Outlaw"           LevelQuest=1 NameQuest="TikiQuest1"         NameMon="Isle Outlaw"           CFrameQuest=CFrame.new(-16548,61,-173)   CFrameMon=CFrame.new(-16443,116,-264)
        elseif lvl<=2524 then Mon="Island Boy"            LevelQuest=2 NameQuest="TikiQuest1"         NameMon="Island Boy"            CFrameQuest=CFrame.new(-16548,61,-173)   CFrameMon=CFrame.new(-16901,84,-193)
        elseif lvl<=2549 then Mon="Isle Champion"         LevelQuest=2 NameQuest="TikiQuest2"         NameMon="Isle Champion"         CFrameQuest=CFrame.new(-16539,56,1052)   CFrameMon=CFrame.new(-16642,236,1031)
        elseif lvl<=2574 then Mon="Serpent Hunter"        LevelQuest=1 NameQuest="TikiQuest3"         NameMon="Serpent Hunter"        CFrameQuest=CFrame.new(-16665,105,1580)  CFrameMon=CFrame.new(-16521,106,1489)
        else                   Mon="Skull Slayer"         LevelQuest=2 NameQuest="TikiQuest3"         NameMon="Skull Slayer"          CFrameQuest=CFrame.new(-16665,105,1580)  CFrameMon=CFrame.new(-16855,122,1478)
        end
    end
end

-- ══════════════════════════════════════════════
--  AUTO FARM ENGINE
-- ══════════════════════════════════════════════
--[[
  DESIGN:
  ─────────
  FarmAnchor = fixed Vector3 captured once when NPC is found. NEVER changes.

  StartPull() — Heartbeat: snaps ALL matching NPCs to FarmAnchor every frame.
  StartHover() — Heartbeat: locks player Y to FarmAnchor.Y + HOVER_H every frame.

  Since both are pinned to the same immutable point, no feedback loop = no sky drift.

  Attack is now a SEPARATE always-running loop (task.wait 0.01) that fires
  as fast as possible independently of the farm logic loop.

  Farm logic loop just handles: quest check → find target → set anchor → wait for death.
  It does NOT call attack itself — the separate loop handles that.
]]

local HOVER_H    = 12
local _pullConn  = nil
local _hoverConn = nil

-- Snapshot used by pull loop — set just before StartPull, never mutated after
local _pullAnchorCF  = CFrame.new(0,0,0)
local _hoverPos      = Vector3.new(0,0,0)
local _pullName      = ""   -- snapshot of MonFarm at pull start

local function StopPull()
    if _pullConn then _pullConn:Disconnect(); _pullConn=nil end
end
local function StopHover()
    if _hoverConn then _hoverConn:Disconnect(); _hoverConn=nil end
end
local function StopFarmLoops()
    StopPull(); StopHover()
end

local function PrepNPC(e)
    local er = e:FindFirstChild("HumanoidRootPart"); if not er then return end
    local s = InfRange and 999 or math.max(AttackRange, 30)
    er.Size = Vector3.new(s,s,s); er.CanCollide = false
    e.Humanoid.WalkSpeed = 0; e.Humanoid.JumpPower = 0
    local head = e:FindFirstChild("Head")
    if head then head.CanCollide = false end
    if e.Humanoid:FindFirstChild("Animator") then e.Humanoid.Animator:Destroy() end
end

local function StartPull()
    StopPull()
    -- Snapshot everything we need — no upvalues that can change mid-run
    local cf   = _pullAnchorCF
    local name = _pullName
    local mon  = Mon  -- also snapshot Mon in case CheckQuest changes it
    _pullConn = RunService.Heartbeat:Connect(function()
        if not AF.Active then StopPull(); return end
        pcall(function()
            local en = workspace:FindFirstChild("Enemies"); if not en then return end
            for _, e in ipairs(en:GetChildren()) do
                if (e.Name == name or e.Name == mon)
                    and e:FindFirstChild("HumanoidRootPart")
                    and e:FindFirstChildOfClass("Humanoid")
                    and e.Humanoid.Health > 0 then
                    local er = e.HumanoidRootPart
                    er.CFrame    = cf
                    er.Velocity  = Vector3.zero
                    local s = InfRange and 999 or math.max(AttackRange,30)
                    er.Size = Vector3.new(s,s,s); er.CanCollide = false
                    e.Humanoid.WalkSpeed = 0; e.Humanoid.JumpPower = 0
                    local head = e:FindFirstChild("Head")
                    if head then head.CanCollide = false end
                    if e.Humanoid:FindFirstChild("Animator") then
                        e.Humanoid.Animator:Destroy()
                    end
                    pcall(function() sethiddenproperty(LocalPlayer,"SimulationRadius",math.huge) end)
                end
            end
        end)
    end)
end

local function StartHover()
    StopHover()
    local hp = _hoverPos  -- immutable snapshot
    _hoverConn = RunService.Heartbeat:Connect(function()
        if not AF.Active then StopHover(); return end
        local hrp = GetHRP(); if not hrp then return end
        hrp.CFrame = CFrame.new(hp)   -- force every frame, no drift threshold
        NoCollide()
        pcall(function() sethiddenproperty(LocalPlayer,"SimulationRadius",math.huge) end)
    end)
end

local function RunAutoFarm()
    -- Guard: if already running, reset the flag and let it restart cleanly
    if AF.Running then
        AF.Running = false
        task.wait(0.1)
    end
    AF.Running = true

    task.spawn(function()
        while AF.Active do
            local ok, err = pcall(function()

                -- ① Dead?
                local hum = GetHum()
                if not hum or hum.Health <= 0 then
                    AF.Status = "Dead — respawning..."
                    StopFarmLoops()
                    attackTarget = nil
                    task.wait(4)
                    return
                end

                -- ② Get quest info
                CheckQuest()
                if not Mon then task.wait(0.3); return end

                -- ③ Quest UI check
                local qGui = LocalPlayer.PlayerGui:FindFirstChild("Main")
                local qEl  = qGui and qGui:FindFirstChild("Quest")
                local qVis = qEl and qEl.Visible

                -- ④ No quest → go accept
                if not qVis then
                    StopFarmLoops(); attackTarget = nil
                    AF.Status = "Accepting quest..."
                    -- SkyTP with +3 Y offset so we land on top of NPC, not inside it
                    SkyTP(CFrameQuest, 3)
                    task.wait(0.4)
                    -- Retry if not close enough (entrance portal may have moved us)
                    local hrp = GetHRP()
                    if hrp then
                        local dist = (CFrameQuest.Position - hrp.Position).Magnitude
                        if dist > 40 then
                            SkyTP(CFrameQuest, 3)
                            task.wait(0.3)
                        end
                        hrp = GetHRP()
                        if hrp and (CFrameQuest.Position - hrp.Position).Magnitude <= 40 then
                            pcall(function()
                                ReplicatedStorage.Remotes.CommF_:InvokeServer("StartQuest",NameQuest,LevelQuest)
                            end)
                            task.wait(0.8)
                        end
                    end
                    return
                end

                -- ⑤ Wrong quest active → abandon
                local title = ""
                pcall(function() title = qEl.Container.QuestTitle.Title.Text end)
                if not string.find(title, NameMon or "") then
                    StopFarmLoops(); attackTarget = nil
                    pcall(function() ReplicatedStorage.Remotes.CommF_:InvokeServer("AbandonQuest") end)
                    task.wait(0.2)
                    return
                end

                -- ⑥ Find target NPC
                local en = workspace:FindFirstChild("Enemies")
                if not en then task.wait(0.3); return end
                local target = nil
                for _, e in ipairs(en:GetChildren()) do
                    if e.Name == Mon
                       and e:FindFirstChild("HumanoidRootPart")
                       and e:FindFirstChildOfClass("Humanoid")
                       and e.Humanoid.Health > 0 then
                        target = e; break
                    end
                end

                -- ⑦ No NPC found → go to spawn zone
                if not target then
                    StopFarmLoops(); attackTarget = nil
                    AF.Status = "Finding mob..."
                    SkyTP(CFrameMon, 5)
                    task.wait(1.2)
                    return
                end

                -- ⑧ Found NPC → set up immutable anchor
                local er = target:FindFirstChild("HumanoidRootPart")
                if not er then task.wait(0.15); return end

                PrepNPC(target)
                AutoHaki()
                EquipWeapon(GetWeaponName())

                -- Lock anchor to NPC's current position
                FarmAnchor     = er.Position
                _pullAnchorCF  = CFrame.new(FarmAnchor)
                _hoverPos      = Vector3.new(FarmAnchor.X, FarmAnchor.Y + HOVER_H, FarmAnchor.Z)
                _pullName      = target.Name
                MonFarm        = target.Name
                attackTarget   = target

                -- Move player to hover position via sky (if far)
                local hrp = GetHRP()
                if hrp and (FarmAnchor - hrp.Position).Magnitude > 10 then
                    AF.Status = "Flying to mob..."
                    hrp.CFrame = CFrame.new(FarmAnchor.X, 9999, FarmAnchor.Z)
                    task.wait(0.06); NoCollide()
                    hrp = GetHRP()
                    if hrp then hrp.CFrame = CFrame.new(_hoverPos) end
                    task.wait(0.05); NoCollide()
                end

                AF.Status = "Farming: " .. Mon

                -- Start Heartbeat loops (both use immutable snapshots)
                StartHover()
                StartPull()

                -- ⑨ Wait for NPC to die
                --   Attack is handled by the standalone fast loop above,
                --   so this just watches health and periodically preps.
                local ticker = 0
                while AF.Active
                      and target and target.Parent
                      and target:FindFirstChildOfClass("Humanoid")
                      and target.Humanoid.Health > 0 do

                    -- Re-prep occasionally (handles Animator respawn)
                    ticker = ticker + 1
                    if ticker % 10 == 0 then
                        pcall(function() PrepNPC(target) end)
                    end

                    -- Re-check quest still visible every 2s
                    if ticker % 20 == 0 then
                        local qv = qEl and qEl.Visible
                        if not qv then break end
                    end

                    task.wait(0.1)
                end

                -- NPC dead / quest done
                StopFarmLoops()
                attackTarget = nil; MonFarm = ""
                task.wait(0.1)
            end)

            if not ok then
                warn("[BFHub] Farm error:", err)
            end
            task.wait(0.05)
        end

        -- AF.Active turned false
        StopFarmLoops()
        attackTarget = nil; MonFarm = ""
        AF.Status    = "Idle"
        AF.Running   = false
    end)
end

-- ══════════════════════════════════════════════
--  RAYFIELD UI
-- ══════════════════════════════════════════════
local Window = Rayfield:CreateWindow({
    Name             = "🍎 BF Hub",
    LoadingTitle     = "BF Hub",
    LoadingSubtitle  = "v4 | Delta | All Seas",
    ConfigurationSaving = {Enabled=false},
    Discord          = {Enabled=false},
    KeySystem        = false,
})

-- ──────────────────────────────────────────────
--  TAB: FARM
-- ──────────────────────────────────────────────
local FarmTab = Window:CreateTab("⚔️ Farm", 4483362458)

FarmTab:CreateSection("Weapon")
FarmTab:CreateDropdown({
    Name="Weapon Type", Options={"Melee","Sword","Gun","Blox Fruit"},
    CurrentOption="Melee", Flag="Weapon",
    Callback=function(v) SelectWeapon=v end,
})

FarmTab:CreateSection("Auto Farm")
FarmTab:CreateToggle({
    Name="Auto Farm", CurrentValue=false, Flag="AutoFarm",
    Callback=function(v)
        AF.Active = v
        if v then
            RunAutoFarm()
        else
            StopFarmLoops()
            attackTarget=nil; MonFarm=""
            AF.Status="Idle"
        end
    end,
})

FarmTab:CreateToggle({
    Name="Auto Attack", CurrentValue=true, Flag="AutoAttack",
    Callback=function(v) AutoAttackOn=v end,
})

FarmTab:CreateSection("Range & Hitbox")
FarmTab:CreateToggle({
    Name="Infinite Range", CurrentValue=true, Flag="InfRange",
    Callback=function(v) InfRange=v end,
})
FarmTab:CreateSlider({
    Name="Attack Range (Inf OFF only)", Range={10,500}, Increment=10,
    Suffix=" st", CurrentValue=60, Flag="AtkRange",
    Callback=function(v) AttackRange=v end,
})
FarmTab:CreateToggle({
    Name="Hitbox Expand", CurrentValue=false, Flag="HitboxExpand",
    Callback=function(v) HitboxOn=v end,
})

FarmTab:CreateSection("Combat")
FarmTab:CreateToggle({
    Name="Auto Haki (12s)", CurrentValue=false, Flag="AutoHaki",
    Callback=function(v) AutoHakiOn=v end,
})

FarmTab:CreateSection("Status")
local StatusLabel = FarmTab:CreateLabel("Status: Idle")
local MobLabel    = FarmTab:CreateLabel("Mob: ?")
local LvlLabel    = FarmTab:CreateLabel("Lvl:?  HP:?/?")

task.spawn(function()
    while true do
        task.wait(1)
        pcall(function()
            local h  = GetHum()
            local hp = h and math.floor(h.Health)    or 0
            local mx = h and math.floor(h.MaxHealth)  or 0
            local lvl= "?"
            pcall(function() lvl = tostring(LocalPlayer.Data.Level.Value) end)
            StatusLabel:Set("Status: "..(AF.Status or "Idle"))
            MobLabel:Set("Mob: "..(Mon or "?"))
            LvlLabel:Set(("Lvl:%s  HP:%d/%d"):format(lvl,hp,mx))
        end)
    end
end)

-- ──────────────────────────────────────────────
--  TAB: MOVEMENT
-- ──────────────────────────────────────────────
local MoveTab = Window:CreateTab("🏃 Movement", 4483362458)
MoveTab:CreateSection("Speed")
MoveTab:CreateToggle({
    Name="Fast Walk", CurrentValue=false, Flag="FastWalk",
    Callback=function(v) ApplyWalkSpeed(v) end,
})
MoveTab:CreateSlider({
    Name="Walk Speed", Range={16,500}, Increment=10, Suffix=" sp",
    CurrentValue=100, Flag="WalkSpeed",
    Callback=function(v)
        WalkSpeedVal = v
        if WalkSpeedOn then ApplyWalkSpeed(true) end
    end,
})
MoveTab:CreateSection("Other")
MoveTab:CreateToggle({
    Name="Anti AFK", CurrentValue=false, Flag="AntiAFK",
    Callback=function(v) AntiAFKOn=v end,
})
MoveTab:CreateButton({
    Name="Rejoin",
    Callback=function()
        pcall(function() game:GetService("TeleportService"):Teleport(game.PlaceId,LocalPlayer) end)
    end,
})

-- ──────────────────────────────────────────────
--  TAB: TELEPORT
-- ──────────────────────────────────────────────
local TPTab = Window:CreateTab("📍 Teleport", 4483362458)

-- ── Player TP ──
TPTab:CreateSection("Player TP — Sky Method")

-- FIX: store selected name in a variable, not from dropdown property
local _selectedPlayer = ""

local function GetPlayerNames()
    local names = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then table.insert(names, p.Name) end
    end
    return #names > 0 and names or {"(no players)"}
end

local _initNames = GetPlayerNames()
_selectedPlayer  = _initNames[1]

local TPDrop = TPTab:CreateDropdown({
    Name          = "Select Player",
    Options       = _initNames,
    CurrentOption = _initNames[1],
    Flag          = "TPPlayerSelect",
    -- KEY FIX: update _selectedPlayer on every change
    Callback      = function(v)
        _selectedPlayer = v
    end,
})

TPTab:CreateButton({
    Name="⚡ TP to Player",
    Callback=function()
        if _selectedPlayer == "" or _selectedPlayer == "(no players)" then
            Rayfield:Notify({Title="BF Hub", Content="Select a player first.", Duration=2})
            return
        end
        -- Search by name directly — no reliance on dropdown property
        local found = nil
        for _, p in ipairs(Players:GetPlayers()) do
            if p.Name == _selectedPlayer and p ~= LocalPlayer then
                found = p; break
            end
        end
        if not found then
            Rayfield:Notify({Title="BF Hub", Content="Player '".. _selectedPlayer .."' not in server.", Duration=3})
            return
        end
        local char = found.Character
        if not char then
            Rayfield:Notify({Title="BF Hub", Content="Player has no character.", Duration=2})
            return
        end
        local th = char:FindFirstChild("HumanoidRootPart")
        if not th then
            Rayfield:Notify({Title="BF Hub", Content="Cannot find player position.", Duration=2})
            return
        end
        -- Sky-TP beside them
        SkyTP(th.CFrame * CFrame.new(3, 0, 3))
        Rayfield:Notify({Title="BF Hub", Content="Teleported to ".. found.Name, Duration=2})
    end,
})

TPTab:CreateButton({
    Name="🔄 Refresh Player List",
    Callback=function()
        local names = GetPlayerNames()
        -- Rayfield doesn't support live option refresh, but we update our variable
        -- so TP still works even if the dropdown label is stale
        _selectedPlayer = names[1]
        Rayfield:Notify({
            Title   = "BF Hub",
            Content = (#names).." player(s) found. Auto-selected: "..(names[1] or "none"),
            Duration = 3,
        })
    end,
})

-- Manually type a name to TP
TPTab:CreateSection("TP by Name")
local _manualName = ""
TPTab:CreateInput({
    Name        = "Player Name",
    PlaceholderText = "Type exact name...",
    RemoveTextAfterFocusLost = false,
    Flag        = "ManualTPName",
    Callback    = function(v) _manualName = v end,
})
TPTab:CreateButton({
    Name="⚡ TP to Typed Name",
    Callback=function()
        if _manualName == "" then return end
        local found = Players:FindFirstChild(_manualName)
        if not found or found == LocalPlayer then
            Rayfield:Notify({Title="BF Hub", Content="Player '".. _manualName .."' not found.", Duration=3})
            return
        end
        local char = found.Character
        if not char then
            Rayfield:Notify({Title="BF Hub", Content="No character.", Duration=2})
            return
        end
        local th = char:FindFirstChild("HumanoidRootPart")
        if not th then return end
        SkyTP(th.CFrame * CFrame.new(3,0,3))
        Rayfield:Notify({Title="BF Hub", Content="Teleported to ".. found.Name, Duration=2})
    end,
})

TPTab:CreateSection("Quick TPs")
TPTab:CreateButton({
    Name="⬆️ Sky (Y=9999)",
    Callback=function()
        local h=GetHRP(); if not h then return end
        h.CFrame=CFrame.new(h.Position.X,9999,h.Position.Z)
    end,
})
TPTab:CreateButton({
    Name="⬇️ Ground (Y=5)",
    Callback=function()
        local h=GetHRP(); if not h then return end
        h.CFrame=CFrame.new(h.Position.X,5,h.Position.Z)
    end,
})
TPTab:CreateButton({
    Name="🕳️ Void (Y=-5000)",
    Callback=function()
        local h=GetHRP(); if not h then return end
        NoCollide()
        h.CFrame=CFrame.new(h.Position.X,9999,h.Position.Z)
        task.wait(0.06)
        h=GetHRP(); if not h then return end
        NoCollide()
        h.CFrame=CFrame.new(h.Position.X,-5000,h.Position.Z)
    end,
})

-- ──────────────────────────────────────────────
--  TAB: ESP
-- ──────────────────────────────────────────────
local ESPTab = Window:CreateTab("👁️ ESP", 4483362458)
ESPTab:CreateSection("Player")
ESPTab:CreateToggle({Name="Player ESP",    CurrentValue=true,  Flag="ESPOn",     Callback=function(v) ESPOn=v end})
ESPTab:CreateToggle({Name="Show Names",    CurrentValue=true,  Flag="ESPNames",  Callback=function(v) ShowName=v end})
ESPTab:CreateToggle({Name="Show Health",   CurrentValue=true,  Flag="ESPHealth", Callback=function(v) ShowHealth=v end})
ESPTab:CreateSection("World")
ESPTab:CreateToggle({
    Name="Fruit ESP 🍎", CurrentValue=false, Flag="FruitESP",
    Callback=function(v) FruitESPOn=v; if v then ScanFruits() else ClearFruitBBs() end end,
})

-- ──────────────────────────────────────────────
--  TAB: MISC
-- ──────────────────────────────────────────────
local MiscTab = Window:CreateTab("⚙️ Misc", 4483362458)

MiscTab:CreateSection("Game")
MiscTab:CreateToggle({
    Name="Save Spawn Point", CurrentValue=false, Flag="SaveSpawn",
    Callback=function(v)
        if v then pcall(function() ReplicatedStorage.Remotes.CommF_:InvokeServer("SetSpawnPoint") end) end
    end,
})
MiscTab:CreateToggle({
    Name="Auto Haki Color Buy", CurrentValue=false, Flag="AutoHakiColor",
    Callback=function(v)
        task.spawn(function()
            while v do
                pcall(function() ReplicatedStorage.Remotes.CommF_:InvokeServer("ColorsDealer","2") end)
                task.wait(1)
            end
        end)
    end,
})

MiscTab:CreateSection("Team")
MiscTab:CreateButton({Name="Pirates", Callback=function()
    pcall(function() ReplicatedStorage.Remotes.CommF_:InvokeServer("SetTeam","Pirates") end)
end})
MiscTab:CreateButton({Name="Marines", Callback=function()
    pcall(function() ReplicatedStorage.Remotes.CommF_:InvokeServer("SetTeam","Marines") end)
end})

MiscTab:CreateSection("Shop")
MiscTab:CreateButton({Name="Buy Geppo", Callback=function()
    pcall(function() ReplicatedStorage.Remotes.CommF_:InvokeServer("BuyHaki","Geppo") end)
end})
MiscTab:CreateButton({Name="Buy Buso", Callback=function()
    pcall(function() ReplicatedStorage.Remotes.CommF_:InvokeServer("BuyHaki","Buso") end)
end})
MiscTab:CreateButton({Name="Buy Ken", Callback=function()
    pcall(function() ReplicatedStorage.Remotes.CommF_:InvokeServer("KenTalk","Buy") end)
end})

MiscTab:CreateSection("Codes")
MiscTab:CreateButton({
    Name="Redeem All Codes",
    Callback=function()
        local codes = {
            "KITT_RESET","Sub2UncleKizaru","SUB2GAMERROBOT_RESET1","Sub2Fer999",
            "Enyu_is_Pro","JCWK","StarcodeHEO","MagicBus","KittGaming",
            "Sub2CaptainMaui","Sub2OfficalNoobie","TheGreatAce","Sub2NoobMaster123",
            "Sub2Daigrock","Axiore","StrawHatMaine","TantaiGaming","Bluxxy",
            "SUB2GAMERROBOT_EXP1","Chandler","NOMOREHACK","BANEXPLOIT","WildDares",
            "BossBuild","GetPranked","EARN_FRUITS","FIGHT4FRUIT","NOEXPLOITER",
            "NOOB2ADMIN","CODESLIDE","ADMINHACKED","ADMINDARES","fruitconcepts",
            "krazydares","TRIPLEABUSE","SEATROLLING","24NOADMIN","REWARDFUN",
            "NEWTROLL","fudd10_v2","Fudd10","Bignews","SECRET_ADMIN"
        }
        for _, c in ipairs(codes) do
            pcall(function() ReplicatedStorage.Remotes.Redeem:InvokeServer(c) end)
        end
        Rayfield:Notify({Title="BF Hub", Content="All codes redeemed!", Duration=3})
    end,
})

MiscTab:CreateSection("Auto Stats")
MiscTab:CreateDropdown({
    Name="Auto Stat Points", Options={"Off","Melee","Defense","Sword","Gun","Fruit"},
    CurrentOption="Off", Flag="AutoStats",
    Callback=function(v)
        task.spawn(function()
            local m = {Melee="Melee",Defense="Defense",Sword="Sword",Gun="Gun",Fruit="Demon Fruit"}
            while v ~= "Off" do
                pcall(function() ReplicatedStorage.Remotes.CommF_:InvokeServer("AddPoint",m[v],3) end)
                task.wait(0.5)
            end
        end)
    end,
})

-- ══════════════════════════════════════════════
task.wait(2)
Rayfield:Notify({
    Title    = "🍎 BF Hub v4 Loaded",
    Content  = "Fast attack | Fixed TP | Stable farm | All Seas",
    Duration = 5,
})
