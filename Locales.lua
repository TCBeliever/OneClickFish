local ADDON, ns = ...

-- L is filled by ns.ApplyLocale: enUS first, then the chosen locale on top.
-- A missing key reads as itself, so plain English sentences need no enUS
-- entry; only symbolic keys do.
local L = setmetatable({}, { __index = function(t, k) return k end })
ns.L = L
ns.locales = { enUS = {}, zhTW = {}, zhCN = {} }

ns.LANGUAGES = {
	{ code = nil,    key = "LANG_auto" },
	{ code = "enUS", label = "English" },
	{ code = "zhTW", label = "繁體中文" },
	{ code = "zhCN", label = "简体中文" },
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

-- code: "enUS" | "zhTW" | "zhCN" | nil (follow the game)
function ns.SetLanguage(code)
	ns.db.settings.locale = code
	ns.ApplyLocale(code or GetLocale())
	for _, b in ipairs(bound) do SetBoundText(b[1], b[2]) end
	ns.Changed()
end

-- How the copy is written (the addon-ui-copy skill): a label names the action;
-- a tooltip only says what the player needs and cannot see; a page has a line
-- under its title only for a rule of the whole page; a tooltip on something
-- clicked has one "action: result" per line.

ns.locales.enUS = {
	["LANG_auto"]   = "Auto (game language)",
	["Slash hint"]  = "/ocfish opens the settings.",
	["KEY_HINT"]    = "Press to cast. When the bobber splashes, press again to loot.",
	["KEY_TIP"]     = "With the bobber out of reach, a press casts again. No casting in combat.",

	-- the window: a line under a page title, for the pages that have one
	["SOUND_DESC"]   = "Applied while the line is out, put back when it is in.",
	["GEAR_DESC"]    = "Pick the lure and the fishing hat to use.",
	["PRICES_DESC"]  = "With either addon below installed, catches are valued at market price. Otherwise, at what a vendor pays.",
	-- tooltips in the window
	["MODE_TIP"]      = "When off, the key, the cast button and the count all stop. The minimap button's left click switches it too.",
	["EQUIP_TIP"]     = "With no pole equipped, one from your bags goes on when you cast.",
	["LOOT_TIP"]      = "The catch goes straight into your bags. Fishing only.",
	["CHIME_TIP"]     = "A ping when the bobber lands.",
	["BG_TIP"]        = "Hear the splash while another window is in front.",
	["LURE_AUTO_TIP"] = "With no lure on the pole, the first press puts it on and the second casts. A lure already on is never replaced.",
	["HAT_TIP"]       = "Put on before a cast. Your own head piece comes back when fishing mode is switched off.",
	["BUTTON_TIP"]    = "Hidden, the key still casts.",
	["MINIMAP_TIP"]   = "Hidden, /ocfish opens the settings.",
	["HUD_TIP"]       = "Hidden, the session is still counted.",
	["IDLE_TIP"]      = "It comes back with the next cast.",
	["LOCK_TIP"]      = "Neither the HUD nor the cast button can be dragged.",
	["RESET_TIP"]     = "After 30 minutes without a cast, the next one resets it too.",
	["THEME_tide"]     = "Tide (blue)",
	["THEME_obsidian"] = "Obsidian (black-gold)",

	-- the cast button, the minimap button and the HUD, on hover
	["MODE_on"]        = "Fishing mode on",
	["MODE_off"]       = "Fishing mode off",
	["BUTTON_READY"]   = "Ready to loot",
	["BUTTON_NO_LURE"] = "No lure on the pole",
	["BUTTON_LEFT"]    = "Left click: cast, loot after the splash",
	["BUTTON_SHIFT"]   = "Shift + left click: fishing mode off",
	["MINIMAP_LEFT"]   = "Left click: fishing mode on or off",
	["HUD_WHEEL"]      = "Mouse wheel: page",
	["HUD_CTRL_WHEEL"] = "Ctrl + mouse wheel: resize",
	["TIP_RIGHT"]      = "Right click: settings",
	["TIP_DRAG"]       = "Drag: move",

	-- the HUD
	["ROW_casts"]       = "Casts",
	["ROW_catches"]     = "Catches",
	["ROW_perHour"]     = "Catch/hr",
	["ROW_value"]       = "Est. value (%s)",
	["ROW_gold"]        = "Gold/hr",
	["ROW_time"]        = "Time",
	["ROW_lure"]        = "Lure",
	["LURE_none"]       = "none",
	["SRC_vendor"]      = "vendor",
	["STATE_installed"] = "installed",
	["STATE_missing"]   = "not installed",

	-- chat
	["NO_KEY"]       = "No key set. Type /ocfish to set one.",
	["KEY_TAKEN"]    = "%s was bound to %s and now casts and loots.",
	["RESTORED"]     = "The game settings changed for fishing are restored.",
	["RIVAL_LOADED"] = "%s also changes fishing settings. With both on, they may not be put back after fishing. Turn one of them off.",
}

ns.locales.zhTW = {
	["LANG_auto"]   = "自動（跟隨遊戲語言）",
	["Slash hint"]  = "輸入 /ocfish 開啟設定。",
	["KEY_HINT"]    = "按一下拋竿，水花濺起再按一下收竿。",
	["KEY_TIP"]     = "浮標太遠撈不到時，按下去會重新拋竿。戰鬥中無效。",

	-- the cast button, the minimap button and the HUD, on hover
	["MODE_on"]        = "釣魚模式開啟",
	["MODE_off"]       = "釣魚模式關閉",
	["BUTTON_READY"]   = "可以收竿",
	["BUTTON_NO_LURE"] = "魚竿沒上餌",
	["BUTTON_LEFT"]    = "左鍵：拋竿，水花後收竿",
	["BUTTON_SHIFT"]   = "Shift + 左鍵：關閉釣魚模式",
	["MINIMAP_LEFT"]   = "左鍵：開關釣魚模式",
	["HUD_WHEEL"]      = "滾輪：翻頁",
	["HUD_CTRL_WHEEL"] = "Ctrl + 滾輪：縮放",
	["TIP_RIGHT"]      = "右鍵：設定",
	["TIP_DRAG"]       = "拖曳：移動",

	-- the HUD's terms stay English in zhTW (shorter, and clearer than 拋竿 / 漁獲 / 收益); the lure is Chinese
	["ROW_casts"]       = "Casts",
	["ROW_catches"]     = "Catches",
	["ROW_perHour"]     = "Catch/hr",
	["ROW_value"]       = "Est. value (%s)",
	["ROW_gold"]        = "Gold/hr",
	["ROW_time"]        = "Time",
	["ROW_lure"]        = "魚餌",
	["LURE_none"]       = "沒有",
	["None"]            = "無",
	["SRC_vendor"]      = "商店",
	["Session"]         = "Session",
	["Reset"]           = "歸零",
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
	["SOUND_DESC"]   = "只在拋竿時生效，收竿就還原。",
	["GEAR_DESC"]    = "點選要用的魚餌和釣魚帽。",
	["PRICES_DESC"]  = "裝了下面任一個就用拍賣市價，否則用商店收購價。",

	-- fishing mode page
	["MODE_TIP"]             = "關掉後按鍵、拋竿按鈕和統計都停用。小地圖按鈕左鍵也能開關。",
	["Key"]                  = "按鍵",
	["Not bound"]            = "未綁定",
	["Press a key..."]       = "按下要用的鍵…",
	["Clear"]                = "清除",

	-- casting page
	["Equip a fishing pole from your bags"] = "自動裝上魚竿",
	["EQUIP_TIP"]                           = "拋竿時手上沒有魚竿，就從背包裝上。",
	["Auto loot"]                           = "自動拾取",
	["LOOT_TIP"]                            = "釣到的東西直接進背包，只管釣魚。",
	["Chime on cast"]                       = "拋竿提示音",
	["CHIME_TIP"]                           = "浮標落水時響一聲。",

	-- sound page
	["Lower music and ambience"]     = "壓低音樂與環境音",
	["Music"]                        = "音樂",
	["Ambience"]                     = "環境音",
	["Louder sound effects"]         = "音效開到最大",
	["Keep sound in the background"] = "切到背景仍有聲音",
	["BG_TIP"]                       = "切到其他視窗時照樣聽得到水花聲。",

	-- lure and hat page
	["Lure"]                 = "魚餌",
	["Apply before casting"] = "拋竿前自動上餌",
	["LURE_AUTO_TIP"]        = "魚竿沒餌時，第一下上餌，第二下才拋竿。已經有餌就不換。",
	["Fishing hat"]          = "釣魚帽",
	["HAT_TIP"]              = "拋竿前戴上，關掉釣魚模式時換回原本的頭部裝備。",

	-- cast button page
	["Show the cast button"]    = "顯示拋竿按鈕",
	["BUTTON_TIP"]              = "隱藏後按鍵照樣能拋竿。",
	["Button size"]             = "按鈕大小",
	["Show the minimap button"] = "顯示小地圖按鈕",
	["MINIMAP_TIP"]             = "隱藏後用 /ocfish 開設定。",

	-- session HUD page
	["Show the HUD"]            = "顯示 HUD",
	["HUD_TIP"]                 = "隱藏後照樣統計。",
	["List catches"]            = "列出漁獲",
	["Hide after"]              = "閒置後收起",
	["minutes"]                 = "分鐘",
	["IDLE_TIP"]                = "下次拋竿再出現。",
	["Size"]                    = "大小",
	["Background"]              = "背景",
	["Show border"]             = "顯示外框",
	["Lock positions"]          = "鎖定位置",
	["LOCK_TIP"]                = "HUD 和拋竿按鈕都不能拖動。",
	["Reset positions"]         = "重設位置",
	["Reset session"]           = "統計歸零",
	["RESET_TIP"]               = "30 分鐘沒拋竿，下一竿也會自動歸零。",

	-- appearance page
	["Language"]             = "語言",
	["Theme"]                = "主題",
	["THEME_tide"]           = "潮汐（藍）",
	["THEME_obsidian"]       = "曜墨金（黑金）",
	["Off"]                  = "關",
	["On"]                   = "開",
	["Window scale"]         = "視窗大小",

	-- chat
	["NO_KEY"]          = "還沒設定按鍵，輸入 /ocfish 設定。",
	["KEY_TAKEN"]       = "%s 原本是「%s」，已改成拋竿與收竿。",
	["RESTORED"]        = "釣魚時改過的遊戲設定已還原。",
	["RIVAL_LOADED"]    = "%s 也在管釣魚設定，兩個一起開，釣完設定可能還原不回來。請停用其中一個。",
	["Session reset."]  = "統計已歸零。",
	["Not in combat."]  = "戰鬥中無法變更。",
}

-- zhCN: the zhTW table in simplified characters, with the mainland client's
-- words where they differ (设置, 窗口, 商人, 边框, 常规, 禁用, 拖动).
ns.locales.zhCN = {
	["LANG_auto"]   = "自动（跟随游戏语言）",
	["Slash hint"]  = "输入 /ocfish 打开设置。",
	["KEY_HINT"]    = "按一下抛竿，水花溅起再按一下收竿。",
	["KEY_TIP"]     = "浮标太远够不到时，按下去会重新抛竿。战斗中无效。",

	-- the cast button, the minimap button and the HUD, on hover
	["MODE_on"]        = "钓鱼模式开启",
	["MODE_off"]       = "钓鱼模式关闭",
	["BUTTON_READY"]   = "可以收竿",
	["BUTTON_NO_LURE"] = "鱼竿没上饵",
	["BUTTON_LEFT"]    = "左键：抛竿，水花后收竿",
	["BUTTON_SHIFT"]   = "Shift + 左键：关闭钓鱼模式",
	["MINIMAP_LEFT"]   = "左键：开关钓鱼模式",
	["HUD_WHEEL"]      = "滚轮：翻页",
	["HUD_CTRL_WHEEL"] = "Ctrl + 滚轮：缩放",
	["TIP_RIGHT"]      = "右键：设置",
	["TIP_DRAG"]       = "拖动：移动",

	-- the HUD's terms stay English, as in zhTW; the lure is Chinese
	["ROW_casts"]       = "Casts",
	["ROW_catches"]     = "Catches",
	["ROW_perHour"]     = "Catch/hr",
	["ROW_value"]       = "Est. value (%s)",
	["ROW_gold"]        = "Gold/hr",
	["ROW_time"]        = "Time",
	["ROW_lure"]        = "鱼饵",
	["LURE_none"]       = "没有",
	["None"]            = "无",
	["SRC_vendor"]      = "商人",
	["Session"]         = "Session",
	["Reset"]           = "归零",
	["STATE_installed"] = "已安装",
	["STATE_missing"]   = "未安装",

	["Cast & loot"]          = "抛竿与收竿",
	["Open settings"]        = "打开设置",
	["No fishing pole equipped."] = "没有装备鱼竿。",

	-- the window
	["Fishing"]              = "钓鱼",
	["HUD"]                  = "HUD",
	["General"]              = "常规",
	["Fishing mode"]         = "钓鱼模式",
	["Casting"]              = "抛竿",
	["Sound"]                = "声音",
	["Lure and hat"]         = "鱼饵与帽子",
	["Cast button"]          = "抛竿按钮",
	["Session HUD"]          = "Session HUD",
	["Appearance"]           = "外观",
	["Prices"]               = "价格",
	["SOUND_DESC"]   = "只在抛竿时生效，收竿就还原。",
	["GEAR_DESC"]    = "点选要用的鱼饵和钓鱼帽。",
	["PRICES_DESC"]  = "装了下面任一个就用拍卖行市价，否则用商人收购价。",

	-- fishing mode page
	["MODE_TIP"]             = "关掉后按键、抛竿按钮和统计都停用。小地图按钮左键也能开关。",
	["Key"]                  = "按键",
	["Not bound"]            = "未绑定",
	["Press a key..."]       = "按下要用的键…",
	["Clear"]                = "清除",

	-- casting page
	["Equip a fishing pole from your bags"] = "自动装上鱼竿",
	["EQUIP_TIP"]                           = "抛竿时手上没有鱼竿，就从背包装上。",
	["Auto loot"]                           = "自动拾取",
	["LOOT_TIP"]                            = "钓到的东西直接进背包，只管钓鱼。",
	["Chime on cast"]                       = "抛竿提示音",
	["CHIME_TIP"]                           = "浮标落水时响一声。",

	-- sound page
	["Lower music and ambience"]     = "压低音乐与环境音",
	["Music"]                        = "音乐",
	["Ambience"]                     = "环境音",
	["Louder sound effects"]         = "音效开到最大",
	["Keep sound in the background"] = "切到后台仍有声音",
	["BG_TIP"]                       = "切到其他窗口时照样听得到水花声。",

	-- lure and hat page
	["Lure"]                 = "鱼饵",
	["Apply before casting"] = "抛竿前自动上饵",
	["LURE_AUTO_TIP"]        = "鱼竿没饵时，第一下上饵，第二下才抛竿。已经有饵就不换。",
	["Fishing hat"]          = "钓鱼帽",
	["HAT_TIP"]              = "抛竿前戴上，关掉钓鱼模式时换回原本的头部装备。",

	-- cast button page
	["Show the cast button"]    = "显示抛竿按钮",
	["BUTTON_TIP"]              = "隐藏后按键照样能抛竿。",
	["Button size"]             = "按钮大小",
	["Show the minimap button"] = "显示小地图按钮",
	["MINIMAP_TIP"]             = "隐藏后用 /ocfish 打开设置。",

	-- session HUD page
	["Show the HUD"]            = "显示 HUD",
	["HUD_TIP"]                 = "隐藏后照样统计。",
	["List catches"]            = "列出渔获",
	["Hide after"]              = "闲置后收起",
	["minutes"]                 = "分钟",
	["IDLE_TIP"]                = "下次抛竿再出现。",
	["Size"]                    = "大小",
	["Background"]              = "背景",
	["Show border"]             = "显示边框",
	["Lock positions"]          = "锁定位置",
	["LOCK_TIP"]                = "HUD 和抛竿按钮都不能拖动。",
	["Reset positions"]         = "重置位置",
	["Reset session"]           = "统计归零",
	["RESET_TIP"]               = "30 分钟没抛竿，下一竿也会自动归零。",

	-- appearance page
	["Language"]             = "语言",
	["Theme"]                = "主题",
	["THEME_tide"]           = "潮汐（蓝）",
	["THEME_obsidian"]       = "曜墨金（黑金）",
	["Off"]                  = "关",
	["On"]                   = "开",
	["Window scale"]         = "窗口大小",

	-- chat
	["NO_KEY"]          = "还没设置按键，输入 /ocfish 设置。",
	["KEY_TAKEN"]       = "%s 原本是“%s”，已改成抛竿与收竿。",
	["RESTORED"]        = "钓鱼时改过的游戏设置已还原。",
	["RIVAL_LOADED"]    = "%s 也在改钓鱼设置，两个一起开，钓完设置可能还原不回来。请禁用其中一个。",
	["Session reset."]  = "统计已归零。",
	["Not in combat."]  = "战斗中无法更改。",
}

ns.ApplyLocale(GetLocale())

-- The Key Bindings screen reads these globals.
BINDING_HEADER_ONECLICKFISH = "OneClickFish"
BINDING_NAME_ONECLICKFISH_CAST = L["Cast & loot"]
