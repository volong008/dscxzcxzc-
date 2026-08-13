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
local SoundService      = game:GetService("SoundService")

local Player = Players.LocalPlayer

-- ========================================
-- AUTO REJOIN SYSTEM
-- ========================================

local isRejoining = false

local function DoRejoin()
    if isRejoining then return end
    isRejoining = true
    task.wait(2)
    print("[AUTO REJOIN] Đang tiến hành vào lại game...")
    if #Players:GetPlayers() <= 1 then
        TeleportService:Teleport(game.PlaceId, Player)
    else
        TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, Player)
    end
end

local function EnableAutoRejoin()
    if not getgenv().Config or not getgenv().Config["Auto Rejoin"] then return end

    GuiService.ErrorMessageChanged:Connect(function()
        print("[AUTO REJOIN] Phát hiện bị Kick/Mất kết nối!")
        DoRejoin()
    end)

    task.spawn(function()
        local robloxPromptGui = CoreGui:WaitForChild("RobloxPromptGui", 10)
        if robloxPromptGui then
            local promptOverlay = robloxPromptGui:WaitForChild("promptOverlay", 10)
            if promptOverlay then
                promptOverlay.ChildAdded:Connect(function(child)
                    if child.Name == "ErrorPrompt" then
                        print("[AUTO REJOIN] Bị hiện thông báo lỗi Kick/Disconnect!")
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
            print("[FPS CAP] Đã giới hạn FPS xuống: " .. tostring(fpsLimit))
        end
    end
end

task.spawn(ApplyFPSCap)

-- ========================================
-- EXTREME FPS BOOST & PURGE SYSTEM
-- ========================================

local function ApplyFPSBoost()
    if not getgenv().Config or not getgenv().Config["FPS BOOST"] then return end

    -- Minimum render quality / mesh detail.
    pcall(function()
        settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
        settings().Rendering.MeshPartDetailLevel = Enum.MeshPartDetailLevel.Level00
    end)

    -- FPS BOOST: disable 3D rendering completely.
    -- The fullscreen dashboard remains visible because it is 2D UI.
    pcall(function()
        RunService:Set3DRenderingEnabled(false)
    end)

    -- FPS BOOST: mute the game's audio pipeline.
    pcall(function()
        SoundService.Volume = 0
        SoundService.AmbientReverb = Enum.ReverbType.NoReverb
    end)

    -- Minimal lighting.
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

    -- Batch purge: avoids creating one coroutine per new map object.
    local purgeQueue = {}
    local purgeQueued = setmetatable({}, {__mode = "k"})
    local queueHead = 1
    local queueTail = 0
    local purgeRunning = false

    local function ExtremePurge(obj)
        if not obj or not obj.Parent then return end

        pcall(function()
            if obj:IsA("Sky") or obj:IsA("Atmosphere") or obj:IsA("Clouds") then
                obj:Destroy()

            elseif obj:IsA("Decal") or obj:IsA("Texture")
                or obj:IsA("SurfaceAppearance") or obj:IsA("ShirtGraphic") then
                obj:Destroy()

            elseif obj:IsA("ParticleEmitter") or obj:IsA("Trail")
                or obj:IsA("Beam") or obj:IsA("Smoke")
                or obj:IsA("Fire") or obj:IsA("Sparkles")
                or obj:IsA("Highlight") or obj:IsA("Explosion")
                or obj:IsA("SunRaysEffect") or obj:IsA("BloomEffect")
                or obj:IsA("BlurEffect") or obj:IsA("ColorCorrectionEffect")
                or obj:IsA("DepthOfFieldEffect") or obj:IsA("PointLight")
                or obj:IsA("SpotLight") or obj:IsA("SurfaceLight")
                or obj:IsA("Sound") then
                obj:Destroy()

            elseif obj:IsA("MeshPart") then
                obj.CastShadow = false
                obj.Material = Enum.Material.SmoothPlastic
                obj.Reflectance = 0
                pcall(function()
                    obj.TextureID = ""
                end)

            elseif obj:IsA("BasePart") then
                obj.CastShadow = false
                obj.Material = Enum.Material.SmoothPlastic
                obj.Reflectance = 0
                local mesh = obj:FindFirstChildOfClass("SpecialMesh")
                if mesh then pcall(function() mesh.TextureId = "" end) end
            end
        end)
    end

    local function QueuePurge(obj)
        if not obj or purgeQueued[obj] then return end
        purgeQueued[obj] = true
        queueTail += 1
        purgeQueue[queueTail] = obj
    end

    for _, obj in ipairs(Workspace:GetDescendants()) do
        QueuePurge(obj)
    end

    Workspace.DescendantAdded:Connect(QueuePurge)
    Lighting.ChildAdded:Connect(function(obj)
        pcall(function() obj:Destroy() end)
    end)

    -- Silence sounds created after the initial purge.
    local function DisableSound(obj)
        if obj and obj:IsA("Sound") then
            pcall(function()
                obj:Stop()
                obj.Volume=0
                obj:Destroy()
            end)
        end
    end

    pcall(function()
        SoundService.DescendantAdded:Connect(DisableSound)
        for _,obj in ipairs(SoundService:GetDescendants()) do
            DisableSound(obj)
        end
    end)

    if not purgeRunning then
        purgeRunning = true
        task.spawn(function()
            while queueHead <= queueTail do
                local processed = 0
                while processed < 200 and queueHead <= queueTail do
                    local obj = purgeQueue[queueHead]
                    purgeQueue[queueHead] = nil
                    queueHead += 1
                    ExtremePurge(obj)
                    processed += 1
                end
                if queueHead > 1000 and queueHead > queueTail / 2 then
                    local newQueue = {}
                    local n = 0
                    for i = queueHead, queueTail do
                        n += 1
                        newQueue[n] = purgeQueue[i]
                    end
                    purgeQueue = newQueue
                    queueHead = 1
                    queueTail = n
                end
                task.wait()
            end
            purgeRunning = false
        end)
    end

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

    local function CleanCharacter(character)
        if not character then return end
        for _, obj in ipairs(character:GetDescendants()) do
            pcall(function()
                if obj:IsA("Accessory") or obj:IsA("Shirt")
                    or obj:IsA("Pants") or obj:IsA("CharacterAppearance")
                    or obj:IsA("BodyColors") then
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

    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= Player then
            if p.Character then CleanCharacter(p.Character) end
            p.CharacterAdded:Connect(function(char)
                task.wait(0.1)
                CleanCharacter(char)
            end)
        end
    end

    pcall(function()
        MaterialService:ClearToDefault()
        for _, obj in ipairs(MaterialService:GetChildren()) do obj:Destroy() end
    end)

    pcall(function()
        local pGui = Player:FindFirstChild("PlayerGui")
        if pGui then
            for _, obj in ipairs(pGui:GetDescendants()) do
                if obj:IsA("UIStroke") or obj:IsA("UIGradient") or obj:IsA("BlurEffect") then
                    obj:Destroy()
                end
            end
            pGui.DescendantAdded:Connect(function(obj)
                if obj:IsA("UIStroke") or obj:IsA("UIGradient") or obj:IsA("BlurEffect") then
                    pcall(function() obj:Destroy() end)
                end
            end)
        end
    end)

    print("[FPS BOOST EXTREME] Batch purge + Performance mesh LOD + effects/shadows disabled.")
end

-- FPS BOOST MUST COMPLETE BEFORE GUI
ApplyFPSBoost()

-- ========================================
-- ADDITIONAL EXTREME FPS OPTIMIZATIONS
-- Giữ nguyên FPS BOOST cũ ở trên.
-- Phần này CHỈ BỔ SUNG các tối ưu mới.
-- ========================================

local ExtraFPS = {
    AudioOff = true,
    Rendering3DOff = true,
    LightingCleanup = true,
    MemoryCleanup = true,
}

-- 1. TẮT 3D RENDERING
-- Không thay thế logic FPS cũ; chỉ bổ sung tùy chọn này.
if ExtraFPS.Rendering3DOff then
    pcall(function()
        RunService:Set3DRenderingEnabled(false)
    end)
end

-- 2. TẮT ÂM THANH TOÀN BỘ
if ExtraFPS.AudioOff then
    pcall(function()
        SoundService.Volume = 0
        SoundService.AmbientReverb = Enum.ReverbType.NoReverb
    end)

    pcall(function()
        for _, v in ipairs(game:GetDescendants()) do
            if v:IsA("Sound") then
                pcall(function()
                    v:Stop()
                    v.Volume = 0
                    v.Playing = false
                end)
            end
        end
    end)

    -- Sound mới được tạo sau này cũng bị tắt.
    pcall(function()
        game.DescendantAdded:Connect(function(v)
            if v:IsA("Sound") then
                pcall(function()
                    v:Stop()
                    v.Volume = 0
                    v.Playing = false
                end)
            end
        end)
    end)
end

-- 3. BỔ SUNG LIGHTING CLEANUP
if ExtraFPS.LightingCleanup then
    pcall(function()
        Lighting.GlobalShadows = false

        for _, v in ipairs(Lighting:GetChildren()) do
            pcall(function()
                v:Destroy()
            end)
        end
    end)
end

-- 4. DỌN LUA MEMORY ĐỊNH KỲ
-- Chỉ bổ sung GC, không đụng logic farm.
if ExtraFPS.MemoryCleanup then
    task.spawn(function()
        while task.wait(60) do
            pcall(function()
                collectgarbage("collect")
            end)
        end
    end)
end

print("🔥 [FPS BOOST ADD-ON] 3D OFF | AUDIO OFF | LIGHTING CLEANUP | GC 60s")


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
    if not self._device_key or self._device_key == "" then
        warn("[FarmSync ERROR] Khong tim thay Device Key trong bo nho!")
        return false
    end

    local endpoint = self._api_url .. "changeaccounttofolder/"
    local bodyData = HttpService:JSONEncode({
        username = self._username,
        from = from,
        to = to,
        change_without_replacement = without_replacement or false,
        data = "",
        final_config_id = nil
    })

    print("--------------------------------------------------")
    warn("[FarmSync Key Found]: " .. tostring(self._device_key))
    print("[FarmSync Request]: User=" .. self._username .. " | From=" .. tostring(from) .. " | To=" .. tostring(to))
    print("--------------------------------------------------")

    local response = request({
        Url     = endpoint,
        Method  = "POST",
        Body    = bodyData,
        Headers = self:GetHeaders()
    })

    if response and response.Body then
        local ok, data = pcall(HttpService.JSONDecode, HttpService, response.Body)
        if ok and type(data) == "table" and not data.error then
            warn("[FarmSync] Doi Folder thanh cong cho Acc: " .. self._username)
            return true
        else
            local err = (type(data) == "table" and data.error) or response.Body
            warn("[FarmSync WARNING] Khong the doi Folder: " .. tostring(err))
        end
    else
        warn("[FarmSync ERROR] Khong ket noi duoc toi Server Cloud!")
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

    warn("\n==================================================")
    warn("⚡ PHAT HIEN DIEU KIEN CHUYEN ACC: " .. tostring(reason))
    warn("==================================================")

    local client = FarmSyncClient.new()
    local success = client:ChangeToFolder(fromFolder, toFolder, withoutReplacement)

    if success then
        warn("[Auto Change] Doi Folder thanh cong! Dang tat Roblox de Manager bat Acc moi...")
        task.wait(1)
        game:Shutdown()
    else
        warn("[Auto Change] Doi Folder that bai hoac het Acc ranh! Giu game tiep tuc cay...")
        isChangingFolder = false
    end
end

-- ========================================
-- HELPER FUNCTIONS (CHECK LEVEL & INVENTORY)
-- ========================================

local function GetPlayerLevel()
    local level = 0
    
    local leaderstats = Player:FindFirstChild("leaderstats")
    if leaderstats then
        local lvlObj = leaderstats:FindFirstChild("Level") or leaderstats:FindFirstChild("LVL") or leaderstats:FindFirstChild("level")
        if lvlObj then
            level = tonumber(lvlObj.Value) or 0
        end
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

-- ========================================
-- ITEM DATA & RARITY CHECKER
-- ========================================

-- Cache ProfileData một lần để tránh require/WaitForChild lặp lại trong các vòng quét.
local ProfileData = nil
local ProfileDataModule = nil

pcall(function()
    ProfileDataModule = ReplicatedStorage
        :WaitForChild("Modules", 3)
        :WaitForChild("ProfileData", 3)

    if ProfileDataModule then
        ProfileData = require(ProfileDataModule)
    end
end)

local function getProfileData()
    -- Do not permanently cache the returned profile table.
    -- The game can replace/refresh the profile state while the script is running.
    if not ProfileDataModule or not ProfileDataModule.Parent then
        ProfileDataModule = ReplicatedStorage:FindFirstChild("Modules")
            and ReplicatedStorage.Modules:FindFirstChild("ProfileData")
    end

    if ProfileDataModule and ProfileDataModule.Parent then
        local ok, data = pcall(require, ProfileDataModule)
        if ok and type(data) == "table" then
            ProfileData = data
            return data
        end
    end

    return ProfileData
end

local ItemData = nil
local RarityCache = {}

pcall(function()
    ItemData = require(
        ReplicatedStorage:WaitForChild("Database")
            :WaitForChild("Sync")
            :WaitForChild("Item")
    )
end)

local function FindRarity(data, target)
    if not target then return nil end

    local cached = RarityCache[target]
    if cached ~= nil then
        return cached == false and nil or cached
    end

    if target == "Icecream" or target == "IcecreamChroma" then
        RarityCache[target] = "Godly"
        return "Godly"
    end

    if type(data) ~= "table" then
        RarityCache[target] = false
        return nil
    end

    local direct = data[target]
    if type(direct) == "table" and direct.Rarity then
        RarityCache[target] = direct.Rarity
        return direct.Rarity
    end

    local found = nil

    local function scan(tbl, depth)
        if found or type(tbl) ~= "table" or depth > 12 then return end

        for _, v in pairs(tbl) do
            if type(v) == "table" then
                if v.Name == target or v.ItemName == target then
                    found = v.Rarity
                    return
                end

                scan(v, depth + 1)
                if found then return end
            end
        end
    end

    scan(data, 0)

    RarityCache[target] = found or false
    return found
end

local function HasGodlyOrIcecream()
    local found = false

    pcall(function()
        local profile = getProfileData()
        if not profile then return end

        for _, category in ipairs({"Weapons", "Pets", "Materials"}) do
            local catData = profile[category]
            local owned = catData and catData.Owned

            if owned then
                for itemName, amount in pairs(owned) do
                    if amount and amount > 0 then
                        if itemName == "Icecream" or itemName == "IcecreamChroma" then
                            found = true
                            return
                        end

                        local rarity = FindRarity(ItemData, itemName)
                        if rarity and string.lower(tostring(rarity)) == "godly" then
                            found = true
                            return
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

local HttpRequest =
    (syn and syn.request)
    or (http and http.request)
    or http_request
    or (Fluxus and Fluxus.request)
    or request

local function sendDiscordWebhook(itemName, rarity)
    local webhookUrl = getgenv().Config["Webhook URL"]
    if not webhookUrl or webhookUrl == "" then return end

    local discordId = getgenv().Config["Discord ID"] or ""
    local pingText = discordId ~= "" and ("<@" .. discordId .. ">") or ""

    local rarityColors = {
        ["Common"] = 10066329,
        ["Uncommon"] = 3381555,
        ["Rare"] = 3368703,
        ["Legendary"] = 16737792,
        ["Godly"] = 16718105,
        ["Ancient"] = 16711680,
        ["Chroma"] = 16711935
    }

    local embedColor = rarityColors[rarity] or 65535

    local payload = {
        ["content"] = pingText,
        ["embeds"] = {{
            ["title"] = "🎉 UNBOXED RARE ITEM!",
            ["description"] = "Bạn vừa mở ra một vật phẩm phẩm cấp cao!",
            ["color"] = embedColor,
            ["fields"] = {
                {
                    ["name"] = "👤 Player",
                    ["value"] = string.format("`%s` (@%s)", Player.DisplayName, Player.Name),
                    ["inline"] = true
                },
                {
                    ["name"] = "🗡️ Item",
                    ["value"] = string.format("`%s`", tostring(itemName)),
                    ["inline"] = true
                },
                {
                    ["name"] = "⭐ Rarity",
                    ["value"] = string.format("**%s**", tostring(rarity)),
                    ["inline"] = true
                }
            },
            ["footer"] = {
                ["text"] = "Cream Services MM2 Auto Farm • " .. os.date("%X")
            },
            ["timestamp"] = DateTime.now():ToIsoDate()
        }}
    }

    if HttpRequest then
        pcall(function()
            HttpRequest({
                Url = webhookUrl,
                Method = "POST",
                Headers = {["Content-Type"] = "application/json"},
                Body = HttpService:JSONEncode(payload)
            })
        end)
    end
end

-- Lắng nghe sự kiện nhận item từ Inventory
local InventoryRemotes = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Inventory")
local ChangeInventoryItem = InventoryRemotes:WaitForChild("ChangeInventoryItem")

ChangeInventoryItem.OnClientEvent:Connect(function(category, item, amount)
    local rarity = FindRarity(ItemData, item) or "Unknown"

    print("========== CRATE / INVENTORY ==========")
    print("Category:", category)
    print("Item:", item)
    print("Amount:", amount)
    print("Rarity:", rarity)

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
        print("🎁 Đủ 120 SummerKey2026! Tiến hành mở Summer2026Box...")

        task.spawn(function()
            local args = {
                "Summer2026Box",
                "MysteryBox",
                "SummerKey2026"
            }

            pcall(function()
                ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Shop"):WaitForChild("OpenCrate"):InvokeServer(unpack(args))
            end)

            task.wait(2)
            isOpeningCrate = false
        end)
    end
end

-- ========================================
-- TRUE FULLSCREEN CONTROL CENTER + TOGGLE ICON
-- ========================================
local getDailyProgress

local GuiElements = {}
local GuiRefs = {}
local startTime = os.clock()
local GUI_UPDATE_INTERVAL = 0.10
local SLOW_UPDATE_INTERVAL = 0.75
local guiLastValues = {}
local guiVisible = false

local TOGGLE_ICON_URL = "https://tr.rbxcdn.com/180DAY-be66902a5abc9378827c1473671627f7/420/420/PantsAccessory/Webp/noFilter"
local TOGGLE_ICON_FILE = "MM2_Cream_Toggle.webp"

local function makeCorner(obj, radius)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, radius or 8)
    c.Parent = obj
    return c
end

local function makeStroke(obj, thickness, transparency)
    local s = Instance.new("UIStroke")
    s.Thickness = thickness or 1
    s.Transparency = transparency or 0.5
    s.Parent = obj
    return s
end

local function getToggleAsset()
    local ok, asset = pcall(function()
        if type(getcustomasset) ~= "function" then return nil end
        if type(isfile) == "function" and not isfile(TOGGLE_ICON_FILE) then
            local httpRequest = (syn and syn.request) or (http and http.request)
                or http_request or (Fluxus and Fluxus.request) or request
            if httpRequest and type(writefile) == "function" then
                local r = httpRequest({Url = TOGGLE_ICON_URL, Method = "GET"})
                if r and r.Body and #r.Body > 0 then writefile(TOGGLE_ICON_FILE, r.Body) end
            end
        end
        if type(isfile) == "function" and isfile(TOGGLE_ICON_FILE) then
            return getcustomasset(TOGGLE_ICON_FILE)
        end
    end)
    return ok and asset or nil
end

local function destroyDashboard()
    if GuiRefs.DragConnection then pcall(function() GuiRefs.DragConnection:Disconnect() end) end
    if GuiRefs.ScreenGui then pcall(function() GuiRefs.ScreenGui:Destroy() end) end
    GuiRefs.ScreenGui = nil
    GuiRefs.DragConnection = nil
    table.clear(GuiElements)
    table.clear(guiLastValues)
end

local function createToggleButton()
    local old = CoreGui:FindFirstChild("MM2ToggleGUI")
    if old then old:Destroy() end

    local sg = Instance.new("ScreenGui")
    sg.Name = "MM2ToggleGUI"
    sg.ResetOnSpawn = false
    sg.IgnoreGuiInset = true
    sg.DisplayOrder = 100000
    sg.Parent = CoreGui

    local b = Instance.new("ImageButton")
    b.Name = "ToggleButton"
    b.AnchorPoint = Vector2.new(1,1)
    b.Size = UDim2.fromOffset(64,64)
    b.Position = UDim2.new(1,-18,1,-18)
    b.BackgroundColor3 = Color3.fromRGB(13,16,22)
    b.BorderSizePixel = 0
    b.AutoButtonColor = false
    b.Parent = sg
    makeCorner(b,18)
    makeStroke(b,2,0.15)

    local asset = getToggleAsset()
    if asset then
        b.Image = asset
        b.ScaleType = Enum.ScaleType.Fit
    else
        b.Image = ""
        b.Text = "🐂"
        b.Font = Enum.Font.GothamBold
        b.TextSize = 28
        b.TextColor3 = Color3.fromRGB(245,247,250)
    end

    b.MouseEnter:Connect(function()
        TweenService:Create(b,TweenInfo.new(0.10,Enum.EasingStyle.Quad),{Size=UDim2.fromOffset(70,70)}):Play()
    end)
    b.MouseLeave:Connect(function()
        TweenService:Create(b,TweenInfo.new(0.10,Enum.EasingStyle.Quad),{Size=UDim2.fromOffset(64,64)}):Play()
    end)
    b.MouseButton1Click:Connect(function()
        if guiVisible then
            guiVisible=false
            destroyDashboard()
        else
            guiVisible=true
            -- ========================================
-- FINAL ORDER: FPS BOOST FIRST -> BLACK 3D -> GUI
-- ========================================
pcall(function()
    RunService:Set3DRenderingEnabled(false)
end)

pcall(function()
    Lighting.GlobalShadows = false
    for _, v in ipairs(Lighting:GetChildren()) do
        pcall(function()
            v:Destroy()
        end)
    end
end)

createUI()
        end
    end)
end

local function addCard(parent,key,title,value,sub,order)
    local card=Instance.new("Frame")
    card.LayoutOrder=order
    card.BackgroundColor3=Color3.fromRGB(16,20,28)
    card.BorderSizePixel=0
    card.Parent=parent
    makeCorner(card,14)
    makeStroke(card,1,0.78)

    local accent=Instance.new("Frame")
    accent.Size=UDim2.new(0,3,0.62,0)
    accent.Position=UDim2.new(0,0,0.19,0)
    accent.BackgroundColor3=Color3.fromRGB(235,185,85)
    accent.BorderSizePixel=0
    accent.Parent=card
    makeCorner(accent,3)

    local l=Instance.new("TextLabel")
    l.Size=UDim2.new(1,-36,0,18)
    l.Position=UDim2.new(0,18,0,14)
    l.BackgroundTransparency=1
    l.Text=title
    l.TextColor3=Color3.fromRGB(119,132,151)
    l.Font=Enum.Font.GothamBold
    l.TextSize=10
    l.TextXAlignment=Enum.TextXAlignment.Left
    l.Parent=card

    local v=Instance.new("TextLabel")
    v.Size=UDim2.new(1,-36,0,34)
    v.Position=UDim2.new(0,18,0,36)
    v.BackgroundTransparency=1
    v.Text=value
    v.TextColor3=Color3.fromRGB(244,246,250)
    v.Font=Enum.Font.GothamSemibold
    v.TextSize=20
    v.TextXAlignment=Enum.TextXAlignment.Left
    v.TextTruncate=Enum.TextTruncate.AtEnd
    v.Parent=card

    local s=Instance.new("TextLabel")
    s.Size=UDim2.new(1,-36,0,14)
    s.Position=UDim2.new(0,18,1,-23)
    s.BackgroundTransparency=1
    s.Text=sub
    s.TextColor3=Color3.fromRGB(65,78,97)
    s.Font=Enum.Font.GothamMedium
    s.TextSize=8
    s.TextXAlignment=Enum.TextXAlignment.Left
    s.Parent=card

    GuiElements[key]=v
end

-- ========================================
-- LIVE DAILY COINS CHECKER
-- Exact same path as the user's working checker:
-- ProfileData -> Summer2026 -> Quests -> DailyCoins -> Progress
-- ========================================
local function checkDailyCoinsLive()
    local ok, profile = pcall(function()
        local modules = ReplicatedStorage:WaitForChild("Modules")
        local module = modules:WaitForChild("ProfileData")
        return require(module)
    end)

    if not ok or type(profile) ~= "table" then
        return nil
    end

    local myQuests = profile["Summer2026"] and profile["Summer2026"].Quests

    if not myQuests then
        return nil
    end

    local dailyQuest = myQuests["DailyCoins"]

    if type(dailyQuest) ~= "table" then
        return nil
    end

    local progress = dailyQuest["Progress"]

    if type(progress) == "number" then
        return math.max(0, math.floor(progress))
    end

    if type(progress) == "string" then
        local n = progress:match("^(%d+)%s*/%s*960$")
        if n then
            return tonumber(n)
        end

        n = tonumber(progress)
        if n then
            return math.max(0, math.floor(n))
        end
    end

    return nil
end

function createUI()
    if not getgenv().Config or not getgenv().Config["Enable Gui"] then return end
    destroyDashboard()

    local sg=Instance.new("ScreenGui")
    sg.Name="MM2AutoFarmGUI"
    sg.ResetOnSpawn=false
    sg.IgnoreGuiInset=true
    sg.DisplayOrder=99999
    sg.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
    sg.Parent=CoreGui
    GuiRefs.ScreenGui=sg

    -- Dashboard phủ 100% màn hình, không còn panel giữa màn hình.
    local root=Instance.new("Frame")
    root.Size=UDim2.fromScale(1,1)
    root.BackgroundColor3=Color3.fromRGB(5,7,11)
    root.BorderSizePixel=0
    root.Parent=sg

    local topLine=Instance.new("Frame")
    topLine.Size=UDim2.new(1,0,0,3)
    topLine.BackgroundColor3=Color3.fromRGB(235,185,85)
    topLine.BorderSizePixel=0
    topLine.Parent=root

    local sidebar=Instance.new("Frame")
    sidebar.Size=UDim2.new(0,235,1,-3)
    sidebar.Position=UDim2.new(0,0,0,3)
    sidebar.BackgroundColor3=Color3.fromRGB(9,12,18)
    sidebar.BorderSizePixel=0
    sidebar.Parent=root

    local divider=Instance.new("Frame")
    divider.Size=UDim2.new(0,1,1,0)
    divider.Position=UDim2.new(1,-1,0,0)
    divider.BackgroundColor3=Color3.fromRGB(28,34,44)
    divider.BorderSizePixel=0
    divider.Parent=sidebar

    local brand=Instance.new("TextLabel")
    brand.Size=UDim2.new(1,-36,0,34)
    brand.Position=UDim2.new(0,24,0,30)
    brand.BackgroundTransparency=1
    brand.Text="CREAM SERVICES"
    brand.TextColor3=Color3.fromRGB(247,248,251)
    brand.Font=Enum.Font.GothamBold
    brand.TextSize=18
    brand.TextXAlignment=Enum.TextXAlignment.Left
    brand.Parent=sidebar

    local sub=Instance.new("TextLabel")
    sub.Size=UDim2.new(1,-36,0,18)
    sub.Position=UDim2.new(0,25,0,60)
    sub.BackgroundTransparency=1
    sub.Text="MM2 AUTO FARM"
    sub.TextColor3=Color3.fromRGB(94,108,128)
    sub.Font=Enum.Font.GothamMedium
    sub.TextSize=9
    sub.TextXAlignment=Enum.TextXAlignment.Left
    sub.Parent=sidebar

    local online=Instance.new("Frame")
    online.Size=UDim2.new(1,-32,0,48)
    online.Position=UDim2.new(0,16,0,110)
    online.BackgroundColor3=Color3.fromRGB(15,21,28)
    online.BorderSizePixel=0
    online.Parent=sidebar
    makeCorner(online,11)

    local dot=Instance.new("Frame")
    dot.Size=UDim2.fromOffset(8,8)
    dot.Position=UDim2.new(0,14,0.5,-4)
    dot.BackgroundColor3=Color3.fromRGB(80,220,145)
    dot.BorderSizePixel=0
    dot.Parent=online
    makeCorner(dot,8)

    local ot=Instance.new("TextLabel")
    ot.Size=UDim2.new(1,-38,1,0)
    ot.Position=UDim2.new(0,32,0,0)
    ot.BackgroundTransparency=1
    ot.Text="SYSTEM ONLINE"
    ot.TextColor3=Color3.fromRGB(190,201,215)
    ot.Font=Enum.Font.GothamBold
    ot.TextSize=10
    ot.TextXAlignment=Enum.TextXAlignment.Left
    ot.Parent=online

    local menu=Instance.new("Frame")
    menu.Size=UDim2.new(1,-32,0,190)
    menu.Position=UDim2.new(0,16,0,178)
    menu.BackgroundTransparency=1
    menu.Parent=sidebar
    local ml=Instance.new("UIListLayout")
    ml.Padding=UDim.new(0,8)
    ml.Parent=menu

    local function menuItem(txt,active)
        local item=Instance.new("Frame")
        item.Size=UDim2.new(1,0,0,38)
        item.BackgroundColor3=active and Color3.fromRGB(23,28,37) or Color3.fromRGB(9,12,18)
        item.BorderSizePixel=0
        item.Parent=menu
        makeCorner(item,9)
        local ind=Instance.new("Frame")
        ind.Size=UDim2.new(0,3,0.55,0)
        ind.Position=UDim2.new(0,0,0.225,0)
        ind.BackgroundColor3=active and Color3.fromRGB(235,185,85) or Color3.fromRGB(9,12,18)
        ind.BorderSizePixel=0
        ind.Parent=item
        makeCorner(ind,3)
        local t=Instance.new("TextLabel")
        t.Size=UDim2.new(1,-26,1,0)
        t.Position=UDim2.new(0,16,0,0)
        t.BackgroundTransparency=1
        t.Text=txt
        t.TextColor3=active and Color3.fromRGB(235,239,246) or Color3.fromRGB(95,108,128)
        t.Font=Enum.Font.GothamBold
        t.TextSize=10
        t.TextXAlignment=Enum.TextXAlignment.Left
        t.Parent=item
    end

    menuItem("OVERVIEW",true)
    menuItem("AUTO FARM",false)
    menuItem("SUMMER 2026",false)
    menuItem("INVENTORY",false)

    local user=Instance.new("TextLabel")
    user.Size=UDim2.new(1,-36,0,30)
    user.Position=UDim2.new(0,24,1,-55)
    user.BackgroundTransparency=1
    user.Text="@"..Player.Name
    user.TextColor3=Color3.fromRGB(89,103,123)
    user.Font=Enum.Font.GothamMedium
    user.TextSize=10
    user.TextXAlignment=Enum.TextXAlignment.Left
    user.Parent=sidebar

    local content=Instance.new("Frame")
    content.Size=UDim2.new(1,-235,1,-3)
    content.Position=UDim2.new(0,235,0,3)
    content.BackgroundTransparency=1
    content.Parent=root

    local title=Instance.new("TextLabel")
    title.Size=UDim2.new(1,-220,0,40)
    title.Position=UDim2.new(0,30,0,30)
    title.BackgroundTransparency=1
    title.Text="FARM CONTROL CENTER"
    title.TextColor3=Color3.fromRGB(245,247,250)
    title.Font=Enum.Font.GothamBold
    title.TextSize=27
    title.TextXAlignment=Enum.TextXAlignment.Left
    title.Parent=content

    local subtitle=Instance.new("TextLabel")
    subtitle.Size=UDim2.new(1,-220,0,22)
    subtitle.Position=UDim2.new(0,31,0,68)
    subtitle.BackgroundTransparency=1
    subtitle.Text="REALTIME STATUS  •  SUMMER 2026  •  AUTO FARM"
    subtitle.TextColor3=Color3.fromRGB(94,108,128)
    subtitle.Font=Enum.Font.GothamMedium
    subtitle.TextSize=9
    subtitle.TextXAlignment=Enum.TextXAlignment.Left
    subtitle.Parent=content

    local hide=Instance.new("TextButton")
    hide.Size=UDim2.fromOffset(132,40)
    hide.Position=UDim2.new(1,-162,0,32)
    hide.BackgroundColor3=Color3.fromRGB(17,22,30)
    hide.BorderSizePixel=0
    hide.AutoButtonColor=false
    hide.Text="🐂  HIDE GUI"
    hide.TextColor3=Color3.fromRGB(194,202,214)
    hide.Font=Enum.Font.GothamBold
    hide.TextSize=9
    hide.Parent=content
    makeCorner(hide,10)
    makeStroke(hide,1,0.72)
    hide.MouseButton1Click:Connect(function()
        guiVisible=false
        destroyDashboard()
    end)

    local line=Instance.new("Frame")
    line.Size=UDim2.new(1,-60,0,1)
    line.Position=UDim2.new(0,30,0,110)
    line.BackgroundColor3=Color3.fromRGB(28,34,44)
    line.BorderSizePixel=0
    line.Parent=content

    local gridHolder=Instance.new("Frame")
    gridHolder.Size=UDim2.new(1,-60,1,-165)
    gridHolder.Position=UDim2.new(0,30,0,135)
    gridHolder.BackgroundTransparency=1
    gridHolder.Parent=content

    local grid=Instance.new("UIGridLayout")
    grid.CellSize=UDim2.new(0.5,-10,0,118)
    grid.CellPadding=UDim2.new(0,18,0,18)
    grid.SortOrder=Enum.SortOrder.LayoutOrder
    grid.Parent=gridHolder

    local initialProfile=getProfileData()
    local initialDaily=checkDailyCoinsLive()
    local initialKeys=nil

    if type(initialProfile)=="table"
        and type(initialProfile.Materials)=="table"
        and type(initialProfile.Materials.Owned)=="table" then
        initialKeys=tonumber(initialProfile.Materials.Owned["SummerKey2026"])
    end

    addCard(gridHolder,"PROCESS","PROCESS","Progress WATTING MAP","CURRENT MAP / FARM STATE",1)
    addCard(gridHolder,"DAILY PROGRESS","DAILY PROGRESS",
        initialDaily and string.format("%d / 960",initialDaily) or "-- / 960",
        "SUMMER 2026 QUEST",2)
    addCard(gridHolder,"CURRENT SUMMER COIN","SUMMER KEY",
        initialKeys and tostring(math.max(0,math.floor(initialKeys))) or "--",
        "AUTO CRATE AT 120",3)
    addCard(gridHolder,"SESSION NORMAIL COIN","SESSION COINS","+0","CURRENT SESSION",4)
    addCard(gridHolder,"ROUND NORMAIL COIN","ROUND COINS","0 / 0","CURRENT ROUND",5)
    addCard(gridHolder,"SESSION TIME","SESSION TIME","00:00:00","SCRIPT RUNTIME",6)
    addCard(gridHolder,"HAVE GODLY","GODLY STATUS","NO","GODLY / ICECREAM / CHROMA",7)

    local footer=Instance.new("TextLabel")
    footer.Size=UDim2.new(1,-60,0,18)
    footer.Position=UDim2.new(0,30,1,-28)
    footer.BackgroundTransparency=1
    footer.Text="LIVE • 100ms CHECK • CLICK THE CREAM ICON TO SHOW / HIDE"
    footer.TextColor3=Color3.fromRGB(60,73,92)
    footer.Font=Enum.Font.GothamMedium
    footer.TextSize=8
    footer.TextXAlignment=Enum.TextXAlignment.Right
    footer.Parent=content

    GuiRefs.Panel=root
    guiVisible=true
end

local function updateGuiText(key,value)
    local label=GuiElements[key]
    if not label or not label.Parent then return end
    local text=tostring(value)
    if guiLastValues[key]==text then return end
    guiLastValues[key]=text
    label.Text=text
end

local function normalizeProgressValue(value)
    if type(value) == "number" then
        return math.max(0, math.floor(value))
    end

    if type(value) == "string" then
        local n = value:match("(%d+)%s*/%s*960")
        if n then return tonumber(n) or 0 end

        n = tonumber(value)
        if n then return math.max(0, math.floor(n)) end
    end

    return nil
end

getDailyProgress = function(_profile)
    return checkDailyCoinsLive()
end

if getgenv().Config and getgenv().Config["Enable Gui"] then
    createToggleButton()
    createUI()
end

-- ========================================
-- REALTIME GUI / EVENT STATS
-- ========================================
task.spawn(function()
    local lastGodlyCheck=0
    local cachedGodly=false
    local lastDaily=nil
    local lastKeys=nil
    local lastProcess=nil

    while true do
        task.wait(GUI_UPDATE_INTERVAL)

        -- Read profile independently of the farm loop.
        local now=os.clock()
        local profile=getProfileData()

        -- DAILY PROGRESS: continuously run the same checker logic as the
        -- user's standalone script. Only update the GUI when Progress changes.
        local liveDailyProgress=checkDailyCoinsLive()

        if liveDailyProgress ~= nil then
            if lastDaily ~= liveDailyProgress then
                lastDaily=liveDailyProgress
                updateGuiText(
                    "DAILY PROGRESS",
                    string.format("%d / 960", liveDailyProgress)
                )
            end
        elseif lastDaily ~= nil then
            -- ProfileData can temporarily be unavailable while the game
            -- refreshes it. Keep the last valid GUI value instead of 0.
            updateGuiText(
                "DAILY PROGRESS",
                string.format("%d / 960", lastDaily)
            )
        end

        -- SUMMER KEY: live inventory value.
        local keysCount=nil
        if type(profile)=="table"
            and type(profile.Materials)=="table"
            and type(profile.Materials.Owned)=="table" then

            local rawKeys=profile.Materials.Owned["SummerKey2026"]
            local n=tonumber(rawKeys)
            if n ~= nil then
                keysCount=math.max(0,math.floor(n))
            end
        end

        if keysCount ~= nil then
            if lastKeys == nil or keysCount ~= lastKeys then
                lastKeys=keysCount
                updateGuiText("CURRENT SUMMER COIN",tostring(keysCount))
                checkAndOpenCrate(keysCount)
            end
        elseif lastKeys ~= nil then
            updateGuiText("CURRENT SUMMER COIN",tostring(lastKeys))
        end

        -- PROCESS / MAP: update independently so the card never gets stuck
        -- on the value from the moment the GUI was created.
        local processText=nil
        local activeContainer=Workspace:FindFirstChild("CoinContainer",true)
        if activeContainer and activeContainer.Parent then
            local map=activeContainer.Parent
            if map and map.Name then
                processText=tostring(map.Name)
            end
        end

        if not processText or processText=="" then
            if farmRunning then
                processText="FARMING..."
            else
                processText="Progress WATTING MAP"
            end
        end

        if processText ~= lastProcess then
            lastProcess=processText
            updateGuiText("PROCESS",processText)
        end

        if now-lastGodlyCheck>=SLOW_UPDATE_INTERVAL then
            lastGodlyCheck=now
            cachedGodly=HasGodlyOrIcecream()
            updateGuiText("HAVE GODLY",cachedGodly and "YES" or "NO")
        end

        local elapsed=math.floor(now-startTime)
        local h=math.floor(elapsed/3600)
        local m=math.floor((elapsed%3600)/60)
        local s=elapsed%60
        updateGuiText("SESSION TIME",string.format("%02d:%02d:%02d",h,m,s))

        local farmSyncCfg=getgenv().Config["Auto Change"]
            and getgenv().Config["Auto Change"]["Farm Sync"]

        if farmSyncCfg and farmSyncCfg["Enable"] and not isChangingFolder then
            if lastDaily ~= nil and lastDaily>=960 and lastKeys ~= nil and lastKeys<120 then
                local questCfg=farmSyncCfg["Daily Quest"]
                if questCfg and questCfg["Folder From"] and questCfg["Folder To"] then
                    TriggerAutoChange(
                        questCfg["Folder From"],
                        questCfg["Folder To"],
                        "Hoàn thành Daily Quest (960/960) & SummerKey2026 ("..tostring(lastKeys).." < 120)"
                    )
                end
            end

            local currentLvl=GetPlayerLevel()
            if currentLvl>=10 and cachedGodly then
                local godlyCfg=farmSyncCfg["Godly And Level 10"]
                if godlyCfg and godlyCfg["Folder From"] and godlyCfg["Folder To"] then
                    TriggerAutoChange(
                        godlyCfg["Folder From"],
                        godlyCfg["Folder To"],
                        "Đạt Level 10 ("..tostring(currentLvl)..") và sở hữu Weapon Godly/Icecream/IcecreamChroma"
                    )
                end
            end
        end
    end
end)

-- ========================================
-- FARMING & MOVEMENT CORE LOGIC
-- ========================================
local SCAN_DELAY = 0.08
local CONTAINER_SCAN_DELAY = 0.20
local Speed = 200
local RESPAWN_SETTLE_TIME = 0.35

local currentCharacter = nil
local currentHumanoid = nil
local currentRoot = nil
local currentHead = nil

local characterGeneration = 0
local isDeadOrResetting = false
local farmRunning = false

local lastKeys = 0
local lastCoins = 0
local isFirstCheck = true

local function checkEventStats()
    local profile = getProfileData()
    if not profile or not profile.Materials or not profile.Materials.Owned then return end

    local keysCount = tonumber(profile.Materials.Owned["SummerKey2026"]) or 0
    local coinsCount = tonumber(profile.Materials.Owned["Coins"]) or 0

    if isFirstCheck then
        print("\n======== THỐNG KÊ BAN ĐẦU ========")
        print(string.format("🔑 SummerKey2026 : %d", keysCount))
        print(string.format("🪙 Coins          : %d", coinsCount))
        print("==================================")
        isFirstCheck = false
    else
        local earnedKeys = keysCount - lastKeys
        local earnedCoins = coinsCount - lastCoins

        print("\n======== TỔNG KẾT ROUND ========")
        print(string.format("🔑 SummerKey2026 : %d (+%d ván này)", keysCount, earnedKeys))
        print(string.format("🪙 Coins          : %d (+%d ván này)", coinsCount, earnedCoins))
        print("==================================")
    end

    lastKeys = keysCount
    lastCoins = coinsCount
    checkAndOpenCrate(keysCount)
end

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

local cachedCoinContainer = nil

local function findCoinContainer()
    if cachedCoinContainer and cachedCoinContainer.Parent then
        return cachedCoinContainer
    end

    cachedCoinContainer = Workspace:FindFirstChild("CoinContainer", true)
    return cachedCoinContainer
end

Workspace.DescendantRemoving:Connect(function(obj)
    if obj == cachedCoinContainer then
        cachedCoinContainer = nil
    end
end)

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

local function processCoin(coinPart, generation)
    local character, humanoid, root = getCharacterSafe()
    if not character or not root or not coinPart or not coinPart.Parent then return false end

    root.AssemblyLinearVelocity = Vector3.zero
    root.AssemblyAngularVelocity = Vector3.zero

    local distance = (root.Position - coinPart.Position).Magnitude
    local time = math.max(distance / Speed, 0.2)

    local tween = TweenService:Create(
        root,
        TweenInfo.new(time, Enum.EasingStyle.Linear),
        { CFrame = coinPart.CFrame }
    )

    tween:Play()
    tween.Completed:Wait()

    root.AssemblyLinearVelocity = Vector3.zero
    task.wait(0.1)

    local timeout = 0
    while coinPart and coinPart.Parent and timeout < 10 do
        task.wait(0.1)
        timeout = timeout + 1
    end

    return true
end

local function farmRound(container)
    if farmRunning then return end
    if not container or not container.Parent then return end

    local character, humanoid, root, _, generation = getCharacterSafe()
    if not character then return end

    farmRunning = true
    local map = container.Parent
    updateGuiText("PROCESS", map.Name)

    print("\n==============================")
    print("ROUND MỚI | MAP:", map.Name)
    print("==============================")

    local ok, err = xpcall(function()
        if not freezeCharacter(humanoid, root) then return end

        while container and container.Parent and generation == characterGeneration and not isDeadOrResetting do
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
    end, debug.traceback)

    unfreezeCharacter(humanoid, root)
    farmRunning = false

    if not ok then warn("❌ farmRound lỗi:\n" .. tostring(err)) end
    if generation == characterGeneration and not isDeadOrResetting then checkEventStats() end

    -- PROCESS is maintained by the realtime GUI loop
end

-- ========================================
-- MAIN LOOP
-- ========================================
print("\n==============================")
print("MM2 AUTO FLY COIN SAFE STARTED")
print("==============================")

task.spawn(function()
    task.wait(1)
    pcall(checkEventStats)
end)

local initialContainer = findCoinContainer()
if initialContainer then
    while initialContainer and initialContainer.Parent do
        task.wait(CONTAINER_SCAN_DELAY)
    end
end

while true do
    if not isDeadOrResetting and getCharacterSafe() then
        local container = findCoinContainer()
        if container and container.Parent then
            farmRound(container)
            while container and container.Parent do
                task.wait(CONTAINER_SCAN_DELAY)
            end
        else
            -- PROCESS is maintained by the realtime GUI loop
            task.wait(CONTAINER_SCAN_DELAY)
        end
    else
        task.wait(CONTAINER_SCAN_DELAY)
    end
end


-- ========================================
-- FINAL FPS BOOST REINFORCEMENT
-- Giữ toàn bộ FPS BOOST cũ + ép các tùy chọn bổ sung chạy sau cùng.
-- ========================================

pcall(function()
    RunService:Set3DRenderingEnabled(false)
end)

pcall(function()
    Lighting.GlobalShadows = false
    for _, v in ipairs(Lighting:GetChildren()) do
        pcall(function()
            v:Destroy()
        end)
    end
end)

pcall(function()
    SoundService.Volume = 0
    SoundService.AmbientReverb = Enum.ReverbType.NoReverb

    for _, v in ipairs(game:GetDescendants()) do
        if v:IsA("Sound") then
            v:Stop()
            v.Volume = 0
            v.Playing = false
        end
    end
end)

task.spawn(function()
    while task.wait(60) do
        pcall(function()
            collectgarbage("collect")
        end)
    end
end)

