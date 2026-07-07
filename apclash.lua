local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

local THRESHOLD = 2.5
local active = false
local loop_main = nil
local lastVimTick = 0
local lastAnimTick = 0
local aliveCache = {}
local s, u = {}, nil
local connections = {}

-- Track exact Highlight instance
local currentHighlightInstance = nil
local parryPlayedForCurrentHighlight = false
local dynamicDelayTime = 0
local highlightDetectedTime = 0

-- Pre-cached tracks & lifecycle trackers
local cachedGrabTrack = nil
local lastCachedSword = nil
local lastCharacterInstance = nil

local Config = {
    ToggleKey = Enum.KeyCode.P,
    TerminateKey = Enum.KeyCode.Insert,
    AnimCooldown = 0.35,
    SpamAnimRate = 0.045,
}

-- RakNet (make sure it's enabled in your executor)
local raknet = raknet or (getgenv and getgenv().raknet)

local function isPlayerDead()
    return LocalPlayer.Character and LocalPlayer.Character.Parent == workspace.Dead
end

local function getBall()
    local b = workspace:FindFirstChild("Balls")
    if not b then return end
    for _, v in ipairs(b:GetChildren()) do
        if v:GetAttribute("realBall") == true then return v end
    end
end

local function refreshAliveCache()
    local newCache = {}
    local aliveFolder = workspace:FindFirstChild("Alive")
    local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if aliveFolder and hrp then
        local temp = {}
        for _, char in ipairs(aliveFolder:GetChildren()) do
            if char:IsA("Model") and char.PrimaryPart and char ~= LocalPlayer.Character then
                local dist = (hrp.Position - char.PrimaryPart.Position).Magnitude
                table.insert(temp, {c = char, d = dist})
            end
        end
        table.sort(temp, function(a, b) return a.d < b.d end)
        for i = 1, math.min(#temp, 3) do
            table.insert(newCache, temp[i].c)
        end
    end
    aliveCache = newCache
end

local function getClosestPlayer()
    if aliveCache and aliveCache[1] then
        return aliveCache[1]
    end
    return nil
end

local function blockSuccessParry()
    pcall(function()
        local char = LocalPlayer.Character
        if not char then return end
        local hum = char:FindFirstChild("Humanoid")
        local animator = hum and hum:FindFirstChild("Animator")
        if not animator then return end
        for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
            if track.Name:match("Success") or (track.Animation and track.Animation.Name:match("Success")) or track:GetAttribute("SuccessParry") then
                track:Stop(0.05)
            end
        end
    end)
end

local function playGrabParry(forceBypass)
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChild("Humanoid")
    local animator = hum and hum:FindFirstChild("Animator")
   
    if not animator then return false end
   
    if not forceBypass and (tick() - lastAnimTick < Config.AnimCooldown) then
        return false
    end
    
    local swordName = LocalPlayer:GetAttribute("CurrentlyEquippedSword") or "Default"
   
    if lastCharacterInstance ~= char then
        cachedGrabTrack = nil
        lastCharacterInstance = char
        currentHighlightInstance = nil
        parryPlayedForCurrentHighlight = false
    end
    if lastCachedSword ~= swordName then
        cachedGrabTrack = nil
        lastCachedSword = swordName
    end
    if cachedGrabTrack then
        local success, isPlaying = pcall(function() return cachedGrabTrack.IsPlaying end)
        if not success then
            cachedGrabTrack = nil
        end
    end
    if not cachedGrabTrack then
        local api = ReplicatedStorage:FindFirstChild("Shared")
        local swordAPI = api and api:FindFirstChild("SwordAPI")
        local collection = swordAPI and swordAPI:FindFirstChild("Collection")
       
        if collection then
            local swordFolder = collection:FindFirstChild(swordName) or collection:FindFirstChild("Default")
            local grabAnimationObject = nil
           
            if swordFolder then
                local isAccessory = LocalPlayer:GetAttribute("HasAccessoryEquipped") and "Accessory" or "Base"
                local variantFolder = swordFolder:FindFirstChild(isAccessory) or swordFolder
               
                local styleName = LocalPlayer:GetAttribute("AnimationStyle") or "Default"
                local finalFolder = variantFolder:FindFirstChild(styleName) or variantFolder
               
                for _, v in ipairs(finalFolder:GetDescendants()) do
                    if v:IsA("Animation") and v:GetAttribute("GrabParry") then
                        grabAnimationObject = v
                        break
                    end
                end
               
                if not grabAnimationObject then
                    for _, v in ipairs(swordFolder:GetDescendants()) do
                        if v:IsA("Animation") and v:GetAttribute("GrabParry") then
                            grabAnimationObject = v
                            break
                        end
                    end
                end
            end
           
            if not grabAnimationObject then
                for _, v in ipairs(collection:GetDescendants()) do
                    if v:IsA("Animation") and v:GetAttribute("GrabParry") then
                        grabAnimationObject = v
                        break
                    end
                end
            end
            if grabAnimationObject then
                pcall(function()
                    cachedGrabTrack = animator:LoadAnimation(grabAnimationObject)
                    pcall(function() cachedGrabTrack.Priority = Enum.AnimationPriority.Action4 end)
                    if not cachedGrabTrack.Priority then
                        cachedGrabTrack.Priority = Enum.AnimationPriority.Action
                    end
                end)
            end
        end
    end
    if cachedGrabTrack then
        local played = pcall(function()
            if forceBypass or cachedGrabTrack.IsPlaying then
                cachedGrabTrack:Stop(0)
            end
            cachedGrabTrack:Play(0.02)
            cachedGrabTrack:AdjustSpeed(1.1)
        end)
       
        if played then
            lastAnimTick = tick()
            return true
        else
            cachedGrabTrack = nil
        end
    end
   
    return false
end

local function getParryHighlight()
    local char = LocalPlayer.Character
    if not char then return nil end
   
    for _, descendant in ipairs(char:GetDescendants()) do
        if descendant:IsA("Highlight") and descendant.Name == "ParryHighlight" then
            return descendant
        end
    end
    return nil
end

-- RakNet Fire Helper
local function fireParryRakNet(remote, baseArgs)
    if not remote or not baseArgs then return end
    
    local args = table.clone(baseArgs)
    
    -- Build dynamic data
    local aliveTable = {}
    if type(aliveCache) == "table" then
        for _, char2 in ipairs(aliveCache) do
            if char2 and char2.Parent and char2.PrimaryPart then
                aliveTable[char2.Name] = Camera:WorldToScreenPoint(char2.PrimaryPart.Position)
            end
        end
    end
    local mousePos = {UserInputService:GetMouseLocation().X, UserInputService:GetMouseLocation().Y}
    
    -- Update key arguments
    args[4] = Camera.CFrame
    args[5] = aliveTable
    args[6] = mousePos
    
    -- Try RakNet first
    local sent = false
    if raknet then
        pcall(function()
            raknet.send(args, 2, 2, 0)  -- High priority, reliable ordered
            sent = true
        end)
    end
    
    -- Fallback
    if not sent then
        pcall(function()
            remote:FireServer(unpack(args))
        end)
    end
end

local function rawExecutionCycle()
    if not active then return end
    if isPlayerDead() then return end
   
    local now = tick()
    local ball = getBall()
    local char = LocalPlayer.Character
   
    if char and lastCharacterInstance ~= char then
        cachedGrabTrack = nil
        lastCharacterInstance = char
        currentHighlightInstance = nil
        parryPlayedForCurrentHighlight = false
    end
   
    local isClashing = false
    if ball and ball:GetAttribute("target") == LocalPlayer.Name then
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        local closestEnemy = getClosestPlayer()
       
        if hrp and closestEnemy and closestEnemy.PrimaryPart then
            local ballVel = ball.AssemblyLinearVelocity.Magnitude
            local playerToBallDist = (hrp.Position - ball.Position).Magnitude
            local playerToEnemyDist = (hrp.Position - closestEnemy.PrimaryPart.Position).Magnitude
           
            local ping = 5
            local dynamicRange = (ping + math.min(ballVel / 6, 95))
           
            if playerToBallDist <= dynamicRange and playerToEnemyDist <= (dynamicRange * 1.5) and playerToBallDist <= 25 then
                isClashing = true
            end
        end
    end

    if isClashing then
        if now - lastAnimTick >= Config.SpamAnimRate then
            playGrabParry(false)
        end
    else
        local targetHighlight = getParryHighlight()
       
        if targetHighlight then
            local isNewHighlight = false
           
            if currentHighlightInstance ~= targetHighlight then
                currentHighlightInstance = targetHighlight
                parryPlayedForCurrentHighlight = false
                isNewHighlight = true
                highlightDetectedTime = now
                dynamicDelayTime = math.random(12, 38) / 1000
            end
           
            if not parryPlayedForCurrentHighlight then
                if isNewHighlight or (now - highlightDetectedTime >= dynamicDelayTime) then
                    local fired = playGrabParry(isNewHighlight)
                    if fired then
                        parryPlayedForCurrentHighlight = true
                    end
                end
            end
        else
            currentHighlightInstance = nil
            parryPlayedForCurrentHighlight = false
        end
    end

    -- RakNet Parry Firing
    if u and type(s) == "table" then
        for remote, cap in pairs(s) do
            if remote and cap then
                task.spawn(function()
                    fireParryRakNet(remote, cap)
                end)
            end
        end
    end

    blockSuccessParry()
end

-- Setup hooks
local function setupHooks()
    oth.hook(Instance.new("RemoteEvent").FireServer, function(self, ...)
        local args = {...}
        if #args == 7 and type(args[2]) == "string" then
            u = args[2]
            s[self] = args
        end
        return oth.get_root_callback()(self, unpack(args))
    end)
end

setupHooks()
refreshAliveCache()

local cacheThread = task.spawn(function()
    while task.wait(3) do
        refreshAliveCache()
    end
end)

local function flushStateCache()
    cachedGrabTrack = nil
    lastCharacterInstance = nil
    currentHighlightInstance = nil
    parryPlayedForCurrentHighlight = false
end

local charAddedConn = LocalPlayer.CharacterAdded:Connect(flushStateCache)
local charAppearedConn = LocalPlayer.CharacterAppearanceLoaded:Connect(flushStateCache)

local function terminate()
    active = false
    if loop_main then loop_main:Disconnect() end
    if cacheThread then task.cancel(cacheThread) end
    if charAddedConn then charAddedConn:Disconnect() end
    if charAppearedConn then charAppearedConn:Disconnect() end
    for _, conn in ipairs(connections) do
        if conn then conn:Disconnect() end
    end
    s, aliveCache = nil, nil
    cachedGrabTrack = nil
    lastCharacterInstance = nil
    oth.unhook(Instance.new("RemoteEvent").FireServer)
end

table.insert(connections, UserInputService.InputBegan:Connect(function(i, g)
    if i.KeyCode == Config.TerminateKey then
        terminate()
        return
    end
    if g then return end
    if i.KeyCode == Config.ToggleKey then
        if isPlayerDead() then return end
        active = true
        if not loop_main then
            loop_main = RunService.Heartbeat:Connect(rawExecutionCycle)
        end
    end
end))

table.insert(connections, UserInputService.InputEnded:Connect(function(i)
    if i.KeyCode == Config.ToggleKey then
        active = false
        if loop_main then 
            loop_main:Disconnect() 
            loop_main = nil 
        end
    end
end))
