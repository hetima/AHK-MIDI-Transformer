# AHK-MIDI-Transformer

MIDIデバイスのベロシティ固定とスケール固定を行うAutoHotkeyスクリプトです。

タスクバーのメニューからインプットデバイス(MIDIキーボードなど)とアウトプットデバイス(loopMIDI仮想デバイスなど)を選択します。
タスクバーのSettingメニューから動作の設定ができます。

## Fixed Velocity
ベロシティの値を固定させます。0-127の間で変更できます。0のときはオフになります。設定ウィンドウの他CCでも変更できます。  
CCで変更したい場合一度起動して終了させ、同じ階層に作られたiniファイルの
```
fixedVelocityCC=21
```
の部分をお望みの数字に書き換えてください。デフォルトでは相対値(65で+、63で-)で変わります。絶対値で変更したい場合は
```
CCMode=1
```
の設定を0にしてください。

## Auto Scale
白鍵のみでスケールを演奏できるようになります。設定ウィンドウでキーやスケールを変更できます。  
強制的にCがルート音にります。例えばキーをFにするとCでFが鳴ります。  
C Majorにしておくと何も変更されない通常通りの動作となります。起動し直すとC Majorに戻ります。  

## Chord In Black Key
黒鍵1キーでコードを弾ける機能です。C# から1オクターブ上の D# まで Auto Scale のスケールに合ったコードを弾くことができます。それよりも高い/低い黒鍵も順番にコードが鳴ります。Settingウィンドウで機能自体のオンオフと、どのC#からどの高さの音を鳴らすかを設定できます。

## Chord In White Key
白鍵1キーでコードを弾ける機能です。これがオンになっている間は Chord In Black Key もオンになります。

## ファイル構成

### AHK-MIDI-Transformer.ahk

本体です。通常はこれを起動させます。


### Midi.ahk

必要なライブラリです。[AutoHotkey-Midiをforkして改造したバージョン](https://github.com/hetima/AutoHotkey-Midi)です。

### SampleExpansion.ahk

AHK-MIDI-Transformer.ahk を読み込んで更に機能を追加したスクリプトです。  
本体のみでもそれなりの機能はあるのですが、このようにカスタマイズすると更に便利になります。

### icon.ico

タスクトレイに表示されるアイコンです。

## 拡張

AHK-MIDI-Transformer.ahk を読み込んで更に機能を追加したスクリプトで使えるコード例

・ `midi`  
AutoHotkey-Midi のインスタンスがグローバル変数 `midi` に格納されています。

・ AMTFinishLaunching:` ラベル  
AHK-MIDI-Transformer の初期化が完了したタイミングで呼び出されるラベルです。

・ `AMTMidiNoteOn:` ラベル  
・ `AMTMidiNoteOnCtrl:` ラベル  
すべてのノートオンを受け取るラベルです。 `midi.MidiIn()` で現在のMIDIイベントを取得し `intercepted` プロパティを `True` にすることによりパススルーされなくなり発音されなくなります。  
同時に Ctrl キーを押しているときは `AMTMidiNoteOnCtrl:` ラベルが実行されます。

```ahk
AMTMidiNoteOn:
    ; midi.MidiIn() で現在のMIDIイベントを取得できる
    event := midi.MidiIn()
    ; ベロシティ
    velocity := event.velocity
    ; ノートネーム C など
    note := event.note
    ; オクターブ
    octave := event.octave
    ; ノートネーム+オクターブ C3 など
    noteName := event.noteName
    ; ノートナンバー
    noteNumber := event.noteNumber

    If (GetKeyState("Shift"))
    {
        ; intercepted を True にすることによってパススルーされなくなる
        event.intercepted := True
    }
Return
```

・ `AMTMidiNoteOff:` ラベル  
すべてのノートオフを受け取るラベルです。`intercepted` の仕様は `AMTMidiNoteOn:` と同等です。  
ノートオフには `Ctrl` が付いたラベルはありません。

・ `AMTMidiNoteOnノート名:` ラベル  
・ `AMTMidiNoteOffノート名:` ラベル  
・ `AMTMidiNoteOnノート名Ctrl:` ラベル  
ノートオン/オフをノートごとに受け取るラベルです。C3などの文字もしくは生の値です。数値の確認はセッティングウィンドウを前面に出して鍵盤を押すと表示されます。このラベルが実行されると発音はされません。個別ラベル実行時に `intercepted` は `True` になっています。ノートごとのラベルが存在する場合、そのノートでは  `AMTMidiNoteOn/Off:` は実行されませんが、個別ラベルの中で `intercepted` を `False` にすると `AMTMidiNoteOn/Off:` も実行され、そのまま変更がなければパススルーもされます。  
ノートオンでは同時に Ctrl キーを押しているときは末尾に `Ctrl` が付いたラベルが実行されます。


```ahk
AMTMidiNoteOnC1:
    If (GetKeyState("Shift"))
    {
        Return
    }
    ; 上記の AMTMidiNoteOn: も呼びたい場合、 intercepted := False とする
    midi.MidiIn().intercepted := False
Return
```


・ `AMTMidiControlChange:` ラベル  
・ `AMTMidiControlChangeCtrl:` ラベル  
すべてのCCを受け取るラベルです。`intercepted` の仕様は `AMTMidiNoteOn:` と同等です。  
同時に Ctrl キーを押しているときは末尾に `Ctrl` が付いたラベルが実行されます。

```ahk
AMTMidiControlChange:
    event := midi.MidiIn()
    cc := event.controller
    value := event.value
    If (cc == 99){
        event.intercepted := True
    }
Return
```

・ `AMTMidiControlChange数字:` ラベル  
・ `AMTMidiControlChange数字Ctrl:` ラベル  
CCを個別に受け取るラベルです。個別のラベルが存在する場合、そのCCでは  `AMTMidiControlChange:` は実行されませんが、個別ラベルの中で `intercepted` を `False` にすると `AMTMidiControlChange:` も実行され、そのまま変更がなければパススルーもされます。  
同時に Ctrl キーを押しているときは末尾に `Ctrl` が付いたラベルが実行されます。

・ `SendAllNoteOff()`  
オールノートオフをアウトプットデバイスに送信する関数です。

・ `SetAutoScale(key, scale, showPanel = False)`  
Auto Scaleの設定を変更する関数です。`Key` はC=1～B=12、`scale` は Major=1 Minor=2 H-Minor=3 M-Minor=4 の数字を指定します。`showPanel` を `True` にしておくとパネルを表示します。

```ahk
;Ctrlを押しながら鍵盤を弾くとAutoScale設定を変更する例
AMTMidiNoteOnCtrl:
    event := midi.MidiIn()
    event.intercepted := True
    scale := 1
    ;Shiftも押すとマイナー
    If (GetKeyState("Shift"))
    {
        scale := 2
    }
    key := Mod( event.noteNumber, MIDI_NOTE_SIZE )
    SetAutoScale(key + 1, scale, True)
Return
```

・ `ShowMessagePanel(txt, title = "Message")`  
引数 `txt` を大きな文字で表示するウィンドウを表示します。1秒経過するかescを押すとウィンドウは閉じます。

・ `SetOctaveShift(octv, showPanel = False)`  
・ `IncreaseOctaveShift(num, showPanel = False)`  
オクターブシフトの値を設定します。`IncreaseOctaveShift` に負の値を渡すとオクターブを下げることができます。`showPanel` を `True` にしておくとパネルを表示します。

・ `SetChordInBlackKeyEnabled(isEnabled, showPanel = False)`  
Chord In Black Key のオンオフを設定します。第一引数に True/False もしくは 1/0 を渡します。トグルしたい場合は `SetChordInBlackKeyEnabled( !blackKeyChordEnabled )` としてください。`showPanel` を `True` にしておくとパネルを表示します。

・ `SetChordInWhiteKeyEnabled(isEnabled, showPanel = False)`  
Chord In White Key のオンオフを設定します。第一引数に True/False もしくは 1/0 を渡します。トグルしたい場合は `SetChordInWhiteKeyEnabled(!whiteKeyChordEnabled)` としてください。`showPanel` を `True` にしておくとパネルを表示します。

