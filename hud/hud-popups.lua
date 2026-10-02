-- hud-popups.lua
local Mod = {}
local HU = require("../hud-utils")
local basePad = 10
local warningPopups = {}
local maxWarningPopups = 5
local POPUP_TRANS = "@@popup_trans@@"
local POPUP_SEP = "\31"

local function strip_colors(s)
	if not s then
		return ""
	end

	return tostring(s):gsub("\\#%x%x%x%x%x%x\\", "")
end

local function safe_measure(s)
	local clean = strip_colors(s)

	djui_hud_set_font(FONT_NORMAL)

	return djui_hud_measure_text(clean) or 0
end

local function update_popup_anim(anim, isVisible)
	if isVisible then
		if anim.timer < anim.timeEnter then
			anim.timer = anim.timer + 1
		end
	else
		if anim.timer > 0 then
			anim.timer = anim.timer - 1
		end
	end
end

local function unpack_popup_trans(text)
	if type(text) ~= "string" then
		return text
	end

	local prefix = POPUP_TRANS .. POPUP_SEP

	if text:sub(1, #prefix) ~= prefix then
		return text
	end

	local data = {}
	local last_end = 1
	local s, e = text:find(POPUP_SEP, 1, true)

	while s do
		table.insert(data, text:sub(last_end, s - 1))
		last_end = e + 1
		s, e = text:find(POPUP_SEP, last_end, true)
	end

	table.insert(data, text:sub(last_end))

	-- Return the translation key directly instead of looking it up in LANG.
	return data[2] or text
end

function create_warning_local(text)
	text = unpack_popup_trans(text or "")
	text = HU.normalize_text(text or "")

	local lines = {}
	local currentColor = ""
	local maxTextWidth = 540

	for seg in text:gmatch("([^\n]*)\n?") do
		local words = {}

		for w in seg:gmatch("%S+") do
			table.insert(words, w)
		end

		local curLine = ""

		for _, w in ipairs(words) do
			local hexMatch = w:match("\\#%x%x%x%x%x%x\\")

			local testLine = (curLine == "") and w or (curLine .. " " .. w)

			if safe_measure(currentColor .. testLine) > maxTextWidth then
				table.insert(lines, currentColor .. curLine)
				curLine = w
			else
				curLine = testLine
			end

			if hexMatch then
				currentColor = hexMatch
			end
		end

		if curLine ~= "" then
			table.insert(lines, currentColor .. curLine)
		end
	end

	local customRowHeight = 38
	local baseH = (basePad * 4) + (#lines * customRowHeight)

	if #warningPopups >= maxWarningPopups then
		table.remove(warningPopups)
	end

	table.insert(warningPopups, {
		timer = 0,
		timeEnter = 15,
		timeExit = 15,
		lines = lines,
		baseH = baseH,
		rowH = customRowHeight,
		stayTimer = 120,
		isExiting = false,
	})

	play_sound(SOUND_MENU_PINCH_MARIO_FACE, gGlobalSoundSource)
end

function create_warning_popup(text)
	local p = create_packet(PACKET_TYPE_WARNING_MESSAGE, text)

	if network_is_server() then
		create_warning_local(text)
		network_send(true, p)
	else
		send_packet_to_server(p)
	end
end

local function get_holiday_color()
	if holidayEvent == HOLIDAYS.HALLOWEEN then
		return 255, 121, 0
	elseif holidayEvent == HOLIDAYS.CHRISTMAS then
		return 255, 0, 0
	elseif holidayEvent == HOLIDAYS.NEW_YEARS_EVE then
		return 99, 122, 255
	elseif holidayEvent == HOLIDAYS.ST_PATRICKS then
		return 0, 255, 0
	elseif holidayEvent == HOLIDAYS.APRIL_FOOLS then
		return 255, 255, 0
	elseif holidayEvent == HOLIDAYS.EASTER then
		return 255, 105, 180
	elseif holidayEvent == HOLIDAYS.PRIDE_MONTH then
		return 255, 0, 0
	end

	return 0, 128, 128
end

local function get_rainbow_color()
	local rainbow = (get_global_timer() % 180) / 180
	local hue = rainbow * 6

	local x = math.floor(hue)
	local f = hue - x

	local q = math.floor(255 * (1 - f))
	local t = math.floor(255 * f)

	if x == 0 then
		return 255, t, 0
	elseif x == 1 then
		return q, 255, 0
	elseif x == 2 then
		return 0, 255, t
	elseif x == 3 then
		return 0, q, 255
	elseif x == 4 then
		return t, 0, 255
	else
		return 255, 0, q
	end
end

function Mod.render_warning_popups()
	djui_hud_set_resolution(RESOLUTION_DJUI)
	djui_hud_set_font(FONT_NORMAL)

	local sw = djui_hud_get_screen_width()
	local sh = djui_hud_get_screen_height()

	local s = sh / 1080

	for i = #warningPopups, 1, -1 do
		local p = warningPopups[i]

		if p.timer >= p.timeEnter then
			if p.stayTimer > 0 then
				p.stayTimer = p.stayTimer - 1
			else
				p.isExiting = true
			end
		end

		local currentBoxWidth = 600 * s
		local currentBoxHeight = p.baseH * s

		update_popup_anim(p, not p.isExiting)

		if p.isExiting and p.timer <= 0 then
			table.remove(warningPopups, i)
		else
			local progress = p.timer / p.timeEnter

			local x = (sw - currentBoxWidth) / 2

			local targetY = (sh / 1.25) - (currentBoxHeight / 2)
			local startY = sh + 10

			local y = startY + (targetY - startY) * progress

			local prevTimer = p.timer

			if p.isExiting then
				prevTimer = p.timer + 1
			elseif p.timer >= p.timeEnter then
				prevTimer = p.timer
			else
				prevTimer = p.timer - 1
			end

			if prevTimer < 0 then
				prevTimer = 0
			end

			local prevProgress = prevTimer / p.timeEnter

			local yPrev = startY + (targetY - startY) * prevProgress

			local r, g, b = get_holiday_color()

			if holidayEvent == HOLIDAYS.PRIDE_MONTH then
				r, g, b = get_rainbow_color()
			end

			local baseRectAlpha = 64
			local baseTextAlpha = 255

			djui_hud_set_color(r, g, b, progress * baseRectAlpha)

			HU.djui_hud_render_rect_rounded_interpolated(
				x,
				yPrev,
				currentBoxWidth,
				currentBoxHeight,
				x,
				y,
				currentBoxWidth,
				currentBoxHeight,
				16
			)

			local currYPrev = yPrev + (basePad * 2 * s)
			local currY = y + (basePad * 2 * s)

			for _, line in ipairs(p.lines) do
				local clean = strip_colors(line)

				local tw = djui_hud_measure_text(clean) * s

				local tx = x + (currentBoxWidth - tw) / 2

				djui_hud_set_color(255, 255, 255, progress * baseTextAlpha)

				HU.print_colored_text_interpolated(line, tx, currYPrev, tx, currY, s, progress * baseTextAlpha)

				currYPrev = currYPrev + (p.rowH * s)
				currY = currY + (p.rowH * s)
			end
		end
	end
end

return Mod
