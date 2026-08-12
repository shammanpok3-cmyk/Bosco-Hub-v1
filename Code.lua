-- Compatibility shim: prefer task.wait but fall back to wait()
if type(task) ~= "table" or type(task.wait) ~= "function" then
    repeat wait() until game:IsLoaded()
else
    repeat task.wait() until game:IsLoaded()
end

-- Safe no-op shims for executor-only globals so the script doesn't error in Studio / non-executor envs
if type(mousemoverel) ~= "function" then mousemoverel = function(...) end end
if type(mouse1press) ~= "function" then mouse1press = function(...) end end
if type(mouse1release) ~= "function" then mouse1release = function(...) end end
if type(hookmetamethod) ~= "function" then hookmetamethod = nil end
if type(writefile) ~= "function" then writefile = nil end
if type(readfile) ~= "function" then readfile = nil end
if type(isfile) ~= "function" then isfile = nil end
if type(queue_on_teleport) ~= "function" then queue_on_teleport = nil end

-- Preserve existing Drawing check usage (some code uses pcall to detect Drawing)
local hasDrawing = pcall(function() return Drawing and Drawing.new end)

repeat task.wait() until game:IsLoaded()

--[[
    Bosco Hub V1 — LocalScript (PC)
    Made by Bosco
    RightShift / RightCtrl → open/close menu
]]

local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local Workspace = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")

local LP = Players.LocalPlayer
local PGui = LP:FindFirstChild("PlayerGui") or LP:WaitForChild("PlayerGui", 10)
local Camera = Workspace.CurrentCamera

-- TEAM CHECK (Auto TeamID)
local function isTeammate(player)
    if not player then return false end
    if player:GetAttribute("TeamID") == LP:GetAttribute("TeamID") then return true end
    return false
end

-- UTILITY
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Blacklist
rayParams.IgnoreWater = true
local function isTargetVisible(origin, targetPos, targetPlayerObj)
    local ignoreList = {LP.Character}
    if targetPlayerObj and targetPlayerObj.Character then table.insert(ignoreList, targetPlayerObj.Character) end
    rayParams.FilterDescendantsInstances = ignoreList
    local dir = (targetPos - origin)
    if dir.Magnitude <= 0 then return true end
    local result = Workspace:Raycast(origin, dir.Unit * dir.Magnitude, rayParams)
    if not result then return true end
    local hit = result.Instance
    local isSmoke = hit.Transparency > 0.5 or not hit.CanCollide or hit.Name:lower():find("smoke") or hit.Name:lower():find("effect") or hit.Name:lower():find("particle")
    if not isSmoke and hit.Parent then isSmoke = hit.Parent.Name:lower():find("smoke") or hit.Parent.Name:lower():find("grenade") end
    if isSmoke then
        local newIgnoreList = {}
        for _, v in ipairs(ignoreList) do table.insert(newIgnoreList, v) end
        table.insert(newIgnoreList, hit)
        rayParams.FilterDescendantsInstances = newIgnoreList
        local newOrigin = result.Position + dir.Unit * 0.1
        local newDist = (targetPos - newOrigin).Magnitude
        if newDist <= 0 then return true end
        return Workspace:Raycast(newOrigin, dir.Unit * newDist, rayParams) == nil
    end
    return false
end

local Features = {}

-- ANTI-CHEAT BYPASS (Safe)
local Services = setmetatable({}, {__index = function(_, k) return game:GetService(k) end})
local function SafeDestroy(obj)
    if typeof(obj) == "Instance" then pcall(function() obj:Destroy() end) end
end
local function DeepCleanup()
    for _, v in ipairs(LP.PlayerGui:GetDescendants()) do
        if v.Name == "ClientAlert" or v.Name == "LocalScript3" then SafeDestroy(v) end
    end
    for _, v in ipairs((LP:FindFirstChild("PlayerScripts") and LP.PlayerScripts:GetDescendants() or {})) do
        if v.Name == "ClientAlert" or v.Name == "LocalScript3" then SafeDestroy(v) end
    end
end
...
task.spawn(function() while task.wait(10) do DeepCleanup() end end)
DeepCleanup()

-- Drawing check
local hasDrawing = pcall(function() return Drawing.new("Circle") end)

-- INFINITE JUMP
Features.infiniteJumpEnabled = false
Features.infiniteJumpPower = 50
local jumpHeld, lastJump = false, 0
local function getHum() local c = LP.Character; return c and c:FindFirstChildOfClass("Humanoid") end
UIS.InputBegan:Connect(function(input) if input.KeyCode == Enum.KeyCode.Space then jumpHeld = true end end)
UIS.InputEnded:Connect(function(input) if input.KeyCode == Enum.KeyCode.Space then jumpHeld = false end end)
RunService.RenderStepped:Connect(function()
    if not Features.infiniteJumpEnabled or not jumpHeld then return end
    local hum = getHum()
    if not hum or hum.FloorMaterial ~= Enum.Material.Air then return end
    if tick() - lastJump < 0.1 then return end
    hum.JumpPower = Features.infiniteJumpPower
    hum.Jump = true; hum:ChangeState(Enum.HumanoidStateType.Jumping)
    lastJump = tick()
end)
function Features.setInfiniteJump(on) Features.infiniteJumpEnabled = on end
LP.CharacterAdded:Connect(function() task.wait(0.2); jumpHeld = false end)

-- ESP
Features.espEnabled = false
Features.espSettings = { Box=true, BoxFilled=false, Name=true, Distance=true, TeamCheck=true }
local espObjects, espLoop = {}, nil
local function teamCol(p) return p.Team and p.Team.TeamColor.Color or Color3.fromRGB(255,60,60) end
local function isEnemy(p) return not (Features.espSettings.TeamCheck and isTeammate(p)) end
local function removeESP(p) local d = espObjects[p]; if d then if d.hl and d.hl.Parent then d.hl:Destroy() end; if d.bb and d.bb.Parent then d.bb:Destroy() end; espObjects[p] = nil end end
local function removeAllESP() for p in pairs(espObjects) do removeESP(p) end end
local function updateESP(p)
    if p == LP then return end
    local char = p.Character; local hrp = char and char:FindFirstChild("HumanoidRootPart"); local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not Features.espEnabled or not char or not hrp or not hum or hum.Health <= 0 or not isEnemy(p) then removeESP(p); return end
    local d = espObjects[p] or {}; espObjects[p] = d; local col = teamCol(p)
    if Features.espSettings.Box or Features.espSettings.BoxFilled then
        if not d.hl or not d.hl.Parent then local h = Instance.new("Highlight"); h.Name="BHESP"; h.Adornee=char; h.Parent=char; d.hl=h end
        d.hl.OutlineColor=col; d.hl.FillColor=col; d.hl.OutlineTransparency=Features.espSettings.Box and 0 or 1; d.hl.FillTransparency=Features.espSettings.BoxFilled and 0.55 or 1; d.hl.Enabled=true
    elseif d.hl then d.hl:Destroy(); d.hl=nil end
    if Features.espSettings.Name or Features.espSettings.Distance then
        if not d.bb or not d.bb.Parent then
            local bb=Instance.new("BillboardGui"); bb.Name="BHBB"; bb.AlwaysOnTop=true; bb.Size=UDim2.fromOffset(130,44); bb.StudsOffset=Vector3.new(0,3.5,0); bb.Adornee=hrp; bb.Parent=hrp
            local ul=Instance.new("UIListLayout"); ul.HorizontalAlignment=Enum.HorizontalAlignment.Center; ul.SortOrder=Enum.SortOrder.LayoutOrder; ul.Parent=bb
            local nl=Instance.new("TextLabel"); nl.Name="NL"; nl.BackgroundTransparency=1; nl.Size=UDim2.new(1,0,0,18); nl.Font=Enum.Font.GothamBold; nl.TextSize=13; nl.TextStrokeTransparency=0.4; nl.[...]
            local dl=Instance.new("TextLabel"); dl.Name="DL"; dl.BackgroundTransparency=1; dl.Size=UDim2.new(1,0,0,16); dl.Font=Enum.Font.Gotham; dl.TextSize=11; dl.TextStrokeTransparency=0.4; dl.Layo[...]
            d.bb=bb
        end
        local bb=d.bb; bb.Adornee=hrp; bb.Enabled=true
        local nl=bb:FindFirstChild("NL"); if nl then nl.Visible=Features.espSettings.Name; if Features.espSettings.Name then nl.Text=p.DisplayName~="" and p.DisplayName or p.Name; nl.TextColor3=col en[...]
        local dl=bb:FindFirstChild("DL"); if dl then dl.Visible=Features.espSettings.Distance; if Features.espSettings.Distance then dl.Text=math.floor((Camera.CFrame.Position-hrp.Position).Magnitude)[...]
    elseif d.bb then d.bb:Destroy(); d.bb=nil end
end
local function startESPLoop() if espLoop then return end; espLoop=RunService.RenderStepped:Connect(function() if not Features.espEnabled then return end; for _,p in ipairs(Players:GetPlayers()) do upd[...]
local function stopESPLoop() if espLoop then espLoop:Disconnect(); espLoop=nil end end
function Features.setESP(on) Features.espEnabled=on; if on then startESPLoop() else stopESPLoop(); removeAllESP() end end
function Features.setESPSetting(k,v) Features.espSettings[k]=v; if Features.espEnabled then for _,p in ipairs(Players:GetPlayers()) do updateESP(p) end end end
Players.PlayerRemoving:Connect(removeESP)
LP.CharacterAdded:Connect(function() task.wait(0.2); if Features.espEnabled then removeAllESP() end end)

-- SILENT AIM (Gun Hook Method)
Features.silentAimEnabled = false
Features.silentAimSettings = { FOV=300, MaxDistance=500, HitPart="Head", TeamCheck=true, ShowFOV=true }
local silentAimHooked = false
local silentFovCircle = nil

local function setupSilentAim()
    if silentAimHooked then return end
    silentAimHooked = true
    
    pcall(function()
        local Gun = require(LP.PlayerScripts.Modules.ItemTypes.Gun)
        local Utility = require(game:GetService("ReplicatedStorage").Modules.Utility)
        local originalStartShooting = Gun.StartShooting
        
        Gun.StartShooting = function(self, ...)
            local results = {originalStartShooting(self, ...)}
            
            if not self.ClientFighter or not self.ClientFighter.IsLocalPlayer then
                return unpack(results)
            end

[TRUNCATED]
