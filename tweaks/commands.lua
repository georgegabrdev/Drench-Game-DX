local WI = require("b-wins")
local MWI = require("c-mWins")

function on_chat_message(msg)
	WI.reset_wins()
	MWI.reset_m_wins()
end

hook_chat_command("reset_wins", "Resets your wins and minigame wins. (DONT DO THIS)", on_chat_message)

function on_chat_message_again(msg)
	local num = tonumber(msg)
	local m = gMarioStates[0]

	if not num then
		djui_chat_message_create("\\#ff5050\\Invalid amount!")
	end
	if not network_is_server() and not network_is_moderator() then
		djui_chat_message_create(
			"\\#ff5050\\You have permission to perform this command... or DO you?\n(No, you don't have moderator)"
		)
		return
	end
	for i = 1, num do
		create_warning_popup("!!! NUCLEAR LAUNCH DETECTED !!!")
		spawn_sync_object(id_bhvNuclearBomb, E_MODEL_NONE, m.pos.x, m.pos.y, m.pos.z, nil)
	end
end

hook_chat_command("nuclearbomb", "No.", on_chat_message_again)

function end_round()
	if not network_is_server() and not network_is_moderator() then
		djui_chat_message_create(
			"\\#ff5050\\You have permission to perform this command... or DO you?\n(No, you don't have moderator)"
		)
		return
	end
	gGlobalSyncTable.gameState = GAME_STATE_MINI_END
end

hook_chat_command("end", "Ends the round", end_round)

function download_link()
	djui_chat_message_create("\\#00ffff\\Download link: \\#ffffff\\https://github.com/georgegabrdev/Drench-Game-DX")
end

hook_chat_command("download", "Provides a link to download the mod", download_link)
