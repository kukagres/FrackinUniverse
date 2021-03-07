require "/scripts/util.lua"
require "/scripts/interp.lua"
require "/scripts/furesearchGenerators.lua"

local cosmeticList={legwear=true,chestwear=true,headwear=true,backwear=true}
local armorList={legarmour=true,chestarmour=true,headarmour=true,enviroProtectionPack=true}
local cosmeticSlotList={"headCosmetic", "chestCosmetic", "legsCosmetic", "backCosmetic"}
local armorSlotList={"head", "chest", "legs", "back"}
local textboxPulseInterval=1.0
local upgradeButtonLockout=0.5

function init()
	widget.setButtonEnabled("btnUpgradeMax", false)
	self.itemList = "itemScrollArea.itemList"
	self.isUpgradeKit = true

	local upgradeAnvil = world.objectQuery(world.entityPosition(player.id()), 5, { name = "weaponupgradeanvil2" })
	if upgradeAnvil and #upgradeAnvil > 0 then
		self.isUpgradeKit = false
	end

	if self.isUpgradeKit then
		local upgradeAnvil = world.objectQuery(world.entityPosition(player.id()), 5, { name = "extraweaponupgradeanvil" })
		if upgradeAnvil and #upgradeAnvil > 0 then
			self.isUpgradeKit = false
		end
	end

	self.upgradeLevel = 10 -- sayter set this to 10 (from 8). frankly i'm not sure that's a good idea
	self.upgradeLevelTool = 20 -- sayter set this to 10 (from 8). frankly i'm not sure that's a good idea
	self.maxEssenceValue=root.evalFunction("weaponEssenceValue", self.upgradeLevel)
	self.upgradeableWeaponItems = {}
	self.selectedItem = nil
	populateItemList()

	widget.setText("warningLabel","")
end

function update(dt)
	self.buttonTimer=math.max(self.playerTypingTimer or upgradeButtonLockout,(self.buttonTimer or upgradeButtonLockout)-dt)
	self.playerTypingTimer=math.max(0,(self.playerTypingTimer or upgradeButtonLockout)-dt)
	self.textboxPulseTimer=math.max(0,(self.textboxPulseTimer or textboxPulseInterval)-dt)
	populateItemList()
	itemSelected()
	pulseTextbox()
end

function fetchTags(iConf)
	local tags={}
	for k,v in pairs(iConf.config or {}) do
		if string.lower(k)=="itemtags" then
			tags=util.mergeTable(tags,copy(v))
		end
	end
	for k,v in pairs(iConf.parameters or {}) do
		if string.lower(k)=="itemtags" then
			tags=util.mergeTable(tags,copy(v))
		end
	end
	return tags
end

function matchAny(str,tbl)
	for _,v in pairs(tbl) do
		if v==str then
			return true
		end
	end
	return false
end

function itemHasTag(item,tag)
	local tagData=fetchTags(item)
	for _,v in pairs(tagData) do
		if string.lower(v)==string.lower(tag) then
			return true
		end
	end
	return false
end

function highestRarity(rarity2,rarity1)
	local t={common=1,uncommon=2,rare=3,legendary=4,essential=5}
	rarity1=string.lower(rarity1 or "")
	rarity2=string.lower(rarity2 or "")
	if (t[rarity1] or 0)> (t[rarity2] or 0) then return rarity1 else return rarity2 end
end

function upgradeCost(itemConfig,target)
	if (not itemConfig) then return 0 end
	local iLvl=itemConfig.parameters.level or itemConfig.config.level or 1
	local baseIlvl=iLvl
	local currentValue=0
	local downgrade=false
	local isTool=itemHasTag(itemConfig,"upgradeableTool")
	local maxLvl=(isTool and self.upgradeLevelTool) or self.upgradeLevel
	--target=target or iLvl+1
	target=target or iLvl

	if iLvl > maxLvl then
		downgrade=true
	else
		while (iLvl<target) and not (iLvl>=maxLvl) do
			currentValue=currentValue+costMath(iLvl)
			iLvl=math.min(iLvl+1,maxLvl)
		end
	end

	return math.floor(currentValue),downgrade
end

function costMath(iLvl)
	local prevValue = root.evalFunction("weaponEssenceValue", iLvl)
	local newValue = (self.maxEssenceValue * iLvl / 3) + 200
	return math.max(math.floor(newValue-prevValue),0)
end

--[[{
	"weaponEssenceValue" : [ "linear", "clamp",
		[1, 3750],
		[2, 4000],
		[3, 4500],
		[4, 5250],
		[5, 6250],
		[6, 7500],
		[7, 9000],
		[8, 10750],
		[9, 12750],
		[10, 15000]
	]
}
]]

function populateItemList(forceRepop)
	local upgradeableWeaponItems = player.itemsWithTag("upgradeableWeapon")
	local buffer = {}

	for i = 1, #upgradeableWeaponItems do
		local monkeys=deepSizeOf(upgradeableWeaponItems[i])
		if monkeys <=250 then
			upgradeableWeaponItems[i].count = 1
			table.insert(buffer,upgradeableWeaponItems[i])
		end
	end

	upgradeableWeaponItems=buffer

	widget.setVisible("emptyLabel", #upgradeableWeaponItems == 0)

	local playerEssence = player.currency("essence")

	if forceRepop or not compare(upgradeableWeaponItems, self.upgradeableWeaponItems) then
		self.upgradeableWeaponItems = upgradeableWeaponItems
		widget.clearListItems(self.itemList)
		widget.setButtonEnabled("btnUpgrade", false)
		--widget.setButtonEnabled("btnUpgradeMax", false)

		for i, item in pairs(self.upgradeableWeaponItems) do
			local config = root.itemConfig(item)

			local listItem = string.format("%s.%s", self.itemList, widget.addListItem(self.itemList))
			local name = config.parameters.shortdescription or config.config.shortdescription

			widget.setText(string.format("%s.itemName", listItem), name)
			widget.setItemSlotItem(string.format("%s.itemIcon", listItem), item)

			local price = upgradeCost(config)
			widget.setData(listItem, { index = i })

			widget.setVisible(string.format("%s.unavailableoverlay", listItem), price > playerEssence)
		end

		self.selectedItem = nil
		showWeapon(nil)
	end
end

function showWeapon(item, price, priceMax, downgrade)
	local playerEssence = player.currency("essence")
	local enableButton = false
	local isWorn = item and checkWorn(item)

	widget.setText("warningLabel",(isWorn and "Error: "..isWorn) or (downgrade and "Warning: Item may lose levels.") or "")

	if not self.isUpgradeKit then
		if item then

			enableButton = price and (playerEssence >= price) and not isWorn
			local enableButtonMax = priceMax and (playerEssence >= priceMax) and not isWorn
			local directive = enableButton and "^green;" or "^red;"
			local directive2 = enableButtonMax and "^green;" or "^red;"
			widget.setText("essenceCost", string.format("%s / %s%s^reset;", playerEssence,directive2, priceMax or "--"))
		else
			widget.setText("essenceCost", string.format("%s / --", playerEssence))
		end
	else
		local hasKit=(player.hasCountOfItem({name = "cuddlehorse", count = 1}) or 0) > 0
		widget.setText("essenceCost",hasKit and "^green;FREE FROM UPGRADE KIT" or "^red;MISSING UPGRADE KIT")
		enableButton=hasKit and not isWorn
	end
	--widget.setButtonEnabled("btnUpgradeMax",false)
	widget.setButtonEnabled("btnUpgrade", ((self.buttonTimer and self.buttonTimer or upgradeButtonLockout) <= 0) and enableButton)
end

function getSelectedItem()
	if not self.selectedItem then return end
	return self.upgradeableWeaponItems[widget.getData(string.format("%s.%s", self.itemList, self.selectedItem)).index]
end

function itemSelected()
	local oldSelected=self.selectedItem
	self.selectedItem = widget.getListSelected(self.itemList)
	local changed
	if oldSelected~=self.selectedItem then
		changed=true
	end
	if self.selectedItem then
		local isTool=itemHasTag(root.itemConfig(getSelectedItem()),"upgradeableTool")
		local maxLvl=(isTool and self.upgradeLevelTool) or self.upgradeLevel
		local weaponItem = getSelectedItem()
		local upCostOnce,downgradeOnce=upgradeCost(root.itemConfig(weaponItem))
		local upCostTarget,downgradeTarget=upgradeCost(root.itemConfig(weaponItem),self.upgradeTargetLevel)
		showWeapon(weaponItem, upCostOnce,upCostTarget,downgradeOnce or downgradeTarget)
	end

	if self.playerTypingTimer and self.playerTypingTimer <= 0 then
		fixTargetText(changed)
	end
end

function fixTargetText(changed)
	local originalText = widget.getText("upgradeTargetText")
	local text = originalText
	local num=((not changed) and tonumber(text)) or 0
	local item=getSelectedItem()
	if not item then
		text=""
		self.upgradeTargetLevel=nil
	else
		item=root.itemConfig(item)
		local itemLevel=math.floor(item.parameters.level or item.config.level or 1)
		local isTool=itemHasTag(item,"upgradeableTool")
		local maxLvl=(isTool and self.upgradeLevelTool) or self.upgradeLevel
		--num=math.min(maxLvl,math.max(itemLevel+1,((not self.isUpgradeKit) and num) or 0))
		if self.isUpgradeKit then
			num=util.clamp(num,itemLevel+(changed and 1 or 0),itemLevel+1)
		else
			num=math.max(itemLevel+(changed and 1 or 0),num)
		end
		num=math.min(maxLvl,num)
		self.upgradeTargetLevel=num
		text=num..""
		if num==itemLevel then
			widget.setText("btnUpgrade","Infuse")
		else
			widget.setText("btnUpgrade","Upgrade")
		end
	end
	if originalText~=text then
		widget.setText("upgradeTargetText",text)
		self.playerTypingTimer=upgradeButtonLockout
		self.buttonTimer=upgradeButtonLockout
		widget.setButtonEnabled("btnUpgrade", false)
		itemSelected()
	end
end

function pulseTextbox()
	if self.textboxPulseTimer>0 then return end
	if not self.textboxColor then
		self.textboxColor=true
	else
		self.textboxColor=not self.textboxColor
	end
	widget.setFontColor("upgradeTargetText",self.textboxColor and {192,192,192} or {128,128,128})

	self.textboxPulseTimer=textboxPulseInterval
end

function doUpgradeMax()
--fishdick
end

function btnUpgradeMax()
--fishbutt
end

function doUpgrade()
	if self.selectedItem then
		local consumedKit=false
		if self.isUpgradeKit then
			local cost,downgrade=upgradeCost(root.itemConfig(getSelectedItem()),self.upgradeTargetLevel)
			if (not downgrade) and (cost>0) and (not player.consumeItem({name = "cuddlehorse", count = 1}, true)) then
				widget.setButtonEnabled("btnUpgrade", false)
				return
			elseif (not downgrade) and (cost>0) then
				consumedKit=true
			end
		end

		local isWorn=checkWorn(getSelectedItem())
		if isWorn then
			if consumedKit then
				player.giveItem({name = "cuddlehorse", count = 1})
			end
			widget.setText("warningLabel",isWorn and "Error: "..isWorn or "")
			widget.setButtonEnabled("btnUpgrade", false)
			--widget.setButtonEnabled("btnUpgradeMax", false)
			return
		end
		local upgradeItem=getSelectedItem()
		local pass,result=pcall(upgrade,upgradeItem,self.upgradeTargetLevel)
		if not pass then
			if self.isUpgradeKit then
				player.giveItem({name = "cuddlehorse", count = 1})
			end
			player.giveItem(upgradeItem)
			sb.logInfo("Upgrade failed: %s",result)
		elseif not result.completed then
			if result.consumedItem then
				player.giveItem(upgradeItem)
			end
			if consumedKit then
				player.giveItem({name = "cuddlehorse", count = 1})
			end
		end
	end
end

function checkWorn(item)
	if not item then return "no item selected" end
	local itemCat=root.itemConfig(item)
	if itemCat and itemCat.parameters and itemCat.parameters.category then
		itemCat=itemCat.parameters.category
	elseif itemCat and itemCat.config and itemCat.config.category then
		itemCat=itemCat.config.category
	else
		return "category missing"
	end
	local swapSlotItem=player.swapSlotItem()
	local isCosmeticArmor=cosmeticList[itemCat]
	local isArmor=armorList[itemCat]
	if isCosmeticArmor then
		for _,slot in pairs(cosmeticSlotList) do
			local compTo=player.equippedItem(slot)
			if compare(compTo,item) then return "equipped in cosmetic slot" end
		end
	elseif isArmor then
		for _,slot in pairs(armorSlotList) do
			local compTo=player.equippedItem(slot)
			if compare(compTo,item) then return "equipped in armor slot" end
		end
	end
	if compare(swapSlotItem,item) then return "held by mouse" end
	return false
end

function upgradeTargetText()
	self.playerTypingTimer=upgradeButtonLockout
end

function upgrade(upgradeItem,target)
	--local upgradeItem=getSelectedItem()
	local upgradeStates={}
	if upgradeItem then
		if checkWorn(upgradeItem) then
			return
		end
		local consumedItem = player.consumeItem(upgradeItem, false, true)
		if consumedItem then
			upgradeStates.consumedItem=true
			local upCost=(target and upgradeCost(root.itemConfig(upgradeItem),target) or upgradeCost(root.itemConfig(upgradeItem)))
			local consumedCurrency = self.isUpgradeKit or player.consumeCurrency("essence", upCost)
			local upgradedItem = copy(consumedItem)
			if consumedCurrency or (upCost==0) then
				upgradeStates.consumeCurrency=((not self.isUpgradeKit) and upCost)
				local itemConfig = root.itemConfig(upgradedItem)
				local mergeBuffer={}
				local oldRarity=(itemConfig.parameters and itemConfig.parameters.rarity) or (itemConfig.config and itemConfig.config.rarity)
				mergeBuffer.rarity=oldRarity

				sb.logInfo("Pre-Upgrade Stats: \n"..sb.printJson(upgradedItem,1)) -- list all current bonuses being applied to the weapon for debug

				--set level
				local isTool=itemHasTag(itemConfig,"upgradeableTool")
				local maxLvl=(isTool and self.upgradeLevelTool) or self.upgradeLevel
				--mergeBuffer.level = math.min((itemConfig.parameters.level or itemConfig.config.level or 1)+1,maxLvl)
				mergeBuffer.level = math.min((itemConfig.parameters.level or itemConfig.config.level or 1),maxLvl)
				if target then
					mergeBuffer.level=math.min(math.max(mergeBuffer.level,target),maxLvl)
				end

				--load item upgrade parameters
				if (itemConfig.config.upgradeParametersTricorder) and (mergeBuffer.level >= 1) then
					mergeBuffer=util.mergeTable(mergeBuffer,copy(itemConfig.config.upgradeParametersTricorder))
					mergeBuffer.rarity=highestRarity(mergeBuffer.rarity,oldRarity)
					oldRarity=mergeBuffer.rarity
				end
				if (itemConfig.config.upgradeParameters) and (mergeBuffer.level > 4) then
					mergeBuffer=util.mergeTable(mergeBuffer,copy(itemConfig.config.upgradeParameters))
					mergeBuffer.rarity=highestRarity(mergeBuffer.rarity,oldRarity)
					oldRarity=mergeBuffer.rarity
				end
				if (itemConfig.config.upgradeParameters2) and (mergeBuffer.level > 5) then
					mergeBuffer=util.mergeTable(mergeBuffer,copy(itemConfig.config.upgradeParameters2))
					mergeBuffer.rarity=highestRarity(mergeBuffer.rarity,oldRarity)
					oldRarity=mergeBuffer.rarity
				end
				if (itemConfig.config.upgradeParameters3) and (mergeBuffer.level > 6) then
					mergeBuffer=util.mergeTable(mergeBuffer,copy(itemConfig.config.upgradeParameters3))
					mergeBuffer.rarity=highestRarity(mergeBuffer.rarity,oldRarity)
					oldRarity=mergeBuffer.rarity
				end

				local categoryLower=string.lower(mergeBuffer.category or itemConfig.parameters.category or itemConfig.config.category or "")

				--base DPS
				local baseDps=(mergeBuffer.baseDps) or itemConfig.config.baseDps
				if baseDps then
					mergeBuffer.baseDps = baseDps * (1 + (mergeBuffer.level/80) )	-- increase DPS a bit
				end

				--crit chance
				local critChance=(mergeBuffer.critChance) or itemConfig.config.critChance
				if critChance then
					local modifier=0.15
					if matchAny(categoryLower,{"rapier","katana","mace"}) then
						modifier=0.25
					end
					mergeBuffer.critChance = critChance + (mergeBuffer.level*modifier) -- increase Crit Chance
				end

				--crit chance
				local critBonus=(mergeBuffer.critBonus) or itemConfig.config.critBonus
				if critBonus then
					local modifier=0.5
					if matchAny(categoryLower,{"rapier","katana","mace"}) then
						modifier=1.0
					end
					mergeBuffer.critBonus = critBonus + (mergeBuffer.level*modifier) -- increase Crit Chance
				end

				-- set Rarity
				if mergeBuffer.level == 4 then
					mergeBuffer.rarity = highestRarity("uncommon",mergeBuffer.rarity)
				elseif mergeBuffer.level == 5 then
					mergeBuffer.rarity = highestRarity("rare",mergeBuffer.rarity)
				elseif mergeBuffer.level == 6 then
					mergeBuffer.rarity = highestRarity("legendary",mergeBuffer.rarity)
				elseif mergeBuffer.level >= 7 then
					mergeBuffer.rarity = highestRarity("essential",mergeBuffer.rarity)
				end

				-- is it a shield?
				if (categoryLower == "shield") then
					local shieldBash=mergeBuffer.shieldBash or itemConfig.config.shieldBash
					if shieldBash then
						mergeBuffer.shieldBash=shieldBash+(mergeBuffer.level*0.5)
					end

					local shieldBashPush=mergeBuffer.shieldBashPush or itemConfig.config.shieldBashPush
					if shieldBashPush then
						mergeBuffer.shieldBashPush=shieldBashPush+(mergeBuffer.level*0.5)
					end

					local cooldownTime=mergeBuffer.cooldownTime or itemConfig.config.cooldownTime
					if cooldownTime then
						mergeBuffer.cooldownTime=cooldownTime*(1.0-(0.02*mergeBuffer.level))
					end

					local perfectBlockTime=mergeBuffer.perfectBlockTime or itemConfig.config.perfectBlockTime
					if perfectBlockTime then
						mergeBuffer.perfectBlockTime=perfectBlockTime*(1.0+(mergeBuffer.level*0.05))
					end

					local shieldEnergyBonus=mergeBuffer.shieldEnergyBonus or itemConfig.config.shieldEnergyBonus
					if shieldEnergyBonus then
						mergeBuffer.shieldEnergyBonus=shieldEnergyBonus*(1.0+(mergeBuffer.level*0.05))
					end

					local baseShieldHealth=mergeBuffer.baseShieldHealth or itemConfig.config.baseShieldHealth
					if baseShieldHealth then
						mergeBuffer.baseShieldHealth=baseShieldHealth*(1.0+(mergeBuffer.level*0.15))
					end
				end

				-- is it a staff or wand?
				if matchAny(categoryLower,{"staff","wand"}) then
					local baseDamageFactor=mergeBuffer.baseDamageFactor or itemConfig.config.baseDamageFactor
					if baseDamageFactor then
						mergeBuffer.baseDamageFactor=baseDamageFactor*(1.0+(mergeBuffer.level*0.075))
					end
				end

				-- magnorbs
				if (itemConfig.config.orbitRate) then
					local shieldKnockback=mergeBuffer.shieldKnockback or itemConfig.config.shieldKnockback
					if shieldKnockback then
						mergeBuffer.shieldKnockback=shieldKnockback+mergeBuffer.level
					end

					local shieldEnergyCost=mergeBuffer.shieldEnergyCost or itemConfig.config.shieldEnergyCost
					if shieldEnergyCost then
						mergeBuffer.shieldEnergyCost=shieldEnergyCost+mergeBuffer.level
					end

					local shieldHealth=mergeBuffer.shieldHealth or itemConfig.config.shieldHealth
					if shieldHealth then
						mergeBuffer.shieldHealth=shieldHealth+mergeBuffer.level
					end
				end

				-- boomerangs and other projectileParameters based things (magnorbs here too, chakrams)
				local projectileParameters=copy(mergeBuffer.projectileParameters or (itemConfig.config.projectileParameters and {}))
				if projectileParameters then
					projectileParameters.power=projectileParameters.power or itemConfig.config.projectileParameters.power
					if projectileParameters.power then
						projectileParameters.power=projectileParameters.power+(mergeBuffer.level/7)
					end
					projectileParameters.controlForce=projectileParameters.controlForce or itemConfig.config.projectileParameters.controlForce
					if projectileParameters.controlForce then
						projectileParameters.controlForce=projectileParameters.controlForce+mergeBuffer.level
					end
					mergeBuffer.projectileParameters=projectileParameters
				end

				local primaryAbility=copy(mergeBuffer.primaryAbility or (itemConfig.config.primaryAbility and {}))
				if primaryAbility then
					if not matchAny(categoryLower,{"gun staff","sggunstaff"}) then --exclude Shellguard gunblades from this bit to not break their rotation
						-- bows
						if (categoryLower == "bow") then
							primaryAbility.drawTime=primaryAbility.drawTime or itemConfig.config.primaryAbility.drawTime
							if primaryAbility.drawTime then
								primaryAbility.drawTime = primaryAbility.drawTime * (1 - (0.05*mergeBuffer.level))
							end
							primaryAbility.powerProjectileTime=primaryAbility.powerProjectileTime or itemConfig.config.primaryAbility.powerProjectileTime
							if type(primaryAbility.powerProjectileTime)=="number" then
								primaryAbility.powerProjectileTime = primaryAbility.powerProjectileTime*(1-(0.05*mergeBuffer.level))
							elseif type(primaryAbility.powerProjectileTime)=="table" then
								primaryAbility.powerProjectileTime[1]=primaryAbility.powerProjectileTime[1]*(1-(0.05*mergeBuffer.level))
								primaryAbility.powerProjectileTime[2]=primaryAbility.powerProjectileTime[2]*(1+(0.05*mergeBuffer.level))
							end
							primaryAbility.energyPerShot=primaryAbility.energyPerShot or itemConfig.config.primaryAbility.energyPerShot
							if primaryAbility.energyPerShot then
								primaryAbility.energyPerShot = primaryAbility.energyPerShot * math.max(0,(1-(mergeBuffer.level*0.05)))
							end
							primaryAbility.holdEnergyUsage=primaryAbility.holdEnergyUsage or itemConfig.config.primaryAbility.holdEnergyUsage
							if primaryAbility.holdEnergyUsage then
								primaryAbility.holdEnergyUsage = primaryAbility.holdEnergyUsage * math.max(0,1.0-(mergeBuffer.level*0.05))
							end
							primaryAbility.airborneBonus=primaryAbility.airborneBonus or itemConfig.config.primaryAbility.airborneBonus
							if primaryAbility.airborneBonus then
								primaryAbility.airborneBonus = primaryAbility.airborneBonus*(1+(mergeBuffer.level*0.02))
							end
						end
						-- beams and miners
						primaryAbility.beamLength=primaryAbility.beamLength or itemConfig.config.primaryAbility.beamLength
						if (primaryAbility.beamLength) then
							primaryAbility.beamLength=primaryAbility.beamLength + mergeBuffer.level
						end

						-- wands/staves
						primaryAbility.maxCastRange=primaryAbility.maxCastRange or itemConfig.config.primaryAbility.maxCastRange
						if (primaryAbility.maxCastRange) then
							primaryAbility.maxCastRange = primaryAbility.maxCastRange + (mergeBuffer.level/4)
						end

						primaryAbility.energyCost=primaryAbility.energyCost or itemConfig.config.primaryAbility.energyCost
						if (itemConfig.config.primaryAbility.energyCost) then
							primaryAbility.energyCost = primaryAbility.energyCost * math.max(0,1.0-(mergeBuffer.level*0.03))
						end

						-- does the item have a baseDps? if so, we increase the DPS slightly, but not if the weapon is a big hitter.
						primaryAbility.baseDps=primaryAbility.baseDps or itemConfig.config.primaryAbility.baseDps
						if (primaryAbility.baseDps) and not (primaryAbility.baseDps >=20) then
							primaryAbility.baseDps=primaryAbility.baseDps*(1+(mergeBuffer.level/79))
						end
					else
						--gunblade upgrade data here
					end
					mergeBuffer.primaryAbility=primaryAbility
				end

				-- Can it STUN?
				if matchAny(categoryLower,{"hammer","mace","greataxe","quarterstaff"}) then
					local stunChance=mergeBuffer.stunChance or itemConfig.config.stunChance
					if stunChance then
						mergeBuffer.stunChance=stunChance+(mergeBuffer.level*0.5)
					end
				end

				upgradedItem.parameters=util.mergeTable(copy(upgradedItem.parameters),copy(mergeBuffer))
				upgradeStates.completed=true
			end

			-- check if player gets Research randomly
			if upgradeStates.completed then
				player.giveItem(upgradedItem)
				checkResearchBonus()
				sb.logInfo("Upgraded Stats: \n"..sb.printJson(upgradedItem,1)) -- list all current bonuses being applied to the weapon for debug
			end
			--player.giveItem(upgradedItem)
			return upgradeStates
		end
	end

	if self.isUpgradeKit then
		pane.dismiss()
	else
		populateItemList(true)
	end
end

local oldCompare=compare
function compare(t1,t2)
	local pass,result=pcall(oldCompare,t1,t2)
	if pass then
		return result
	else
		criticalError()
	end
end

function criticalError()
	--fatal error, essentially. this can happen with certain items like the massive spawned in holo ruler thing. we're going to just disable the entire UI and display an informative warning.
	widget.setVisible("essenceCostDescription",true)
	widget.setVisible("upgradeTargetLabel",false)
	widget.setVisible("upgradeTargetText",false)
	widget.setVisible("itemScrollArea",false)
	widget.setVisible("essenceCost",true)
	widget.setVisible("warningLabel",true)
	widget.setVisible("emptyLabel",false)
	widget.setVisible("btnUpgrade",false)
	widget.setVisible("btnUpgradeMax",false)
	widget.setText("essenceCostDescription","^red;HEAVILY OVER-MODDED ITEM")
	widget.setText("essenceCost","^yellow;Find it. Remove it.")
	widget.setText("warningLabel","^red;CRITICAL ERROR: ID10T")
	script.setUpdateDelta(0)
	error("You have a heavily overloaded item. This upgrade UI can't handle those. Items like the holographic ruler, for example.")
end

function deepSizeOf(arg)
	if type(arg)~="table" then return 1 end
	local i=0
	for _,value in pairs(arg) do
		if type(value)~="table" then i=i+1
		else i=i+deepSizeOf(value)
		end
	end
	return(i)
end
