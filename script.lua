local Workspace = game:GetService("Workspace")
local TeleportService = game:GetService("TeleportService")
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

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

local TargetRarity = config.targetRarity or "Secret"
local AutoServerHop = config.autoServerHop or true
local ESPEnabled = config.espEnabled or true
local AutoScanOnJoin = config.autoScanOnJoin or true
local highlights = {}
local isScanning = false

local Window = Library:CreateWindow({
	Title = "Maddog & Thunder Hub",
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
		spawn(function()
			for i = 1, 5 do
				if not isScanning then
					scanForRarities()
					wait(0.1)
					if not AutoServerHop then
						break
					end
					joinDifferentServer()
					wait(2)
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
	for _, highlight in pairs(highlights) do
		if highlight and highlight.Parent then
			highlight:Destroy()
		end
	end
	highlights = {}
end

function joinDifferentServer()
	Library:Notify("Server Hopping - Finding new server...", 1)

	spawn(function()
		local success, result = pcall(function()
			local currentServerId = game.JobId

			-- Get multiple pages of servers for better selection
			local allAvailableServers = {}
			for page = 1, 3 do
				local cursor = ""
				if page > 1 then
					cursor = "&cursor=" .. tostring((page - 1) * 100)
				end

				local pageServers = HttpService:JSONDecode(
					game:HttpGet(
						"https://games.roblox.com/v1/games/"
							.. game.PlaceId
							.. "/servers/Public?sortOrder=Desc&limit=100"
							.. cursor
					)
				)

				for _, server in pairs(pageServers.data) do
					if server.id ~= currentServerId and server.playing < server.maxPlayers and server.playing > 3 then
						table.insert(allAvailableServers, server)
					end
				end
			end

			-- Filter out visited servers
			local unvisitedServers = {}
			for _, server in pairs(allAvailableServers) do
				if not visitedServers[server.id] then
					table.insert(unvisitedServers, server)
				end
			end

			local targetServer = nil

			-- Try unvisited servers first
			if #unvisitedServers > 0 then
				targetServer = unvisitedServers[math.random(1, #unvisitedServers)]
				Library:Notify("Joining unvisited server (ID: " .. string.sub(targetServer.id, 1, 8) .. "...)", 2)
			-- If no unvisited servers, clear history and pick any different server
			elseif #allAvailableServers > 0 then
				visitedServers = {}
				saveVisitedServers()
				targetServer = allAvailableServers[math.random(1, #allAvailableServers)]
				Library:Notify(
					"History cleared - Joining server (ID: " .. string.sub(targetServer.id, 1, 8) .. "...)",
					2
				)
			end

			if targetServer then
				-- Add to visited list before teleporting
				visitedServers[targetServer.id] = os.time()
				saveVisitedServers()
				TeleportService:TeleportToPlaceInstance(game.PlaceId, targetServer.id, Players.LocalPlayer)
				return true
			end

			return false
		end)

		if not success or not result then
			Library:Notify("Fallback: Random server teleport", 1)
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
												highlight.FillColor = Color3.fromRGB(255, 255, 0)
												highlight.OutlineColor = Color3.fromRGB(0, 0, 0)
												highlight.Adornee = bikeModel
												highlight.Parent = bikeModel
												table.insert(highlights, highlight)
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
		Library:Notify("🎉 TARGET FOUND! Found " .. TargetRarity .. " rarity Brainrots!", 5)
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
	spawn(function()
		wait(0.5)
		scanForRarities()
	end)
end
