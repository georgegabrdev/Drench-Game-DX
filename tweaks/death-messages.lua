local ATTACK_TIMEOUT = 90

local lastAttacker = {}
local attackTimer = {}

local function on_pvp_attack(attacker, victim, interaction)
	local attackerIndex = attacker.playerIndex
	local victimIndex = victim.playerIndex

	-- Don't record self-attacks.
	if attackerIndex == victimIndex then
		return
	end

	lastAttacker[victimIndex] = attackerIndex
	attackTimer[victimIndex] = 0
end

local function update()
	for i = 0, MAX_PLAYERS - 1 do
		if attackTimer[i] ~= nil then
			attackTimer[i] = attackTimer[i] + 1

			if attackTimer[i] > ATTACK_TIMEOUT then
				attackTimer[i] = nil
				lastAttacker[i] = nil
			end
		end
	end
end

local function on_death(m)
	local victimIndex = m.playerIndex
	local killerIndex = lastAttacker[victimIndex]
	local timer = attackTimer[victimIndex]

	-- No recent PvP attack.
	if killerIndex == nil or timer == nil then
		return
	end

	-- Don't report suicide.
	if killerIndex == victimIndex then
		return
	end

	-- Make sure the killer is still connected.
	if not gNetworkPlayers[killerIndex].connected then
		return
	end

	-- Send the kill event to every player.
	network_send(true, {
		type = "death_message",
		victim = victimIndex,
		killer = killerIndex,
	})

	-- Clear the stored attack.
	lastAttacker[victimIndex] = nil
	attackTimer[victimIndex] = nil
end

local function on_packet_receive(data)
	if data.type ~= "death_message" then
		return
	end

	local victimIndex = data.victim
	local killerIndex = data.killer

	if victimIndex == nil or killerIndex == nil then
		return
	end

	if not gNetworkPlayers[victimIndex].connected then
		return
	end

	if not gNetworkPlayers[killerIndex].connected then
		return
	end

	local victimName = gNetworkPlayers[victimIndex].name
	local killerName = gNetworkPlayers[killerIndex].name

	djui_chat_message_create(
		network_get_player_text_color_string(victimIndex)
			.. victimName
			.. " has been killed by "
			.. network_get_player_text_color_string(killerIndex)
			.. killerName
	)
end

hook_event(HOOK_UPDATE, update)
hook_event(HOOK_ON_PVP_ATTACK, on_pvp_attack)
hook_event(HOOK_ON_DEATH, on_death)
hook_event(HOOK_ON_PACKET_RECEIVE, on_packet_receive)
