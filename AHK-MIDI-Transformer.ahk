; # AHK-MIDI-Transformer
; タスクバーのメニューからインプットデバイス(MIDIキーボードなど)とアウトプットデバイス(loopMIDI仮想デバイスなど)を選択します。
; タスクバーのSettingメニューから動作の設定ができます。
; ## Fixed Velocity
; ベロシティの値を固定させます
; 0-127の間で変更できます。0のときはオフになります。設定ウィンドウの他CCでも変更できます。
; CCで変更したい場合一度起動して終了させ、同じ階層に作られたiniファイルの
; ```
; fixedVelocityCC=21
; ```
; の部分をお望みの数字に書き換えてください。デフォルトでは相対値(65で+、63で-)で変わります。絶対値で変更したい場合は
; ```
; CCMode=1
; ```
; の設定を0にしてください。
; ## Auto Scale
; 白鍵のみでスケールを演奏できるようになります。設定ウィンドウでキーやスケールを変更できます。
; 強制的にCがルート音にります。例えばキーをFにするとCでFが鳴ります。
; C Majorにしておくと何も変更されない通常通りの動作となります。起動し直すとC Majorに戻ります。


#NoEnv  ; Recommended for performance and compatibility with future AutoHotkey releases.
; #Warn  ; Enable warnings to assist with detecting common errors.
SendMode Input  ; Recommended for new scripts due to its superior speed and reliability.

; 設定ファイルのパス
Global settingFilePath
if(!settingFilePath){
    settingFilePath := A_ScriptDir . "\AHK-MIDI-Transformer.ini"
}
; 以下の設定はiniファイルに保存されるのでここを編集しても反映されません
; iniファイルがないときの初期値です
; GUIで変更できない現在値を変えたい場合はahkを終了させてからiniを編集してください

; ベロシティ固定値 0-127 0==off
Global fixedVelocity := 0
; ベロシティ固定値を変更するCC
Global fixedVelocityCC := 21
; CCで変更するとき100以下の増減値（CCMode := 1のときのみ有効）
Global fixedVelocityCCStep := 5
; CC設定 0==絶対値 1==相対(65で+、63で-) 
Global CCMode := 1

;iniに書き込まれる設定おわり


; オートスケール
Global autoScaleKey := 1 ;1==C ~ 12==B
Global autoScale := 1 ;1==Major 2==Minor 3==H-Minor 4==M-Minor
Global octaveShift := 0
; 一時的にオフにするとき用
Global autoScaleOff := False


; このファイルと同じ階層にある Midi.ahk を読み込む
#include %A_LineFile%\..\Midi.ahk
Global midi := new Midi()
OnExit, ExitSub
midi.LoadIOSetting(settingFilePath)
LoadSetting()
InitSettingGui()
InitSettingCCFV()
Menu, Tray, Add
Menu, Tray, Add, Setting
midiEventPassThrough := True

;Global MIDI_NOTES     := [ "C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B" ]
Global MIDI_SCALES    := ["Major", "Minor", "H-Minor", "M-Minor"]
Global MIDI_SCALES_S  := ["", "min", "Hmin", "Mmin"]
Global MINOR_SHIFT     := [ 0, 0, 0, 0, -1, 0, 0, 0, 0, -1, 0, -1 ]
Global H_MINOR_SHIFT   := [ 0, 0, 0, 0, -1, 0, 0, 0, 0, -1, 0, 0 ]
Global M_MINOR_SHIFT   := [ 0, 0, 0, 0, -1, 0, 0, 0, 0, 0, 0, 0 ]

Process, Exist,
global __pid := ErrorLevel
; 必須初期化おわり

Menu, Tray, Icon, %A_LineFile% \..\icon.ico

; 初期化おわり
Return


; オールノートオフを送信する
SendAllNoteOff(ch = 1)
{
    dwMidi := (176+ch) + (123 << 8) + (0 << 16)
    midi.MidiOutRawData(dwMidi)
}

;;;;;;;;;; transform ;;;;;;;;;;

; CC
MidiControlChange:
    event := midi.MidiIn()
    event.intercepted := False
    altLabel := "AMTMidiControlChange" . event.controller
    If IsLabel( altLabel )
    {
        Gosub %altLabel%
        event.intercepted := True
    }
    else If IsLabel( "AMTMidiControlChange" )
    {
        ;ラベルが存在しないと直接指定できないので変数に入れる
        altLabel := "AMTMidiControlChange"
        Gosub %altLabel%
    }
    If (!event.intercepted){
        cc := event.controller
        If (cc == fixedVelocityCC)
        {
            SetFixedVelocityFromCC()
        }else{
            midi.MidiOutRawData(event.rawBytes)
        }
    }
    ;設定ウィンドウがアクティブなら情報表示
    IfWinActive ahk_pid %__pid%
    {
        If (!event.intercepted)
        {
            log := "CC:" event.controller . " (" . event.value . ")"
        }
        else
        {
            log := "CC:" event.controller . " (" . event.value . ")  -> intercepted"
        }
        GuiControl, 7:Text, SLogTxt, %log%
    }
Return


TransformMidiNote(noteEvent)
{
    noteNumber := noteEvent.noteNumber
    noteNumber := octaveShift * MIDI_NOTE_SIZE + noteNumber
    If (!autoScaleOff)
    {
        If (autoScale == 2)
        {
            noteScaleNumber := Mod( noteNumber, MIDI_NOTE_SIZE )
            noteNumber := noteNumber + MINOR_SHIFT[noteScaleNumber + 1]
        }
        else If (autoScale == 3)
        {
            noteScaleNumber := Mod( noteNumber, MIDI_NOTE_SIZE )
            noteNumber := noteNumber + H_MINOR_SHIFT[noteScaleNumber + 1]
        }
        else If (autoScale == 4)
        {
            noteScaleNumber := Mod( noteNumber, MIDI_NOTE_SIZE )
            noteNumber := noteNumber + M_MINOR_SHIFT[noteScaleNumber + 1]
        }
        If (autoScaleKey != 1)
        {
            keyShift := autoScaleKey - 1
            If (keyShift > 6)
            {
                keyShift := keyShift - 12
            }
            noteNumber := noteNumber + keyShift
        }
    }
    Return noteNumber
}


; fixed velocity
MidiNoteOn:
    event := midi.MidiIn()
    event.intercepted := False
    altLabel := "AMTMidiNoteOn" . event.noteNumber
    If IsLabel( altLabel )
    {
        Gosub %altLabel%
        event.intercepted := True
    }
    else If IsLabel( "AMTMidiNoteOn" )
    {
        ;ラベルが存在しないと直接指定できないので変数に入れる
        altLabel := "AMTMidiNoteOn"
        Gosub %altLabel%
    }
    If (!event.intercepted)
    {
        ; MsgBox %event.velocity%
        If (fixedVelocity > 0 && fixedVelocity < 128)
        {
            newVel := fixedVelocity
        }else{
            newVel = event.velocity
        }
        newNum := TransformMidiNote(event)
        Midi.MidiOut("N1", 1, newNum, newVel)
    }
    ;設定ウィンドウがアクティブなら情報表示
    IfWinActive ahk_pid %__pid%
    {
        If (!event.intercepted)
        {
            ; Determine the octave of the note in the scale 
            noteOctaveNumber := Floor( midiEvent.noteNumber / MIDI_NOTE_SIZE )
            ; Create a friendly name for the note and octave, ie: "C4"
            newNoteName := MIDI_NOTES[ Mod( newNum, MIDI_NOTE_SIZE ) + 1 ] . MIDI_OCTAVES[ Floor( newNum / MIDI_NOTE_SIZE ) + 1 ]
            log := event.noteNumber . " (" . event.noteName . ") vel:" . event.velocity . " -> " . newNum . " (" . newNoteName . ") vel:" . newVel
        }
        else
        {
            log := event.noteNumber . " (" . event.noteName . ") vel:" . event.velocity . " -> intercepted"
        }
        GuiControl, 7:Text, SLogTxt, %log%
    }
Return

MidiNoteOff:
    event := midi.MidiIn()
    event.intercepted := False
    altLabel := "AMTMidiNoteOff" . event.noteNumber
    If IsLabel( altLabel )
    {
        Gosub %altLabel%
        event.intercepted := True
    }
    else If IsLabel( "AMTMidiNoteOff" )
    {
        ;ラベルが存在しないと直接指定できないので変数に入れる
        altLabel := "AMTMidiNoteOff"
        Gosub %altLabel%
    }
    If (!event.intercepted)
    {
        noteNumber := TransformMidiNote(event)
        Midi.MidiOut("N0", 1, noteNumber, event.velocity)
    }
Return

;;;;;;;;;; setting ;;;;;;;;;;

; fixedVelocityを変更するCCが来たらパネルを表示
SetFixedVelocityFromCC()
{
    If (CCMode==0){
        fixedVelocity := midi.MidiIn().value
    }else{
        step := 1
        If (fixedVelocity <= 100 && fixedVelocityCCStep > 0 && fixedVelocityCCStep < 20){
            step := fixedVelocityCCStep
        }
        fixedVelocity := fixedVelocity + (midi.MidiIn().value - 64)*step
    }
    If (fixedVelocity > 127){
        fixedVelocity := 127
    }Else if(fixedVelocity < 0){
        fixedVelocity := 0
    }

    GuiControl, 9:Text, CCTxt, %fixedVelocity%
    Gui 9:Show, w360 h100, Fixed Velocity
    SetTimer, HideSettingCCFV, 1000
    updateSettingWindow()
}

SetAutoScale(key, scale, showPanel = False)
{
    autoScaleKey := key
    autoScale := scale
    UpdateSettingWindow()
    If (showPanel){
        str := MIDI_NOTES[key] . " " . MIDI_SCALES_S[scale]
        GuiControl, 9:Text, CCTxt, %str%
        Gui 9:Show, w360 h100, Auto Scale
        SetTimer, HideSettingCCFV, 1000
    }
}

; 設定ウィンドウ

global SFVSlidr
global SFVTxt
global SScaleKey
global SScale
global SLogTxt
InitSettingGui(){
    Gui 7: -MinimizeBox -MaximizeBox
    Gui 7: Font, s12, Segoe UI
    Gui 7: Add, Text, x8 y16 w120 h30 +0x200 Right, Fixed Velocity:
    Gui 7: Add, Slider, vSFVSlidr gSlidrChanged x136 y16 w230 h32 +NoTicks +Center Range0-127, %fixedVelocity%
    Gui 7: Add, Text, vSFVTxt x380 y16 w53 h30 +0x200, %fixedVelocity%

    Gui 7: Add, Text, x8 y64 w120 h30 +0x200 Right, Auto Scale:
    Gui 7: Add, DropDownList, vSScaleKey gSScaleKeyChanged AltSubmit x136 y64 w87, C|C#/Db|D|D#/Eb|E|F|F#/Gb|G|G#/Ab|A|A#/Bb|B
    Gui 7: Add, DropDownList, vSScale gSScaleChanged AltSubmit x240 y64 w90, Major|Minor|H-Minor|M-Minor
    Gui 7: Add, Text,vSLogTxt x16 y110 w380 h26 +0x200,
    Gui 7: Font
}

; Esc押したら閉じる
7GuiEscape:
    Gui ,7: Cancel
Return

; Settingメニュー項目
Setting:
;   Msgbox, Menu
    showSetting()
Return

; 設定ウィンドウを表示
ShowSetting()
{
    updateSettingWindow()
    Gui 7: Show, w440 h140, AHK-MIDI-Transformer Setting
    Return
}
UpdateSettingWindow()
{
    GuiControl , 7:, SFVSlidr, %fixedVelocity%
    GuiControl , 7:Text, SFVTxt, %fixedVelocity%
    GuiControl, 7:Choose, SScaleKey, %autoScaleKey%
    GuiControl, 7:Choose, SScale, %autoScale%
}

SScaleKeyChanged:
    GuiControlGet, outputVar, 7:, SScaleKey
    autoScaleKey := outputVar
Return

SScaleChanged:
    GuiControlGet, outputVar, 7:, SScale
    autoScale := outputVar
Return

; 設定ウィンドウのスライダーが動いたら
SlidrChanged:
    GuiControlGet, outputVar, 7:, SFVSlidr
    fixedVelocity := outputVar
    updateSettingWindow()
    ; GuiControl, 7:Text, SFVTxt, %fixedVelocity%
Return


; fixedVelocity 変更中のウィンドウ
global CCTxt

InitSettingCCFV()
{
    Gui 9:-MinimizeBox -MaximizeBox
    Gui 9:Font, s60
    Gui 9:Add, Text, vCCTxt x0 y16 w360 h62 +0x200 Center, %fixedVelocity%
    Gui 9:Font
}

; Esc押したら閉じる
9GuiEscape:
    Gui ,9: Cancel
Return

ShowSettingCCFV()
{
    Gui 9: Show, w348 h98, Window
}

HideSettingCCFV:
    Gui 9:Hide
    SetTimer, HideSettingCCFV, Off
Return




; 設定読み込み/保存
LoadSettingValue(name, defaultVal)
{
    IniRead, result, %settingFilePath%, mySettings, %name%
    If (result <> "ERROR"){
        return result
    }
    return defaultVal
}

LoadSetting()
{
    fixedVelocity := LoadSettingValue("fixedVelocity", fixedVelocity)
    fixedVelocityCC := LoadSettingValue("fixedVelocityCC", fixedVelocityCC)
    fixedVelocityCCStep :=LoadSettingValue("fixedVelocityCCStep", fixedVelocityCCStep)
    CCMode :=LoadSettingValue("CCMode", CCMode)

}

SaveSettingValue(name, val)
{
    IniWrite, %val%, %settingFilePath%, mySettings, %name%
}

SaveSetting()
{
    SaveSettingValue("fixedVelocity", fixedVelocity)
    SaveSettingValue("fixedVelocityCC", fixedVelocityCC)
    SaveSettingValue("fixedVelocityCCStep", fixedVelocityCCStep)
    SaveSettingValue("CCMode", CCMode)
    ; IniWrite, %fixedVelocity%, %settingFilePath%, mySettings, fixedVelocity
}

ExitSub:
    SaveSetting()
    midi.SaveIOSetting(settingFilePath)
ExitApp
