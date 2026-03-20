-- ══════════════════════════════════════════════
--  BF Hub | Rayfield UI | Delta Compatible
--  All Seas | Mobile Friendly
--  Fixed: sky glitch, NPC pull, attack toggle,
--         range slider, sky-method player TP
-- ══════════════════════════════════════════════

local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local VIM               = game:GetService("VirtualInputManager")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer       = Players.LocalPlayer

-- ── Rayfield Load ─────────────────────────────
local Rayfield
pcall(function()
    Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()
end)
if not Rayfield then
    local s = function() end
    local t = {CreateToggle=s,CreateSlider=s,CreateButton=s,
               CreateDropdown=s,CreateLabel=s,CreateSection=s}
    Rayfield = {CreateWindow=function() return setmetatable({},{
        __index=function() return function() return t end end}) end,
        Notify=s}
end

-- ══════════════════════════════════════════════
--  HELPERS
-- ══════════════════════════════════════════════
local function GetChar() return LocalPlayer.Character end
local function GetHRP()
    local c = GetChar()
    return c and c:FindFirstChild("HumanoidRootPart")
end
local function GetHum()
    local c = GetChar()
    return c and c:FindFirstChildOfClass("Humanoid")
end
local function SetCharNoCollide()
    local c = GetChar(); if not c then return end
    for _, p in ipairs(c:GetDescendants()) do
        if p:IsA("BasePart") then p.CanCollide = false end
    end
end

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

local AF     = {Active=false, _running=false, Status="Idle"}
local Mon, NameMon, NameQuest, LevelQuest, CFrameQuest, CFrameMon
local MonFarm       = ""
local attackTarget  = nil
local FarmAnchor    = Vector3.new(0,0,0)  -- fixed ground point, set once per NPC

local World1 = game.PlaceId == 2753915549
local World2 = game.PlaceId == 4442272183
local World3 = game.PlaceId == 7449423635

-- ══════════════════════════════════════════════
--  TELEPORT SYSTEM
-- ══════════════════════════════════════════════

-- Entrance portal map: if target is near an entrance zone, fire requestEntrance
local EntranceZones = {
    [2753915549] = {
        {zone=Vector3.new(-7894.6,5547.1,-380.3),   entry=Vector3.new(-7894.6,5547.1,-380.3)},
        {zone=Vector3.new(61163.9,11.7,1819.8),     entry=Vector3.new(61163.9,11.7,1819.8)},
        {zone=Vector3.new(-4607.8,872.5,-1667.6),   entry=Vector3.new(-4607.8,872.5,-1667.6)},
    },
    [4442272183] = {
        {zone=Vector3.new(923.2,127.0,32852.8),     entry=Vector3.new(923.2,127.0,32852.8)},
        {zone=Vector3.new(-6508.6,89.0,-132.8),     entry=Vector3.new(-6508.6,89.0,-132.8)},
    },
    [7449423635] = {
        {zone=Vector3.new(5657.9,1013.1,-335.5),    entry=Vector3.new(5657.9,1013.1,-335.5)},
        {zone=Vector3.new(-5075.5,314.5,-3150.0),   entry=Vector3.new(-5075.5,314.5,-3150.0)},
    },
}

local function CheckAndEnter(destPos)
    local hrp = GetHRP(); if not hrp then return end
    local zones = EntranceZones[game.PlaceId] or {}
    for _, z in ipairs(zones) do
        -- target is near this entrance, and we are not already inside
        if (destPos - z.zone).Magnitude < 1000
        and (hrp.Position - z.zone).Magnitude > 400 then
            pcall(function()
                ReplicatedStorage.Remotes.CommF_:InvokeServer("requestEntrance", z.entry)
            end)
            task.wait(0.6)
            return
        end
    end
end

--[[
    SkyTP(destCF)
    The "sky method":
      1. Teleport straight up to Y=9999 above destination XZ
      2. Handle entrance portals (server processes them while we're in sky)
      3. Drop to final destination
    This skips all floors and physics. No tween, no lerp, no glitch.
]]
local function SkyTP(destCF)
    local hrp = GetHRP(); if not hrp then return end
    local dest = destCF
    SetCharNoCollide()

    -- Step 1: Jump to sky above destination XZ
    hrp.CFrame = CFrame.new(dest.Position.X, 9999, dest.Position.Z)
    task.wait(0.07)

    -- Step 2: Entrance portal (while we're safely in sky)
    CheckAndEnter(dest.Position)
    task.wait(0.05)

    -- Step 3: Land at destination
    hrp = GetHRP(); if not hrp then return end
    hrp.CFrame = dest
    task.wait(0.05)
    SetCharNoCollide()
end

-- ══════════════════════════════════════════════
--  ATTACK (no-cooldown, server-side)
-- ══════════════════════════════════════════════
local function FindEnemiesInRange(tbl, enemies)
    local c = LocalPlayer.Character; if not c then return nil end
    local origin = c:GetPivot().Position
    local range  = InfRange and math.huge or AttackRange
    local last   = nil
    for _, e in ipairs(enemies) do
        if not e:GetAttribute("IsBoat")
           and e:FindFirstChildOfClass("Humanoid")
           and e.Humanoid.Health > 0 then
            local head = e:FindFirstChild("Head")
            if head and (origin - head.Position).Magnitude <= range then
                table.insert(tbl, {e, head})
                last = head
            end
        end
    end
    return last
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
    local hits    = {}
    local en      = workspace:FindFirstChild("Enemies")
    local enemies = en and en:GetChildren() or {}
    local last    = FindEnemiesInRange(hits, enemies)
    if not last or not GetEquippedTool() then return end
    pcall(function()
        local net    = ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Net")
        local regAtk = net:WaitForChild("RE/RegisterAttack")
        local regHit = net:WaitForChild("RE/RegisterHit")
        if #hits > 0 then
            regAtk:FireServer(1e-9)
            regHit:FireServer(last, hits)
        end
    end)
end

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
                VIM:SendKeyEvent(true, Enum.KeyCode.W, false, game)
                task.wait(0.1)
                VIM:SendKeyEvent(false, Enum.KeyCode.W, false, game)
            end)
        end
    end
end)

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
                if e:FindFirstChild("Head") then e.Head.CanCollide = false end
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
    bb.AlwaysOnTop=true; bb.Size=UDim2.new(0,180,0,40)
    bb.StudsOffset=Vector3.new(0,6,0); bb.Adornee=adornee
    bb.Parent=game:GetService("CoreGui")
    local l=Instance.new("TextLabel",bb)
    l.BackgroundTransparency=1; l.Size=UDim2.new(1,0,1,0)
    l.Text="🍎 "..label; l.TextColor3=Color3.fromRGB(255,215,0)
    l.Font=Enum.Font.GothamBold; l.TextSize=14
    l.TextStrokeTransparency=0.2; l.TextStrokeColor3=Color3.new(0,0,0)
    FruitBBs[adornee]=bb
    adornee.AncestryChanged:Connect(function()
        if not adornee.Parent then
            pcall(function() bb:Destroy() end)
            FruitBBs[adornee]=nil
        end
    end)
end
local function ClearFruitBBs()
    for a,bb in pairs(FruitBBs) do pcall(function() bb:Destroy() end); FruitBBs[a]=nil end
end
local function ScanFruits()
    if not FruitESPOn then return end
    local function TryTag(obj)
        if not string.find(string.lower(obj.Name),"fruit") then return end
        local adornee
        if obj:IsA("Tool")        then adornee = obj:FindFirstChild("Handle") or obj.PrimaryPart
        elseif obj:IsA("Model")   then adornee = obj.PrimaryPart or obj:FindFirstChildOfClass("BasePart")
        elseif obj:IsA("BasePart") then adornee = obj end
        if adornee then MakeFruitBB(adornee, obj.Name) end
    end
    for _, obj in ipairs(workspace:GetChildren()) do TryTag(obj) end
    for _, fname in ipairs({"Fruits","DevilFruits","DroppedFruits"}) do
        local f=workspace:FindFirstChild(fname)
        if f then for _, obj in ipairs(f:GetChildren()) do TryTag(obj) end end
    end
end
workspace.DescendantAdded:Connect(function(obj)
    if FruitESPOn and obj:IsA("Tool") and string.find(string.lower(obj.Name),"fruit") then
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

-- ══════════════════════════════════════════════
--  PLAYER ESP
-- ══════════════════════════════════════════════
local ESPObj={}
local ESPCfg={NC=Color3.fromRGB(255,255,255),HC=Color3.fromRGB(80,255,120),LC=Color3.fromRGB(255,60,60)}
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
        nl.TextColor3=ESPCfg.NC; nl.TextStrokeTransparency=0.5
        nl.Font=Enum.Font.GothamBold; nl.TextSize=14; nl.Text=p.Name
        local hl=Instance.new("TextLabel",bb)
        hl.BackgroundTransparency=1; hl.Size=UDim2.new(1,0,.5,0)
        hl.Position=UDim2.new(0,0,.5,0); hl.TextStrokeTransparency=0.5
        hl.Font=Enum.Font.Gotham; hl.TextSize=14
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
            hl.TextColor3=(hp/mx)>0.4 and ESPCfg.HC or ESPCfg.LC
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

-- ══════════════════════════════════════════════
--  QUEST DATA
-- ══════════════════════════════════════════════
local function CheckQuest()
    local ok,lvl=pcall(function() return LocalPlayer.Data.Level.Value end)
    lvl=ok and lvl or 0
    if World1 then
        if     lvl<=9   then Mon="Bandit"              LevelQuest=1 NameQuest="BanditQuest1"   NameMon="Bandit"              CFrameQuest=CFrame.new(1059,15,1550)     CFrameMon=CFrame.new(1046,27,1561)
        elseif lvl<=14  then Mon="Monkey"              LevelQuest=1 NameQuest="JungleQuest"    NameMon="Monkey"              CFrameQuest=CFrame.new(-1598,35,153)     CFrameMon=CFrame.new(-1449,68,11)
        elseif lvl<=29  then Mon="Gorilla"             LevelQuest=2 NameQuest="JungleQuest"    NameMon="Gorilla"             CFrameQuest=CFrame.new(-1598,35,153)     CFrameMon=CFrame.new(-1130,40,-525)
        elseif lvl<=39  then Mon="Pirate"              LevelQuest=1 NameQuest="BuggyQuest1"    NameMon="Pirate"              CFrameQuest=CFrame.new(-1141,4,3832)     CFrameMon=CFrame.new(-1104,14,3896)
        elseif lvl<=59  then Mon="Brute"               LevelQuest=2 NameQuest="BuggyQuest1"    NameMon="Brute"               CFrameQuest=CFrame.new(-1141,4,3832)     CFrameMon=CFrame.new(-1140,15,4323)
        elseif lvl<=74  then Mon="Desert Bandit"       LevelQuest=1 NameQuest="DesertQuest"    NameMon="Desert Bandit"       CFrameQuest=CFrame.new(894,5,4392)       CFrameMon=CFrame.new(925,6,4482)
        elseif lvl<=89  then Mon="Desert Officer"      LevelQuest=2 NameQuest="DesertQuest"    NameMon="Desert Officer"      CFrameQuest=CFrame.new(894,5,4392)       CFrameMon=CFrame.new(1608,9,4371)
        elseif lvl<=99  then Mon="Snow Bandit"         LevelQuest=1 NameQuest="SnowQuest"      NameMon="Snow Bandit"         CFrameQuest=CFrame.new(1390,88,-1299)    CFrameMon=CFrame.new(1354,87,-1394)
        elseif lvl<=119 then Mon="Snowman"             LevelQuest=2 NameQuest="SnowQuest"      NameMon="Snowman"             CFrameQuest=CFrame.new(1390,88,-1299)    CFrameMon=CFrame.new(1202,145,-1550)
        elseif lvl<=149 then Mon="Chief Petty Officer" LevelQuest=1 NameQuest="MarineQuest2"   NameMon="Chief Petty Officer" CFrameQuest=CFrame.new(-5040,27,4325)    CFrameMon=CFrame.new(-4881,23,4274)
        elseif lvl<=174 then Mon="Sky Bandit"          LevelQuest=1 NameQuest="SkyQuest"       NameMon="Sky Bandit"          CFrameQuest=CFrame.new(-4840,716,-2619)  CFrameMon=CFrame.new(-4953,296,-2899)
        elseif lvl<=189 then Mon="Dark Master"         LevelQuest=2 NameQuest="SkyQuest"       NameMon="Dark Master"         CFrameQuest=CFrame.new(-4840,716,-2619)  CFrameMon=CFrame.new(-5260,391,-2229)
        elseif lvl<=209 then Mon="Prisoner"            LevelQuest=1 NameQuest="PrisonerQuest"  NameMon="Prisoner"            CFrameQuest=CFrame.new(5309,2,475)       CFrameMon=CFrame.new(5099,0,474)
        elseif lvl<=249 then Mon="Dangerous Prisoner"  LevelQuest=2 NameQuest="PrisonerQuest"  NameMon="Dangerous Prisoner"  CFrameQuest=CFrame.new(5309,2,475)       CFrameMon=CFrame.new(5655,16,866)
        elseif lvl<=274 then Mon="Toga Warrior"        LevelQuest=1 NameQuest="ColosseumQuest" NameMon="Toga Warrior"        CFrameQuest=CFrame.new(-1580,6,-2986)    CFrameMon=CFrame.new(-1820,52,-2741)
        elseif lvl<=299 then Mon="Gladiator"           LevelQuest=2 NameQuest="ColosseumQuest" NameMon="Gladiator"           CFrameQuest=CFrame.new(-1580,6,-2986)    CFrameMon=CFrame.new(-1293,56,-3339)
        elseif lvl<=324 then Mon="Military Soldier"    LevelQuest=1 NameQuest="MagmaQuest"     NameMon="Military Soldier"    CFrameQuest=CFrame.new(-5313,11,8515)    CFrameMon=CFrame.new(-5411,11,8454)
        elseif lvl<=374 then Mon="Military Spy"        LevelQuest=2 NameQuest="MagmaQuest"     NameMon="Military Spy"        CFrameQuest=CFrame.new(-5313,11,8515)    CFrameMon=CFrame.new(-5803,86,8829)
        elseif lvl<=399 then Mon="Fishman Warrior"     LevelQuest=1 NameQuest="FishmanQuest"   NameMon="Fishman Warrior"     CFrameQuest=CFrame.new(61123,18,1569)    CFrameMon=CFrame.new(60878,18,1544)
        elseif lvl<=449 then Mon="Fishman Commando"    LevelQuest=2 NameQuest="FishmanQuest"   NameMon="Fishman Commando"    CFrameQuest=CFrame.new(61123,18,1569)    CFrameMon=CFrame.new(61923,18,1494)
        elseif lvl<=474 then Mon="God's Guard"         LevelQuest=1 NameQuest="SkyExp1Quest"   NameMon="God's Guard"         CFrameQuest=CFrame.new(-4722,844,-1950)  CFrameMon=CFrame.new(-4710,845,-1927)
        elseif lvl<=524 then Mon="Shanda"              LevelQuest=2 NameQuest="SkyExp1Quest"   NameMon="Shanda"              CFrameQuest=CFrame.new(-7859,5544,-381)  CFrameMon=CFrame.new(-7678,5566,-497)
        elseif lvl<=549 then Mon="Royal Squad"         LevelQuest=1 NameQuest="SkyExp2Quest"   NameMon="Royal Squad"         CFrameQuest=CFrame.new(-7907,5635,-1412) CFrameMon=CFrame.new(-7624,5658,-1467)
        elseif lvl<=624 then Mon="Royal Soldier"       LevelQuest=2 NameQuest="SkyExp2Quest"   NameMon="Royal Soldier"       CFrameQuest=CFrame.new(-7907,5635,-1412) CFrameMon=CFrame.new(-7837,5646,-1791)
        elseif lvl<=649 then Mon="Galley Pirate"       LevelQuest=1 NameQuest="FountainQuest"  NameMon="Galley Pirate"       CFrameQuest=CFrame.new(5260,37,4050)     CFrameMon=CFrame.new(5551,79,3930)
        else                 Mon="Galley Captain"      LevelQuest=2 NameQuest="FountainQuest"  NameMon="Galley Captain"      CFrameQuest=CFrame.new(5260,37,4050)     CFrameMon=CFrame.new(5442,43,4950)
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
        if     lvl<=1524 then Mon="Pirate Millionaire"    LevelQuest=1 NameQuest="PiratePortQuest"   NameMon="Pirate Millionaire"    CFrameQuest=CFrame.new(-450,108,5951)    CFrameMon=CFrame.new(-246,47,5584)
        elseif lvl<=1574 then Mon="Pistol Billionaire"    LevelQuest=2 NameQuest="PiratePortQuest"   NameMon="Pistol Billionaire"    CFrameQuest=CFrame.new(-450,108,5951)    CFrameMon=CFrame.new(-55,84,5948)
        elseif lvl<=1599 then Mon="Dragon Crew Warrior"   LevelQuest=1 NameQuest="DragonCrewQuest"   NameMon="Dragon Crew Warrior"   CFrameQuest=CFrame.new(6750,127,-711)    CFrameMon=CFrame.new(6710,52,-1139)
        elseif lvl<=1624 then Mon="Dragon Crew Archer"    LevelQuest=2 NameQuest="DragonCrewQuest"   NameMon="Dragon Crew Archer"    CFrameQuest=CFrame.new(6750,127,-711)    CFrameMon=CFrame.new(6669,481,329)
        elseif lvl<=1649 then Mon="Hydra Enforcer"        LevelQuest=1 NameQuest="VenomCrewQuest"    NameMon="Hydra Enforcer"        CFrameQuest=CFrame.new(5206,1004,748)    CFrameMon=CFrame.new(4547,1003,334)
        elseif lvl<=1699 then Mon="Venomous Assailant"    LevelQuest=2 NameQuest="VenomCrewQuest"    NameMon="Venomous Assailant"    CFrameQuest=CFrame.new(5206,1004,748)    CFrameMon=CFrame.new(4675,1135,996)
        elseif lvl<=1724 then Mon="Marine Commodore"      LevelQuest=1 NameQuest="MarineTreeIsland"  NameMon="Marine Commodore"      CFrameQuest=CFrame.new(2481,74,-6780)    CFrameMon=CFrame.new(2577,76,-7740)
        elseif lvl<=1774 then Mon="Marine Rear Admiral"   LevelQuest=2 NameQuest="MarineTreeIsland"  NameMon="Marine Rear Admiral"   CFrameQuest=CFrame.new(2481,74,-6780)    CFrameMon=CFrame.new(3762,124,-6824)
        elseif lvl<=1799 then Mon="Fishman Raider"        LevelQuest=1 NameQuest="DeepForestIsland3" NameMon="Fishman Raider"        CFrameQuest=CFrame.new(-10582,331,-8761) CFrameMon=CFrame.new(-10408,332,-8369)
        elseif lvl<=1824 then Mon="Fishman Captain"       LevelQuest=2 NameQuest="DeepForestIsland3" NameMon="Fishman Captain"       CFrameQuest=CFrame.new(-10582,331,-8761) CFrameMon=CFrame.new(-10995,352,-9002)
        elseif lvl<=1849 then Mon="Forest Pirate"         LevelQuest=1 NameQuest="DeepForestIsland"  NameMon="Forest Pirate"         CFrameQuest=CFrame.new(-13234,331,-7625) CFrameMon=CFrame.new(-13274,332,-7770)
        elseif lvl<=1899 then Mon="Mythological Pirate"   LevelQuest=2 NameQuest="DeepForestIsland"  NameMon="Mythological Pirate"   CFrameQuest=CFrame.new(-13234,331,-7625) CFrameMon=CFrame.new(-13681,501,-6991)
        elseif lvl<=1924 then Mon="Jungle Pirate"         LevelQuest=1 NameQuest="DeepForestIsland2" NameMon="Jungle Pirate"         CFrameQuest=CFrame.new(-12680,390,-9902) CFrameMon=CFrame.new(-12256,332,-10486)
        elseif lvl<=1974 then Mon="Musketeer Pirate"      LevelQuest=2 NameQuest="DeepForestIsland2" NameMon="Musketeer Pirate"      CFrameQuest=CFrame.new(-12680,390,-9902) CFrameMon=CFrame.new(-13458,392,-9859)
        elseif lvl<=1999 then Mon="Reborn Skeleton"       LevelQuest=1 NameQuest="HauntedQuest1"     NameMon="Reborn Skeleton"       CFrameQuest=CFrame.new(-9479,141,5566)   CFrameMon=CFrame.new(-8764,166,6160)
        elseif lvl<=2024 then Mon="Living Zombie"         LevelQuest=2 NameQuest="HauntedQuest1"     NameMon="Living Zombie"         CFrameQuest=CFrame.new(-9479,141,5566)   CFrameMon=CFrame.new(-10144,139,5838)
        elseif lvl<=2049 then Mon="Demonic Soul"          LevelQuest=1 NameQuest="HauntedQuest2"     NameMon="Demonic Soul"          CFrameQuest=CFrame.new(-9517,172,6078)   CFrameMon=CFrame.new(-9506,172,6159)
        elseif lvl<=2074 then Mon="Posessed Mummy"        LevelQuest=2 NameQuest="HauntedQuest2"     NameMon="Posessed Mummy"        CFrameQuest=CFrame.new(-9517,172,6078)   CFrameMon=CFrame.new(-9582,6,6205)
        elseif lvl<=2099 then Mon="Peanut Scout"          LevelQuest=1 NameQuest="NutsIslandQuest"   NameMon="Peanut Scout"          CFrameQuest=CFrame.new(-2104,38,-10194)  CFrameMon=CFrame.new(-2143,48,-10030)
        elseif lvl<=2124 then Mon="Peanut President"      LevelQuest=2 NameQuest="NutsIslandQuest"   NameMon="Peanut President"      CFrameQuest=CFrame.new(-2104,38,-10194)  CFrameMon=CFrame.new(-1859,38,-10422)
        elseif lvl<=2149 then Mon="Ice Cream Chef"        LevelQuest=1 NameQuest="IceCreamIslandQuest" NameMon="Ice Cream Chef"      CFrameQuest=CFrame.new(-821,66,-10966)   CFrameMon=CFrame.new(-872,66,-10920)
        elseif lvl<=2199 then Mon="Ice Cream Commander"   LevelQuest=2 NameQuest="IceCreamIslandQuest" NameMon="Ice Cream Commander" CFrameQuest=CFrame.new(-821,66,-10966)   CFrameMon=CFrame.new(-558,112,-11291)
        elseif lvl<=2224 then Mon="Cookie Crafter"        LevelQuest=1 NameQuest="CakeQuest1"        NameMon="Cookie Crafter"        CFrameQuest=CFrame.new(-2021,38,-12029)  CFrameMon=CFrame.new(-2374,38,-12125)
        elseif lvl<=2249 then Mon="Cake Guard"            LevelQuest=2 NameQuest="CakeQuest1"        NameMon="Cake Guard"            CFrameQuest=CFrame.new(-2021,38,-12029)  CFrameMon=CFrame.new(-1598,44,-12245)
        elseif lvl<=2274 then Mon="Baking Staff"          LevelQuest=1 NameQuest="CakeQuest2"        NameMon="Baking Staff"          CFrameQuest=CFrame.new(-1928,38,-12843)  CFrameMon=CFrame.new(-1888,78,-12998)
        elseif lvl<=2299 then Mon="Head Baker"            LevelQuest=2 NameQuest="CakeQuest2"        NameMon="Head Baker"            CFrameQuest=CFrame.new(-1928,38,-12843)  CFrameMon=CFrame.new(-2216,83,-12869)
        elseif lvl<=2324 then Mon="Cocoa Warrior"         LevelQuest=1 NameQuest="ChocQuest1"        NameMon="Cocoa Warrior"         CFrameQuest=CFrame.new(233,30,-12201)    CFrameMon=CFrame.new(-22,81,-12352)
        elseif lvl<=2349 then Mon="Chocolate Bar Battler" LevelQuest=2 NameQuest="ChocQuest1"        NameMon="Chocolate Bar Battler" CFrameQuest=CFrame.new(233,30,-12201)    CFrameMon=CFrame.new(583,77,-12463)
        elseif lvl<=2374 then Mon="Sweet Thief"           LevelQuest=1 NameQuest="ChocQuest2"        NameMon="Sweet Thief"           CFrameQuest=CFrame.new(151,31,-12775)    CFrameMon=CFrame.new(165,76,-12601)
        elseif lvl<=2399 then Mon="Candy Rebel"           LevelQuest=2 NameQuest="ChocQuest2"        NameMon="Candy Rebel"           CFrameQuest=CFrame.new(151,31,-12775)    CFrameMon=CFrame.new(135,77,-12877)
        elseif lvl<=2424 then Mon="Candy Pirate"          LevelQuest=1 NameQuest="CandyQuest1"       NameMon="Candy Pirate"          CFrameQuest=CFrame.new(-1150,20,-14446)  CFrameMon=CFrame.new(-1311,26,-14562)
        elseif lvl<=2449 then Mon="Snow Demon"            LevelQuest=2 NameQuest="CandyQuest1"       NameMon="Snow Demon"            CFrameQuest=CFrame.new(-1150,20,-14446)  CFrameMon=CFrame.new(-880,71,-14539)
        elseif lvl<=2474 then Mon="Isle Outlaw"           LevelQuest=1 NameQuest="TikiQuest1"        NameMon="Isle Outlaw"           CFrameQuest=CFrame.new(-16548,61,-173)   CFrameMon=CFrame.new(-16443,116,-264)
        elseif lvl<=2524 then Mon="Island Boy"            LevelQuest=2 NameQuest="TikiQuest1"        NameMon="Island Boy"            CFrameQuest=CFrame.new(-16548,61,-173)   CFrameMon=CFrame.new(-16901,84,-193)
        elseif lvl<=2549 then Mon="Isle Champion"         LevelQuest=2 NameQuest="TikiQuest2"        NameMon="Isle Champion"         CFrameQuest=CFrame.new(-16539,56,1052)   CFrameMon=CFrame.new(-16642,236,1031)
        elseif lvl<=2574 then Mon="Serpent Hunter"        LevelQuest=1 NameQuest="TikiQuest3"        NameMon="Serpent Hunter"        CFrameQuest=CFrame.new(-16665,105,1580)  CFrameMon=CFrame.new(-16521,106,1489)
        else                   Mon="Skull Slayer"         LevelQuest=2 NameQuest="TikiQuest3"        NameMon="Skull Slayer"          CFrameQuest=CFrame.new(-16665,105,1580)  CFrameMon=CFrame.new(-16855,122,1478)
        end
    end
end

-- ══════════════════════════════════════════════
--  AUTO FARM ENGINE
-- ══════════════════════════════════════════════
--[[
  ROOT CAUSE OF SKY GLITCH (now fixed):
  ─────────────────────────────────────
  Old design: Player hovers above NPC → NPC is pulled to player →
  player re-hovers above new NPC position → feedback loop → both fly.

  New design:
  • FarmAnchor = the NPC's world position at the MOMENT we find it.
                 This is a FIXED Vector3 that never changes mid-kill.
  • PULL LOOP:  snaps all NPCs to FarmAnchor every frame.
  • HOVER LOOP: locks player to FarmAnchor.X, FarmAnchor.Y + HOVER_H, FarmAnchor.Z
                (a fixed absolute Y — cannot drift upward).
  • Because both the NPCs and player are pinned to fixed coordinates,
    there is zero feedback and no possibility of flying upward.
]]

local HOVER_H   = 14        -- studs above FarmAnchor.Y where player sits
local _pullConn  = nil
local _hoverConn = nil

local function StopPull()
    if _pullConn  then _pullConn:Disconnect();  _pullConn=nil  end
end
local function StopHover()
    if _hoverConn then _hoverConn:Disconnect(); _hoverConn=nil end
end
local function StopFarmLoops()
    StopPull(); StopHover()
    attackTarget=nil; MonFarm=""
end

-- Pull every matching NPC to the fixed FarmAnchor
local function StartPull()
    StopPull()
    local anchorCF = CFrame.new(FarmAnchor)   -- captured once, never changes
    _pullConn = RunService.Heartbeat:Connect(function()
        if not AF.Active then StopPull(); return end
        pcall(function()
            local en = workspace:FindFirstChild("Enemies"); if not en then return end
            for _, e in ipairs(en:GetChildren()) do
                if (e.Name == MonFarm or e.Name == Mon)
                    and e:FindFirstChild("HumanoidRootPart")
                    and e:FindFirstChildOfClass("Humanoid")
                    and e.Humanoid.Health > 0 then
                    local er = e.HumanoidRootPart
                    er.CFrame    = anchorCF      -- pin to fixed point
                    er.Velocity  = Vector3.zero
                    local s = InfRange and 999 or math.max(AttackRange,30)
                    er.Size      = Vector3.new(s,s,s)
                    er.CanCollide = false
                    e.Humanoid.WalkSpeed = 0
                    e.Humanoid.JumpPower = 0
                    if e:FindFirstChild("Head") then e.Head.CanCollide = false end
                    if e.Humanoid:FindFirstChild("Animator") then
                        e.Humanoid.Animator:Destroy()
                    end
                    pcall(function() sethiddenproperty(LocalPlayer,"SimulationRadius",math.huge) end)
                end
            end
        end)
    end)
end

-- Lock player to a fixed Y above FarmAnchor
local function StartHover()
    StopHover()
    -- Compute the fixed hover position ONCE from the immutable FarmAnchor
    local hoverPos = Vector3.new(FarmAnchor.X, FarmAnchor.Y + HOVER_H, FarmAnchor.Z)
    _hoverConn = RunService.Heartbeat:Connect(function()
        if not AF.Active then StopHover(); return end
        local hrp = GetHRP(); if not hrp then return end
        -- Only correct if we drift more than 2 studs (prevents micro-jitter)
        if (hrp.Position - hoverPos).Magnitude > 2 then
            hrp.CFrame = CFrame.new(hoverPos)
        end
        SetCharNoCollide()
        pcall(function() sethiddenproperty(LocalPlayer,"SimulationRadius",math.huge) end)
    end)
end

local function PrepNPC(e)
    local er = e:FindFirstChild("HumanoidRootPart"); if not er then return end
    local s = InfRange and 999 or math.max(AttackRange,30)
    er.Size       = Vector3.new(s,s,s)
    er.CanCollide = false
    e.Humanoid.WalkSpeed = 0
    e.Humanoid.JumpPower = 0
    if e:FindFirstChild("Head") then e.Head.CanCollide = false end
    if e.Humanoid:FindFirstChild("Animator") then e.Humanoid.Animator:Destroy() end
end

local function RunAutoFarm()
    if AF._running then return end
    AF._running = true

    task.spawn(function()
        while AF.Active do
            pcall(function()

                -- ① Death check
                local hum = GetHum()
                if not hum or hum.Health <= 0 then
                    AF.Status = "Dead... waiting"
                    StopFarmLoops()
                    task.wait(4); return
                end

                -- ② Refresh quest
                CheckQuest()
                if not Mon then task.wait(0.5); return end

                local qGui = LocalPlayer.PlayerGui:FindFirstChild("Main")
                local qVis = qGui and qGui:FindFirstChild("Quest") and qGui.Quest.Visible

                -- ③ No quest → sky-hop to NPC and accept
                if not qVis then
                    StopFarmLoops()
                    AF.Status = "Accepting quest..."
                    SkyTP(CFrameQuest)
                    task.wait(0.5)
                    local hrp = GetHRP()
                    if hrp and (CFrameQuest.Position - hrp.Position).Magnitude <= 30 then
                        pcall(function()
                            ReplicatedStorage.Remotes.CommF_:InvokeServer("StartQuest",NameQuest,LevelQuest)
                        end)
                        task.wait(0.8)
                    end
                    return
                end

                -- ④ Wrong quest → abandon
                local title = qGui.Quest.Container.QuestTitle.Title.Text
                if not string.find(title, NameMon or "") then
                    StopFarmLoops()
                    pcall(function() ReplicatedStorage.Remotes.CommF_:InvokeServer("AbandonQuest") end)
                    task.wait(0.3); return
                end

                -- ⑤ Find target NPC in Enemies folder
                local en = workspace:FindFirstChild("Enemies")
                if not en then task.wait(0.5); return end
                local target = nil
                for _, e in ipairs(en:GetChildren()) do
                    if e.Name == Mon
                       and e:FindFirstChild("HumanoidRootPart")
                       and e:FindFirstChildOfClass("Humanoid")
                       and e.Humanoid.Health > 0 then
                        target = e; break
                    end
                end

                -- ⑥ No NPC → sky-hop to spawn zone
                if not target then
                    StopFarmLoops()
                    AF.Status = "Finding mob..."
                    SkyTP(CFrameMon)
                    task.wait(1.5); return
                end

                -- ⑦ Target found — LOCK anchor to NPC's current position
                local er = target:FindFirstChild("HumanoidRootPart")
                if not er then task.wait(0.2); return end

                -- Set FarmAnchor ONCE — this is the immutable ground point
                FarmAnchor   = Vector3.new(er.Position.X, er.Position.Y, er.Position.Z)
                MonFarm      = target.Name
                attackTarget = target
                PrepNPC(target)
                AutoHaki()
                EquipWeapon(GetWeaponName())

                -- Sky-hop player to hover position directly
                local hrp = GetHRP()
                if hrp and (er.Position - hrp.Position).Magnitude > 8 then
                    AF.Status = "Flying to mob..."
                    local hoverPos = Vector3.new(FarmAnchor.X, FarmAnchor.Y + HOVER_H, FarmAnchor.Z)
                    -- Jump to sky above hover point, then drop to hover
                    hrp.CFrame = CFrame.new(FarmAnchor.X, 9999, FarmAnchor.Z)
                    task.wait(0.06)
                    SetCharNoCollide()
                    hrp = GetHRP()
                    if hrp then hrp.CFrame = CFrame.new(hoverPos) end
                    task.wait(0.05)
                    SetCharNoCollide()
                end

                AF.Status = "Farming: " .. Mon

                -- Start both Heartbeat loops (both anchored to fixed FarmAnchor)
                StartHover()
                StartPull()

                -- ⑧ Attack until dead
                local ticks = 0
                while AF.Active
                      and target and target.Parent
                      and target:FindFirstChildOfClass("Humanoid")
                      and target.Humanoid.Health > 0 do
                    AttackNoCoolDown()
                    pcall(function() PrepNPC(target) end)
                    task.wait(0.08)
                    ticks = ticks + 1
                    if ticks % 25 == 0 then
                        local qv = qGui and qGui:FindFirstChild("Quest") and qGui.Quest.Visible
                        if not qv then break end
                    end
                end

                -- Done with this NPC
                StopHover(); StopPull()
                attackTarget=nil; MonFarm=""
                task.wait(0.15)
            end)

            task.wait(0.1)
        end

        -- Cleanup when toggled off
        StopHover(); StopPull()
        attackTarget=nil; MonFarm=""
        AF.Status   = "Idle"
        AF._running = false
    end)
end

-- ══════════════════════════════════════════════
--  RAYFIELD UI
-- ══════════════════════════════════════════════
local Window = Rayfield:CreateWindow({
    Name             = "🍎 BF Hub",
    LoadingTitle     = "BF Hub",
    LoadingSubtitle  = "Delta | All Seas | Fixed",
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
    Name="Weapon Type",Options={"Melee","Sword","Gun","Blox Fruit"},
    CurrentOption="Melee",Flag="Weapon",
    Callback=function(v) SelectWeapon=v end,
})

FarmTab:CreateSection("Auto Farm")
FarmTab:CreateToggle({
    Name="Auto Farm",CurrentValue=false,Flag="AutoFarm",
    Callback=function(v)
        AF.Active=v
        if v then RunAutoFarm()
        else
            StopHover(); StopPull()
            attackTarget=nil; MonFarm=""
            AF.Status="Idle"
        end
    end,
})

FarmTab:CreateToggle({
    Name="Auto Attack",CurrentValue=true,Flag="AutoAttack",
    Callback=function(v) AutoAttackOn=v end,
})

FarmTab:CreateSection("Range & Hitbox")
FarmTab:CreateToggle({
    Name="Infinite Range",CurrentValue=true,Flag="InfRange",
    Callback=function(v) InfRange=v end,
})
FarmTab:CreateSlider({
    Name="Attack Range (when Inf OFF)",Range={10,500},Increment=10,
    Suffix=" studs",CurrentValue=60,Flag="AtkRange",
    Callback=function(v) AttackRange=v end,
})
FarmTab:CreateToggle({
    Name="Hitbox Expand",CurrentValue=false,Flag="HitboxExpand",
    Callback=function(v) HitboxOn=v end,
})

FarmTab:CreateSection("Combat")
FarmTab:CreateToggle({
    Name="Auto Haki (12s)",CurrentValue=false,Flag="AutoHaki",
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
            local h=GetHum()
            local hp=h and math.floor(h.Health) or 0
            local mx=h and math.floor(h.MaxHealth) or 0
            local lvl="?" pcall(function() lvl=tostring(LocalPlayer.Data.Level.Value) end)
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
    Name="Fast Walk",CurrentValue=false,Flag="FastWalk",
    Callback=function(v) ApplyWalkSpeed(v) end,
})
MoveTab:CreateSlider({
    Name="Walk Speed",Range={16,500},Increment=10,Suffix=" sp",
    CurrentValue=100,Flag="WalkSpeed",
    Callback=function(v) WalkSpeedVal=v if WalkSpeedOn then ApplyWalkSpeed(true) end end,
})
MoveTab:CreateSection("Other")
MoveTab:CreateToggle({
    Name="Anti AFK",CurrentValue=false,Flag="AntiAFK",
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

TPTab:CreateSection("Player TP — Sky Method")
local _pnames = {"(none)"}
local function RebuildPlayerList()
    _pnames={}
    for _,p in ipairs(Players:GetPlayers()) do
        if p~=LocalPlayer then table.insert(_pnames,p.Name) end
    end
    if #_pnames==0 then _pnames={"(none)"} end
end
RebuildPlayerList()

local TPDrop = TPTab:CreateDropdown({
    Name="Select Player",Options=_pnames,CurrentOption=_pnames[1],
    Flag="TPPlayerSelect",Callback=function() end,
})

TPTab:CreateButton({
    Name="⚡ TP to Player (Sky Method)",
    Callback=function()
        local name=TPDrop.CurrentOption
        if name=="(none)" then return end
        local tp=Players:FindFirstChild(name)
        if tp and tp.Character then
            local th=tp.Character:FindFirstChild("HumanoidRootPart")
            if th then SkyTP(th.CFrame * CFrame.new(2,0,2)) end
        else
            Rayfield:Notify({Title="BF Hub",Content="Player not found.",Duration=2})
        end
    end,
})
TPTab:CreateButton({
    Name="🔄 Refresh Player List",
    Callback=function()
        RebuildPlayerList()
        Rayfield:Notify({Title="BF Hub",Content=#_pnames.." player(s) found.",Duration=2})
    end,
})

TPTab:CreateSection("Quick TPs")
TPTab:CreateButton({
    Name="⬆️ To Sky (Y=9999)",
    Callback=function()
        local h=GetHRP(); if not h then return end
        h.CFrame=CFrame.new(h.Position.X,9999,h.Position.Z)
    end,
})
TPTab:CreateButton({
    Name="⬇️ To Ground (Y=5)",
    Callback=function()
        local h=GetHRP(); if not h then return end
        h.CFrame=CFrame.new(h.Position.X,5,h.Position.Z)
    end,
})
TPTab:CreateButton({
    Name="🕳️ Void (Y=-5000)",
    Callback=function()
        local h=GetHRP(); if not h then return end
        SetCharNoCollide()
        -- Sky method to avoid getting blocked by terrain on the way down
        h.CFrame=CFrame.new(h.Position.X,9999,h.Position.Z)
        task.wait(0.06)
        h=GetHRP(); if not h then return end
        SetCharNoCollide()
        h.CFrame=CFrame.new(h.Position.X,-5000,h.Position.Z)
    end,
})

-- ──────────────────────────────────────────────
--  TAB: ESP
-- ──────────────────────────────────────────────
local ESPTab = Window:CreateTab("👁️ ESP", 4483362458)
ESPTab:CreateSection("Player")
ESPTab:CreateToggle({Name="Player ESP",CurrentValue=true,Flag="ESPOn",Callback=function(v) ESPOn=v end})
ESPTab:CreateToggle({Name="Show Names",CurrentValue=true,Flag="ESPNames",Callback=function(v) ShowName=v end})
ESPTab:CreateToggle({Name="Show Health",CurrentValue=true,Flag="ESPHealth",Callback=function(v) ShowHealth=v end})
ESPTab:CreateSection("World")
ESPTab:CreateToggle({
    Name="Fruit ESP 🍎",CurrentValue=false,Flag="FruitESP",
    Callback=function(v) FruitESPOn=v if v then ScanFruits() else ClearFruitBBs() end end,
})

-- ──────────────────────────────────────────────
--  TAB: MISC
-- ──────────────────────────────────────────────
local MiscTab = Window:CreateTab("⚙️ Misc", 4483362458)

MiscTab:CreateSection("Game")
MiscTab:CreateToggle({
    Name="Save Spawn Point",CurrentValue=false,Flag="SaveSpawn",
    Callback=function(v)
        if v then pcall(function() ReplicatedStorage.Remotes.CommF_:InvokeServer("SetSpawnPoint") end) end
    end,
})
MiscTab:CreateToggle({
    Name="Auto Haki Color Buy",CurrentValue=false,Flag="AutoHakiColor",
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
MiscTab:CreateButton({Name="Pirates",Callback=function()
    pcall(function() ReplicatedStorage.Remotes.CommF_:InvokeServer("SetTeam","Pirates") end)
end})
MiscTab:CreateButton({Name="Marines",Callback=function()
    pcall(function() ReplicatedStorage.Remotes.CommF_:InvokeServer("SetTeam","Marines") end)
end})

MiscTab:CreateSection("Shop")
MiscTab:CreateButton({Name="Buy Geppo",Callback=function()
    pcall(function() ReplicatedStorage.Remotes.CommF_:InvokeServer("BuyHaki","Geppo") end)
end})
MiscTab:CreateButton({Name="Buy Buso",Callback=function()
    pcall(function() ReplicatedStorage.Remotes.CommF_:InvokeServer("BuyHaki","Buso") end)
end})
MiscTab:CreateButton({Name="Buy Ken",Callback=function()
    pcall(function() ReplicatedStorage.Remotes.CommF_:InvokeServer("KenTalk","Buy") end)
end})

MiscTab:CreateSection("Codes")
MiscTab:CreateButton({
    Name="Redeem All Codes",
    Callback=function()
        local codes={"KITT_RESET","Sub2UncleKizaru","SUB2GAMERROBOT_RESET1","Sub2Fer999",
            "Enyu_is_Pro","JCWK","StarcodeHEO","MagicBus","KittGaming","Sub2CaptainMaui",
            "Sub2OfficalNoobie","TheGreatAce","Sub2NoobMaster123","Sub2Daigrock","Axiore",
            "StrawHatMaine","TantaiGaming","Bluxxy","SUB2GAMERROBOT_EXP1","Chandler",
            "NOMOREHACK","BANEXPLOIT","WildDares","BossBuild","GetPranked","EARN_FRUITS",
            "FIGHT4FRUIT","NOEXPLOITER","NOOB2ADMIN","CODESLIDE","ADMINHACKED","ADMINDARES",
            "fruitconcepts","krazydares","TRIPLEABUSE","SEATROLLING","24NOADMIN",
            "REWARDFUN","NEWTROLL","fudd10_v2","Fudd10","Bignews","SECRET_ADMIN"}
        for _,c in ipairs(codes) do
            pcall(function() ReplicatedStorage.Remotes.Redeem:InvokeServer(c) end)
        end
        Rayfield:Notify({Title="BF Hub",Content="Codes redeemed!",Duration=3})
    end,
})

MiscTab:CreateSection("Auto Stats")
MiscTab:CreateDropdown({
    Name="Auto Stat Points",Options={"Off","Melee","Defense","Sword","Gun","Fruit"},
    CurrentOption="Off",Flag="AutoStats",
    Callback=function(v)
        task.spawn(function()
            local m={Melee="Melee",Defense="Defense",Sword="Sword",Gun="Gun",Fruit="Demon Fruit"}
            while v~="Off" do
                pcall(function() ReplicatedStorage.Remotes.CommF_:InvokeServer("AddPoint",m[v],3) end)
                task.wait(0.5)
            end
        end)
    end,
})

-- ══════════════════════════════════════════════
task.wait(2)
Rayfield:Notify({
    Title   = "🍎 BF Hub Loaded",
    Content = "Fixed sky glitch | Anchor pull | Sky TP | All Seas",
    Duration = 5,
})