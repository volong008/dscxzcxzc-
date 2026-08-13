-- Services
local Players           = game:GetService("Players")
local Workspace         = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")
local HttpService       = game:GetService("HttpService")
local CoreGui           = game:GetService("CoreGui")
local Lighting          = game:GetService("Lighting")
local MaterialService   = game:GetService("MaterialService")
local TeleportService   = game:GetService("TeleportService")
local GuiService        = game:GetService("GuiService")
local RunService        = game:GetService("RunService")

local Player = Players.LocalPlayer

-- ========================================
-- AUTO REJOIN SYSTEM UPDATED
-- ========================================

local function DoRejoin()
    task.wait(2)
    if #Players:GetPlayers() <= 1 then
        TeleportService:Teleport(game.PlaceId, Player)
    else
        TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, Player)
    end
end

local function EnableAutoRejoin()
    if not getgenv().Config or not getgenv().Config["Auto Rejoin"] then return end

    GuiService.ErrorMessageChanged:Connect(function()
        DoRejoin()
    end)

    task.spawn(function()
        local robloxPromptGui = CoreGui:WaitForChild("RobloxPromptGui", 10)
        if robloxPromptGui then
            local promptOverlay = robloxPromptGui:WaitForChild("promptOverlay", 10)
            if promptOverlay then
                promptOverlay.ChildAdded:Connect(function(child)
                    if child.Name == "ErrorPrompt" then
                        DoRejoin()
                    end
                end)
            end
        end
    end)
end

task.spawn(EnableAutoRejoin)

-- ========================================
-- FPS CAP SYSTEM
-- ========================================

local function ApplyFPSCap()
    if getgenv().Config and getgenv().Config["FPS CAP"] then
        local fpsLimit = tonumber(getgenv().Config["FPS CAP"])
        if fpsLimit and type(setfpscap) == "function" then
            setfpscap(fpsLimit)
        end
    end
end

task.spawn(ApplyFPSCap)

-- ========================================
-- EXTREME FPS BOOST & PURGE SYSTEM
-- ========================================

local function ApplyFPSBoost()
    if not getgenv().Config or not getgenv().Config["FPS BOOST"] then return end

    pcall(function()
        settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
        settings().Rendering.MeshPartDetailLevel = Enum.MeshPartDetailLevel.Level00
    end)

    if getgenv().Config["Enable Gui"] then
        pcall(function()
            RunService:Set3DRenderingEnabled(false)
        end)
    end

    pcall(function()
        Lighting.GlobalShadows = false
        Lighting.EnvironmentDiffuseScale = 0
        Lighting.EnvironmentSpecularScale = 0
        Lighting.Brightness = 0
        Lighting.FogEnd = 9e9
        Lighting.Technology = Enum.Technology.Compatibility
        Lighting.Outlines = false
    end)

    for _, obj in ipairs(Lighting:GetChildren()) do
        pcall(function() obj:Destroy() end)
    end
    Lighting.ChildAdded:Connect(function(obj)
        task.defer(function() pcall(function() obj:Destroy() end) end)
    end)

    local Terrain = Workspace:FindFirstChildOfClass("Terrain")
    if Terrain then
        pcall(function()
            Terrain:Clear()
            Terrain.Decoration = false
            Terrain.WaterWaveSize = 0
            Terrain.WaterWaveSpeed = 0
            Terrain.WaterReflectance = 0
            Terrain.WaterTransparency = 1
        end)
    end

    local function ExtremePurge(obj)
        pcall(function()
            if obj:IsA("Sky") or obj:IsA("Atmosphere") or obj:IsA("Clouds") or obj:IsA("Decal") 
            or obj:IsA("Texture") or obj:IsA("SurfaceAppearance") or obj:IsA("ShirtGraphic") 
            or obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Beam") 
            or obj:IsA("Smoke") or obj:IsA("Fire") or obj:IsA("Sparkles") 
            or obj:IsA("Highlight") or obj:IsA("Explosion") or obj:IsA("PostEffect") 
            or obj:IsA("Light") or obj:IsA("Sound") then
                obj:Destroy()
            elseif obj:IsA("BasePart") then
                obj.CastShadow = false
                obj.Material = Enum.Material.SmoothPlastic
                obj.Reflectance = 0
                if obj:IsA("MeshPart") then
                    obj.TextureID = ""
                end
                local specMesh = obj:FindFirstChildOfClass("SpecialMesh")
                if specMesh then
                    specMesh.TextureId = ""
                end
            end
        end)
    end

    for _, obj in ipairs(Workspace:GetDescendants()) do
        ExtremePurge(obj)
    end

    Workspace.DescendantAdded:Connect(function(obj)
        task.defer(ExtremePurge, obj)
    end)

    local function CleanCharacter(character)
        for _, obj in ipairs(character:GetDescendants()) do
            pcall(function()
                if obj:IsA("Accessory") or obj:IsA("Shirt") or obj:IsA("Pants") 
                or obj:IsA("CharacterAppearance") or obj:IsA("BodyColors") then
                    obj:Destroy()
                else
                    ExtremePurge(obj)
                end
            end)
        end
    end

    if Player.Character then CleanCharacter(Player.Character) end
    Player.CharacterAdded:Connect(function(char)
        task.wait(0.1)
        CleanCharacter(char)
    end)

    pcall(function()
        MaterialService:ClearToDefault()
        for _, obj in ipairs(MaterialService:GetChildren()) do obj:Destroy() end
    end)
end

task.spawn(ApplyFPSBoost)

-- ========================================
-- FARMSYNC AUTO CHANGE CLIENT MODULE
-- ========================================

local function GetAutoDeviceKey()
    return getgenv().locked_device_key 
        or getgenv().device_key 
        or (getgenv().FarmSync and getgenv().FarmSync.device_key)
        or (getgenv().Config and getgenv().Config.device_key)
end

local FarmSyncClient = {}
FarmSyncClient.__index = FarmSyncClient

function FarmSyncClient.new()
    return setmetatable({
        _username   = Player.Name,
        _device_key = GetAutoDeviceKey(),
        _api_url    = "https://api.farmsync.cloud/api/client/"
    }, FarmSyncClient)
end

function FarmSyncClient:GetHeaders()
    return {
        ["x-auth-token"] = tostring(self._device_key or ""),
        ["Content-Type"]  = "application/json"
    }
end

function FarmSyncClient:ChangeToFolder(from, to, without_replacement)
    if not self._device_key or self._device_key == "" then return false end

    local endpoint = self._api_url .. "changeaccounttofolder/"
    local bodyData = HttpService:JSONEncode({
        username = self._username,
        from = from,
        to = to,
        change_without_replacement = without_replacement or false,
        data = "",
        final_config_id = nil
    })

    local response = request({
        Url     = endpoint,
        Method  = "POST",
        Body    = bodyData,
        Headers = self:GetHeaders()
    })

    if response and response.Body then
        local ok, data = pcall(HttpService.JSONDecode, HttpService, response.Body)
        if ok and type(data) == "table" and not data.error then
            return true
        end
    end
    return false
end

local isChangingFolder = false

local function TriggerAutoChange(fromFolder, toFolder, reason)
    if isChangingFolder then return end

    local farmSyncCfg = getgenv().Config["Auto Change"] and getgenv().Config["Auto Change"]["Farm Sync"]
    if not farmSyncCfg or not farmSyncCfg["Enable"] then return end

    isChangingFolder = true
    local withoutReplacement = farmSyncCfg["Without Replacement"] or false

    local client = FarmSyncClient.new()
    local success = client:ChangeToFolder(fromFolder, toFolder, withoutReplacement)

    if success then
        task.wait(1)
        game:Shutdown()
    else
        isChangingFolder = false
    end
end

-- ========================================
-- HELPER FUNCTIONS
-- ========================================

local function GetPlayerLevel()
    local level = 0
    local leaderstats = Player:FindFirstChild("leaderstats")
    if leaderstats then
        local lvlObj = leaderstats:FindFirstChild("Level") or leaderstats:FindFirstChild("LVL") or leaderstats:FindFirstChild("level")
        if lvlObj then level = tonumber(lvlObj.Value) or 0 end
    end
    if level == 0 then
        for name, value in pairs(Player:GetAttributes()) do
            if string.lower(name) == "level" then
                level = tonumber(value) or 0
                break
            end
        end
    end
    return level
end

local ItemData = nil
pcall(function()
    ItemData = require(ReplicatedStorage:WaitForChild("Database"):WaitForChild("Sync"):WaitForChild("Item"))
end)

local function FindRarity(data, target)
    if target == "Icecream" or target == "IcecreamChroma" then return "Godly" end
    if type(data) ~= "table" then return nil end
    local item = data[target]
    if type(item) == "table" and item.Rarity then return item.Rarity end
    for _, v in pairs(data) do
        if type(v) == "table" then
            if v.Name == target or v.ItemName == target then return v.Rarity end
            local rarity = FindRarity(v, target)
            if rarity then return rarity end
        end
    end
end

local function HasGodlyOrIcecream()
    local found = false
    pcall(function()
        local ProfileDataModule = ReplicatedStorage:WaitForChild("Modules", 1):WaitForChild("ProfileData", 1)
        if ProfileDataModule then
            local ProfileData = require(ProfileDataModule)
            for _, category in ipairs({"Weapons", "Pets", "Materials"}) do
                local catData = ProfileData[category]
                if catData and catData.Owned then
                    for itemName, amount in pairs(catData.Owned) do
                        if amount and amount > 0 then
                            if itemName == "Icecream" or itemName == "IcecreamChroma" then found = true return end
                            local rarity = FindRarity(ItemData, itemName)
                            if rarity and string.lower(tostring(rarity)) == "godly" then found = true return end
                        end
                    end
                end
            end
        end
    end)
    return found
end

-- ========================================
-- DISCORD WEBHOOK SYSTEM
-- ========================================

local function sendDiscordWebhook(itemName, rarity)
    local webhookUrl = getgenv().Config["Webhook URL"]
    if not webhookUrl or webhookUrl == "" then return end

    local discordId = getgenv().Config["Discord ID"] or ""
    local pingText = discordId ~= "" and ("<@" .. discordId .. ">") or ""

    local rarityColors = {
        ["Common"] = 10066329, ["Uncommon"] = 3381555, ["Rare"] = 3368703,
        ["Legendary"] = 16737792, ["Godly"] = 16718105, ["Ancient"] = 16711680, ["Chroma"] = 16711935
    }

    local payload = {
        ["content"] = pingText,
        ["embeds"] = {{
            ["title"] = "🎉 UNBOXED RARE ITEM!",
            ["description"] = "Bạn vừa mở ra một vật phẩm phẩm cấp cao!",
            ["color"] = rarityColors[rarity] or 65535,
            ["fields"] = {
                { ["name"] = "👤 Player", ["value"] = string.format("`%s` (@%s)", Player.DisplayName, Player.Name), ["inline"] = true },
                { ["name"] = "🗡️ Item", ["value"] = string.format("`%s`", tostring(itemName)), ["inline"] = true },
                { ["name"] = "⭐ Rarity", ["value"] = string.format("**%s**", tostring(rarity)), ["inline"] = true }
            },
            ["footer"] = { ["text"] = "Cream Services MM2 Auto Farm • " .. os.date("%X") },
            ["timestamp"] = DateTime.now():ToIsoDate()
        }}
    }

    local httpRequest = (syn and syn.request) or (http and http.request) or http_request or (Fluxus and Fluxus.request) or request
    if httpRequest then
        pcall(function()
            httpRequest({
                Url = webhookUrl, Method = "POST",
                Headers = {["Content-Type"] = "application/json"},
                Body = HttpService:JSONEncode(payload)
            })
        end)
    end
end

local InventoryRemotes = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Inventory")
local ChangeInventoryItem = InventoryRemotes:WaitForChild("ChangeInventoryItem")

ChangeInventoryItem.OnClientEvent:Connect(function(category, item, amount)
    local rarity = FindRarity(ItemData, item) or "Unknown"
    local notifyList = getgenv().Config["Notify Rarity"] or {}
    for _, targetRarity in ipairs(notifyList) do
        if string.lower(tostring(rarity)) == string.lower(tostring(targetRarity)) or item == "Icecream" or item == "IcecreamChroma" then
            sendDiscordWebhook(item, rarity)
            break
        end
    end
end)

-- ========================================
-- AUTO OPEN CRATE LOGIC
-- ========================================

local isOpeningCrate = false
local function checkAndOpenCrate(keysCount)
    if keysCount >= 120 and not isOpeningCrate then
        isOpeningCrate = true
        task.spawn(function()
            local args = { "Summer2026Box", "MysteryBox", "SummerKey2026" }
            pcall(function()
                ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Shop"):WaitForChild("OpenCrate"):InvokeServer(unpack(args))
            end)
            task.wait(2)
            isOpeningCrate = false
        end)
    end
end

-- ========================================
-- MODERN ULTRA GUI + TOGGLE ICON
-- ========================================

local GuiElements = {}
local startTime = os.clock()
local isGuiVisible = true

local function createUI()
    if not getgenv().Config or not getgenv().Config["Enable Gui"] then return end

    local existingUI = CoreGui:FindFirstChild("MM2AutoFarmGUI")
    if existingUI then existingUI:Destroy() end

    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "MM2AutoFarmGUI"
    screenGui.ResetOnSpawn = false
    screenGui.IgnoreGuiInset = true 
    screenGui.Parent = CoreGui

    local mainFrame = Instance.new("Frame")
    mainFrame.Name = "MainFrame"
    mainFrame.Size = UDim2.new(1, 0, 1, 0)
    mainFrame.BackgroundColor3 = Color3.fromRGB(12, 13, 18)
    mainFrame.BorderSizePixel = 0
    mainFrame.Parent = screenGui

    local centerCard = Instance.new("Frame")
    centerCard.Name = "CenterCard"
    centerCard.Size = UDim2.new(0, 480, 0, 520)
    centerCard.Position = UDim2.new(0.5, -240, 0.5, -260)
    centerCard.BackgroundColor3 = Color3.fromRGB(20, 22, 30)
    centerCard.BorderSizePixel = 0
    centerCard.Parent = mainFrame

    local cardCorner = Instance.new("UICorner")
    cardCorner.CornerRadius = UDim.new(0, 16)
    cardCorner.Parent = centerCard

    local cardStroke = Instance.new("UIStroke")
    cardStroke.Color = Color3.fromRGB(45, 50, 70)
    cardStroke.Thickness = 1.5
    cardStroke.Parent = centerCard

    local header = Instance.new("Frame")
    header.Size = UDim2.new(1, 0, 0, 90)
    header.BackgroundTransparency = 1
    header.Parent = centerCard

    local logoText = Instance.new("TextLabel")
    logoText.Size = UDim2.new(1, 0, 0, 32)
    logoText.Position = UDim2.new(0, 0, 0, 18)
    logoText.BackgroundTransparency = 1
    logoText.Text = "CREAM SERVICES"
    logoText.TextColor3 = Color3.fromRGB(0, 230, 180)
    logoText.Font = Enum.Font.FredokaOne
    logoText.TextSize = 26
    logoText.Parent = header

    local subText = Instance.new("TextLabel")
    subText.Size = UDim2.new(1, 0, 0, 20)
    subText.Position = UDim2.new(0, 0, 0, 52)
    subText.BackgroundTransparency = 1
    subText.Text = "MM2 Ultimate Auto Farm • discord.gg/3btrMQPydy"
    subText.TextColor3 = Color3.fromRGB(140, 145, 170)
    subText.Font = Enum.Font.GothamMedium
    subText.TextSize = 13
    subText.Parent = header

    local line = Instance.new("Frame")
    line.Size = UDim2.new(0.85, 0, 0, 2)
    line.Position = UDim2.new(0.075, 0, 0, 90)
    line.BackgroundColor3 = Color3.fromRGB(0, 230, 180)
    line.BorderSizePixel = 0
    line.Parent = centerCard

    local container = Instance.new("Frame")
    container.Size = UDim2.new(0.9, 0, 0, 390)
    container.Position = UDim2.new(0.05, 0, 0, 108)
    container.BackgroundTransparency = 1
    container.Parent = centerCard

    local listLayout = Instance.new("UIListLayout")
    listLayout.SortOrder = Enum.SortOrder.LayoutOrder
    listLayout.Padding = UDim.new(0, 8)
    listLayout.Parent = container

    local rows = {
        {"PROCESS", "Progress WATTING MAP", Color3.fromRGB(255, 170, 0)},
        {"DAILY PROGRESS", "0 / 960", Color3.fromRGB(255, 255, 255)},
        {"CURRENT SUMMER COIN", "0", Color3.fromRGB(85, 255, 127)},
        {"SESSION NORMAIL COIN", "+0", Color3.fromRGB(170, 170, 255)},
        {"ROUND NORMAIL COIN", "0 / 0", Color3.fromRGB(200, 200, 200)},
        {"SESSION TIME", "00:00:00", Color3.fromRGB(0, 230, 255)},
        {"HAVE GODLY", "NO", Color3.fromRGB(255, 85, 85)}
    }

    for idx, rowData in ipairs(rows) do
        local rowFrame = Instance.new("Frame")
        rowFrame.Size = UDim2.new(1, 0, 0, 46)
        rowFrame.BackgroundColor3 = Color3.fromRGB(28, 31, 44)
        rowFrame.BorderSizePixel = 0
        rowFrame.LayoutOrder = idx
        rowFrame.Parent = container

        local rowCorner = Instance.new("UICorner")
        rowCorner.CornerRadius = UDim.new(0, 8)
        rowCorner.Parent = rowFrame

        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(0.5, -15, 1, 0)
        label.Position = UDim2.new(0, 15, 0, 0)
        label.BackgroundTransparency = 1
        label.Text = rowData[1]
        label.TextColor3 = Color3.fromRGB(150, 155, 180)
        label.Font = Enum.Font.GothamBold
        label.TextSize = 12
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.Parent = rowFrame

        local val = Instance.new("TextLabel")
        val.Size = UDim2.new(0.5, -15, 1, 0)
        val.Position = UDim2.new(0.5, 0, 0, 0)
        val.BackgroundTransparency = 1
        val.Text = rowData[2]
        val.TextColor3 = rowData[3]
        val.Font = Enum.Font.GothamBold
        val.TextSize = 13
        val.TextXAlignment = Enum.TextXAlignment.Right
        val.Parent = rowFrame

        GuiElements[rowData[1]] = val
    end

    -- Icon Toggle GUI Button
    local toggleBtn = Instance.new("ImageButton")
    toggleBtn.Name = "ToggleGuiButton"
    toggleBtn.Size = UDim2.new(0, 50, 0, 50)
    toggleBtn.Position = UDim2.new(0, 20, 0, 20)
    toggleBtn.Image = "https://tr.rbxcdn.com/180DAY-be66902a5abc9378827c1473671627f7/420/420/PantsAccessory/Webp/noFilter"
    toggleBtn.BackgroundColor3 = Color3.fromRGB(25, 28, 38)
    toggleBtn.BorderSizePixel = 0
    toggleBtn.Active = true
    toggleBtn.Parent = screenGui

    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(0, 25)
    btnCorner.Parent = toggleBtn

    local btnStroke = Instance.new("UIStroke")
    btnStroke.Color = Color3.fromRGB(0, 230, 180)
    btnStroke.Thickness = 2
    btnStroke.Parent = toggleBtn

    toggleBtn.MouseButton1Click:Connect(function()
        isGuiVisible = not isGuiVisible
        if isGuiVisible then
            mainFrame.Visible = true
            TweenService:Create(mainFrame, TweenInfo.new(0.25), {BackgroundTransparency = 0}):Play()
            TweenService:Create(centerCard, TweenInfo.new(0.25), {Size = UDim2.new(0, 480, 0, 520)}):Play()
        else
            local t1 = TweenService:Create(mainFrame, TweenInfo.new(0.25), {BackgroundTransparency = 1})
            local t2 = TweenService:Create(centerCard, TweenInfo.new(0.25), {Size = UDim2.new(0, 0, 0, 0)})
            t1:Play()
            t2:Play()
            t1.Completed:Wait()
            if not isGuiVisible then
                mainFrame.Visible = false
            end
        end
    end)
end

local function updateGuiText(key, value)
    if GuiElements[key] then
        GuiElements[key].Text = tostring(value)
        if key == "HAVE GODLY" then
            GuiElements[key].TextColor3 = (value == "YES") and Color3.fromRGB(85, 255, 127) or Color3.fromRGB(255, 85, 85)
        end
    end
end

task.spawn(function()
    createUI()
    while true do
        task.wait(1)

        local elapsed = math.floor(os.clock() - startTime)
        local hours = math.floor(elapsed / 3600)
        local mins = math.floor((elapsed % 3600) / 60)
        local secs = elapsed % 60
        updateGuiText("SESSION TIME", string.format("%02d:%02d:%02d", hours, mins, secs))

        local dailyProgressValue = 0
        local keysCount = 0

        pcall(function()
            local ProfileDataModule = ReplicatedStorage:WaitForChild("Modules", 1):WaitForChild("ProfileData", 1)
            if ProfileDataModule then
                local ProfileData = require(ProfileDataModule)

                local myQuests = ProfileData["Summer2026"] and ProfileData["Summer2026"].Quests
                if myQuests then
                    local dailyCoinData = myQuests["DailyCoins"] or myQuests["DailyCoins2026"] or myQuests["Daily Coin"]
                    if dailyCoinData and dailyCoinData.Progress then
                        dailyProgressValue = tonumber(dailyCoinData.Progress) or 0
                        updateGuiText("DAILY PROGRESS", string.format("%s / 960", tostring(dailyCoinData.Progress)))
                    end
                end

                if ProfileData.Materials and ProfileData.Materials.Owned then
                    keysCount = ProfileData.Materials.Owned["SummerKey2026"] or 0
                    updateGuiText("CURRENT SUMMER COIN", tostring(keysCount))
                    checkAndOpenCrate(keysCount)
                end
            end
        end)

        local hasGodly = HasGodlyOrIcecream()
        updateGuiText("HAVE GODLY", hasGodly and "YES" or "NO")

        local farmSyncCfg = getgenv().Config["Auto Change"] and getgenv().Config["Auto Change"]["Farm Sync"]
        if farmSyncCfg and farmSyncCfg["Enable"] and not isChangingFolder then

            if dailyProgressValue >= 960 and keysCount < 120 then
                local questCfg = farmSyncCfg["Daily Quest"]
                if questCfg and questCfg["Folder From"] and questCfg["Folder To"] then
                    TriggerAutoChange(
                        questCfg["Folder From"],
                        questCfg["Folder To"],
                        "Hoàn thành Daily Quest (960/960)"
                    )
                end
            end

            local currentLvl = GetPlayerLevel()
            if currentLvl >= 10 and hasGodly then
                local godlyCfg = farmSyncCfg["Godly And Level 10"]
                if godlyCfg and godlyCfg["Folder From"] and godlyCfg["Folder To"] then
                    TriggerAutoChange(
                        godlyCfg["Folder From"],
                        godlyCfg["Folder To"],
                        "Đạt Level 10 và sở hữu Godly"
                    )
                end
            end

        end
    end
end)

-- ========================================
-- CHECK LOBBY & FARMING LOGIC (SỬA LỖI TẠI ĐÂY)
-- ========================================
local SCAN_DELAY = 0.1
local CONTAINER_SCAN_DELAY = 0.25
local Speed = 200
local RESPAWN_SETTLE_TIME = 0.35

local currentCharacter = nil
local currentHumanoid = nil
local currentRoot = nil
local currentHead = nil

local characterGeneration = 0
local isDeadOrResetting = false
local farmRunning = false

local function clearCharacterRefs()
    currentCharacter = nil
    currentHumanoid = nil
    currentRoot = nil
    currentHead = nil
end

local function forceUnanchor(character)
    if not character then return end
    local root = character:FindFirstChild("HumanoidRootPart")
    local humanoid = character:FindFirstChildOfClass("Humanoid")

    if root then
        pcall(function()
            root.Anchored = false
            root.AssemblyLinearVelocity = Vector3.zero
            root.AssemblyAngularVelocity = Vector3.zero
        end)
    end

    if humanoid then
        pcall(function()
            humanoid.PlatformStand = false
            humanoid.Sit = false
            humanoid.AutoRotate = true
        end)
    end
end

local function setupCharacter(character)
    characterGeneration += 1
    local myGeneration = characterGeneration

    isDeadOrResetting = true

    local humanoid = character:WaitForChild("Humanoid", 8)
    local root = character:WaitForChild("HumanoidRootPart", 8)
    local head = character:WaitForChild("Head", 8)

    if myGeneration ~= characterGeneration then return end

    if not humanoid or not root or not head then
        clearCharacterRefs()
        return
    end

    currentCharacter = character
    currentHumanoid = humanoid
    currentRoot = root
    currentHead = head

    forceUnanchor(character)
    task.wait(RESPAWN_SETTLE_TIME)

    if myGeneration == characterGeneration and character.Parent and humanoid.Health > 0 then
        isDeadOrResetting = false
    end

    humanoid.Died:Connect(function()
        if myGeneration ~= characterGeneration then return end
        isDeadOrResetting = true
        forceUnanchor(character)
    end)
end

Player.CharacterRemoving:Connect(function(character)
    isDeadOrResetting = true
    characterGeneration += 1
    forceUnanchor(character)
    clearCharacterRefs()
end)

Player.CharacterAdded:Connect(function(character)
    task.spawn(setupCharacter, character)
end)

if Player.Character then
    task.spawn(setupCharacter, Player.Character)
end

local function getCharacterSafe()
    local character = currentCharacter
    local humanoid = currentHumanoid
    local root = currentRoot
    local head = currentHead

    if isDeadOrResetting then return nil end

    if not character or not character.Parent or not humanoid or not humanoid.Parent or humanoid.Health <= 0 or not root or not root.Parent or not head or not head.Parent then
        return nil
    end

    return character, humanoid, root, head, characterGeneration
end

-- =========================================================
-- ĐÃ FIX: KIỂM TRA TRẠNG THÁI WAITING MAP VÀ LOBBY NGHIÊM NGẶT
-- =========================================================

local function isWaitingMap()
    -- Kiểm tra thư mục Map thực sự từ Workspace
    local mapFolder = Workspace:FindFirstChild("Map") or Workspace:FindFirstChild("CurrentMap")
    
    -- Nếu không tồn tại Folder Map hoặc Map không có con -> Đang chờ
    if not mapFolder or #mapFolder:GetChildren() == 0 then
        return true
    end

    -- Nếu Map chỉ là Lobby
    if mapFolder:FindFirstChild("Lobby") or mapFolder.Name:lower():find("lobby") then
        return true
    end

    return false
end

local function findCoinContainer()
    -- Kiểm tra nếu game đang ở trạng thái Waiting Map thì lập tức trả về nil
    if isWaitingMap() then
        return nil
    end

    local container = Workspace:FindFirstChild("CoinContainer", true)
    if container and container.Parent then
        local parentName = container.Parent.Name:lower()
        -- Loại bỏ hoàn toàn nếu Container nằm trong Lobby/Waiting
        if parentName:find("lobby") or parentName:find("waiting") or parentName:find("spawn") then
            return nil
        end
        return container
    end

    return nil
end

local function getClosestCoin(container, root)
    if not container or not container.Parent or not root or not root.Parent then return nil end

    local closestCoin = nil
    local shortestDistance = math.huge

    for _, coin in ipairs(container:GetChildren()) do
        if coin:IsA("BasePart") and (coin.Name == "Coin_Server" or coin.Name:find("Coin")) then
            local dist = (coin.Position - root.Position).Magnitude
            if dist < shortestDistance then
                shortestDistance = dist
                closestCoin = coin
            end
        end
    end

    return closestCoin
end

local function freezeCharacter(humanoid, root)
    if not humanoid or humanoid.Health <= 0 or not root or not root.Parent then return false end
    return pcall(function()
        humanoid.Sit = false
        humanoid.PlatformStand = false
        humanoid.AutoRotate = false
        root.AssemblyLinearVelocity = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero
        root.Anchored = false
    end)
end

local function unfreezeCharacter(humanoid, root)
    if not root or not root.Parent then return end
    pcall(function()
        root.AssemblyLinearVelocity = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero
        root.Anchored = false
        if humanoid and humanoid.Parent then
            humanoid.PlatformStand = false
            humanoid.Sit = false
            humanoid.AutoRotate = true
        end
    end)
end

local activeTween = nil

local function processCoin(coinPart, generation)
    local character, humanoid, root = getCharacterSafe()
    if not character or not root or not coinPart or not coinPart.Parent then return false end

    root.AssemblyLinearVelocity = Vector3.zero
    root.AssemblyAngularVelocity = Vector3.zero

    local distance = (root.Position - coinPart.Position).Magnitude
    local time = math.max(distance / Speed, 0.15)

    if activeTween then pcall(function() activeTween:Cancel() end) end

    activeTween = TweenService:Create(
        root,
        TweenInfo.new(time, Enum.EasingStyle.Linear),
        { CFrame = coinPart.CFrame }
    )

    activeTween:Play()
    activeTween.Completed:Wait()

    root.AssemblyLinearVelocity = Vector3.zero

    local timeout = 0
    while coinPart and coinPart.Parent and timeout < 8 do
        task.wait(0.08)
        timeout = timeout + 1
    end

    return true
end

local function farmRound(container)
    if farmRunning then return end
    if not container or not container.Parent or isWaitingMap() then return end

    local character, humanoid, root, _, generation = getCharacterSafe()
    if not character then return end

    farmRunning = true
    local map = container.Parent
    updateGuiText("PROCESS", map.Name)

    pcall(function()
        if not freezeCharacter(humanoid, root) then return end

        while container and container.Parent and generation == characterGeneration and not isDeadOrResetting and not isWaitingMap() do
            local _, h, r, _, gen = getCharacterSafe()
            if not h or not r or gen ~= generation then break end

            local targetCoin = getClosestCoin(container, r)
            if targetCoin then
                local success = processCoin(targetCoin, generation)
                if not success and (generation ~= characterGeneration or isDeadOrResetting) then
                    break
                end
            else
                task.wait(SCAN_DELAY)
            end
        end
    end)

    unfreezeCharacter(humanoid, root)
    farmRunning = false
    updateGuiText("PROCESS", "Progress WATTING MAP")
end

-- ========================================
-- MAIN LOOP KHÓA CHẶT TELEPORT TRONG LOBBY
-- ========================================

while true do
    if not isDeadOrResetting and getCharacterSafe() then
        -- Chỉ thực hiện quét coin khi chắc chắn game đã thoát khỏi Waiting Map
        if not isWaitingMap() then
            local container = findCoinContainer()
            if container and container.Parent then
                farmRound(container)
                while container and container.Parent and not isWaitingMap() do
                    task.wait(CONTAINER_SCAN_DELAY)
                end
            else
                updateGuiText("PROCESS", "Progress WATTING MAP")
                task.wait(CONTAINER_SCAN_DELAY)
            end
        else
            updateGuiText("PROCESS", "Progress WATTING MAP")
            task.wait(CONTAINER_SCAN_DELAY)
        end
    else
        task.wait(CONTAINER_SCAN_DELAY)
    end
end
