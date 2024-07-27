local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local MarketPlaceService = game:GetService("MarketplaceService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

local PetModule = require(ReplicatedStorage.Modules.SharedData.PetData)
local EggData = require(ReplicatedStorage.Modules.SharedData.EggData)
local Constants = require(ReplicatedStorage.Modules.Constants)
local Multipliers = require(ReplicatedStorage.Modules.Multiplier)
local PetHandlerModule = require(ServerScriptService.Modules.PetHandlerModule)

local Knit = require(ReplicatedStorage.Packages.Knit)
local EggModels = workspace:FindFirstChild("EggModels")
local Remotes = ReplicatedStorage.Remotes
local playerPets = workspace:FindFirstChild("PlayerPets")
local PetService = Knit.CreateService({Name = "PetService", Client = {}})


function PetService.Client:EquipPet(player: Player, petInfo: string | number)
	local DataService = Knit.GetService("DataService")
	--assert(type(petInfo) == "table", "player must be exploiting or something lol")
	--if (Pets.Get(petInfo.PetName) == nil) then return end
	--> Disabled for now if (Pets.Get(petInfo.PetName) == nil) then return end

	local foundPet = DataService:Get(player, {"Pet", "Inventory"})[petInfo]

	if (foundPet == nil) then
		return false, "Pet Was Not Found"
	end

	if (table.find(DataService:Get(player, {"Pet", "Equipped"}), foundPet.PetId)) then
		return false, "Pet Is Already Equipped"
	end

	local maxPetsEquipped = Multipliers.MaxPetEquipped(player)
	--> Checking max equip size
	if (#DataService:Get(player, {"Pet", "Equipped"}) < maxPetsEquipped) then
		DataService:NewTableValue(player, {"Pet", "Equipped"}, foundPet.PetId)
		local Multiplier = DataService:Get(player, {"Pet", "Inventory"})[foundPet.PetId].Multiplier
		if Multiplier then
			DataService:Increment(player, "PetPower", Multiplier)
		end
		self.Server:_setupPet(player, foundPet)

		return true, "Pet Was Equipped Successfully"
	else
		return false, "You Have Max Pets Equipped"
	end
end


function PetService.Client:UnequipPet(player: Player, petInfo: string)
	local DataService = Knit.GetService("DataService")
	--assert(type(petInfo) == "table", "player must be exploiting or something lol")
	--if (Pets.Get(petInfo.PetName) == nil) then return end
	--> Disabled for now if (Pets.Get(petInfo.PetName) == nil) then return end

	local foundPet = DataService:Get(player, {"Pet", "Inventory"})[petInfo]

	if (foundPet == nil) then
		return false, "Pet Was Not Found"
	end

	local index = table.find(DataService:Get(player, {"Pet", "Equipped"}), foundPet.PetId)
	local petValueInstance = playerPets:FindFirstChild(foundPet.PetId)
	local petModelInstance = game.Workspace.Terrain:FindFirstChild(foundPet.PetId)

	if (index) then
		local Multiplier = DataService:Get(player, {"Pet", "Inventory"})[foundPet.PetId].Multiplier
		if Multiplier then
			local ammount = math.max( DataService:Get(player, "PetPower") - Multiplier, 1)
			DataService:Set(player, "PetPower", ammount)
		end
		DataService:RemoveTable(player, {"Pet", "Equipped"}, index)
		if (petValueInstance and petValueInstance:GetAttribute("Owner") == player.Name) then
			petValueInstance:Destroy()
		end
		if (petModelInstance and petModelInstance:GetAttribute("Owner") == player.Name) then
			petModelInstance:Destroy()
		end

		return true, "Pet Was Unequipped Successfully"
	else
		return false, "Pet Was Not Equipped"
	end
end

function PetService.Client:EquipBest(Player)
	local DataService = Knit.GetService("DataService")
	--[[
		use table.sort to find pets with best for the stat
		loop through all equipped pets and remove from
		table and instances
	]]

	for _, petId in ipairs(DataService:Get(Player, {"Pet", "Equipped"})) do
		local Multiplier = DataService:Get(Player, {"Pet", "Inventory"})[petId].Multiplier
		if Multiplier then
			local ammount = math.max( DataService:Get(Player, "PetPower") - Multiplier, 1 )
			DataService:Set(Player, "PetPower", ammount)
		end
		
		--> when I have pet models in workspace
		local petValueInstance = playerPets:FindFirstChild(petId)
		if (petValueInstance and petValueInstance:GetAttribute("Owner") == Player.Name) then
			petValueInstance:Destroy()
		end
		local petModelInstance = game.Workspace.Terrain:FindFirstChild(petId)
		if (petModelInstance and petModelInstance:GetAttribute("Owner") == Player.Name) then
			petModelInstance:Destroy()
		end
	end	

	local petData = DataService:Get(Player, {"Pet", "Inventory"})
	local equippedPets = DataService:Get(Player, {"Pet", "Equipped"})
	local selectedUnequippedPets = {}
	local sortedPetData = {}
	DataService:Set(Player, {"Pet", "Equipped"}, {})

	for petId, petInfo in pairs(petData) do
		if (table.find(equippedPets, petId)) then
			table.insert(selectedUnequippedPets, petInfo)
		end
		if petInfo.Type == "Crafting" then continue end
		table.insert(sortedPetData, petInfo.PetId)
	end

	local selectedPets = {}
	local maxPetsEquipped = Multipliers.MaxPetEquipped(Player)
	local equippedPet = false

	table.sort(sortedPetData, function(a, b)
		local Pet_DataA = petData[a]
		local Pet_DataB = petData[b]

		local Rariety_A = Constants.Rarities[PetModule[Pet_DataA.PetName].Rarity].SortOrder
		local Rariety_B = Constants.Rarities[PetModule[Pet_DataB.PetName].Rarity].SortOrder

		if Pet_DataA.Multiplier ~= Pet_DataB.Multiplier then
			return Pet_DataA.Multiplier > Pet_DataB.Multiplier
		end

		if Rariety_A ~= Rariety_B then
			return Rariety_A > Rariety_B
		end

		if Pet_DataA.PetName ~= Pet_DataB.PetName then
			return Pet_DataA.PetName > Pet_DataB.PetName
		end

		return Pet_DataA.PetId > Pet_DataB.PetId
	end)

	for i = 1, maxPetsEquipped do
		local petSortedInfo = sortedPetData[i]
		if (petSortedInfo) then
			equippedPet = true
			task.defer(function()
				local Multiplier = DataService:Get(Player, {"Pet", "Inventory"})[petSortedInfo].Multiplier
				DataService:NewTableValue(Player, {"Pet", "Equipped"}, petSortedInfo)
				DataService:Increment(Player, "PetPower", Multiplier)
			end)
			self.Server:_setupPet(Player, DataService:Get(Player, {"Pet", "Inventory"})[petSortedInfo])
			table.insert(selectedPets, DataService:Get(Player, {"Pet", "Inventory"})[petSortedInfo])
		end
	end
	if (equippedPet == true) then
		return selectedPets, selectedUnequippedPets, "Equipped Best Pets Successfully"
	else
		return false, false, "You Don't Have Any Pets!"
	end
end



function PetService.Client:UnequipAll(player: Player)
	local DataService = Knit.GetService("DataService")
	if (#DataService:Get(player, {"Pet", "Equipped"}) > 1) then
		local temp = {}
		local actualData = {}

		for _, petId in pairs(DataService:Get(player, {"Pet", "Equipped"})) do
			table.insert(temp, petId)
			
			local Multiplier = DataService:Get(player, {"Pet", "Inventory"})[petId].Multiplier
			if Multiplier then
				local ammount = math.max( DataService:Get(player, "PetPower") - Multiplier, 1 )
				DataService:Set(player, "PetPower", ammount)
			end
			
			local petValueInstance = playerPets:FindFirstChild(petId)
			if (petValueInstance and petValueInstance:GetAttribute("Owner") == player.Name) then
				petValueInstance:Destroy()
			end
			local petModelInstance = game.Workspace.Terrain:FindFirstChild(petId)
			if (petModelInstance and petModelInstance:GetAttribute("Owner") == player.Name) then
				petModelInstance:Destroy()
			end
		end

		for _, petId in ipairs(temp) do
			local petData = DataService:Get(player, {"Pet", "Inventory"})[petId]
			if (petData) then
				table.insert(actualData, petData)
			end
		end

		DataService:Set(player, {"Pet", "Equipped"}, {})
		return actualData, "Unequipped All Pets"
	end
end

function PetService.Client:DeletePet(player: Player, petIds: {[string]: string})
	local DataService = Knit.GetService("DataService")

	assert(type(petIds) == "table", "player must be exploiting or something lol")

	local deletedPets = {}

	for _, petId in ipairs(petIds) do
		if (DataService:Get(player, {"Pet", "Inventory"})[petId]) then
			local index = table.find(DataService:Get(player, {"Pet", "Equipped"}), petId)
			local petValueInstance = playerPets:FindFirstChild(petId)
			local petModelInstance = game.Workspace.Terrain:FindFirstChild(petId)
			if index then
				DataService:RemoveTable(player, {"Pet", "Equipped"}, index)
				local Multiplier = DataService:Get(player, {"Pet", "Inventory"})[petId].Multiplier
				if Multiplier then
					local ammount = math.max( DataService:Get(player, "PetPower") - Multiplier, 1 )
					DataService:Set(player, "PetPower", ammount)
				end
				
				if (petValueInstance and petValueInstance:GetAttribute("Owner") == player.Name) then
					petValueInstance:Destroy()
				end
				if (petModelInstance and petModelInstance:GetAttribute("Owner") == player.Name) then
					petModelInstance:Destroy()
				end
			end

			DataService:ArraySet(player , {"Pet", "Inventory"}, petId, nil)
			table.insert(deletedPets, petId)
		end
	end
	return deletedPets
end

function PetService:DeletePet(player: Player, petIds: {[string]: string})
	local DataService = Knit.GetService("DataService")

	assert(type(petIds) == "table", "player must be exploiting or something lol")

	local deletedPets = {}

	for _, petId in ipairs(petIds) do
		if (DataService:Get(player, {"Pet", "Inventory"})[petId]) then
			local index = table.find(DataService:Get(player, {"Pet", "Equipped"}), petId)
			local petValueInstance = playerPets:FindFirstChild(petId)
			local petModelInstance = game.Workspace.Terrain:FindFirstChild(petId)
			if index then
				DataService:RemoveTable(player, {"Pet", "Equipped"}, index)
				local Multiplier = DataService:Get(player, {"Pet", "Inventory"})[petId].Multiplier
				if Multiplier then
					local ammount = math.max( DataService:Get(player, "PetPower") - Multiplier, 1 )
					DataService:Set(player, "PetPower", ammount)
				end

				if (petValueInstance and petValueInstance:GetAttribute("Owner") == player.Name) then
					petValueInstance:Destroy()
				end
				if (petModelInstance and petModelInstance:GetAttribute("Owner") == player.Name) then
					petModelInstance:Destroy()
				end
			end

			DataService:ArraySet(player , {"Pet", "Inventory"}, petId, nil)
			table.insert(deletedPets, petId)
		end
	end
	return deletedPets
end

function PetService.Client:CraftPet(Player, PetId, PetInfo)
	local DataService = Knit.GetService("DataService")
	local Inventory = DataService:Get(Player, {"Pet", "Inventory"})
	local Equipped = DataService:Get(Player, {"Pet", "Equipped"})

	local CraftedTable = {}

	if PetInfo.PetType >= 3 and Inventory[PetId] == nil then return end 

	--> insert pets where gonna craft
	table.insert(CraftedTable, PetId)
	for petId, petData in Inventory do
		if not table.find(CraftedTable, petId) then
			if petData.PetName == PetInfo.PetName and petData.PetType == PetInfo.PetType and petData.Type == PetInfo.Type and PetId ~= petData.PetId then
				table.insert(CraftedTable, petId)
			end
		end
	end


	if #CraftedTable >= 5 then
		for i = 2,5 do
			local currentPetInfo = Inventory[CraftedTable[i]]

			if currentPetInfo then
				local index = table.find(Equipped, currentPetInfo.PetId)
				local petValueInstance = playerPets:FindFirstChild(currentPetInfo.PetId)
				local petModelInstance = game.Workspace.Terrain:FindFirstChild(currentPetInfo.PetId)
				if index then
					DataService:RemoveTable(Player, {"Pet", "Equipped"}, index)
					local Multiplier = DataService:Get(Player, {"Pet", "Inventory"})[currentPetInfo.PetId].Multiplier
					if Multiplier then
						local ammount = math.max( DataService:Get(Player, "PetPower") - Multiplier, 1 )
						DataService:Set(Player, "PetPower", ammount)
					end

					if (petValueInstance and petValueInstance:GetAttribute("Owner") == Player.Name) then
						petValueInstance:Destroy()
					end
					if (petModelInstance and petModelInstance:GetAttribute("Owner") == Player.Name) then
						petModelInstance:Destroy()
					end
				end

				DataService:ArraySet(Player, {"Pet", "Inventory"}, currentPetInfo.PetId, nil)
			end
		end
	else

		return false
	end

	local index = table.find(Equipped, PetId)
	local petValueInstance = playerPets:FindFirstChild(PetId)
	local petModelInstance = game.Workspace.Terrain:FindFirstChild(PetId)
	if index then
		DataService:RemoveTable(Player, {"Pet", "Equipped"}, index)
		local Multiplier = DataService:Get(Player, {"Pet", "Inventory"})[PetId].Multiplier
		if Multiplier then
			local ammount = math.max( DataService:Get(Player, "PetPower") - Multiplier, 1 )
			DataService:Set(Player, "PetPower", ammount)
		end

		if (petValueInstance and petValueInstance:GetAttribute("Owner") == Player.Name) then
			petValueInstance:Destroy()
		end
		if (petModelInstance and petModelInstance:GetAttribute("Owner") == Player.Name) then
			petModelInstance:Destroy()
		end
	end

	local currentPetType = PetInfo.PetType + 1
	local CurrentPetMultiplier = PetInfo.Multiplier * 2

	DataService:SetValues(Player, {"Pet", "Inventory", PetId}, {PetType = currentPetType, Multiplier = CurrentPetMultiplier})
	--DataService:SetValues(Player, {"Pet", "Inventory", PetId}, {"Multiplier", CurrentPetMultiplier})

	return true, "Crafted Pet", DataService:Get(Player, {"Pet", "Inventory"})[PetId]
end

function PetService.Client:GetAllPetsOfAType(Player, PetInfo)
	local DataService = Knit.GetService("DataService")

	local Inventory = DataService:Get(Player, {"Pet", "Inventory"})

	local count = 0

	for petId, petData in Inventory do
		if petData.PetName == PetInfo.PetName and petData.PetType == PetInfo.PetType and petData.Type == PetInfo.Type then
			count = count + 1
		end
	end

	return count
end

--function PetService.Client:OrderPetTable(Player)
--	local DataService = Knit.GetService("DataService")
--	local petData = DataService:Get(Player, {"Pet", "Inventory"})

--	table.sort(petData, function(a, b)
--		return a.Multiplier > b.Multiplier
--	end)
--	return petData
--end

local function generatePetId(petData: { [string]: {any} })
	local petId = HttpService:GenerateGUID(false)
	if (petData[petId]) then
		generatePetId(petData)
	else
		return petId
	end
end

function PetService:AddPet(player: Player, petInfo: string)
	local DataService = Knit.GetService("DataService")
	local petId  = generatePetId(DataService:Get(player, {"Pet", "Inventory"}))
	DataService:SetValues(player ,{"Pet", "Inventory"}, {
		[petId] = {
			PetName = petInfo,
			Nickname = petInfo,
			PetId = petId,
			Multiplier = PetModule[petInfo].Multiplier,
			Level = 1,
			Exp = 0,
			Power = "",
			Type = "Normal",
			PetType = 1,
			Rarity = PetModule[petInfo].Rariety,
			Craftable = true,
			Deletable = true,
			PowerRerollable = false,
		}
	})
end

function PetService:SetupPet(player: Player, petStats: {[any]: any})
	self:_setupPet(player, petStats)
end

function PetService.Client:_GetPetData(player: Player, ActualPlayer:Player,  pet_id)
	local DataService = Knit.GetService("DataService")
	return DataService:Get(ActualPlayer, {"Pet", "Inventory"})[pet_id]
end

function PetService:ClearPets(player: Player)
	for _, petValueInstance in ipairs(playerPets:GetChildren()) do
		if (petValueInstance:GetAttribute("Owner") == player.Name) then
			petValueInstance:Destroy()
		end
	end
	for _, petModelInstance in ipairs(game.Workspace.Terrain:GetChildren()) do
		if (petModelInstance:GetAttribute("Owner") == player.Name) then
			petModelInstance:Destroy()
		end
	end
end

function PetService:_setupPet(player: Player, petStats: {[any]: any})
	if (playerPets:FindFirstChild(petStats.PetId)) then
		playerPets:FindFirstChild(petStats.PetId):Destroy()
		return
	end 

	if (ReplicatedStorage.Pets:WaitForChild(petStats.PetName)) then
		local fakePetModel = Instance.new("StringValue")
		fakePetModel.Name = petStats.PetId
		fakePetModel.Value = petStats.PetName

		local Attribute = ReplicatedStorage.Pets:WaitForChild(petStats.PetName):GetAttribute("Movement")

		fakePetModel:SetAttribute("Movement", Attribute)--petData.Fly and "Fly" or "Walk")
		fakePetModel:SetAttribute("Owner", player.Name)

		fakePetModel.Parent = playerPets

		--local Tag = script.PetTag:Clone()
		--Tag.Parent = petModel.PrimaryPart
		--Tag.PetName.Text = petModel.Name

		--petModel.Name = petStats.PetId
		--petModel:SetAttribute("Owner", player.Name)
		----petModel:SetAttribute("Movement", petData.Fly and "Fly" or "Walk")
		--for _, v in ipairs(petModel:GetDescendants()) do
		--	if (v:IsA("BasePart")) then
		--		v.Anchored = true
		--		v.CanCollide = false
		--	end
		--end
		--petModel.Parent = playerPets
	else
		warn("failed pet creation L do better")
	end
end

function PetService:KnitInit()
	Players.PlayerRemoving:Connect(function(player: Player) 
		for _, PetModels: Model in workspace.PlayerPets:GetChildren() do
			if PetModels:GetAttribute("Owner") == player.Name then
				PetModels:Destroy()
			end
		end
	end)
end


return PetService
