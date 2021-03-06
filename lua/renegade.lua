--[[
	Renegade 2D: Lua script by @hamb
	Version: 1.1.0
	Engine: OpenRA release-20200504
]]

--[[
	TODO:
		Implement passenger logic with sidebar
		Bleed: OnDamage callback update
		Bleed: Cloak lua API update for nametags
		Bleed: Actor experience API update (can carry it over with EjectOnDeath hack)
		Disabling purchase terminal items should only disable, not hide, items in the list
			- Potentially do the same for being out-of-range from a building, requring 'nearby building'
		Replace chinook drop-offs with production from the destroyed building.
			- Helicopters and planes may want to spawn adjacent to the building.
		Refactor nametag drawing
		Add support for not all buildings being present
		Add support for locked vehicles
]]

--[[ Variables set by build script ]]
Mod = "{BUILD_MOD}"

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
BeaconTimeLimit = DateTime.Seconds(30)
RespawnTime = DateTime.Seconds(3)
LightSources = { } -- Used for beacon light adjustments.
LocalPlayerInfo = nil -- HACK: Used for nametags & scoreboard.
EnemyNametagsHiddenForTypes = { "stnk" } -- HACK: Used for nametags.
GameOver = false
TimeLimitExpired = false
BotNames = {
	"Plorp", "Gorbel", "Splunch", "Borch", "Big Jeff", "Spurtle", "Gurgis", "Brumpus", "Yurst", "Ol Ginch",
	"Gurch", "Plape", "Sporf", "Kranch", "Splinch", "Gorpo", "Forpel", "Gromph", "Dorbie", "Jorf", "Splurst",
	"Shorp", "Bortles", "Bubson", "Plench", "Clorch", "Borth", "Bobson", "Munton", "Plungus", "Brungus", "Dorgel",
	"Blurp", "Paunch", "Biggs", "Wedge", "Arp 299", "Gorgo", "Sqlurp", "Farfel"
}

--[[ Mod-specific ]]
if Mod == "cnc" then
	SpawnAsActorType = "e1"
	AlphaTeamPlayerName = "GDI"
	BravoTeamPlayerName = "Nod"
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
	BravoBeaconType = "nuke-beacon"
	AlphaBeaconLightType = "Blue"
	BravoBeaconLightType = "Red"
	AlphaBeaconLightIntensity = 1
	BravoBeaconLightIntensity = 0.5
	BeaconDeploySound = "target3.aud"
	BeaconHitCamera = "camera.beacon"
	BeaconSoundsTable['ion-beacon'] = 'ionchrg1.aud'
	BeaconSoundsTable['nuke-beacon'] = 'nuke1.aud'
	RespawnCamera = "camera.respawn"
	HackEjectOnDeathExcludeTypes = {"tran","orca","heli"}
elseif Mod == "ra" then
	SpawnAsActorType = "e1"
	AlphaTeamPlayerName = "Allies"
	BravoTeamPlayerName = "Soviet"
	NeutralPlayerName = "Neutral"
	ConstructionYardActorTypes = {"fact"}
	RefineryActorTypes = {"proc"}
	PowerplantActorTypes = {"apwr"}
	RadarActorTypes = {"dome"}
	WarFactoryActorTypes = {"weap"}
	BarracksActorTypes = {"barr","tent"}
	HelipadActorTypes = {"hpad","afld"}
	ServiceDepotActorTypes = {"fix"}
	DefenseActorTypes = {"pbox","hbox","gun","ftur","tsla"}
	AiHarvesterActorType = "harv-ai"
	PlayerHarvesterActorType = "harv"
	SoundMissionStarted = "radaron2.aud"
	SoundBaseUnderAttack = "baseatk1.aud"
	SoundMissionAccomplished = "misnwon1.aud"
	SoundMissionFailed = "misnlst1.aud"
	AlphaBeaconType = "nuke-beacon"
	BravoBeaconType = "nuke-beacon"
	AlphaBeaconLightType = "Red"
	BravoBeaconLightType = "Red"
	AlphaBeaconLightIntensity = 0.5
	BravoBeaconLightIntensity = 0.5
	BeaconDeploySound = "bleep9.aud"
	BeaconHitCamera = "camera.paradrop"
	BeaconSoundsTable['nuke-beacon'] = 'aprep1.aud'
	RespawnCamera = "camera.respawn"
	HackEjectOnDeathExcludeTypes = {"tran","heli","hind"}
end
AlphaTeamPlayer = Player.GetPlayer(AlphaTeamPlayerName)
BravoTeamPlayer = Player.GetPlayer(BravoTeamPlayerName)
NeutralPlayer = Player.GetPlayer(NeutralPlayerName)

WorldLoaded = function()
	Media.PlaySound(SoundMissionStarted)

	DisplayMessage('Welcome to Renegade 2D (version 1.1.0)!')

	SetPlayerInfo()
	SetTeamInfo()
	SetBotNames()

	AssignTeamBuildings()
	AssignSpawnLocations()

	SetVictoryConditions()

	BindBaseEvents()
	BindVehicleEvents()
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
	SetLighting()
	IncrementUnderAttackNotificationTicks()
	DrawNameTags()
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
			HasBeaconConditionToken = -1, -- Attached to a Hero actor
			VehicleConditionToken = -1, -- Attached to a Purchase Terminal actor
			InfantryConditionToken = -1, -- Attached to a Purchase Terminal actor
			AircraftConditionToken = -1, -- Attached to a Purchase Terminal actor
			RadarConditionToken = -1, -- Attached to a Purchase Terminal actor
			Kills = 0, -- Hero kills
			Deaths = 0, -- Hero deaths
			PassengerOfVehicle = nil, -- Actor of what vehicle they are a passenger of
			EjectOnDeathHealth = 0, -- HACK: Storing health when entering a vehicle, since Cargo.EjectOnDeath is busted and we do it ourselves.
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
		local humansOnTeam = 0
		for k, v in pairs(PlayerInfo) do
			if v.Player.Faction == team.Faction then
				playersOnTeam[v.Player.InternalName] = v

				if not v.Player.IsBot then
					humansOnTeam = humansOnTeam + 1
				end
			end
		end

		if humansOnTeam == 0 then humansOnTeam = -1 end -- So bots don't trip team surrender checks

		-- HACK: Give the AI team a ton of cash for repair costs
		team.Cash = 100000

		TeamInfo[team.InternalName] = {
			AiPlayer = team, -- The "AI" player of the team
			Players = playersOnTeam, -- All other Player actors on this team
			SurrendersRemaining = humansOnTeam, -- A count of how many human players are on the team, for surrender checks
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
	local objectiveText = 'Destroy the enemy base!'
	if DateTime.TimeLimit > 0 then
		objectiveText = 'Destroy the enemy base, or most team points after time limit!'
	end

	DisplayMessage('Objective - ' .. objectiveText)

	Utils.Do(PlayerInfo, function(pi)
		local objectiveId = pi.Player.AddObjective(objectiveText)
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
			GrantRewardOnKilled(self, killer)

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
			local damageTaken = GetDamageTaken(self)
			RepairBuilding(self, ti.ConstructionYard, damageTaken)
			NotifyBaseUnderAttack(self, damageTaken)
			GrantRewardOnDamaged(self, attacker, damageTaken, "building")
		end)

		-- Refinery
		Trigger.OnKilled(ti.Refinery, function(self, killer)
			CreateBuildingHusk(self)
			NotifyBuildingDestroyed(self, killer)
			GrantRewardOnKilled(self, killer)

			if not ti.AiHarvester.IsDead then
				ti.AiHarvester.Kill()
			end
		end)
		Trigger.OnDamaged(ti.Refinery, function(self, attacker)
			local damageTaken = GetDamageTaken(self)
			RepairBuilding(self, ti.ConstructionYard, damageTaken)
			NotifyBaseUnderAttack(self, damageTaken)
			GrantRewardOnDamaged(self, attacker, damageTaken, "building")
		end)

		-- Barracks
		Trigger.OnKilled(ti.Barracks, function(self, killer)
			CreateBuildingHusk(self)
			NotifyBuildingDestroyed(self, killer)
			GrantRewardOnKilled(self, killer)

			Utils.Do(ti.Players, function(pi)
				pi.PurchaseTerminal.RevokeCondition(pi.InfantryConditionToken)
				pi.PurchaseTerminal.GrantCondition('infantry-penalty') -- Don't ever need to revoke it.
			end)
		end)
		Trigger.OnDamaged(ti.Barracks, function(self, attacker)
			local damageTaken = GetDamageTaken(self)
			RepairBuilding(self, ti.ConstructionYard, damageTaken)
			NotifyBaseUnderAttack(self, damageTaken)
			GrantRewardOnDamaged(self, attacker, damageTaken, "building")
		end)

		-- War Factory
		Trigger.OnKilled(ti.WarFactory, function(self, killer)
			CreateBuildingHusk(self)
			NotifyBuildingDestroyed(self, killer)
			GrantRewardOnKilled(self, killer)

			Utils.Do(ti.Players, function(pi)
				pi.PurchaseTerminal.RevokeCondition(pi.VehicleConditionToken)
				pi.PurchaseTerminal.GrantCondition('vehicle-penalty') -- Don't ever need to revoke it.
			end)
		end)
		Trigger.OnDamaged(ti.WarFactory, function(self, attacker)
			local damageTaken = GetDamageTaken(self)
			RepairBuilding(self, ti.ConstructionYard, damageTaken)
			NotifyBaseUnderAttack(self, damageTaken)
			GrantRewardOnDamaged(self, attacker, damageTaken, "building")
		end)

		-- Helipad
		Trigger.OnKilled(ti.Helipad, function(self, killer)
			CreateBuildingHusk(self)
			NotifyBuildingDestroyed(self, killer)
			GrantRewardOnKilled(self, killer)

			Utils.Do(ti.Players, function(pi)
				pi.PurchaseTerminal.RevokeCondition(pi.AircraftConditionToken)
				pi.PurchaseTerminal.GrantCondition('aircraft-penalty') -- Don't ever need to revoke it.
			end)
		end)
		Trigger.OnDamaged(ti.Helipad, function(self, attacker)
			local damageTaken = GetDamageTaken(self)
			RepairBuilding(self, ti.ConstructionYard, damageTaken)
			NotifyBaseUnderAttack(self, damageTaken)
			GrantRewardOnDamaged(self, attacker, damageTaken, "building")
		end)

		-- Radar
		Trigger.OnKilled(ti.Radar, function(self, killer)
			CreateBuildingHusk(self)
			NotifyBuildingDestroyed(self, killer)
			GrantRewardOnKilled(self, killer)

			Utils.Do(ti.Players, function(pi)
				pi.PurchaseTerminal.RevokeCondition(pi.RadarConditionToken)
			end)
		end)
		Trigger.OnDamaged(ti.Radar, function(self, attacker)
			local damageTaken = GetDamageTaken(self)
			RepairBuilding(self, ti.ConstructionYard, damageTaken)
			NotifyBaseUnderAttack(self, damageTaken)
			GrantRewardOnDamaged(self, attacker, damageTaken, "building")
		end)

		-- Powerplant
		Trigger.OnKilled(ti.Powerplant, function(self, killer)
			CreateBuildingHusk(self)
			NotifyBuildingDestroyed(self, killer)
			GrantRewardOnKilled(self, killer)

			if not ti.Radar.IsDead then
				Utils.Do(ti.Players, function(pi)
					pi.PurchaseTerminal.RevokeCondition(pi.RadarConditionToken)
				end)
			end
		end)
		Trigger.OnDamaged(ti.Powerplant, function(self, attacker)
			local damageTaken = GetDamageTaken(self)
			RepairBuilding(self, ti.ConstructionYard, damageTaken)
			NotifyBaseUnderAttack(self, damageTaken)
			GrantRewardOnDamaged(self, attacker, damageTaken, "building")
		end)

		-- Service Depot
		Trigger.OnKilled(ti.ServiceDepot, function(self, killer)
			CreateBuildingHusk(self)
			NotifyBuildingDestroyed(self, killer)
			GrantRewardOnKilled(self, killer)
		end)
		Trigger.OnDamaged(ti.ServiceDepot, function(self, attacker)
			local damageTaken = GetDamageTaken(self)
			RepairBuilding(self, ti.ConstructionYard, damageTaken)
			NotifyBaseUnderAttack(self, damageTaken)
			GrantRewardOnDamaged(self, attacker, damageTaken, "building")
		end)

		-- Defenses
		Utils.Do(ti.Defenses, function(building)
			Trigger.OnKilled(building, function(self, killer)
				CreateBuildingHusk(self)
				NotifyBuildingDestroyed(self, killer)
				GrantRewardOnKilled(self, killer)
			end)
			Trigger.OnDamaged(building, function(self, attacker)
				local damageTaken = GetDamageTaken(self)
				RepairBuilding(self, ti.ConstructionYard, damageTaken)
				NotifyBaseUnderAttack(self, damageTaken)
				GrantRewardOnDamaged(self, attacker, damageTaken, "building")
			end)
		end)

	end)
end

CreateBuildingHusk = function(building)
	local huskName = building.Type .. BuildingHuskSuffix
	Actor.Create(huskName, true, { Owner = building.Owner, Location = building.Location })
end

NotifyBuildingDestroyed = function(self, killer)
	DisplayMessage(self.Owner.Name .. " " .. self.TooltipName .. " was destroyed by " .. GetDisplayNameForActor(killer) .. "!")
end

RepairBuilding = function(self, constructionYard, damageTaken)
	if damageTaken > 0 and not self.IsDead and not constructionYard.IsDead then
		self.StartBuildingRepairs()
	end
end

NotifyBaseUnderAttack = function(self, damageTaken)
	if damageTaken <= 0 then
		return -- Was healed or no damage.
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

NotifyHarvesterUnderAttack = function(self, damageTaken)
	if damageTaken <= 0 then
		return -- Was healed or no damage.
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
		-- HACK: EjectOnDeath is currently busted! Handle this logic ourselves.
		-- For polish, see if we can place created actors in subcells (since vehicles can have > 1 passenger)
		local ejectOnDeathHackUsed = false
		local pi = PlayerInfo[self.Owner.InternalName]
		if pi.PassengerOfVehicle ~= nil and not ArrayContains(HackEjectOnDeathExcludeTypes, pi.PassengerOfVehicle.Type) then
			local hero = Actor.Create(self.Type, true, { Owner = pi.Player, Location = pi.PassengerOfVehicle.Location })
			hero.Health = pi.EjectOnDeathHealth
			pi.Hero = hero
			hero.Scatter()

			-- Recursion!
			pi.PassengerOfVehicle = nil
			pi.IsPilot = false
			pi.EjectOnDeathHealth = 0
			BindHeroEvents(hero)

			return
		end
		-- End of EjectOnDeath hack.

		if self.Owner.InternalName == killer.Owner.InternalName then
			DisplayMessage(GetDisplayNameForActor(self) .. " killed themselves!")
		else
			DisplayMessage(GetDisplayNameForActor(killer) .. " killed " .. GetDisplayNameForActor(self) .. "!")
		end

		GrantRewardOnKilled(self, killer)

		-- Remove any vehicle-related information, in case the unit dies before exiting (aircraft do this)
		local selfPi = PlayerInfo[self.Owner.InternalName]
		selfPi.PassengerOfVehicle = nil
		selfPi.IsPilot = false

		-- Increment K/D
		local killerPi = PlayerInfo[killer.Owner.InternalName]

		if selfPi ~= nil then
			selfPi.Deaths = selfPi.Deaths + 1
		end
		if killerPi ~= nil then
			killerPi.Kills = killerPi.Kills + 1
		end

		-- Add a death cam
		local camera = Actor.Create(RespawnCamera, true,  { Owner = self.Owner, Location = self.Location })
		Trigger.AfterDelay(RespawnTime, function() camera.Destroy() end)

		-- Respawn hero
		Trigger.AfterDelay(RespawnTime, function() SpawnHero(self.Owner) end)
	end)

	Trigger.OnDamaged(hero, function(self, attacker)
		local damageTaken = GetDamageTaken(self)
		GrantRewardOnDamaged(self, attacker, damageTaken, "hero")
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
		local damageTaken = GetDamageTaken(self)
		GrantRewardOnDamaged(self, attacker, damageTaken, "unit")

		-- This should live in InitializeAiHarvester, but because of how damage taken is calculated with events
		-- we're forced to calculate it once on a single trigger.
		if produced.Type == AiHarvesterActorType then
			NotifyHarvesterUnderAttack(self, damageTaken)
		end
	end)
	Trigger.OnKilled(produced, function(self, killer)
		GrantRewardOnKilled(self, killer)
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

		-- Eject on death hack: Set the current health value when we need to eject anyone out.
		pi.EjectOnDeathHealth = passenger.Health

		-- Name tag hack: Setting the driver to display the proper pilot name.
		if transport.PassengerCount == 1 then
			pi.IsPilot = true
		end
	end)

	-- If it's empty and alive, transfer ownership back to neutral.
	-- Husks (if any) retain ownership, and don't want husk explosions to hurt allies.
	Trigger.OnPassengerExited(produced, function(transport, passenger)
		if not transport.IsDead and transport.PassengerCount == 0 then
			-- NOTE: With EjectOnDeath being busted, this might not be working as intended.
			transport.Owner = NeutralPlayer
		end

		local pi = PlayerInfo[passenger.Owner.InternalName]

		-- Set passenger state
		pi.PassengerOfVehicle = nil

		-- Name tag hack: Remove pilot info.
		pi.IsPilot = false
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
		-- TODO: When OnDamaged finally provides damage, move the notify under attack trigger here.
		if not wasPurchased then
			-- Initial AI Harvester
			local damageTaken = GetDamageTaken(self)
			NotifyHarvesterUnderAttack(self, damageTaken)
			GrantRewardOnDamaged(self, attacker, damageTaken, "unit")
		end
	end)

	Trigger.OnKilled(harv, function(self, killer)
		if not wasPurchased then
			GrantRewardOnKilled(self, killer)
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
			local dropOffAt = ti.WarFactoryActorLocation + CVec.New(1, 2) -- Offset again
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
			-- Spawn it south of a destroyed helipad.
			local spawnAt = ti.HelipadActorLocation + CVec.New(1, 2);
			local produced = Actor.Create(type, true, { Owner = NeutralPlayer, Location = spawnAt })
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

				Radar.Ping(pi.Player, beacon.CenterPosition, pingColor, DateTime.Seconds(5))
			end)
		end)

		Trigger.OnDamaged(beacon, function(actor, attacker)
			if actor.Health == 0 and actor.Type ~= attacker.Type then
				-- If the beacon has no health left, disable the activebeacon condition so it doesn't explode.
				beacon.RevokeCondition(beaconToken)
			end

			local damageTaken = GetDamageTaken(actor)
			GrantRewardOnDamaged(actor, attacker, damageTaken, "beacon")
		end)

		-- Add a lighting source
		local lightDurationTicks = DateTime.Seconds(5)
		local lightDelayTicks = BeaconTimeLimit - DateTime.Seconds(5)
		local ambientLightSourceKey = AddLightSource("Ambient", -0.5, lightDurationTicks, lightDelayTicks)
		local colorLightSourceKey = 0
		if beacon.Type == AlphaBeaconType then
			colorLightSourceKey = AddLightSource(AlphaBeaconLightType, AlphaBeaconLightIntensity, lightDurationTicks, lightDelayTicks)
		else
			colorLightSourceKey = AddLightSource(BravoBeaconLightType, BravoBeaconLightIntensity, lightDurationTicks, lightDelayTicks)
		end

		Trigger.OnKilled(beacon, function(actor, killer)
			if actor.Type ~= killer.Type then
				GrantRewardOnKilled(actor, killer)
				FadeLightSource(ambientLightSourceKey)
				FadeLightSource(colorLightSourceKey)
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
				Trigger.AfterDelay(DateTime.Seconds(3), function() camera.Destroy() end)

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

SetLighting = function()
	Utils.Do(LightSources, function(source)
		if source.DelayTicks > 0 then
			source.DelayTicks = source.DelayTicks - 1
		else
			local adj = 1 + (source.AdjustmentPerTick * source.CurrentTick)

			if source.TickSign == 1 and source.CurrentTick == source.DurationTicks then
				source.TickSign = -1
			elseif source.TickSign == -1 and source.CurrentTick == 0 then
				source.TickSign = 0
				adj = 1 -- Force base value, in case of junk decimal precision.
			end

			source.CurrentTick = source.CurrentTick + source.TickSign

			source.CalculatedAdjustment = adj
		end
	end)

	local lowestAmbient = 1
	local highestBlue = 1
	local highestRed = 1

	Utils.Do(LightSources, function(source)
		if source.LightingType == "Ambient" and source.CalculatedAdjustment < lowestAmbient then
			lowestAmbient = source.CalculatedAdjustment
		elseif source.LightingType == "Blue" and source.CalculatedAdjustment > highestBlue then
			highestBlue = source.CalculatedAdjustment
		elseif source.LightingType == "Red" and source.CalculatedAdjustment > highestRed then
			highestRed = source.CalculatedAdjustment
		end

		if source.TickSign == 0 then
			LightSources[source.Key] = nil
		end
	end)

	Lighting.Ambient = lowestAmbient
	Lighting.Blue = highestBlue
	Lighting.Red = highestRed
end

AddLightSource = function(lightingType, targetAdjustment, durationTicks, delayTicks)
	local key = #LightSources .. lightingType -- Not guaranteed to be unique.

	local adjustmentPerTick = targetAdjustment / durationTicks
	LightSources[key] =
	{
		Key = key,
		LightingType = lightingType,
		DelayTicks = delayTicks,
		DurationTicks = durationTicks,
		CurrentTick = 0,
		TickSign = 1, -- 1 or -1, to ramp up and down. 0 indicates removal.
		TargetAdjustment = targetAdjustment,
		AdjustmentPerTick = adjustmentPerTick,
		CalculatedAdjustment = 1 -- Should begin at base value.
	}

	return key
end

FadeLightSource = function(key)
	LightSources[key].TickSign = -1
end

GrantRewardOnDamaged = function(self, attacker, damageTaken, actorCategory)
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
		-- Temporary point experiments
		local buildingPointsModifierOption = Map.LobbyOption("buildingpointsmodifier")
		local unitPointsModifierOption = Map.LobbyOption("unitpointsmodifier")

		local buildingPointsModifier = 1.0
		if buildingPointsModifierOption == "a" then
			buildingPointsModifier = 2.0
		elseif buildingPointsModifierOption == "c" then
			buildingPointsModifier = 0.5
		end
		local unitPointsModifier = 0.5
		if unitPointsModifierOption == "a" then
			unitPointsModifier = 1.0
		elseif unitPointsModifierOption == "c" then
			unitPointsModifier = 0.25
		end

		--[[
			Take % damage dealt of actor's max HP.
			Multiply % damage dealt by modifiers. Floor the %, and convert to points.
			Reward one point at a minimum for less than 1% damage done.
		]]
		damageTaken = math.abs(damageTaken) -- Heals are negative.

		local percentageDamageDealt = (damageTaken / self.MaxHealth) * 100
		local points = percentageDamageDealt
		if actorCategory == "building" then
			points = points * buildingPointsModifier
		else
			points = points * unitPointsModifier
		end
		points = math.floor(points)

		attackerpi.Player.Experience = attackerpi.Player.Experience + points
		attackerpi.Player.Cash = attackerpi.Player.Cash + points
	end
end

GetDamageTaken = function(self)
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

	return damageTaken
end

GrantRewardOnKilled = function(self, killer)
	if ActorIsNeutral(self) then -- Ignore destroying neutral units.
		return
	end
	if self.Owner.Faction == killer.Owner.Faction then -- Ignore self/team.
		return
	end

	local killerpi = PlayerInfo[killer.Owner.InternalName]
	if killerpi ~= nil then -- Killed by a player
		-- Use actor costs defined in yaml to determine point reward.
		-- Our Lua API throws an exception if a unit has no cost.
		-- Just in case, handle it gracefully here.
		local hasValued = pcall(function() Actor.Cost(self.Type) end)
		if hasValued then
			local points = Actor.Cost(self.Type)

			killerpi.Player.Experience = killerpi.Player.Experience + points
			killerpi.Player.Cash = killerpi.Player.Cash + points
		else
			DisplayMessage('ERROR: Actor ' .. self.Type .. ' is missing a point reward!')
		end
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
				pi.Team.SurrendersRemaining = pi.Team.SurrendersRemaining - 1
				DisplayMessage(pi.Player.Name .. ' surrendered!')
			end
		end)
	end

	-- Check for victory
	local tiWinner = nil
	local tiLoser = nil

	if TeamInfo[AlphaTeamPlayerName].SurrendersRemaining == 0 then
		tiWinner = TeamInfo[AlphaTeamPlayerName]
		tiLoser = TeamInfo[BravoTeamPlayerName]
		DisplayMessage("All " .. AlphaTeamPlayerName .. " players have surrendered!")
	elseif TeamInfo[BravoTeamPlayerName].SurrendersRemaining == 0 then
		tiWinner = TeamInfo[BravoTeamPlayerName]
		tiLoser = TeamInfo[AlphaTeamPlayerName]
		DisplayMessage("All " .. BravoTeamPlayerName .. " players have surrendered!")
	end

	if tiLoser == nil then
		if TimeLimitExpired == true then
			-- GDI wins in event of tie.
			if TeamStats[AlphaTeamPlayerName].Experience >= TeamStats[AlphaTeamPlayerName].Experience then
				tiWinner = TeamInfo[AlphaTeamPlayerName]
				tiLoser = TeamInfo[BravoTeamPlayerName]
			else
				tiWinner = TeamInfo[BravoTeamPlayerName]
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
						tiWinner = TeamInfo[BravoTeamPlayerName]
						tiLoser = TeamInfo[AlphaTeamPlayerName]
					else
						tiWinner = TeamInfo[AlphaTeamPlayerName]
						tiLoser = TeamInfo[BravoTeamPlayerName]
					end
				end
			end)
		end
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
	Trigger.OnTimerExpired(function()
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
	local bravo = BravoTeamPlayerName .. ': ' .. tostring(TeamStats[BravoTeamPlayerName].Experience) .. ' points - '
		.. tostring(TeamStats[BravoTeamPlayerName].Kills) .. '/' .. tostring(TeamStats[BravoTeamPlayerName].Deaths) .. ' k/d'

	local scoreboard = '\n' .. '\n' .. '\n' .. '\n'
	if TeamStats[AlphaTeamPlayerName].Experience >= TeamStats[BravoTeamPlayerName].Experience then
		scoreboard = scoreboard .. alpha .. '\n' .. bravo
	else
		scoreboard = scoreboard .. bravo .. '\n' .. alpha
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

DrawNameTags = function()
	local isSpectating = LocalPlayerInfo == nil

	Utils.Do(TeamInfo, function(ti)
		local sameTeam = isSpectating or LocalPlayerInfo.Player.Faction == ti.AiPlayer.Faction

		Utils.Do(ti.Players, function(pi)
			if pi.Hero ~= nil and (pi.Hero.IsInWorld or pi.IsPilot) then

				local pilotOfAliveVehicle = pi.IsPilot and pi.PassengerOfVehicle.HasProperty('CenterPosition') -- Is a pilot, and not of a dead/falling aircraft

				local showTag =
					sameTeam -- On the same team (check required for cloak hack)
					or (not sameTeam and not ArrayContains(EnemyNametagsHiddenForTypes, pi.Hero.Type)) -- HACK: Don't show nametags on enemy units with cloak
					or pilotOfAliveVehicle -- Is a pilot of a not dead/falling aircraft
					or GameOver -- Game is over

				if showTag then
					local name = GetDisplayNameForActor(pi.Hero)
					name = name:sub(0, 14) -- truncate nametags to 14 chars

					local drawOverActor = pi.Hero
					local extraOffset = 0
					if pilotOfAliveVehicle then
						drawOverActor = pi.PassengerOfVehicle
						extraOffset = Actor.CruiseAltitude(pi.PassengerOfVehicle.Type)
						if pi.PassengerOfVehicle.PassengerCount > 1 then
							name = name .. " (+" .. passengerCount - 1 .. ")"
						end
					end

					local pos = WPos.New(drawOverActor.CenterPosition.X, drawOverActor.CenterPosition.Y - 1250 - extraOffset, 0)
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
	return player.InternalName == AlphaTeamPlayerName or player.InternalName == BravoTeamPlayerName
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
			local purchasePool = { }

			if pi.Player.Faction == "gdi" then
				purchasePool = { "e1", "e2" }
				if pi.Player.Cash >= 300 and pi.Player.Cash < 600 then
					purchasePool = { "e1", "e2", "e3", "e3" }
				elseif pi.Player.Cash >= 600 then
					purchasePool = { "rmbo", "e3" }
				end
			else -- Nod
				purchasePool = { "e1", "e4" }
				if pi.Player.Cash >= 300 and pi.Player.Cash < 600 then
					purchasePool = { "e1", "e4", "e3", "e3" }
				elseif pi.Player.Cash >= 600 then
					purchasePool = { "e5", "e3" }
				end
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
	if weaponTest then -- Coordinates fit bravo map
		Actor.Create('camera', true, { Owner = AlphaTeamPlayer, Location = CPos.New(22, 23) })
		Actor.Create('camera', true, { Owner = BravoTeamPlayer, Location = CPos.New(25, 23) })
		local a1 = Actor.Create('obli', true, { Owner = AlphaTeamPlayer, Location = CPos.New(22, 23) })
		local a2 = Actor.Create('mtnk', true, { Owner = BravoTeamPlayer, Location = CPos.New(24, 23) })
		local a3 = Actor.Create('mtnk', true, { Owner = BravoTeamPlayer, Location = CPos.New(24, 24) })
		local a4 = Actor.Create('mtnk', true, { Owner = BravoTeamPlayer, Location = CPos.New(25, 23) })
		--local a5 = Actor.Create('mtnk', true, { Owner = BravoTeamPlayer, Location = CPos.New(25, 24) })
		a2.GrantCondition('brandnew')
		a3.GrantCondition('brandnew')
		a4.GrantCondition('brandnew')
		--a5.GrantCondition('brandnew')

		Actor.Create('camera', true, { Owner = AlphaTeamPlayer, Location = CPos.New(22, 33) })
		Actor.Create('camera', true, { Owner = BravoTeamPlayer, Location = CPos.New(25, 33) })
		local b1 = Actor.Create('mtnk', true, { Owner = AlphaTeamPlayer, Location = CPos.New(21, 30) })
		local b2 = Actor.Create('mtnk', true, { Owner = AlphaTeamPlayer, Location = CPos.New(21, 31) })
		local b3 = Actor.Create('mtnk', true, { Owner = AlphaTeamPlayer, Location = CPos.New(21, 32) })
		local b4 = Actor.Create('stnk', true, { Owner = BravoTeamPlayer, Location = CPos.New(22, 30) })
		local b5 = Actor.Create('stnk', true, { Owner = BravoTeamPlayer, Location = CPos.New(22, 31) })
		local b6 = Actor.Create('stnk', true, { Owner = BravoTeamPlayer, Location = CPos.New(22, 32) })

		--b1.GrantCondition('brandnew')
		--b2.GrantCondition('brandnew')
		--b3.GrantCondition('brandnew')
		b4.GrantCondition('brandnew')
		b5.GrantCondition('brandnew')
		b6.GrantCondition('brandnew')
	end
end
