local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local TweenService      = game:GetService("TweenService")
local VIM               = game:GetService("VirtualInputManager")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer       = Players.LocalPlayer

local Rayfield
pcall(function()
    Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()
end)
if not Rayfield then
    local noop = function() return {Set=function()end} end
    local tab  = setmetatable({},{__index=function() return noop end})
    Rayfield   = {CreateWindow=function() return setmetatable({},{__index=function() return function() return tab end end}) end, Notify=function()end}
end

local function GetChar() return LocalPlayer.Character end
local function GetHRP()  local c=GetChar(); return c and c:FindFirstChild("HumanoidRootPart") end
local function GetHum()  local c=GetChar(); return c and c:FindFirstChildOfClass("Humanoid") end

local RegAttack, RegHit
task.spawn(function()
    pcall(function()
        local net = ReplicatedStorage:WaitForChild("Modules",15):WaitForChild("Net",15)
        RegAttack = net:WaitForChild("RE/RegisterAttack",15)
        RegHit    = net:WaitForChild("RE/RegisterHit",15)
    end)
end)

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
local ChestFarmOn  = false

local AF = {Active=false, Running=false, Status="Idle"}
local Mon, NameMon, NameQuest, LevelQuest, CFrameQuest, CFrameMon
local MonFarm    = ""
local FarmAnchor = Vector3.new(0,0,0)

local World1 = game.PlaceId == 2753915549
local World2 = game.PlaceId == 4442272183
local World3 = game.PlaceId == 7449423635

local function NormalTP(destCF)
    local hrp = GetHRP(); if not hrp then return end
    local x, y, z = destCF.Position.X, math.max(destCF.Position.Y, 4), destCF.Position.Z
    hrp.CFrame = CFrame.new(x, y, z)
    task.wait()
    hrp = GetHRP(); if not hrp then return end
    hrp.CFrame = CFrame.new(x, y, z)
    task.wait()
    hrp = GetHRP(); if not hrp then return end
    hrp.CFrame = CFrame.new(x, y, z)
end

local EntranceZones = {
    [2753915549] = {
        {thr=1200, zone=Vector3.new(-7894.6,5547.1,-380.3),  entry=Vector3.new(-7894.6,5547.1,-380.3)},
        {thr=3500, zone=Vector3.new(61163.9,11.7,1819.8),    entry=Vector3.new(61163.9,11.7,1819.8)},
        {thr=1200, zone=Vector3.new(-4607.8,872.5,-1667.6),  entry=Vector3.new(-4607.8,872.5,-1667.6)},
    },
    [4442272183] = {
        {thr=3500, zone=Vector3.new(923.2,127.0,32852.8),    entry=Vector3.new(923.2,127.0,32852.8)},
        {thr=1200, zone=Vector3.new(-6508.6,89.0,-132.8),    entry=Vector3.new(-6508.6,89.0,-132.8)},
    },
    [7449423635] = {
        {thr=1200, zone=Vector3.new(5657.9,1013.1,-335.5),   entry=Vector3.new(5657.9,1013.1,-335.5)},
        {thr=1200, zone=Vector3.new(-5075.5,314.5,-3150.0),  entry=Vector3.new(-5075.5,314.5,-3150.0)},
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

local _tweenActive = false
local function StopTween()
    _tweenActive = false
    local hrp = GetHRP()
    if hrp then local bv=hrp:FindFirstChild("_FyzeBV"); if bv then bv:Destroy() end end
end

local function TweenTP(destCF, yExtra)
    StopTween()
    local hrp = GetHRP(); if not hrp then return end
    local hum = GetHum(); if not hum or hum.Health <= 0 then return end
    yExtra = yExtra or 0

    CheckAndEnter(destCF.Position)
    hrp = GetHRP(); if not hrp then return end

    local destY   = math.max(destCF.Position.Y, 4) + yExtra
    local finalCF = CFrame.new(destCF.Position.X, destY,      destCF.Position.Z)
    local aboveCF = CFrame.new(destCF.Position.X, destY + 30, destCF.Position.Z)

    local c = GetChar()
    if c then for _, p in ipairs(c:GetDescendants()) do if p:IsA("BasePart") then p.CanCollide=false end end end

    _tweenActive = true

    if hrp:FindFirstChild("_FyzeBV") then hrp:FindFirstChild("_FyzeBV"):Destroy() end
    local bv = Instance.new("BodyVelocity")
    bv.Name="_FyzeBV"; bv.MaxForce=Vector3.new(1e5,1e5,1e5); bv.Velocity=Vector3.zero; bv.Parent=hrp

    local d1 = (aboveCF.Position - hrp.Position).Magnitude
    local tw1 = TweenService:Create(hrp, TweenInfo.new(math.max(d1/200,0.15),Enum.EasingStyle.Linear), {CFrame=aboveCF})
    tw1:Play(); tw1.Completed:Wait()
    if not _tweenActive then StopTween(); return end

    hrp = GetHRP(); if not hrp then StopTween(); return end
    local d2 = (finalCF.Position - hrp.Position).Magnitude
    local tw2 = TweenService:Create(hrp, TweenInfo.new(math.max(d2/100,0.15),Enum.EasingStyle.Quad), {CFrame=finalCF})
    tw2:Play(); tw2.Completed:Wait()

    StopTween()
    hrp = GetHRP()
    if hrp then
        hrp.CanCollide = false
        if hrp.Position.Y < 2 then hrp.CFrame = CFrame.new(hrp.Position.X,5,hrp.Position.Z) end
    end
end

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
                    table.insert(hits, {e, head}); last = head
                end
            end
        end
    end
    return last, hits
end

local function GetEquippedTool()
    local c = LocalPlayer.Character; if not c then return nil end
    for _, v in ipairs(c:GetChildren()) do if v:IsA("Tool") then return v end end
end

local function AttackNoCoolDown()
    if not AutoAttackOn or not RegAttack or not RegHit then return end
    if not GetEquippedTool() then return end
    local last, hits = FindHits()
    if not last or #hits == 0 then return end
    pcall(function() RegAttack:FireServer(1e-9) end)
    pcall(function() RegHit:FireServer(last, hits) end)
end

RunService.Heartbeat:Connect(function()
    if AutoAttackOn then pcall(AttackNoCoolDown) end
end)

local function SetWalkSpeed(on)
    WalkSpeedOn = on
    pcall(function()
        local h = GetHum()
        if h then h.WalkSpeed = on and WalkSpeedVal or 16 end
    end)
end

RunService.Stepped:Connect(function()
    if not WalkSpeedOn then return end
    pcall(function()
        local h = GetHum()
        if h then h.WalkSpeed = WalkSpeedVal end
    end)
end)

LocalPlayer.CharacterAdded:Connect(function(c)
    _tweenActive = false
    local hrp = c:FindFirstChild("HumanoidRootPart")
    if hrp then local bv=hrp:FindFirstChild("_FyzeBV"); if bv then bv:Destroy() end end
    if WalkSpeedOn then task.wait(1); SetWalkSpeed(true) end
end)

local _waterOrigY = nil
RunService.Heartbeat:Connect(function()
    if not WalkOnWater then return end
    pcall(function()
        local map = workspace:FindFirstChild("Map"); if not map then return end
        local wb  = map:FindFirstChild("WaterBase-Plane"); if not wb then return end
        if not _waterOrigY then _waterOrigY = wb.Size.Y end
        wb.Size = Vector3.new(wb.Size.X, 112, wb.Size.Z)
        wb.CanCollide = true
    end)
end)

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

task.spawn(function()
    while true do
        task.wait(55)
        if AntiAFKOn then
            pcall(function()
                VIM:SendKeyEvent(true,  Enum.KeyCode.W, false, game); task.wait(0.1)
                VIM:SendKeyEvent(false, Enum.KeyCode.W, false, game)
            end)
        end
    end
end)

task.spawn(function()
    while true do
        if AutoHakiOn then AutoHaki() end
        task.wait(12)
    end
end)

RunService.Heartbeat:Connect(function()
    if not HitboxOn then return end
    pcall(function()
        local en = workspace:FindFirstChild("Enemies"); if not en then return end
        local s  = InfRange and 999 or math.max(AttackRange,30)
        for _, e in ipairs(en:GetChildren()) do
            local r = e:FindFirstChild("HumanoidRootPart")
            if r and r.Size.X < s then
                r.Size=Vector3.new(s,s,s); r.CanCollide=false
                local head=e:FindFirstChild("Head"); if head then head.CanCollide=false end
            end
        end
    end)
end)

local FruitBBs = {}
local function MakeFruitBB(adornee, label)
    if FruitBBs[adornee] or not adornee or not adornee.Parent then return end
    local bb = Instance.new("BillboardGui")
    bb.AlwaysOnTop=true; bb.Size=UDim2.new(0,180,0,40); bb.StudsOffset=Vector3.new(0,6,0)
    bb.Adornee=adornee; bb.Parent=game:GetService("CoreGui")
    local l = Instance.new("TextLabel",bb)
    l.BackgroundTransparency=1; l.Size=UDim2.new(1,0,1,0); l.Text=label
    l.TextColor3=Color3.fromRGB(255,215,0); l.Font=Enum.Font.GothamBold; l.TextSize=14
    l.TextStrokeTransparency=0.2; l.TextStrokeColor3=Color3.new(0,0,0)
    FruitBBs[adornee]=bb
    adornee.AncestryChanged:Connect(function()
        if not adornee.Parent then pcall(function() bb:Destroy() end); FruitBBs[adornee]=nil end
    end)
end
local function ClearFruitBBs()
    for a,bb in pairs(FruitBBs) do pcall(function() bb:Destroy() end); FruitBBs[a]=nil end
end
local function ScanFruits()
    if not FruitESPOn then return end
    local function TryTag(obj)
        if not string.find(string.lower(obj.Name),"fruit") then return end
        local ad
        if obj:IsA("Tool") then ad=obj:FindFirstChild("Handle") or obj.PrimaryPart
        elseif obj:IsA("Model") then ad=obj.PrimaryPart or obj:FindFirstChildOfClass("BasePart")
        elseif obj:IsA("BasePart") then ad=obj end
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

local ESPObj = {}
local C_W=Color3.fromRGB(255,255,255); local C_G=Color3.fromRGB(80,255,120); local C_R=Color3.fromRGB(255,60,60)
local function AddESP(p)
    if p==LocalPlayer then return end
    ESPObj[p]={}
    local function Setup()
        local ch=p.Character; if not ch then return end
        local hrp=ch:FindFirstChild("HumanoidRootPart"); if not hrp then return end
        if ESPObj[p].bb   then ESPObj[p].bb:Destroy() end
        if ESPObj[p].conn then ESPObj[p].conn:Disconnect() end
        local bb=Instance.new("BillboardGui")
        bb.AlwaysOnTop=true; bb.Size=UDim2.new(0,200,0,50); bb.StudsOffset=Vector3.new(0,3,0)
        bb.Adornee=hrp; bb.Parent=hrp
        local nl=Instance.new("TextLabel",bb)
        nl.BackgroundTransparency=1; nl.Size=UDim2.new(1,0,.5,0)
        nl.TextColor3=C_W; nl.TextStrokeTransparency=0.5; nl.Font=Enum.Font.GothamBold; nl.TextSize=14; nl.Text=p.Name
        local hl=Instance.new("TextLabel",bb)
        hl.BackgroundTransparency=1; hl.Size=UDim2.new(1,0,.5,0); hl.Position=UDim2.new(0,0,.5,0)
        hl.TextStrokeTransparency=0.5; hl.Font=Enum.Font.Gotham; hl.TextSize=14
        ESPObj[p].bb=bb
        ESPObj[p].conn=RunService.RenderStepped:Connect(function()
            if not ESPOn then bb.Enabled=false; return end
            local c2=p.Character; if not c2 then bb.Enabled=false; return end
            local h2=c2:FindFirstChild("HumanoidRootPart")
            local hu=c2:FindFirstChildOfClass("Humanoid")
            if not h2 or not hu then bb.Enabled=false; return end
            bb.Enabled=true; bb.Adornee=h2
            nl.Visible=ShowName; nl.Text=p.Name; hl.Visible=ShowHealth
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
    if d.bb then d.bb:Destroy() end; if d.conn then d.conn:Disconnect() end; ESPObj[p]=nil
end
for _,p in ipairs(Players:GetPlayers()) do AddESP(p) end
Players.PlayerAdded:Connect(AddESP); Players.PlayerRemoving:Connect(RemoveESP)

local function CheckQuest()
    local ok,lvl = pcall(function() return LocalPlayer.Data.Level.Value end)
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

local function GetChests()
    local found = {}
    local function check(obj)
        local n = obj.Name:lower()
        if n == "chest" or n:find("chest") then
            local part = obj:IsA("BasePart") and obj
                      or (obj:IsA("Model") and (obj.PrimaryPart or obj:FindFirstChildOfClass("BasePart")))
            if part then table.insert(found, {model=obj, part=part}) end
        end
    end
    for _, obj in ipairs(workspace:GetDescendants()) do
        pcall(check, obj)
    end
    return found
end

local function RunChestFarm()
    task.spawn(function()
        while ChestFarmOn do
            local chests = GetChests()
            if #chests == 0 then task.wait(2); else
                for _, c in ipairs(chests) do
                    if not ChestFarmOn then break end
                    if not c.model.Parent then continue end
                    local hrp = GetHRP(); if not hrp then task.wait(0.5); continue end
                    local pos = c.part.Position
                    hrp.CFrame = CFrame.new(pos.X, pos.Y + 4, pos.Z)
                    task.wait(0.05)
                    hrp = GetHRP(); if hrp then hrp.CFrame = CFrame.new(pos.X, pos.Y + 4, pos.Z) end
                    task.wait(0.05)
                    hrp = GetHRP(); if hrp then hrp.CFrame = CFrame.new(pos.X, pos.Y + 4, pos.Z) end
                    task.wait(0.1)
                    pcall(function()
                        ReplicatedStorage.Remotes.CommF_:InvokeServer("OpenChest", c.model)
                    end)
                    pcall(function()
                        local hrp2 = GetHRP()
                        if hrp2 then hrp2.CFrame = CFrame.new(pos) end
                    end)
                    task.wait(0.3)
                end
            end
            task.wait(0.5)
        end
    end)
end

local AutoFruitOn    = false
local _fruitBusy     = false
local _pendingFruits = {}

local FRUIT_KEYWORDS = {
    "fruit","flame","ice","sand","dark","light","rubber","magma","quake",
    "string","gas","snow","smoke","diamond","barrier","spring","gravity",
    "love","door","paw","Phoenix","Buddha","dragon","leopard","rumble",
    "control","soul","venom","mammoth","kitsune","portal","spin","chop",
    "spike","bomb","rocket","bird","spike","swamp","ghost",
}

local function IsFruitObj(obj)
    local n = obj.Name:lower()
    for _, kw in ipairs(FRUIT_KEYWORDS) do
        if n:find(kw:lower()) then return true end
    end
    return false
end

local function GetFruitPart(obj)
    if obj:IsA("BasePart") then return obj end
    if obj:IsA("Tool") then
        return obj:FindFirstChild("Handle") or obj:FindFirstChildOfClass("BasePart")
    end
    if obj:IsA("Model") then
        return obj.PrimaryPart or obj:FindFirstChildOfClass("BasePart")
    end
    return nil
end

local function IsWorldFruit(obj)
    local p = obj.Parent
    if not p then return false end
    if p.Name == "Fruits" or p.Name == "DroppedFruits" or p.Name == "DevilFruits" then
        return true
    end
    if p == workspace then return true end
    if p.Parent == workspace and not p:FindFirstChildOfClass("Humanoid") then
        return true
    end
    return false
end

local function QueueFruit(obj)
    if not AutoFruitOn then return end
    local part = GetFruitPart(obj)
    if not part then return end
    for _, f in ipairs(_pendingFruits) do
        if f.obj == obj then return end
    end
    table.insert(_pendingFruits, {obj=obj, part=part})
end

local function CollectFruit(entry)
    local obj  = entry.obj
    local part = entry.part
    if not obj or not obj.Parent then return end
    if not part or not part.Parent then return end

    local pos = part.Position
    local hrp = GetHRP(); if not hrp then return end

    local wasFarming = AF.Active and (_hoverConn ~= nil or _pullConn ~= nil)
    if wasFarming then StopFarmLoops() end

    AF.Status = "Getting fruit: " .. obj.Name

    local fx, fy, fz = pos.X, math.max(pos.Y, 4), pos.Z
    hrp.CFrame = CFrame.new(fx, fy + 3, fz)
    task.wait()
    hrp = GetHRP(); if hrp then hrp.CFrame = CFrame.new(fx, fy + 3, fz) end
    task.wait()
    hrp = GetHRP(); if hrp then hrp.CFrame = CFrame.new(fx, fy + 3, fz) end
    task.wait(0.1)

    hrp = GetHRP()
    if hrp then hrp.CFrame = CFrame.new(fx, fy, fz) end
    task.wait(0.05)

    pcall(function()
        ReplicatedStorage.Remotes.CommF_:InvokeServer("GetFruit", obj.Name)
    end)
    task.wait(0.05)

    pcall(function()
        ReplicatedStorage.Remotes.CommF_:InvokeServer("GiveFruitPlayer", obj)
    end)
    task.wait(0.05)

    pcall(function()
        ReplicatedStorage.Remotes.CommF_:InvokeServer("FruitNotif", obj.Name)
    end)
    task.wait(0.05)

    task.wait(0.3)
    local c = GetChar()
    if c then
        for _, item in ipairs(c:GetChildren()) do
            if item:IsA("Tool") and IsFruitObj(item) then
                pcall(function()
                    ReplicatedStorage.Remotes.CommF_:InvokeServer("StoreFruit", item.Name)
                end)
                pcall(function()
                    ReplicatedStorage.Remotes.CommF_:InvokeServer("SetFruitStorage", item.Name)
                end)
            end
        end
        for _, item in ipairs(LocalPlayer.Backpack:GetChildren()) do
            if item:IsA("Tool") and IsFruitObj(item) then
                pcall(function()
                    ReplicatedStorage.Remotes.CommF_:InvokeServer("StoreFruit", item.Name)
                end)
                pcall(function()
                    ReplicatedStorage.Remotes.CommF_:InvokeServer("SetFruitStorage", item.Name)
                end)
            end
        end
    end

    if wasFarming and AF.Active then
        StartHover()
        StartPull()
    end

    if AF.Active then
        AF.Status = "Farming: " .. (Mon or "")
    else
        AF.Status = "Idle"
    end
end

task.spawn(function()
    while true do
        task.wait(0.2)
        if AutoFruitOn and not _fruitBusy and #_pendingFruits > 0 then
            _fruitBusy = true
            local entry = table.remove(_pendingFruits, 1)
            pcall(CollectFruit, entry)
            _fruitBusy = false
        end
    end
end)

workspace.DescendantAdded:Connect(function(obj)
    if not AutoFruitOn then return end
    task.wait(0.3)
    if not obj or not obj.Parent then return end
    if not IsFruitObj(obj) then return end
    if not IsWorldFruit(obj) then return end
    local part = GetFruitPart(obj)
    if part then QueueFruit(obj) end
end)

local function ScanWorldFruits()
    for _, obj in ipairs(workspace:GetDescendants()) do
        pcall(function()
            if not IsFruitObj(obj) then return end
            if not IsWorldFruit(obj) then return end
            local part = GetFruitPart(obj)
            if part then QueueFruit(obj) end
        end)
    end
    for _, fname in ipairs({"Fruits","DroppedFruits","DevilFruits"}) do
        local folder = workspace:FindFirstChild(fname)
        if folder then
            for _, obj in ipairs(folder:GetChildren()) do
                pcall(function()
                    local part = GetFruitPart(obj)
                    if part then QueueFruit(obj) end
                end)
            end
        end
    end
end

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
end
local function StopFarmLoops()
    StopPull()
    StopHover()
    StopTween()
end

local function PrepNPC(e)
    local er = e:FindFirstChild("HumanoidRootPart"); if not er then return end
    local s = InfRange and 999 or math.max(AttackRange,30)
    er.Size=Vector3.new(s,s,s); er.CanCollide=false
    local hu = e:FindFirstChildOfClass("Humanoid")
    if hu then hu.WalkSpeed=0; hu.JumpPower=0
        if hu:FindFirstChild("Animator") then hu.Animator:Destroy() end
    end
    local head=e:FindFirstChild("Head"); if head then head.CanCollide=false end
end

local function StartPull()
    StopPull()
    local cf   = _pullAnchorCF
    local name = _pullName
    local mon  = Mon
    _pullConn = RunService.Heartbeat:Connect(function()
        if not AF.Active then StopPull(); return end
        pcall(function()
            local en = workspace:FindFirstChild("Enemies"); if not en then return end
            for _, e in ipairs(en:GetChildren()) do
                if (e.Name==name or e.Name==mon) then
                    local hu = e:FindFirstChildOfClass("Humanoid")
                    local er = e:FindFirstChild("HumanoidRootPart")
                    if hu and hu.Health > 0 and er then
                        er.CFrame=cf; er.Velocity=Vector3.zero
                        local s=InfRange and 999 or math.max(AttackRange,30)
                        er.Size=Vector3.new(s,s,s); er.CanCollide=false
                        hu.WalkSpeed=0; hu.JumpPower=0
                        local head=e:FindFirstChild("Head"); if head then head.CanCollide=false end
                        pcall(function() sethiddenproperty(LocalPlayer,"SimulationRadius",math.huge) end)
                    end
                end
            end
        end)
    end)
end

local function StartHover()
    StopHover()
    local hp = _hoverPos
    _hoverConn = RunService.Heartbeat:Connect(function()
        if not AF.Active then StopHover(); return end
        local hrp = GetHRP(); if not hrp then return end
        hrp.CFrame = CFrame.new(hp)
        hrp.CanCollide = false
        pcall(function() sethiddenproperty(LocalPlayer,"SimulationRadius",math.huge) end)
    end)
end

local function RunAutoFarm()
    if AF.Running then AF.Running=false; task.wait(0.3) end
    AF.Running = true
    task.spawn(function()
        while AF.Active do
            local hum = GetHum()
            if not hum or hum.Health <= 0 then
                AF.Status = "Dead"; StopFarmLoops(); task.wait(4)
                if not AF.Active then break end
            end

            CheckQuest()
            if not Mon then task.wait(0.3); continue end

            local qGui = LocalPlayer.PlayerGui:FindFirstChild("Main")
            local qEl  = qGui and qGui:FindFirstChild("Quest")
            local qVis = qEl and qEl.Visible

            if not qVis then
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
                        ReplicatedStorage.Remotes.CommF_:InvokeServer("StartQuest", NameQuest, LevelQuest)
                    end)
                    task.wait(0.8)
                end
                continue
            end

            local title = ""
            pcall(function() title = qEl.Container.QuestTitle.Title.Text end)
            if not string.find(title, NameMon or "") then
                StopFarmLoops()
                pcall(function() ReplicatedStorage.Remotes.CommF_:InvokeServer("AbandonQuest") end)
                task.wait(0.2); continue
            end

            local en = workspace:FindFirstChild("Enemies")
            if not en then task.wait(0.3); continue end
            local target = nil
            for _, e in ipairs(en:GetChildren()) do
                local hu = e:FindFirstChildOfClass("Humanoid")
                if e.Name==Mon and hu and hu.Health>0 and e:FindFirstChild("HumanoidRootPart") then
                    target=e; break
                end
            end

            if not target then
                StopFarmLoops()
                AF.Status = "Finding mob"
                TweenTP(CFrameMon, 5)
                task.wait(1.5); continue
            end

            StopFarmLoops()
            local er = target:FindFirstChild("HumanoidRootPart")
            if not er then task.wait(0.2); continue end

            PrepNPC(target)
            AutoHaki()
            EquipWeapon(GetWeaponName())

            local ancY       = math.max(er.Position.Y, 4)
            FarmAnchor       = Vector3.new(er.Position.X, ancY, er.Position.Z)
            _pullAnchorCF    = CFrame.new(FarmAnchor)
            _hoverPos        = Vector3.new(FarmAnchor.X, FarmAnchor.Y + HOVER_H, FarmAnchor.Z)
            _pullName        = target.Name
            MonFarm          = target.Name

            local hrp = GetHRP()
            if hrp and (FarmAnchor - hrp.Position).Magnitude > 10 then
                AF.Status = "Flying to mob"
                TweenTP(CFrame.new(FarmAnchor), HOVER_H)
                task.wait(0.1)
            end

            AF.Status = "Farming: "..Mon
            StartHover()
            StartPull()

            local tick = 0
            while AF.Active and target and target.Parent do
                local hu2 = target:FindFirstChildOfClass("Humanoid")
                if not hu2 or hu2.Health <= 0 then break end
                tick = tick + 1
                if tick % 8  == 0 then pcall(function() PrepNPC(target) end) end
                if tick % 20 == 0 then
                    if not (qEl and qEl.Visible) then break end
                end
                task.wait(0.1)
            end

            StopFarmLoops(); MonFarm = ""; task.wait(0.1)
        end

        StopFarmLoops(); MonFarm=""; AF.Status="Idle"; AF.Running=false
    end)
end

local BH = {Status="Idle", Target=""}
local BH_tpConn     = nil
local BH_atkConn    = nil
local BH_mucTieu    = nil
local BH_ReturnPos  = nil
local BH_TPActive   = false
local BH_AtkActive  = false

local function StopBHTP()
    if BH_tpConn then BH_tpConn:Disconnect(); BH_tpConn = nil end
    BH_TPActive = false
end

local function StopBHAtk()
    if BH_atkConn then BH_atkConn:Disconnect(); BH_atkConn = nil end
    BH_AtkActive = false
end

local function StopBH()
    StopBHTP()
    StopBHAtk()
    BH_mucTieu  = nil
    BH_ReturnPos = nil
    BH.Status = "Idle"
    BH.Target = ""
end

-- Stepped TP: glues your HRP onto the target every physics step.
-- Also claims simulation ownership so BF server correction cannot override us.
local function StartBHTP(target)
    StopBHTP()
    BH_mucTieu  = target
    BH_TPActive = true
    BH_tpConn = RunService.Stepped:Connect(function()
        pcall(function()
            if not BH_TPActive or not BH_mucTieu then return end
            local nhanVat     = LocalPlayer.Character
            local nhanVatDich = BH_mucTieu.Character
            if not nhanVat or not nhanVatDich then return end
            local chanToi  = nhanVat:FindFirstChild("HumanoidRootPart")
            local chanDich = nhanVatDich:FindFirstChild("HumanoidRootPart")
            if not chanToi or not chanDich then return end
            local viTriDich = chanDich.Position
            -- Claim physics ownership so server cannot correct our position
            pcall(function() sethiddenproperty(LocalPlayer, "SimulationRadius", math.huge) end)
            chanToi.CFrame = CFrame.new(viTriDich.X, viTriDich.Y, viTriDich.Z)
            chanToi.AssemblyLinearVelocity = Vector3.zero
            chanToi.CanCollide = false
        end)
    end)
end

-- T-Rex M1 auto attack for PvP.
-- BF player damage does NOT use RegisterHit — it uses the equipped tool's own
-- RemoteEvent (LeftClickRemote / RemoteEvent inside the tool), firing the
-- target's HRP as the argument, exactly like a real M1 click.
local function GetEquippedToolRemote()
    local c = LocalPlayer.Character; if not c then return nil end
    for _, v in ipairs(c:GetChildren()) do
        if v:IsA("Tool") then
            -- Try common remote names used by BF melee/sword tools
            return v:FindFirstChild("LeftClickRemote")
                or v:FindFirstChild("RemoteEvent")
                or v:FindFirstChild("RemoteFunction")
        end
    end
    return nil
end

local function StartBHAtk(target)
    StopBHAtk()
    BH_AtkActive = true
    BH_atkConn = RunService.Heartbeat:Connect(function()
        pcall(function()
            if not BH_AtkActive or not target or not target.Character then return end
            local tc = target.Character
            local hu = tc:FindFirstChildOfClass("Humanoid")
            if not hu or hu.Health <= 0 then return end
            local tHrp = tc:FindFirstChild("HumanoidRootPart"); if not tHrp then return end

            -- Method 1: tool LeftClickRemote / RemoteEvent (T-Rex M1 & most melee)
            local remote = GetEquippedToolRemote()
            if remote then
                -- Standard BF M1 signature: FireServer(targetHRP, direction)
                pcall(function() remote:FireServer(tHrp, Vector3.new(0,0,-1)) end)
                -- Some tools use (direction, hitInstance) instead
                pcall(function() remote:FireServer(Vector3.new(0,0,-1), tHrp) end)
            end

            -- Method 2: mob attack remotes as fallback (works if server validates them for players too)
            if RegAttack then pcall(function() RegAttack:FireServer(1e-9) end) end
            if RegHit then
                local tHead = tc:FindFirstChild("Head") or tHrp
                pcall(function() RegHit:FireServer(tHead, {{tc, tHead}}) end)
            end
        end)
    end)
end

-- Save current position then start sticking + attacking
local function BH_Engage(target)
    if not target or not target.Character then
        Rayfield:Notify({Title="Bounty Hunt", Content="Target has no character.", Duration=2})
        return
    end
    local hrp = GetHRP(); if not hrp then return end
    BH_ReturnPos = hrp.CFrame
    BH.Target    = target.Name
    BH.Status    = "Locked: " .. target.Name
    -- Equip weapon so tool remote exists when attack loop fires
    pcall(function() EquipWeapon(GetWeaponName()) end)
    task.wait(0.1)
    StartBHTP(target)
    StartBHAtk(target)
end

-- Stop sticking and teleport back to saved position
local function BH_Return()
    StopBHTP()
    StopBHAtk()
    BH.Status = "Returning..."
    BH.Target = ""
    task.spawn(function()
        task.wait(0.05)
        local hrp = GetHRP()
        if hrp and BH_ReturnPos then
            hrp.CFrame = BH_ReturnPos
            task.wait()
            hrp = GetHRP(); if hrp then hrp.CFrame = BH_ReturnPos end
            task.wait()
            hrp = GetHRP(); if hrp then hrp.CFrame = BH_ReturnPos end
        end
        BH_ReturnPos = nil
        BH.Status = "Idle"
    end)
end

local Window = Rayfield:CreateWindow({
    Name="FyZe Hub", LoadingTitle="FyZe Hub", LoadingSubtitle="",
    ConfigurationSaving={Enabled=false}, Discord={Enabled=false}, KeySystem=false,
})

local FarmTab = Window:CreateTab("Farm", 4483362458)
FarmTab:CreateSection("Weapon")
FarmTab:CreateDropdown({
    Name="Weapon Type", Options={"Melee","Sword","Gun","Blox Fruit"},
    CurrentOption="Melee", Flag="Weapon",
    Callback=function(v) SelectWeapon=tostring(v) end,
})
FarmTab:CreateSection("Auto Farm")
FarmTab:CreateToggle({
    Name="Auto Farm", CurrentValue=false, Flag="AutoFarm",
    Callback=function(v)
        AF.Active=v
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
    Name="Attack Range", Range={10,500}, Increment=10, Suffix=" studs",
    CurrentValue=60, Flag="AtkRange",
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
local StatusLabel = FarmTab:CreateParagraph({Title="Status", Content="Idle"})
local MobLabel    = FarmTab:CreateParagraph({Title="Mob",    Content="none"})
local LvlLabel    = FarmTab:CreateParagraph({Title="Info",   Content="Lvl:? HP:?/?"})
task.spawn(function()
    while true do
        task.wait(1)
        pcall(function()
            local h  = GetHum()
            local hp = h and math.floor(h.Health)    or 0
            local mx = h and math.floor(h.MaxHealth)  or 0
            local lvl= "?"
            pcall(function() lvl=tostring(LocalPlayer.Data.Level.Value) end)
            pcall(function() StatusLabel:Set({Title="Status", Content=AF.Status or "Idle"}) end)
            pcall(function() MobLabel:Set({Title="Mob",       Content=Mon or "none"}) end)
            pcall(function() LvlLabel:Set({Title="Info",      Content=("Lvl:%s HP:%d/%d"):format(lvl,hp,mx)}) end)
        end)
    end
end)

local ChestTab = Window:CreateTab("Chest", 4483362458)
ChestTab:CreateSection("Auto Chest Farm")
ChestTab:CreateToggle({
    Name="Auto Chest Farm", CurrentValue=false, Flag="ChestFarm",
    Callback=function(v)
        ChestFarmOn = v
        if v then RunChestFarm() end
    end,
})
ChestTab:CreateSection("Auto Fruit Snatcher")
ChestTab:CreateToggle({
    Name="Auto Fruit Snatcher", CurrentValue=false, Flag="FruitSnatch",
    Callback=function(v)
        AutoFruitOn = v
        _pendingFruits = {}
        if v then
            ScanWorldFruits()
        end
    end,
})
ChestTab:CreateParagraph({
    Title="Fruit Snatcher",
    Content="When a devil fruit spawns, auto TPs to it, picks it up and stores it in fruit storage. Works with or without auto farm.",
})

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
        WalkSpeedVal=v
        if WalkSpeedOn then
            pcall(function() local h=GetHum(); if h then h.WalkSpeed=WalkSpeedVal end end)
        end
    end,
})
MoveTab:CreateSection("Other")
MoveTab:CreateToggle({
    Name="Walk on Water", CurrentValue=false, Flag="WalkOnWater",
    Callback=function(v)
        WalkOnWater=v
        if not v then
            pcall(function()
                local map=workspace:FindFirstChild("Map"); if not map then return end
                local wb=map:FindFirstChild("WaterBase-Plane"); if not wb then return end
                wb.Size=Vector3.new(wb.Size.X, _waterOrigY or 80, wb.Size.Z)
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
        pcall(function() game:GetService("TeleportService"):Teleport(game.PlaceId, LocalPlayer) end)
    end,
})

local TPTab = Window:CreateTab("Teleport", 4483362458)
TPTab:CreateSection("Player Teleport")
local _selPlayer = "(none)"
local function GetPlayerNames()
    local n={}
    for _,p in ipairs(Players:GetPlayers()) do
        if p~=LocalPlayer then table.insert(n,p.Name) end
    end
    return #n>0 and n or {"(none)"}
end
local _initNames = GetPlayerNames()
_selPlayer = _initNames[1]
TPTab:CreateDropdown({
    Name="Select Player", Options=_initNames, CurrentOption=_initNames[1],
    Flag="TPPlayerDrop",
    Callback=function(v) _selPlayer=tostring(v) end,
})
TPTab:CreateButton({
    Name="Teleport to Player",
    Callback=function()
        task.spawn(function()
            if _selPlayer=="" or _selPlayer=="(none)" then return end
            local found
            for _,p in ipairs(Players:GetPlayers()) do
                if p.Name==_selPlayer and p~=LocalPlayer then found=p; break end
            end
            if not found or not found.Character then return end
            local th = found.Character:FindFirstChild("HumanoidRootPart"); if not th then return end
            local dest = CFrame.new(th.Position + Vector3.new(3,0,3))
            NormalTP(dest)
        end)
    end,
})
TPTab:CreateButton({
    Name="Refresh List",
    Callback=function()
        local n=GetPlayerNames(); _selPlayer=n[1]
        Rayfield:Notify({Title="FyZe Hub", Content="Refreshed. "..#n.." player(s).", Duration=2})
    end,
})
TPTab:CreateSection("Type Name")
local _typedName = ""
TPTab:CreateInput({
    Name="Player Name", PlaceholderText="Exact username...",
    RemoveTextAfterFocusLost=false, Flag="TypedTPName",
    Callback=function(v) _typedName=tostring(v) end,
})
TPTab:CreateButton({
    Name="Teleport to Typed Name",
    Callback=function()
        task.spawn(function()
            if _typedName=="" then return end
            local found=Players:FindFirstChild(_typedName)
            if not found or found==LocalPlayer or not found.Character then return end
            local th=found.Character:FindFirstChild("HumanoidRootPart"); if not th then return end
            NormalTP(CFrame.new(th.Position + Vector3.new(3,0,3)))
        end)
    end,
})
TPTab:CreateSection("Quick")
TPTab:CreateButton({
    Name="To Sky",
    Callback=function()
        task.spawn(function()
            local h=GetHRP(); if not h then return end
            NormalTP(CFrame.new(h.Position.X, 9999, h.Position.Z))
        end)
    end,
})
TPTab:CreateButton({
    Name="To Ground",
    Callback=function()
        task.spawn(function()
            local h=GetHRP(); if not h then return end
            NormalTP(CFrame.new(h.Position.X, 5, h.Position.Z))
        end)
    end,
})
TPTab:CreateButton({
    Name="To Void",
    Callback=function()
        task.spawn(function()
            local h=GetHRP(); if not h then return end
            NormalTP(CFrame.new(h.Position.X, -5000, h.Position.Z))
        end)
    end,
})

local ESPTab = Window:CreateTab("ESP", 4483362458)
ESPTab:CreateSection("Player")
ESPTab:CreateToggle({Name="Player ESP",  CurrentValue=true,  Flag="ESPOn",     Callback=function(v) ESPOn=v end})
ESPTab:CreateToggle({Name="Show Names",  CurrentValue=true,  Flag="ESPNames",  Callback=function(v) ShowName=v end})
ESPTab:CreateToggle({Name="Show Health", CurrentValue=true,  Flag="ESPHealth", Callback=function(v) ShowHealth=v end})
ESPTab:CreateSection("World")
ESPTab:CreateToggle({
    Name="Fruit ESP", CurrentValue=false, Flag="FruitESP",
    Callback=function(v) FruitESPOn=v; if v then ScanFruits() else ClearFruitBBs() end end,
})

local BHTab = Window:CreateTab("Bounty Hunt", 4483362458)
BHTab:CreateSection("Select Target")

local _bhSelectedPlayer = "(none)"
local function GetPVPPlayerNames()
    local n = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then table.insert(n, p.Name) end
    end
    return #n > 0 and n or {"(none)"}
end
local _bhInitNames = GetPVPPlayerNames()
_bhSelectedPlayer = _bhInitNames[1]

local _bhDropdown
_bhDropdown = BHTab:CreateDropdown({
    Name="Target Player", Options=_bhInitNames, CurrentOption=_bhInitNames[1],
    Flag="BHPlayerDrop",
    Callback=function(v) _bhSelectedPlayer=tostring(v) end,
})
BHTab:CreateButton({
    Name="Refresh Player List",
    Callback=function()
        local n = GetPVPPlayerNames()
        _bhSelectedPlayer = n[1]
        Rayfield:Notify({Title="Bounty Hunt", Content="Refreshed. "..#n.." player(s).", Duration=2})
    end,
})

BHTab:CreateSection("Control")
BHTab:CreateButton({
    Name="Engage (TP + Auto Attack)",
    Callback=function()
        task.spawn(function()
            if _bhSelectedPlayer == "" or _bhSelectedPlayer == "(none)" then
                Rayfield:Notify({Title="Bounty Hunt", Content="Select a target first.", Duration=2})
                return
            end
            local target
            for _, p in ipairs(Players:GetPlayers()) do
                if p.Name == _bhSelectedPlayer and p ~= LocalPlayer then
                    target = p; break
                end
            end
            if not target then
                Rayfield:Notify({Title="Bounty Hunt", Content="Player not found.", Duration=2})
                return
            end
            if not target.Character then
                Rayfield:Notify({Title="Bounty Hunt", Content="Target has no character.", Duration=2})
                return
            end
            BH_Engage(target)
            Rayfield:Notify({Title="Bounty Hunt", Content="Locked onto "..target.Name..". Press Return to go back.", Duration=3})
        end)
    end,
})
BHTab:CreateButton({
    Name="Return (Stop + Go Back)",
    Callback=function()
        task.spawn(function()
            BH_Return()
        end)
    end,
})
BHTab:CreateButton({
    Name="Stop Attack Only",
    Callback=function()
        StopBHAtk()
        BH.Status = BH_TPActive and ("TP only: "..BH.Target) or "Idle"
    end,
})

BHTab:CreateSection("Status")
local BHStatusLabel = BHTab:CreateParagraph({Title="Status", Content="Idle"})
local BHTargetLabel = BHTab:CreateParagraph({Title="Target", Content="none"})
task.spawn(function()
    while true do
        task.wait(0.5)
        pcall(function()
            pcall(function() BHStatusLabel:Set({Title="Status", Content=BH.Status or "Idle"}) end)
            pcall(function() BHTargetLabel:Set({Title="Target", Content=BH.Target~="" and BH.Target or "none"}) end)
        end)
    end
end)
BHTab:CreateParagraph({
    Title="How to use",
    Content="1. Select player from dropdown\n2. Press Engage — TPs you onto them every frame (Stepped) and auto attacks\n3. Press Return — stops TP + attack and sends you back to where you were",
})

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
        local codes={"KITT_RESET","Sub2UncleKizaru","SUB2GAMERROBOT_RESET1","Sub2Fer999",
            "Enyu_is_Pro","JCWK","StarcodeHEO","MagicBus","KittGaming","Sub2CaptainMaui",
            "Sub2OfficalNoobie","TheGreatAce","Sub2NoobMaster123","Sub2Daigrock","Axiore",
            "StrawHatMaine","TantaiGaming","Bluxxy","SUB2GAMERROBOT_EXP1","Chandler",
            "NOMOREHACK","BANEXPLOIT","WildDares","BossBuild","GetPranked","EARN_FRUITS",
            "FIGHT4FRUIT","NOEXPLOITER","NOOB2ADMIN","CODESLIDE","ADMINHACKED","ADMINDARES",
            "fruitconcepts","krazydares","TRIPLEABUSE","SEATROLLING","24NOADMIN","REWARDFUN",
            "NEWTROLL","fudd10_v2","Fudd10","Bignews","SECRET_ADMIN"}
        for _,c in ipairs(codes) do
            pcall(function() ReplicatedStorage.Remotes.Redeem:InvokeServer(c) end)
        end
        Rayfield:Notify({Title="FyZe Hub", Content="All codes redeemed.", Duration=3})
    end,
})
MiscTab:CreateSection("Stats")
MiscTab:CreateDropdown({
    Name="Auto Stats", Options={"Off","Melee","Defense","Sword","Gun","Fruit"},
    CurrentOption="Off", Flag="AutoStats",
    Callback=function(v)
        task.spawn(function()
            local m={Melee="Melee",Defense="Defense",Sword="Sword",Gun="Gun",Fruit="Demon Fruit"}
            local sel=tostring(v)
            while sel~="Off" and m[sel] do
                pcall(function() ReplicatedStorage.Remotes.CommF_:InvokeServer("AddPoint",m[sel],3) end)
                task.wait(0.5)
                sel=tostring(v)
            end
        end)
    end,
})
