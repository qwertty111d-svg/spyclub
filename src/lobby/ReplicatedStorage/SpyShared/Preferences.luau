local Preferences = {}
local DEFAULTS = {
	language = 'ru', musicVolume = 0.65, sfxVolume = 0.8,
	motionBlur = false, cameraMotion = true, reducedMotion = false,
	fov = 70, effects = true,
}
function Preferences.defaults()
	return table.clone(DEFAULTS)
end
function Preferences.sanitize(raw)
	if type(raw) ~= 'table' then return nil, 'invalid_settings' end
	local clean = Preferences.defaults()
	for key, value in pairs(raw) do
		local default = DEFAULTS[key]
		if default == nil or type(value) ~= type(default) then return nil, 'invalid_settings' end
		if type(default) == 'number' then
			local low, high = 0, 1
			if key == 'fov' then low, high = 60, 90 end
			if value ~= value or value < low or value > high then return nil, 'invalid_settings' end
		elseif key == 'language' and value ~= 'ru' and value ~= 'en' and value ~= 'zh' then
			return nil, 'invalid_settings'
		end
		clean[key] = value
	end
	return clean, nil
end
return Preferences
