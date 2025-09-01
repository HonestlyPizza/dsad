local Workspace = game:GetService("Workspace")
local TeleportService = game:GetService("TeleportService")
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")

local function joinserver()
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
end
local plots = Workspace.Plots:GetChildren()

local TargetRarity = "Secret"
local foundAnyRarity = false
local foundTargetRarity = false

for _, plot in ipairs(plots) do
	print("Plot: " .. plot.Name)

	local animalPodiums = plot:FindFirstChild("AnimalPodiums")
	if animalPodiums then
		local slots = animalPodiums:GetChildren()
		for _, slot in ipairs(slots) do
			print("  Slot: " .. slot.Name)

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
								print("    Found rarity: " .. rarity.Text)

								if rarity.Text == TargetRarity then
									foundTargetRarity = true
									print("    Target rarity found: " .. rarity.Text)

									local bikeModel = slot
									if bikeModel and bikeModel:IsA("Model") then
										local highlight = Instance.new("Highlight")

										highlight.Name = "RarityESP"
										highlight.FillColor = Color3.fromRGB(255, 255, 0)
										highlight.OutlineColor = Color3.fromRGB(0, 0, 0)
										highlight.Adornee = bikeModel

										highlight.Parent = bikeModel
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

if foundTargetRarity then
	print("Target rarity (" .. TargetRarity .. ") found! Not teleporting.")
elseif foundAnyRarity then
	wait(0.2)
	joinserver()
else
	wait(0.2)
	joinserver()
end
