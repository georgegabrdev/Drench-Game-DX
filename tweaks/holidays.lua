HOLIDAYS = {
	NONE = 0,
	HALLOWEEN = 1,
	CHRISTMAS = 2,
	NEW_YEARS_EVE = 3,
	ST_PATRICKS = 4,
	APRIL_FOOLS = 5,
	EASTER = 6,
	PRIDE_MONTH = 7,
}

holidayEvent = HOLIDAYS.NONE
local holidayPopup = false

local HOLIDAY_DATA = {
	{
		month = 3,
		day = 17,
		id = HOLIDAYS.ST_PATRICKS,
		light = {
			dir = { x = 64, y = 100, z = 64 },
			color = { r = 50, g = 200, b = 50 },
		},
		fog = { r = 40, g = 120, b = 40 },
	},

	{
		month = 4,
		day = 1,
		id = HOLIDAYS.APRIL_FOOLS,
	},

	{
		month = 6,
		day = 2,
		id = HOLIDAYS.PRIDE_MONTH,
	},

	{
		month = 3,
		day = 20,
		id = HOLIDAYS.EASTER,
		light = {
			dir = { x = 0, y = 127, z = 0 },
			color = { r = 255, g = 255, b = 255 },
		},
		fog = { r = 255, g = 255, b = 255 },
	},

	{
		month = 10,
		day = nil,
		id = HOLIDAYS.HALLOWEEN,
		light = {
			dir = { x = 80, y = 20, z = 80 },
			color = { r = 180, g = 100, b = 255 },
		},
		fog = { r = 40, g = 10, b = 60 },
	},

	{
		month = 12,
		day = 31,
		id = HOLIDAYS.NEW_YEARS_EVE,
		light = {
			dir = { x = 64, y = 100, z = 64 },
			color = { r = 150, g = 150, b = 255 },
		},
		fog = { r = 15, g = 15, b = 25 },
	},

	{
		month = 12,
		day = nil,
		id = HOLIDAYS.CHRISTMAS,
		light = {
			dir = { x = 40, y = 100, z = 40 },
			color = { r = 200, g = 220, b = 255 },
		},
		fog = { r = 230, g = 240, b = 255 },
	},
}

local function apply_settings(config)
	set_vertex_color(0, -1)
	set_vertex_color(1, -1)
	set_vertex_color(2, -1)

	set_lighting_dir(0, 0)
	set_lighting_dir(1, 0)
	set_lighting_dir(2, 0)

	set_lighting_color(0, -1)
	set_lighting_color(1, -1)
	set_lighting_color(2, -1)

	set_fog_color(0, 255)
	set_fog_color(1, 255)
	set_fog_color(2, 255)

	if not config then
		return
	end

	if config.light then
		if config.light.dir then
			set_lighting_dir(0, config.light.dir.x or 0)
			set_lighting_dir(1, config.light.dir.y or 0)
			set_lighting_dir(2, config.light.dir.z or 0)
		end

		if config.light.color then
			local r = config.light.color.r or 255
			local g = config.light.color.g or 255
			local b = config.light.color.b or 255

			set_lighting_color(0, r)
			set_lighting_color(1, g)
			set_lighting_color(2, b)

			set_vertex_color(0, r)
			set_vertex_color(1, g)
			set_vertex_color(2, b)
		end
	end

	if config.fog then
		set_fog_color(0, config.fog.r or 255)
		set_fog_color(1, config.fog.g or 255)
		set_fog_color(2, config.fog.b or 255)
	end
end

local function show_holiday_popup()
	if holidayPopup then
		return
	end
	if holidayEvent == HOLIDAYS.NONE then
		return
	end

	local message = "???"

	if holidayEvent == HOLIDAYS.HALLOWEEN then
		message = "\\#ff7900\\Happy Halloween!"
	elseif holidayEvent == HOLIDAYS.CHRISTMAS then
		message = "\\#ff0000\\Merry \\#ffffff\\Christmas!"
	elseif holidayEvent == HOLIDAYS.NEW_YEARS_EVE then
		message = "\\#ffffff\\Happy \\#637aff\\New Year!"
	elseif holidayEvent == HOLIDAYS.ST_PATRICKS then
		message = "\\#00ff00\\Happy St. \\#ffffff\\Patrick's Day!"
	elseif holidayEvent == HOLIDAYS.APRIL_FOOLS then
		message = "\\#ffff00\\Happy \\#ff00ff\\April Fools' Day!"
	elseif holidayEvent == HOLIDAYS.EASTER then
		message = "\\#ff69b4\\Happy \\#b266ff\\Easter!"
	elseif holidayEvent == HOLIDAYS.PRIDE_MONTH then
		message =
			"Happy \\#ff0000\\P\\#ff7f00\\r\\#ffff00\\i\\#00ff00\\d\\#00ffff\\e \\#0000ff\\M\\#8b00ff\\o\\#ff0000\\n\\#ff7f00\\t\\#ffff00\\h!"
	end

	create_warning_popup(message)
	holidayPopup = true
end

local function on_level_init_holiday()
	local newEventID = HOLIDAYS.NONE
	local foundConfig = nil

	local dt = get_date_and_time()
	local month = dt.month + 1

	for _, cfg in ipairs(HOLIDAY_DATA) do
		if month == cfg.month then
			if cfg.day == nil or cfg.day == dt.day then
				foundConfig = cfg
				newEventID = cfg.id
				break
			end
		end
	end

	holidayEvent = newEventID

	apply_settings(foundConfig)
	show_holiday_popup()
end

hook_event(HOOK_ON_LEVEL_INIT, on_level_init_holiday)
