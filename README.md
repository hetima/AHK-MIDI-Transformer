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


・ `AMTMidiNoteOn:` ラベル  
すべてのノートオンを受け取るラベルです。 `midi.MidiIn()` で現在のMIDIイベントを取得し `intercepted` プロパティを `True` にすることによりパススルーされなくなり発音されなくなります。

```ahk
AMTMidiNoteOn:
    ;Ctrlを押しながら鍵盤を弾くとなにかする
    If (GetKeyState("Ctrl"))
    {
        ; intercepted を True にすることによってパススルーされなくなる
        event := midi.MidiIn()
        event.intercepted := True
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
    }
Return
```

・ `AMTMidiNoteOff:` ラベル  
すべてのノートオフを受け取るラベルです。`intercepted` の仕様は `AMTMidiNoteOn:` と同等です。

・ `AMTMidiNoteOnノート名:` ラベル  
・ `AMTMidiNoteOffノート名:` ラベル  
ノートオン/オフをノートごとに受け取るラベルです。C3などの文字もしくは生の値です。数値の確認はセッティングウィンドウを前面に出して鍵盤を押すと表示されます。このラベルが実行されると発音はされません。個別ラベル実行時に `intercepted` は `True` になっています。ノートごとのラベルが存在する場合、そのノートでは  `AMTMidiNoteOn/Off:` は実行されませんが、個別ラベルの中で `intercepted` を `False` にすると `AMTMidiNoteOn/Off:` も実行され、そのまま変更がなければパススルーもされます。  

```ahk
AMTMidiNoteOnC1:
    ; 上記の AMTMidiNoteOn: に対応させたい場合、Ctrl が押されていたら intercepted := False とする
    If (GetKeyState("Ctrl"))
    {
        midi.MidiIn().intercepted := False
        Return
    }
    ; main code
Return
```


・ `AMTMidiControlChange:` ラベル  
すべてのCCを受け取るラベルです。`intercepted` の仕様は `AMTMidiNoteOn:` と同等です。

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
CCを個別に受け取るラベルです。個別のラベルが存在する場合、そのCCでは  `AMTMidiControlChange:` は実行されませんが、個別ラベルの中で `intercepted` を `False` にすると `AMTMidiControlChange:` も実行され、そのまま変更がなければパススルーもされます。  

・ `SendAllNoteOff()`  
オールノートオフをアウトプットデバイスに送信する関数です。

・ `SetAutoScale(key, scale, showPanel = False)`  
Auto Scaleの設定を変更する関数です。`Key` はC=1～B=12、`scale` は Major=1 Minor=2 H-Minor=3 M-Minor=4 の数字を指定します。`showPanel` を `True` にしておくとパネルを表示します。

```ahk
AMTMidiNoteOn:
    ;Ctrlを押しながら鍵盤を弾くとAutoScale設定を変更する例
    If (GetKeyState("Ctrl"))
    {
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
    }
Return
```