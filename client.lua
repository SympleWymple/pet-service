local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local Knit = require(ReplicatedStorage.Packages.Knit)
local WaitFor = require(ReplicatedStorage.Packages.WaitFor)
local Assets = ReplicatedStorage.Pets

local PetUtility = require(ReplicatedStorage.Modules.PetUtility)
local UIGradient = require(ReplicatedStorage.Modules.Gradient)


local unitVec = Vector3.new(1, 0, 1)
local player = Players.LocalPlayer


local PetMovementController = Knit.CreateController { Name = "PetMovementController"}
PetMovementController._Pets = {}
PetMovementController.otherPetsHidden = false
PetMovementController.allPetsHidden = false

function PetMovementController:TogglePetsVisibility(hidePets: boolean, hideType: string)
	if hidePets == true then
		if hideType == "All" then
			PetMovementController.allPetsHidden = true
			for _, pet in self._Pets do pet.Render.Parent = ReplicatedStorage end
			return
		end
		if hideType == "Others" then
			PetMovementController.otherPetsHidden = true
			if PetMovementController.allPetsHidden== true then return end
			for _, pet in self._Pets do pet.Render.Parent = pet.Owner ~= player and ReplicatedStorage or workspace end
		end
	else
		if hideType == "All" then
			PetMovementController.allPetsHidden = false
			for _, pet in self._Pets do 
				pet.Render.Parent = PetMovementController.otherPetsHidden == false and workspace or PetMovementController.otherPetsHidden == true and pet.Owner ~= player and ReplicatedStorage or workspace 
			end
			return
		end
		if hideType == "Others" then
			PetMovementController.otherPetsHidden = false
			if PetMovementController.allPetsHidden == true then return end
			for _, pet in self._Pets do pet.Render.Parent = workspace end
		end
	end
end


function PetMovementController:_getOwnedPets(player: Player)
	local pets = {}
	for _, pet in self._Pets do
		if (pet.Owner == player) then
			table.insert(pets, pet)
		end
	end
	return pets
end

function PetMovementController:_preparePet(serverPet: StringValue)
	local PetService = Knit.GetService("PetService")

	if (serverPet:IsA("StringValue")) then


		if (Assets:WaitForChild(serverPet.Value)) then
			local petModel = Assets:WaitForChild(serverPet.Value):Clone()

			local petTag = script.PetTag:Clone()
			petTag.Parent = petModel.PrimaryPart
			petTag.PetName.Text = petModel.Name

			petModel.Name = serverPet.Name
			petModel:SetAttribute("Owner", serverPet:GetAttribute("Owner"))

			local server_player = Players:FindFirstChild(serverPet:GetAttribute("Owner"))
			if server_player then
				local pet_data = PetService:_GetPetData(server_player, serverPet.Name):expect()
				--> shinny stuff
				if pet_data.PetType > 1 then
					petTag.PetEvo.Visible = true
					petTag.PetEvo.Text = ("Shiny (%s)"):format(string.rep("I", pet_data.PetType - 1))
					UIGradient(petTag.PetEvo, "Shiny", 45)
				end
				
				if pet_data.Type ~= "Normal" then
					local Type = ReplicatedStorage.Assets.PetType:FindFirstChild(pet_data.Type)
					if Type then
						local TypeClone = Type:Clone()
						for i, v in TypeClone:GetChildren() do
							if v:IsA("ParticleEmitter") then
								v.Parent = petModel.PrimaryPart
							end
						end

					end
				end
			end
			
			for _, v in petModel:GetDescendants() do
				if (v:IsA("BasePart")) then
					v.Anchored = true
					v.CanCollide = false
				end
			end
			
			
			petModel.Parent = PetMovementController.allPetsHidden == true and ReplicatedStorage or PetMovementController.otherPetsHidden == true and Players:FindFirstChild(serverPet:GetAttribute("Owner")) ~= player and ReplicatedStorage or workspace.Terrain
			return petModel
		else
			warn("failed pet creation L do better")
		end
	end

end


function PetMovementController:_createPet(serverPet: StringValue)
	local petOwner = serverPet:GetAttribute("Owner")
	local petModel = self:_preparePet(serverPet)
	if not petModel then
		return
	end
	local preparedModel = PetUtility.SetupPet(petModel)

	if (not Players:FindFirstChild(petOwner)) then
		warn("Failed to get Pet Owner")
		return
	end

	local petInformation = {
		Owner = Players:FindFirstChild(petOwner),
		Render = preparedModel,
		AnimationType = serverPet:GetAttribute("Movement"),
		RadiusAngle = 0, 
		LastPosition = Vector3.new(), 
		Model = petModel,
		RadiusOffset = 30,
		Phase = math.random() * 3.14, 
		Anim = CFrame.new(), 
		Twist = CFrame.new(), 
		Animation = CFrame.new(), 
		CFrame = CFrame.new()
	}

	local character = Players:FindFirstChild(petOwner).Character
	if (character) then
		petInformation.CFrame = character.PrimaryPart.CFrame * CFrame.new(0, -2.5, 0)
		petModel:PivotTo(petInformation.CFrame)
	end

	self._Pets[petModel.Name] = petInformation
	local pets = self:_getOwnedPets(Players:FindFirstChild(petOwner))

	for index, value in pets do
		value.RadiusAngle = math.rad((index / #pets * 360))
	end
end


function PetMovementController:_removePet(petModel: StringValue)
	local pet = self._Pets[petModel.Name]
	if pet ~= nil then
		local pets = self:_getOwnedPets(pet.Owner)
		for index, value in pets do
			value.RadiusAngle = math.rad(index / (#pets - 1) * 360)
		end
		if pet.Render ~= nil then
			pet.Render:Destroy()
		end
		self._Pets[petModel.Name] = nil
	end
end

--> MOVEMENT SYSTEM
local function GetPetCFrameGoal(ServerPet)
	local Character = ServerPet.Owner.Character
	if not Character or not Character.PrimaryPart then
		return CFrame.new(0, -5, 0)
	end
	local number5 = 5 + ServerPet.Model.PrimaryPart.Size.Z / 2
	return Character:GetPrimaryPartCFrame() + Vector3.new(math.sin(ServerPet.RadiusAngle + ServerPet.RadiusOffset) * 5, -3, math.cos(ServerPet.RadiusAngle + ServerPet.RadiusOffset) * 5)
end

function PetMovementController:_updateMovement(pet: {[any]: any} )
	local character = pet.Owner.Character

	if (character and character.PrimaryPart) then	
		if (pet.Render and pet.Render.PrimaryPart) then
			local currentPetPhase = tick() + pet.Phase
			local returnedCframe = GetPetCFrameGoal(pet)

			local CharacterUnitVec = character.PrimaryPart.Position * unitVec
			local LastPosition = (CharacterUnitVec - pet.LastPosition).magnitude > 0.05
			local NewCFrame1 = CFrame.new()

			if LastPosition then
				NewPetCFrame = pet.CFrame - pet.CFrame.Position
			else
				NewPetCFrame = CFrame.new(pet.CFrame.Position * unitVec, CharacterUnitVec) - pet.CFrame.Position
			end

			if pet.AnimationType == "Walk" and (LastPosition or returnedCframe.Position.Y < pet.Model.PrimaryPart.Position.Y) then
				local animation = math.clamp((returnedCframe.Position * unitVec - pet.CFrame.Position * unitVec).magnitude, 0, 2) / 2
				NewCFrame1 = CFrame.new(0, math.abs(math.sin(currentPetPhase * 10)) * 3 * animation, 0) * CFrame.Angles(0, 0, math.rad(math.sin(currentPetPhase * 10)) * 20 * animation)
			elseif pet.AnimationType == "Fly" then
				NewCFrame1 = CFrame.new(0, 3, 0) * CFrame.Angles(math.rad(math.cos(currentPetPhase * 4)) * 8, 0, 0) + Vector3.new(0, math.sin(currentPetPhase * 4) * 0.5, 0)
			end
			
			print(NewCFrame1)
			local TwistLerp = pet.Twist:Lerp(NewPetCFrame, 0.15)
			local TwistLerpPos = TwistLerp - TwistLerp.Position

			local CframeAnim = pet.Animation:Lerp(NewCFrame1, 0.333)
			local CframeLerp = pet.CFrame:Lerp(returnedCframe, 0.1)

			pet.LastPosition = CharacterUnitVec
			pet.Twist = TwistLerpPos
			pet.Animation = CframeAnim
			pet.CFrame = CframeLerp
			pet.Model:SetPrimaryPartCFrame(CFrame.new(CframeLerp.Position) * TwistLerpPos * CframeAnim * CFrame.Angles(0, math.rad(180), 0))
		end
	end
end


function PetMovementController:KnitStart()	
	local DataController = Knit.GetController("DataController")
	local Replica = DataController:GetReplica("PlayerProfile")
	
	local playerPets = workspace:WaitForChild("PlayerPets")
	
	Replica:ListenToChange({"Setting", "ShowPets"}, function(old_Value, new_Value)
		self:TogglePetsVisibility(new_Value, "All")
	end)
	
	if Replica.Data.Setting.ShowPets == false then
		self:TogglePetsVisibility(true, "All")
	end
	
	for _, pet in playerPets:GetChildren() do
		task.defer(function()
			self:_createPet(pet)
		end)
	end

	playerPets.ChildAdded:Connect(function(petInstance)
		repeat wait() until petInstance ~= nil
		self:_createPet(petInstance)
	end)

	playerPets.ChildRemoved:Connect(function(petInstance)
		repeat wait() until petInstance ~= nil
		self:_removePet(petInstance)
	end)

	RunService.RenderStepped:Connect(function()
		for _, pet in self._Pets do
			self:_updateMovement(pet) --> or task.defer
		end
	end)
end

return PetMovementController
