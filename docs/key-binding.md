# 按鍵的兩種做法

一鍵釣魚的核心只有一件事：同一個鍵，沒拋竿時要「施放釣魚」，浮標可以互動時要「與目標互動」。遊戲不允許插件自己點浮標，也不允許在戰鬥中改按鍵，所以能用的只有 `SetOverrideBinding` 系列：在非戰鬥時把一個鍵暫時指到別的動作。

兩種做法差在「沒拋竿時」那個鍵是怎麼接到施放釣魚的。

## A. EasyFishing 的做法（目前採用）

`Bindings.xml` 綁的是一段 Lua（`OneClickFish_Run()`），本身什麼都不做，只負責把 override 補上。插件**隨時**都在這個鍵上掛著一個 override，依狀態二選一：

| 狀態 | override |
|---|---|
| 沒拋竿、或浮標不在互動範圍 | `SetOverrideBindingClick(鍵 → OneClickFishButton)`：點安全按鈕，施放釣魚 |
| 拋竿中且浮標是軟目標 | `SetOverrideBinding(鍵 → INTERACTTARGET)`：收竿 |

每次狀態變化（拋竿開始、結束、軟目標變化、按鍵設定變更、進入世界）都要清掉 override 再重掛。

- 優點：按鍵本身的動作無害。萬一 override 不見了（例如戰鬥中來不及更新），按下去只是重新掛上，不會做錯事。設定頁的「綁定按鍵」也只碰一個 binding 名稱。
- 缺點：兩個方向都要維護 override，狀態多一層；登入後第一次按若 override 還沒掛好，那一下會被吃掉（現在登入、進世界、`UPDATE_BINDINGS` 都會先掛，實際很少發生）。

## B. 直接用 CLICK binding（原本的第一版）

`Bindings.xml` 直接綁 `CLICK OneClickFishButton:LeftButton`：遊戲自己去點安全按鈕，不經過 Lua，也不需要 override。只有在「拋竿中且浮標是軟目標」時才掛一個 override 到 `INTERACTTARGET`，其他時候把 override 清掉，鍵就回到原本的 CLICK。

- 優點：少一個狀態，程式短；第一次按就有效；按鍵設定畫面顯示的就是一個普通的點擊綁定。
- 缺點：鍵的底層動作永遠是施放釣魚。若日後想加「停用插件」開關，得另外處理，不能靠 override 讓鍵變無害。

## 對玩家的差別

幾乎沒有。兩種做法在「浮標不在範圍」時都是重新拋竿（巨集開頭的 `/stopcasting` 會先收掉現在這竿），在「可互動」時都是收竿，戰鬥中都改不了。差別在程式的複雜度與第一次按鍵的可靠度，不在手感。

## 建議

B 比較簡單，而且沒有「第一下被吃掉」的狀況。目前照 A 實作是為了先對齊 EasyFishing 驗證過的流程；在遊戲裡確認 A 可用之後，換成 B 只需要改 `Bindings.xml` 的綁定方式，以及 `Core.lua` 的 `RefreshBinding` 在非就緒狀態下改為不掛 override。
