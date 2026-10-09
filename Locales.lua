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
	["HUD_HINT"]    = "Right click: settings. Drag to move, Ctrl + mouse wheel to resize.",
	["KEY_HINT"]    = "Press it at the water to cast. When the bobber splashes, press it again: it loots.",
	["KEY_TIP"]     = "One key for the whole cast. While the bobber is out of reach the key casts again instead; a cast cannot be made in combat.",
	["EQUIP_TIP"]   = "Out of combat, a fishing pole from your bags is equipped before the cast.",
	["LOOT_TIP"]    = "No loot window: the catch goes straight to your bags.",
	["CHIME_TIP"]   = "A short ping when the line lands.",
	["DUCK_TIP"]    = "There is no event for a bite: the splash is the cue. Music and ambience are lowered while the line is out and put back when it is in.",
	["SFX_TIP"]     = "Sound effects at full volume while the line is out, so the splash stands out.",
	["HUD_TIP"]     = "Casts, catches, their value and gold per hour, from the first cast on. Thirty minutes without a cast starts a new session.",
	["CATCHES_TIP"] = "What was caught this session under the numbers, the most caught first.",
	["IDLE_TIP"]    = "The HUD goes after this long without a cast, and comes back with the next one.",
	["LOCK_TIP"]    = "The HUD and the cast button stay where they are.",
	["MODE_TIP"]    = "Everything at once: the key, the cast button, the settings switched for a cast, the session. Off, the key does nothing and nothing is counted. The minimap button switches it too.",
	["MODE_on"]     = "Fishing mode on",
	["MODE_off"]    = "Fishing mode off",
	["BUTTON_TIP"]  = "The pole in your fishing tool slot, on screen. Left click casts, or loots when the bobber is ready; right click opens the settings.",
	["BUTTON_WHAT"] = "The cast button. The pole it wears is the one in your fishing tool slot.",
	["BUTTON_LEFT"] = "Left click: cast. Bobber ready: loot.",
	["BUTTON_RIGHT"] = "Right click: settings.",
	["BUTTON_DRAG"] = "Drag to move.",
	["MINIMAP_HINT"] = "Left click: fishing mode on or off. Right click: settings.",
	["ROW_fishing"]     = "Casts / catches / hr",
	["ROW_value"]       = "Est. value (%s)",
	["ROW_rate"]        = "Gold/hr · time",
	["ROW_lure"]        = "Lure",
	["LURE_none"]       = "none",
	["LURE_TIP"]        = "A consumable used on the pole, good for some minutes. What is left shows on the HUD, and the cast button turns amber when the pole wants one. The lures your bags hold, newest first; the X is none.",
	["LURE_AUTO_TIP"]   = "With the lure gone, a press puts a new one on the pole; the next press casts.",
	["HAT_TIP"]         = "A fishing hat from your bags, or the one on your head, put on before a cast. What was on your head before is put back when fishing mode is switched off. The X is none.",
	["SRC_vendor"]      = "vendor",
	["STATE_installed"] = "installed",
	["STATE_missing"]   = "not installed",
	["PRICES_NOTE"]     = "The value of a catch is a market price when an auction addon has one, else what a vendor pays. Auctionator or TradeSkillMaster, when installed, are read as they are; nothing to set up.",
}

ns.locales.zhTW = {
	["LANG_auto"]   = "自動（跟隨遊戲語言）",
	["Slash hint"]  = "輸入 /ocfish 開啟設定。",
	["HUD_HINT"]    = "右鍵：設定。拖曳移動，Ctrl + 滾輪縮放。",
	["KEY_HINT"]    = "在水邊按下拋竿。浮標濺起水花時再按一次，就收竿拾取。",
	["KEY_TIP"]     = "一個按鍵包辦整次拋竿。浮標不在互動範圍內時，按鍵會改為重新拋竿；戰鬥中無法拋竿。",
	["EQUIP_TIP"]   = "非戰鬥時，拋竿前會先從背包裝上魚竿。",
	["LOOT_TIP"]    = "不開拾取視窗：漁獲直接進背包。",
	["CHIME_TIP"]   = "魚線落水時播一聲短促提示音。",
	["DUCK_TIP"]    = "遊戲沒有「魚上鉤」事件，只能聽水花聲。拋竿期間壓低音樂與環境音，收竿後還原。",
	["SFX_TIP"]     = "拋竿期間音效開到最大，讓水花聲更明顯。",
	["HUD_TIP"]     = "從第一次拋竿起算的拋竿數、漁獲、價值與每小時收益。超過三十分鐘沒拋竿就重新計算。",
	["CATCHES_TIP"] = "數字下方列出這次釣到的東西，釣最多的排最前面。",
	["IDLE_TIP"]    = "這麼久沒拋竿 HUD 就收起來，下一次拋竿再出現。",
	["LOCK_TIP"]    = "HUD 與拋竿按鈕固定不動。",
	["MODE_TIP"]    = "一次開關全部：按鍵、拋竿按鈕、拋竿時切換的設定、統計。關閉時按鍵沒有作用，也不計數。小地圖按鈕也可以切換。",
	["MODE_on"]     = "釣魚模式開啟",
	["MODE_off"]    = "釣魚模式關閉",
	["BUTTON_TIP"]  = "把釣魚工具欄位的魚竿放在畫面上。左鍵拋竿，浮標就緒時左鍵收竿；右鍵開啟設定。",
	["BUTTON_WHAT"] = "拋竿按鈕。顯示的是你釣魚工具欄位裡的魚竿。",
	["BUTTON_LEFT"] = "左鍵：拋竿。浮標就緒時：收竿。",
	["BUTTON_RIGHT"] = "右鍵：設定。",
	["BUTTON_DRAG"] = "拖曳移動。",
	["MINIMAP_HINT"] = "左鍵：開關釣魚模式。右鍵：設定。",
	["ROW_fishing"]     = "拋竿 / 漁獲 / hr",
	["ROW_value"]       = "收益估計 (%s)",
	["ROW_rate"]        = "收益/hr · 時間",
	["ROW_lure"]        = "魚餌",
	["LURE_none"]       = "沒有",
	["LURE_TIP"]        = "用在魚竿上、持續幾分鐘的消耗品。剩餘時間顯示在 HUD，魚竿需要魚餌時拋竿按鈕會變琥珀色。列出背包裡的魚餌，新的在前；X 是不用。",
	["LURE_AUTO_TIP"]   = "魚餌用完時，按一下先把新的上到魚竿，再按一下才拋竿。",
	["HAT_TIP"]         = "拋竿前戴上的釣魚帽，從背包或頭上找。關閉釣魚模式時換回原本戴的。X 是不用。",
	["Lure"]            = "魚餌",
	["Apply before casting"] = "拋竿前自動上餌",
	["Hat"]             = "帽子",
	["Fishing hat"]     = "釣魚帽",
	["None"]            = "無",
	["SRC_vendor"]      = "商店",
	["Session"]         = "Session",
	["Reset"]           = "重算",
	["STATE_installed"] = "已安裝",
	["STATE_missing"]   = "未安裝",
	["PRICES_NOTE"]     = "漁獲的價值以市場價格估計，沒有拍賣插件時用商店收購價。裝了 Auctionator 或 TradeSkillMaster 就直接讀取，不用設定。",

	["Cast & loot"]          = "拋竿與收竿",
	["Open settings"]        = "開啟設定",
	["Key"]                  = "按鍵",
	["Not bound"]            = "尚未綁定",
	["Press a key..."]       = "請按一個鍵…",
	["Clear"]                = "清除",
	["Casting"]              = "拋竿",
	["Equip a fishing pole from your bags"] = "從背包裝上魚竿",
	["Loot the catch at once"]              = "立即拾取漁獲",
	["Chime when the line lands"]           = "魚線落水時提示音",
	["Sound while the line is out"]         = "拋竿期間的聲音",
	["Lower music and ambience"]            = "壓低音樂與環境音",
	["Music"]                = "音樂",
	["Ambience"]             = "環境音",
	["Louder sound effects"] = "音效開到最大",
	["Fishing mode"]         = "釣魚模式",
	["Fishing"]              = "釣魚",
	["On screen"]            = "畫面",
	["Session HUD"]          = "Session HUD",
	["Prices"]               = "價格",
	["Show the cast button"] = "顯示拋竿按鈕",
	["Show the minimap button"] = "顯示小地圖按鈕",
	["Show the HUD"]         = "顯示 HUD",
	["Show catches on the HUD"] = "HUD 列出漁獲",
	["Hide after"]           = "閒置後隱藏",
	["%d min"]               = "%d 分鐘",
	["Scale"]                = "縮放",
	["Position"]             = "位置",
	["Lock"]                 = "鎖定",
	["Reset positions"]      = "重設位置",
	["No fishing pole equipped."] = "沒有裝備魚竿。",
	["Reset session"]        = "重新計算",
	["General"]              = "一般",
	["Language"]             = "語言",
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
