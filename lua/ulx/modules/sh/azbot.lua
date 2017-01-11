
if engine.ActiveGamemode() == "zombiesurvival" then
	hook.Add("PlayerSpawn", "!human info", function(pl)
		if not AzBot.IsSelfRedeemEnabled or pl:Team() ~= TEAM_UNDEAD or GAMEMODE:GetWave() > AzBot.SelfRedeemWaveMax then return end
		local hint = "You can type !human before wave " .. (AzBot.SelfRedeemWaveMax + 1) .. " to play as survivor."
		pl:PrintMessage(HUD_PRINTCENTER, hint)
		pl:ChatPrint(hint)
	end)
	
	function ulx.giveHumanLoadout(pl)
		pl:Give("weapon_zs_axe")
		pl:Give("weapon_zs_peashooter")
		pl:GiveAmmo(50, "pistol")
	end
	
	function ulx.tryBringToHumans(pl)
		local potSpawnTgts = team.GetPlayers(TEAM_HUMAN)
		for i = 1, 5 do
			local potSpawnTgtOrNil = table.Random(potSpawnTgts)
			if IsValid(potSpawnTgtOrNil) and not util.TraceHull{
				start = potSpawnTgtOrNil:GetPos(),
				endpos = potSpawnTgtOrNil:GetPos(),
				mins = potSpawnTgtOrNil:OBBMins(),
				maxs = potSpawnTgtOrNil:OBBMaxs(),
				filter = potSpawnTgts,
				mask = MASK_PLAYERSOLID }.Hit then
				pl:SetPos(potSpawnTgtOrNil:GetPos())
				break
			end
		end
	end
	
	local nextByPl = {}
	local tierByPl = {}
	function ulx.human(pl)
		if not AzBot.IsSelfRedeemEnabled then
			local response = "This command is enabled on bot maps only!"
			pl:ChatPrint(response)
			pl:PrintMessage(HUD_PRINTCENTER, response)
			return
		end
		if GAMEMODE:GetWave() > AzBot.SelfRedeemWaveMax then
			local response = "It's too late to self-redeem (can only be done before wave " .. (AzBot.SelfRedeemWaveMax + 1) .. ")."
			pl:ChatPrint(response)
			pl:PrintMessage(HUD_PRINTCENTER, response)
			return
		end
		if pl:Team() ~= TEAM_UNDEAD then
			local response = "You're already human!"
			pl:ChatPrint(response)
			pl:PrintMessage(HUD_PRINTCENTER, response)
			return
		end
		local remainingTime = (nextByPl[pl] or 0) - CurTime()
		if remainingTime > 0 then
			local response = "You already self-redeemed recently. Try again in " .. remainingTime .. " seconds!"
			pl:ChatPrint(response)
			pl:PrintMessage(HUD_PRINTCENTER, response)
			return
		end
		local nextTier = (tierByPl[pl] or 0) + 1
		tierByPl[pl] = nextTier
		local cooldown = nextTier * 30
		nextByPl[pl] = CurTime() + cooldown
		local response = "You self-redeemed. Your current cooldown until next self-redeem is " .. cooldown .. " seconds."
		pl:ChatPrint(response)
		pl:PrintMessage(HUD_PRINTCENTER, response)
		pl:Redeem()
		pl:StripWeapons()
		pl:StripAmmo()
		ulx.giveHumanLoadout(pl)
		ulx.tryBringToHumans(pl)
	end
	local cmd = ulx.command("Zombie Survival", "ulx human", ulx.human, "!human")
	cmd:defaultAccess(ULib.ACCESS_ALL)
	cmd:help("If you're a zombie, you can use this command to instantly respawn as a human with a default loadout.")
end

local function registerCmd(camelCaseName, access, ...)
	local func
	local params = {}
	for idx, arg in ipairs{ ... } do
		if istable(arg) then
			table.insert(params, arg)
		elseif isfunction(arg) then
			func = arg
			break
		else
			break
		end
	end
	ulx["azBot" .. camelCaseName] = func
	local cmdStr = (access == ULib.ACCESS_SUPERADMIN and "azbot " or "") .. camelCaseName:lower()
	local cmd = ulx.command("AzBot", cmdStr, func, "!" .. cmdStr)
	for k, param in pairs(params) do cmd:addParam(param) end
	cmd:defaultAccess(access)
end
local function registerSuperadminCmd(camelCaseName, ...) registerCmd(camelCaseName, ULib.ACCESS_SUPERADMIN, ...) end
local function registerAdminCmd(camelCaseName, ...) registerCmd(camelCaseName, ULib.ACCESS_ADMIN, ...) end

local plsParam = { type = ULib.cmds.PlayersArg }
local numParam = { type = ULib.cmds.NumArg }
local strParam = { type = ULib.cmds.StringArg }
local optionalStrParam = { type = ULib.cmds.StringArg, ULib.cmds.optional }

registerAdminCmd("BotMod", numParam, function(caller, num)
	local formerZombiesCountAddition = AzBot.ZombiesCountAddition
	AzBot.ZombiesCountAddition = math.Round(num)
	local function format(num) return "[formula + (" .. num .. ")]" end
	caller:ChatPrint("Zombies count changed from " .. format(formerZombiesCountAddition) .. " to " .. format(AzBot.ZombiesCountAddition) .. ".")
end)

registerSuperadminCmd("ViewMesh", plsParam, function(caller, pls) for k, pl in pairs(pls) do AzBot.SetMapNavMeshUiSubscription(pl, "view") end end)
registerSuperadminCmd("EditMesh", plsParam, function(caller, pls) for k, pl in pairs(pls) do AzBot.SetMapNavMeshUiSubscription(pl, "edit") end end)
registerSuperadminCmd("HideMesh", plsParam, function(caller, pls) for k, pl in pairs(pls) do AzBot.SetMapNavMeshUiSubscription(pl, nil) end end)

registerSuperadminCmd("SaveMesh", function(caller)
	AzBot.SaveMapNavMesh()
	caller:ChatPrint("Saved.")
end)
registerSuperadminCmd("ReloadMesh", function(caller)
	AzBot.LoadMapNavMesh()
	AzBot.UpdateMapNavMeshUiSubscribers()
	caller:ChatPrint("Reloaded.")
end)
registerSuperadminCmd("RefreshMeshView", function(caller)
	AzBot.UpdateMapNavMeshUiSubscribers()
	caller:ChatPrint("Refreshed.")
end)

registerSuperadminCmd("SetParam", strParam, strParam, optionalStrParam, function(caller, id, name, serializedNumOrStrOrEmpty)
	AzBot.TryCatch(function()
		AzBot.MapNavMesh.ItemById[AzBot.DeserializeNavMeshItemId(id)]:SetParam(name, serializedNumOrStrOrEmpty)
		AzBot.UpdateMapNavMeshUiSubscribers()
	end, function(errorMsg)
		caller:ChatPrint("Error. Re-check your parameters.")
	end)
end)

registerSuperadminCmd("ViewPath", plsParam, strParam, strParam, function(caller, pls, startNodeId, endNodeId)
	local nodeById = AzBot.MapNavMesh.NodeById
	local startNode = nodeById[AzBot.DeserializeNavMeshItemId(startNodeId)]
	local endNode = nodeById[AzBot.DeserializeNavMeshItemId(endNodeId)]
	if not startNode or not endNode then
		caller:ChatPrint("Not all specified nodes exist.")
		return
	end
	local path = AzBot.GetBestMeshPathOrNil(startNode, endNode)
	if not path then
		caller:ChatPrint("Couldn't find any path for the two specified nodes.")
		return
	end
	for k, pl in pairs(pls) do AzBot.ShowMapNavMeshPath(pl, path) end
end)
registerSuperadminCmd("DebugPath", plsParam, optionalStrParam, function(caller, pls, serializedEntIdxOrEmpty)
	local ent = serializedEntIdxOrEmpty == "" and caller:GetEyeTrace().Entity or Entity(tonumber(serializedEntIdxOrEmpty) or -1)
	if not IsValid(ent) then
		caller:ChatPrint("No entity cursored or invalid entity index specified.")
		return
	end
	caller:ChatPrint("Debugging path from player to " .. tostring(ent) .. ".")
	for k, pl in pairs(pls) do AzBot.ShowMapNavMeshPath(pl, pl, ent) end
end)
registerSuperadminCmd("ResetPath", plsParam, function(caller, pls) for k, pl in pairs(pls) do AzBot.HideMapNavMeshPath(pl) end end)
