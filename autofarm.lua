-- FyZe Hub | Blox Fruits | All Seas | Delta

local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local TweenService      = game:GetService("TweenService")
local VIM               = game:GetService("VirtualInputManager")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer       = Players.LocalPlayer

-- ════════════════════════════════════
--  RAYFIELD LOAD
-- ════════════════════════════════════
local Rayfield
pcall(function()
    Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()
end)
if not Rayfield then
    local s = function() end
    local t = {CreateToggle=s,CreateSlider=s,CreateButton=s,
               CreateDropdown=s,CreateLabel=s,CreateSection=s,CreateInput=s}
    Rayfield = {
        CreateWindow = function()
            return setmetatable({},{__index=function() return function() return t end end})
        end,
        Notify = s,
    }
end

-- ════════════════════════════════════
--  HELPERS
-- ════════════════════════════════════
local function GetChar() return LocalPlayer.Character end
local function GetHRP()
    local c = GetChar(); return c and c:FindFirstChild("HumanoidRootPart")
end
local function GetHum()
    local c = GetChar(); return c and c:FindFirstChildOfClass("Humanoid")
end
-- Disable all character collisions
local function NoCollide()
    local c = GetChar(); if not c then return end
    for _, p in ipairs(c:GetDescendants()) do
        if p:IsA("BasePart") then p.CanCollide = false end
    end
end
-- Clamp Y above water (BF water surface ~Y=0)
local function SafeY(y) return math.max(y, 4) end

-- ════════════════════════════════════
--  CACHE ATTACK REMOTES
-- ════════════════════════════════════
local RegAttack, RegHit
task.spawn(function()
    pcall(function()
        local net = ReplicatedStorage:WaitForChild("Modules",15)
                      :WaitForChild("Net",15)
        RegAttack = net:WaitForChild("RE/RegisterAttack",15)
        RegHit    = net:WaitForChild("RE/RegisterHit",15)
    end)
end)

-- ════════════════════════════════════
--  STATE
-- ════════════════════════════════════
local SelectWeapon = "Melee"
local WalkSpeedVal = 100
local WalkSpeedOn  = false
local WalkOnWater  = false
local HitboxOn     = false
local AutoHakiOn   = false
local AntiAFKOn    = false
local FruitESPOn   = false
local ESPOn        = true
local ShowName     = true
local ShowHealth   = true
local AutoAttackOn = true
local AttackRange  = 60
local InfRange     = true

local AF = { Active=false, Running=false, Status="Idle" }
local Mon, NameMon, NameQuest, LevelQuest, CFrameQuest, CFrameMon
local MonFarm    = ""
local FarmAnchor = Vector3.new(0,0,0)

local World1 = game.PlaceId == 2753915549
local World2 = game.PlaceId == 4442272183
local World3 = game.PlaceId == 7449423635

-- ════════════════════════════════════
--  TELEPORT SYSTEM
--
--  TweenTP  — smooth farm travel (lerp tween).
--             Runs entrance check. Used by farm only.
--
--  PortalTP — instant player/manual TP using BF
--             FreeFalling state (no bounce-back,
--             no entrance check).
-- ════════════════════════════════════
local EntranceZones = {
    [2753915549] = {
        { thr=1200, zone=Vector3.new(-7894.6,5547.1,-380.3),  entry=Vector3.new(-7894.6,5547.1,-380.3) },
        { thr=3500, zone=Vector3.new(61163.9,11.7,1819.8),    entry=Vector3.new(61163.9,11.7,1819.8)   },
        { thr=1200, zone=Vector3.new(-4607.8,872.5,-1667.6),  entry=Vector3.new(-4607.8,872.5,-1667.6) },
    },
    [4442272183] = {
        { thr=3500, zone=Vector3.new(923.2,127.0,32852.8),    entry=Vector3.new(923.2,127.0,32852.8)   },
        { thr=1200, zone=Vector3.new(-6508.6,89.0,-132.8),    entry=Vector3.new(-6508.6,89.0,-132.8)   },
    },
    [7449423635] = {
        { thr=1200, zone=Vector3.new(5657.9,1013.1,-335.5),   entry=Vector3.new(5657.9,1013.1,-335.5)  },
        { thr=1200, zone=Vector3.new(-5075.5,314.5,-3150.0),  entry=Vector3.new(-5075.5,314.5,-3150.0) },
    },
}

local function CheckAndEnter(destPos)
    local hrp = GetHRP(); if not hrp then return end
    for _, z in ipairs(EntranceZones[game.PlaceId] or {}) do
        if (destPos - z.zone).Magnitude < z.thr
        and (hrp.Position - z.zone).Magnitude > z.thr * 0.45 then
            pcall(function()
                ReplicatedStorage.Remotes.CommF_:InvokeServer("requestEntrance", z.entry)
            end)
            task.wait(0.7)
            return
        end
    end
end

-- TweenTP: smooth two-phase lerp.
-- Phase 1: fly UP to destY+20 at 400 st/s (linear)
-- Phase 2: drop DOWN to destY at 200 st/s (quad ease)
-- BodyVelocity pin prevents physics fighting the tween.
-- IMPORTANT: caller must StopHover() before calling this
--            or the hover loop will fight the tween.
local _tweenActive = false

local function StopTween()
    _tweenActive = false
    local hrp = GetHRP()
    if hrp then
        local bv = hrp:FindFirstChild("_FyzeBV")
        if bv then bv:Destroy() end
    end
end

local function TweenTP(destCF, yExtra)
    StopTween()
    local hrp = GetHRP(); if not hrp then return end
    local hum = GetHum(); if not hum or hum.Health <= 0 then return end
    yExtra = yExtra or 0

    -- Entrance check BEFORE moving
    CheckAndEnter(destCF.Position)
    hrp = GetHRP(); if not hrp then return end

    local destY  = SafeY(destCF.Position.Y) + yExtra
    local finalCF = CFrame.new(destCF.Position.X, destY, destCF.Position.Z)
    local aboveCF = CFrame.new(destCF.Position.X, destY + 20, destCF.Position.Z)

    NoCollide()
    _tweenActive = true

    -- Pin with BodyVelocity
    local bv = Instance.new("BodyVelocity")
    bv.Name     = "_FyzeBV"
    bv.MaxForce = Vector3.new(1e5, 1e5, 1e5)
    bv.Velocity = Vector3.zero
    bv.Parent   = hrp

    -- Phase 1: up
    local d1 = (aboveCF.Position - hrp.Position).Magnitude
    local tw1 = TweenService:Create(hrp,
        TweenInfo.new(math.max(d1/400, 0.05), Enum.EasingStyle.Linear),
        {CFrame = aboveCF})
    tw1:Play(); tw1.Completed:Wait()
    if not _tweenActive then return end

    -- Phase 2: down
    hrp = GetHRP(); if not hrp then StopTween(); return end
    local d2 = (finalCF.Position - hrp.Position).Magnitude
    local tw2 = TweenService:Create(hrp,
        TweenInfo.new(math.max(d2/200, 0.04), Enum.EasingStyle.Quad),
        {CFrame = finalCF})
    tw2:Play(); tw2.Completed:Wait()

    StopTween()
    NoCollide()

    -- Final water safety check
    hrp = GetHRP()
    if hrp and hrp.Position.Y < 2 then
        hrp.CFrame = CFrame.new(hrp.Position.X, 5, hrp.Position.Z)
    end
end

-- PortalTP: mimics BF portal teleport.
-- Sets FreeFalling physics state first (stops anti-cheat kick),
-- then snaps CFrame twice for reliability.
-- No entrance check = no bounce-back on player TP.
local function PortalTP(destCF)
    local hrp = GetHRP(); if not hrp then return end
    local hum = GetHum(); if not hum then return end
    local landY = math.max(destCF.Position.Y, 4)
    NoCollide()
    hum:ChangeState(Enum.HumanoidStateType.FreeFalling)
    task.wait(0.05)
    hrp = GetHRP(); if not hrp then return end
    NoCollide()
    hrp.CFrame = CFrame.new(destCF.Position.X, landY, destCF.Position.Z)
    task.wait(0.05)
    hrp = GetHRP()
    if hrp then
        hrp.CFrame = CFrame.new(destCF.Position.X, landY, destCF.Position.Z)
    end
    NoCollide()
end

-- ════════════════════════════════════
--  ATTACK (Heartbeat — every frame)
-- ════════════════════════════════════
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
    if not GetEquippedTool() then return end
    local last, hits = FindHits()
    if not last or #hits == 0 then return end
    pcall(function() RegAttack:FireServer(1e-9) end)
    pcall(function() RegHit:FireServer(last, hits) end)
end

RunService.Heartbeat:Connect(function()
    if AutoAttackOn then pcall(AttackNoCoolDown) end
end)

-- ════════════════════════════════════
--  MISC HELPERS
-- ════════════════════════════════════
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

-- Walk speed: persistent Heartbeat loop so BF can't reset it
local function SetWalkSpeed(on)
    WalkSpeedOn = on
    pcall(function()
        local h = GetHum()
        if h then h.WalkSpeed = on and WalkSpeedVal or 16 end
    end)
end
RunService.Heartbeat:Connect(function()
    if not WalkSpeedOn then return end
    pcall(function()
        local h = GetHum()
        if h and h.WalkSpeed ~= WalkSpeedVal then h.WalkSpeed = WalkSpeedVal end
    end)
end)
LocalPlayer.CharacterAdded:Connect(function()
    task.wait(1)
    if WalkSpeedOn then SetWalkSpeed(true) end
end)

-- Walk on water: raise WaterBase-Plane collision Y
-- Only modifies when active, restores original on toggle off
local _waterOrigSize = nil
RunService.Heartbeat:Connect(function()
    if not WalkOnWater then return end
    pcall(function()
        local map = workspace:FindFirstChild("Map"); if not map then return end
        local wb  = map:FindFirstChild("WaterBase-Plane"); if not wb then return end
        if not _waterOrigSize then _waterOrigSize = wb.Size end
        -- Raise Y from ~80 to 112 so surface is walkable
        if wb.Size.Y < 110 then
            wb.Size = Vector3.new(wb.Size.X, 112, wb.Size.Z)
        end
        wb.CanCollide = true
    end)
end)

-- Anti AFK
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

-- Auto Haki loop
task.spawn(function()
    while true do
        if AutoHakiOn then AutoHaki() end
        task.wait(12)
    end
end)

-- Global hitbox expand
RunService.Heartbeat:Connect(function()
    if not HitboxOn then return end
    pcall(function()
        local en = workspace:FindFirstChild("Enemies"); if not en then return end
        local s  = InfRange and 999 or math.max(AttackRange,30)
        for _, e in ipairs(en:GetChildren()) do
            local hrp = e:FindFirstChild("HumanoidRootPart")
            if hrp and hrp.Size.X < s then
                hrp.Size = Vector3.new(s,s,s); hrp.CanCollide = false
                local head = e:FindFirstChild("Head")
                if head then head.CanCollide = false end
            end
        end
    end)
end)

-- ════════════════════════════════════
--  FRUIT ESP
-- ════════════════════════════════════
local FruitBBs = {}
local function MakeFruitBB(adornee, label)
    if FruitBBs[adornee] or not adornee or not adornee.Parent then return end
    local bb = Instance.new("BillboardGui")
    bb.AlwaysOnTop=true; bb.Size=UDim2.new(0,180,0,40)
    bb.StudsOffset=Vector3.new(0,6,0); bb.Adornee=adornee
    bb.Parent=game:GetService("CoreGui")
    local l = Instance.new("TextLabel",bb)
    l.BackgroundTransparency=1; l.Size=UDim2.new(1,0,1,0)
    l.Text=label; l.TextColor3=Color3.fromRGB(255,215,0)
    l.Font=Enum.Font.GothamBold; l.TextSize=14
    l.TextStrokeTransparency=0.2; l.TextStrokeColor3=Color3.new(0,0,0)
    FruitBBs[adornee]=bb
    adornee.AncestryChanged:Connect(function()
        if not adornee.Parent then
            pcall(function() bb:Destroy() end); FruitBBs[adornee]=nil
        end
    end)
end
local function ClearFruitBBs()
    for a,bb in pairs(FruitBBs) do
        pcall(function() bb:Destroy() end); FruitBBs[a]=nil
    end
end
local function ScanFruits()
    if not FruitESPOn then return end
    local function TryTag(obj)
        if not string.find(string.lower(obj.Name),"fruit") then return end
        local ad
        if obj:IsA("Tool")        then ad = obj:FindFirstChild("Handle") or obj.PrimaryPart
        elseif obj:IsA("Model")   then ad = obj.PrimaryPart or obj:FindFirstChildOfClass("BasePart")
        elseif obj:IsA("BasePart") then ad = obj end
        if ad then MakeFruitBB(ad, obj.Name) end
    end
    for _,o in ipairs(workspace:GetChildren()) do TryTag(o) end
    for _,fn in ipairs({"Fruits","DevilFruits","DroppedFruits"}) do
        local f=workspace:FindFirstChild(fn)
        if f then for _,o in ipairs(f:GetChildren()) do TryTag(o) end end
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
            for a,bb in pairs(FruitBBs) do
                if not a.Parent then pcall(function() bb:Destroy() end); FruitBBs[a]=nil end
            end
            ScanFruits()
        else
            if next(FruitBBs) then ClearFruitBBs() end
        end
    end
end)

-- ════════════════════════════════════
--  PLAYER ESP
-- ════════════════════════════════════
local ESPObj = {}
local C_W = Color3.fromRGB(255,255,255)
local C_G = Color3.fromRGB(80,255,120)
local C_R = Color3.fromRGB(255,60,60)
local function AddESP(p)
    if p==LocalPlayer then return end
    ESPObj[p]={}
    local function Setup()
        local ch=p.Character; if not ch then return end
        local hrp=ch:FindFirstChild("HumanoidRootPart"); if not hrp then return end
        if ESPObj[p].bb   then ESPObj[p].bb:Destroy() end
        if ESPObj[p].conn then ESPObj[p].conn:Disconnect() end
        local bb=Instance.new("BillboardGui")
        bb.AlwaysOnTop=true; bb.Size=UDim2.new(0,200,0,50)
        bb.StudsOffset=Vector3.new(0,3,0); bb.Adornee=hrp; bb.Parent=hrp
        local nl=Instance.new("TextLabel",bb)
        nl.BackgroundTransparency=1; nl.Size=UDim2.new(1,0,.5,0)
        nl.TextColor3=C_W; nl.TextStrokeTransparency=0.5
        nl.Font=Enum.Font.GothamBold; nl.TextSize=14; nl.Text=p.Name
        local hl=Instance.new("TextLabel",bb)
        hl.BackgroundTransparency=1; hl.Size=UDim2.new(1,0,.5,0)
        hl.Position=UDim2.new(0,0,.5,0)
        hl.TextStrokeTransparency=0.5; hl.Font=Enum.Font.Gotham; hl.TextSize=14
        ESPObj[p].bb=bb
        ESPObj[p].conn=RunService.RenderStepped:Connect(function()
            if not ESPOn then bb.Enabled=false; return end
            local c2=p.Character; if not c2 then bb.Enabled=false; return end
            local h=c2:FindFirstChild("HumanoidRootPart")
            local hu=c2:FindFirstChildOfClass("Humanoid")
            if not h or not hu then bb.Enabled=false; return end
            bb.Enabled=true; bb.Adornee=h
            nl.Visible=ShowName; nl.Text=p.Name
            hl.Visible=ShowHealth
            local hp,mx=math.floor(hu.Health),math.max(hu.MaxHealth,1)
            hl.Text=("HP:%d/%d"):format(hp,mx)
            hl.TextColor3=(hp/mx)>0.4 and C_G or C_R
        end)
    end
    if p.Character then Setup() end
    p.CharacterAdded:Connect(Setup)
end
local function RemoveESP(p)
    local d=ESPObj[p]; if not d then return end
    if d.bb   then d.bb:Destroy() end
    if d.conn then d.conn:Disconnect() end
    ESPObj[p]=nil
end
for _,p in ipairs(Players:GetPlayers()) do AddESP(p) end
Players.PlayerAdded:Connect(AddESP)
Players.PlayerRemoving:Connect(RemoveESP)

-- ════════════════════════════════════
--  QUEST DATA
-- ════════════════════════════════════
local function CheckQuest()
    local ok,lvl=pcall(function() return LocalPlayer.Data.Level.Value end)
    lvl=ok and lvl or 0
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

-- ════════════════════════════════════
--  FARM ENGINE
-- ════════════════════════════════════
--[[
  FarmAnchor = fixed Vector3 captured once when NPC found.
  Pull loop  = snaps ALL matching NPCs to FarmAnchor every frame.
  Hover loop = locks player to FarmAnchor + HOVER_H every frame.

  KEY FIX for sky glitch:
    StopFarmLoops() (which calls StopHover) is called BEFORE
    every TweenTP call. Without this the hover Heartbeat fights
    the tween and launches the player upward indefinitely.
]]
local HOVER_H       = 12
local _pullConn     = nil
local _hoverConn    = nil
local _pullAnchorCF = CFrame.new(0,0,0)
local _hoverPos     = Vector3.new(0,0,0)
local _pullName     = ""

local function StopPull()
    if _pullConn  then _pullConn:Disconnect();  _pullConn=nil  end
end
local function StopHover()
    if _hoverConn then _hoverConn:Disconnect(); _hoverConn=nil end
    -- Also kill any in-progress tween
    StopTween()
end
local function StopFarmLoops()
    StopPull(); StopHover()
end

local function PrepNPC(e)
    local er = e:FindFirstChild("HumanoidRootPart"); if not er then return end
    local s = InfRange and 999 or math.max(AttackRange,30)
    er.Size=Vector3.new(s,s,s); er.CanCollide=false
    e.Humanoid.WalkSpeed=0; e.Humanoid.JumpPower=0
    local head=e:FindFirstChild("Head"); if head then head.CanCollide=false end
    if e.Humanoid:FindFirstChild("Animator") then e.Humanoid.Animator:Destroy() end
end

local function StartPull()
    StopPull()
    local cf   = _pullAnchorCF   -- immutable snapshot
    local name = _pullName
    local mon  = Mon
    _pullConn = RunService.Heartbeat:Connect(function()
        if not AF.Active then StopPull(); return end
        pcall(function()
            local en = workspace:FindFirstChild("Enemies"); if not en then return end
            for _, e in ipairs(en:GetChildren()) do
                if (e.Name==name or e.Name==mon)
                    and e:FindFirstChild("HumanoidRootPart")
                    and e:FindFirstChildOfClass("Humanoid")
                    and e.Humanoid.Health > 0 then
                    local er = e.HumanoidRootPart
                    er.CFrame   = cf
                    er.Velocity = Vector3.zero
                    local s = InfRange and 999 or math.max(AttackRange,30)
                    er.Size=Vector3.new(s,s,s); er.CanCollide=false
                    e.Humanoid.WalkSpeed=0; e.Humanoid.JumpPower=0
                    local head=e:FindFirstChild("Head"); if head then head.CanCollide=false end
                    if e.Humanoid:FindFirstChild("Animator") then e.Humanoid.Animator:Destroy() end
                    pcall(function() sethiddenproperty(LocalPlayer,"SimulationRadius",math.huge) end)
                end
            end
        end)
    end)
end

local function StartHover()
    StopHover()
    local hp = _hoverPos   -- immutable snapshot
    _hoverConn = RunService.Heartbeat:Connect(function()
        if not AF.Active then StopHover(); return end
        local hrp = GetHRP(); if not hrp then return end
        hrp.CFrame = CFrame.new(hp)
        NoCollide()
        pcall(function() sethiddenproperty(LocalPlayer,"SimulationRadius",math.huge) end)
    end)
end

local function RunAutoFarm()
    if AF.Running then AF.Running=false; task.wait(0.2) end
    AF.Running = true
    task.spawn(function()
        while AF.Active do
            pcall(function()

                -- Dead check
                local hum = GetHum()
                if not hum or hum.Health <= 0 then
                    AF.Status="Dead"; StopFarmLoops(); task.wait(4); return
                end

                -- Quest data
                CheckQuest()
                if not Mon then task.wait(0.3); return end

                local qGui = LocalPlayer.PlayerGui:FindFirstChild("Main")
                local qEl  = qGui and qGui:FindFirstChild("Quest")
                local qVis = qEl and qEl.Visible

                -- No quest active
                if not qVis then
                    -- MUST stop hover BEFORE calling TweenTP
                    StopFarmLoops()
                    AF.Status = "Accepting quest"
                    TweenTP(CFrameQuest, 3)
                    task.wait(0.5)
                    local hrp = GetHRP()
                    if hrp and (CFrameQuest.Position - hrp.Position).Magnitude > 40 then
                        TweenTP(CFrameQuest, 3); task.wait(0.4)
                    end
                    hrp = GetHRP()
                    if hrp and (CFrameQuest.Position - hrp.Position).Magnitude <= 40 then
                        pcall(function()
                            ReplicatedStorage.Remotes.CommF_:InvokeServer("StartQuest",NameQuest,LevelQuest)
                        end)
                        task.wait(0.8)
                    end
                    return
                end

                -- Wrong quest
                local title = ""
                pcall(function() title = qEl.Container.QuestTitle.Title.Text end)
                if not string.find(title, NameMon or "") then
                    StopFarmLoops()
                    pcall(function() ReplicatedStorage.Remotes.CommF_:InvokeServer("AbandonQuest") end)
                    task.wait(0.2); return
                end

                -- Find target NPC
                local en = workspace:FindFirstChild("Enemies")
                if not en then task.wait(0.3); return end
                local target = nil
                for _, e in ipairs(en:GetChildren()) do
                    if e.Name==Mon
                       and e:FindFirstChild("HumanoidRootPart")
                       and e:FindFirstChildOfClass("Humanoid")
                       and e.Humanoid.Health > 0 then
                        target=e; break
                    end
                end

                -- No NPC found — travel to spawn zone
                if not target then
                    -- MUST stop hover BEFORE calling TweenTP
                    StopFarmLoops()
                    AF.Status = "Finding mob"
                    TweenTP(CFrameMon, 5)
                    task.wait(1.2); return
                end

                -- Found NPC — set up anchor
                local er = target:FindFirstChild("HumanoidRootPart")
                if not er then task.wait(0.15); return end

                PrepNPC(target)
                AutoHaki()
                EquipWeapon(GetWeaponName())

                local anchorY    = SafeY(er.Position.Y)
                FarmAnchor       = Vector3.new(er.Position.X, anchorY, er.Position.Z)
                _pullAnchorCF    = CFrame.new(FarmAnchor)
                _hoverPos        = Vector3.new(FarmAnchor.X, FarmAnchor.Y + HOVER_H, FarmAnchor.Z)
                _pullName        = target.Name
                MonFarm          = target.Name

                -- Travel to hover position
                -- StopFarmLoops first so hover doesn't fight the tween
                local hrp = GetHRP()
                if hrp and (FarmAnchor - hrp.Position).Magnitude > 10 then
                    AF.Status = "Flying to mob"
                    StopFarmLoops()   -- critical: kill hover before tweening
                    TweenTP(CFrame.new(FarmAnchor), HOVER_H)
                    task.wait(0.1)
                    NoCollide()
                end

                AF.Status = "Farming: " .. Mon

                -- Start both loops (anchor is now fixed, no drift possible)
                StartHover()
                StartPull()

                -- Wait for NPC to die
                local tick = 0
                while AF.Active and target and target.Parent
                      and target:FindFirstChildOfClass("Humanoid")
                      and target.Humanoid.Health > 0 do
                    tick = tick + 1
                    if tick % 10 == 0 then pcall(function() PrepNPC(target) end) end
                    if tick % 20 == 0 then
                        if not (qEl and qEl.Visible) then break end
                    end
                    task.wait(0.1)
                end

                StopFarmLoops(); MonFarm=""; task.wait(0.1)
            end)
            task.wait(0.05)
        end
        StopFarmLoops(); MonFarm=""; AF.Status="Idle"; AF.Running=false
    end)
end

-- ════════════════════════════════════
--  UI
-- ════════════════════════════════════
local Window = Rayfield:CreateWindow({
    Name             = "FyZe Hub",
    LoadingTitle     = "FyZe Hub",
    LoadingSubtitle  = "",
    ConfigurationSaving = {Enabled=false},
    Discord          = {Enabled=false},
    KeySystem        = false,
})

-- ── Farm Tab ──────────────────────────────────
local FarmTab = Window:CreateTab("Farm", 4483362458)

FarmTab:CreateSection("Weapon")
FarmTab:CreateDropdown({
    Name="Weapon Type", Options={"Melee","Sword","Gun","Blox Fruit"},
    CurrentOption="Melee", Flag="Weapon",
    -- Rayfield passes the selected string directly
    Callback=function(v) SelectWeapon = tostring(v) end,
})

FarmTab:CreateSection("Auto Farm")
FarmTab:CreateToggle({
    Name="Auto Farm", CurrentValue=false, Flag="AutoFarm",
    Callback=function(v)
        AF.Active = v
        if v then RunAutoFarm()
        else StopFarmLoops(); MonFarm=""; AF.Status="Idle" end
    end,
})
FarmTab:CreateToggle({
    Name="Auto Attack", CurrentValue=true, Flag="AutoAttack",
    Callback=function(v) AutoAttackOn=v end,
})

FarmTab:CreateSection("Range")
FarmTab:CreateToggle({
    Name="Infinite Range", CurrentValue=true, Flag="InfRange",
    Callback=function(v) InfRange=v end,
})
FarmTab:CreateSlider({
    Name="Attack Range", Range={10,500}, Increment=10,
    Suffix=" studs", CurrentValue=60, Flag="AtkRange",
    Callback=function(v) AttackRange=v end,
})
FarmTab:CreateToggle({
    Name="Hitbox Expand", CurrentValue=false, Flag="HitboxExpand",
    Callback=function(v) HitboxOn=v end,
})

FarmTab:CreateSection("Combat")
FarmTab:CreateToggle({
    Name="Auto Haki", CurrentValue=false, Flag="AutoHaki",
    Callback=function(v) AutoHakiOn=v end,
})

FarmTab:CreateSection("Status")
local StatusLabel = FarmTab:CreateLabel("Status: Idle")
local MobLabel    = FarmTab:CreateLabel("Mob: none")
local LvlLabel    = FarmTab:CreateLabel("Lvl: ? | HP: ?/?")
task.spawn(function()
    while true do
        task.wait(1)
        pcall(function()
            local h  = GetHum()
            local hp = h and math.floor(h.Health)   or 0
            local mx = h and math.floor(h.MaxHealth) or 0
            local lvl= "?"
            pcall(function() lvl=tostring(LocalPlayer.Data.Level.Value) end)
            StatusLabel:Set("Status: "..(AF.Status or "Idle"))
            MobLabel:Set("Mob: "..(Mon or "none"))
            LvlLabel:Set(("Lvl:%s | HP:%d/%d"):format(lvl,hp,mx))
        end)
    end
end)

-- ── Movement Tab ──────────────────────────────
local MoveTab = Window:CreateTab("Movement", 4483362458)
MoveTab:CreateSection("Speed")
MoveTab:CreateToggle({
    Name="Fast Walk", CurrentValue=false, Flag="FastWalk",
    Callback=function(v) SetWalkSpeed(v) end,
})
MoveTab:CreateSlider({
    Name="Walk Speed", Range={16,500}, Increment=10, Suffix=" sp",
    CurrentValue=100, Flag="WalkSpeed",
    Callback=function(v)
        WalkSpeedVal = v
        -- Immediately apply if walk speed is active
        if WalkSpeedOn then
            pcall(function()
                local h = GetHum()
                if h then h.WalkSpeed = WalkSpeedVal end
            end)
        end
    end,
})

MoveTab:CreateSection("Other")
MoveTab:CreateToggle({
    Name="Walk on Water", CurrentValue=false, Flag="WalkOnWater",
    Callback=function(v)
        WalkOnWater = v
        if not v then
            -- Restore water plane to original depth
            pcall(function()
                local map = workspace:FindFirstChild("Map"); if not map then return end
                local wb  = map:FindFirstChild("WaterBase-Plane"); if not wb then return end
                local origY = _waterOrigSize and _waterOrigSize.Y or 80
                wb.Size = Vector3.new(wb.Size.X, origY, wb.Size.Z)
            end)
        end
    end,
})
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

-- ── Teleport Tab ──────────────────────────────
local TPTab = Window:CreateTab("Teleport", 4483362458)

TPTab:CreateSection("Player Teleport")

local _selPlayer = "(none)"
local function GetPlayerNames()
    local n = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then table.insert(n, p.Name) end
    end
    return #n > 0 and n or {"(none)"}
end

-- Build initial list
local _initNames = GetPlayerNames()
_selPlayer = _initNames[1]

TPTab:CreateDropdown({
    Name="Select Player",
    Options=_initNames,
    CurrentOption=_initNames[1],
    Flag="TPPlayerDrop",
    -- Store selection — Rayfield passes a string
    Callback=function(v) _selPlayer = tostring(v) end,
})

TPTab:CreateButton({
    Name="Teleport to Player",
    -- Wrap in task.spawn: PortalTP yields (task.wait) which would
    -- block Rayfield's callback thread and cause errors
    Callback=function()
        task.spawn(function()
            if _selPlayer == "" or _selPlayer == "(none)" then return end
            local found
            for _, p in ipairs(Players:GetPlayers()) do
                if p.Name == _selPlayer and p ~= LocalPlayer then
                    found = p; break
                end
            end
            if not found then return end
            local char = found.Character; if not char then return end
            local th = char:FindFirstChild("HumanoidRootPart"); if not th then return end
            PortalTP(th.CFrame * CFrame.new(3, 0, 3))
        end)
    end,
})

TPTab:CreateButton({
    Name="Refresh List",
    Callback=function()
        local n = GetPlayerNames()
        _selPlayer = n[1]
        Rayfield:Notify({Title="FyZe Hub", Content="Refreshed. "..#n.." player(s).", Duration=2})
    end,
})

TPTab:CreateSection("Type Name")
local _typedName = ""
TPTab:CreateInput({
    Name="Player Name",
    Placeholder="Exact username...",
    ClearTextOnFocus=false,
    Flag="TypedTPName",
    Callback=function(v) _typedName = tostring(v) end,
})
TPTab:CreateButton({
    Name="Teleport to Typed Name",
    Callback=function()
        task.spawn(function()
            if _typedName == "" then return end
            local found = Players:FindFirstChild(_typedName)
            if not found or found == LocalPlayer then return end
            local char = found.Character; if not char then return end
            local th = char:FindFirstChild("HumanoidRootPart"); if not th then return end
            PortalTP(th.CFrame * CFrame.new(3, 0, 3))
        end)
    end,
})

TPTab:CreateSection("Quick")
TPTab:CreateButton({
    Name="To Sky",
    Callback=function()
        task.spawn(function()
            local h = GetHRP(); if not h then return end
            PortalTP(CFrame.new(h.Position.X, 9999, h.Position.Z))
        end)
    end,
})
TPTab:CreateButton({
    Name="To Ground",
    Callback=function()
        task.spawn(function()
            local h = GetHRP(); if not h then return end
            PortalTP(CFrame.new(h.Position.X, 5, h.Position.Z))
        end)
    end,
})
TPTab:CreateButton({
    Name="To Void",
    Callback=function()
        task.spawn(function()
            local h = GetHRP(); if not h then return end
            local hum = GetHum(); if not hum then return end
            NoCollide()
            hum:ChangeState(Enum.HumanoidStateType.FreeFalling)
            task.wait(0.05)
            h = GetHRP(); if not h then return end
            NoCollide()
            h.CFrame = CFrame.new(h.Position.X, -5000, h.Position.Z)
            task.wait(0.05)
            h = GetHRP()
            if h then h.CFrame = CFrame.new(h.Position.X, -5000, h.Position.Z) end
        end)
    end,
})

-- ── ESP Tab ───────────────────────────────────
local ESPTab = Window:CreateTab("ESP", 4483362458)
ESPTab:CreateSection("Player")
ESPTab:CreateToggle({Name="Player ESP",  CurrentValue=true,  Flag="ESPOn",     Callback=function(v) ESPOn=v end})
ESPTab:CreateToggle({Name="Show Names",  CurrentValue=true,  Flag="ESPNames",  Callback=function(v) ShowName=v end})
ESPTab:CreateToggle({Name="Show Health", CurrentValue=true,  Flag="ESPHealth", Callback=function(v) ShowHealth=v end})
ESPTab:CreateSection("World")
ESPTab:CreateToggle({
    Name="Fruit ESP", CurrentValue=false, Flag="FruitESP",
    Callback=function(v)
        FruitESPOn = v
        if v then ScanFruits() else ClearFruitBBs() end
    end,
})

-- ── Misc Tab ──────────────────────────────────
local MiscTab = Window:CreateTab("Misc", 4483362458)
MiscTab:CreateSection("Game")
MiscTab:CreateToggle({
    Name="Save Spawn Point", CurrentValue=false, Flag="SaveSpawn",
    Callback=function(v)
        if v then pcall(function() ReplicatedStorage.Remotes.CommF_:InvokeServer("SetSpawnPoint") end) end
    end,
})
MiscTab:CreateToggle({
    Name="Auto Haki Color", CurrentValue=false, Flag="HakiColor",
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
            "Enyu_is_Pro","JCWK","StarcodeHEO","MagicBus","KittGaming","Sub2CaptainMaui",
            "Sub2OfficalNoobie","TheGreatAce","Sub2NoobMaster123","Sub2Daigrock","Axiore",
            "StrawHatMaine","TantaiGaming","Bluxxy","SUB2GAMERROBOT_EXP1","Chandler",
            "NOMOREHACK","BANEXPLOIT","WildDares","BossBuild","GetPranked","EARN_FRUITS",
            "FIGHT4FRUIT","NOEXPLOITER","NOOB2ADMIN","CODESLIDE","ADMINHACKED","ADMINDARES",
            "fruitconcepts","krazydares","TRIPLEABUSE","SEATROLLING","24NOADMIN","REWARDFUN",
            "NEWTROLL","fudd10_v2","Fudd10","Bignews","SECRET_ADMIN",
        }
        for _, c in ipairs(codes) do
            pcall(function() ReplicatedStorage.Remotes.Redeem:InvokeServer(c) end)
        end
    end,
})

MiscTab:CreateSection("Stats")
MiscTab:CreateDropdown({
    Name="Auto Stats",
    Options={"Off","Melee","Defense","Sword","Gun","Fruit"},
    CurrentOption="Off",
    Flag="AutoStats",
    Callback=function(v)
        task.spawn(function()
            local m = {Melee="Melee",Defense="Defense",Sword="Sword",Gun="Gun",Fruit="Demon Fruit"}
            local sel = tostring(v)
            while sel ~= "Off" do
                pcall(function() ReplicatedStorage.Remotes.CommF_:InvokeServer("AddPoint",m[sel],3) end)
                task.wait(0.5)
                -- re-read in case toggle changed
                sel = tostring(v)
            end
        end)
    end,
})
