function init()
	self.chatTimer = 0 --Cooldown on announcing power conditions
	
	self.onShip=world.getProperty("fu_byos.owner") --Is world a BYOS?
	self.onStation=(world.type() == 'playerstation') or (world.type() == 'asteroids')
    --Is world a player station or asteroid belt?
	local ePos=entity.position()
	storage.randomizedPos = storage.randomizedPos or {ePos[1] + math.random(2,3), ePos[2] + 1}
	
	self.solarPower1=1.0 --Solar Panel power mult
	self.solarPower2=2.5 --Solar Array power mult
	self.solarPower3=6 --Solar Tower power mult
	self.windPower=12 --Wind Array max output
end

function update(dt)

	if (world.underground(storage.randomizedPos) or ((not (self.onShip or self.onStation)) and (world.timeOfDay() > 0.55))) then --Are we underground, or on a planet at nighttime?
		self.solargenmult = 0 --No solar power
	else
		self.solargenmult = getLightLevel()
	end
	
	self.generated_solar1 = self.solargenmult * self.solarPower1 --Solar Panel power
	self.generated_solar2 = self.solargenmult * self.solarPower2 --Solar Array power
	self.generated_solar3 = self.solargenmult * self.solarPower3 --Solar Tower power
	
	if isn_powerGenerationBlocked() then
		self.generated_wind=0
	else
		self.generated_wind = math.min(math.abs(world.windLevel(isn_getTruePosition())),self.windPower)
	end
	
	--Round power to 1 decimal place for readability
	
	self.generated_solar1 = math.floor(self.generated_solar1*10)/10
	self.generated_solar2 = math.floor(self.generated_solar2*10)/10
	self.generated_solar3 = math.floor(self.generated_solar3*10)/10
	self.generated_wind = math.floor(self.generated_wind*10)/10
	
	--Power output determined, now figure out if and how the beacon should speak
	
	self.chatTimer = math.max(0, self.chatTimer - dt)
	
	if self.chatTimer == 0 then
		local players = world.entityQuery(object.position(), config.getParameter("chatRadius"), {
			includedTypes = {"player"},
			boundMode = "CollisionArea"
		})
		
		self.beaconDialog = "Solar Panel: "..self.generated_solar1.."W\nSolar Array: "..self.generated_solar2.."W\nSolar Tower: "..self.generated_solar3.."W\nWind Array: "..self.generated_wind.."W"
		
		if #players > 0 and self.beaconDialog then
			object.say(self.beaconDialog)
			self.chatTimer = config.getParameter("chatCooldown")
		end
	end
end

function getLightLevel()

	local light = getLight(storage.randomizedPos)
	local genmult = 1
	if self.onStation or self.onShip then
		-- player space stations and ships always counts as high power, but never MAX power.
		genmult = 3.5
	elseif light >= 0.85 then
		genmult = 4 * (1 + light)
	elseif light >= 0.75 then
		genmult = 4
	elseif light >= 0.65 then
		genmult = 3
	elseif light >= 0.55 then
		genmult = 2
	elseif light <= 0.2 then
		genmult = 0
	end

	 -- water significantly reduces the output
	if world.liquidAt(storage.randomizedPos) then
		genmult = genmult * 0.05
	end
	
	return genmult
end

function isn_powerGenerationBlocked() --Is wind generation disallowed (underwater or underground)?
	local location = isn_getTruePosition()
	if world.underground(location) or world.liquidAt(location) or (math.abs(world.windLevel(location)) < 0.1) then return true end
end

function isn_getTruePosition() --Where are we?
	storage.truepos = storage.truepos or {entity.position()[1] + math.random(2,3), entity.position()[2] + 1}
	return storage.truepos
end

function getLight(location) --How light is the area?
	local objects = world.objectQuery(entity.position(), 20)
	local lights = {}
	for i=1,#objects do
		local light = world.callScriptedEntity(objects[i],'object.getLightColor')
		if light and (light[1] > 0 or light[2] > 0 or light[3] > 0) then
			lights[objects[i]] = light
			world.callScriptedEntity(objects[i],'object.setLightColor',{light[1]/3,light[2]/3,light[3]/3})
		end
	end

	 --via 'compressing' liquids like lava it is possible to get exhorbitant values on light level, over 100x the expected range.
	local light = math.min(world.lightLevel(location),1.0)
	for key,value in pairs(lights) do
		world.callScriptedEntity(key,'object.setLightColor',value)
	end
	return light
end
