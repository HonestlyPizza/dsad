local Workspace = game:GetService("Workspace")
local TeleportService = game:GetService("TeleportService")
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

local spawnNow = (task and task.spawn) or function(fn)
	return spawn(fn)
end
local sleep = (task and task.wait) or function(t)
	return wait(t)
end

local CONFIG_FILE = "BROTConfig.json"
local VISITED_SERVERS_FILE = "VisitedServers.json"

local defaultConfig = {
	enabled = true,
	targetRarity = "Secret",
	autoServerHop = false,
	espEnabled = true,
	autoScanOnJoin = true,
}

local visitedServers = {}

local function loadVisitedServers()
	local success, result = pcall(function()
		if readfile and isfile and isfile(VISITED_SERVERS_FILE) then
			return HttpService:JSONDecode(readfile(VISITED_SERVERS_FILE))
		end
		return {}
	end)
	return success and result or {}
end

local function saveVisitedServers()
	pcall(function()
		if writefile then
			writefile(VISITED_SERVERS_FILE, HttpService:JSONEncode(visitedServers))
		end
	end)
end

local function addCurrentServer()
	local currentServerId = game.JobId
	if currentServerId and currentServerId ~= "" then
		visitedServers[currentServerId] = os.time()
		local count = 0
		for _ in pairs(visitedServers) do
			count = count + 1
		end
		if count > 50 then
			local serverList = {}
			for serverId, timestamp in pairs(visitedServers) do
				table.insert(serverList, { id = serverId, time = timestamp })
			end
			table.sort(serverList, function(a, b)
				return a.time < b.time
			end)
			visitedServers = {}
			for i = math.max(1, #serverList - 25), #serverList do
				visitedServers[serverList[i].id] = serverList[i].time
			end
		end
		saveVisitedServers()
	end
end

local function loadConfig()
	local success, result = pcall(function()
		if readfile and isfile and isfile(CONFIG_FILE) then
			local configData = HttpService:JSONDecode(readfile(CONFIG_FILE))
			return configData
		end
		return defaultConfig
	end)

	if success and result then
		return result
	else
		return defaultConfig
	end
end

local function saveConfig(config)
	pcall(function()
		if writefile then
			writefile(CONFIG_FILE, HttpService:JSONEncode(config))
		end
	end)
end

visitedServers = loadVisitedServers()
addCurrentServer()

local config = loadConfig()

if not config.enabled then
	print("Brainrot Rarity Script is DISABLED via config file.")
	print("To enable, set 'enabled' to true in " .. CONFIG_FILE)
	return
end

print("Brainrot Rarity Script is ENABLED - Loading LinoriaLib UI...")

local repo = "https://raw.githubusercontent.com/violin-suzutsuki/LinoriaLib/main/"

local libraryLoad = game:HttpGetAsync(repo .. "Library.lua")
local themeLoad = game:HttpGetAsync(repo .. "addons/ThemeManager.lua")
local saveLoad = game:HttpGetAsync(repo .. "addons/SaveManager.lua")

local Library = loadstring(libraryLoad)()
local ThemeManager = loadstring(themeLoad)()
local SaveManager = loadstring(saveLoad)()

local TargetRarity = config.targetRarity or defaultConfig.targetRarity
local AutoServerHop = (config.autoServerHop ~= nil) and config.autoServerHop or defaultConfig.autoServerHop
local ESPEnabled = (config.espEnabled ~= nil) and config.espEnabled or defaultConfig.espEnabled
local AutoScanOnJoin = (config.autoScanOnJoin ~= nil) and config.autoScanOnJoin or defaultConfig.autoScanOnJoin
local highlights = {}
local isScanning = false

local Window = Library:CreateWindow({
	Title = "Madden WOOD & Thunder Hub",
	Center = true,
	AutoShow = true,
	TabPadding = 8,
	MenuFadeTime = 0.2,
})

local Tabs = {
	Main = Window:AddTab("Main"),
	Settings = Window:AddTab("Settings"),
}

local LeftGroupBox = Tabs.Main:AddLeftGroupbox("Configuration")

LeftGroupBox:AddToggle("ScriptEnabled", {
	Text = "Script Enabled",
	Default = config.enabled,
	Tooltip = "Enable/disable the script functionality",
	Callback = function(Value)
		config.enabled = Value
		saveConfig(config)
		if not Value then
			Library:Notify("Script Disabled - Will not run on next join", 3)
		end
	end,
})

LeftGroupBox:AddDropdown("TargetRarity", {
	Values = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythical", "Secret" },
	Default = TargetRarity,
	Multi = false,
	Text = "Target Rarity",
	Tooltip = "Select the rarity to hunt for",
	Callback = function(Value)
		TargetRarity = Value
		config.targetRarity = TargetRarity
		saveConfig(config)
	end,
})

LeftGroupBox:AddToggle("AutoServerHop", {
	Text = "Auto Server Hop",
	Default = AutoServerHop,
	Tooltip = "Automatically switch servers when target rarity not found",
	Callback = function(Value)
		AutoServerHop = Value
		config.autoServerHop = Value
		saveConfig(config)
	end,
})

LeftGroupBox:AddToggle("ESPEnabled", {
	Text = "Enable ESP",
	Default = ESPEnabled,
	Tooltip = "Highlight target rarity brainrots",
	Callback = function(Value)
		ESPEnabled = Value
		config.espEnabled = Value
		saveConfig(config)
		if not Value then
			clearHighlights()
		end
	end,
})

LeftGroupBox:AddToggle("AutoScanOnJoin", {
	Text = "Auto Scan on Join",
	Default = AutoScanOnJoin,
	Tooltip = "Automatically scan for rarities when joining a server",
	Callback = function(Value)
		AutoScanOnJoin = Value
		config.autoScanOnJoin = Value
		saveConfig(config)
	end,
})

local RightGroupBox = Tabs.Main:AddRightGroupbox("Actions")

RightGroupBox:AddButton({
	Text = "Instant Scan",
	Func = function()
		if not isScanning then
			scanForRarities()
		else
			Library:Notify("Already scanning! Please wait...", 1)
		end
	end,
	DoubleClick = false,
	Tooltip = "Instantly scan current server for target rarity",
})

RightGroupBox:AddButton({
	Text = "Force Different Server",
	Func = function()
		Library:Notify("Forcing server hop with history check...", 1)
		local currentServerId = game.JobId
		local visitedCount = 0
		for _ in pairs(visitedServers) do
			visitedCount = visitedCount + 1
		end
		Library:Notify("Current: " .. string.sub(currentServerId, 1, 8) .. " | Visited: " .. tostring(visitedCount), 2)
		joinDifferentServer()
	end,
	DoubleClick = false,
	Tooltip = "Force join a different server with debug info",
})

RightGroupBox:AddButton({
	Text = "Speed Hop Mode",
	Func = function()
		Library:Notify("Speed hopping through servers...", 1)
		spawnNow(function()
			for i = 1, 5 do
				if not isScanning then
					scanForRarities()
					sleep(0.1)
					if not AutoServerHop then
						break
					end
					joinDifferentServer()
					sleep(2)
				else
					break
				end
			end
		end)
	end,
	DoubleClick = false,
	Tooltip = "Rapidly scan multiple servers",
})

RightGroupBox:AddButton({
	Text = "Clear ESP",
	Func = function()
		clearHighlights()
		Library:Notify("ESP Cleared!", 1)
	end,
	DoubleClick = false,
	Tooltip = "Remove all ESP highlights",
})

RightGroupBox:AddButton({
	Text = "Clear Server History",
	Func = function()
		visitedServers = {}
		saveVisitedServers()
		local currentServerId = game.JobId
		if currentServerId and currentServerId ~= "" then
			visitedServers[currentServerId] = os.time()
			saveVisitedServers()
		end
		Library:Notify("Server history cleared! Current server re-added.", 2)
	end,
	DoubleClick = false,
	Tooltip = "Clear visited servers list (keeps current server)",
})

local InfoGroupBox = Tabs.Main:AddRightGroupbox("Information")

InfoGroupBox:AddLabel("Secret Finder")

local SettingsGroupBox = Tabs.Settings:AddLeftGroupbox("UI Settings")

SettingsGroupBox:AddLabel("UI Theme"):AddColorPicker("MenuColor", {
	Default = Color3.new(0, 1, 0),
	Title = "Menu Color",
	Transparency = 0,
	Callback = function(Value) end,
})

SettingsGroupBox:AddToggle("KeybindMenuOpen", {
	Default = false,
	Text = "Open Keybind Menu",
	Callback = function(Value)
		Library.KeybindFrame.Visible = Value
	end,
})

SettingsGroupBox:AddButton({
	Text = "Unload Script",
	Func = function()
		Library:Unload()
	end,
	DoubleClick = true,
	Tooltip = "Double-click to unload the script",
})

function clearHighlights()
	for _, item in pairs(highlights) do
		if item then
			if typeof(item) == "Instance" and item.ClassName == "Tween" then
				item:Cancel()
				item:Destroy()
			elseif typeof(item) == "Instance" and item.Parent then
				item:Destroy()
			elseif item.Destroy then
				item:Destroy()
			end
		end
	end
	highlights = {}
end

function joinDifferentServer()
	Library:Notify("Server Hopping - Finding new server...", 1)

	spawnNow(function()
		local success, result = pcall(function()
			local currentServerId = game.JobId
			local attempts = 0
			local maxAttempts = 10

			
			while attempts < maxAttempts do
				attempts = attempts + 1

				local serverLists = {
					"https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100",
					"https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Desc&limit=100",
					"https://games.roblox.com/v1/games/"
						.. game.PlaceId
						.. "/servers/Public?sortOrder=Random&limit=100",
				}

				local allServers = {}

				for _, url in ipairs(serverLists) do
					local ok, response = pcall(function()
						return HttpService:JSONDecode(game:HttpGet(url))
					end)

					if ok and response and response.data then
						for _, server in ipairs(response.data) do
							
							if server.id and server.id ~= currentServerId and server.playing < server.maxPlayers then
								local exists = false
								for _, existing in ipairs(allServers) do
									if existing.id == server.id then
										exists = true
										break
									end
								end
								if not exists then
									table.insert(allServers, server)
								end
							end
						end
					end
					sleep(0.1)
				end

				local filteredServers = {}
				for _, server in ipairs(allServers) do
					if server.id ~= currentServerId then
						table.insert(filteredServers, server)
					end
				end
				allServers = filteredServers

				if #allServers == 0 then
					Library:Notify("No different servers found, attempt " .. attempts .. "/" .. maxAttempts, 1)
					if attempts >= maxAttempts then
						Library:Notify("Using fallback teleport method...", 1)
						TeleportService:Teleport(game.PlaceId, Players.LocalPlayer)
						return true
					end
					sleep(1) 
				else
					local unvisitedServers = {}
					local visitedServers_available = {}

					for _, server in ipairs(allServers) do
						if not visitedServers[server.id] then
							table.insert(unvisitedServers, server)
						else
							table.insert(visitedServers_available, server)
						end
					end

					local targetServer = nil
					if #unvisitedServers > 0 then
						table.sort(unvisitedServers, function(a, b)
							return (a.playing or 0) < (b.playing or 0)
						end)
						targetServer = unvisitedServers[1]
						Library:Notify("Joining unvisited server (ID: " .. string.sub(targetServer.id, 1, 8) .. ")", 2)
					elseif #visitedServers_available > 0 then
						local filteredVisited = {}
						for _, server in ipairs(visitedServers_available) do
							if server.id ~= currentServerId then
								table.insert(filteredVisited, server)
							end
						end
						if #filteredVisited > 0 then
							targetServer = filteredVisited[math.random(1, #filteredVisited)]
							Library:Notify(
								"Rejoining different server (ID: " .. string.sub(targetServer.id, 1, 8) .. ")",
								2
							)
						end
					end

					if targetServer and targetServer.id ~= currentServerId then

						visitedServers[targetServer.id] = os.time()
						saveVisitedServers()

						if targetServer.id == currentServerId then
							Library:Notify("Safety check failed - server ID matches current, retrying...", 1)
						else
							Library:Notify(
								"Teleporting to confirmed different server: " .. string.sub(targetServer.id, 1, 8),
								2
							)
							TeleportService:TeleportToPlaceInstance(game.PlaceId, targetServer.id, Players.LocalPlayer)

							sleep(2)
							if game.JobId == currentServerId then
								Library:Notify("Still in same server, retrying...", 1)
							else
								return true 
							end
						end
					end
				end
			end

			
			Library:Notify("All attempts failed, using fallback teleport", 1)
			return false
		end)

		if not success or not result then
			Library:Notify("Retrying with basic teleport...", 1)
			TeleportService:Teleport(game.PlaceId, Players.LocalPlayer)
		end
	end)
end

function scanForRarities()
	if isScanning then
		return
	end
	isScanning = true

	local plots = Workspace.Plots:GetChildren()
	local foundAnyRarity = false
	local foundTargetRarity = false
	local raritiesFound = {}

	clearHighlights()

	Library:Notify("Fast scanning for " .. TargetRarity .. " rarity...", 1)

	for _, plot in ipairs(plots) do
		local animalPodiums = plot:FindFirstChild("AnimalPodiums")
		if animalPodiums then
			local slots = animalPodiums:GetChildren()
			for _, slot in ipairs(slots) do
				local base = slot:FindFirstChild("Base")
				if base then
					local spawn = base:FindFirstChild("Spawn")
					if spawn then
						local attachment = spawn:FindFirstChild("Attachment")
						if attachment then
							local animalOverhead = attachment:FindFirstChild("AnimalOverhead")
							if animalOverhead then
								local rarity = animalOverhead:FindFirstChild("Rarity")
								local stolen = animalOverhead:FindFirstChild("Stolen")

								if stolen and stolen:IsA("TextLabel") and stolen.Text == "IN MACHINE" then
								else
									if rarity and rarity:IsA("TextLabel") then
										foundAnyRarity = true
										local rarityText = rarity.Text

										if not raritiesFound[rarityText] then
											raritiesFound[rarityText] = 0
										end
										raritiesFound[rarityText] = raritiesFound[rarityText] + 1

										if rarityText == TargetRarity then
											foundTargetRarity = true

											if ESPEnabled then
												local bikeModel = slot
												if bikeModel and bikeModel:IsA("Model") then
													local highlight = Instance.new("Highlight")
													highlight.Name = "RarityESP"
													highlight.FillColor = Color3.fromRGB(0, 255, 0)
													highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
													highlight.FillTransparency = 0.3
													highlight.OutlineTransparency = 0
													highlight.Adornee = bikeModel
													highlight.Parent = bikeModel
													table.insert(highlights, highlight)

													local billboardGui = Instance.new("BillboardGui")
													billboardGui.Name = "RarityESPText"
													billboardGui.Size = UDim2.new(0, 200, 0, 100)
													billboardGui.StudsOffset = Vector3.new(0, 5, 0)
													billboardGui.Adornee = bikeModel
													billboardGui.Parent = bikeModel

													local textLabel = Instance.new("TextLabel")
													textLabel.Size = UDim2.new(1, 0, 1, 0)
													textLabel.BackgroundTransparency = 0.2
													textLabel.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
													textLabel.BorderSizePixel = 0
													textLabel.Text = rarityText .. " FOUND!"
													textLabel.TextColor3 = Color3.fromRGB(255, 255, 0)
													textLabel.TextScaled = true
													textLabel.TextStrokeTransparency = 0
													textLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
													textLabel.Font = Enum.Font.GothamBold
													textLabel.Parent = billboardGui

													local tween = game:GetService("TweenService"):Create(
														textLabel,
														TweenInfo.new(
															0.8,
															Enum.EasingStyle.Sine,
															Enum.EasingDirection.InOut,
															-1,
															true
														),
														{ TextTransparency = 0.3 }
													)
													tween:Play()

													table.insert(highlights, billboardGui)
													table.insert(highlights, tween)
												end
											end
										end
									end
								end
							end
						end
					end
				end
			end
		end
	end

	local summaryText = "Results: "
	if foundAnyRarity then
		for rarityName, count in pairs(raritiesFound) do
			summaryText = summaryText .. rarityName .. "(" .. count .. ") "
		end
	else
		summaryText = summaryText .. "No Brainrots found"
	end

	if foundTargetRarity then
		Library:Notify("TARGET FOUND! Found " .. TargetRarity .. " rarity Brainrots!", 5)
		loadstring(game:HttpGet("https://raw.githubusercontent.com/tienkhanh1/spicy/main/Chilli.lua"))()
	elseif foundAnyRarity then
		Library:Notify("Target not found - " .. summaryText, 2)
		if AutoServerHop then
			joinDifferentServer()
		end
	else
		Library:Notify("No Brainrots found - Hopping servers...", 2)
		if AutoServerHop then
			joinDifferentServer()
		end
	end

	isScanning = false
end

ThemeManager:SetLibrary(Library)
SaveManager:SetLibrary(Library)

ThemeManager:SetFolder("LinoriaLibSettings")
ThemeManager:ApplyToTab(Tabs.Settings)

SaveManager:SetFolder("LinoriaLibSettings/BrainrotRarity")

SaveManager:BuildConfigSection(Tabs.Settings)

SaveManager:SetIgnoreIndexes({})

SaveManager:LoadAutoloadConfig()

if AutoScanOnJoin then
	spawnNow(function()
		sleep(0.5)
		scanForRarities()
	end)
end
