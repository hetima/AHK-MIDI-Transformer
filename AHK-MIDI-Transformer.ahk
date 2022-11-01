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

; 黒鍵を弾くとコードになる。0==off 1==on
Global blackKeyChordEnabled := 0
; C#を基準にする 0 ～ 5
Global blackKeyChordRootKey := 3
; そのC#を弾くと鳴る音の高さ
Global blackKeyChordRootPitch := 3 
; コード弾きのボイシング
Global chordVoicing := 1
; iniに書き込まれる設定おわり

; オートスケール
Global autoScaleKey := 1 ;1==C ~ 12==B
Global autoScale := 1 ;1==Major 2==Minor 3==H-Minor 4==M-Minor
Global octaveShift := 0
; 一時的にオフにするとき用
Global autoScaleOff := False

;Global MIDI_NOTES     := [ "C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B" ]
Global MIDI_SCALES     := ["Major", "Minor", "H-Minor", "M-Minor"]
Global MIDI_SCALES_S   := ["", "min", "Hmin", "Mmin"]

Global MAJOR_KEYS      := [ 0, 2, 4, 5, 7, 9, 11 ] ;CDEFGAB
Global MINOR_KEYS      := [ 0, 2, 3, 5, 7, 8, 10 ]
Global H_MINOR_KEYS    := [ 0, 2, 3, 5, 7, 8, 11 ]
Global M_MINOR_KEYS    := [ 0, 2, 3, 5, 7, 9, 11 ]
Global SCALE_KEYS      := [MAJOR_KEYS, MINOR_KEYS, H_MINOR_KEYS, M_MINOR_KEYS]

Global MAJOR_SHIFT     := [ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 ]
Global MINOR_SHIFT     := [ 0, 0, 0, 0, -1, 0, 0, 0, 0, -1, 0, -1 ]
Global H_MINOR_SHIFT   := [ 0, 0, 0, 0, -1, 0, 0, 0, 0, -1, 0, 0 ]
Global M_MINOR_SHIFT   := [ 0, 0, 0, 0, -1, 0, 0, 0, 0, 0, 0, 0 ]
Global SCALE_SHIFTS    := [MAJOR_SHIFT, MINOR_SHIFT, H_MINOR_SHIFT, M_MINOR_SHIFT]

Global VOICING_TRIAD   := [[1,3,5]]
Global VOICING_1INV    := [[1+7,3,5]]
Global VOICING_2INV    := [[1+7,3+7,5]]
Global VOICING_CHORDS  := [VOICING_TRIAD, VOICING_1INV, VOICING_2INV]
Global VOICING_NAMES   := ["triad", "1st inv", "2nd inv"]

; このファイルと同じ階層にある Midi.ahk を読み込む
#include %A_LineFile%\..\Midi.ahk
Global midi := new Midi()
OnExit, ExitSub
midi.LoadIOSetting(settingFilePath)
LoadSetting()
InitSettingGui()
InitSettingMessageGui()
Menu, Tray, Add
Menu, Tray, Add, Setting
midiEventPassThrough := True

Process, Exist,
global __pid := ErrorLevel
; 必須初期化おわり

If (FileExist(A_LineFile . "\..\icon.ico")){
    Menu, Tray, Icon, %A_LineFile% \..\icon.ico
}

finishLaunching := "AMTFinishLaunching"
If (IsLabel(finishLaunching)){
    Gosub, %finishLaunching%
}

; 初期化おわり
Return


; オールノートオフを送信する
SendAllNoteOff(ch = 1)
{
    dwMidi := (176+ch) + (123 << 8) + (0 << 16)
    midi.MidiOutRawData(dwMidi)
}

SendAllSoundOff(ch = 1)
{
    dwMidi := (176+ch) + (120 << 8) + (0 << 16)
    midi.MidiOutRawData(dwMidi)
}

SendResetAllController(ch = 1)
{
    dwMidi := (176+ch) + (121 << 8) + (0 << 16)
    midi.MidiOutRawData(dwMidi)
}

;;;;;;;;;; transform ;;;;;;;;;;

; CC
MidiControlChange:
    event := midi.MidiIn()
    event.intercepted := False
    allCCLAbel := "AMTMidiControlChange"
    altLabel := allCCLAbel . event.controller
    If (GetKeyState("Ctrl"))
    {
        allCCLAbel := allCCLAbel . "Ctrl"
        altLabel := altLabel . "Ctrl"
    }
    If IsLabel( altLabel )
    {
        event.intercepted := True
        Gosub %altLabel%
    }
    If(!event.intercepted && IsLabel( allCCLAbel ))
    {
        Gosub %allCCLAbel%
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


TransformMidiNoteNumber(originalNoteNumber)
{
    noteNumber := octaveShift * MIDI_NOTE_SIZE + originalNoteNumber
    If (!autoScaleOff)
    {
        noteScaleNumber := Mod( noteNumber, MIDI_NOTE_SIZE )
        noteNumber := noteNumber + SCALE_SHIFTS[autoScale][noteScaleNumber + 1]

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
    noteOnLabel := "AMTMidiNoteOn"
    altLabel := noteOnLabel . event.noteNumber
    noteNameLabel := noteOnLabel . event.noteName
    If (GetKeyState("Ctrl"))
    {
        noteOnLabel := noteOnLabel . "Ctrl"
        altLabel := altLabel . "Ctrl"
        noteNameLabel := noteNameLabel . "Ctrl"
    }
    If IsLabel( altLabel )
    {
        event.intercepted := True
        Gosub %altLabel%
    }
    else If IsLabel( noteNameLabel )
    {
        event.intercepted := True
        Gosub %noteNameLabel%
    }
    If (!event.intercepted && IsLabel( noteOnLabel ))
    {
        Gosub %noteOnLabel%
    }
    If (!event.intercepted){
        TryBlackKeyChord(event, True)
    }
    If (!event.intercepted)
    {
        ; MsgBox %event.velocity%
        If (fixedVelocity > 0 && fixedVelocity < 128)
        {
            newVel := fixedVelocity
        }else{
            newVel := event.velocity
        }
        newNum := TransformMidiNoteNumber(event.noteNumber)
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
        event.intercepted := True
        Gosub %altLabel%
    }
    else If IsLabel( "AMTMidiNoteOff" . event.noteName )
    {
        altLabel := "AMTMidiNoteOff" . event.noteName
        event.intercepted := True
        Gosub %altLabel%
    }
    If (!event.intercepted){
        TryBlackKeyChord(event, False)
    }
    If (!event.intercepted && IsLabel( "AMTMidiNoteOff" ))
    {
        ;ラベルが存在しないと直接指定できないので変数に入れる
        altLabel := "AMTMidiNoteOff"
        Gosub %altLabel%
    }
    If (!event.intercepted)
    {
        noteNumber := TransformMidiNoteNumber(event.noteNumber)
        Midi.MidiOut("N0", 1, noteNumber, event.velocity)
    }
Return

; 黒鍵でコードを弾く
TryBlackKeyChord(event, isNoteOn)
{
    If (!blackKeyChordEnabled)
    {
        Return
    }
    If (InStr(event.note, "#") == 0){
        Return
    }
    rootKey := ((blackKeyChordRootKey + 2) * 12) + 1
    rootPitch := ((blackKeyChordRootPitch + 2) * 12)
    ;ルートのC#からの差分を求め
    diff := event.noteNumber - rootKey
    if(diff == 0)
    {
        key := 0
    }
    ;黒鍵の差分　  -17 -15 -12|-10 -7 -5 -3  0  2  5  7  9|12 14 17
    ;鳴らしたい音  -12|-10 -8  -7  -5 -3 -1  0  2  4  5  7  9 11|12
    else if(diff > 0)
    {
        ;何番目の黒鍵なのか調べる
        num := Floor(Mod(diff, 12)/2) + Floor(diff/12)*5
        ;スケール内でその順番にあるノートを調べる
        keys := [0,2,4,5,7,9,11]
        key := keys[Mod(num, 7) + 1]
        if(num>=7){
            key := key + (Floor(num/7))*12
        }
    }
    else
    {
        diff := Abs(diff)
        mod := Mod(diff, 12)
        num := Floor((mod==0 ? 0 : mod-1)/2) + Floor(diff/12)*5
        keys := [0,1,3,5,7,8,10]
        key := keys[Mod(num, 7) + 1]
        if(num>=7){
            key := key + (Floor(num/7))*12
        }
        key := -key
    }
    
    MidiOutChord(key + rootPitch, event.velocity, isNoteOn)
    event.intercepted := True
    ; if(isNoteOn){
    ;     ShowMessagePanel(num . ":" . key, "test")
    ; }
} 

; コードCルートのノートを渡すとAutoScale考慮してコードを鳴らす
MidiOutChord(noteNumber, vel, isNoteOn = True)
{
    If (fixedVelocity > 0 && fixedVelocity < 128)
    {
        newVel := fixedVelocity
    }else{
        newVel := vel
    }
    If (isNoteOn){
        MidiStatus :=  143 + 1
    }else{
        MidiStatus :=  127 + 1
    }

    keys := SCALE_KEYS[autoScale]
    ; Cにする
    diff := Mod(noteNumber, 12)
    diff2 := 0
    For, i, key In MAJOR_KEYS
    {
        if(diff<=key){
            diff2 := i-1
            Break
        }
    }
    
    noteNumber := noteNumber - diff
    noteNumber := TransformMidiNoteNumber(noteNumber)
    ; 度数
    if(VOICING_CHORDS[chordVoicing].length()>=7){
        chord := VOICING_CHORDS[chordVoicing][diff2+1]
    }else{
        chord := VOICING_CHORDS[chordVoicing][1]
    }
    ;chord := [1,5,8]
    For i, chordNote In chord
    {
        ; For, j, key In MAJOR_KEYS
        ; {
        ;     if(chordNote<=key){
        ;         chordNote := j-1
        ;         Break
        ;     }
        ; }
        octave := 0
        tone := 0
        StringReplace, chordNote, chordNote, ! , , All 
        If (ErrorLevel == 0){
            octave := -1
        }
        StringReplace, chordNote, chordNote, # , , All 
        If (ErrorLevel == 0){
            tone += 1
        }
        StringReplace, chordNote, chordNote, b , , All 
        If (ErrorLevel == 0){
            tone -= 1
        }
        chordNote += diff2 -1
        val1 := Mod(chordNote, 7)+1
        diff3 := Floor(chordNote/7)*12
        shft := keys[val1]

        note := noteNumber + shft + diff3 + (octave * 12) + tone

        dwMidi := MidiStatus + ((note) << 8) + (newVel << 16)
        midi.MidiOutRawData(dwMidi)
    }
}

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

    ShowMessagePanel(fixedVelocity, "Fixed Velocity")
    updateSettingWindow()
}

SetAutoScale(key, scale, showPanel = False)
{
    autoScaleKey := key
    autoScale := scale
    UpdateSettingWindow()
    If (showPanel){
        str := MIDI_NOTES[key] . " " . MIDI_SCALES_S[scale]
        ShowMessagePanel(str, "Auto Scale")
    }
}

IncreaseOctaveShift(num, showPanel = False)
{
    SetOctaveShift(octaveShift + num, showPanel)
    If (showPanel){
        str := octaveShift
        ShowMessagePanel(str, "Octave Shift")
    }}

SetOctaveShift(octv, showPanel = False)
{
    If (octv < -4)
    {
        octv := -4
    }
    else If (octv > 4)
    {
        octv := 4
    }
    octaveShift := octv
    UpdateSettingWindow()
    If (showPanel){
        str := octaveShift
        ShowMessagePanel(str, "Octave Shift")
    }
}

SetChordInBlackKey(isEnabled, rootKey, rootPitch)
{
    blackKeyChordEnabled := isEnabled
    blackKeyChordRootKey := rootKey
    blackKeyChordRootPitch := rootPitch
    updateSettingWindow()
}

SetChordInBlackKeyEnabled(isEnabled, showPanel = False)
{
    blackKeyChordEnabled := (isEnabled ? 1:0)
    updateSettingWindow()
    If (showPanel){
        str := "CBK:" . (blackKeyChordEnabled ? "ON":"OFF")
        ShowMessagePanel(str, "ChordInBlackKey")
    }
}
SetChordInBlackKeyRootKey(rootKey)
{
    blackKeyChordRootKey := rootKey
    updateSettingWindow()
}
SetChordInBlackKeyRootPitch(rootPitch)
{
    blackKeyChordRootPitch := rootPitch
    updateSettingWindow()
}

AddVoicing(name, voicing)
{
    VOICING_NAMES.Push(name)
    VOICING_CHORDS.Push(voicing)
    voicingsList := ""
    For Key, Value in VOICING_NAMES
    {
        voicingsList .= "|" . Value 
    }
    GuiControl, 7:, SVoicong, %voicingsList%

}

SetVoicing(num)
{
    chordVoicing := num
    updateSettingWindow()
}

; 設定ウィンドウ

global SFVSlidr
global SFVTxt
global SScaleKey
global SScale
global SLogTxt
global SOctv
global SBKCEnabled
global SBKCRoot
global SBKCPitch
global SVoicong
InitSettingGui(){
    voicingsList := ""
    For Key, Value in VOICING_NAMES
    {
        voicingsList .= Value . "|"
    }
    Gui 7: -MinimizeBox -MaximizeBox
    Gui 7: Font, s12, Segoe UI
    Gui 7: Add, Text, x0 y16 w110 h30 +0x200 Right, Fixed Velocity:
    Gui 7: Add, Slider, vSFVSlidr gSlidrChanged x120 y16 w230 h32 +NoTicks +Center Range0-127, %fixedVelocity%
    Gui 7: Add, Text, vSFVTxt x380 y16 w53 h30 +0x200, %fixedVelocity%

    Gui 7: Add, Text, x0 y64 w110 h30 +0x200 Right, Auto Scale:
    Gui 7: Add, DropDownList, vSScaleKey gSScaleKeyChanged AltSubmit x120 y64 w78, C|C#/Db|D|D#/Eb|E|F|F#/Gb|G|G#/Ab|A|A#/Bb|B
    Gui 7: Add, DropDownList, vSScale gSScaleChanged AltSubmit x208 y64 w90, Major|Minor|H-Minor|M-Minor
    Gui 7: Add, Text, x302 y64 w64 h30 +0x200 +Right, Octave:
    Gui 7: Add, DropDownList, vSOctv gOctvChanged x374 y64 w50, -4|-3|-2|-1|0|1|2|3|4

    Gui 7: Add, CheckBox, vSBKCEnabled gBKCChanged x16 y110 w156 h30, Chord in Black Key
    Gui 7: Add, Text, x176 y110 w68 h30 +0x200 +Right, Root C#:
    Gui 7: Add, DropDownList, vSBKCRoot gBKCChanged x248 y110 w50, 0|1|2|3|4|5
    Gui 7: Add, Text, x312 y110 w50 h30 +0x200 +Right, Pitch:
    Gui 7: Add, DropDownList, vSBKCPitch gBKCChanged x370 y110 w50, 0|1|2|3|4|5

    Gui 7: Add, Text, x200 y144 w106 h30 +0x200 +Right, Chord Voicong:
    Gui 7: Add, DropDownList, vSVoicong gVoicongChanged AltSubmit x320 y144 w110, %voicingsList%

    Gui 7: Add, Text,vSLogTxt x16 y190 w380 h26 +0x200,
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
    Gui 7: Show, w440 h220, AHK-MIDI-Transformer Setting
    Return
}

UpdateSettingWindow()
{
    GuiControl , 7:, SFVSlidr, %fixedVelocity%
    GuiControl , 7:Text, SFVTxt, %fixedVelocity%
    GuiControl, 7:Choose, SScaleKey, %autoScaleKey%
    GuiControl, 7:Choose, SScale, %autoScale%
    GuiControl, 7:ChooseString, SOctv, %octaveShift%
    GuiControl, 7:, SBKCEnabled, %blackKeyChordEnabled%
    GuiControl, 7:ChooseString, SBKCRoot, %blackKeyChordRootKey%
    GuiControl, 7:ChooseString, SBKCPitch, %blackKeyChordRootPitch%
    GuiControl, 7:Choose, SVoicong, %chordVoicing%

}

SScaleKeyChanged:
    GuiControlGet, outputVar, 7:, SScaleKey
    autoScaleKey := outputVar
    SendAllNoteOff()
Return

SScaleChanged:
    GuiControlGet, outputVar, 7:, SScale
    autoScale := outputVar
    SendAllNoteOff()
Return

OctvChanged:
    GuiControlGet, outputVar, 7:, SOctv
    octaveShift := outputVar
    SendAllNoteOff()
Return

BKCChanged:
    GuiControlGet, outputVar, 7:, SBKCEnabled
    blackKeyChordEnabled := outputVar
    GuiControlGet, outputVar, 7:, SBKCRoot
    blackKeyChordRootKey := outputVar
    GuiControlGet, outputVar, 7:, SBKCPitch
    blackKeyChordRootPitch := outputVar
    SendAllNoteOff()
Return

VoicongChanged:
    GuiControlGet, outputVar, 7:, SVoicong
    chordVoicing := outputVar
    SendAllNoteOff()
Return
; 設定ウィンドウのスライダーが動いたら
SlidrChanged:
    GuiControlGet, outputVar, 7:, SFVSlidr
    fixedVelocity := outputVar
    updateSettingWindow()
    ; GuiControl, 7:Text, SFVTxt, %fixedVelocity%
    SendAllNoteOff()
Return


; メッセージパネル
global MsgTxt

InitSettingMessageGui()
{
    Gui 9:-MinimizeBox -MaximizeBox
    Gui 9:Font, s60
    Gui 9:Add, Text, vMsgTxt x0 y16 w360 h62 +0x200 Center, %fixedVelocity%
    Gui 9:Font
}

; Esc押したら閉じる
9GuiEscape:
    Gui ,9: Cancel
Return

ShowMessagePanel(txt, title = "Message")
{
    GuiControl, 9:Text, MsgTxt, %txt%
    Gui 9:Show, w360 h100, %title%
    SetTimer, HideSettingCCFV, 1000
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
    blackKeyChordEnabled :=LoadSettingValue("blackKeyChordEnabled", blackKeyChordEnabled)
    blackKeyChordRootKey :=LoadSettingValue("blackKeyChordRootKey", blackKeyChordRootKey)
    blackKeyChordRootPitch :=LoadSettingValue("blackKeyChordRootPitch", blackKeyChordRootPitch)
    chordVoicing :=LoadSettingValue("chordVoicing", chordVoicing)

    If (VOICING_CHORDS.length() < chordVoicing){
        chordVoicing := 1
    }
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
    SaveSettingValue("blackKeyChordEnabled", blackKeyChordEnabled)
    SaveSettingValue("blackKeyChordRootKey", blackKeyChordRootKey)
    SaveSettingValue("blackKeyChordRootPitch", blackKeyChordRootPitch)
    SaveSettingValue("chordVoicing", chordVoicing)
    ; IniWrite, %fixedVelocity%, %settingFilePath%, mySettings, fixedVelocity
}

ExitSub:
    SaveSetting()
    midi.SaveIOSetting(settingFilePath)
ExitApp
