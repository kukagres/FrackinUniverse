shoggothChargeAttack = {}

--------------------------------------------------------------------------------
function shoggothChargeAttack.enter()
	if not hasTarget() then
		return nil
	end
	monster.setDamageOnTouch(true)
	return {
		timer = config.getParameter("shoggothChargeAttack.skillTime", 0.14),
		damagePerSecond = config.getParameter("shoggothChargeAttack.damagePerSecond", 5000),
		distanceRange = config.getParameter("shoggothChargeAttack.distanceRange"),
		intervalTime = config.getParameter("shoggothChargeAttack.intervalTime"),
		currentPeriod = config.getParameter("shoggothChargeAttack.intervalTime"),
		swiping = false
	}
end

--------------------------------------------------------------------------------
function shoggothChargeAttack.enteringState(stateData)
	animator.setAnimationState("movement", "idle")

	monster.setActiveSkillName("shoggothChargeAttack")
end

--------------------------------------------------------------------------------
function shoggothChargeAttack.update(dt, stateData)
	if not hasTarget() then return true end
	if status.resourcePercentage("health")<=0 then return true end

	local toTarget = world.distance(self.targetPosition, mcontroller.position())
	local targetDir = util.toDirection(toTarget[1])

	--if not stateData.swiping then

		--projectile interval check and spawn
		if stateData.currentPeriod < 0 then
			if isBlocked() then
				local crashTiles = {}
				local basePos = config.getParameter("projectileSourcePosition", {0, 0})
				local dir=mcontroller.facingDirection()
				local xmin=(2+((stateData.blockCounter or 0) * util.clamp(dir,-1,0)))
				local xmax=(22+((stateData.blockCounter or 0) * util.clamp(dir,0,1)))
				local ymin=(-14.5+((stateData.blockCounter or 0) * util.clamp(dir,-1,0)))
				local ymax=(10+((stateData.blockCounter or 0) * util.clamp(dir,0,1)))
				--sb.logInfo("%s",{xmin,xmax,ymin,ymax})
				--for xOffset = 2, 22 do
				for xOffset = xmin, xmax do
					--for yOffset = -14.5, 10 do
					for yOffset = ymin, ymax do
						table.insert(crashTiles, monster.toAbsolutePosition({basePos[1] + xOffset, basePos[2] + yOffset}))
					end
				end

				self.randValNum = math.random(100)
				if self.randValNum >=90 then
					animator.playSound("idleBreath")
				end
				animator.playSound("shoggothChomp")
				world.damageTiles(crashTiles, "foreground", monster.toAbsolutePosition({10, 0}), "plantish", 30)
				stateData.blockCounter=(stateData.blockCounter or 0)+1
			else
				stateData.blockCounter=0
			end
			shoggothChargeAttack.chomp(targetDir)
			stateData.currentPeriod = stateData.intervalTime
		else
			stateData.currentPeriod = stateData.currentPeriod - dt
		end

		if math.abs(toTarget[1]) > stateData.distanceRange[2] then
			animator.setAnimationState("movement", "run")
			move(toTarget, true)
		elseif math.abs(toTarget[1]) < stateData.distanceRange[1] then
			move({-toTarget[1], toTarget[2]}, true)
			animator.setAnimationState("movement", "run")
			mcontroller.controlFace(targetDir)
		else
			stateData.swiping = true
		end
	--end

	return stateData.swiping
end


function shoggothChargeAttack.chomp(direction)
	local projectileType = config.getParameter("shoggothChargeAttack.projectile.type")
	local projectileConfig = config.getParameter("shoggothChargeAttack.projectile.config")
	local projectileOffset = config.getParameter("shoggothChargeAttack.projectile.offset")
	world.spawnProjectile(projectileType, monster.toAbsolutePosition(projectileOffset), entity.id(), {direction, 0}, true, projectileConfig)
	--sb.logInfo("chomp %s",projectileConfig)
end

function shoggothChargeAttack.leavingState(stateData)
	animator.setAnimationState("movement", "idle")
	monster.setActiveSkillName("")
end