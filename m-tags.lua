----------------
--- TAG DATA ---
----------------

local TAG_DATA = {
	{ key = "CREATOR", name = "[CREATOR]", color = "\\#27F568\\" },
	{ key = "HOST", name = "[HOST]", color = "\\#FF8000\\" },
	{ key = "RANDOM_KID", name = "[Random Kid]", color = "\\#FF8000\\" },
	{ key = "COOL_GUY", name = "\\#ab00ff\\[Cool \\#00ff85\\guy]", color = "" },
	--2808064910043531445
}

TAG_TYPE = {}
DEF_TAGS = {}

for i, data in ipairs(TAG_DATA) do
	local id = 1 << (i - 1) -- 1, 2, 4, 8, 16...

	TAG_TYPE[data.key] = id
	DEF_TAGS[id] = {
		name = data.name,
		color = data.color,
	}
end
-----------------
--- DC TO TAG ---
-----------------

----------------------
--- COOPNET TO TAG ---
----------------------

-- add your coopNet id here
local coopnetToTag = {
	["1045699806986420677"] = TAG_TYPE.CREATOR, -- Georgegabr1
	["2808064910043531445"] = TAG_TYPE.COOL_GUY,
}

local discordToTag = {
	["980159405674856478"] = TAG_TYPE.CREATOR, -- Georgegabr1
	["780825981228548177"] = TAG_TYPE.COOL_GUY, -- Sverige
	["1417950281450131549"] = TAG_TYPE.RANDOM_KID, -- kitanstuff
}

--980159405674856478

-----------------
--- TAG LOGIC ---
-----------------

gPlayerSyncTable[0].tagId = 0
local myTagResolved = false
local myCachedTagId = 0
local initTimer = 0

function get_my_discord_id()
	local id = "0"
	if network_discord_id_from_local_index then
		id = network_discord_id_from_local_index(0)
	elseif get_local_discord_id then
		id = get_local_discord_id()
	end

	if not id or id == "" then
		return "0"
	end
	return tostring(id)
end

local function get_my_coopnet_id()
	local id = "0"
	if get_coopnet_id then
		id = get_coopnet_id(0)
	end

	if not id or id == "" then
		return "0"
	end
	return tostring(id)
end

local function resolve_my_tag()
	if myTagResolved then
		if gPlayerSyncTable[0].tagId ~= myCachedTagId then
			gPlayerSyncTable[0].tagId = myCachedTagId
		end
		return
	end

	local discordId = get_my_discord_id()
	local coopnetId = get_my_coopnet_id()

	if (discordId ~= "0" and discordId ~= "") or (coopnetId ~= "0" and coopnetId ~= "") then
		gPlayerSyncTable[0].tagId = 0

		if discordToTag[discordId] then
			gPlayerSyncTable[0].tagId = gPlayerSyncTable[0].tagId | discordToTag[discordId]
		end

		if coopnetToTag[coopnetId] then
			gPlayerSyncTable[0].tagId = gPlayerSyncTable[0].tagId | coopnetToTag[coopnetId]
		end

		myCachedTagId = gPlayerSyncTable[0].tagId
		myTagResolved = true
	else
		initTimer = initTimer + 1
		if initTimer > 90 then
			gPlayerSyncTable[0].tagId = 0
			myCachedTagId = 0
			myTagResolved = true
		end
	end
end

local function on_sync_valid()
	if myTagResolved then
		local currentTag = gPlayerSyncTable[0].tagId
		gPlayerSyncTable[0].tagId = 0
		gPlayerSyncTable[0].tagId = currentTag
	end
end

local function get_team_tag(playerIndex)
	local m = gPlayerSyncTable[playerIndex]
	if not m or not m.team or not TEAM_DATA[m.team] then
		return ""
	end

	return TEAM_DATA[m.team][3]:gsub("^(\\#[0-9a-fA-F]+\\)", "%1[") .. "] "
end

local function get_formatted_tag(playerIndex)
	local tagId = gPlayerSyncTable[playerIndex].tagId or 0
	local str = ""

	for id, def in pairs(DEF_TAGS) do
		if (tagId & id) ~= 0 then
			str = str .. def.color .. def.name .. " "
		end
	end

	return str
end

local function get_player_display_name(playerIndex)
	local np = gNetworkPlayers[playerIndex]
	local playerColor = network_get_player_text_color_string(playerIndex)
	local tagStr = get_formatted_tag(playerIndex)
	local teamStr = get_team_tag(playerIndex)

	if not np then
		return ""
	end

	local name = np.name
	if name == "Player" then
		name = "Player " .. playerIndex
	end

	return string.format("%s%s%s%s", teamStr, tagStr, playerColor, name)
end

local function main_update()
	resolve_my_tag()

	if network_is_server() then
		gPlayerSyncTable[0].tagId = gPlayerSyncTable[0].tagId | TAG_TYPE.HOST
		myCachedTagId = gPlayerSyncTable[0].tagId
	end
end

local function on_chat_message(m, msg)
	local s = gPlayerSyncTable[m.playerIndex]

	if not s then
		return
	end

	if (s.tagId or 0) == 0 and (not s.team or not TEAM_DATA[s.team]) then
		return
	end

	local displayName = get_player_display_name(m.playerIndex)
	local formattedMsg = string.format("%s\\#dcdcdc\\: %s", displayName, msg)

	djui_chat_message_create(formattedMsg)

	if m.playerIndex == 0 then
		play_sound(SOUND_MENU_MESSAGE_DISAPPEAR, gGlobalSoundSource)
	else
		play_sound(SOUND_MENU_MESSAGE_APPEAR, gGlobalSoundSource)
	end

	return false
end

------------------
--- C/D POPUPS ---
------------------

local function on_player_disconnected(m)
	gPlayerSyncTable[m.playerIndex].tagId = 0
end

--[[local function on_player_connected(m)
	djui_chat_message_create(
		string.format(
			"%s has won a game %d times!",
			network_get_player_text_color_string(m.playerIndex),
			gPlayerSyncTable[0].gameWins
		)
	)
	djui_chat_message_create(
		string.format(
			"%s has won a minigame %d times!",
			network_get_player_text_color_string(m.playerIndex),
			gPlayerSyncTable[0].minigameWins
		)
	)
end]]
-------------
--- HOOKS ---
-------------

hook_event(HOOK_UPDATE, main_update)
hook_event(HOOK_ON_CHAT_MESSAGE, on_chat_message)
hook_event(HOOK_ON_SYNC_VALID, on_sync_valid)
hook_event(HOOK_ON_PLAYER_DISCONNECTED, on_player_disconnected)
--hook_event(HOOK_ON_PLAYER_CONNECTED, on_player_connected)
