--[[
	Renegade 2D: Lua script by @hamb
	Version: 0.95
	Engine: OpenRA release-20190314
]]

--[[ General ]]
PlayerInfo = { }
TeamInfo = { }
TeamStats = { } -- Updated on an event. Stores total experience, kills, and deaths for the team
HealthAfterOnDamageEventTable = { } -- HACK: We store damage dealt since last instance, since OnDamage doesn't tell us.
HarvesterWaypoints = { } -- Waypoints used to guide harvesters near their ore field.
BeaconSoundsTable = { }
CashPerSecond = 2 -- Cash given per second.
CashPerSecondPenalized = 1 -- Cash given per second, with no ref.
BuildingHuskSuffix = ".husk"
PurchaseTerminalActorType = "purchaseterminal"
PurchaseTerminalInfantryActorTypePrefix = "buy.infantry."
PurchaseTerminalVehicleActorTypePrefix = "buy.vehicle."
PurchaseTerminalAircraftActorTypePrefix = "buy.aircraft."
PurchaseTerminalBeaconActorTypePrefix = "buy.beacon."
HeroItemPlaceBeaconActorTypePrefix = "buy.placebeacon."
NotifyBaseUnderAttackInterval = DateTime.Seconds(30)
NotifyHarvesterUnderAttackInterval = DateTime.Seconds(30)
BeaconTimeLimit = DateTime.Seconds(45)
RespawnTime = DateTime.Seconds(3)
LocalPlayerInfo = nil -- HACK: Used for nametags & scoreboard.
EnemyNametagsHiddenForTypes = { "stnk" } -- HACK: Used for nametags.
GameOver = false
TimeLimitExpired = false
BotNames = {
	"Plorp", "Gorbel", "Splunch", "Borch", "Big Jeff", "Spurtle", "Gurgis", "Brumpus", "Yurst", "Ol Ginch",
	"Gurch", "Plape", "Sporf", "Kranch", "Splinch", "Gorpo", "Forpel", "Gromph", "Dorbie", "Jorf", "Splurst",
	"Shorp", "Bortles", "Bubson", "Plench", "Clorch", "Borth", "Bobson", "Munton", "Plungus", "Brungus", "Dorgel",
	"Blurp", "Paunch", "Wedge", "Arp 299"
}

--[[ Mod-specific ]]
Mod = "cnc"
if Mod == "cnc" then
	SpawnAsActorType = "e1"
	AlphaTeamPlayerName = "GDI"
	BetaTeamPlayerName = "Nod"
	NeutralPlayerName = "Neutral"
	ConstructionYardActorTypes = {"fact"}
	RefineryActorTypes = {"proc"}
	PowerplantActorTypes = {"nuk2"}
	RadarActorTypes = {"hq"}
	WarFactoryActorTypes = {"weap","afld"}
	BarracksActorTypes = {"pyle","hand"}
	HelipadActorTypes = {"hpad"}
	ServiceDepotActorTypes = {"fix"}
	DefenseActorTypes = {"gtwr","atwr","gun","obli"}
	AiHarvesterActorType = "harv-ai"
	PlayerHarvesterActorType = "harv"
	SoundMissionStarted = "bombit1.aud"
	SoundBaseUnderAttack = "baseatk1.aud"
	SoundMissionAccomplished = "accom1.aud"
	SoundMissionFailed = "fail1.aud"
	AlphaBeaconType = "ion-beacon"
	BetaBeaconType = "nuke-beacon"
	BeaconDeploySound = "target3.aud"
	BeaconHitCamera = "camera.beacon"
	BeaconSoundsTable['ion-beacon'] = 'ionchrg1.aud'
	BeaconSoundsTable['nuke-beacon'] = 'nuke1.aud'
elseif Mod == "ra" then
	SpawnAsActorType = "e1"
	AlphaTeamPlayerName = "Allies"
	BetaTeamPlayerName = "Soviet"
	NeutralPlayerName = "Neutral"
	ConstructionYardActorTypes = {"fact"}
	RefineryActorTypes = {"proc"}
	PowerplantActorTypes = {"apwr"}
	RadarActorTypes = {"dome"}
	WarFactoryActorTypes = {"weap"}
	BarracksActorTypes = {"barr","tent"}
	HelipadActorTypes = {"hpad"}
	ServiceDepotActorTypes = {"fix"}
	DefenseActorTypes = {"pbox","hbox","gun","ftur","tsla"}
	AiHarvesterActorType = "harv-ai"
	PlayerHarvesterActorType = "harv"
	SoundMissionStarted = "newopt1.aud"
	SoundBaseUnderAttack = "baseatk1.aud"
	SoundMissionAccomplished = "misnwon1.aud"
	SoundMissionFailed = "misnlst1.aud"
	AlphaBeaconType = "nuke-beacon"
	BetaBeaconType = "nuke-beacon"
	BeaconDeploySound = "bleep9.aud"
	BeaconHitCamera = "camera.paradrop"
	BeaconSoundsTable['nuke-beacon'] = 'aprep1.aud'
end
AlphaTeamPlayer = Player.GetPlayer(AlphaTeamPlayerName)
BetaTeamPlayer = Player.GetPlayer(BetaTeamPlayerName)
NeutralPlayer = Player.GetPlayer(NeutralPlayerName)

WorldLoaded = function()
	Media.PlaySound(SoundMissionStarted)

	SetPlayerInfo()
	SetTeamInfo()
	SetBotNames()

	AssignTeamBuildings()
	AssignSpawnLocations()

	SetVictoryConditions()

	BindBaseEvents()
	BindVehicleEvents()
	BindProximityEvents()
	BindTimeLimitEvents()

	AddPurchaseTerminals()

	-- Delayed due to interacting with actors that were added on tick 0.
	Trigger.AfterDelay(1, function()
		Utils.Do(PlayerInfo, function(pi) SpawnHero(pi.Player) end)

		BindPurchaseTerminals()

		InitializeAiHarvesters()
	end)

	-- Tick interval > 1
	IncrementPlayerCash()
	DistributeGatheredResources()
	UpdateTeamStats()
	CheckVictoryConditions()
	DrawScoreboard()

	-- Any tests
	DoTests()
end

Tick = function()
	-- Tick interval = 1
	IncrementUnderAttackNotificationTicks()
	HackyDrawNameTags()
end

--[[ World Loaded / Gameplay ]]
SetPlayerInfo = function()
	local teamPlayers = Player.GetPlayers(function(p)
		return PlayerIsHumanOrBot(p)
	end)

	Utils.Do(teamPlayers, function(p)
		PlayerInfo[p.InternalName] =
		{
			Player = p, -- Player
			Team = nil, -- TeamInformation for this player
			Hero = nil, -- Actor: Hero
			PurchaseTerminal = nil, -- Actor: Purchase Terminal
			CanBuyConditionToken = -1, -- Attached to a Hero actor
			HasBeaconConditionToken = -1, -- Attached to a Hero actor
			VehicleConditionToken = -1, -- Attached to a Purchase Terminal actor
			InfantryConditionToken = -1, -- Attached to a Purchase Terminal actor
			AircraftConditionToken = -1, -- Attached to a Purchase Terminal actor
			RadarConditionToken = -1, -- Attached to a Purchase Terminal actor
			Kills = 0, -- Hero kills
			Deaths = 0, -- Hero deaths
			PassengerOfVehicle = nil, -- Actor of what vehicle they are a passenger of
			IsPilot = false, -- Bool indicating if they are piloting a vehicle
			ProximityEventTokens = { }, -- Conditional tokens used for proximity events
			VictoryMissionObjectiveId = -1,  -- Conditional token used for victory conditions
			Surrendered = false, -- Bool if they've surrendered
			BotState = { -- Used if the player is a bot
				DisplayName = "" -- Bot's display name
			}
		}

		if p.IsLocalPlayer then	LocalPlayerInfo = PlayerInfo[p.InternalName] end
	end)
end

SetTeamInfo = function()
	local teams = Player.GetPlayers(function (p) return PlayerIsTeamAi(p) end)

	Utils.Do(teams, function(team)
		local playersOnTeam = { }
		for k, v in pairs(PlayerInfo) do
			if v.Player.Faction == team.Faction then
				playersOnTeam[v.Player.InternalName] = v
			end
		end

		TeamInfo[team.InternalName] = {
			AiPlayer = team, -- The "AI" player of the team
			Players = playersOnTeam, -- All other Player actors on this team
			ConstructionYard = nil, -- Actor reference to Construction Yard
			Refinery = nil, -- Actor reference to Refinery
			Barracks = nil, -- Actor reference to Barracks
			WarFactory = nil, -- Actor reference to Vehicle Production
			Helipad = nil, -- Actor reference to Helipad
			Radar = nil, -- Actor reference to Radar
			Powerplant = nil, -- Actor reference to Power Plant
			ServiceDepot = nil, -- Actor reference to Service Depot
			AiHarvester = nil, -- Actor reference to the AI-driven team harvester
			Defenses = {}, -- Actor references to any base defenses
			SpawnLocations = {}, -- Spawn locations set at the start of the game
			LastCheckedResourceAmount = 0, -- Used when calculating and distributing shared funds
			TicksSinceLastBuildingDamage = NotifyBaseUnderAttackInterval, -- Amount of ticks since a building was last damaged
			TicksSinceLastHarvesterDamage = NotifyHarvesterUnderAttackInterval, -- Amount of ticks since a harvester was last damaged
			WarFactoryActorLocation = nil, -- Location of where the war factory was, so air drops can be made when it's destroyed
			HelipadActorLocation = nil -- Location of where the helipad was,  so air drops can be made when it's destroyed
		}
	end)

	-- Store a reference to the team info on the player.
	Utils.Do(TeamInfo, function(ti)
		Utils.Do(ti.Players, function(pi)
			pi.Team = ti
		end)
	end)
end

SetBotNames = function()
	-- Assigns bots a random name.
	BotNames = Utils.Shuffle(BotNames)
	local index = 1
	Utils.Do(PlayerInfo, function(pi)
		if pi.Player.IsBot then
			pi.BotState.DisplayName = BotNames[index]
			index = index + 1
		end
	end)
end

AssignTeamBuildings = function()
	Utils.Do(Map.ActorsInWorld, function(actor)
		if ArrayContains(ConstructionYardActorTypes, actor.Type) then
			TeamInfo[actor.Owner.InternalName].ConstructionYard = actor
		end

		if ArrayContains(RefineryActorTypes, actor.Type) then
			TeamInfo[actor.Owner.InternalName].Refinery = actor
		end

		if ArrayContains(RadarActorTypes, actor.Type) then
			TeamInfo[actor.Owner.InternalName].Radar = actor
		end

		if ArrayContains(WarFactoryActorTypes, actor.Type) then
			TeamInfo[actor.Owner.InternalName].WarFactory = actor
			TeamInfo[actor.Owner.InternalName].WarFactoryActorLocation = actor.Location
		end

		if ArrayContains(BarracksActorTypes, actor.Type) then
			TeamInfo[actor.Owner.InternalName].Barracks = actor
		end

		if ArrayContains(HelipadActorTypes, actor.Type) then
			TeamInfo[actor.Owner.InternalName].Helipad = actor
			TeamInfo[actor.Owner.InternalName].HelipadActorLocation = actor.Location
		end

		if ArrayContains(PowerplantActorTypes, actor.Type) then
			TeamInfo[actor.Owner.InternalName].Powerplant = actor
		end

		if ArrayContains(ServiceDepotActorTypes, actor.Type) then
			TeamInfo[actor.Owner.InternalName].ServiceDepot = actor
		end

		if ArrayContains(DefenseActorTypes, actor.Type) then
			local ti = TeamInfo[actor.Owner.InternalName]
			ti.Defenses[#ti.Defenses+1] = actor
		end
	end)
end

AssignSpawnLocations = function()
	--[[
		Hacky/funny :)
		Spawn points are defined as areas around a building's location
		Assumes buildings are shaped as:
			ooo
			ooo
			ooo

		We get the center of the building, expand twice, and only use the annulus (outer ring).
	]]
	Utils.Do(TeamInfo, function(ti)
		local cells = {}

		local spawnBy = {
			ti.ConstructionYard, ti.Refinery, ti.Barracks, ti.WarFactory, ti.Helipad, ti.Radar, ti.Powerplant, ti.ServiceDepot
		}

		Utils.Do(spawnBy, function(building)
			local loc = building.Location + CVec.New(1, 1)
			local expandedOnce = Utils.ExpandFootprint({loc}, true)
			local expandedTwice = Utils.ExpandFootprint(expandedOnce, true)
			local annulus = GetCPosAnnulus(expandedOnce, expandedTwice)

			Utils.Do(annulus, function(cell)
				cells[#cells+1] = cell
			end)

		end)

		ti.SpawnLocations = cells
	end)
end

SetVictoryConditions = function()
	Utils.Do(PlayerInfo, function(pi)
		local objectiveId = pi.Player.AddPrimaryObjective('Destroy the enemy base!')
		pi.VictoryMissionObjectiveId = objectiveId
	end)
end

AddPurchaseTerminals = function()
	Utils.Do(PlayerInfo, function(pi)
		-- Hacky, but create all purchase terminals at 0,0.
		-- The side effect is a unit nudging if a purchase is made while standing on it.
		Actor.Create(PurchaseTerminalActorType, true, { Owner = pi.Player, Location = CPos.New(0, 0) })
	end)
end

BindPurchaseTerminals = function()
	Utils.Do(Map.ActorsInWorld, function(actor)
		if actor.Type == PurchaseTerminalActorType then
			local pt = actor
			local pi = PlayerInfo[pt.Owner.InternalName]

			pi.PurchaseTerminal = pt

			-- NOTE: Team conditions should match the faction name.
			pt.GrantCondition(pi.Player.Faction)

			pi.RadarConditionToken = pt.GrantCondition("radar")
			pi.InfantryConditionToken = pt.GrantCondition("infantry")
			pi.VehicleConditionToken = pt.GrantCondition("vehicle")
			pi.AircraftConditionToken = pt.GrantCondition("aircraft")

			Trigger.OnProduction(pt, function(producer, produced)
				BuildPurchaseTerminalItem(pi, produced.Type)
			end)
		end
	end)
end

BindBaseEvents = function()
	Utils.Do(TeamInfo, function(ti)
		-- Construction Yard
		Trigger.OnKilled(ti.ConstructionYard, function(self, killer)
			CreateBuildingHusk(self)
			NotifyBuildingDestroyed(self, killer)
			GrantRewardOnKilled(self, killer, "building")

			local baseBuildings = {
				ti.Refinery, ti.Barracks, ti.WarFactory, ti.Helipad, ti.Radar, ti.Powerplant, ti.ServiceDepot
			}
			Utils.Do(baseBuildings, function(building)
				if not building.IsDead then building.StopBuildingRepairs() end
			end)
			Utils.Do(ti.Defenses, function(building)
				if not building.IsDead then building.StopBuildingRepairs() end
			end)
		end)
		Trigger.OnDamaged(ti.ConstructionYard, function(self, attacker)
			if not self.IsDead then
				self.StartBuildingRepairs()
			end
			NotifyBaseUnderAttack(self)
			GrantRewardOnDamaged(self, attacker)
		end)

		-- Refinery
		Trigger.OnKilled(ti.Refinery, function(self, killer)
			CreateBuildingHusk(self)
			NotifyBuildingDestroyed(self, killer)
			GrantRewardOnKilled(self, killer, "building")

			if not ti.AiHarvester.IsDead then
				ti.AiHarvester.Kill()
			end
		end)
		Trigger.OnDamaged(ti.Refinery, function(self, attacker)
			if not self.IsDead and not ti.ConstructionYard.IsDead then
				self.StartBuildingRepairs()
			end
			NotifyBaseUnderAttack(self)
			GrantRewardOnDamaged(self, attacker)
		end)

		-- Barracks
		Trigger.OnKilled(ti.Barracks, function(self, killer)
			CreateBuildingHusk(self)
			NotifyBuildingDestroyed(self, killer)
			GrantRewardOnKilled(self, killer, "building")

			Utils.Do(ti.Players, function(pi)
				pi.PurchaseTerminal.RevokeCondition(pi.InfantryConditionToken)
				pi.PurchaseTerminal.GrantCondition('infantry-penalty') -- Don't ever need to revoke it.
			end)
		end)
		Trigger.OnDamaged(ti.Barracks, function(self, attacker)
			if not self.IsDead and not ti.ConstructionYard.IsDead then
				self.StartBuildingRepairs()
			end
			NotifyBaseUnderAttack(self)
			GrantRewardOnDamaged(self, attacker)
		end)

		-- War Factory
		Trigger.OnKilled(ti.WarFactory, function(self, killer)
			CreateBuildingHusk(self)
			NotifyBuildingDestroyed(self, killer)
			GrantRewardOnKilled(self, killer, "building")

			Utils.Do(ti.Players, function(pi)
				pi.PurchaseTerminal.RevokeCondition(pi.VehicleConditionToken)
				pi.PurchaseTerminal.GrantCondition('vehicle-penalty') -- Don't ever need to revoke it.
			end)
		end)
		Trigger.OnDamaged(ti.WarFactory, function(self, attacker)
			if not self.IsDead and not ti.ConstructionYard.IsDead then
				self.StartBuildingRepairs()
			end
			NotifyBaseUnderAttack(self)
			GrantRewardOnDamaged(self, attacker)
		end)

		-- Helipad
		Trigger.OnKilled(ti.Helipad, function(self, killer)
			CreateBuildingHusk(self)
			NotifyBuildingDestroyed(self, killer)
			GrantRewardOnKilled(self, killer, "building")

			Utils.Do(ti.Players, function(pi)
				pi.PurchaseTerminal.RevokeCondition(pi.AircraftConditionToken)
				pi.PurchaseTerminal.GrantCondition('aircraft-penalty') -- Don't ever need to revoke it.
			end)
		end)
		Trigger.OnDamaged(ti.Helipad, function(self, attacker)
			if not self.IsDead and not ti.ConstructionYard.IsDead then
				self.StartBuildingRepairs()
			end
			NotifyBaseUnderAttack(self)
			GrantRewardOnDamaged(self, attacker)
		end)

		-- Radar
		Trigger.OnKilled(ti.Radar, function(self, killer)
			CreateBuildingHusk(self)
			NotifyBuildingDestroyed(self, killer)
			GrantRewardOnKilled(self, killer, "building")

			Utils.Do(ti.Players, function(pi)
				pi.PurchaseTerminal.RevokeCondition(pi.RadarConditionToken)
			end)
		end)
		Trigger.OnDamaged(ti.Radar, function(self, attacker)
			if not self.IsDead and not ti.ConstructionYard.IsDead then
				self.StartBuildingRepairs()
			end
			NotifyBaseUnderAttack(self)
			GrantRewardOnDamaged(self, attacker)
		end)

		-- Powerplant
		Trigger.OnKilled(ti.Powerplant, function(self, killer)
			CreateBuildingHusk(self)
			NotifyBuildingDestroyed(self, killer)
			GrantRewardOnKilled(self, killer, "building")

			if not ti.Radar.IsDead then
				Utils.Do(ti.Players, function(pi)
					pi.PurchaseTerminal.RevokeCondition(pi.RadarConditionToken)
				end)
			end
		end)
		Trigger.OnDamaged(ti.Powerplant, function(self, attacker)
			if not self.IsDead and not ti.ConstructionYard.IsDead then
				self.StartBuildingRepairs()
			end
			NotifyBaseUnderAttack(self)
			GrantRewardOnDamaged(self, attacker)
		end)

		-- Service Depot
		Trigger.OnKilled(ti.ServiceDepot, function(self, killer)
			CreateBuildingHusk(self)
			NotifyBuildingDestroyed(self, killer)
			GrantRewardOnKilled(self, killer, "building")
		end)
		Trigger.OnDamaged(ti.ServiceDepot, function(self, attacker)
			if not self.IsDead and not ti.ConstructionYard.IsDead then
				self.StartBuildingRepairs()
			end
			NotifyBaseUnderAttack(self)
			GrantRewardOnDamaged(self, attacker)
		end)

		-- Defenses
		Utils.Do(ti.Defenses, function(building)
			Trigger.OnKilled(building, function(self, killer)
				CreateBuildingHusk(self)
				NotifyBuildingDestroyed(self, killer)
				GrantRewardOnKilled(self, killer, "defense")
			end)
			Trigger.OnDamaged(building, function(self, attacker)
				if not self.IsDead and not ti.ConstructionYard.IsDead then
					self.StartBuildingRepairs()
				end
				NotifyBaseUnderAttack(self)
				GrantRewardOnDamaged(self, attacker)
			end)
		end)

	end)
end

CreateBuildingHusk = function(building)
	local huskName = building.Type .. BuildingHuskSuffix
	local husk = Actor.Create(huskName, true, { Owner = building.Owner, Location = building.Location })
	local ti = TeamInfo[building.Owner.InternalName]
	BindBuildingProximityEvent(ti, husk)
end

NotifyBuildingDestroyed = function(self, killer)
	DisplayMessage(self.Owner.Name .. " " .. self.TooltipName .. " was destroyed by " .. GetDisplayNameForActor(killer) .. "!")
end

NotifyBaseUnderAttack = function(self)
	local actorId = tostring(self) -- returns e.g. "Actor (e1 53)", where the last # is unique.
	local previousHealth = HealthAfterOnDamageEventTable[actorId]
	if previousHealth ~= nil and previousHealth < self.Health then
		return -- Was healed.
	end

	local ti = TeamInfo[self.Owner.InternalName]
	if ti.TicksSinceLastBuildingDamage >= NotifyBaseUnderAttackInterval then
		-- Only display a message and play audio to that team (radar pings are handled by engine)
		Utils.Do(ti.Players, function(pi)
			if pi.Player.IsLocalPlayer then
				DisplayMessage(self.Owner.Name .. " " .. self.TooltipName .. " is under attack!")
				Media.PlaySound(SoundBaseUnderAttack)
			end
		end)
	end

	ti.TicksSinceLastBuildingDamage = 0
end

NotifyHarvesterUnderAttack = function(self)
	local actorId = tostring(self) -- returns e.g. "Actor (e1 53)", where the last # is unique.
	local previousHealth = HealthAfterOnDamageEventTable[actorId]
	if previousHealth ~= nil and previousHealth < self.Health then
		return -- Was healed.
	end

	local ti = TeamInfo[self.Owner.InternalName]
	if ti.TicksSinceLastHarvesterDamage >= NotifyHarvesterUnderAttackInterval then
		-- Only display a message and radar ping to that team
		Utils.Do(ti.Players, function(pi)
			if pi.Player.IsLocalPlayer then
				DisplayMessage(self.Owner.Name .. " Harvester is under attack!")
				Radar.Ping(pi.Player, self.CenterPosition, HSLColor.Red, DateTime.Seconds(5))
			end
		end)
	end

	ti.TicksSinceLastHarvesterDamage = 0
end

SpawnHero = function(player)
	local pi = PlayerInfo[player.InternalName]

	if GameOver or pi.Surrendered then return end

	local spawnpoint = GetAvailableSpawnPoint(pi)
	local hero = Actor.Create(SpawnAsActorType, true, { Owner = player, Location = spawnpoint })

	pi.Hero = hero

	-- Revoke any inventory tokens
	if pi.HasBeaconConditionToken > -1 then
		hero.RevokeCondition(pi.HasBeaconConditionToken)
		pi.HasBeaconConditionToken = -1
	end

    FocusLocalCameraOnActor(hero)
	BindHeroEvents(hero)
	InitializeIfBot(pi)
end

GetAvailableSpawnPoint = function(pi)
	-- Currently doesn't check for occupancy, but doesn't matter much.
	local spawnLocations = pi.Team.SpawnLocations
	return Utils.Random(spawnLocations)
end

FocusLocalCameraOnActor = function(actor)
	if actor.Owner.IsLocalPlayer then
		Camera.Position = actor.CenterPosition
	end
end

BindHeroEvents = function(hero)
	Trigger.OnKilled(hero, function(self, killer)
		if self.Owner.InternalName == killer.Owner.InternalName then
			DisplayMessage(GetDisplayNameForActor(self) .. " killed themselves!")
		else
			DisplayMessage(GetDisplayNameForActor(killer) .. " killed " .. GetDisplayNameForActor(self) .. "!")
		end

		GrantRewardOnKilled(self, killer, "hero")

		-- Increment K/D
		local selfPi = PlayerInfo[self.Owner.InternalName]
		local killerPi = PlayerInfo[killer.Owner.InternalName]

		if selfPi ~= nil then
			selfPi.Deaths = selfPi.Deaths + 1
		end
		if killerPi ~= nil then
			killerPi.Kills = killerPi.Kills + 1
		end

		Trigger.AfterDelay(RespawnTime, function() SpawnHero(self.Owner) end)
	end)

	Trigger.OnDamaged(hero, function(self, attacker)
		GrantRewardOnDamaged(self, attacker)
	end)

	-- Beacons
	Trigger.OnProduction(hero, function(producer, produced)
		local pi = PlayerInfo[hero.Owner.InternalName]
		BuildHeroItem(pi, produced.Type)
	end)
end

BindVehicleEvents = function()
	Utils.Do(TeamInfo, function(ti)
		Trigger.OnProduction(ti.WarFactory, function(producer, produced)
			BindProducedVehicleEvents(produced)
		end)
		Trigger.OnProduction(ti.Helipad, function(producer, produced)
			BindProducedVehicleEvents(produced)
		end)
	end)
end

BindProducedVehicleEvents = function(produced)
	-- New vehicles are granted a 'brandnew' condition so they are mobile.
	local brandnewToken = produced.GrantCondition('brandnew')

	-- Revoke the brandew token 3 seconds later, this will be enough time for them to move to rallypoint.
	Trigger.AfterDelay(DateTime.Seconds(3), function()
		if produced.IsInWorld then
			produced.RevokeCondition(brandnewToken)
		end
	end)

	-- Damage/killed events
	Trigger.OnDamaged(produced, function(self, attacker)
		GrantRewardOnDamaged(self, attacker)
	end)
	Trigger.OnKilled(produced, function(self, killer)
		GrantRewardOnKilled(self, killer, "unit")
	end)

	-- New vehicles belong to appropriate team's Neutral (except AI harvesters...)
	if produced.Type ~= AiHarvesterActorType then
		produced.Owner = NeutralPlayer
	else
		local wasPurchased = true
		InitializeAiHarvester(produced, wasPurchased)
	end

	-- Ownership bindings
	Trigger.OnPassengerEntered(produced, function(transport, passenger)
		-- If someone enters a vehicle with no passengers, they're the owner.
		if transport.PassengerCount == 1 then
			transport.Owner = passenger.Owner
		end
		local pi = PlayerInfo[passenger.Owner.InternalName]

		-- Set passenger state
		pi.PassengerOfVehicle = transport

		-- Name tag hack: Setting the driver to display the proper pilot name.
		if transport.PassengerCount == 1 then
			pi.IsPilot = true
		end
	end)

	-- If it's empty and alive, transfer ownership back to neutral.
	-- Husks (if any) retain ownership, and don't want husk explosions to hurt allies.
	Trigger.OnPassengerExited(produced, function(transport, passenger)
		if not transport.IsDead and transport.PassengerCount == 0 then
			transport.Owner = NeutralPlayer
		end

		local pi = PlayerInfo[passenger.Owner.InternalName]

		-- Set passenger state
		pi.PassengerOfVehicle = nil

		-- Name tag hack: Remove pilot info.
		pi.IsPilot = false
	end)
end

BindProximityEvents = function()
	Utils.Do(TeamInfo, function(ti)

		local proximityEnabledBuildings = {
			ti.ConstructionYard,
			ti.Refinery,
			ti.Barracks,
			ti.WarFactory,
			ti.Helipad,
			ti.Radar,
			ti.Powerplant,
			ti.ServiceDepot
		}

		Utils.Do(proximityEnabledBuildings, function(building)
			BindBuildingProximityEvent(ti, building)
		end)
	end)
end

BindBuildingProximityEvent = function(ti, building)
	-- Fun fact: We declare the exited trigger first, so it always fires first
	-- Spawning a new infantry unit will cause the first one to exit, and the new one to enter
	-- thus the order of token removal/addition is proper

	Trigger.OnExitedProximityTrigger(building.CenterPosition, WDist.FromCells(3), function(actor)
		-- HACK: Beacons may also trip this.
		-- Need to stop assuming that the actor is a hero, etc.
		if actor.Type == AlphaBeaconType or actor.Type == BetaBeaconType then
			return
		end

		if actor.IsDead then
			return
		end

		local pi = PlayerInfo[actor.Owner.InternalName]
		if pi ~= nil then -- A human player
			if pi.Player.Faction == ti.AiPlayer.Faction then -- On same team
				local tokenToRevoke = pi.ProximityEventTokens[building.Type]

				if tokenToRevoke ~= nil then
					pi.Hero.RevokeCondition(tokenToRevoke)
					pi.ProximityEventTokens[building.Type] = -1
				end
			end
		end
	end)

	Trigger.OnEnteredProximityTrigger(building.CenterPosition, WDist.FromCells(3), function(actor)
		-- HACK: Beacons may also trip this.
		-- Need to stop assuming that the actor is a hero, etc.
		if actor.Type == AlphaBeaconType or actor.Type == BetaBeaconType then
			return
		end

		if building.IsDead then -- Building trips its own exit, ignore
			return
		end

		local pi = PlayerInfo[actor.Owner.InternalName]
		if pi ~= nil and pi.PassengerOfVehicle == nil then -- A human player + not in vehicle
			if pi.Player.Faction == ti.AiPlayer.Faction then -- On same team
				pi.ProximityEventTokens[building.Type] = pi.Hero.GrantCondition("canbuy") -- e.g. table['fact'] = token
			end
		end

	end)
end

InitializeAiHarvesters = function()
	-- Order all starting harvesters to find resources
	Utils.Do(Map.ActorsInWorld, function (actor)
		-- Hack: cache waypoint location to move harvester to
		if actor.Type == 'waypoint' then HarvesterWaypoints[actor.Owner.Faction] = actor.Location end

		if actor.Type == AiHarvesterActorType and PlayerIsTeamAi(actor.Owner) then
			local wasPurchased = false
			InitializeAiHarvester(actor, wasPurchased)
		end
	end)
end

InitializeAiHarvester = function(harv, wasPurchased)
	local ti = TeamInfo[harv.Owner.InternalName]
	ti.AiHarvester = harv

	local waypointLocation = HarvesterWaypoints[harv.Owner.Faction]
	harv.Move(waypointLocation, 3)
	harv.FindResources()

	Trigger.OnDamaged(harv, function(self, attacker)
		NotifyHarvesterUnderAttack(self)
		if not wasPurchased then
			GrantRewardOnDamaged(self, attacker)
		end
	end)

	Trigger.OnKilled(harv, function(self, killer)
		if not wasPurchased then
			GrantRewardOnKilled(self, killer, "unit")
		end

		if not ti.WarFactory.IsDead and not ti.Refinery.IsDead then
			ti.WarFactory.Produce(AiHarvesterActorType)
		end
	end)
end

BuildPurchaseTerminalItem = function(pi, actorType)
	local hero = pi.Hero;
	local type = GetPurchasedActorType(actorType)

	-- Disable purchases for a bit to prevent accidental purchases.
	local cooldownToken = pi.PurchaseTerminal.GrantCondition("purchase-terminal-cooldown")
	Trigger.AfterDelay(10, function() pi.PurchaseTerminal.RevokeCondition(cooldownToken) end)

	if string.find(actorType, PurchaseTerminalInfantryActorTypePrefix) then
		-- We don't init the health because it's percentage based.
		local newHero = Actor.Create(type, false, { Owner = pi.Player, Location = hero.Location })

		-- If a unit has full HP, keep it full HP when they buy a new one
		local fullyHealed = hero.Health == hero.MaxHealth
		if not fullyHealed then
			newHero.Health = hero.Health
		end

		newHero.IsInWorld = true

		pi.Hero = newHero

		-- HACK: Add their current health to damage table
		local actorId = tostring(newHero)
		HealthAfterOnDamageEventTable[actorId] = newHero.Health

		-- Carry over any inventory tokens
		if pi.HasBeaconConditionToken > -1 then
			pi.HasBeaconConditionToken = newHero.GrantCondition("hasbeacon")
		end

		-- Doesn't look that great if moving.
		hero.Stop()
		hero.IsInWorld = false
		hero.Destroy()

		BindHeroEvents(newHero)
	elseif string.find(actorType, PurchaseTerminalVehicleActorTypePrefix) then
		local ti = pi.Team
		if not ti.WarFactory.IsDead then
			ti.WarFactory.Produce(type)
		else
			-- Actors will be reinforced by transport helicopter from the top of the map,
			-- relative to where their war factory was.
			-- We exit out the other end not to cause traffic jams!
			-- This will need un-hardcoding if the map is not symmetrical.
			-- And looks hilariously glitchy on map borders.
			local enterFrom = CPos.New(ti.WarFactoryActorLocation.X + 1, 0) -- Location offset +1, to get the "center"
			local dropOffAt = ti.WarFactoryActorLocation + CVec.New(1, 1) -- Offset again
			local exitAt = CPos.New(enterFrom.X, 999)

			local produced = Reinforcements.ReinforceWithTransport(
				NeutralPlayer,				-- Neutral owner
				"tran-ai",					-- Transport type
				{ type },					-- Actor(s) in transport
				{ enterFrom, dropOffAt },	-- Entry path
				{ exitAt }					-- Exit path
			)[2][1]

			BindProducedVehicleEvents(produced)
		end
	elseif string.find(actorType, PurchaseTerminalAircraftActorTypePrefix) then
		local ti = pi.Team
		if not ti.Helipad.IsDead then
			ti.Helipad.Produce(type)
		else
			-- TODO: Need to fly it in from off-map.
			local produced = Actor.Create(type, true, { Owner = NeutralPlayer, Location = ti.HelipadActorLocation })
			BindProducedVehicleEvents(produced)
		end
	elseif string.find(actorType, PurchaseTerminalBeaconActorTypePrefix) then
		pi.HasBeaconConditionToken = hero.GrantCondition("hasbeacon")
	end
end

BuildHeroItem = function(pi, actorType)
	local type = GetPurchasedActorType(actorType)

	if string.find(actorType, HeroItemPlaceBeaconActorTypePrefix) then
		-- Create beacon at current location (hero gets nudged)
		local beacon = Actor.Create(type, true, { Owner = pi.Player, Location = pi.Hero.Location })
		local beaconToken = beacon.GrantCondition('activebeacon', BeaconTimeLimit)

		DisplayMessage(beacon.TooltipName .. ' deployed!')

		-- Remove beacon ownership
		pi.Hero.RevokeCondition(pi.HasBeaconConditionToken)
		pi.HasBeaconConditionToken = -1

		-- Notify all players
		Media.PlaySound(BeaconDeploySound)
		Trigger.AfterDelay(DateTime.Seconds(2), function() Media.PlaySound(BeaconSoundsTable[beacon.Type]) end)

		Utils.Do(TeamInfo, function(ti)
			Utils.Do(ti.Players, function(pi)
				local pingColor = HSLColor.Red

				if pi.Player.Faction == beacon.Owner.Faction then
					pingColor = HSLColor.Green
				end

				-- Pings may linger after beacon is destroyed.
				Radar.Ping(pi.Player, beacon.CenterPosition, pingColor, BeaconTimeLimit)
			end)
		end)

		Trigger.OnDamaged(beacon, function(actor, attacker)
			if actor.Health == 0 and actor.Type ~= attacker.Type then
				-- If the beacon has no health left, disable the activebeacon condition so it doesn't explode.
				beacon.RevokeCondition(beaconToken)
			end

			GrantRewardOnDamaged(actor, attacker);
		end)

		Trigger.OnKilled(beacon, function(actor, killer)
			if actor.Type ~= killer.Type then
				GrantRewardOnKilled(actor, killer, "beacon");
				DisplayMessage(beacon.TooltipName .. ' was disarmed by ' .. GetDisplayNameForActor(killer) .. '!')
			end
		end)

		-- Flash the beacon at intervals
		local flashTicks = GetBeaconFlashTicks()
		for i,v in pairs(flashTicks) do
			Trigger.AfterDelay(v, function() if beacon.IsInWorld then beacon.Flash(2, pi.Player) end end)
		end

		-- Set up warhead
		Trigger.AfterDelay(BeaconTimeLimit, function()
			if beacon.IsInWorld then
				-- Add a camera for the impact, and remove after.
				local camera = Actor.Create(BeaconHitCamera, true,  { Owner = pi.Player, Location = beacon.Location })
				Trigger.AfterDelay(DateTime.Seconds(2), function() camera.Destroy() end)

				-- Calling .Kill() to force their explosion.
				-- (A beacon should technically have a projectile come first.)
				beacon.Kill()
			end
		end)
	end
end

GetBeaconFlashTicks = function()
	-- Performs a gradual decrease, counting backwards from the beacon ticks.
	local ticks = { }

	local baseTickReduction = 5
	local intervalSteps = 4

	local tick = BeaconTimeLimit
	local tickReduction = baseTickReduction

	while tick > 0 do
		local step = 1
		while step <= intervalSteps do
			tick = tick - tickReduction
			if tick > 0 then ticks[#ticks+1] = tick end
			step = step + 1
		end
		tickReduction = tickReduction + baseTickReduction
	end

	return ticks
end

GrantRewardOnDamaged = function(self, attacker)
	--[[
		This is a fun state machine that calculates damage done.
		It can be completely removed if Lua exposes that information.

		We create a table of actor IDs.
		This table stores health of all actors in the world, and changes after the OnDamage event.
	]]
	local actorId = tostring(self) -- returns e.g. "Actor (e1 53)", where the last # is unique.
	local previousHealth = HealthAfterOnDamageEventTable[actorId]

	if previousHealth == nil then
		-- If an actor isn't in the damage table, they haven't taken damage yet
		-- (or they were purchased, in which case we set their current hp there)
		-- Assume previous health was max HP.
		previousHealth = self.MaxHealth
	end

	local currentHealth = self.Health
	HealthAfterOnDamageEventTable[actorId] = currentHealth

	local damageTaken = previousHealth - currentHealth

	if damageTaken == 0 then -- No damage taken (can happen)
		return
	elseif ActorIsNeutral(self) then -- Ignore attacking neutral units.
		return
	elseif damageTaken > 0 and self.Owner.Faction == attacker.Owner.Faction then -- Ignore self/team when damage is greater than 0.
		return
	elseif self.Owner.InternalName == attacker.Owner.InternalName then -- Ignore self heal/damage in all cases.
		return
	end

	local attackerpi = PlayerInfo[attacker.Owner.InternalName]
	if attackerpi ~= nil then -- Is a player
		--[[
			Points are calculated as a percentage of damage done against an actor's max HP.
			If an actor has 5000 health, and the attack dealt 1500 damage, this is 30%.

			If damage or healing dealt was less than 1%, they are given one point.
			If damage > 1%, the percentage is doubled then floored (e.g. 2.3% -> 4.6% -> 4 points).
			If healing > 1%, the percentage is floored (e.g. 2.3% -> 2 points).

			An MLRS and Artillery destroying a structure will end up with identical points.
		]]

		-- If the damage dealt was negative, this is a heal
		local wasHeal = damageTaken < 0
		damageTaken = math.abs(damageTaken)

		local percentageDamageDealt = (damageTaken / self.MaxHealth) * 100

		local points = 0

		if percentageDamageDealt < 1 then
			points = 1
		else
			points = percentageDamageDealt

			if not wasHeal then
				points = points * 2
			end

			points = math.floor(points + 0.5)
		end

		attackerpi.Player.Experience = attackerpi.Player.Experience + points
		attackerpi.Player.Cash = attackerpi.Player.Cash + points
	end
end

GrantRewardOnKilled = function(self, killer, actorCategory)
	if ActorIsNeutral(self) then -- Ignore destroying neutral units.
		return
	end
	if self.Owner.Faction == killer.Owner.Faction then -- Ignore self/team.
		return
	end

	local killerpi = PlayerInfo[killer.Owner.InternalName]
	if killerpi ~= nil then -- Is a player
		local points = 0
		if actorCategory == "hero" then	points = 100
		elseif actorCategory == "unit" then points = 100
		elseif actorCategory == "defense" then points = 200
		elseif actorCategory == "building" then	points = 300
		elseif actorCategory == "beacon" then points = 300
		end

		killerpi.Player.Experience = killerpi.Player.Experience + points
		killerpi.Player.Cash = killerpi.Player.Cash + points
	end
end

--[[ Ticking ]]
IncrementPlayerCash = function()
	Utils.Do(TeamInfo, function(ti)
		Utils.Do(ti.Players, function(pi)
			local cash = CashPerSecond

			if ti.Refinery.IsDead then
				cash = CashPerSecondPenalized
			end

			pi.Player.Cash = pi.Player.Cash + cash
		end)
	end)

	Trigger.AfterDelay(25, IncrementPlayerCash)
end

DistributeGatheredResources = function()
	-- This distributes resources gathered by AI Harvesters or other players.
	Utils.Do(TeamInfo, function(ti)
		if not ti.Refinery.IsDead and ti.LastCheckedResourceAmount ~= ti.AiPlayer.Resources then
			local addedCash = ti.AiPlayer.Resources - ti.LastCheckedResourceAmount
			-- HACK: In the rules we try to get a free repair cost.
			-- But it seems possible that it can still cost the AI a credit.
			-- Thus if the AI lost $, the players did. Don't pass that onto the players.
			if addedCash > 0 then
				Utils.Do(ti.Players, function(pi)
					pi.Player.Cash = pi.Player.Cash + addedCash
				end)
			end

			ti.LastCheckedResourceAmount = ti.AiPlayer.Resources
		end
	end)

	Trigger.AfterDelay(5, DistributeGatheredResources)
end

CheckVictoryConditions = function()
	-- Check for surrendered players
	-- We can't use objective triggers since they fire for only local players,
	-- which means modifying game state == out of sync
	-- TODO: If all players have surrendered on a team, we need to force that team a loss.
	if not GameOver then
		Utils.Do(PlayerInfo, function(pi)
			if not pi.Surrendered and pi.Player.IsObjectiveFailed(pi.VictoryMissionObjectiveId) then
				-- Destroy any vehicles they're in, then their hero.
				if pi.PassengerOfVehicle ~= nil then
					pi.PassengerOfVehicle.Kill()
				end
				if not pi.Hero.IsDead then
					pi.Hero.Kill()
				end

				pi.Surrendered = true
				DisplayMessage(pi.Player.Name .. ' surrendered!')
			end
		end)
	end

	-- Check for victory
	local tiWinner = nil
	local tiLoser = nil

	if TimeLimitExpired == true then
		-- GDI wins in event of tie.
		if TeamStats[AlphaTeamPlayerName].Experience >= TeamStats[AlphaTeamPlayerName].Experience then
			tiWinner = TeamInfo[AlphaTeamPlayerName]
			tiLoser = TeamInfo[BetaTeamPlayerName]
		else
			tiWinner = TeamInfo[BetaTeamPlayerName]
			tiLoser = TeamInfo[AlphaTeamPlayerName]
		end
	else
		Utils.Do(TeamInfo, function(ti)
			if ti.ConstructionYard.IsDead
				and ti.Refinery.IsDead
				and ti.Barracks.IsDead
				and ti.WarFactory.IsDead
				and ti.Helipad.IsDead
				and ti.Radar.IsDead
				and ti.Powerplant.IsDead
				and ti.ServiceDepot.IsDead
				then

				if ti.AiPlayer.InternalName == AlphaTeamPlayerName then
					tiWinner = TeamInfo[BetaTeamPlayerName]
					tiLoser = TeamInfo[AlphaTeamPlayerName]
				else
					tiWinner = TeamInfo[AlphaTeamPlayerName]
					tiLoser = TeamInfo[BetaTeamPlayerName]
				end
			end
		end)
	end

	if tiLoser ~= nil then
		GameOver = true
		DisplayMessage('Game over! ' .. tiWinner.AiPlayer.InternalName .. ' wins!')

		Utils.Do(tiWinner.Players, function(pi)
			pi.Player.MarkCompletedObjective(pi.VictoryMissionObjectiveId)
			if pi.Player.IsLocalPlayer then
				Media.PlaySound(SoundMissionAccomplished)
			end
		end)

		Utils.Do(tiLoser.Players, function(pi)
			pi.Player.MarkFailedObjective(pi.VictoryMissionObjectiveId)
			if pi.Player.IsLocalPlayer then
				Media.PlaySound(SoundMissionFailed)
			end
		end)
	end

	if not GameOver then
		Trigger.AfterDelay(25, CheckVictoryConditions)
	end
end

BindTimeLimitEvents = function()
	if DateTime.TimeLimit == 0 then
		-- No time limit
		return
	end

	Trigger.AfterDelay(DateTime.TimeLimit, function()
		TimeLimitExpired = true
		DisplayMessage("Time limit expired!")
	end)
end

UpdateTeamStats = function()
	local updatedStats = { }

	Utils.Do(TeamInfo, function(ti)
		updatedStats[ti.AiPlayer.InternalName] = { Experience = 0, Kills = 0, Deaths = 0 }
		local stats = updatedStats[ti.AiPlayer.InternalName]

		Utils.Do(ti.Players, function(pi)
			stats.Experience = stats.Experience + pi.Player.Experience
			stats.Kills = stats.Kills + pi.Kills
			stats.Deaths = stats.Deaths + pi.Deaths
		end)
	end)

	TeamStats = updatedStats

	Trigger.AfterDelay(5, UpdateTeamStats)
end

DrawScoreboard = function()
	local isSpectating = LocalPlayerInfo == nil

	local alpha = AlphaTeamPlayerName .. ': ' .. tostring(TeamStats[AlphaTeamPlayerName].Experience) .. ' points - '
		.. tostring(TeamStats[AlphaTeamPlayerName].Kills) .. '/' .. tostring(TeamStats[AlphaTeamPlayerName].Deaths) .. ' k/d'
	local beta = BetaTeamPlayerName .. ': ' .. tostring(TeamStats[BetaTeamPlayerName].Experience) .. ' points - '
		.. tostring(TeamStats[BetaTeamPlayerName].Kills) .. '/' .. tostring(TeamStats[BetaTeamPlayerName].Deaths) .. ' k/d'

	local scoreboard = '\n' .. '\n' .. '\n' .. '\n'
	if TeamStats[AlphaTeamPlayerName].Experience >= TeamStats[BetaTeamPlayerName].Experience then
		scoreboard = scoreboard .. alpha .. '\n' .. beta
	else
		scoreboard = scoreboard .. beta .. '\n' .. alpha
	end

	if not isSpectating then
		local pi = LocalPlayerInfo
		scoreboard = scoreboard .. '\n'
		.. pi.Player.Name .. ': ' .. tostring(pi.Player.Experience) .. ' points - '
		.. tostring(pi.Kills) .. '/' .. tostring(pi.Deaths) .. ' k/d'
	end

	UserInterface.SetMissionText(scoreboard)

	Trigger.AfterDelay(5, DrawScoreboard)
end

IncrementUnderAttackNotificationTicks = function()
	Utils.Do(TeamInfo, function(ti)
		ti.TicksSinceLastBuildingDamage = ti.TicksSinceLastBuildingDamage + 1
		ti.TicksSinceLastHarvesterDamage = ti.TicksSinceLastHarvesterDamage + 1
	end)
end

HackyDrawNameTags = function()
	--[[
		This is a hack until WithTextDecoration is used.

		Units that can cloak will never show their nametag to enemies,
		since we can't track that state in Lua.
	]]

	local isSpectating = LocalPlayerInfo == nil

	Utils.Do(TeamInfo, function(ti)
		local sameTeam = isSpectating or LocalPlayerInfo.Player.Faction == ti.AiPlayer.Faction

		Utils.Do(ti.Players, function(pi)
			if pi.Hero ~= nil and pi.Hero.IsInWorld then
				-- HACK: Don't show nametags on enemy units with cloak
				local showTag = sameTeam
					or (not sameTeam and not ArrayContains(EnemyNametagsHiddenForTypes, pi.Hero.Type))
					or GameOver

				if showTag then
					local name = GetDisplayNameForActor(pi.Hero)
					name = name:sub(0, 14) -- truncate to 14 chars

					local pos = WPos.New(pi.Hero.CenterPosition.X, pi.Hero.CenterPosition.Y - 1250, 0)
					Media.FloatingText(name, pos, 1, pi.Player.Color)
				end
			end

			if pi.IsPilot then
				-- HACK: Don't show nametags on enemy units with cloak
				local showTag = (sameTeam
					or (not sameTeam and not ArrayContains(EnemyNametagsHiddenForTypes, pi.PassengerOfVehicle.Type))
					or GameOver
					)
					and pi.PassengerOfVehicle.HasProperty('CenterPosition') -- Handle dead/falling aircraft.

				if showTag then
					local extraOffset = Actor.CruiseAltitude(pi.PassengerOfVehicle.Type)
					local pos = WPos.New(pi.PassengerOfVehicle.CenterPosition.X, pi.PassengerOfVehicle.CenterPosition.Y - 1250 - extraOffset, 0)
					local passengerCount = pi.PassengerOfVehicle.PassengerCount
					local name = GetDisplayNameForActor(pi.Hero)
					name = name:sub(0, 14) -- truncate to 14 chars
					if passengerCount > 1 then
						name = name .. " (+" .. passengerCount - 1 .. ")"
					end
					Media.FloatingText(name, pos, 1, pi.Player.Color)
				end
			end
		end)
	end)
end

GetDisplayNameForActor = function(actor)
	-- Support for bot display names.
	local pi = PlayerInfo[actor.Owner.InternalName]
	if pi ~= nil and pi.Player.IsBot then -- nil if neutral, or a team actor.
		return pi.BotState.DisplayName .. " (bot)"
	else
		return actor.Owner.Name
	end
end

--[[ Misc. ]]--
DisplayMessage = function(message)
	Media.DisplayMessage(message, "Console")
end

ArrayContains = function(collection, value)
	for i, v in ipairs(collection) do
		if v == value then
			return true
		end
	end
	return false
end

GetCPosAnnulus = function(baseFootprintCells, expandedFootprintCells)
	-- Used for spawn logic, gets an annulus of two footprints
	local result = {}

	for i, v in ipairs(expandedFootprintCells) do
		if not ArrayContains(baseFootprintCells, v) then
			result[#result+1] = v
		end
	end

	return result
end

PlayerIsTeamAi = function(player)
	return player.InternalName == AlphaTeamPlayerName or player.InternalName == BetaTeamPlayerName
end

PlayerIsHumanOrBot = function(player)
	return player.IsNonCombatant == false and PlayerIsTeamAi(player) == false
end

GetPurchasedActorType = function(actorType)
	-- Returns the last item in a period delimited string.
	-- e.g. 'buy.infantry.e1' returns 'e1'
	local index = string.find(actorType, ".[^.]*$")
	local purchasedType = string.sub(actorType, index + 1)
	return purchasedType
end

ActorIsNeutral = function(actor)
	return actor.Owner.InternalName == NeutralPlayerName
end

-- [[ AI/Bots ]]
--[[
	Lazy/hacky bot logic:
	- On spawn, purchase an anti-infantry or anti-armor unit depending on cash available. Would be better to have an enforced mix.
	- Hunt for things.
]]
InitializeIfBot = function(pi)
	if not pi.Player.IsBot then
		return
	end

	-- Wait a second for a couple reasons:
	-- Looks more natural.
	-- Purchase terminals don't exist on first tick anyways (hacky).
	Trigger.AfterDelay(DateTime.Seconds(1), function()
		if Mod == "cnc" then
			local purchasePool = { "e1", "e2" }
			if pi.Player.Cash >= 250 and pi.Player.Cash < 500 then
				purchasePool = { "e1", "e3" }
			elseif pi.Player.Cash >= 500 then
				purchasePool = { "rmbo", "e3" }
			end
			local toPurchase = Utils.Random(purchasePool)

			if pi.PurchaseTerminal ~= nil then
				pi.PurchaseTerminal.Produce('buy.infantry.' .. toPurchase)
			end

			-- Wait one tick to send the hunt order to the purchased infantry.
			Trigger.AfterDelay(1, function()
				pi.Hero.Hunt()
			end)
		end
	end)
end

-- [[ Tests ]]
DoTests = function()
	local weaponTest = false
	if weaponTest then
		Actor.Create('camera', true, { Owner = AlphaTeamPlayer, Location = CPos.New(22, 23) })
		Actor.Create('camera', true, { Owner = BetaTeamPlayer, Location = CPos.New(25, 23) })
		local a1 = Actor.Create('rmbo', true, { Owner = AlphaTeamPlayer, Location = CPos.New(22, 23) })
		local a2 = Actor.Create('e5', true, { Owner = BetaTeamPlayer, Location = CPos.New(25, 23) })
		--a1.GrantCondition('brandnew')
		--a2.GrantCondition('brandnew')

		Actor.Create('camera', true, { Owner = AlphaTeamPlayer, Location = CPos.New(22, 33) })
		Actor.Create('camera', true, { Owner = BetaTeamPlayer, Location = CPos.New(25, 33) })
		local a3 = Actor.Create('e2', true, { Owner = AlphaTeamPlayer, Location = CPos.New(22, 33) })
		local a4 = Actor.Create('e4', true, { Owner = BetaTeamPlayer, Location = CPos.New(25, 33) })
		--a3.GrantCondition('brandnew')
		--a4.GrantCondition('brandnew')
	end
end
