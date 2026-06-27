--!nostrict
local run = function(func)
    local suc, res = pcall(function()
        task.spawn(func)
    end)
    if not suc then
        if vape then
            vape:CreateNotification('Vape', `Failed to load module? reasoning {res} || Storing to server..`,12,'alert')
            -- todo send to server packets
        end
    end
end
local cloneref = cloneref or function(obj: any)
    return obj
end
local hookedfunctionstable = {}
local clonefunction = clonefunction or function(func: Function)
	return func
end
local hookfunction = hookfunction or function(func: Function, newfunc: Function)
	if table.find(hookedfunctionstable, func) then
		return func
	end
	table.insert(hookedfunctionstable, {
		og = func,
		new = newfunc
	})
	return newfunc
end
local restorefunction = restorefunction or function(func: Function)
	for i, v in pairs(hookedfunctionstable) do
		if v.og == func then
			table.remove(hookedfunctionstable, i)
			return v.og
		end
	end
	return nil
end
local vapeEvents = setmetatable({}, {
	__index = function(self, index)
		self[index] = Instance.new('BindableEvent')
		return self[index]
	end
})
local playersService = cloneref(game:GetService('Players'))
local replicatedStorage = cloneref(game:GetService('ReplicatedStorage'))
local runService = cloneref(game:GetService('RunService'))
local inputService = cloneref(game:GetService('UserInputService'))
local tweenService = cloneref(game:GetService('TweenService'))
local httpService = cloneref(game:GetService('HttpService'))
local textChatService = cloneref(game:GetService('TextChatService'))
local collectionService = cloneref(game:GetService('CollectionService'))
local contextActionService = cloneref(game:GetService('ContextActionService'))
local guiService = cloneref(game:GetService('GuiService'))
local coreGui = cloneref(game:GetService('CoreGui'))
local starterGui = cloneref(game:GetService('StarterGui'))
local lightingService = cloneref(game:GetService('Lighting'))
local isnetworkowner = isnetworkowner or function()
    return true
end
local gameCamera = workspace.CurrentCamera
local lplr = playersService.LocalPlayer
local assetfunction = getcustomasset
local vape = shared.vape
local entitylib = vape.Libraries.entity
local targetinfo = vape.Libraries.targetinfo
local sessioninfo = vape.Libraries.sessioninfo
local uipallet = vape.Libraries.uipallet
local tween = vape.Libraries.tween
local color = vape.Libraries.color
local whitelist = vape.Libraries.whitelist
local prediction = vape.Libraries.prediction
local getfontsize = vape.Libraries.getfontsize
local getcustomasset = vape.Libraries.getcustomasset
local rankCache = {}
local store = {
	lastHit = 0,
	attackReach = 0,
	attackReachUpdate = tick(),
	damageBlockFail = tick(),
	hand = {},
	rank = setmetatable({}, {
		__index = function(self, index)
			return {
				async = function()
					if rankCache[index] then
						return rankCache[index]
					end

					if index then
						local rank = bedwars.Client:Get('FetchRanks'):CallServer({index.UserId})
						if typeof(rank) == 'table' and rank[1] and rank[1].rankDivision then
							rankCache[index] = rank[1].rankDivision
							return rankCache[index]
						end
					end

					return nil
				end,
			}
		end
	}),
	inventory = {
		inventory = {
			items = {},
			armor = {}
		},
		hotbar = {}
	},
	selfProjectiles = {},
	inventories = {},
	matchState = 0,
	queueType = 'bedwars_test',
	tools = {}
}
getgenv().store = store
local Reach = {}
local HitBoxes = {}
local InfiniteFly = {}
local TrapDisabler
local AntiFallPart
local bedwars, remotes, sides, oldinvrender, oldSwing = {}, {}, {}

local function addBlur(parent)
	local blur = Instance.new('ImageLabel')
	blur.Name = 'Blur'
	blur.Size = UDim2.new(1, 89, 1, 52)
	blur.Position = UDim2.fromOffset(-48, -31)
	blur.BackgroundTransparency = 1
	blur.Image = getcustomasset('catrewrite/assets/new/blur.png')
	blur.ScaleType = Enum.ScaleType.Slice
	blur.SliceCenter = Rect.new(52, 31, 261, 502)
	blur.Parent = parent
	return blur
end

local function collection(tags, module, customadd, customremove)
	tags = typeof(tags) ~= 'table' and {tags} or tags
	local objs, connections = {}, {}

	for _, tag in tags do
		table.insert(connections, collectionService:GetInstanceAddedSignal(tag):Connect(function(v)
			if customadd then
				customadd(objs, v, tag)
				return
			end
			table.insert(objs, v)
		end))
		table.insert(connections, collectionService:GetInstanceRemovedSignal(tag):Connect(function(v)
			if customremove then
				customremove(objs, v, tag)
				return
			end
			v = table.find(objs, v)
			if v then
				table.remove(objs, v)
			end
		end))

		for _, v in collectionService:GetTagged(tag) do
			if customadd then
				customadd(objs, v, tag)
				continue
			end
			table.insert(objs, v)
		end
	end

	local cleanFunc = function(self)
		for _, v in connections do
			v:Disconnect()
		end
		table.clear(connections)
		table.clear(objs)
		table.clear(self)
	end
	if module then
		module:Clean(cleanFunc)
	end
	return objs, cleanFunc
end

local function getBestArmor(slot)
	local closest, mag = nil, 0

	for _, item in store.inventory.inventory.items do
		local meta = item and bedwars.ItemMeta[item.itemType] or {}

		if meta.armor and meta.armor.slot == slot then
			local newmag = (meta.armor.damageReductionMultiplier or 0)

			if newmag > mag then
				closest, mag = item, newmag
			end
		end
	end

	return closest
end

local function getBow()
	local bestBow, bestBowSlot, bestBowDamage = nil, nil, 0
	for slot, item in store.inventory.inventory.items do
		local bowMeta = bedwars.ItemMeta[item.itemType].projectileSource
		if bowMeta and table.find(bowMeta.ammoItemTypes, 'arrow') then
			local bowDamage = bedwars.ProjectileMeta[bowMeta.projectileType('arrow')].combat.damage or 0
			if bowDamage > bestBowDamage then
				bestBow, bestBowSlot, bestBowDamage = item, slot, bowDamage
			end
		end
	end
	return bestBow, bestBowSlot
end

local function getItem(itemName, inv, find)
	for slot, item in (inv or store.inventory.inventory.items) do
		if find and item.itemType:find(itemName) or item.itemType == itemName then
			return item, slot
		end
	end
	return nil
end

local function getRoactRender(func)
	return debug.getupvalue(debug.getupvalue(debug.getupvalue(func, 3).render, 2).render, 1)
end

local function getSword()
	local bestSword, bestSwordSlot, bestSwordDamage = nil, nil, 0
	for slot, item in store.inventory.inventory.items do
		local swordMeta = bedwars.ItemMeta[item.itemType].sword
		if swordMeta then
			local swordDamage = swordMeta.damage or 0
			if swordDamage > bestSwordDamage then
				bestSword, bestSwordSlot, bestSwordDamage = item, slot, swordDamage
			end
		end
	end
	return bestSword, bestSwordSlot
end

local function getTool(breakType)
	local bestTool, bestToolSlot, bestToolDamage = nil, nil, 0
	for slot, item in store.inventory.inventory.items do
		local toolMeta = bedwars.ItemMeta[item.itemType].breakBlock
		if toolMeta then
			local toolDamage = toolMeta[breakType] or 0
			if toolDamage > bestToolDamage then
				bestTool, bestToolSlot, bestToolDamage = item, slot, toolDamage
			end
		end
	end
	return bestTool, bestToolSlot
end

local function getWool()
	for _, wool in (inv or store.inventory.inventory.items) do
		if wool.itemType:find('wool') then
			return wool and wool.itemType, wool and wool.amount
		end
	end
end

local function getStrength(plr)
	if not plr.Player then
		return 0
	end

	local strength = 0
	for _, v in (store.inventories[plr.Player] or {items = {}}).items do
		local itemmeta = bedwars.ItemMeta[v.itemType]
		if itemmeta and itemmeta.sword and itemmeta.sword.damage > strength then
			strength = itemmeta.sword.damage
		end
	end

	return strength
end

local function getPlacedBlock(pos)
	if not pos then
		return
	end
	local roundedPosition = bedwars.BlockController:getBlockPosition(pos)
	return bedwars.BlockController:getStore():getBlockAt(roundedPosition), roundedPosition
end
getgenv().getPlacedBlock = getPlacedBlock

local function getBlocksInPoints(s, e)
	local blocks, list = bedwars.BlockController:getStore(), {}
	for x = s.X, e.X do
		for y = s.Y, e.Y do
			for z = s.Z, e.Z do
				local vec = Vector3.new(x, y, z)
				if blocks:getBlockAt(vec) then
					table.insert(list, vec * 3)
				end
			end
		end
	end
	return list
end

local function getNearGround(range)
	range = Vector3.new(3, 3, 3) * (range or 10)
	local localPosition, mag, closest = entitylib.character.RootPart.Position, 60
	local blocks = getBlocksInPoints(bedwars.BlockController:getBlockPosition(localPosition - range), bedwars.BlockController:getBlockPosition(localPosition + range))

	for _, v in blocks do
		if not getPlacedBlock(v + Vector3.new(0, 3, 0)) then
			local newmag = (localPosition - v).Magnitude
			if newmag < mag then
				mag, closest = newmag, v + Vector3.new(0, 3, 0)
			end
		end
	end

	table.clear(blocks)
	return closest
end

local function getShieldAttribute(char)
	local returned = 0
	for name, val in char:GetAttributes() do
		if name:find('Shield') and type(val) == 'number' and val > 0 then
			returned += val
		end
	end
	return returned
end


local knockbackSpeed, knockbackBoost = 0, tick()
local function getSpeed()
	local multi, increase, modifiers = 0, true, bedwars.SprintController:getMovementStatusModifier():getModifiers()

	for v in modifiers do
		local val = v.constantSpeedMultiplier and v.constantSpeedMultiplier or 0
		if val and val > math.max(multi, 1) then
			increase = false
			multi = val - (0.06 * math.round(val))
		end
	end

	for v in modifiers do
		multi += math.max((v.moveSpeedMultiplier or 0) - 1, 0)
	end

	if multi > 0 and increase then
		multi += 0.16 + (0.02 * math.round(multi))
	end

	return (20 + (knockbackBoost > tick() and knockbackSpeed or 0)) * (multi + 1)
end
getgenv().getSpeed = getSpeed

local function getTableSize(tab)
	local ind = 0
	for _ in tab do
		ind += 1
	end
	return ind
end

local function getHotbar(tool)
	for i, v in (store.inventory.hotbar or {}) do
		if v.item and v.item.tool == tool then
			return i - 1
		end
	end
	return nil
end
getgenv().getHotbar = getHotbar

local function hotbarSwitch(slot)
	if slot and store.inventory.hotbarSlot ~= slot then
		bedwars.Store:dispatch({
			type = 'InventorySelectHotbarSlot',
			slot = slot
		})
		vapeEvents.InventoryChanged.Event:Wait()
		return true
	end
	return false
end
getgenv().hotbarSwitch = hotbarSwitch

local function isFriend(plr, recolor)
	if vape.Categories.Friends.Options['Use friends'].Enabled then
		local friend = table.find(vape.Categories.Friends.ListEnabled, plr.Name) and true
		if recolor then
			friend = friend and vape.Categories.Friends.Options['Recolor visuals'].Enabled
		end
		return friend
	end
	return nil
end

local function isTarget(plr)
	return table.find(vape.Categories.Targets.ListEnabled, plr.Name) and true
end

local function notif(...) return vape:CreateNotification(...) end

local function removeTags(str)
	str = str:gsub('<br%s*/>', '\n')
	return (str:gsub('<[^<>]->', ''))
end

local function roundPos(vec)
	return Vector3.new(math.round(vec.X / 3) * 3, math.round(vec.Y / 3) * 3, math.round(vec.Z / 3) * 3)
end

local function switchItem(tool, delayTime)
	delayTime = delayTime or 0.05
	local check = lplr.Character and lplr.Character:FindFirstChild('HandInvItem') or nil
	if check and check.Value ~= tool and tool.Parent ~= nil then
		task.spawn(function()
			bedwars.Client:Get(remotes.EquipItem):CallServerAsync({hand = tool})
		end)
		check.Value = tool
		if delayTime > 0 then
			task.wait(delayTime)
		end
		return true
	end
end
getgenv().switchItem = switchItem

local function waitForChildOfType(obj, name, timeout, prop)
	local check, returned = tick() + timeout, nil
	repeat
		returned = prop and obj[name] or obj:FindFirstChildOfClass(name)
		if returned and returned.Name ~= 'UpperTorso' or check < tick() then
			break
		end
		task.wait()
	until false
	return returned
end

local function waitForChildYield(obj, timeout, ...)
	local check, returned = tick(), obj
	for _, v in { ... } do
		if not returned then
			break
		end
		check = tick() + timeout
		repeat
			local new = returned:FindFirstChild(v)
			if new or tick() > check then
				returned = new
				break
			end
			task.wait()
		until false
	end
	return returned
end

local function rakNetCheck(module)
	if not (raknet and raknet.add_send_hook and pcall(raknet.add_send_hook, function() end)) then
		notif(module, 'This feature requires raknet! (risky feature, please do not use on mains.)', 10, 'warning')
		return false
	end

	return true
end

local frictionTable, oldfrict = {}, {}
local frictionConnection
local frictionState

local function modifyVelocity(v)
	if v:IsA('BasePart') and v.Name ~= 'HumanoidRootPart' and not oldfrict[v] then
		oldfrict[v] = v.CustomPhysicalProperties or 'none'
		v.CustomPhysicalProperties = PhysicalProperties.new(0.0001, 0.2, 0.5, 1, 1)
	end
end

local function updateVelocity(force)
	local newState = getTableSize(frictionTable) > 0
	if frictionState ~= newState or force then
		if frictionConnection then
			frictionConnection:Disconnect()
		end
		if newState then
			if entitylib.isAlive then
				for _, v in entitylib.character.Character:GetDescendants() do
					modifyVelocity(v)
				end
				frictionConnection = entitylib.character.Character.DescendantAdded:Connect(modifyVelocity)
			end
		else
			for i, v in oldfrict do
				i.CustomPhysicalProperties = v ~= 'none' and v or nil
			end
			table.clear(oldfrict)
		end
	end
	frictionState = newState
end

local kitorder = {
	hannah = 5,
	spirit_assassin = 4,
	dasher = 3,
	jade = 2,
	regent = 1
}

local getBlockHits
local sortmethods, breakmethods = {
	Damage = function(a, b)
		return a.Entity.Character:GetAttribute('LastDamageTakenTime') < b.Entity.Character:GetAttribute('LastDamageTakenTime')
	end,
	Threat = function(a, b)
		return getStrength(a.Entity) > getStrength(b.Entity)
	end,
	Kit = function(a, b)
		return (a.Entity.Player and kitorder[a.Entity.Player:GetAttribute('PlayingAsKit')] or 0) > (b.Entity.Player and kitorder[b.Entity.Player:GetAttribute('PlayingAsKit')] or 0)
	end,
	Health = function(a, b)
		return a.Entity.Health < b.Entity.Health
	end,
	Angle = function(a, b)
		local selfrootpos = entitylib.character.RootPart.Position
		local localfacing = entitylib.character.RootPart.CFrame.LookVector * Vector3.new(1, 0, 1)
		local angle = math.acos(localfacing:Dot(((a.Entity.RootPart.Position - selfrootpos) * Vector3.new(1, 0, 1)).Unit))
		local angle2 = math.acos(localfacing:Dot(((b.Entity.RootPart.Position - selfrootpos) * Vector3.new(1, 0, 1)).Unit))
		return angle < angle2
	end,
	Mouse = function(a, b)
		local mouse = lplr:GetMouse()
		local origin = Vector2.new(mouse.X, mouse.Y)

		local posa, visa = gameCamera:WorldToScreenPoint(a.Entity.RootPart.Position)
		local posb, visb = gameCamera:WorldToScreenPoint(b.Entity.RootPart.Position)
		local dista = visa and (Vector2.new(posa.X, posa.Y) - origin).Magnitude or math.huge
        local distb = visb and (Vector2.new(posb.X, posb.Y) - origin).Magnitude or math.huge
        return (dista == dista and dista or math.huge) < (distb == distb and distb or math.huge)
	end
}, {
	Health = function(...)
		return getBlockHits(...)
	end,
	Distance = function(a)
		local pos = (entitylib.isAlive and (entitylib.character.RootPart.Position - Vector3.new(0, 1, 0)) or Vector3.zero)
		return (pos - Vector3.new(a.Position.X, pos.Y, a.Position.Z)).Magnitude
	end
}

run(function()
	local oldstart = entitylib.start
	local function customEntity(ent)
		if ent:HasTag('inventory-entity') and not ent:HasTag('Monster') and not ent:HasTag('trainingRoomDummy') then
			return
		end

		entitylib.addEntity(ent, nil, ent:HasTag('Drone') and function(self)
			local droneplr = playersService:GetPlayerByUserId(self.Character:GetAttribute('PlayerUserId'))
			return not droneplr or lplr:GetAttribute('Team') ~= droneplr:GetAttribute('Team')
		end or function(self)
			return lplr:GetAttribute('Team') ~= self.Character:GetAttribute('Team')
		end)
	end

	entitylib.start = function()
		oldstart()
		if entitylib.Running then
			for _, ent in collectionService:GetTagged('entity') do
				customEntity(ent)
			end
			table.insert(entitylib.Connections, collectionService:GetInstanceAddedSignal('entity'):Connect(customEntity))
			table.insert(entitylib.Connections, collectionService:GetInstanceRemovedSignal('entity'):Connect(function(ent)
				entitylib.removeEntity(ent)
			end))
		end
	end

	entitylib.addPlayer = function(plr)
		if plr.Character then
			entitylib.refreshEntity(plr.Character, plr)
		end
		entitylib.PlayerConnections[plr] = {
			plr.CharacterAdded:Connect(function(char)
				entitylib.refreshEntity(char, plr)
			end),
			plr.CharacterRemoving:Connect(function(char)
				entitylib.removeEntity(char, plr == lplr)
			end),
			plr:GetAttributeChangedSignal('Team'):Connect(function()
				for _, v in entitylib.List do
					if v.Targetable ~= entitylib.targetCheck(v) then
						entitylib.refreshEntity(v.Character, v.Player)
					end
				end

				if plr == lplr then
					entitylib.start()
				else
					entitylib.refreshEntity(plr.Character, plr)
				end
			end)
		}
	end

	entitylib.addEntity = function(char, plr, teamfunc)
		if not char then return end
		entitylib.EntityThreads[char] = task.spawn(function()
			local hum, humrootpart, head
			if plr then
				hum = waitForChildOfType(char, 'Humanoid', 10)
				humrootpart = hum and waitForChildOfType(hum, 'RootPart', workspace.StreamingEnabled and 9e9 or 10, true)
				head = char:WaitForChild('Head', 10) or humrootpart
			else
				hum = {HipHeight = 0.5}
				humrootpart = waitForChildOfType(char, 'PrimaryPart', 10, true)
				head = humrootpart
			end
			local updateobjects = plr and plr ~= lplr and {
				char:WaitForChild('ArmorInvItem_0', 5),
				char:WaitForChild('ArmorInvItem_1', 5),
				char:WaitForChild('ArmorInvItem_2', 5),
				char:WaitForChild('HandInvItem', 5)
			} or {}

			if hum and humrootpart then
				local entity = {
					Connections = {},
					Character = char,
					Health = (char:GetAttribute('Health') or 100) + getShieldAttribute(char),
					Head = head,
					Humanoid = hum,
					HumanoidRootPart = humrootpart,
					HipHeight = hum.HipHeight + (humrootpart.Size.Y / 2) + (hum.RigType == Enum.HumanoidRigType.R6 and 2 or 0),
					Jumps = 0,
					JumpTick = tick(),
					Jumping = false,
					LandTick = tick(),
					MaxHealth = char:GetAttribute('MaxHealth') or 100,
					NPC = plr == nil,
					Player = plr,
					RootPart = humrootpart,
					TeamCheck = teamfunc
				}

				if plr == lplr then
					entity.AirTime = tick()
					entitylib.character = entity
					entitylib.isAlive = true
					entitylib.Events.LocalAdded:Fire(entity)
					table.insert(entitylib.Connections, char.AttributeChanged:Connect(function(attr)
						vapeEvents.AttributeChanged:Fire(attr)
					end))
				else
					entity.Targetable = entitylib.targetCheck(entity)
					if plr ~= nil then
						table.insert(entity.Connections, hum.AnimationPlayed:Connect(function(track)
							entitylib.Events.AnimationPlayed:Fire(plr, track)
						end))
					end
					
					for _, v in entitylib.getUpdateConnections(entity) do
						table.insert(entity.Connections, v:Connect(function()
							entity.Health = (char:GetAttribute('Health') or 100) + getShieldAttribute(char)
							entity.MaxHealth = char:GetAttribute('MaxHealth') or 100
							entitylib.Events.EntityUpdated:Fire(entity)
						end))
					end

					for _, v in updateobjects do
						table.insert(entity.Connections, v:GetPropertyChangedSignal('Value'):Connect(function()
							task.delay(0.1, function()
								if bedwars.getInventory then
									store.inventories[plr] = bedwars.getInventory(plr)
									entitylib.Events.EntityUpdated:Fire(entity)
								end
							end)
						end))
					end

					if plr then
						local anim = char:FindFirstChild('Animate')
						if anim then
							pcall(function()
								anim = anim.jump:FindFirstChildWhichIsA('Animation').AnimationId
								table.insert(entity.Connections, hum.Animator.AnimationPlayed:Connect(function(playedanim)
									if playedanim.Animation.AnimationId == anim then
										entity.JumpTick = tick()
										entity.Jumps += 1
										entity.LandTick = tick() + 1
										entity.Jumping = entity.Jumps > 1
									end
								end))
							end)
						end

						task.delay(0.1, function()
							if bedwars.getInventory then
								store.inventories[plr] = bedwars.getInventory(plr)
							end
						end)
					end
					table.insert(entitylib.List, entity)
					entitylib.Events.EntityAdded:Fire(entity)
				end

				table.insert(entity.Connections, char.ChildRemoved:Connect(function(part)
					if part == humrootpart or part == hum or part == head then
						if part == humrootpart and hum.RootPart then
							humrootpart = hum.RootPart
							entity.RootPart = hum.RootPart
							entity.HumanoidRootPart = hum.RootPart
							return
						end
						entitylib.removeEntity(char, plr == lplr)
					end
				end))
			end
			entitylib.EntityThreads[char] = nil
		end)
	end

	entitylib.getUpdateConnections = function(ent)
		local char = ent.Character
		local tab = {
			char:GetAttributeChangedSignal('Health'),
			char:GetAttributeChangedSignal('MaxHealth'),
			{
				Connect = function()
					ent.Friend = ent.Player and isFriend(ent.Player) or nil
					ent.Target = ent.Player and isTarget(ent.Player) or nil
					return {Disconnect = function() end}
				end
			}
		}

		if ent.Player then
			table.insert(tab, ent.Player:GetAttributeChangedSignal('PlayingAsKit'))
		end

		for name, val in char:GetAttributes() do
			if name:find('Shield') and type(val) == 'number' then
				table.insert(tab, char:GetAttributeChangedSignal(name))
			end
		end

		return tab
	end

	entitylib.targetCheck = function(ent)
		if ent.TeamCheck then
			return ent:TeamCheck()
		end
		if ent.NPC then return true end
		if isFriend(ent.Player) then return false end
		if not select(2, whitelist:get(ent.Player)) then return false end
		return lplr:GetAttribute('Team') ~= ent.Player:GetAttribute('Team')
	end
	vape:Clean(entitylib.Events.LocalAdded:Connect(updateVelocity))
end)
entitylib.start()

local oldrf = nil
run(function()
	oldrf = clonefunction(restorefunction)
	getgenv().restorefunction = newcclosure(function(old, target)
		target = target or old
		local suc, res = pcall(function()
			return oldrf(old, target)
		end)
		if not suc then
			return hookfunction(target, old)
		end
		return res
	end, 'restorefunction')
	pcall(function() restorefunction = getgenv().restorefunction end)
end)

run(function()
	local KnitInit, Knit
	repeat
		KnitInit, Knit = pcall(function()
			return require(replicatedStorage.rbxts_include.node_modules["@easy-games"].knit.src).KnitClient
		end)
		if KnitInit then break end
		task.wait()
	until KnitInit

	if not debug.getupvalue(Knit.Start, 1) then
		repeat task.wait() until debug.getupvalue(Knit.Start, 1)
	end
	
	local Flamework = require(replicatedStorage['rbxts_include']['node_modules']['@flamework'].core.out).Flamework
	local InventoryUtil = require(replicatedStorage.TS.inventory['inventory-util']).InventoryUtil
	local Client = require(replicatedStorage.TS.remotes).default.Client
	local OldGet, OldBreak = Client.Get, nil

	bedwars = setmetatable({
		AbilityController = Flamework.resolveDependency('@easy-games/game-core:client/controllers/ability/ability-controller@AbilityController'),
		AnimationType = require(replicatedStorage.TS.animation['animation-type']).AnimationType,
		AdetundeUpgradeMeta = require(replicatedStorage.TS.games.bedwars.items['frosty-hammer']['frosty-hammer-upgrades']).FrostyHammerUpgradeMeta,
		AdetundeUtil = require(replicatedStorage.TS.games.bedwars.items['frosty-hammer']['frosty-hammer-util']).FrostyHammerUtil,
		AnimationUtil = require(replicatedStorage['rbxts_include']['node_modules']['@easy-games']['game-core'].out['shared'].util['animation-util']).AnimationUtil,
		AppController = require(replicatedStorage['rbxts_include']['node_modules']['@easy-games']['game-core'].out.client.controllers['app-controller']).AppController,
		BedBreakEffectMeta = require(replicatedStorage.TS.locker['bed-break-effect']['bed-break-effect-meta']).BedBreakEffectMeta,
		BedwarsKitMeta = require(replicatedStorage.TS.games.bedwars.kit['bedwars-kit-meta']).BedwarsKitMeta,
		BedwarsKitSkin = debug.getupvalue(require(replicatedStorage.TS.games.bedwars['kit-skin']['bedwars-kit-skin-meta']).getKitSkinMetadata, 1) or {},
		BlockBreaker = Knit.Controllers.BlockBreakController.blockBreaker,
		BlockController = require(replicatedStorage['rbxts_include']['node_modules']['@easy-games']['block-engine'].out).BlockEngine,
		BlockEngine = require(lplr.PlayerScripts.TS.lib['block-engine']['client-block-engine']).ClientBlockEngine,
		BlockPlacer = require(replicatedStorage['rbxts_include']['node_modules']['@easy-games']['block-engine'].out.client.placement['block-placer']).BlockPlacer,
		BlockSelector = require(replicatedStorage.rbxts_include.node_modules['@easy-games']['block-engine'].out.client.select['block-selector']).BlockSelector,
		BowConstantsTable = debug.getupvalue(Knit.Controllers.ProjectileController.enableBeam, 8) or {RelX = 0, RelY = 0, RelZ = 0},
		ClickHold = require(replicatedStorage['rbxts_include']['node_modules']['@easy-games']['game-core'].out.client.ui.lib.util['click-hold']).ClickHold,
		Client = Client,
		ClientConstructor = require(replicatedStorage['rbxts_include']['node_modules']['@rbxts'].net.out.client),
		ClientDamageBlock = require(replicatedStorage['rbxts_include']['node_modules']['@easy-games']['block-engine'].out.shared.remotes).BlockEngineRemotes.Client,
		CombatConstant = require(replicatedStorage.TS.combat['combat-constant']).CombatConstant,
		DamageIndicator = Knit.Controllers.DamageIndicatorController.spawnDamageIndicator,
		DefaultKillEffect = require(lplr.PlayerScripts.TS.controllers.global.locker['kill-effect'].effects['default-kill-effect']),
		EnchantMeta = require(replicatedStorage.TS.enchant['enchant-meta']).EnchantMeta,
		EmoteType = require(replicatedStorage.TS.locker.emote['emote-type']).EmoteType,
		GamePlayer = require(replicatedStorage.TS.player['game-player']),
		GameAnimationUtil = require(replicatedStorage.TS.animation['animation-util']).GameAnimationUtil,
		getIcon = function(item, showinv)
			local itemmeta = bedwars.ItemMeta[item.itemType]
			return itemmeta and showinv and itemmeta.image or ''
		end,
		getInventory = function(plr)
			local suc, res = pcall(function()
				return InventoryUtil.getInventory(plr)
			end)
			return suc and res or {
				items = {},
				armor = {}
			}
		end,
		HudAliveCount = require(lplr.PlayerScripts.TS.controllers.global['top-bar'].ui.game['hud-alive-player-counts']).HudAlivePlayerCounts,
		ItemMeta = require(replicatedStorage.TS.item['item-meta']).items,
		KillEffectMeta = require(replicatedStorage.TS.locker['kill-effect']['kill-effect-meta']).KillEffectMeta,
		KillFeedController = Flamework.resolveDependency('client/controllers/game/kill-feed/kill-feed-controller@KillFeedController'),
		Knit = Knit,
		KnockbackUtil = require(replicatedStorage.TS.damage['knockback-util']).KnockbackUtil,
		MageKitUtil = require(replicatedStorage.TS.games.bedwars.kit.kits.mage['mage-kit-util']).MageKitUtil,
		NotificationController = Flamework.resolveDependency('@easy-games/game-core:client/controllers/notification-controller@NotificationController'),
		NametagController = Knit.Controllers.NametagController,
		PartyController = Flamework.resolveDependency('@easy-games/lobby:client/controllers/party-controller@PartyController'),
		ProjectileMeta = require(replicatedStorage.TS.projectile['projectile-meta']).ProjectileMeta,
		QueryUtil = require(replicatedStorage['rbxts_include']['node_modules']['@easy-games']['game-core'].out).GameQueryUtil,
		QueueCard = require(lplr.PlayerScripts.TS.controllers.global.queue.ui['queue-card']).QueueCard,
		QueueMeta = require(replicatedStorage.TS.game['queue-meta']).QueueMeta,
		Roact = require(replicatedStorage['rbxts_include']['node_modules']['@rbxts']['roact'].src),
		RankMeta = require(replicatedStorage.TS.rank['rank-meta']).RankMeta,
		RuntimeLib = require(replicatedStorage['rbxts_include'].RuntimeLib),
		SummonerKitBalance = require(replicatedStorage.TS.games.bedwars.kit.kits.summoner['summoner-kit-balance']).SummonerKitBalance,
		StatusEffectUtil = require(replicatedStorage.TS['status-effect']['status-effect-util']).StatusEffectUtil,
		StatusEffectMeta = require(replicatedStorage.TS['status-effect']['status-effect-type']).StatusEffectType,
		SharedConstants = require(replicatedStorage.TS['shared-constants']).CpsConstants or {},
		SoundList = require(replicatedStorage.TS.sound['game-sound']).GameSound,
		SoundManager = require(replicatedStorage['rbxts_include']['node_modules']['@easy-games']['game-core'].out).SoundManager,
		Store = require(lplr.PlayerScripts.TS.ui.store).ClientStore,
		TeamUpgradeMeta = debug.getupvalue(require(replicatedStorage.TS.games.bedwars['team-upgrade']['team-upgrade-meta']).getTeamUpgradeMetaForQueue, 7) or {},
		UILayers = require(replicatedStorage['rbxts_include']['node_modules']['@easy-games']['game-core'].out).UILayers,
		VisualizerUtils = require(lplr.PlayerScripts.TS.lib.visualizer['visualizer-utils']).VisualizerUtils,
		WeldTable = require(replicatedStorage.TS.util['weld-util']).WeldUtil,
		WinEffectMeta = require(replicatedStorage.TS.locker['win-effect']['win-effect-meta']).WinEffectMeta,
		ZapNetworking = require(lplr.PlayerScripts.TS.lib.network)
	}, {
		__index = function(self, ind)
			rawset(self, ind, Knit.Controllers[ind])
			return rawget(self, ind)
		end
	})
	getgenv().bedwars = bedwars
	store.enchants = setmetatable({}, {
		__index = function(self, plr)
			return {
				async = function()
					if plr and plr.Character then
						for i in plr.Character:GetAttributes() do
							if i:find('StatusEffect_') and not i:find('_stacks') then
								local name = bedwars.StatusEffectMeta[({i:gsub('StatusEffect_', '')})[1]]
								if bedwars.StatusEffectMeta[name] then
									name = bedwars.StatusEffectMeta[name]
									for num = 1, 3 do
										name = name:gsub(`_{num}`, '')
									end

									if bedwars.EnchantMeta[name] then
										return bedwars.EnchantMeta[name].image
									end
								end
							end
						end
					end
					return nil
				end,
			}
		end
	})

	local function createMethodHook(object, method)
		local original = object[method]
		local hooks, order = {}, 0
		local wrapper

		local function sync()
			if #hooks > 0 then
				object[method] = wrapper
			elseif object[method] == wrapper then
				object[method] = original
			end
		end

		wrapper = function(...)
			local index = 0
			local function nextHook(...)
				index += 1
				local hook = hooks[index]
				if hook then
					return hook.Callback(nextHook, ...)
				end
				return original(...)
			end
			return nextHook(...)
		end

		return {
			Add = function(_, id, priority, callback)
				for i = #hooks, 1, -1 do
					if hooks[i].Id == id then
						table.remove(hooks, i)
					end
				end

				order += 1
				local entry = {
					Id = id,
					Priority = priority or 100,
					Order = order,
					Callback = callback,
				}

				table.insert(hooks, entry)
				table.sort(hooks, function(a, b)
					return a.Priority == b.Priority and a.Order < b.Order or a.Priority < b.Priority
				end)
				sync()

				return function()
					for i = #hooks, 1, -1 do
						if hooks[i] == entry then
							table.remove(hooks, i)
						end
					end
					sync()
				end
			end,
			Destroy = function()
				table.clear(hooks)
				sync()
			end,
		}
	end

	bedwars.ProjectileLaunchHook = createMethodHook(bedwars.ProjectileController, 'calculateImportantLaunchValues')
	vape:Clean(function()
		bedwars.ProjectileLaunchHook:Destroy()
	end)

	local function getproto(...)
		local success, res = pcall(debug.getproto, ...)
		return success and res or function() end
	end
	local remoteNames = {
		AfkStatus = getproto(Knit.Controllers.AfkController.KnitStart, 1) or function() end,
		AttackEntity = Knit.Controllers.SwordController.sendServerRequest or function() end,
		BeePickup = Knit.Controllers.BeeNetController.trigger or function() end,
		CannonAim = getproto(Knit.Controllers.CannonController.startAiming, 5) or function() end,
		CannonLaunch = Knit.Controllers.CannonHandController.launchSelf or function() end,
		ConsumeBattery = getproto(Knit.Controllers.BatteryController.onKitLocalActivated, 1) or function() end,
		ConsumeItem = getproto(Knit.Controllers.ConsumeController.onEnable, 1) or function() end,
		ConsumeSoul = Knit.Controllers.GrimReaperController.consumeSoul or function() end,
		ConsumeTreeOrb = getproto(Knit.Controllers.EldertreeController.createTreeOrbInteraction, 1) or function() end,
		DepositPinata = getproto(getproto(Knit.Controllers.PiggyBankController.KnitStart, 2), 5) or function() end,
		DragonBreath = getproto(Knit.Controllers.VoidDragonController.onKitLocalActivated, 5) or function() end,
		DragonEndFly = getproto(Knit.Controllers.VoidDragonController.flapWings, 1) or function() end,
		DragonFly = Knit.Controllers.VoidDragonController.flapWings or function() end,
		DropItem = Knit.Controllers.ItemDropController.dropItemInHand or function() end,
		EquipItem = getproto(require(replicatedStorage.TS.entity.entities['inventory-entity']).InventoryEntity.equipItem, 4) or function() end,
		FireProjectile = debug.getupvalue(Knit.Controllers.ProjectileController.launchProjectileWithValues, 2) or function() end,
		GroundHit = Knit.Controllers.FallDamageController.KnitStart or function() end,
		GuitarHeal = Knit.Controllers.GuitarController.performHeal or function() end,
		HannahKill = getproto(Knit.Controllers.HannahController.registerExecuteInteractions, 1) or function() end,
		HarvestCrop = getproto(getproto(Knit.Controllers.CropController.KnitStart, 4), 1) or function() end,
		KaliyahPunch = getproto(Knit.Controllers.DragonSlayerController.onKitLocalActivated, 1) or function() end,
		MageSelect = getproto(Knit.Controllers.MageController.registerTomeInteraction, 1) or function() end,
		MinerDig = getproto(Knit.Controllers.MinerController.setupMinerPrompts, 1) or function() end,
		PickupItem = Knit.Controllers.ItemDropController.checkForPickup or function() end,
		PickupMetal = getproto(Knit.Controllers.HiddenMetalController.onKitLocalActivated, 4) or function() end,
		ReportPlayer = require(lplr.PlayerScripts.TS.controllers.global.report['report-controller']).default.reportPlayer or function() end,
		ResetCharacter = getproto(Knit.Controllers.ResetController.createBindable, 1) or function() end,
		SpawnRaven = getproto(Knit.Controllers.RavenController.KnitStart, 1) or function() end,
		SummonerClawAttack = Knit.Controllers.SummonerClawHandController.attack or function() end,
		WarlockTarget = getproto(Knit.Controllers.WarlockStaffController.KnitStart, 2) or function() end
	}

	local packages = httpService:JSONDecode(downloadFile('catrewrite/profiles/packages.json'))	
	local function dumpRemote(tab)
		if not tab then return '' end
		local ind
		for i, v in tab do
			if v == 'Client' then
				ind = i
				break
			end
		end
		return ind and tab[ind + 1] or ''
	end

	for i, v in remoteNames do
		local remote = dumpRemote(debug.getconstants(v))
		if remote == '' and packages.remotes[i] then
			remote = packages.remotes[i]
		end
		if remote == '' then
			notif('Vape', 'Failed to grab remote ('..i..')', 10, 'alert')
            task.wait(2)
            notif('Vape', `Sending packets to server for {i}`, 6)
            -- todo send to server
        end
		remotes[i] = remote
	end
    getgenv().remotes = remotes

	OldBreak = bedwars.BlockController.isBlockBreakable
	OldHit = bedwars.BlockBreaker.hitBlock

	bedwars.BlockBreaker.hitBlock = function(...)
        store.lastHit = tick()
        return OldHit(...)
    end

	Client.Get = function(self, remoteName)
		local call = OldGet(self, remoteName)
		if remoteName == remotes.AttackEntity then
		return {
			instance = call.instance,
			SendToServer = function(_, attackTable, ...)
			    local suc, plr = pcall(function()
					return playersService:GetPlayerFromCharacter(attackTable.entityInstance)
				end)
				local selfpos = attackTable.validate.selfPosition.value
				local targetpos = attackTable.validate.targetPosition.value
				store.attackReach = ((selfpos - targetpos).Magnitude * 100) // 1 / 100
				store.attackReachUpdate = tick() + 1
				if Reach.Enabled or HitBoxes.Enabled then
					attackTable.validate.raycast = attackTable.validate.raycast or {}
					attackTable.validate.selfPosition.value += CFrame.lookAt(selfpos, targetpos).LookVector * math.max((selfpos - targetpos).Magnitude - 14.399, 0)
				end
				if suc and plr then
					if not select(2, whitelist:get(plr)) then return end
				end
				return call:SendToServer(attackTable, ...)
		    end
		}
		elseif remoteName == 'StepOnSnapTrap' and TrapDisabler.Enabled then
			return {SendToServer = function() end}
		end
		return call
	end

	bedwars.BlockController.isBlockBreakable = function(self, breakTable, plr)
		local obj = bedwars.BlockController:getStore():getBlockAt(breakTable.blockPosition)

		if obj and obj.Name == 'bed' then
			for _, plr in playersService:GetPlayers() do
				if obj:GetAttribute('Team'..(plr:GetAttribute('Team') or 0)..'NoBreak') and not select(2, whitelist:get(plr)) then
					return false
				end
			end
		end

		return OldBreak(self, breakTable, plr)
	end

	local cache, blockhealthbar = {}, {blockHealth = -1, breakingBlockPosition = Vector3.zero}
	store.blockPlacer = bedwars.BlockPlacer.new(bedwars.BlockEngine, 'wool_white')

	local function getBlockHealth(block, blockpos)
		local blockdata = bedwars.BlockController:getStore():getBlockData(blockpos)
		return (blockdata and (blockdata:GetAttribute('1') or blockdata:GetAttribute('Health')) or block:GetAttribute('Health'))
	end

	getBlockHits = function(block, blockpos)
		if not block then return 0 end
		local breaktype = bedwars.ItemMeta[block.Name].block.breakType
		local tool = store.tools[breaktype]
		tool = tool and bedwars.ItemMeta[tool.itemType].breakBlock[breaktype] or 2
		return getBlockHealth(block, bedwars.BlockController:getBlockPosition(blockpos)) / tool
	end

	--[[
		Pathfinding using a luau version of dijkstra's algorithm
		Source: https://stackoverflow.com/questions/39355587/speeding-up-dijkstras-algorithm-to-solve-a-3d-maze
	]]
	local function isMinable(pos)
		for _, side in {Vector3.new(0, 3, 0), Vector3.new(3, 0, 0), Vector3.new(0, 0, 3)} do
			side = pos + side
			local block = getPlacedBlock(side)
			if block and (block:GetAttribute("PlacedByUserId") or 0) ~= 0 then
				return false
			end
		end
		return true
	end
	local function calculatePath(target, blockpos, method, angle, wallcheck)
		local visited, unvisited, distances, air, path = {}, {{0, blockpos}}, {[blockpos] = 0}, {}, {}

		for _ = 1, 10000 do
			local _, node = next(unvisited)
			if not node then break end
			table.remove(unvisited, 1)
			visited[node[2]] = true

			for _, side in sides do
				side = node[2] + side
				if visited[side] then continue end

				local block = getPlacedBlock(side)
				if not block or block:GetAttribute('NoBreak') or block == target then
					if not block then
						air[node[2]] = true
					end
					continue
				end

				if math.acos((gameCamera.CFrame.LookVector * Vector3.new(1, 0, 1)):Dot(((block.Position - entitylib.character.RootPart.Position) * Vector3.new(1, 0, 1)).Unit)) > (math.rad(angle) / 2) then
					continue
				end

				local curdist = (method and method(block, side) or getBlockHits(block, side)) + node[1]
				if curdist < (distances[side] or math.huge) then
					table.insert(unvisited, {curdist, side})
					distances[side] = curdist
					path[side] = node[2]
				end
			end
		end

		local pos, cost = nil, math.huge
		for node in air do
			if distances[node] < cost and (not wallcheck or isMinable(node)) then
				pos, cost = node, distances[node]
			end
		end

		if pos then
			cache[blockpos] = {
				pos,
				cost,
				path,
			}
			return pos, cost, path
		end
		return nil
	end

	bedwars.placeBlock = function(pos, item)
		if getItem(item) then
			store.blockPlacer.blockType = item
			return store.blockPlacer:placeBlock(bedwars.BlockController:getBlockPosition(pos))
		end
	end

	bedwars.breakBlock = function(block, effects, anim, customHealthbar, visualise, sort, angle, wallcheck)
		if lplr:GetAttribute('DenyBlockBreak') or not entitylib.isAlive or InfiniteFly.Enabled then return end

		local handler = bedwars.BlockController:getHandlerRegistry():getHandler(block.Name)
		local cost, pos, target, path = math.huge, nil, nil, nil

		for _, v in (handler and handler:getContainedPositions(block) or {block.Position / 3}) do
			local dpos, dcost, dpath = calculatePath(block, v * 3, sort, angle or 360, wallcheck)
			if dpos and dcost < cost then
				cost, pos, target, path = dcost, dpos, v * 3, dpath
			end
		end

		if pos then
			if (entitylib.character.RootPart.Position - pos).Magnitude > 30 then return end
			local dblock, dpos = getPlacedBlock(pos)
			if not dblock then return end

			if (workspace:GetServerTimeNow() - bedwars.SwordController.lastAttack) > 0.4 then
				local breaktype = dblock.Name == 'gumdrop_bounce_pad' and 'stone' or bedwars.ItemMeta[dblock.Name].block.breakType
				local tool = store.tools[breaktype]
				if tool then
					if visualise then
						local hotbar = getHotbar(tool.tool)
						if hotbar then
							hotbarSwitch(hotbar)
						end
					else
						switchItem(tool.tool)
					end
				end
			end

			if blockhealthbar.blockHealth == -1 or dpos ~= blockhealthbar.breakingBlockPosition then
				blockhealthbar.blockHealth = getBlockHealth(dblock, dpos)
				blockhealthbar.breakingBlockPosition = dpos
			end

			bedwars.ClientDamageBlock:Get('DamageBlock'):CallServerAsync({
				blockRef = {blockPosition = dpos},
				hitPosition = pos,
				hitNormal = Vector3.FromNormalId(Enum.NormalId.Top)
			}):andThen(function(result)
				if result then
					if result == 'cancelled' then
						store.damageBlockFail = tick() + 1
						return
					end

					if effects then
						local blockdmg = (blockhealthbar.blockHealth - (result == 'destroyed' and 0 or getBlockHealth(dblock, dpos)))
						customHealthbar = customHealthbar or bedwars.BlockBreaker.updateHealthbar
						customHealthbar(bedwars.BlockBreaker, {blockPosition = dpos}, blockhealthbar.blockHealth, dblock:GetAttribute('MaxHealth'), blockdmg, dblock)
						blockhealthbar.blockHealth = math.max(blockhealthbar.blockHealth - blockdmg, 0)

						if blockhealthbar.blockHealth <= 0 then
							bedwars.BlockBreaker.breakEffect:playBreak(dblock.Name, dpos, lplr)
							bedwars.BlockBreaker.healthbarMaid:DoCleaning()
							blockhealthbar.breakingBlockPosition = Vector3.zero
						else
							bedwars.BlockBreaker.breakEffect:playHit(dblock.Name, dpos, lplr)
						end
					end

					if anim then
						local animation = bedwars.AnimationUtil:playAnimation(lplr, bedwars.BlockController:getAnimationController():getAssetId(1))
						bedwars.ViewmodelController:playAnimation(15)
						task.wait(0.3)
						animation:Stop()
						animation:Destroy()
					end
				end
			end)

			if effects then
				return pos, path, target
			end
		end
		return nil
	end

	for _, v in Enum.NormalId:GetEnumItems() do
		table.insert(sides, Vector3.FromNormalId(v) * 3)
	end

	local function updateStore(new, old)
		if new.Bedwars ~= old.Bedwars then
			store.equippedKit = new.Bedwars.kit ~= 'none' and new.Bedwars.kit or ''
		end

		if new.Game ~= old.Game then
			store.matchState = new.Game.matchState
			store.queueType = new.Game.queueType or 'bedwars_test'
		end

		if new.Inventory ~= old.Inventory then
			local newinv = (new.Inventory and new.Inventory.observedInventory or {inventory = {}})
			local oldinv = (old.Inventory and old.Inventory.observedInventory or {inventory = {}})
			store.inventory = newinv

			if newinv ~= oldinv then
				vapeEvents.InventoryChanged:Fire()
			end

			if newinv.inventory.items ~= oldinv.inventory.items then
				vapeEvents.InventoryAmountChanged:Fire()
				store.tools.sword = getSword()
				for _, v in {'stone', 'wood', 'wool'} do
					store.tools[v] = getTool(v)
				end
			end

			if newinv.inventory.hand ~= oldinv.inventory.hand then
				local currentHand, toolType = new.Inventory.observedInventory.inventory.hand, ''
				if currentHand then
					local handData = bedwars.ItemMeta[currentHand.itemType]
					if handData then
						toolType = handData.sword and 'sword' or handData.block and 'block' or currentHand.itemType:find('bow') and 'bow'
					end
				end

				store.hand = {
					tool = currentHand and currentHand.tool,
					amount = currentHand and currentHand.amount or 0,
					toolType = toolType
				}
			end
		end
	end

	local storeChanged = bedwars.Store.changed:connect(updateStore)
	updateStore(bedwars.Store:getState(), {})

	for _, event in {'MatchEndEvent', 'EntityDeathEvent', 'BedwarsBedBreak', 'BalloonPopped', 'AngelProgress', 'GrapplingHookFunctions'} do
		if not vape.Connections then return end
		bedwars.Client:WaitFor(event):andThen(function(connection)
			vape:Clean(connection:Connect(function(...)
				vapeEvents[event]:Fire(...)
			end))
		end)
	end

	vape:Clean(bedwars.ZapNetworking.EntityDamageEventZap.On(function(...)
		local a = {
			entityInstance = ...,
			damage = select(2, ...),
			damageType = select(3, ...),
			fromPosition = select(4, ...),
			fromEntity = select(5, ...),
			knockbackMultiplier = select(6, ...),
			knockbackId = select(7, ...),
			disableDamageHighlight = select(13, ...)
		}
		vapeEvents.EntityDamageEvent:Fire(a)
	end))
	
	vape:Clean(workspace.ChildAdded:Connect(function(projectile)
		task.delay(0, function()
			if projectile and projectile.Parent and entitylib.isAlive and projectile:GetAttribute('ProjectileShooter') == lplr.UserId then
				table.insert(store.selfProjectiles, projectile)
				projectile.Destroying:Once(function()
					local index = table.find(store.selfProjectiles, projectile)
					if index then
						table.remove(store.selfProjectiles, index)
					end
				end)
			end
		end)
	end))

	for _, event in {'BreakBlockEvent'} do
		vape:Clean(bedwars.ZapNetworking[event..'Zap'].On(function(...)
			local data = {
				blockRef = {
					blockPosition = ...,
				},
				player = select(5, ...)
			}
			for i, v in cache do
				if ((data.blockRef.blockPosition * 3) - v[1]).Magnitude <= 30 then
					table.clear(v[3])
					table.clear(v)
					cache[i] = nil
				end
			end
			vapeEvents[event]:Fire(data)
		end))
	end

	store.blocks = collection('block', vape)
	store.shop = collection({'BedwarsItemShop', 'TeamUpgradeShopkeeper'}, vape, function(tab, obj)
		table.insert(tab, {
			Id = obj.Name,
			RootPart = obj,
			Shop = obj:HasTag('BedwarsItemShop'),
			Upgrades = obj:HasTag('TeamUpgradeShopkeeper')
		})
	end)
	store.enchant = collection({'enchant-table', 'broken-enchant-table'}, vape, nil, function(tab, obj, tag)
		if obj:HasTag('enchant-table') and tag == 'broken-enchant-table' then return end
		obj = table.find(tab, obj)
		if obj then
			table.remove(tab, obj)
		end
	end)

	local kills = sessioninfo:AddItem('Kills')
	local beds = sessioninfo:AddItem('Beds')
	local wins = sessioninfo:AddItem('Wins')
	local games = sessioninfo:AddItem('Games')
	sessioninfo:AddItem('Cheater List', '', function()
		local text = ''
		for _, plr in playersService:GetPlayers() do
			if CheatersFlagged[plr] then
				text = text..'\n'..(plr.DisplayName ~= plr.Name and plr.DisplayName..' ('..plr.Name..')' or plr.Name)
			end
		end

		return text
	end, false)

	local mapname = 'Unknown'
	sessioninfo:AddItem('Map', 0, function()
		return mapname
	end, false)

	task.delay(1, function()
		games:Increment()
	end)

	task.spawn(function()
		pcall(function()
			repeat task.wait() until store.matchState ~= 0 or vape.Loaded == nil
			if vape.Loaded == nil then return end
			store.map = waitForChildYield(workspace, 9e9, 'Map', 'Worlds'):GetChildren()[1]
			mapname = store.map.Name
			mapname = string.gsub(string.split(mapname, '_')[2] or mapname, '-', '') or 'Blank'
			if store.map then
				vape:Clean(store.map.Blocks.ChildAdded:Connect(function(v) -- bedwars game is so bad bro 😭 how did you even break this event
					task.delay(0, function()
						if v:GetAttribute('Block') and (v:GetAttribute('PlacedByUserId') or 0) ~= 0 then
							local data = {
								blockRef = {
									blockPosition = v.Position / 3,
								},
								player = playersService:GetPlayerByUserId(v:GetAttribute('PlacedByUserId')),
							}
							for i, v in cache do
								if ((data.blockRef.blockPosition * 3) - v[1]).Magnitude <= 30 then
									table.clear(v[3])
									table.clear(v)
									cache[i] = nil
								end
							end
							vapeEvents.PlaceBlockEvent:Fire(data)
						end
					end)
				end))
			end
		end)
	end)

	vape:Clean(vapeEvents.BedwarsBedBreak.Event:Connect(function(bedTable)
		if bedTable.player and bedTable.player.UserId == lplr.UserId then
			beds:Increment()
		end
	end))

	vape:Clean(vapeEvents.MatchEndEvent.Event:Connect(function(winTable)
		if (bedwars.Store:getState().Game.myTeam or {}).id == winTable.winningTeamId or lplr.Neutral then
			wins:Increment()
		end
	end))

	vape:Clean(vapeEvents.EntityDeathEvent.Event:Connect(function(deathTable)
		local killer = playersService:GetPlayerFromCharacter(deathTable.fromEntity)
		local killed = playersService:GetPlayerFromCharacter(deathTable.entityInstance)
		if not killed or not killer then return end

		if killed ~= lplr and killer == lplr then
			kills:Increment()
		end
	end))

	task.spawn(function()
		local rayParams = RaycastParams.new()
		rayParams.FilterType = Enum.RaycastFilterType.Include
		rayParams.FilterDescendantsInstances = {workspace:WaitForChild('Map', 9e9)}
		store.airRay = rayParams

		repeat
			if entitylib.isAlive then
				entitylib.character.AirTime = workspace:Raycast((store.rootpart or entitylib.character.RootPart).Position, Vector3.new(0, -4.5, 0), rayParams) and tick() or entitylib.character.AirTime
			end

			for _, v in entitylib.List do
				v.LandTick = math.abs(v.RootPart.Velocity.Y) < 0.1 and v.LandTick or tick()
				if (tick() - v.LandTick) > 0.2 and v.Jumps ~= 0 then
					v.Jumps = 0
					v.Jumping = false
				end
			end
			task.wait()
		until vape.Loaded == nil
	end)

	pcall(function()
		if getthreadidentity and setthreadidentity then
			local old = getthreadidentity()
			setthreadidentity(2)

			bedwars.Shop = require(replicatedStorage.TS.games.bedwars.shop['bedwars-shop']).BedwarsShop
			bedwars.ShopItems = debug.getupvalue(debug.getupvalue(bedwars.Shop.getShopItem, 1), 2)
			bedwars.Shop.getShopItem('iron_sword', lplr)

			setthreadidentity(old)
			store.shopLoaded = true
		else
			task.spawn(function()
				repeat
					task.wait(0.1)
				until vape.Loaded == nil or bedwars.AppController:isAppOpen('BedwarsItemShopApp')

				bedwars.Shop = require(replicatedStorage.TS.games.bedwars.shop['bedwars-shop']).BedwarsShop
				bedwars.ShopItems = debug.getupvalue(debug.getupvalue(bedwars.Shop.getShopItem, 1), 2)
				store.shopLoaded = true
			end)
		end
	end)

	vape:Clean(function()
		getgenv().restorefunction = oldrf
		pcall(function() restorefunction = oldrf end)
		Client.Get = OldGet
		bedwars.BlockController.isBlockBreakable = OldBreak
		store.blockPlacer:disable()
		for _, v in vapeEvents do
			v:Destroy()
		end
		for _, v in cache do
			table.clear(v[3])
			table.clear(v)
		end
		table.clear(store.blockPlacer)
		table.clear(vapeEvents)
		table.clear(bedwars)
		table.clear(store)
		table.clear(cache)
		table.clear(sides)
		table.clear(remotes)
		table.clear(hookedfunctionstable)
		storeChanged:disconnect()
		storeChanged = nil
		oldrf = nil
	end)
end)

for _, v in {'Anti Ragdoll', 'Trigger Bot', 'Silent Aim', 'Auto Rejoin', 'Rejoin', 'Disabler', 'Timer', 'Server Hop', 'Mouse TP', 'Murder Mystery'} do
	vape:Remove(v)
end

local AntiFallDirection
local Fly
local LongJump
local Attacking

--[[
    Combat
]]--

task.defer(function()
	run(function()
		local AimAssist
		local AimMode
		local Mode
		local Targets
		local Sort
		local AimPart
		local AimSpeed
		local Shake
		local Distance
		local AngleSlider
		local StrafeIncrease
		local BlockBreak
		local KillauraTarget
		local ClickAim
		local Mouse
		local Limit
		
		local function ease(t)
			return t < 0.5 and 4 * t * t * t or 1 - math.pow(-2 * t + 2, 3) / 2
		end
		
		local cache = {}
		local function getMousePosition()
			if inputService.TouchEnabled then
				return gameCamera.ViewportSize / 2
			end
			return inputService.GetMouseLocation(inputService)
		end
		
		local function getAim(ent)
			if AimPart.Value == 'Closest' then
				if not cache[ent.Character] then
					cache[ent.Character] = ent.Character:GetChildren()
				end
				local localPosition, magnitude, part = getMousePosition(), 9e9, nil
				for _, v in cache[ent.Character] do
					if v and v.Parent and v:IsA('BasePart') then
						local position, vis = gameCamera.WorldToViewportPoint(gameCamera, v.Position)
		
						if vis then
							local mag = (localPosition - Vector2.new(position.x, position.y)).Magnitude
		
							if mag < magnitude then
								magnitude = mag
								part = v
							end
						end
					end
				end
				if part then
					return part.Position
				end
			end
			return ent.RootPart.Position
		end
		
		local started, lasttarget = 0, nil
		local aimfuncs = {
			Simple = function(localcframe, ent, fps)
				local rng = Random.new()
				local speed = (AimSpeed.Value + (StrafeIncrease.Enabled and (inputService:IsKeyDown(Enum.KeyCode.A) or inputService:IsKeyDown(Enum.KeyCode.D)) and 10 or 0))
		
				return localcframe:Lerp(CFrame.lookAt(localcframe.p, getAim(ent) + Vector3.new((rng:NextNumber() - 0.5) * Shake.Value * fps, (rng:NextNumber() - 0.5) * Shake.Value * fps, (rng:NextNumber() - 0.5) * Shake.Value * fps)), speed * fps), speed
			end,
			Adaptive = function(localcframe, ent, fps)
				local prog, rng = ease(math.min(tick() - started, 1)), Random.new()
				local speed = (AimSpeed.Value * 0.1 * prog) + (1 - prog) + (StrafeIncrease.Enabled and (inputService:IsKeyDown(Enum.KeyCode.A) or inputService:IsKeyDown(Enum.KeyCode.D)) and 10 or 5)
				return localcframe:Lerp(CFrame.lookAt(localcframe.p, getAim(ent) + Vector3.new((rng:NextNumber() - 0.5) * Shake.Value * fps, (rng:NextNumber() - 0.5) * Shake.Value * fps, (rng:NextNumber() - 0.5) * Shake.Value * fps)), speed * fps), speed
			end
		}
		
		local function GetTarget()
			if lasttarget then
				local localPosition = entitylib.character.RootPart.Position
				if not lasttarget or not lasttarget.RootPart or not lasttarget.Humanoid or not lasttarget.Humanoid.Health or lasttarget.Humanoid.Health <= 0 then
					return false
				end
				if (localPosition - lasttarget.RootPart.Position).Magnitude > Distance.Value then
					return false
				end
				if Targets.Walls.Enabled and entitylib.Wallcheck(localPosition, lasttarget.RootPart.Position, Targets.Walls.Enabled) then
					return false
				end
				return lasttarget
			end
		
			return false
		end
		
		local function getAttackData()
			if Mouse.Enabled and not inputService:IsMouseButtonPressed(0) and (tick() - bedwars.SwordController.lastSwing) > 0.15 then
				return false
			end
			if ClickAim.Enabled and (tick() - bedwars.SwordController.lastSwing) > 0.3 then
				return false
			end
			if BlockBreak.Enabled and (tick() - store.lastHit) < 0.3 then
				return false
			end
			if Limit.Enabled and store.hand.toolType ~= 'sword' then
				return false
			end
		
			if (tick() - started) > 1 or not lasttarget or not lasttarget.Parent or not lasttarget.Humanoid or lasttarget.Humanoid.Health <= 0 then
				local ent = GetTarget() or KillauraTarget.Enabled and store.KillauraTarget or entitylib.EntityPosition({
					Range = Distance.Value,
					Part = 'RootPart',
					Wallcheck = Targets.Walls.Enabled,
					Players = Targets.Players.Enabled,
					NPCs = Targets.NPCs.Enabled,
					Sort = sortmethods[Sort.Value],
				})
				if ent then
					started = tick()
				end
				lasttarget = ent
			end
			return lasttarget
		end
		
		AimAssist = vape.Categories.Combat:CreateModule({
			Name = 'Aim Assist',
			Function = function(callback)
				if callback then
					local rotate = 0
					
					AimAssist:Clean(runService.PostSimulation:Connect(function(dt)
						if entitylib.isAlive then
							entitylib.character.Humanoid.AutoRotate = tick() > rotate
							local ent = getAttackData()
							if ent then
								local root = entitylib.character.RootPart
								local delta = (ent.RootPart.Position - root.Position)
								local localfacing = root.CFrame.LookVector * Vector3.new(1, 0, 1)
								local angle = math.acos(localfacing:Dot((delta * Vector3.new(1, 0, 1)).Unit))
								if angle >= (math.rad(AngleSlider.Value) / 2) then
									return
								end
								targetinfo.Targets[ent] = tick() + 1
		
								local cframe, speed = aimfuncs[Mode.Value](gameCamera.CFrame, ent, dt)
								if AimMode.Value == 'First person' or AimMode.Value == 'Dynamic' and entitylib.character.Head.LocalTransparencyModifier == 1 then
									gameCamera.CFrame = cframe
								elseif AimMode.Value == 'Third person' or AimMode.Value == 'Dynamic' and entitylib.character.Head.LocalTransparencyModifier ~= 1 then
									cframe, speed = aimfuncs[Mode.Value](root.CFrame, ent, dt)
									entitylib.character.Humanoid.AutoRotate = false
									root.CFrame = CFrame.lookAlong(root.Position, cframe.LookVector * Vector3.new(1, 0, 1))
									rotate = tick() + 0.1
								elseif AimMode.Value == 'Mouse' then
									local viewport = gameCamera:WorldToViewportPoint(cframe.Position)
									local pos = (Vector2.new(viewport.X, viewport.Y) - inputService:GetMouseLocation()) * (speed / 15)
									mousemoverel(pos.X, pos.Y)
								end
							end
						end
					end))
				end
			end,
			Tooltip = 'Smoothly aims to closest valid target with sword'
		})
		local modes = {}
		for i in aimfuncs do
			table.insert(modes, i)
		end
		AimMode = AimAssist:CreateDropdown({
			Name = 'Aim perspective',
			Tooltip = 'First person - Uses your camera to aim\nThird person - Moves your character to where your supposed to look\nMouse - Moves your mouse & camera\nDynamic - Uses first person mode if ur in first person, and uses third person if ur in third person',
			List = {'First person', 'Third person', 'Mouse', 'Dynamic'},
			Default = 'First person'
		})
		Mode = AimAssist:CreateDropdown({
			Name = 'Mode',
			List = modes,
			Tooltip = 'Simple - Smooth aiming\nAdaptive - Advanced tracking with adaptive behavior',
			Default = modes[1],
		})
		Targets = AimAssist:CreateTargets({
			Players = true,
			Walls = true,
		})
		local methods = {'Damage', 'Distance'}
		for i in sortmethods do
			if not table.find(methods, i) then
				table.insert(methods, i)
			end
		end
		ClickAim = AimAssist:CreateToggle({
			Name = 'Click aim',
			Default = true,
		})
		Mouse = AimAssist:CreateToggle({Name = 'Require mouse down'})
		StrafeIncrease = AimAssist:CreateToggle({Name = 'Strafe increase'})
		BlockBreak = AimAssist:CreateToggle({Name = 'Check block break'})
		KillauraTarget = AimAssist:CreateToggle({Name = 'Use killaura target'})
		AimSpeed = AimAssist:CreateSlider({
			Name = 'Aim speed',
			Min = 1,
			Max = 20,
			Default = 6,
		})
		Distance = AimAssist:CreateSlider({
			Name = 'Distance',
			Min = 1,
			Max = 30,
			Default = 30,
			Suffix = function(val)
				return val == 1 and 'stud' or 'studs'
			end,
		})
		Shake = AimAssist:CreateSlider({
			Name = 'Shake',
			Min = 0,
			Max = 100,
			Default = 0,
			Tooltip = 'Adds random jitter to simulate human aim',
		})
		AngleSlider = AimAssist:CreateSlider({
			Name = 'Max angle',
			Min = 1,
			Max = 360,
			Default = 70,
		})
		Limit = AimAssist:CreateToggle({
			Name = 'Limit to items',
			Tooltip = 'Only attacks when sword is held',
		})
		Sort = AimAssist:CreateDropdown({
			Name = 'Target mode',
			List = methods,
			Default = 'Angle',
		})
		AimPart = AimAssist:CreateDropdown({
			Name = 'Target area',
			List = {'Center', 'Closest'},
			Default = 'Center',
		})
	end)

	run(function()
		local AutoClicker
		local CPS
		local BlockCPS
		local Thread
		
		local function AutoClick()
			if Thread then
				task.cancel(Thread)
			end
		
			Thread = task.delay(1 / (store.hand.toolType == 'block' and BlockCPS or CPS).GetRandomValue(), function()
				repeat
					if not bedwars.AppController:isLayerOpen(bedwars.UILayers.MAIN) then
						local blockPlacer = bedwars.BlockPlacementController.blockPlacer
						if store.hand.toolType == 'block' and blockPlacer then
							if canDebug then
								if inputService.TouchEnabled then
									task.spawn(function()
										blockPlacer:autoBridge(workspace:GetServerTimeNow() - bedwars.KnockbackController:getLastKnockbackTime() >= 0.2 )
									end)
								else
									local old = bedwars.BlockCpsController.lastPlaceTimestamp
									if (workspace:GetServerTimeNow() - bedwars.BlockCpsController.lastPlaceTimestamp) >= ((1 / 12) * 0.5) then
										local mouseinfo = blockPlacer.clientManager:getBlockSelector():getMouseInfo(0)
										if mouseinfo and mouseinfo.placementPosition == mouseinfo.placementPosition then
											local suc, res = pcall(function()
												return bedwars.placeBlock(({getPlacedBlock(mouseinfo.placementPosition)})[2])
											end)
											if not suc then
												print(res)
											end
											if bedwars.BlockCpsController.lastPlaceTimestamp == old then
												bedwars.BlockCpsController.lastPlaceTimestamp = workspace:GetServerTimeNow()
											end
										end
									end
								end
							end
						elseif store.hand.toolType == 'sword' then
							bedwars.SwordController:swingSwordAtMouse(0.39)
						end
					end
		
					task.wait(1 / (store.hand.toolType == 'block' and BlockCPS or CPS).GetRandomValue()) --
				until not AutoClicker.Enabled
			end)
		end
		
		AutoClicker = vape.Categories.Combat:CreateModule({
			Name = 'Auto Clicker',
			Function = function(callback)
				if callback then
					AutoClicker:Clean(inputService.InputBegan:Connect(function(input)
						if table.find({Enum.UserInputType.MouseButton1, Enum.UserInputType.Touch},input.UserInputType) then
							AutoClick()
						end
					end))
		
					AutoClicker:Clean(inputService.InputEnded:Connect(function(input)
						if table.find({Enum.UserInputType.MouseButton1, Enum.UserInputType.Touch},input.UserInputType) and Thread then
							task.cancel(Thread)
							Thread = nil
						end
					end))
		
					if inputService.TouchEnabled then
						for _, v in { '2', '5' } do
							pcall(function()
								AutoClicker:Clean(lplr.PlayerGui.MobileUI[v].MouseButton1Down:Connect(AutoClick))
								AutoClicker:Clean(lplr.PlayerGui.MobileUI[v].MouseButton1Up:Connect(function()
									if Thread then
										task.cancel(Thread)
										Thread = nil
									end
								end))
							end)
						end
					end
				else
					if Thread then
						task.cancel(Thread)
						Thread = nil
					end
				end
			end,
			Tooltip = 'Hold attack button to automatically click',
		})
		CPS = AutoClicker:CreateTwoSlider({
			Name = 'CPS',
			Min = 1,
			Max = 9,
			DefaultMin = 7,
			DefaultMax = 7,
		})
		AutoClicker:CreateToggle({
			Name = 'Place Blocks',
			Default = true,
			Function = function(callback)
				if BlockCPS and BlockCPS.Object then
					BlockCPS.Object.Visible = callback
				end
			end,
		})
		BlockCPS = AutoClicker:CreateTwoSlider({
			Name = 'Block CPS',
			Min = 1,
			Max = 20,
			DefaultMin = 12,
			DefaultMax = 12,
			Darker = true,
		})
	end)

	run(function()
		local old
		vape.Categories.Combat:CreateModule({
			Name = 'No Click Delay',
			Function = function(callback)
				if callback then
					old = clonefunction(bedwars.SwordController.isClickingTooFast)
					hookfunction(bedwars.SwordController.isClickingTooFast, function(self)
						self.lastSwing = os.clock()
						return false
					end)
				else
					restorefunction(old, bedwars.SwordController.isClickingTooFast)
					old = nil
				end
			end
		})
	end)

	run(function()
		local Reach
		local SwordRange
		Reach = vape.Categories.Combat:CreateModule({
			Name = 'Reach',
			Tooltip = 'Allows you to attack further',
			Function = function(callback)
				bedwars.CombatConstant.RAYCAST_SWORD_CHARACTER_DISTANCE = callback and SwordRange.Value + 2 or 14.4
			end
		})
		SwordRange = Reach:CreateSlider({
			Name = 'Sword Range',
			Min = 1,
			Max = 18,
			Default = 18,
			Decimal = 5,
			Darker = true,
			Suffix = function(val)
				return val <= 1 and 'stud' or 'studs'
			end,
			Function = function(val)
				bedwars.CombatConstant.RAYCAST_SWORD_CHARACTER_DISTANCE = Reach.Enabled and val or 14.4
			end,
		})
	end)

	run(function()
		local Sprint
		local old
		
		Sprint = vape.Categories.Combat:CreateModule({
			Name = 'Sprint',
			Function = function(callback)
				if callback then
					if inputService.TouchEnabled then 
						pcall(function() 
							lplr.PlayerGui.MobileUI['4'].Visible = false 
						end) 
					end
					old = clonefunction(bedwars.SprintController.stopSprinting)
					hookfunction(bedwars.SprintController.stopSprinting, function(...)
						local call = old(...)
						bedwars.SprintController:startSprinting()
						return call
					end)
					Sprint:Clean(entitylib.Events.LocalAdded:Connect(function() 
						task.delay(0.1, function() 
							bedwars.SprintController:stopSprinting() 
						end) 
					end))
					bedwars.SprintController:stopSprinting()
				else
					if inputService.TouchEnabled then 
						pcall(function() 
							lplr.PlayerGui.MobileUI['4'].Visible = true 
						end) 
					end
					restorefunction(old,bedwars.SprintController.stopSprinting)
					old = nil
				end
			end,
			Tooltip = 'Sets your sprinting to true.'
		})
	end)

	run(function()
		local TriggerBot
		local CPS
		local rayParams = RaycastParams.new()
		
		TriggerBot = vape.Categories.Combat:CreateModule({
			Name = 'Trigger Bot',
			Function = function(callback)
				if callback then
					repeat
						local doAttack
						if not bedwars.AppController:isLayerOpen(bedwars.UILayers.MAIN) then
							if entitylib.isAlive and store.hand.toolType == 'sword' and bedwars.DaoController.chargingMaid == nil then
								local attackRange = bedwars.ItemMeta[store.hand.tool.Name].sword.attackRange
								rayParams.FilterDescendantsInstances = {lplr.Character}
		
								local unit = lplr:GetMouse().UnitRay
								local localPos = entitylib.character.RootPart.Position
								local rayRange = (attackRange or 14.4)
								local ray = bedwars.QueryUtil:raycast(unit.Origin, unit.Direction * 200, rayParams)
								if ray and (localPos - ray.Instance.Position).Magnitude <= rayRange then
									local limit = (attackRange)
									for _, ent in entitylib.List do
										doAttack = ent.Targetable and ray.Instance:IsDescendantOf(ent.Character) and (localPos - ent.RootPart.Position).Magnitude <= rayRange
										if doAttack then
											break
										end
									end
								end
		
								doAttack = doAttack or bedwars.SwordController:getTargetInRegion(attackRange or 3.8 * 3, 0)
								if doAttack then
									bedwars.SwordController:swingSwordAtMouse()
								end
							end
						end
		
						task.wait(doAttack and 1 / CPS.GetRandomValue() or 0.016)
					until not TriggerBot.Enabled
				end
			end,
			Tooltip = 'Automatically swings when hovering over a entity'
		})
		CPS = TriggerBot:CreateTwoSlider({
			Name = 'CPS',
			Min = 1,
			Max = 9,
			DefaultMin = 7,
			DefaultMax = 7
		})
	end)

	run(function()
		local Velocity
		local Horizontal
		local Vertical
		local Chance
		local TargetCheck
		local rand, old = Random.new()
		
		Velocity = vape.Categories.Combat:CreateModule({
			Name = 'Velocity',
			Function = function(callback)
				if callback then
					old = clonefunction(bedwars.KnockbackUtil.applyKnockback)
					hookfunction(bedwars.KnockbackUtil.applyKnockback, function(root, mass, dir, knockback, ...)
						if rand:NextNumber(0, 100) > Chance.Value then return end
						local check = (not TargetCheck.Enabled) or entitylib.EntityPosition({
							Range = 50,
							Part = 'RootPart',
							Players = true
						})
		
						if check then
							knockback = knockback or {}
							if Horizontal.Value == 0 and Vertical.Value == 0 then return end
							knockback.horizontal = (knockback.horizontal or 1) * (Horizontal.Value / 100)
							knockback.vertical = (knockback.vertical or 1) * (Vertical.Value / 100)
						end
						
						return old(root, mass, dir, knockback, ...)
					end)
				else
					restorefunction(old,bedwars.KnockbackUtil.applyKnockback)
					old = nil
				end
			end,
			Tooltip = 'Reduces knockback taken'
		})
		Horizontal = Velocity:CreateSlider({
			Name = 'Horizontal',
			Min = 0,
			Max = 100,
			Default = 0,
			Suffix = '%'
		})
		Vertical = Velocity:CreateSlider({
			Name = 'Vertical',
			Min = 0,
			Max = 100,
			Default = 0,
			Suffix = '%'
		})
		Chance = Velocity:CreateSlider({
			Name = 'Chance',
			Min = 0,
			Max = 100,
			Default = 100,
			Suffix = '%'
		})
		TargetCheck = Velocity:CreateToggle({Name = 'Only when targeting'})
	end)

	run(function()
		local HitFlick
		local Mode
		local Chance
		local TargetCheck
		local rand = Random.new()
		local old = nil
		
		local function rotateY(v, deg)
			local r = math.rad(deg)
			return Vector3.new(v.X * math.cos(r) - v.Z * math.sin(r), 0, v.X * math.sin(r) + v.Z * math.cos(r))
		end
		
		HitFlick = vape.Categories.Combat:CreateModule({
			Name = 'Hit Flick',
			Function = function(callback)
				if callback then
					old = clonefunction(bedwars.KnockbackUtil.applyKnockback)
					hookfunction(bedwars.KnockbackUtil.applyKnockback,function(root, mass, dir, knockback, ...)
						if rand:NextNumber(0, 100) > Chance.Value then
							return old(root, mass, dir, knockback, ...)
						end
						if TargetCheck.Enabled and not entitylib.EntityPosition({
							Range = 22,
							Part = 'RootPart',
							Players = true,
						}) then
							return old(root, mass, dir, knockback, ...)
						end
		
						local velocity = (root.Position * Vector3.new(1, 0, 1)) - Vector3.new(dir.X, 0, dir.Z)
						if velocity.Magnitude < 0.001 then
							return old(root, mass, dir, knockback, ...)
						end
						velocity = velocity.Unit
						local chosen = Mode.Value == 'Random' and ({ 'Left', 'Right', 'Pull' })[rand:NextInteger(1, 3)] or Mode.Value
						local rdir = chosen == 'Pull' and -velocity or table.find({'Left', 'Right'}, chosen) and rotateY(velocity, chosen == 'Left' and 90 or 90) or velocity
						return old(root, mass, Vector3.new(root.Position.X - rdir.X * 100, dir.Y, root.Position.Z - rdir.Z * 100), knockback, ...)
					end)
				else
					restorefunction(old, bedwars.KnockbackUtil.applyKnockback)
					old = nil
				end
			end,
			Tooltip = 'Redirects knockback you receive in a chosen direction.'
		})
		
		Mode = HitFlick:CreateDropdown({
			Name = 'Direction',
			List = {'Left', 'Right', 'Pull', 'Random'},
			Default = 'Random',
			Tooltip = 'Left/Right: deflect sideways 90dg\nPull: go past the attacker\nRandom: pick one each hit',
		})
		Chance = HitFlick:CreateSlider({
			Name = 'Chance',
			Min = 0,
			Max = 100,
			Default = 100,
			Suffix = '%',
			Tooltip = 'Probability the redirect applies per knockback event',
		})
		TargetCheck = HitFlick:CreateToggle({
			Name = 'Only when targeting',
			Tooltip = 'Only redirects knockback when an enemy is within 22 studs',
		})
	end)
end)

--[[
    Blatant
]]--


--[[
    Render
]]--


--[[
    Utility
]]--


--[[
    World
]]--


--[[
    Inventory
]]--

--[[
    Minigames
]]--

--[[
    Kits
]]--


--[[
    Legit
]]--
