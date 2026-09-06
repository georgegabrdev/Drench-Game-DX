local HU = require("../hud-utils")
local MWI = require("../tweaks/c-mWins")
local TRANSLATIONS = require("../translations/translation-main")
local M = {}

-- all hud stuff
local scoreMenuTimer = 0
local addPointTimer = 0
local scoreMenuFinal = false
local standingsBarCurrY = {}
local lastCountdownNumber = 0

local CountdownAnim = {
	time = 0,
	prevTime = 0,

	anim = {
		timeEnter = 8,
		timeStay = 14,
		timeExit = 8,
	},
}
local countdownTimer = 0
local hudHint = -1
local gaveMiniWin = false

local function get_display_name(i)
	local np = gNetworkPlayers[i]
	if not np then
		return "Unknown"
	end

	local name = np.name or "Unknown"

	if name == "Player" then
		name = "Player " .. i
	end

	return name
end

function M.render_main_hud()
	djui_hud_set_resolution(RESOLUTION_N64)
	djui_hud_set_font(djui_menu_get_font())

	-- reset score menu fields
	if gGlobalSyncTable.gameState ~= GAME_STATE_SCORES then
		scoreMenuTimer = 0
		addPointTimer = 0
		hudHint = -1
		scoreMenuFinal = false
	end

	if inMenu then
		return render_menu()
	end

	-- side bar
	local sideBarLines = {}
	local screenWidth, screenHeight = djui_hud_get_screen_width(), djui_hud_get_screen_height()
	local width = math.floor(screenWidth * 0.2)
	local scale = 0.25
	local lengthLimit = width / scale - 40 * scale
	if gGlobalSyncTable.gameState ~= GAME_STATE_MINI_END then
		gaveMiniWin = false
	end

	if gGlobalSyncTable.gameState == GAME_STATE_LOBBY then
		scale = 0.2
		lengthLimit = width / scale - 40 * scale
		for_each_connected_player(function(i)
			local sMario = gPlayerSyncTable[i]
			local addStr = "\\#ff5050\\Waiting..."
			if sMario.ready then
				addStr = "\\#50ff50\\Ready!"
			end
			local name = network_get_player_text_color_string(i) .. get_display_name(i)
			name = cap_color_text(name, 18)
			add_line_to_table(sideBarLines, name .. ": " .. addStr, lengthLimit)
		end)
		if gGlobalSyncTable.gameTimer ~= 0 then
			local timeUntilStart = math.max(5 - gGlobalSyncTable.gameTimer // 30, 0)
			add_line_to_table(sideBarLines, translate("starting_in") .. tostring(timeUntilStart), lengthLimit)
		end
	elseif gGlobalSyncTable.gameState == GAME_STATE_RULES then
		local gData = GAME_MODE_DATA[gGlobalSyncTable.gameMode]
		djui_hud_set_font(djui_menu_get_font())
		add_line_to_table(sideBarLines, "\\#ffff50\\" .. gData.name, lengthLimit)
		if gGlobalSyncTable.eliminationMode then
			table.insert(sideBarLines, "\\#ff5050\\Elimination Mode")
		end
		table.insert(
			sideBarLines,
			translate("minigame_text") .. gGlobalSyncTable.miniGameNum .. "/" .. gGlobalSyncTable.maxMiniGames
		)
		table.insert(sideBarLines, "")

		local desc = gData.desc
		if is_final_duel() or gGlobalSyncTable.eliminationMode then
			if gGlobalSyncTable.teamCount == 0 then
				desc = gData.descElim or desc
			else
				desc = gData.descTeamsElim or desc
			end
		elseif gGlobalSyncTable.teamCount ~= 0 then
			desc = gData.descTeams or desc
		end
		add_line_to_table(sideBarLines, desc, lengthLimit)

		if gGlobalSyncTable.gameTimer > 360 then
			local number = (450 - gGlobalSyncTable.gameTimer) // 30 + 1

			if lastCountdownNumber ~= number then
				lastCountdownNumber = number
				CountdownAnim.time = 0
				CountdownAnim.prevTime = 0
				play_sound(SOUND_GENERAL2_SWITCH_TICK_FAST, gGlobalSoundSource)
			end

			local total = CountdownAnim.anim.timeEnter + CountdownAnim.anim.timeStay + CountdownAnim.anim.timeExit

			local function get_progress(t)
				if t <= CountdownAnim.anim.timeEnter then
					return t / CountdownAnim.anim.timeEnter
				elseif t <= CountdownAnim.anim.timeEnter + CountdownAnim.anim.timeStay then
					return 1
				else
					local exit = t - CountdownAnim.anim.timeEnter - CountdownAnim.anim.timeStay
					return 1 - math.min(exit / CountdownAnim.anim.timeExit, 1)
				end
			end

			local prev = get_progress(CountdownAnim.prevTime)
			local curr = get_progress(CountdownAnim.time)

			-- smoothstep
			prev = prev * prev * (3 - 2 * prev)
			curr = curr * curr * (3 - 2 * curr)

			local alpha = math.floor(255 * curr)

			local text = tostring(number)
			if number == 0 then
				text = "GO!"
			end

			local scalePrev = 2.5 - (1.5 * prev)
			local scaleCurr = 2.5 - (1.5 * curr)

			local screenW = djui_hud_get_screen_width()
			local screenH = djui_hud_get_screen_height()

			local wPrev = djui_hud_measure_text(text) * scalePrev
			local wCurr = djui_hud_measure_text(text) * scaleCurr

			local xPrev = (screenW - wPrev) / 2
			local xCurr = (screenW - wCurr) / 2

			local yPrev = screenH / 2 - 50
			local yCurr = screenH / 2 - 50

			-- colors
			local r, g, b = 255, 255, 255

			if number == 3 then
				r, g, b = 255, 70, 70
			elseif number == 2 then
				r, g, b = 255, 200, 50
			elseif number == 1 then
				r, g, b = 70, 255, 90
			elseif number == 0 then
				r, g, b = 70, 180, 255
			end

			-- shadow
			djui_hud_set_color(0, 0, 0, math.floor(alpha * 0.5))

			djui_hud_print_text_interpolated(
				text,
				xPrev + 2,
				yPrev + 2,
				scalePrev,
				scalePrev,
				xCurr + 2,
				yCurr + 2,
				scaleCurr,
				scaleCurr
			)

			-- main
			djui_hud_set_color(r, g, b, alpha)

			djui_hud_print_text_interpolated(
				text,
				xPrev,
				yPrev,
				scalePrev,
				scalePrev,
				xCurr,
				yCurr,
				scaleCurr,
				scaleCurr
			)

			CountdownAnim.prevTime = CountdownAnim.time
			CountdownAnim.time = math.min(CountdownAnim.time + 1, total)
		else
			lastCountdownNumber = 0
			CountdownAnim.time = 0
			CountdownAnim.prevTime = 0
		end
	elseif gGlobalSyncTable.gameState == GAME_STATE_ACTIVE then
		local gData = GAME_MODE_DATA[gGlobalSyncTable.gameMode]
		djui_hud_set_font(djui_menu_get_font())
		add_line_to_table(sideBarLines, "\\#ffff50\\" .. gData.name, lengthLimit)
		if gGlobalSyncTable.eliminationMode then
			table.insert(sideBarLines, "\\#ff5050\\Elimination Mode")
		end

		if gData.roundTime and gGlobalSyncTable.eliminateThisRound ~= 0 then
			if gGlobalSyncTable.eliminateThisRound == 1 then
				add_line_to_table(sideBarLines, "\\#ff5050\\Last place eliminated", lengthLimit)
			else
				add_line_to_table(
					sideBarLines,
					"\\#ff5050\\Bottom " .. tostring(gGlobalSyncTable.eliminateThisRound) .. " eliminated",
					lengthLimit
				)
			end

			-- display our score and safe score
			local sMario0 = gPlayerSyncTable[0]
			local score = sMario0.roundScore or 0
			local scoreText = translate("yourscore")
			if sMario0.eliminated and (spectatedPlayer > 0 and spectatedPlayer < MAX_PLAYERS) then
				-- display spectated player's score instead
				score = gPlayerSyncTable[spectatedPlayer].roundScore or 0
				scoreText = translate("theirscore")
			end
			local scale = 0.25
			local safeScore = get_safe_score(get_standings_table("roundScore"))
			local color = "\\#50ff50\\"
			if safeScore > score then
				color = "\\#ff5050\\"
			end
			local text
			local text2
			if gData.removeDecimal then
				text = string.format(scoreText .. color .. "%.0f", score / 10)
				text2 = string.format("%s %.0f", translate("safescore"), safeScore / 10)
			else
				text = string.format(scoreText .. color .. "%.1f", score / 10)
				text2 = string.format("%s %.1f", translate("safescore"), safeScore / 10)
			end
			local width = djui_hud_measure_text(remove_color(text)) * scale
			local width2 = djui_hud_measure_text(remove_color(text2)) * scale
			local maxWidth = math.max(width, width2)
			local x = (screenWidth - maxWidth) / 2
			local y = 10 * scale
			djui_hud_set_color(0, 0, 0, 100)
			HU.djui_hud_render_rect_rounded(
				x - 10 * scale,
				y - 17 * scale,
				maxWidth + 20 * scale,
				84 * scale,
				14 * scale
			)
			x = (screenWidth - width) / 2
			djui_hud_print_text_with_color_and_outline(text, x, y, scale)
			y = y + 32 * scale
			x = (screenWidth - width2) / 2
			djui_hud_print_text_with_color_and_outline(text2, x, y, scale)
		end
		local excluded_g = {
			[GAME_MODE_BOMB_TAG] = true,
			[GAME_MODE_DICE] = true,
			[GAME_MODE_DUEL] = true,
		}
		local lbStandings = get_standings_table("roundScore")
		local gData = GAME_MODE_DATA[gGlobalSyncTable.gameMode]
		local excluded = excluded_g[gGlobalSyncTable.gameMode] == true
		local hasScores = false
		if not excluded and gData then
			for i, data in ipairs(lbStandings) do
				if (data[2] or 0) ~= 0 then
					hasScores = true
					break
				end
			end
		end

		if hasScores then
			local lbScale = 0.2
			local lbWidth = screenWidth * 0.22
			local lbX = screenWidth - lbWidth - 10
			local lbEntryH = 32 * lbScale
			local lbPad = 10 * lbScale
			local lbCount = 0
			for i, data in ipairs(lbStandings) do
				if gNetworkPlayers[data[1]].connected then
					lbCount = lbCount + 1
				end
			end

			local lbTotalH = lbCount * lbEntryH + lbPad * 2 + 20 * lbScale
			local lbY = (screenHeight - lbTotalH) / 2

			djui_hud_set_color(0, 0, 0, 120)
			HU.djui_hud_render_rect_rounded(lbX - lbPad, lbY - lbPad, lbWidth + lbPad * 2, lbTotalH, 10 * lbScale)

			djui_hud_set_font(djui_menu_get_font())
			local headerText = translate("rankings")
			local hw = djui_hud_measure_text(remove_color(headerText)) * lbScale
			djui_hud_print_text_with_color_and_outline(headerText, lbX + (lbWidth - hw) / 2, lbY, lbScale, 255, 2)
			lbY = lbY + 20 * lbScale

			local lbPlace = 1
			local lbPrevScore = nil
			local lbDisplayedPlace = 1

			for i, data in ipairs(lbStandings) do
				local index = data[1]
				local np = gNetworkPlayers[index]
				if np.connected then
					local score = data[2] or 0

					if lbPrevScore ~= nil and score ~= lbPrevScore then
						lbDisplayedPlace = lbPlace
					elseif lbPrevScore == nil then
						lbDisplayedPlace = 1
					end
					lbPrevScore = score
					lbPlace = lbPlace + 1

					if index == 0 then
						djui_hud_set_color(255, 255, 255, 30)
						HU.djui_hud_render_rect_rounded(
							lbX - lbPad,
							lbY - 4 * lbScale,
							lbWidth + lbPad * 2,
							lbEntryH,
							6 * lbScale
						)
					end

					local placeStr = placeString(lbDisplayedPlace)
					djui_hud_print_text_with_color_and_outline(placeStr, lbX, lbY, lbScale / 1.2, 255, 2)

					local nameColor = network_get_player_text_color_string(index)
					local name = cap_color_text(nameColor .. get_display_name(index), 999)
					djui_hud_print_text_with_color_and_outline(name, lbX + 40 * lbScale, lbY, lbScale / 1.2, 255, 2)

					local scoreVal = gData.removeDecimal and string.format("%.0f", score / 10)
						or string.format("%.1f", score / 10)

					local scoreColor = "\\#ffffff\\"
					if gGlobalSyncTable.eliminateThisRound ~= 0 then
						local safeScore = get_safe_score(lbStandings)
						scoreColor = score >= safeScore and "\\#50ff50\\" or "\\#ff5050\\"
					end
					local scoreText = scoreColor .. scoreVal
					local sw = djui_hud_measure_text(remove_color(scoreText)) * lbScale
					djui_hud_print_text_with_color_and_outline(
						scoreText,
						lbX + lbWidth - sw,
						lbY,
						lbScale / 1.1,
						255,
						2
					)

					lbY = lbY + lbEntryH
				end
			end
		end
		table.insert(sideBarLines, "")

		local roundTime = gData.roundTime or 0
		if gData.firstRoundTime and gGlobalSyncTable.round == 1 then
			roundTime = gData.firstRoundTime
		end
		if gGlobalSyncTable.freezeRoundTimer then
			roundTime = 0
		end
		local maxTime = gData.maxTime or 3 * 30 * 60 -- default 3 minutes max
		if gData.maxRounds and gData.roundTime and gData.roundTime > 0 then
			maxTime = gData.firstRoundTime or gData.roundTime
			maxTime = maxTime + gData.roundTime * (gData.maxRounds - 1)
		end

		local gameTimeLeft = maxTime - gGlobalSyncTable.gameTimer
		local roundTimeLeft = roundTime - gGlobalSyncTable.roundTimer
		if maxTime == -1 then
			gameTimeLeft = 99999 -- FOREVER
		end

		---@type boolean?,boolean?
		local sideBarOverride, sideBarDisable = false, false
		if gData.hudRenderFunc then
			sideBarOverride, sideBarDisable = gData.hudRenderFunc(
				screenWidth,
				screenHeight,
				sideBarLines,
				lengthLimit,
				roundTime,
				roundTimeLeft,
				gameTimeLeft,
				maxTime
			)
		end
		if sideBarDisable then
			sideBarLines = {} -- no side bar
		elseif not sideBarOverride then
			if roundTime ~= 0 and gameTimeLeft >= roundTimeLeft then
				add_line_to_table(
					sideBarLines,
					get_time_string(roundTimeLeft) .. translate("untilelimination"),
					lengthLimit
				)
			elseif maxTime ~= -1 then
				add_line_to_table(
					sideBarLines,
					get_time_string(gameTimeLeft) .. translate("untilgameends"),
					lengthLimit
				)
			else
				sideBarLines = {} -- no side bar
			end
		end

		if gMarioStates[0].action == ACT_SPECTATE then
			local scale = 0.2
			local paddingX = 6
			local paddingY = 2
			local rectHeight = 11
			local thickness = 0.25

			local targetName

			if spectateStar then
				targetName = "\\#ffff00\\Star"
			elseif gNetworkPlayers[spectatedPlayer] then
				targetName = network_get_player_text_color_string(spectatedPlayer) .. get_display_name(spectatedPlayer)
			else
				targetName = "Unknown"
			end

			local text = "\\#ffffff\\< " .. targetName .. " \\#ffffff\\>"

			local rawWidth = djui_hud_measure_text(text)
			local measureText = rawWidth * scale

			local screenW = djui_hud_get_screen_width()
			local screenH = djui_hud_get_screen_height()

			local x = (screenW - measureText) / 2
			local y = screenH - 30

			local rectWidth = measureText + (paddingX * 2)
			local rectX = x - paddingX
			local rectY = y - paddingY

			if not spectateStar and gNetworkPlayers[spectatedPlayer] then
				djui_hud_set_color(0, 0, 0, 128)
				HU.djui_hud_render_rect_rounded_outlined(
					rectX,
					rectY,
					rectWidth,
					rectHeight,
					255,
					255,
					255,
					thickness,
					128
				)
			else
				djui_hud_set_color(0, 0, 0, 128)
				HU.djui_hud_render_rect_rounded(rectX, rectY, rectWidth, rectHeight, 5)
			end

			djui_hud_set_color(255, 255, 255, 255)
			djui_hud_print_text(text, x, y, scale)
		end
	elseif gGlobalSyncTable.gameState == GAME_STATE_MINI_END then
		if is_final_duel() then
			return
		end
		local scale = 1
		local text = translate("no_one_won")

		if gGlobalSyncTable.eliminationMode then
			local sMario = gPlayerSyncTable[0]
			if not sMario.eliminated then
				text = translate("you_survived")
			elseif sMario.roundEliminated ~= 0 then
				text = translate("you_died")
			else
				text = ""
			end
		else
			local standings = get_standings_table("earnedPoints")
			local foundWinner = false
			local prevScore = 0
			for i, data in ipairs(standings) do
				local index = data[1]
				if data[2] ~= 0 and ((not foundWinner) or prevScore == data[2]) then
					prevScore = data[2]
					if foundWinner then
						text = translate("multiple_winners")
						break
					else
						foundWinner = true
						text = network_get_player_text_color_string(index)
							.. get_display_name(index)
							.. translate("wins_suffix")
						if index == 0 and not gaveMiniWin then
							gaveMiniWin = true
							MWI.add_m_win()
						end
					end
				elseif foundWinner and prevScore ~= data[2] then
					break
				end
			end
		end

		if #text ~= 0 then
			local width = djui_hud_measure_text(remove_color(text)) * scale
			local x = (screenWidth - width) / 2
			local y = screenHeight / 2 - 16 * scale
			djui_hud_set_color(0, 0, 0, 100)
			HU.djui_hud_render_rect_rounded(x - 10 * scale, y - 10 * scale, width + 20 * scale, 52 * scale, 10 * scale)
			djui_hud_set_color(255, 255, 255, 255)
			djui_hud_print_text_with_color_and_outline(text, x, y, scale, 255, 2)
		end
	elseif gGlobalSyncTable.gameState == GAME_STATE_SCORES then
		local standings = {}
		local prevPlace = {}
		if gGlobalSyncTable.eliminationMode then
			scoreMenuFinal = true
			standings = get_standings_table_bool("eliminated")
		elseif not scoreMenuFinal then
			standings = get_standings_table("earnedPoints")
		else
			standings = get_standings_table("points")
			if gGlobalSyncTable.miniGameNum > 1 then
				local lastStandings = get_standings_table("points", "earnedPoints")
				local prevScore = 0
				local place = 1
				local newPlace = 0
				local prevTeam = -1
				for i, data in ipairs(lastStandings) do
					local index = data[1]
					local sMario = gPlayerSyncTable[index]
					if sMario.team == nil or sMario.team == 0 or sMario.team ~= prevTeam then
						newPlace = newPlace + 1
						prevTeam = sMario.team
					end
					if data[2] ~= prevScore then
						prevScore = data[2]
						place = newPlace
					end
					prevPlace[index] = place
				end
			end
		end

		while do_solo_debug() and #standings < MAX_PLAYERS do
			table.insert(standings, { #standings, #standings })
		end

		local scale = 0.2
		local width = screenWidth * 0.5
		local x = 0
		local y = 5
		local leftToEarn = false
		local prevScore = 0
		local place = 1
		local newPlace = 0
		local prevTeam = -1
		for i, data in ipairs(standings) do
			local index = data[1]
			local sMario = gPlayerSyncTable[index]
			local gamePoints = sMario.points or 0
			if not scoreMenuFinal then
				gamePoints = gamePoints - (sMario.earnedPoints or 0)
			elseif (not gGlobalSyncTable.eliminatedMode) and sMario.team and sMario.team ~= 0 then
				gamePoints = data[2]
			end
			local renderY = y
			if standingsBarCurrY[index] and scoreMenuTimer ~= 0 then
				renderY = smooth_approach(renderY, standingsBarCurrY[index], 0.25)
			end
			standingsBarCurrY[index] = renderY

			x = (screenWidth - width) / 2
			if sMario.team == nil or sMario.team == 0 or sMario.team > #TEAM_DATA then
				djui_hud_set_color(0, 0, 0, 100)
			else
				local color = TEAM_DATA[sMario.team][2]
				djui_hud_set_color(color.r, color.g, color.b, 100)
			end
			HU.djui_hud_render_rect_rounded(x, renderY - 10 * scale, width, 52 * scale, 10 * scale)

			x = x + 20 * scale
			if not gGlobalSyncTable.eliminationMode then
				if sMario.team == nil or sMario.team == 0 or sMario.team ~= prevTeam then
					newPlace = newPlace + 1
					prevTeam = sMario.team
				end

				if data[2] ~= prevScore then
					prevScore = data[2]
					place = newPlace
				end

				if prevPlace[index] then
					local progressText = "\\#02fa13\\-"
					if prevPlace[index] < place then
						progressText = "\\#025dfa\\v"
					elseif prevPlace[index] > place then
						progressText = "\\#fa5102\\^"
					end

					djui_hud_print_text_with_color_and_outline(progressText, x, renderY, scale, 255, 2)
				end

				x = x + 30 * scale

				local text = placeString(place)
				djui_hud_print_text_with_color_and_outline(text, x, renderY, scale, 255, 2)

				x = x + 70 * scale
			end

			local np = gNetworkPlayers[index]
			local name = network_get_player_text_color_string(index) .. np.name
			djui_hud_print_text_with_color_and_outline(name, x, renderY, scale, 255, 2)

			local scoreText = ""
			local earned = (sMario.earnedPoints or 0)
			if not gGlobalSyncTable.eliminationMode then
				if (not scoreMenuFinal) and addPointTimer ~= 0 then
					gamePoints = gamePoints + math.min(addPointTimer, earned)
				end
				earned = earned - addPointTimer
				scoreText = "\\#ffff50\\" .. tostring(gamePoints)
				if scoreMenuFinal and gGlobalSyncTable.teamCount ~= 0 then
					scoreText = scoreText .. " (" .. tostring(sMario.points) .. ")"
				end
			elseif not data[2] then
				scoreText = translate("alive")
			else
				scoreText = translate("dead")
			end
			x = (screenWidth + width) / 2 - (djui_hud_measure_text(remove_color(scoreText)) + 20) * scale
			djui_hud_print_text_with_color_and_outline(scoreText, x, renderY, scale, 255, 2)

			if (not scoreMenuFinal) and earned > 0 then
				x = (screenWidth + width) / 2 - 120 * scale
				scoreText = "+" .. tostring(earned)
				leftToEarn = true
				scoreText = "\\#ffff50\\" .. scoreText
				djui_hud_print_text_with_color_and_outline(scoreText, x, renderY, scale, 255, 2)
			end

			y = y + 60 * scale
		end

		scoreMenuTimer = scoreMenuTimer + 1
		if leftToEarn and scoreMenuTimer >= 60 and scoreMenuTimer % 3 == 0 then
			addPointTimer = addPointTimer + 1
			play_sound(SOUND_GENERAL_COIN, gGlobalSoundSource)
		end
		if (not (leftToEarn or scoreMenuFinal)) and scoreMenuTimer >= 150 then
			scoreMenuFinal = true
			play_sound(SOUND_MENU_STAR_SOUND, gGlobalSoundSource)
		end

		if hudHint == -1 then
			hudHint = math.random(1, 24)
		end
		local text = get_hint(hudHint)
		local connectionsNeeded = 2
		local validPlayers = 0
		for_each_connected_player(function(index)
			validPlayers = validPlayers + 1
			if validPlayers >= connectionsNeeded then
				return true
			end
		end)
		if validPlayers == 0 or not (do_solo_debug() or validPlayers >= connectionsNeeded) then
			text = "Waiting for players..."
		end

		local scale = 0.2
		local lines = {}
		add_line_to_table(lines, text, (screenWidth * 0.8) / scale)
		local y = screenHeight - #lines * 32 * scale
		for i, line in ipairs(lines) do
			local width = djui_hud_measure_text(line) * scale
			local x = (screenWidth - width) / 2
			djui_hud_print_text_with_color_and_outline(line, x, y, scale, 255, 2)
			y = y + 32 * scale
		end
	elseif gGlobalSyncTable.gameState == GAME_STATE_GAME_END then
		local lines = {}
		local winners = get_winners_table()
		local names = {}
		local teamCounted = {}
		for i, index in ipairs(winners) do
			local sMario = gPlayerSyncTable[index]
			if sMario.team == nil or sMario.team == 0 or sMario.team > #TEAM_DATA then
				local text = network_get_player_text_color_string(index) .. get_display_name(index)
				table.insert(names, text)
			elseif not teamCounted[sMario.team] then
				teamCounted[sMario.team] = 1
				local text = TEAM_DATA[sMario.team][3]
				table.insert(names, text)
			end
		end

		if #names == 0 then
			table.insert(lines, translate("no_one_won"))
		elseif #names == 1 then
			local text = names[1] .. translate("wins_suffix")
			table.insert(lines, text)
		else
			table.insert(lines, translate("winners_colon"))
			for i, name in ipairs(names) do
				table.insert(lines, name)
			end
		end

		local scale = 0.5
		local y = 20
		for i, line in ipairs(lines) do
			local width = djui_hud_measure_text(remove_color(line)) * scale
			local x = (screenWidth - width) / 2
			djui_hud_set_color(0, 0, 0, 100)
			HU.djui_hud_render_rect_rounded(x - 10 * scale, y - 10 * scale, width + 20 * scale, 52 * scale, 10 * scale)
			djui_hud_set_color(255, 255, 255, 255)
			djui_hud_print_text_with_color_and_outline(line, x, y, scale, 255, 2)
			y = y + 52 * scale
		end
	end

	if #sideBarLines ~= 0 then
		local x = 20 * scale
		local y = (screenHeight / 2) - #sideBarLines * 16 * scale
		djui_hud_set_color(0, 0, 0, 100)
		HU.djui_hud_render_rect_rounded(2, y - 10 * scale, width, (#sideBarLines * 32 + 20) * scale, 12 * scale)
		for i, line in ipairs(sideBarLines) do
			djui_hud_print_text_with_color_and_outline(line, x, y, scale, 255, 2)
			y = y + 32 * scale
		end
	end
	local modifiers = {}
	local modifierList = {
		{ modifierBits.superSpeed, "50ff50", "super_speed" },
		{ modifierBits.highGravity, "ff5050", "high_gravity" },
		{ modifierBits.lowGravity, "50a0ff", "low_gravity" },
		{ modifierBits.invertedControls, "ff8080", "inverted_controls" },
		{ modifierBits.instaKill, "ff0000", "instakill" },
		{ modifierBits.ZBC, "ff5050", "z_button_challenge" },
		{ modifierBits.BBC, "ff5050", "b_button_challenge" },
	}

	for _, mod in ipairs(modifierList) do
		if is_modifier_active(mod[1]) then
			modifiers[#modifiers + 1] = "\\#" .. mod[2] .. "\\" .. translate(mod[3])
		end
	end

	if #modifiers > 0 then
		djui_hud_set_font(djui_menu_get_font())
		local modScale = 0.25
		local padding = 4
		local lineHeight = 10

		local title = translate("modifiers_title")

		local maxWidth = djui_hud_measure_text(remove_color(title)) * modScale

		for _, text in ipairs(modifiers) do
			local w = djui_hud_measure_text(remove_color(text)) * modScale
			if w > maxWidth then
				maxWidth = w
			end
		end

		local boxWidth = maxWidth + padding * 2
		local boxHeight = (#modifiers + 1) * lineHeight + padding - 12

		local x = screenWidth - boxWidth - 8
		local y = 8

		-- background
		djui_hud_set_color(0, 0, 0, 220)
		HU.djui_hud_render_rect_rounded(x, y, boxWidth, boxHeight, 8)

		-- outline
		djui_hud_set_color(0, 0, 0, 180)
		HU.djui_hud_render_rect_rounded_outlined(x, y, boxWidth, boxHeight, 0, 0, 0, 1, 180)

		-- text
		local textX = x + padding
		local textY = y + padding - 12

		textY = textY + lineHeight

		for _, text in ipairs(modifiers) do
			HU.djui_hud_print_colored_text(text, textX, textY, modScale)

			textY = textY + lineHeight
		end
	end
end

return M
