local hints = {
    "You seem to have freeze'd out...",
    "Maybe something that can keep you warm?"
}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

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

-- Improved model loader
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

        if not objects or #objects == 0 then
            error("The model file returned no objects.")
        end

        -- Prefer a Model if one exists.
        local selected

        for _, object in ipairs(objects) do
            if object:IsA("Model") then
                selected = object
                break
            end
        end

        selected = selected or objects[1]

        -- Preserve the selected object and clean up extras.
        for _, object in ipairs(objects) do
            if object ~= selected then
                object:Destroy()
            end
        end

        return selected
    end

    -- Try cached file.
    if isfile then
        local ok, exists = pcall(isfile, fileName)

        if ok and exists then
            local success, model = pcall(loadFile)

            if success and model then
                print("EVILBITE: Loaded cached model.")
                return model
            end

            warn("EVILBITE: Cached model failed; redownloading.")
        end
    end

    -- Download model.
    local ok, response = pcall(function()
        return request({
            Url = url,
            Method = "GET"
        })
    end)

    if not ok or not response or response.StatusCode ~= 200 then
        warn(
            "EVILBITE: Download failed.",
            response and response.StatusCode or "No response"
        )
        return nil
    end

    -- Save model file.
    local saved, saveError = pcall(function()
        writefile(fileName, response.Body)
    end)

    if not saved then
        warn("EVILBITE: Could not save model:", saveError)
        return nil
    end

    -- Deserialize model.
    local loaded, model = pcall(loadFile)

    if not loaded or not model then
        warn("EVILBITE: Could not load model:", model)
        return nil
    end

    print("EVILBITE: Model deserialized successfully.")
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
        warn("EVILBITE: Camera shaker failed:", camShake)
        return
    end

    -- Load model
    local entity = G.LoadGithubModel(EVILBITE_URL)

    if not entity then
        warn("EVILBITE: Model failed to load. Check the console.")
        return
    end

    entity.Name = "EVILBITE"

    local partCount = 0

    if entity:IsA("BasePart") then
        partCount = 1
    end

    for _, object in ipairs(entity:GetDescendants()) do
        if object:IsA("BasePart") then
            partCount += 1
            object.LocalTransparencyModifier = 0
        end
    end

    if partCount == 0 then
        warn("EVILBITE: Model contains no BaseParts.")
        entity:Destroy()
        return
    end

    entity.Parent = workspace

    local part = entity:IsA("BasePart")
        and entity
        or entity:FindFirstChildWhichIsA("BasePart", true)

    if not part then
        warn("EVILBITE: No usable part found.")
        entity:Destroy()
        return
    end

    print("EVILBITE: Loaded", entity.ClassName, "with", partCount, "parts.")

    -- Position model at a room node
    local nodes = room:FindFirstChild("Nodes")
    local positioned = false

    if nodes then
        local nodeList = nodes:GetChildren()

        if #nodeList > 0 then
            local node = nodeList[math.random(1, #nodeList)]

            if node:IsA("BasePart") then
                local target = node.CFrame
                    * CFrame.new(
                        math.random(5, 10),
                        6,
                        math.random(5, 10)
                    )

                if entity:IsA("Model") then
                    entity:PivotTo(target)
                elseif entity:IsA("BasePart") then
                    entity.CFrame = target
                end

                positioned = true
                print("EVILBITE: Positioned at", target.Position)
            end
        end
    end

    if not positioned then
        local character = player.Character

        if character then
            local target = character:GetPivot() * CFrame.new(0, 6, -25)

            if entity:IsA("Model") then
                entity:PivotTo(target)
            elseif entity:IsA("BasePart") then
                entity.CFrame = target
            end

            print("EVILBITE: Used fallback position.")
        else
            warn("EVILBITE: Could not position model.")
        end
    end

    print("EVILBITE pivot:", entity:GetPivot().Position)

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
    local humanoid = character
        and character:FindFirstChildOfClass("Humanoid")

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

        survived = currentHumanoid ~= nil
            and currentHumanoid.Health > 0
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
        local success, err = pcall(function()
            CustomAchievements:Grant(ACHIEVEMENT, {
                CheckOwned = true,
                Remember = true
            })
        end)

        if not success then
            warn("EVILBITE: Achievement failed:", err)
        end
    end

    task.wait(2.6)

    if entity.Parent then
        entity:Destroy()
    end
end)
