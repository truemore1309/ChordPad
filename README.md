# ChordPad

用 8 顆按鍵彈和弦的 MIDI 小工具。按一顆鍵，就從虛擬 MIDI 埠送出一整個和弦給 DAW（Ableton Live 等）。
介面照 8 按鍵街機搖桿的配置設計，正在按的鍵會亮紅燈。

*An 8-button chord pad for your DAW: press one button on an arcade stick, gamepad, MIDI keyboard or your computer keyboard, and ChordPad sends a whole chord out of a virtual MIDI port.*

## 功能

- **三種輸入**：MIDI 鍵盤／Xbox 手把或街機搖桿／電腦鍵盤（RTYU FGHJ）
- **每顆 pad 一個和弦**：自己加音，或選根音＋和弦類型（Major、m7、dim7…）自動產生；可設輸出通道和力度
- **Learn**：在和弦編輯器按 Learn，再按你想用的鍵，就完成對應
- **搖桿／D-pad 轉 MIDI**
  - 左搖桿：上下＝Pitch Bend，左右＝CC28
  - D-pad：上／下／左／右＝CC 20／21／22／23（按下 127、放開 0），可在 DAW 裡分別 MIDI Map
  - 可設定漸變時間：0→100 與 100→0 各自幾毫秒（0＝立即）
- **Preset**：存成 JSON，可切換、另存
- **Sampler**：一鍵把 8 顆 pad 改成單音 C1–G1（Ableton Drum Rack 排列）
- **Panic**：立刻停止所有聲音

## 下載與安裝（macOS）

1. 到 [Releases](../../releases) 下載 `ChordPad-macOS.zip`，解壓縮後把 `ChordPad.app` 拖進「應用程式」。
2. 第一次打開時 macOS 會說「無法驗證開發者」（這個 App 沒有 Apple 付費簽章）。解法擇一：
   - 在 `ChordPad.app` 上按右鍵 →「打開」→ 再按一次「打開」
   - 或在終端機執行：
     ```bash
     xattr -dr com.apple.quarantine /Applications/ChordPad.app
     ```
3. 打開後，在 DAW 的 MIDI 設定裡啟用名為 **ChordPad** 的 MIDI 輸入埠（Ableton：設定 → Link, Tempo & MIDI → 把 ChordPad 的 Track 打開）。

## 使用方式

- 左上角 **MIDI / XBOX / KEYS** 切換輸入來源
- **點任一顆 pad** 打開和弦編輯器：設定和弦、Learn 觸發鍵、通道、力度
- **SET**：MIDI 輸入／輸出裝置、搖桿與 D-pad 設定、漸變時間、另存 preset
- **SAVE**：儲存目前 preset（沒按 SAVE 的修改不會保留）
- Preset 檔案位置：SET → Reveal presets folder

### 街機搖桿小提示

8BitDo 等街機搖桿通常有 **LS / DP / RS** 切換：
- **LS**：搖桿當左類比搖桿 → 送 Pitch Bend + CC28（Ableton 無法把 Pitch Bend MIDI Map 到參數，CC28 可以）
- **DP**：搖桿當十字鍵 → 送 CC 20–23，最適合在 DAW 裡 MIDI Map
- 街機搖桿本身只有開／關（0 或 100），想要漸變效果請用 SET 裡的 0→100 / 100→0 毫秒設定

## 電腦鍵盤模式（KEYS，進階、僅 macOS）

用 Karabiner-Elements 把 R T Y U F G H J 轉成 MIDI 音符，經由 IAC 虛擬埠送進 ChordPad。

1. 打開「音訊 MIDI 設定」→ 視窗 → 顯示 MIDI 工作室 → 雙擊 **IAC Driver** → 勾選「裝置已連線」，新增一個埠，名稱**必須**是 `ChordPad Keyboard`。
2. 需要 Xcode Command Line Tools（`xcode-select --install`），然後編譯 bridge 工具（會安裝到 `~/.chordpad/keyboard_bridge/`）：
   ```bash
   sh tools/keyboard_bridge/build.sh
   ```
3. 啟動常駐程式（避免快速連按時卡音）：
   ```bash
   ~/.chordpad/keyboard_bridge/chordpad_bridge_daemon &
   ```
4. 安裝 [Karabiner-Elements](https://karabiner-elements.pqrs.org/)，把 `tools/keyboard_bridge/chordpad_keyboard_bridge.json` 複製到 `~/.config/karabiner/assets/complex_modifications/`，再到 Karabiner → Complex Modifications → Add rule 啟用。
   這條規則只在 Ableton Live 在最前面時生效，其他 App 打字不受影響。
5. ChordPad 切到 **KEYS** 模式。

## 從原始碼執行／修改

需要 [Godot 4.5](https://godotengine.org/)。

```bash
# 執行
/Applications/Godot.app/Contents/MacOS/Godot --path .

# 改了 scripts/ui_theme.gd 的顏色之後，重新產生主題
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tools/build_theme.gd

# 檢查手把實際送出的訊號（除錯用）
/Applications/Godot.app/Contents/MacOS/Godot --path . --script res://tools/joypad_monitor.gd

# 匯出 macOS App（需安裝 Godot 4.5.1 匯出模板）
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --export-release "macOS" builds/ChordPad.app
```

關閉視窗時終端機會顯示 `killed`，這是刻意的：程式關閉時直接結束行程，避開 godot_rtmidi 在 Godot 正常關閉流程中的崩潰。

### 專案結構

| 路徑 | 內容 |
|---|---|
| `scripts/midi_router.gd` | MIDI 進出、手把／搖桿／D-pad 處理、漸變（autoload） |
| `scripts/preset_manager.gd` | Preset 讀寫（autoload） |
| `scripts/main.gd`、`scenes/main.tscn` | 主畫面 |
| `scripts/pad_button.gd` | 圓形 pad（自繪、亮起淡出） |
| `scripts/ui_theme.gd` | 配色與主題（輸出到 `ui/theme.tres`） |
| `scripts/chord_theory.gd` | 和弦類型與和弦名稱辨識 |
| `tools/keyboard_bridge/` | 電腦鍵盤 → MIDI 的 Karabiner 橋接工具 |

## 已知限制

- 目前只在 macOS 測試過。Windows 理論上可匯出，但 Windows 不支援虛擬 MIDI 埠，需另外裝 loopMIDI 之類的工具並在 SET 選擇該輸出埠（未測試）。
- 電腦鍵盤模式只支援 macOS。

## 授權

ChordPad 以 [MIT License](LICENSE) 釋出。

使用的第三方元件：
- [godot-rtmidi](https://github.com/NullMember/godot-rtmidi)（Malik Enes Şafak）：The Unlicense（公眾領域），內含 [RtMidi](https://github.com/thestk/rtmidi)（Gary P. Scavone，MIT 類授權）
- [Godot Engine](https://godotengine.org/)：MIT License
