--------------
--- TABLES ---
--------------
---

local LOADED_TRANSLATIONS = {}

local smlua_text_utils_get_language = smlua_text_utils_get_language
---------------
--- REQUIRE ---
---------------

local LANGUAGES = { "en", "es", "pt-br", "fr" }

for _, lang in ipairs(LANGUAGES) do
	LOADED_TRANSLATIONS[lang] = require(lang)
end

local LANGUAGE_CODES = {
	English = "en",
	Spanish = "es",
	Portuguese = "pt-br",
	French = "fr",
}

function murder_role_calc(IsSheriff, IsMurderer)
	local lang = smlua_text_utils_get_language()

	if IsSheriff == true then
		if lang == "Spanish" then
			return "\\#7affff\\Sheriff"
		elseif lang == "Portuguese" then
			return "\\#7affff\\Xerife"
		elseif lang == "French" then
			return "\\#7affff\\Shérif"
		else
			return "\\#7affff\\Sheriff"
		end
	elseif IsMurderer == true then
		if lang == "Spanish" then
			return "\\#ff7a7a\\Asesino"
		elseif lang == "Portuguese" then
			return "\\#ff7a7a\\Assassino"
		elseif lang == "French" then
			return "\\#ff7a7a\\Meurtrier"
		else
			return "\\#ff7a7a\\Murderer"
		end
	else
		if lang == "Spanish" then
			return "\\#7aff7a\\Inocente"
		elseif lang == "Portuguese" then
			return "\\#7aff7a\\Inocente"
		elseif lang == "French" then
			return "\\#7aff7a\\Innocent"
		else
			return "\\#7aff7a\\Innocent"
		end
	end
end

function murder_instructions_calc(IsSheriff, IsMurderer)
	if IsSheriff then
		return translate("murder_sheriff")
	elseif IsMurderer then
		return translate("murder_murderer")
	else
		return translate("murder_innocent")
	end
end

function get_hint(index)
	local code = language or "en"
	local hint_key = "hint_" .. tostring(index)

	if LOADED_TRANSLATIONS[code] and LOADED_TRANSLATIONS[code][hint_key] then
		return LOADED_TRANSLATIONS[code][hint_key]
	end

	return LOADED_TRANSLATIONS["en"][hint_key] or ""
end

function translate(id)
	local code = language or "en"

	if LOADED_TRANSLATIONS[code] and LOADED_TRANSLATIONS[code][id] then
		return LOADED_TRANSLATIONS[code][id]
	end

	return LOADED_TRANSLATIONS["en"][id] or id
end
