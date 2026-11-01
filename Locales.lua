local ADDON, ns = ...

-- L is filled by ns.ApplyLocale: enUS first, then the chosen locale on top.
-- A missing key reads as itself, so plain English sentences need no enUS
-- entry; only symbolic keys do.
local L = setmetatable({}, { __index = function(t, k) return k end })
ns.L = L
ns.locales = { enUS = {}, zhTW = {} }

ns.LANGUAGES = {
	{ code = nil,    key = "LANG_auto" },
	{ code = "enUS", label = "English" },
	{ code = "zhTW", label = "繁體中文" },
}

-- Fill L for `code`.
function ns.ApplyLocale(code)
	for k in pairs(L) do L[k] = nil end
	for k, v in pairs(ns.locales.enUS) do L[k] = v end
	local ov = ns.locales[code]
	if ov and ov ~= ns.locales.enUS then
		for k, v in pairs(ov) do L[k] = v end
	end
	ns.activeLocale = (ov and code) or "enUS"
end

-- Text that is set once (labels, buttons, check boxes) is bound to its key so
-- a language switch can set it again. Everything else is refreshed anyway.
local bound = {}

local function SetBoundText(widget, key)
	if widget.SetLabel then widget:SetLabel(L[key]) else widget:SetText(L[key]) end
end

function ns.Bind(widget, key)
	bound[#bound + 1] = { widget, key }
	SetBoundText(widget, key)
	return widget
end

-- code: "enUS" | "zhTW" | nil (follow the game)
function ns.SetLanguage(code)
	ns.db.settings.locale = code
	ns.ApplyLocale(code or GetLocale())
	for _, b in ipairs(bound) do SetBoundText(b[1], b[2]) end
	ns.Changed()
end

ns.locales.enUS = {
	["LANG_auto"]   = "Auto (game language)",
	["Slash hint"]  = "/ocfish opens the settings.",
	["HUD_HINT"]    = "Right click: settings. Drag to move, mouse wheel to page the catches, Ctrl + mouse wheel to resize.",
	["KEY_HINT"]    = "Press it at the water to cast. When the bobber splashes, press it again to loot.",
	["KEY_TIP"]     = "One key for the whole cast. While the bobber is out of reach it casts again instead. No casting in combat.",

	-- the window: a line under each page title
	["MODE_DESC"]    = "One switch for all of it: the key, the cast button, the settings switched for a cast and the session count. The minimap button switches it too.",
	["CASTING_DESC"] = "What is done for you around a cast.",
	["SOUND_DESC"]   = "Nothing tells you of a bite but the splash. These apply while the line is out and are put back when it is in.",
	["GEAR_DESC"]    = "The lures and fishing hats in your bags; the X is none. With no lure on the pole the cast button turns amber; applied for you, a press puts the lure on and the next one casts, and a lure already on is never replaced. The hat goes on before a cast and comes off when fishing mode is switched off.",
	["BUTTON_DESC"]  = "The pole from your fishing tool slot, on screen. Left click casts, or loots when the bobber is ready; Shift + left click switches fishing mode off; right click opens the settings.",
	["HUD_DESC"]     = "Casts, catches, their value and gold per hour, from the first cast on. Thirty minutes without a cast starts a new session.",
	["LOOK_DESC"]    = "Language, colors and size of this window. The colors apply to the HUD too.",
	["PRICES_DESC"]  = "A catch is valued at its market price when an auction addon has one, else at what a vendor pays. Auctionator and TradeSkillMaster are read when installed; nothing to set up.",
	-- what a toggle does when it is off
	["MODE_OFF"]      = "Off: the key does nothing and nothing is counted.",
	["EQUIP_OFF"]     = "Off: you equip the pole yourself.",
	["LOOT_OFF"]      = "Off: the loot window opens.",
	["CHIME_OFF"]     = "Off: no chime.",
	["DUCK_OFF"]      = "Off: music and ambience stay as they are.",
	["SFX_OFF"]       = "Off: sound effects stay as they are.",
	["BG_OFF"]        = "Off: no sound while the game is in the background.",
	["LURE_AUTO_OFF"] = "Off: you put the lure on yourself.",
	["BUTTON_OFF"]    = "Off: no button on screen; the key still casts.",
	["MINIMAP_OFF"]   = "Off: no minimap button; /ocfish opens the settings.",
	["HUD_OFF"]       = "Off: the HUD is hidden; the session is still counted.",
	["CATCHES_OFF"]   = "Off: only the numbers.",
	["LOCK_OFF"]      = "Off: drag them to move them.",
	["IDLE_TIP"]      = "Minutes without a cast before the HUD goes (1 to 30). It comes back with the next cast.",
	["THEME_tide"]     = "Tide (blue)",
	["THEME_obsidian"] = "Obsidian (black-gold)",

	["MODE_on"]     = "Fishing mode on",
	["MODE_off"]    = "Fishing mode off",
	["BUTTON_WHAT"] = "The cast button. The pole it wears is the one in your fishing tool slot.",
	["BUTTON_LEFT"] = "Left click: cast. Bobber ready: loot.",
	["BUTTON_RIGHT"] = "Right click: settings.",
	["BUTTON_SHIFT"] = "Shift + left click: fishing mode off.",
	["BUTTON_DRAG"] = "Drag to move.",
	["MINIMAP_HINT"] = "Left click: fishing mode on or off. Right click: settings.",
	["ROW_casts"]       = "Casts",
	["ROW_catches"]     = "Catches",
	["ROW_perHour"]     = "Catch/hr",
	["ROW_value"]       = "Est. value (%s)",
	["ROW_gold"]        = "Gold/hr",
	["ROW_time"]        = "Time",
	["ROW_lure"]        = "Lure",
	["LURE_none"]       = "none",
	["RIVAL_LOADED"]    = "%s is on as well. It switches the same interact and sound settings for the cast, and the two put back each other's values, so the settings can stay on after fishing. Turn one of them off.",
	["SRC_vendor"]      = "vendor",
	["STATE_installed"] = "installed",
	["STATE_missing"]   = "not installed",
}

ns.locales.zhTW = {
	["LANG_auto"]   = "自動（跟隨遊戲語言）",
	["Slash hint"]  = "輸入 /ocfish 開啟設定。",
	["HUD_HINT"]    = "右鍵：設定。拖曳移動，滾輪翻頁漁獲，Ctrl + 滾輪縮放。",
	["KEY_HINT"]    = "在水邊按一下拋竿，浮標濺起水花時再按一下收竿。",
	["KEY_TIP"]     = "一個鍵包辦拋竿和收竿。浮標太遠時改成重新拋竿。戰鬥中不能拋竿。",
	["MODE_on"]     = "釣魚模式開啟",
	["MODE_off"]    = "釣魚模式關閉",
	["BUTTON_WHAT"] = "拋竿按鈕。顯示的是你釣魚工具欄位裡的魚竿。",
	["BUTTON_LEFT"] = "左鍵：拋竿。浮標就緒時：收竿。",
	["BUTTON_RIGHT"] = "右鍵：設定。",
	["BUTTON_SHIFT"] = "Shift + 左鍵：關閉釣魚模式。",
	["BUTTON_DRAG"] = "拖曳移動。",
	["MINIMAP_HINT"] = "左鍵：開關釣魚模式。右鍵：設定。",
	-- the HUD's terms stay English in zhTW (shorter, and clearer than 拋竿 / 漁獲 / 收益); the lure is Chinese
	["ROW_casts"]       = "Casts",
	["ROW_catches"]     = "Catches",
	["ROW_perHour"]     = "Catch/hr",
	["ROW_value"]       = "Est. value (%s)",
	["ROW_gold"]        = "Gold/hr",
	["ROW_time"]        = "Time",
	["ROW_lure"]        = "魚餌",
	["LURE_none"]       = "沒有",
	["RIVAL_LOADED"]    = "%s 也在執行。它會在拋竿時切換同一組互動與聲音設定，兩個插件會互相還原成對方的值，釣完後設定可能一直開著。請停用其中一個。",
	["None"]            = "無",
	["SRC_vendor"]      = "商店",
	["Session"]         = "Session",
	["Reset"]           = "重算",
	["STATE_installed"] = "已安裝",
	["STATE_missing"]   = "未安裝",

	["Cast & loot"]          = "拋竿與收竿",
	["Open settings"]        = "開啟設定",
	["No fishing pole equipped."] = "沒有裝備魚竿。",

	-- the window
	["Fishing"]              = "釣魚",
	["HUD"]                  = "HUD",
	["General"]              = "一般",
	["Fishing mode"]         = "釣魚模式",
	["Casting"]              = "拋竿",
	["Sound"]                = "聲音",
	["Lure and hat"]         = "魚餌與帽子",
	["Cast button"]          = "拋竿按鈕",
	["Session HUD"]          = "Session HUD",
	["Appearance"]           = "外觀",
	["Prices"]               = "價格",
	["MODE_DESC"]    = "一個開關管全部：按鍵、拋竿按鈕、拋竿時切換的設定和統計。小地圖按鈕也能切換。",
	["CASTING_DESC"] = "拋竿前後自動幫你做的事。",
	["SOUND_DESC"]   = "魚上鉤只能聽水花聲。以下設定只在拋竿期間生效，收竿後還原。",
	["GEAR_DESC"]    = "列出背包裡的魚餌和釣魚帽，X 是不用。魚竿沒上餌時拋竿按鈕變琥珀色；自動上餌是按一下先上餌、再按一下拋竿，已經有魚餌就不換。帽子在拋竿前戴上，關閉釣魚模式時換回。",
	["BUTTON_DESC"]  = "畫面上的魚竿按鈕。左鍵拋竿，浮標就緒時收竿；Shift + 左鍵關閉釣魚模式；右鍵開設定。",
	["HUD_DESC"]     = "從第一次拋竿開始統計拋竿數、漁獲、價值和每小時收益。三十分鐘沒拋竿就重新計算。",
	["LOOK_DESC"]    = "設定語言、配色和視窗大小。配色也套用到 HUD。",
	["PRICES_DESC"]  = "漁獲價值用拍賣插件的市價，沒有就用商店收購價。有裝 Auctionator 或 TradeSkillMaster 會自動讀取，不用設定。",

	-- fishing mode page
	["MODE_OFF"]             = "關：按鍵沒作用，也不統計",
	["Key"]                  = "按鍵",
	["Not bound"]            = "未綁定",
	["Press a key..."]       = "按下要用的鍵…",
	["Clear"]                = "清除",

	-- casting page
	["Equip a fishing pole from your bags"] = "自動裝上魚竿",
	["EQUIP_OFF"]                           = "關：魚竿要自己裝",
	["Loot the catch at once"]              = "立即拾取",
	["LOOT_OFF"]                            = "關：會跳出拾取視窗",
	["Chime when the line lands"]           = "魚線落水提示音",
	["CHIME_OFF"]                           = "關：不播提示音",

	-- sound page
	["Lower music and ambience"]     = "壓低音樂與環境音",
	["DUCK_OFF"]                     = "關：音樂與環境音不變",
	["Music"]                        = "音樂",
	["Ambience"]                     = "環境音",
	["Louder sound effects"]         = "音效開到最大",
	["SFX_OFF"]                      = "關：音效音量不變",
	["Keep sound in the background"] = "背景也有聲音",
	["BG_OFF"]                       = "關：切到其他視窗就沒聲音",

	-- lure and hat page
	["Lure"]                 = "魚餌",
	["Apply before casting"] = "拋竿前自動上餌",
	["LURE_AUTO_OFF"]        = "關：魚餌要自己上",
	["Fishing hat"]          = "釣魚帽",

	-- cast button page
	["Show the cast button"]    = "顯示拋竿按鈕",
	["BUTTON_OFF"]              = "關：隱藏按鈕，按鍵照樣能拋竿",
	["Button size"]             = "按鈕大小",
	["Show the minimap button"] = "顯示小地圖按鈕",
	["MINIMAP_OFF"]             = "關：隱藏小地圖按鈕，用 /ocfish 開設定",

	-- session HUD page
	["Show the HUD"]            = "顯示 HUD",
	["HUD_OFF"]                 = "關：隱藏 HUD，照樣統計",
	["Show catches on the HUD"] = "HUD 列出漁獲",
	["CATCHES_OFF"]             = "關：只顯示數字",
	["Hide after"]              = "閒置後隱藏",
	["minutes"]                 = "分鐘",
	["IDLE_TIP"]                = "幾分鐘沒拋竿就收起 HUD（1 到 30），下次拋竿再出現。",
	["HUD size"]                = "HUD 大小",
	["Lock the HUD and the cast button"] = "鎖定 HUD 和拋竿按鈕",
	["LOCK_OFF"]                = "關：可以拖曳移動",
	["Reset positions"]         = "重設位置",
	["Reset session"]           = "重新計算",

	-- appearance page
	["Language"]             = "語言",
	["Theme"]                = "主題",
	["THEME_tide"]           = "潮汐（藍）",
	["THEME_obsidian"]       = "曜墨金（黑金）",
	["Off"]                  = "關",
	["On"]                   = "開",
	["Window scale"]         = "視窗大小",

	-- chat
	["No key bound. Bind one under Key Bindings > AddOns > OneClickFish, or in /ocfish."] = "尚未綁定按鍵。請到 按鍵設定 > 插件 > OneClickFish 綁定，或在 /ocfish 設定。",
	["%s was taken from %s."]       = "%s 原本綁在 %s，已改綁到這裡。",
	["Interact and sound settings restored."] = "互動與聲音設定已還原。",
	["Session reset."]              = "已重新計算。",
	["Not in combat."]              = "戰鬥中無法變更。",
}

ns.ApplyLocale(GetLocale())

-- The Key Bindings screen reads these globals.
BINDING_HEADER_ONECLICKFISH = "OneClickFish"
BINDING_NAME_ONECLICKFISH_CAST = L["Cast & loot"]
