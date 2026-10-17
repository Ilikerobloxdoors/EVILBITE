local hints = {
    "You seem to have freeze'd out...",
    "Maybe something that can keep you warm?"
}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")

local player = Players.LocalPlayer
local G = getgenv()

-- SETTINGS
local DAMAGE_PER_TICK = 10
local DAMAGE_INTERVAL = 1

local EVILBITE_URL =
    "https://raw.githubusercontent.com/Ilikerobloxdoors/EVILBITE/main/EVILBITE.rbxm"

local ACHIEVEMENT = {
    Identifier = "DontGetBurned",
    Title = "Dont Get Burned",
    Desc = "You Wanna Get Burned Or not?",
    Reason = "Survive And Encounter EvilBite",
    Image = "rbxassetid://12309073114"
}

-- Custom achievements
local CustomAchievements

pcall(function()
    CustomAchievements = loadstring(game:HttpGet(
        "https://raw.githubusercontent.com/RegularVynixu/DOORS-Custom-Achievements/main/init.luau"
    ))()
end)

-- Model loader
G.LoadGithubModel = function(url)
    if not (writefile and getcustomasset and request) then
        warn("EVILBITE: Required file-loading functions are unavailable.")
        return nil
    end

    local hash = 0
    for i = 1, #url do
        hash = (hash * 31 + string.byte(url, i)) % 4294967296
    end

    local fileName = "evilbite_" .. tostring(hash) .. ".rbxm"

    local function loadFile()
        local assetId = getcustomasset(fileName)
        local objects = game:GetObjects(assetId)
        return objects and objects[1]
    end

    if isfile then
        local ok, exists = pcall(isfile, fileName)

        if ok and exists then
            local loaded, model = pcall(loadFile)
            if loaded and model then
                return model
            end
        end
    end

    local ok, response = pcall(function()
        return request({
            Url = url,
            Method = "GET"
        })
    end)

    if not ok or not response or response.StatusCode ~= 200 then
        warn("EVILBITE: Download failed.")
        return nil
    end

    local saved = pcall(function()
        writefile(fileName, response.Body)
    end)

    if not saved then
        warn("EVILBITE: Could not save model file.")
        return nil
    end

    local loaded, model = pcall(loadFile)

    if not loaded or not model then
        warn("EVILBITE: Could not deserialize model.")
        return nil
    end

    return model
end

local function findDescendant(root, name)
    return root and root:FindFirstChild(name, true)
end

local function setEnabled(object, enabled)
    if object and (
        object:IsA("ParticleEmitter")
        or object:IsA("Beam")
        or object:IsA("Trail")
    ) then
        object.Enabled = enabled
    end
end

task.spawn(function()
    local gameData = ReplicatedStorage:WaitForChild("GameData")
    local latestRoom = gameData:WaitForChild("LatestRoom")
    local rooms = workspace:WaitForChild("CurrentRooms")

    local room = rooms:FindFirstChild(tostring(latestRoom.Value))

    if not room then
        warn("EVILBITE: Current room was not found.")
        return
    end

    -- Camera shake
    local camera = workspace.CurrentCamera
    local shakerModule = ReplicatedStorage:FindFirstChild("CameraShaker")

    if not shakerModule then
        warn("EVILBITE: CameraShaker module not found.")
        return
    end

    local ok, camShake = pcall(function()
        local CameraShaker = require(shakerModule)

        local shaker = CameraShaker.new(
            Enum.RenderPriority.Camera.Value,
            function(cf)
                local currentCamera = workspace.CurrentCamera
                if currentCamera then
                    currentCamera.CFrame = currentCamera.CFrame * cf
                end
            end
        )

        shaker:Start()
        return shaker
    end)

    if not ok then
        warn("EVILBITE: Camera shaker failed to initialize.")
        return
    end

    -- Load model
    local entity = G.LoadGithubModel(EVILBITE_URL)

    if not entity then
        warn("EVILBITE: Model failed to load. Check the console.")
        return
    end

    entity.Name = "EVILBITE"
    entity.Parent = workspace

    -- Find a usable part anywhere in the model
    local part

    if entity:IsA("BasePart") then
        part = entity
    else
        part = entity:FindFirstChildWhichIsA("BasePart", true)
    end

    if not part then
        warn("EVILBITE: Model contains no BasePart.")
        entity:Destroy()
        return
    end

    print("EVILBITE loaded:", entity:GetFullName())
    print("Main part:", part:GetFullName())

    -- Position the complete model at a room node
    local nodes = room:FindFirstChild("Nodes")

    if nodes then
        local nodeList = nodes:GetChildren()

        if #nodeList > 0 then
            local node = nodeList[math.random(1, #nodeList)]
            local target = node.CFrame
                * CFrame.new(math.random(5, 10), 6, math.random(5, 10))

            if entity:IsA("Model") then
                entity:PivotTo(target)
            else
                entity.CFrame = target
            end
        else
            warn("EVILBITE: No room nodes available.")
        end
    else
        warn("EVILBITE: Room has no Nodes folder.")
    end

    -- Find sounds and effects
    local static = findDescendant(entity, "Static Effect")
    local ambience = findDescendant(entity, "Ambience")
    local ambienceFar = findDescendant(entity, "AmbienceFar")
    local heylois = findDescendant(entity, "Heylois")
    local face = findDescendant(entity, "face")

    if static and static:IsA("Sound") then
        static:Play()
    end

    local shaking = true
    local active = false
    local intro = true

    -- Intro camera shake
    task.spawn(function()
        while entity.Parent and intro do
            task.wait(0.5)

            if shaking then
                camShake:ShakeOnce(14, 30, 0, 4)
            end
        end
    end)

    task.wait(5.33)

    shaking = false
    intro = false

    if static and static:IsA("Sound") then
        pcall(function()
            TweenService:Create(
                static,
                TweenInfo.new(1.4),
                { PlaybackSpeed = 0 }
            ):Play()
        end)
    end

    task.wait(2.8)

    if ambience and ambience:IsA("Sound") then
        ambience:Play()
    end

    if ambienceFar and ambienceFar:IsA("Sound") then
        ambienceFar:Play()
    end

    setEnabled(heylois, true)
    setEnabled(face, true)

    active = true

    -- Active camera shake
    task.spawn(function()
        while entity.Parent and active do
            task.wait(0.5)

            if not shaking then
                camShake:ShakeOnce(20, 30, 0, 3)
            end
        end
    end)

    -- Heat detection and damage
    task.spawn(function()
        task.wait(1.3)

        while active and entity.Parent do
            local character = player.Character
            local humanoid = character
                and character:FindFirstChildOfClass("Humanoid")

            if humanoid and humanoid.Health > 0 then
                local tool =
                    character:FindFirstChild("Lighter")
                    or character:FindFirstChild("Candle")

                local hasHeat = false

                if tool then
                    for _, object in ipairs(tool:GetDescendants()) do
                        if object:IsA("PointLight") and object.Enabled then
                            hasHeat = true
                            break
                        end
                    end
                end

                if not hasHeat then
                    humanoid:TakeDamage(DAMAGE_PER_TICK)

                    if humanoid.Health <= 0 then
                        pcall(function()
                            local stats = ReplicatedStorage:FindFirstChild("GameStats")
                            local playerStats = stats and stats:FindFirstChild(
                                "Player_" .. player.Name
                            )
                            local total = playerStats and playerStats:FindFirstChild("Total")
                            local cause = total and total:FindFirstChild("DeathCause")

                            if cause then
                                cause.Value = "Frostbite"
                            end
                        end)

                        break
                    end
                end
            end

            task.wait(DAMAGE_INTERVAL)
        end
    end)

    -- Wait for next room or player death
    local survived = false
    local finished = false

    local character = player.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")

    local diedConnection

    if humanoid then
        diedConnection = humanoid.Died:Connect(function()
            finished = true
        end)
    end

    local roomConnection = latestRoom.Changed:Connect(function()
        finished = true

        local currentCharacter = player.Character
        local currentHumanoid = currentCharacter
            and currentCharacter:FindFirstChildOfClass("Humanoid")

        survived = currentHumanoid ~= nil and currentHumanoid.Health > 0
    end)

    while not finished and entity.Parent do
        task.wait(0.1)
    end

    roomConnection:Disconnect()

    if diedConnection then
        diedConnection:Disconnect()
    end

    active = false
    shaking = false
    intro = false

    if ambience and ambience:IsA("Sound") then
        ambience:Stop()
    end

    if ambienceFar and ambienceFar:IsA("Sound") then
        ambienceFar:Stop()
    end

    setEnabled(heylois, false)
    setEnabled(face, false)

    -- Grant achievement for surviving
    if survived and CustomAchievements then
        local ok, err = pcall(function()
            CustomAchievements:Grant(ACHIEVEMENT, {
                CheckOwned = true,
                Remember = true
            })
        end)

        if not ok then
            warn("EVILBITE: Achievement failed:", err)
        end
    end

    task.wait(2.6)

    if entity.Parent then
        entity:Destroy()
    end
end)
