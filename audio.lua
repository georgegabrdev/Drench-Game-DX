-- All Files are .ogg format
-- Music is compressed to 22050 Hz and Sounds are compressed to 16000

local HU = require("hud-utils")

local musicBitrate = 22050
local musicData = {
	lobby = {
		audio = audio_stream_load("music-lobby.ogg"),
		loop = true,
		musicName = "Lobby - Drench Game",
	},

	dire = {
		audio = audio_stream_load("music-dire.ogg"),
		loop = true,
		loopStart = 49.630,
		loopEnd = 153.967,
		musicName = "Dire - Drench Game",
	},

	scores = {
		audio = audio_stream_load("music-scores.ogg"),
		loop = true,
		loopStart = 20.029,
		loopEnd = -0.2,
		musicName = "Scores - Drench Game",
	},

	mingle = {
		audio = audio_stream_load("music-mingle.ogg"),
		musicName = "Mingle - Drench Game",
	},

	final = {
		audio = audio_stream_load("music-final.ogg"),
		loop = true,
		loopStart = 36.647,
		loopEnd = 162.315,
		musicName = "Final - Drench Game",
	},

	slider = {
		audio = audio_stream_load("music-slider-madness-1.ogg"),
		loop = true,
		loopStart = 3.256,
		musicName = "Slider Madness I - Drench Game",
	},

	slider2 = {
		audio = audio_stream_load("music-slider-madness-2.ogg"),
		loop = true,
		musicName = "Slider Madness II - Drench Game",
	},

	slider3 = {
		audio = audio_stream_load("music-slider-madness-3.ogg"),
		loop = true,
		musicName = "Slider Madness III - Drench Game",
	},

	sliderintense = {
		audio = audio_stream_load("music-slider-madness-3.ogg"),
		loop = true,
		musicName = "Slider Madness III - Drench Game",
	},

	thatguy = {
		audio = audio_stream_load("music-thatguy.ogg"),
		loop = true,
		musicName = "Hexhammer - Dark Matter",
	},

	dark = {
		audio = audio_stream_load("music-dark.ogg"),
		loop = true,
		musicName = "Main Theme - The Binding of Isaac",
	},

	sliderCasino = {
		audio = audio_stream_load("music-slider-casino-1.ogg"),
		loop = true,
		loopStart = 2.433,
		musicName = "Slider Casino I - Drench Game",
	},

	sliderCasino2 = {
		audio = audio_stream_load("music-slider-casino-2.ogg"),
		loop = true,
		loopStart = 2.118,
		musicName = "Slider Casino II - Drench Game",
	},

	sliderCasino3 = {
		audio = audio_stream_load("music-slider-casino-3.ogg"),
		loop = true,
		loopStart = 1.868,
		musicName = "Slider Casino III - Drench Game",
	},

	stealth = {
		audio = audio_stream_load("music-stealth.ogg"),
		loop = true,
		loopStart = 0,
		musicName = "Stealth - Deltarune",
	},

	quick = {
		audio = audio_stream_load("music-quick.ogg"),
		loop = true,
		loopStart = 0,
		musicName = "Attack of the Killer Queen - Deltarune",
	},

	finalOutro = {
		audio = audio_stream_load("music-final-outro.ogg"),
	},
}

soundData = {
	redLight = audio_sample_load("sound-light-red.ogg"),
	redLightShort = audio_sample_load("sound-light-red-short.ogg"),
	redLightLong = audio_sample_load("sound-light-red-long.ogg"),
	greenLight = audio_sample_load("sound-light-green.ogg"),
	greenLightShort = audio_sample_load("sound-light-green-short.ogg"),
	greenLightLong = audio_sample_load("sound-light-green-long.ogg"),
	playerCallout1 = audio_sample_load("sound-mingle-callout-1.ogg"),
	playerCallout2 = audio_sample_load("sound-mingle-callout-2.ogg"),
	playerCallout3 = audio_sample_load("sound-mingle-callout-3.ogg"),
	playerCallout4 = audio_sample_load("sound-mingle-callout-4.ogg"),
	select_menu = audio_sample_load("sound-select_menu.ogg"),
	nuclearbomb = audio_sample_load("sound-nuclearbomb.ogg"),
	explosion = audio_sample_load("sound-explosion.ogg"),
}

-- set current streamed music and update volume
local currentMusic = ""
local musicVolume = 1
local targetVolume = 1
local musicFrequency = 1
local musicPaused = false
local mingleMusic = nil
local pausePoint = 0

local musicPopupTimer = 0
local musicPopupText = ""

local MusicAnim = {
	time = 0,
	prevTime = 0,
	anim = {
		timeEnter = 20,
		timeStay = 120,
		timeExit = 20,
	},
}

function update_music(music)
	if gServerSettings.headlessServer ~= 0 and network_is_server() then
		return
	end -- don't do this for headless

	-- update currently played music
	if currentMusic ~= music then
		-- stop current music
		if currentMusic ~= "" then
			local prevMusic = musicData[currentMusic]
			audio_stream_stop(prevMusic.audio)
			--audio_stream_set_looping(prevMusic.audio, false)
			--audio_stream_set_loop_points(prevMusic.audio, 0, 0)
		end

		musicVolume = 1
		targetVolume = 1
		musicFrequency = 1
		musicPaused = false
		currentMusic = music

		if music == "" then
			return
		end
		local thisMusic = musicData[music]
		if not thisMusic then
			log_to_console("Could not find music: " .. music)
			currentMusic = ""
			return
		end

		musicPopupText = thisMusic.musicName or currentMusic
		MusicAnim.time = 0
		MusicAnim.prevTime = 0

		audio_stream_set_volume(thisMusic.audio, musicVolume)
		audio_stream_set_frequency(thisMusic.audio, musicFrequency)
		audio_stream_play(thisMusic.audio, true, 1)
		audio_stream_set_looping(thisMusic.audio, thisMusic.loop or false)
		if thisMusic.loopEnd then
			local loopEnd = (thisMusic.loopEnd or -1)
			if loopEnd ~= -1 then
				loopEnd = loopEnd * musicBitrate
			end
			audio_stream_set_loop_points(thisMusic.audio, (thisMusic.loopStart or 0) * musicBitrate, loopEnd)
		end
		audio_stream_set_position(thisMusic.audio, 0)
	end

	if music == "" then
		return
	end

	local thisMusic = musicData[music]
	local newTargetVolume = targetVolume
	if charSelectExists and charSelect.is_menu_open() and charSelect.get_options_status(4) ~= 0 then
		-- disable music when in character select menu
		musicVolume = 0
		newTargetVolume = 0
	elseif disableMusic == 1 then
		musicVolume = 0
		newTargetVolume = 0
	elseif disableMusic == 2 and music ~= "mingle" then
		musicVolume = 0
		newTargetVolume = 0
	elseif disableMusic == 3 then
		musicBitrate = 44100
	elseif is_game_paused() or inMenu then
		-- lower volume when paused
		newTargetVolume = targetVolume / 2
	end
	local diff = newTargetVolume - musicVolume
	if diff > 0 then
		musicVolume = math.min(musicVolume + 0.1, newTargetVolume)
	else
		musicVolume = math.max(musicVolume - 0.1, newTargetVolume)
	end
	audio_stream_set_volume(thisMusic.audio, musicVolume)
	audio_stream_set_frequency(thisMusic.audio, musicFrequency)

	if DEBUG_MODE and gControllers[0].buttonDown & L_TRIG ~= 0 then
		audio_stream_set_frequency(thisMusic.audio, musicFrequency * 10)
		log_to_console(tostring(audio_stream_get_position(thisMusic.audio) * 48000 / musicBitrate))
	end

	-- pause at volume 0
	if musicVolume == 0 then
		audio_stream_pause(thisMusic.audio)
		if not musicPaused then
			musicPaused = true
			pausePoint = audio_stream_get_position(thisMusic.audio)
		end
	elseif musicPaused then
		musicPaused = false
		audio_stream_play(thisMusic.audio, false, musicVolume)
		audio_stream_set_position(thisMusic.audio, pausePoint)
	end

	MusicAnim.prevTime = MusicAnim.time
	MusicAnim.time = MusicAnim.time + 1
end

function play_stream_sfx(sound, pos, volume_)
	if gServerSettings.headlessServer ~= 0 and network_is_server() then
		return
	end -- don't do this for headless

	local volume = volume_ or 1
	local audio = soundData[sound]
	if not audio then
		log_to_console("Could not find sfx: " .. sound)
		return
	end
	audio_sample_play(audio, pos, volume)
end

function stop_stream_sfx(sound)
	if gServerSettings.headlessServer ~= 0 and network_is_server() then
		return
	end -- don't do this for headless

	local audio = soundData[sound]
	if not audio then
		return
	end
	audio_sample_stop(audio)
end

function stream_music_fade(newTarget)
	targetVolume = newTarget
end

-- used for Red Light, Green Light
function get_target_volume()
	return targetVolume
end

function set_music_frequency(newFrequency)
	musicFrequency = newFrequency
end

-- does this even work?
function test_loop_point()
	local thisMusic = musicData[currentMusic]
	if (not (thisMusic and thisMusic.loopEnd)) or thisMusic.loopEnd == -1 then
		djui_chat_message_create("No point to test...")
		return true
	end
	-- set 3 seconds before loop?
	audio_stream_set_position(thisMusic.audio, (thisMusic.loopEnd - 3))
	return true
end
if DEBUG_MODE then
	hook_chat_command("looptest", "- Test the loop point for this track", test_loop_point)
end

function render_music_popup()
	if not musicPopupText or musicPopupText == "" then
		return
	end
	local total = MusicAnim.anim.timeEnter + MusicAnim.anim.timeStay + MusicAnim.anim.timeExit

	if MusicAnim.time <= 0 or MusicAnim.time > total then
		return
	end

	djui_hud_set_resolution(RESOLUTION_DJUI)

	-- Progress (previous/current)
	local tPrev
	local tCurr

	if MusicAnim.prevTime <= MusicAnim.anim.timeEnter then
		tPrev = MusicAnim.prevTime / MusicAnim.anim.timeEnter
	elseif MusicAnim.prevTime <= MusicAnim.anim.timeEnter + MusicAnim.anim.timeStay then
		tPrev = 1
	else
		local exit = (MusicAnim.prevTime - MusicAnim.anim.timeEnter - MusicAnim.anim.timeStay)
		tPrev = 1 - math.min(exit / MusicAnim.anim.timeExit, 1)
	end

	if MusicAnim.time <= MusicAnim.anim.timeEnter then
		tCurr = MusicAnim.time / MusicAnim.anim.timeEnter
	elseif MusicAnim.time <= MusicAnim.anim.timeEnter + MusicAnim.anim.timeStay then
		tCurr = 1
	else
		local exit = (MusicAnim.time - MusicAnim.anim.timeEnter - MusicAnim.anim.timeStay)
		tCurr = 1 - math.min(exit / MusicAnim.anim.timeExit, 1)
	end

	tPrev = math.max(0, math.min(1, tPrev))
	tCurr = math.max(0, math.min(1, tCurr))

	-- Smoothstep easing (same as player list)
	tPrev = tPrev * tPrev * (3 - 2 * tPrev)
	tCurr = tCurr * tCurr * (3 - 2 * tCurr)

	local alpha = math.floor(255 * tCurr)

	local screenW = djui_hud_get_screen_width()
	local screenH = djui_hud_get_screen_height()

	local w = 500
	local h = 72

	local x = (screenW - w) * 0.5

	local hiddenY = screenH + 12
	local shownY = screenH - h - 24

	local yPrev = hiddenY + (shownY - hiddenY) * tPrev
	local yCurr = hiddenY + (shownY - hiddenY) * tCurr

	djui_hud_set_font(FONT_NORMAL)

	-- Shadow
	djui_hud_set_color(0, 0, 0, math.floor(90 * tCurr))
	HU.djui_hud_render_rect_rounded_interpolated(x + 2, yPrev + 2, w, h, x + 2, yCurr + 2, w, h, 18)

	-- Main background
	djui_hud_set_color(18, 18, 22, math.floor(235 * tCurr))
	HU.djui_hud_render_rect_rounded_interpolated(x, yPrev, w, h, x, yCurr, w, h, 18)

	-- Accent bar
	djui_hud_set_color(120, 220, 255, alpha)
	HU.djui_hud_render_rect_rounded_interpolated(x + 10, yPrev + 10, 6, h - 20, x + 10, yCurr + 10, 6, h - 20, 12)

	-- Header
	djui_hud_set_color(185, 185, 185, alpha)
	djui_hud_print_text_interpolated(
		translate("now_playing"),
		x + 28,
		yPrev + 11,
		0.6,
		0.6,
		x + 28,
		yCurr + 11,
		0.6,
		0.6
	)

	-- Song title
	djui_hud_set_color(255, 255, 255, alpha)
	djui_hud_print_text_interpolated(musicPopupText, x + 28, yPrev + 32, 0.82, 0.82, x + 28, yCurr + 32, 0.82, 0.82)
end

hook_event(HOOK_ON_HUD_RENDER, render_music_popup)
