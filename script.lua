
local Workspace = game:GetService("Workspace")
local TeleportService = game:GetService("TeleportService")
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")

local CONFIG_FILE = "BrainrotRarityConfig.json"

local defaultConfig = {
	enabled = true,
	targetRarity = "Secret",
	autoServerHop = true,
	espEnabled = true,
	autoScanOnJoin = true,
}

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

local config = loadConfig()

if not config.enabled then
	print("To enable, set 'enabled' to true in " .. CONFIG_FILE)
	return
end

print("Brainrot Rarity Script is ENABLED - Loading UI...")

local Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()

local TargetRarity = config.targetRarity or "Secret"
local AutoServerHop = config.autoServerHop or true
local ESPEnabled = config.espEnabled or true
local AutoScanOnJoin = config.autoScanOnJoin or true
local highlights = {}
local isScanning = false

local Window = Rayfield:CreateWindow({
	Name = "Maddog & Thunder Hub",
	LoadingTitle = "Maddog & Thunder Hub",
	LoadingSubtitle = "by Thunder",
	ConfigurationSaving = {
		Enabled = false,
		FolderName = nil,
		FileName = nil,
	},
	Discord = {
		Enabled = false,
		Invite = "noinvitelink",
		RememberJoins = true,
	},
	KeySystem = false,
})

local MainTab = Window:CreateTab("Main", 4483362458)

local ConfigSection = MainTab:CreateSection("Configuration")

local EnabledToggle = MainTab:CreateToggle({
	Name = "Script Enabled",
	CurrentValue = config.enabled,
	Flag = "ScriptEnabled",
	Callback = function(Value)
		config.enabled = Value
		saveConfig(config)
		if not Value then
			Rayfield:Notify({
				Title = "Script Disabled",
				Content = "Script will not run on next join",
				Duration = 3,
				Image = 4483362458,
			})
		end
	end,
})

local RaritySection = MainTab:CreateSection("Rarity Settings")

local RarityDropdown = MainTab:CreateDropdown({
	Name = "Target Rarity",
	Options = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythical", "Secret"},
	CurrentOption = { TargetRarity },
	MultipleOptions = false,
	Flag = "TargetRarity",
	Callback = function(Option)
		TargetRarity = Option[1]
		config.targetRarity = TargetRarity
		saveConfig(config)
	end,
})

local AutoHopToggle = MainTab:CreateToggle({
	Name = "Auto Server Hop",
	CurrentValue = AutoServerHop,
	Flag = "AutoServerHop",
	Callback = function(Value)
		AutoServerHop = Value
		config.autoServerHop = Value
		saveConfig(config)
	end,
})

local ESPToggle = MainTab:CreateToggle({
	Name = "Enable ESP",
	CurrentValue = ESPEnabled,
	Flag = "ESPEnabled",
	Callback = function(Value)
		ESPEnabled = Value
		config.espEnabled = Value
		saveConfig(config)
		if not Value then
			clearHighlights()
		end
	end,
})

local AutoScanToggle = MainTab:CreateToggle({
	Name = "Auto Scan on Join",
	CurrentValue = AutoScanOnJoin,
	Flag = "AutoScanOnJoin",
	Callback = function(Value)
		AutoScanOnJoin = Value
		config.autoScanOnJoin = Value
		saveConfig(config)
	end,
})

local ActionsSection = MainTab:CreateSection("Actions")

local ScanButton = MainTab:CreateButton({
	Name = "Scan for Rarities",
	Callback = function()
		if not isScanning then
			scanForRarities()
		end
	end,
})

local ServerHopButton = MainTab:CreateButton({
	Name = "Server Hop Now",
	Callback = function()
		joinDifferentServer()
	end,
})

local ClearESPButton = MainTab:CreateButton({
	Name = "Clear ESP",
	Callback = function()
		clearHighlights()
	end,
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
	local success, result = pcall(function()
		local servers = HttpService:JSONDecode(
			game:HttpGet(
				"https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100"
			)
		)

		for _, server in pairs(servers.data) do
			if server.id ~= game.JobId and server.playing < server.maxPlayers then
				TeleportService:TeleportToPlaceInstance(game.PlaceId, server.id, Players.LocalPlayer)
				return true
			end
		end
		return false
	end)

	if not success or not result then
		TeleportService:Teleport(game.PlaceId, Players.LocalPlayer)
	end

	Rayfield:Notify({
		Title = "Server Hopping",
		Content = "Switching to a different server...",
		Duration = 3,
		Image = 4483362458,
	})
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

	Rayfield:Notify({
		Title = "Scanning",
		Content = "Looking for " .. TargetRarity .. " rarity Brainrots...",
		Duration = 2,
		Image = 4483362458,
	})

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

	local summaryText = "Scan Results:\n"
	if foundAnyRarity then
		for rarityName, count in pairs(raritiesFound) do
			summaryText = summaryText .. rarityName .. ": " .. count .. "\n"
		end
	else
		summaryText = summaryText .. "No Brainrots found"
	end

	if foundTargetRarity then
		Rayfield:Notify({
			Title = "🎉 TARGET FOUND!",
			Content = "Found " .. TargetRarity .. " rarity Brainrots!",
			Duration = 10,
			Image = 4483362458,
		})
	elseif foundAnyRarity then
		Rayfield:Notify({
			Title = "Target Not Found",
			Content = summaryText,
			Duration = 5,
			Image = 4483362458,
		})
		if AutoServerHop then
			wait(2)
			joinDifferentServer()
		end
	else
		Rayfield:Notify({
			Title = "No Brainrots Found",
			Content = "No Brainrots detected in this server",
			Duration = 5,
			Image = 4483362458,
		})
		if AutoServerHop then
			wait(2)
			joinDifferentServer()
		end
	end

	isScanning = false
end

if AutoScanOnJoin then
	wait(3)
	scanForRarities()
end
