local WI = require("b-wins")
local MWI = require("c-mWins")

function on_chat_message(msg)
	WI.reset_wins()
	MWI.reset_m_wins()
	return true
end

hook_chat_command("reset_wins", "Resets your wins and minigame wins. (DONT DO THIS)", on_chat_message)

function end_round(msg)
	if not network_is_server() and not network_is_moderator() then
		djui_chat_message_create(translate("no_moderator_permission"))
		return
	end
	gGlobalSyncTable.gameState = GAME_STATE_MINI_END
	return true
end

hook_chat_command("end", "Ends the round", end_round)

function download_link()
	djui_chat_message_create(translate("download_link") .. "https://github.com/georgegabrdev/Drench-Game-DX")
	return true
end

hook_chat_command("download", "Provides a link to download the mod", download_link)

function reset_global_leaderboard_command(msg)
	if not network_is_server() and not network_is_moderator() then
		djui_chat_message_create(translate("no_moderator_permission"))
		return true
	end
	if network_is_server() then
		reset_global_leaderboard()
		djui_chat_message_create("Global leaderboard has been completely reset.")
	else
		network_send_to(1, true, { id = GLOBAL_LEADERBOARD_PACKET, reset = true })
		djui_chat_message_create("Global leaderboard reset requested.")
	end
	return true
end

hook_chat_command("resetleaderboard", "Resets the entire global leaderboard.", reset_global_leaderboard_command)
