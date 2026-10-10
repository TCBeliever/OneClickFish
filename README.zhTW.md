# OneClickFish

**一個按鍵拋竿，同一個按鍵收竿。**

[English](README.md) · [更新紀錄](CHANGELOG.md)

在 *按鍵設定 > 插件 > OneClickFish* 綁一個鍵，或在 `/ocfish` 裡設定。在水邊按下拋竿；浮標濺起水花時再按一次，就收竿拾取，不用瞄準，不用滑鼠。

## 功能

- **一個按鍵。** 拋竿期間開啟遊戲的軟目標互動（寬角度、遠距離）。軟目標是浮標時，按鍵暫時改成「與目標互動」；其他時候按下就拋竿。收竿後還原你的設定；若當機讓設定留著，下次登入也會還原。
- **拋竿前後。** 拋竿前先從背包裝上魚竿；有選釣魚帽（已知的那幾頂，從背包或頭上找）的話也一併戴上，關閉釣魚模式時換回原本戴的。漁獲直接進背包，不開拾取視窗。魚線落水時一聲短促提示音。
- **魚餌。** 從背包裡的技能魚餌挑一個（午夜的那個、舊版通用的，以及可當魚餌用的帽子）。巨龍群島以後以魚命名的「誘餌」（提高釣到某種魚的機率）是加在你身上的增益，不是魚竿上的魚餌，不算在內。剩餘時間顯示在 HUD，魚竿上沒有魚餌時拋竿按鈕變琥珀色；勾了「拋竿前自動上餌」，按一下先上餌，再按一下才拋竿。魚竿上已經有魚餌（不管是哪一種）就不會替換。
- **聲音。** 遊戲沒有「魚上鉤」事件，只能聽水花聲。拋竿期間壓低音樂與環境音，收竿後還原；也可以把音效開到最大。拋竿期間遊戲切到背景仍有聲音，切去其他視窗也聽得到水花聲，不會錯過。
- **本次釣魚 HUD。** 從第一次拋竿起的小方框，三行：Casts、Catches、Catch/hr；Est. value；Gold/hr 與時間（HUD 的名詞在中文版也用英文，比較短也比較好懂），下方列出這次釣到的東西，價值最高的排最前面，附數量與金額；滑過可看物品。一頁十種，最多記五十種；滾輪翻頁。灰色物品和 Dejunk 判定為垃圾的不列。裝了 Auctionator 或 TSM 就用市場價格，否則用商店價格。拋竿期間底部有引導條，標題列有一顆重算按鈕。金額用遊戲的錢幣圖示，最多四位數、一位小數（105.4g、1,054g、10.2kg）。幾分鐘沒拋竿（預設 5 分鐘）方框就收起來，下一次拋竿再出現；超過三十分鐘沒拋竿就重新計算。
- **畫面上。** 一個拋竿按鈕，顯示釣魚工具欄位裡的魚竿，提示也是那支魚竿的：左鍵拋竿或收竿，Shift + 左鍵關閉釣魚模式，右鍵開設定。一個小地圖按鈕，用釣魚專業的圖示：左鍵開關釣魚模式（按鍵、按鈕、拋竿時切換的設定、計數，一次全開全關），右鍵開設定。

全部用遊戲自己的字型和一組扁平配色繪製，與 CombatKit 相同。不用任何函式庫。

## 安裝

- 解壓縮到 `World of Warcraft/_retail_/Interface/AddOns/`，確認有 `AddOns/OneClickFish/OneClickFish.toc`。
- 僅支援正式服（Interface 12.1），沒有做經典版。

## 指令

- `/ocfish`：設定。小地圖旁的插件選單、遊戲的 選項 > 插件 清單、HUD 上按右鍵也可以開。
- `/ocfish on`、`/ocfish off`：釣魚模式。
- `/ocfish reset`：重新計算本次釣魚。
- `/ocfish restore`：手動還原互動與聲音設定。

## 給其他插件

`OneClickFish.GetStats()` 回傳本次釣魚（casts、catches、items、value、marketValue、vendorValue、source、elapsed、catchPerHour、goldPerHour）；`OneClickFish.RegisterCallback(fn)` 在數字變動時呼叫 `fn(stats)`。

## 開發

`deploy.bat` 把插件複製到遊戲目錄，遊戲裡 `/reload`。`python tests/run_tests.py`（需要 `pip install lupa`）會編譯每個檔案、檢查發佈資訊與語系覆蓋，並用 WoW API 樁模擬一趟釣魚，兩種語言各跑一次。[docs/key-binding.md](docs/key-binding.md) 比較按鍵的兩種接法。

一鍵釣魚的技巧參考 [EasyFishing](https://www.curseforge.com/wow/addons/easyfishing)（MIT）；見 [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)。
