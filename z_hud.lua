-- disable everything except camera and health
local HU = require("hud-utils")
local MWI = require("./tweaks/c-mWins")
function behind_hud_render()
	hud_set_value(
		HUD_DISPLAY_FLAGS,
		HUD_DISPLAY_FLAGS_CAMERA | HUD_DISPLAY_FLAGS_POWER | HUD_DISPLAY_FLAGS_CAMERA_AND_POWER
	)
end

hook_event(HOOK_ON_HUD_RENDER_BEHIND, behind_hud_render)

-- radar in Star Steal
local starRadar = { prevX = 0, prevY = 0, prevScale = 0 }
function behind_hud_render()
	if gGlobalSyncTable.gameMode ~= GAME_MODE_STAR_STEAL or gGlobalSyncTable.gameState == GAME_STATE_LOBBY then
		return
	end

	local o = obj_get_first_with_behavior_id(id_bhvStealStar)
	if not o then
		return
	end

	djui_hud_set_resolution(RESOLUTION_N64)
	local pos = { x = o.oPosX, y = o.oPosY + 20, z = o.oPosZ }
	local out = { x = 0, y = 0, z = 0 }
	djui_hud_world_pos_to_screen_pos(pos, out)

	local dX = out.x
	local dY = out.y
	local screenWidth = djui_hud_get_screen_width()
	local screenHeight = djui_hud_get_screen_height()

	local dist = vec3f_dist(pos, gMarioStates[0].pos)
	local alpha = math.clamp(dist, 0, 900) - 800
	if alpha <= 0 then
		starRadar.prevX = dX
		starRadar.prevY = dY
		return
	end

	if out.z > -260 then
		local cdist = vec3f_dist(pos, gLakituState.pos)
		if dist < cdist then
			dY = 0
		else
			dY = screenHeight
		end
	end

	local tex = gTextures.star
	local scale = (math.clamp(dist, 0, 2400) / 2000)
	local width = tex.width * scale
	dX = dX - width / 2
	dY = dY - width / 2
	if dX > (screenWidth - width) then
		dX = (screenWidth - width)
	elseif dX < 0 then
		dX = 0
	end
	if dY > (screenHeight - width) then
		dY = (screenHeight - width)
	elseif dY < 0 then
		dY = 0
	end

	djui_hud_set_color(255, 255, 255, alpha)
	djui_hud_render_texture_interpolated(
		tex,
		starRadar.prevX,
		starRadar.prevY,
		starRadar.prevScale,
		starRadar.prevScale,
		dX,
		dY,
		scale,
		scale
	)

	starRadar.prevX = dX
	starRadar.prevY = dY
	starRadar.prevScale = scale
end

hook_event(HOOK_ON_HUD_RENDER_BEHIND, behind_hud_render)

local teamNameRef = { "Random" }
for i = 1, #TEAM_DATA do
	table.insert(teamNameRef, TEAM_DATA[i][3])
end

local menuSelectedMode = -1
function build_game_mode_menu(menu)
	for i = 0, GAME_MODE_MAX - 1 do
		local gData = GAME_MODE_DATA[i]
		table.insert(menu, {
			gData.name,
			function()
				menuSelectedMode = i
				if i == GAME_MODE_DUEL then
					enter_menu(4)
					return
				elseif type(gData.level) == "table" then
					enter_menu(5)
					return
				end
				gGlobalSyncTable.selectedMode = i
				djui_chat_message_create(translate("selected") .. "\\#ffff50\\" .. gData.name)
				inMenu = false
			end,
		})
	end
end

function build_team_select_menu(menu)
	for i = 0, MAX_PLAYERS - 1 do
		table.insert(menu, {
			gNetworkPlayers[i].name,
			function(x)
				gPlayerSyncTable[i].team = x
			end,
			false,
			function()
				return (not gNetworkPlayers[i].connected) or gPlayerSyncTable[i].spectator
			end,
			currNum = gPlayerSyncTable[i].team or 0,
			minNum = 0,
			maxNum = gGlobalSyncTable.teamCount,
			runOnChange = true,
			nameRef = teamNameRef,
		})
	end
end

local MENU_COLORS = {
	bg = { r = 0, g = 15, b = 25, a = 200 },
	bgTex = { r = 200, g = 255, b = 255, a = 50 },
	descBg = { r = 0, g = 15, b = 25, a = 255 },
	scrollBg = { r = 0, g = 15, b = 25, a = 255 },
	scrollBar = { r = 155, g = 255, b = 255, a = 155 },
}
TEX_TRIANGLE = get_texture_info("triangle")

inMenu = false
local menuOption = 1
local menuID = 1
local stickCooldownX = 0
local stickCooldownY = 0
local cancelTime = 0
local specTime = 0
local frameCounter = 0
local menu_history = {}
local menuMotionEnabled = true
local menuMotionY = 0
local bgTexScroll = 0
local menuMotionScrollY = -1
local resetMenuMotion = false
local menuMotionButton = {}

local function djui_hud_set_color_from_table(color, alpha)
	djui_hud_set_color(color.r or 255, color.g or 255, color.b or 255, alpha or color.a or 255)
end

-- menu data
menu_data = {
	[1] = {
		{
			translate("game_settings"),
			function()
				enter_menu(2)
			end,
			true,
		},
		{
			translate("select_next_minigame"),
			function()
				enter_menu(3)
			end,
			true,
			function()
				return (
					gGlobalSyncTable.gameState ~= GAME_STATE_LOBBY
					and gGlobalSyncTable.gameState ~= GAME_STATE_SCORES
				)
					or (
						gGlobalSyncTable.gameModeSelection ~= SELECT_MODE_CHOOSE
						and (
							gGlobalSyncTable.gameModeSelection ~= SELECT_MODE_ORDER
							or gGlobalSyncTable.gameState ~= GAME_STATE_LOBBY
						)
					)
			end,
		},
		{
			translate("modifiers"),
			function()
				enter_menu(7)
			end,
			true,
		},
		{
			translate("force_start_game"),
			function()
				gGlobalSyncTable.forceStart = not gGlobalSyncTable.forceStart
				if gGlobalSyncTable.forceStart then
					local connectionsNeeded = 2
					local validPlayers = 0
					for_each_connected_player(function(index)
						validPlayers = validPlayers + 1
						if validPlayers >= connectionsNeeded then
							return true
						end
					end)
					if validPlayers ~= 0 and (do_solo_debug() or validPlayers >= connectionsNeeded) then
						djui_chat_message_create("\\#ffff50\\" .. translate("starting_the_game"))
					else
						djui_chat_message_create("\\#ff5050\\" .. translate("need_at_least_2_players"))
						gGlobalSyncTable.forceStart = false
					end
				else
					djui_chat_message_create("\\#ff5050\\" .. translate("canceled_forced_start"))
				end
			end,
			true,
			function()
				return (gGlobalSyncTable.gameState ~= GAME_STATE_LOBBY)
			end,
		},
		{
			translate("cancel_game"),
			function()
				if cancelTime >= get_time() - 5 then
					gGlobalSyncTable.gameState = GAME_STATE_LOBBY
					gGlobalSyncTable.gameTimer = 0
					if gGlobalSyncTable.teamSelection == TEAM_SELECTION_RANDOM then
						do_team_selection()
					end
					cancelTime = 0
					inMenu = false
				else
					djui_chat_message_create("\\#ff5050\\" .. translate("are_you_sure"))
					cancelTime = get_time()
				end
			end,
			true,
			function()
				return (gGlobalSyncTable.gameState == GAME_STATE_LOBBY)
			end,
		},
		{
			translate("team"),
			function(x)
				gPlayerSyncTable[0].team = x
			end,
			false,
			function()
				return not (
					gGlobalSyncTable.teamCount ~= 0
					and gGlobalSyncTable.teamSelection == TEAM_SELECTION_PLAYER
					and gGlobalSyncTable.gameState == GAME_STATE_LOBBY
				)
			end,
			runOnChange = true,
			updateNum = function(button)
				button.maxNum = gGlobalSyncTable.teamCount or 0
				local team = gPlayerSyncTable[0].team or 0
				if team <= button.maxNum then
					button.currNum = team
				else
					button.currNum = 0
				end
			end,
			currNum = 0,
			minNum = 0,
			maxNum = 0,
			nameRef = teamNameRef,
		},
		{
			translate("open_cs_menu"),
			function()
				charSelect.set_menu_open(true)
				inMenu = false
			end,
			false,
			function()
				return not charSelectExists
			end,
		},
		{
			translate("personal_settings"),
			function()
				enter_menu(8)
			end,
			true,
		},
		{
			translate("spectate_text"),
			function()
				local sMario0 = gPlayerSyncTable[0]
				local skipCheck = gGlobalSyncTable.gameState == GAME_STATE_LOBBY
					or (gGlobalSyncTable.gameState ~= GAME_STATE_ACTIVE and not gGlobalSyncTable.eliminationMode)
				if sMario0.spectator or skipCheck or specTime >= get_time() - 5 then
					specTime = 0
					toggle_spectator()
					inMenu = false
				else
					djui_chat_message_create(translate("spectate_warning"))
					specTime = get_time()
				end
			end,
			false,
		},
		{
			translate("exit_menu"),
			function()
				inMenu = false
			end,
			false,
		},
		{
			translate("coopdx_menu"),
			function()
				djui_open_pause_menu()
			end,
			false,
		},
	},
	[2] = {
		{
			translate("game_mode_selection"),
			function(x)
				gGlobalSyncTable.gameModeSelection = x
				gGlobalSyncTable.selectedMode = -1
			end,
			minNum = 0,
			currNum = gGlobalSyncTable.gameModeSelection,
			maxNum = 3,
			runOnChange = true,
			nameRef = { translate("choose"), translate("in_order"), translate("random"), translate("all") },
			save = "gameModeSelection",
		},
		{
			translate("include_all_player_duel"),
			function(x)
				gGlobalSyncTable.includeAllDuel = (x == 1)
			end,
			true,
			function()
				return (gGlobalSyncTable.gameModeSelection == SELECT_MODE_CHOOSE or gGlobalSyncTable.eliminationMode)
			end,
			currNum = (gGlobalSyncTable.includeAllDuel and 1) or 0,
			minNum = 0,
			maxNum = 1,
			runOnChange = true,
			nameRef = { translate("off"), translate("on") },
			save = "includeAllDuel",
		},
		{
			translate("total_minigames"),
			function(x)
				gGlobalSyncTable.maxMiniGames = x
			end,
			true,
			function()
				return gGlobalSyncTable.gameModeSelection == SELECT_MODE_ALL
			end,
			currNum = gGlobalSyncTable.maxMiniGames,
			maxNum = 99,
			runOnChange = true,
			save = "maxMiniGames",
		},
		{
			translate("final_duel"),
			function(x)
				gGlobalSyncTable.finalDuel = (x == 1)
			end,
			true,
			function()
				return (gGlobalSyncTable.gameModeSelection ~= SELECT_MODE_ALL and gGlobalSyncTable.maxMiniGames <= 1)
					or (gGlobalSyncTable.teamCount == 2 and not gGlobalSyncTable.eliminationMode)
			end,
			currNum = (gGlobalSyncTable.finalDuel and 1) or 0,
			minNum = 0,
			maxNum = 1,
			runOnChange = true,
			nameRef = { translate("off"), translate("on") },
			save = "finalDuel",
		},
		{
			translate("elimination_mode"),
			function(x)
				gGlobalSyncTable.eliminationMode = (x == 1)
			end,
			currNum = (gGlobalSyncTable.eliminationMode and 1) or 0,
			minNum = 0,
			maxNum = 1,
			runOnChange = true,
			nameRef = { translate("off"), translate("on") },
			save = "eliminationMode",
		},
		{
			translate("percent_ready_to_start"),
			function(x)
				gGlobalSyncTable.percentToStart = x
			end,
			true,
			currNum = gGlobalSyncTable.percentToStart,
			minNum = 0,
			maxNum = 100,
			runOnChange = true,
			save = "percentToStart",
		},
		{
			translate("teams"),
			function(x)
				gGlobalSyncTable.teamCount = x
				if x == 0 then
					for i = 0, MAX_PLAYERS - 1 do
						gPlayerSyncTable[i].team = 0
					end
				else
					do_team_selection()
				end
			end,
			true,
			currNum = gGlobalSyncTable.teamCount,
			minNum = 0,
			maxNum = 8,
			excludeNum = 1,
			runOnChange = true,
			nameRef = { translate("off") },
			save = "teamCount",
		},
		{
			translate("team_selection"),
			function(x)
				gGlobalSyncTable.teamSelection = x
				if x == TEAM_SELECTION_RANDOM then
					do_team_selection()
				end
			end,
			true,
			function()
				return gGlobalSyncTable.teamCount == 0
			end,
			currNum = gGlobalSyncTable.teamSelection,
			minNum = 0,
			maxNum = 2,
			runOnChange = true,
			nameRef = { translate("random_teams"), translate("hosts_choice"), translate("players_choice") },
			save = "teamSelection",
		},
		{
			translate("select_teams"),
			function()
				enter_menu(6)
			end,
			true,
			function()
				return gGlobalSyncTable.teamSelection ~= TEAM_SELECTION_HOST or gGlobalSyncTable.teamCount == 0
			end,
		},
	},
	[3] = { buildFunc = build_game_mode_menu }, -- auto built
	[4] = {
		{
			translate("total_duelers"),
			function(x)
				local secondToLastOption = menu_data[4][#menu_data[4] - 1]
				local lastOption = menu_data[4][#menu_data[4]]
				for i = 1, x do
					menu_data[4][i + 1] = {
						"Dueler " .. i,
						function()
							-- do nothing
						end,
						playerRef = true,
						currNum = (menu_data[4][i + 1] and get_menu_option(4, i + 1)) or 0,
						minNum = 0,
						maxNum = MAX_PLAYERS - 1,
					}
				end
				if #menu_data[4] > x + 1 then
					for i = x + 2, #menu_data[4] do
						menu_data[4][i] = nil
					end
				end
				table.insert(menu_data[4], secondToLastOption)
				table.insert(menu_data[4], lastOption)
			end,
			currNum = 2,
			minNum = 2,
			maxNum = MAX_PLAYERS,
			runOnChange = true,
		},
		{
			"Dueler 1",
			function()
				-- do nothing
			end,
			playerRef = true,
			currNum = 0,
			minNum = 0,
			maxNum = MAX_PLAYERS - 1,
		},
		{
			"Dueler 2",
			function()
				-- do nothing
			end,
			playerRef = true,
			currNum = 0,
			minNum = 0,
			maxNum = MAX_PLAYERS - 1,
		},
		{
			"\\#50ff50\\" .. translate("confirm_duelers"),
			function()
				for i = 0, MAX_PLAYERS - 1 do
					local sMario = gPlayerSyncTable[i]
					sMario.validForDuel = false
				end
				local duelers = 0
				for i = 2, #menu_data[4] - 2 do
					local index = get_menu_option(4, i)
					local sMario = gPlayerSyncTable[index]
					if not sMario.validForDuel then
						duelers = duelers + 1
						sMario.validForDuel = true
					end
				end
				if do_solo_debug() or duelers >= 2 then
					gGlobalSyncTable.selectedMode = GAME_MODE_DUEL
					gGlobalSyncTable.allDuel = false
					djui_chat_message_create("Selected \\#ffff50\\" .. translate("duel"))
					inMenu = false
				else
					djui_chat_message_create("\\#ff5050\\" .. translate("must_have_at_least_2_duelers"))
				end
			end,
		},
		{
			"\\#ffff50\\" .. translate("all_player_duel"),
			function()
				gGlobalSyncTable.selectedMode = GAME_MODE_DUEL
				gGlobalSyncTable.allDuel = true
				djui_chat_message_create(translate("selected") .. "\\#ffff50\\" .. translate("duel"))
				inMenu = false
			end,
		},
	},
	[5] = {
		{
			translate("toad_town"),
			function()
				gGlobalSyncTable.gameLevelOverride = LEVEL_TOAD_TOWN
				gGlobalSyncTable.selectedMode = menuSelectedMode
				local gData = GAME_MODE_DATA[menuSelectedMode or 0]
				djui_chat_message_create(translate("selected") .. "\\#ffff50\\" .. gData.name)
				inMenu = false
			end,
		},
		{
			translate("koopa_keep"),
			function()
				gGlobalSyncTable.gameLevelOverride = LEVEL_KOOPA_KEEP
				gGlobalSyncTable.selectedMode = menuSelectedMode
				local gData = GAME_MODE_DATA[menuSelectedMode or 0]
				djui_chat_message_create(translate("selected") .. "\\#ffff50\\" .. gData.name)
				inMenu = false
			end,
		},
		{
			translate("ds_fort"),
			function()
				gGlobalSyncTable.gameLevelOverride = LEVEL_DS_FORT
				gGlobalSyncTable.selectedMode = menuSelectedMode
				local gData = GAME_MODE_DATA[menuSelectedMode or 0]
				djui_chat_message_create(translate("selected") .. "\\#ffff50\\" .. gData.name)
				inMenu = false
			end,
		},
		{
			translate("duel"),
			function()
				gGlobalSyncTable.gameLevelOverride = LEVEL_DUEL
				gGlobalSyncTable.selectedMode = menuSelectedMode
				local gData = GAME_MODE_DATA[menuSelectedMode or 0]
				djui_chat_message_create(translate("selected") .. "\\#ffff50\\" .. gData.name)
				inMenu = false
			end,
		},
		{
			translate("random"),
			function()
				gGlobalSyncTable.gameLevelOverride = -1
				gGlobalSyncTable.selectedMode = menuSelectedMode
				local gData = GAME_MODE_DATA[menuSelectedMode or 0]
				djui_chat_message_create(translate("selected") .. "\\#ffff50\\" .. gData.name)
				inMenu = false
			end,
		},
	},
	[6] = { buildFunc = build_team_select_menu }, -- auto built
	[7] = {
		{
			translate("super_speed"),
			function(x)
				toggle_modifier_by_bit(modifierBits.superSpeed, x ~= 0)
			end,
			false,
			runOnChange = true,
			currNum = 0,
			minNum = 0,
			maxNum = 1,
			nameRef = { translate("off"), translate("on") },
			updateNum = function(button)
				button.currNum = is_modifier_active(modifierBits.superSpeed) and 1 or 0
			end,
		},

		{
			translate("high_gravity"),
			function(x)
				toggle_modifier_by_bit(modifierBits.highGravity, x ~= 0)
			end,
			false,
			runOnChange = true,
			currNum = 0,
			minNum = 0,
			maxNum = 1,
			nameRef = { translate("off"), translate("on") },
			updateNum = function(button)
				button.currNum = is_modifier_active(modifierBits.highGravity) and 1 or 0
			end,
		},

		{
			translate("low_gravity"),
			function(x)
				toggle_modifier_by_bit(modifierBits.lowGravity, x ~= 0)
			end,
			false,
			runOnChange = true,
			currNum = 0,
			minNum = 0,
			maxNum = 1,
			nameRef = { translate("off"), translate("on") },
			updateNum = function(button)
				button.currNum = is_modifier_active(modifierBits.lowGravity) and 1 or 0
			end,
		},

		{
			translate("inverted_controls"),
			function(x)
				toggle_modifier_by_bit(modifierBits.invertedControls, x ~= 0)
			end,
			false,
			runOnChange = true,
			currNum = 0,
			minNum = 0,
			maxNum = 1,
			nameRef = { translate("off"), translate("on") },
			updateNum = function(button)
				button.currNum = is_modifier_active(modifierBits.invertedControls) and 1 or 0
			end,
		},

		{
			translate("instakill"),
			function(x)
				toggle_modifier_by_bit(modifierBits.instaKill, x ~= 0)
			end,
			false,
			runOnChange = true,
			currNum = 0,
			minNum = 0,
			maxNum = 1,
			nameRef = { translate("off"), translate("on") },
			updateNum = function(button)
				button.currNum = is_modifier_active(modifierBits.instaKill) and 1 or 0
			end,
		},

		{
			translate("z_button_challenge"),
			function(x)
				toggle_modifier_by_bit(modifierBits.ZBC, x ~= 0)
			end,
			false,
			runOnChange = true,
			currNum = 0,
			minNum = 0,
			maxNum = 1,
			nameRef = { translate("off"), translate("on") },
			updateNum = function(button)
				button.currNum = is_modifier_active(modifierBits.ZBC) and 1 or 0
			end,
		},

		{
			translate("b_button_challenge"),
			function(x)
				toggle_modifier_by_bit(modifierBits.BBC, x ~= 0)
			end,
			false,
			runOnChange = true,
			currNum = 0,
			minNum = 0,
			maxNum = 1,
			nameRef = { translate("off"), translate("on") },
			updateNum = function(button)
				button.currNum = is_modifier_active(modifierBits.BBC) and 1 or 0
			end,
		},
	},

	[8] = {
		{
			translate("music_text"),
			function(x)
				disableMusic = x
			end,
			false,
			runOnChange = true,
			currNum = 0,
			minNum = 0,
			maxNum = 2,
			nameRef = { translate("on"), translate("off"), translate("mingle_only") },
			save = "disableMusic",
			localSave = true,
		},
		{
			translate("colorblind_text"),
			function(x)
				showColorNames = (x ~= 0)
			end,
			false,
			runOnChange = true,
			currNum = 0,
			minNum = 0,
			maxNum = 1,
			nameRef = { "\\#ff5050\\Off", "\\#50ff50\\On" },
			save = "showColorNames",
			localSave = true,
		},
		{
			translate("language_text"),
			function(x)
				local languages = {
					"en",
					"es",
					"pt-br",
					"fr",
				}

				language = languages[x + 1]
			end,
			false,
			runOnChange = true,
			currNum = 0,
			minNum = 0,
			maxNum = 3,
			nameRef = {
				"English",
				"Español",
				"Português",
				"Français",
			},
			save = "language",
			localSave = true,
		},
	},
	[9] = {
		{
			translate("creator"),
			function() end,
			desc = "Georgegabr1",
		},
		{
			translate("minigames"),
			function() end,
			desc = "Drench Game +\nDrench Game v1.2.2 (unofficial)",
		},
		{
			translate("ideas"),
			function() end,
			desc = "SCOPIC64",
		},
	},
}

local TEX_DRENCH = get_texture_info("drench_icon")

local function update_modifier_menu()
	local menu = menu_data[7]
	if not menu then
		return
	end

	for _, button in ipairs(menu) do
		if button.updateNum then
			button.updateNum(button)
		end
	end
end

function render_menu()
	if menuID == 7 then
		update_modifier_menu()
	end

	djui_hud_set_resolution(RESOLUTION_DJUI)
	djui_hud_set_font(djui_menu_get_font())

	local screenWidth = djui_hud_get_screen_width()
	local screenHeight = djui_hud_get_screen_height()

	-- Dark background
	djui_hud_set_color_from_table(MENU_COLORS.bg)
	djui_hud_render_rect(0, 0, screenWidth + 10, screenHeight + 10)

	-- Scrolling tiled background texture
	local tex = TEX_DRENCH
	local bgTexScale = 5
	local maxTexX = math.ceil(screenWidth / (tex.width * bgTexScale))
	local maxTexY = math.ceil(screenHeight / (tex.height * bgTexScale))
	djui_hud_set_color_from_table(MENU_COLORS.bgTex)
	for tileY = -1, maxTexY do
		for tileX = -1, maxTexX do
			if tileX % 2 == tileY % 2 then
				djui_hud_render_texture(
					tex,
					bgTexScroll + tex.width * tileX * bgTexScale,
					bgTexScroll + tex.height * tileY * bgTexScale,
					bgTexScale,
					bgTexScale
				)
			end
		end
	end
	if menuMotionEnabled then
		bgTexScroll = (bgTexScroll + 2) % (tex.width * bgTexScale)
	else
		bgTexScroll = 0
	end
	tex = TEX_TRIANGLE

	local menu = menu_data[menuID]
	if not menu then
		return
	end

	-- Count valid buttons and find how far down the selected one is
	local scroll = false
	local scale = 3
	local totalButtons = 0
	local downBy = 0
	for i, button in ipairs(menu) do
		if option_valid(button, true) then
			totalButtons = totalButtons + 1
		end
		if menuOption == i then
			downBy = totalButtons
		end
	end
	scroll = (totalButtons > 1)

	-- Smooth vertical motion
	local desc = ""
	local x = 0
	local y = (screenHeight * 0.5) - 40 * (scale - 1) * downBy
	if resetMenuMotion or not menuMotionEnabled then
		menuMotionY = y
		menuMotionScrollY = -1
		menuMotionButton = {}
		resetMenuMotion = false
	else
		y = smooth_approach(y, menuMotionY, 0.25)
		menuMotionY = y
	end

	for i, button in ipairs(menu) do
		if option_valid(button, true) then
			local text = button[1]
			local textScale = scale
			local isSelectable = option_valid(button)

			-- Build description for the selected button
			if i == menuOption then
				if button.desc then
					desc = button.desc
					if type(desc) == "table" then
						local currNum = button.currNum or 0
						local min = button.minNum or 0
						desc = desc[currNum - min + 1] or desc[#desc] or ""
					end
					if button.descExtra then
						desc = string.format(desc, button.descExtra(button.currNum or 0))
					else
						desc = string.format(desc, button.currNum or 0)
					end
				end
			else
				textScale = textScale - 1
			end

			-- Append current numeric / named value
			if button.currNum then
				local optionText = ""
				local min = button.minNum or 0
				if button.playerRef then
					if button.currNum ~= -1 then
						local np = gNetworkPlayers[button.currNum]
						if not np.connected then
							button.currNum = 0
							np = gNetworkPlayers[0]
						end
						local playerColor = network_get_player_text_color_string(np.localIndex)
						optionText = playerColor .. np.name
					else
						optionText = "Random"
					end
				elseif button.nameRef and button.nameRef[button.currNum - min + 1] then
					optionText = button.nameRef[button.currNum - min + 1]
				elseif button.timeRef then
					if button.currNum ~= 0 then
						local seconds = button.currNum
						local minutes = seconds // 60
						seconds = seconds % 60
						optionText = string.format("%d:%02d", minutes, seconds)
					else
						optionText = "Infinite"
					end
				else
					local numScale = button.scale or 1
					optionText = tostring(button.currNum * numScale)
					if button.optionPrefix then
						optionText = button.optionPrefix .. optionText
					end
				end

				if i == menuOption and isSelectable then
					optionText = " < " .. optionText .. " \\#5050ff\\>"
				else
					optionText = ": " .. optionText
				end
				optionText = "\\#5050ff\\ " .. optionText
				text = text .. optionText
			end

			x = 100
			local width = djui_hud_measure_text(remove_color(text)) * textScale
			local testWidth = width / textScale * scale
			local origTextScale = textScale
			if x + 20 * scale + testWidth > screenWidth * 0.7 - tex.width then
				local origScale = textScale
				textScale = textScale / 2
				width = width / origScale * textScale
			end

			if i == menuOption then
				x = x + 20 * scale
			end

			-- Smooth per-button horizontal motion
			if menuMotionButton[i] == nil or not menuMotionEnabled then
				menuMotionButton[i] = {}
				menuMotionButton[i].x = x
				menuMotionButton[i].scale = textScale
			else
				local prevX = menuMotionButton[i].x
				local prevScale = menuMotionButton[i].scale
				local origScale = textScale
				x = smooth_approach(x, prevX, 0.25)
				textScale = smooth_approach(textScale * 10, prevScale * 10, 0.25) / 10
				menuMotionButton[i].x = x
				menuMotionButton[i].scale = textScale
				width = width / origScale * textScale
			end

			local valid = option_valid(button)
			local alpha = (valid and 255) or 100
			if origTextScale ~= textScale then
				y = y + 40 * (origTextScale - textScale) / 2
			end
			djui_hud_print_text_with_color(text, x, y, textScale, alpha)
			if i == menuOption then
				djui_hud_set_color(0, 255, 255, sins(frameCounter * 500) * 50 + 25)
				frameCounter = frameCounter + 1
				if frameCounter >= 60 then
					frameCounter = 0
				end
				djui_hud_render_rect(x - 6, y - 6, width + 12, 36 * textScale + 12)
			end
			if origTextScale ~= textScale then
				y = y - 40 * (origTextScale - textScale) / 2
			end
			y = y + 40 * origTextScale
		end
	end

	-- Right-side description panel
	djui_hud_set_color_from_table(MENU_COLORS.descBg)
	djui_hud_render_rect(screenWidth * 0.7, 0, screenWidth + 10, screenHeight + 10)
	local triY = -tex.height
	while triY < screenHeight do
		djui_hud_render_texture(TEX_TRIANGLE, screenWidth * 0.7 - tex.width, triY, 1, 2)
		triY = triY + tex.height * 2
	end
	if #desc ~= 0 then
		local descScale = 1
		local lines = {}
		local line = ""
		desc = desc:gsub("\n", " \n ")
		local words = split(desc, " ")
		local lineWidth = 0
		local spaceWidth = djui_hud_measure_text(" ") * descScale
		for _, word in ipairs(words) do
			if word == "\n" then
				table.insert(lines, line)
				line = ""
				lineWidth = 0
			else
				local wordWidth = djui_hud_measure_text(remove_color(word)) * descScale
				if lineWidth + wordWidth > screenWidth * 0.3 - 50 then
					table.insert(lines, line)
					line = ""
					lineWidth = 0
				end
				line = line .. word .. " "
				lineWidth = lineWidth + wordWidth + spaceWidth
			end
		end
		if #line ~= 0 then
			table.insert(lines, line)
		end
		local dx = screenWidth * 0.7 + 25
		local dy = (screenHeight / 2) - (#lines * 16 + 16) * descScale
		local colorString = ""
		for _, ln in ipairs(lines) do
			djui_hud_print_text_with_color(colorString .. ln, dx, dy, descScale)
			colorString = ""
			local color = djui_hud_get_color()
			if color.r ~= 255 or color.g ~= 255 or color.b ~= 255 then
				colorString = string.format("\\#%02x%02x%02x\\", color.r, color.g, color.b)
			end
			dy = dy + 32 * descScale
		end
	end

	-- Animated scroll bar
	if scroll then
		local sx = 50 - 16
		local sy = 50
		djui_hud_set_color_from_table(MENU_COLORS.scrollBg)
		djui_hud_render_rect(sx, sy, 20, screenHeight - 100)
		local portion = 1 / totalButtons
		local height = (screenHeight - 104) * portion
		sy = sy + ((screenHeight - 104) - height) * (downBy - 1) / (totalButtons - 1)
		if menuMotionEnabled and menuMotionScrollY ~= -1 then
			local prevSY = menuMotionScrollY
			sy = smooth_approach(sy, prevSY, 0.25)
			menuMotionScrollY = sy
		else
			menuMotionScrollY = sy
		end
		djui_hud_set_color_from_table(MENU_COLORS.scrollBar)
		djui_hud_render_rect(sx + 2, sy + 2, 16, height)
	end
end

sMenuInputsPressed = 0
sMenuInputsDown = 0
---@param m MarioState
function menu_controls(m)
	if m.playerIndex ~= 0 then
		return
	end
	if not inMenu then
		if m.controller.buttonPressed & START_BUTTON ~= 0 then
			m.controller.buttonPressed = m.controller.buttonPressed & ~START_BUTTON
			sMenuInputsDown = START_BUTTON
			open_menu()
		else
			return
		end
	end
	if inMenu then
		local m = gMarioStates[0]
		if charSelectExists then
			if m.controller.buttonPressed & Z_TRIG ~= 0 then
				charSelect.set_menu_open(true)
				sMenuInputsDown = Z_TRIG
				inMenu = false
			end
		end
	end

	if m.freeze < 3 then
		m.freeze = 3
	end

	-- Disable controls for everything but the menu
	sMenuInputsPressed = m.controller.buttonDown & (m.controller.buttonDown ~ sMenuInputsDown)
	sMenuInputsDown = m.controller.buttonDown
	m.controller.buttonDown = 0
	m.controller.buttonPressed = 0
	m.controller.stickX = 0
	m.controller.stickY = 0

	if sMenuInputsPressed & R_TRIG ~= 0 then
		djui_open_pause_menu()
	end

	local stickX = m.controller.rawStickX
	if (sMenuInputsDown & L_JPAD) ~= 0 then
		stickX = stickX - 65
	end
	if (sMenuInputsDown & R_JPAD) ~= 0 then
		stickX = stickX + 65
	end
	local stickY = m.controller.rawStickY
	if (sMenuInputsDown & D_JPAD) ~= 0 then
		stickY = stickY - 65
	end
	if (sMenuInputsDown & U_JPAD) ~= 0 then
		stickY = stickY + 65
	end

	if stickCooldownY > 0 then
		stickCooldownY = stickCooldownY - 1
	end
	if stickCooldownX > 0 then
		stickCooldownX = stickCooldownX - 1
	end

	local menu = menu_data[menuID]
	if not menu then
		inMenu = false
		return
	end
	local button = menu[menuOption]

	if (sMenuInputsPressed & A_BUTTON) ~= 0 and button and button[2] and not button.runOnChange then
		if not option_valid(button) then
			play_sound(SOUND_MENU_CAMERA_BUZZ, m.marioObj.header.gfx.cameraToObject)
		else
			play_sound(SOUND_MENU_CLICK_FILE_SELECT, m.marioObj.header.gfx.cameraToObject)
			button[2](button.currNum, button)
		end
	elseif (sMenuInputsPressed & B_BUTTON) ~= 0 then
		if #menu_history ~= 0 then
			play_sound(SOUND_MENU_CLICK_FILE_SELECT, m.marioObj.header.gfx.cameraToObject)
			enter_menu(menu_history[#menu_history][1], menu_history[#menu_history][2], true)
			table.remove(menu_history, #menu_history)
		else
			play_sound(SOUND_MENU_CLICK_FILE_SELECT, m.marioObj.header.gfx.cameraToObject)
			m.controller.buttonDown = B_BUTTON
			inMenu = false
		end
	elseif (sMenuInputsPressed & START_BUTTON) ~= 0 then
		play_sound(SOUND_MENU_CLICK_FILE_SELECT, m.marioObj.header.gfx.cameraToObject)
		m.controller.buttonDown = START_BUTTON
		inMenu = false
	end

	if not button then
		return
	end

	-- Horizontal stick: change numeric values
	if button.currNum and stickCooldownX == 0 and (stickX > 64 or stickX < -64) and option_valid(button) then
		local min = button.minNum or 0
		local max = button.maxNum or 999
		local change = 1
		-- Hold X for ×10 increments on wide-range options
		local changeScale = (max - min >= 10 and sMenuInputsDown & X_BUTTON ~= 0 and 10) or 1
		if stickX < 0 then
			change = -change
		end

		play_sound(SOUND_MENU_CHANGE_SELECT, m.marioObj.header.gfx.cameraToObject)
		button.currNum = button.currNum + change * changeScale

		if max < button.currNum then
			button.currNum = min
		elseif min > button.currNum then
			button.currNum = max
		elseif button.currNum == button.excludeNum then
			button.currNum = button.currNum + change
		end

		-- Skip disconnected players when using playerRef
		if button.playerRef and button.currNum >= 0 and button.currNum < MAX_PLAYERS then
			local np = gNetworkPlayers[button.currNum]
			while not np.connected do
				button.currNum = button.currNum + change
				if max < button.currNum then
					button.currNum = min
				elseif button.currNum == button.excludeNum then
					button.currNum = button.currNum + change
				end
				if button.currNum < 0 or button.currNum >= MAX_PLAYERS then
					break
				end
				np = gNetworkPlayers[button.currNum]
			end
		end

		stickCooldownX = 5
		if button.runOnChange and button[2] then
			button[2](button.currNum, button)
			if (network_is_server() or button.localSave) and button.save then
				mod_storage_save(button.save, tostring(button.currNum))
			end
		end
	end

	-- Vertical stick: navigate buttons
	if #menu > 1 and stickCooldownY == 0 then
		if stickY > 64 then
			play_sound(SOUND_MENU_CHANGE_SELECT, m.marioObj.header.gfx.cameraToObject)
			local valid = true
			local LIMIT = #menu
			while valid and LIMIT ~= 0 do
				LIMIT = LIMIT - 1
				menuOption = menuOption - 1
				if menuOption < 1 then
					menuOption = #menu
				end
				button = menu[menuOption]
				valid = not option_valid(button, true)
			end
			stickCooldownY = 5
		elseif stickY < -64 then
			play_sound(SOUND_MENU_CHANGE_SELECT, m.marioObj.header.gfx.cameraToObject)
			local valid = true
			local LIMIT = #menu
			while valid and LIMIT ~= 0 do
				LIMIT = LIMIT - 1
				menuOption = menuOption + 1
				if #menu < menuOption then
					menuOption = 1
				end
				button = menu[menuOption]
				valid = not option_valid(button, true)
			end
			stickCooldownY = 5
		end
	end
end

function open_menu()
	inMenu = not inMenu
	if inMenu then
		menu_history = {}
		menuMotionButton = {}
		resetMenuMotion = true
		sMenuInputsDown = gMarioStates[0].controller.buttonDown
		enter_menu(1, 1, true)
		play_sound(SOUND_MENU_PAUSE, gGlobalSoundSource)
	end
	return true
end

function enter_menu(id, option, back)
	if not back then
		table.insert(menu_history, { menuID, menuOption })
	end

	menuMotionButton = {}
	if not inMenu then
		inMenu = true
		resetMenuMotion = true
		menu_history = {}
		sMenuInputsDown = gMarioStates[0].controller.buttonDown
	end
	menuID = id or 1
	menuOption = option or 1

	local menu = menu_data[menuID]
	if not menu then
		inMenu = false
		return
	elseif menu.buildFunc then
		menu_data[menuID] = { buildFunc = menu.buildFunc }
		menu = menu_data[menuID]
		menu.buildFunc(menu)
	end

	local totalValid = 0
	local lastValidOption = 0
	for i = 1, #menu do
		if option_valid(menu[i], true) then
			totalValid = totalValid + 1
			lastValidOption = i
		elseif menuOption == i then
			if lastValidOption == 0 then
				menuOption = menuOption + 1
			else
				menuOption = lastValidOption
			end
		end
	end

	if totalValid == 0 then
		if #menu_history ~= 0 then
			enter_menu(menu_history[#menu_history][1], menu_history[#menu_history][2], true)
			table.remove(menu_history, #menu_history)
		else
			inMenu = false
		end
		return
	end

	for i, button in ipairs(menu) do
		if button.save then
			local value = 0
			if not button.localSave then
				value = gGlobalSyncTable[button.save]
			else
				value = _ENV[button.save]
			end
			if type(value) == "boolean" then
				button.currNum = (value and 1) or 0
			elseif type(value) == "number" and value % 1 == 0 then
				button.currNum = value
				local min = button.minNum or 0
				local max = button.maxNum or 100
				if value < min then
					button.currNum = min
				elseif value > max then
					button.currNum = max
				end
			end
		end
		if button.updateNum then
			button.updateNum(button)
		end
	end
end

function reload_menu()
	enter_menu(menuID, menuOption, true)
end

function set_menu_option(id, option, value)
	menu_data[id][option].currNum = value
end

function get_menu_option(id, option)
	return menu_data[id][option].currNum
end

-- Two-argument version: ignoreSelect skips selectInvalid checks,
-- matching the WarioWare behaviour used for visibility vs. interactability.
function option_valid(button, ignoreSelect)
	if (not ignoreSelect) and button.selectInvalid and button.selectInvalid() then
		return false
	end
	if button[3] and not (network_is_server() or network_is_moderator()) then
		return false
	elseif button[4] then
		return (not button[4]())
	end
	return true
end

-- Load saved menu settings on startup
for a, menu in ipairs(menu_data) do
	for b, button in ipairs(menu) do
		if (network_is_server() or button.localSave) and button.save then
			local value = tonumber(mod_storage_load(button.save))
			local min = button.minNum or 0
			local max = button.maxNum or 999
			if value and value % 1 == 0 and button.currNum and value >= min and value <= max then
				button[2](value, button)
				button.currNum = value
			end
		end
	end
end

-- CS support
if charSelectExists then
	charSelect.restrict_palettes(false)
end
