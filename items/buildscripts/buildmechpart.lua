partFrames = {
	arm = {
		{"<armName>", ":idle"},
		{"<armName>Fullbright", ":idle"}
	},
	body = {
		{"bodyBack", ":active"},
		{"bodyFront", ":active"},
		{"bodyFullbright", ":active"}
	},
	booster = {
		{"frontBoosterBack", ":idle"},
		{"frontBoosterFront", ":idle"}
	},
	legs = {
		{"backLeg", ":flat", {11, -4}},
		{"backLegJoint", ":default", {5, -1}},
		{"hips", ":default", {2, 3}},
		{"frontLegJoint", ":default", {-6, -1}},
		{"frontLeg", ":flat", {-10, -4}}
	}
}

function build(directory, config, parameters, level, seed)
	if config.mechPart and partFrames[config.mechPart[1]] then
		local partFile = root.assetJson("/vehicles/modularmech/mechparts_" .. config.mechPart[1] .. ".config")
		local partConfig = partFile[config.mechPart[2]]

		local paletteConfig = root.assetJson("/vehicles/modularmech/mechpalettes.config")
		local directives = directiveString(paletteConfig, partConfig.defaultPrimaryColors, partConfig.defaultSecondaryColors)

		local basePath = "/vehicles/modularmech/"
		local drawables = {}

		for _, frameConfig in ipairs(partFrames[config.mechPart[1]]) do
			local baseImage = partConfig.partImages[frameConfig[1]]
			if baseImage and baseImage ~= "" then
				table.insert(drawables, {
						image = basePath .. baseImage .. frameConfig[2] .. directives,
						centered = true,
						position = frameConfig[3]
					})
			end
		end

		config.tooltipFields = config.tooltipFields or {}
		config.tooltipFields.objectImage = drawables

		local elementalType = partConfig.elementalType or parameters.elementalType or config.elementalType
		if elementalType then
			config.tooltipFields.damageKindImage = "/interface/elements/"..elementalType..".png"
		end

		if partConfig.stats then
			for statName, statValue in pairs(partConfig.stats) do


				--local clampedValue = statName == 'mechMass' and math.max(2, math.min(10, math.floor(statValue/2)*2),1) or math.max(1, math.min(10, math.floor(statValue)))
				--config.tooltipFields[statName .. "StatImage"] = "/interface/tooltips/statbar.png:" .. clampedValue
				local clampedValue = math.max(0, math.min(10, math.floor(statValue)))
				config.tooltipFields[statName .. "StatImage"] = "/interface/tooltips/statbarten.png:" .. clampedValue
			end
		end

		partConfig.stats.mechMass = partConfig.stats.mechMass or 1	-- make sure there is no nil
		config.tooltipFields.mechMassStatLabel = partConfig.stats.mechMass or 1

		if config.mechPart[1] == "arm" then
			local energyDrain = root.evalFunction("mechArmEnergyDrain", partConfig.stats.energy or 0)
			config.tooltipFields.energyDrainStatLabel = string.format("%.02f MJ/s", energyDrain)
		end
	end

	return config, parameters
end

function directiveString(paletteConfig, primaryColors, secondaryColors)
	local result = ""
	for i, fromColor in ipairs(paletteConfig.primaryMagicColors) do
		result = string.format("%s?replace=%s=%s", result, fromColor, primaryColors[i])
	end
	for i, fromColor in ipairs(paletteConfig.secondaryMagicColors) do
		result = string.format("%s?replace=%s=%s", result, fromColor, secondaryColors[i])
	end
	return result
end
