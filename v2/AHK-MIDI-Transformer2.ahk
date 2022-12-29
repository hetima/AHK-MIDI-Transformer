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


#Warn  ; Enable warnings to assist with detecting common errors.
;SendMode Input  ; Recommended for new scripts due to its superior speed and reliability.

; 設定ファイルのパス
Global settingFilePath
if(!IsSet(settingFilePath)){
    settingFilePath := A_ScriptDir . "\AHK-MIDI-Transformer2.ini"
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

; Chord In White Key
Global whiteKeyChordEnabled := 0

; オートスケール
Global autoScaleKey := 1 ;1==C ~ 12==B
Global autoScale := 1 ;1==Major 2==Minor 3==H-Minor 4==M-Minor
Global octaveShift := 0
; 一時的にオフにするとき用
Global autoScaleOff := False

Global MIDI_NOTE_SIZE := 12
Global MIDI_NOTES     := [ "C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B" ]
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

; このファイルと同じ階層にある Midi2.ahk を読み込む
#include %A_LineFile%\..\Midi2.ahk
Global midi := AHKMidi()
Global midiTransformer := AHKMT()
OnExit ExitFunc

midi.LoadIOSetting(settingFilePath)
LoadSetting()
A_TrayMenu.Add()
A_TrayMenu.Add("Setting", ShowSetting)
midi.midiEventPassThrough := True
midi.delegate := midiTransformer


global __pid := ProcessExist()
; 必須初期化おわり

If (FileExist(A_LineFile . "\..\icon.ico")){
    TraySetIcon(A_LineFile . "\..\icon.ico")
}

finishLaunching := "AMTFinishLaunching"
If (IsLabel(finishLaunching)){
    ;Gosub, %finishLaunching%
}

; 初期化おわり


; オールノートオフを送信する
SendAllNoteOff(ch := 1)
{
    dwMidi := (176+ch) + (123 << 8) + (0 << 16)
    midi.MidiOutRawData(dwMidi)
}

SendAllSoundOff(ch := 1)
{
    dwMidi := (176+ch) + (120 << 8) + (0 << 16)
    midi.MidiOutRawData(dwMidi)
}

SendResetAllController(ch := 1)
{
    dwMidi := (176+ch) + (121 << 8) + (0 << 16)
    midi.MidiOutRawData(dwMidi)
}

;;;;;;;;;; transform ;;;;;;;;;;

Class AHKMT
{
    delegate := False
    specificProcessCallback := False

    __New()
    {
        AHKMT.InitSettingGui()
        AHKMT.InitSettingMessageGui()
    }

    ; CC
    MidiControlChange(event)
    {
        ;event := midi.MidiIn()
        event.eventHandled := False
        allCCLAbel := "AMTMidiControlChange"
        altLabel := allCCLAbel . event.controller

        If ( this.specificProcessCallback ){
            processPrefix := __GetProcessLabel()
        }else{
            processPrefix := False
        }
        If (GetKeyState("Ctrl"))
        {
            allCCLAbel := allCCLAbel . "Ctrl"
            altLabel := altLabel . "Ctrl"
        }
        If ( processPrefix ){
            processLabel := processPrefix . altLabel
            If ( HasMethod(this.delegate, processLabel, 1) )
            {
                event.eventHandled := True
                this.delegate.%processLabel%(event)
            }
            processLabel := processPrefix . allCCLAbel
            If (!event.eventHandled && HasMethod(this.delegate, processLabel, 1) )
            {
                event.eventHandled := True
                this.delegate.%processLabel%(event)
            } 
        }

        If (!event.eventHandled && HasMethod(this.delegate, altLabel, 1))
        {
            event.eventHandled := True
            this.delegate.%altLabel%(event)
            ;Gosub %altLabel%
        }
        If (!event.eventHandled && HasMethod(this.delegate, allCCLAbel, 1))
        {
            this.delegate.%allCCLAbel%(event)
            ;Gosub %allCCLAbel%
        }

        If (!event.eventHandled){
            cc := event.controller
            If (cc == fixedVelocityCC)
            {
                SetFixedVelocityFromCC(event)
            }else{
                midi.MidiOutRawData(event.rawBytes)
            }
        }

        ;設定ウィンドウがアクティブなら情報表示
        if(AHKMT.IsSettingWindowVisible())
        {
            If (!event.eventHandled)
            {
                logTxt := "CC:" event.controller . " (" . event.value . ")"
            }
            else
            {
                logTxt := "CC:" event.controller . " (" . event.value . ")  -> intercepted"
            }
            AHKMT.SLogTxt.Text := logTxt
        }
        event.eventHandled := True
    }

    
    ; fixed velocity
    MidiNoteOn(event)
    {
        ;event := midi.MidiIn()
        event.eventHandled := False
        noteOnLabel := "AMTMidiNoteOn"
        altLabel := noteOnLabel . event.noteNumber
        noteNameLabel := noteOnLabel . event.noteName
        newNum := 0
        If ( this.specificProcessCallback ){
            processPrefix := __GetProcessLabel()
        }else{
            processPrefix := False
        }
        If (GetKeyState("Ctrl"))
        {
            noteOnLabel := noteOnLabel . "Ctrl"
            altLabel := altLabel . "Ctrl"
            noteNameLabel := noteNameLabel . "Ctrl"
        }

        If ( processPrefix ){
            processLabel := processPrefix . altLabel
            If ( HasMethod(this.delegate, processLabel, 1) )
            {
                event.eventHandled := True
                this.delegate.%processLabel%(event)
            }
            processLabel := processPrefix . noteNameLabel
            If (!event.eventHandled &&  HasMethod(this.delegate, processLabel, 1) )
            {
                event.eventHandled := True
                this.delegate.%processLabel%(event)
            }
            processLabel := processPrefix . noteOnLabel
            If (!event.eventHandled &&  HasMethod(this.delegate, processLabel, 1) )
            {
                event.eventHandled := True
                this.delegate.%processLabel%(event)
            }
        }

        If (!event.eventHandled && HasMethod(this.delegate, altLabel, 1))
        {
            event.eventHandled := True
            this.delegate.%altLabel%(event)
            ;Gosub %altLabel%
        }
        If (!event.eventHandled && HasMethod(this.delegate, noteNameLabel, 1))
        {
            event.eventHandled := True
            this.delegate.%noteNameLabel%(event)
            ;Gosub %noteNameLabel%
        }


        If (!event.eventHandled && HasMethod(this.delegate, noteOnLabel, 1))
        {
            ;event.eventHandled := True
            this.delegate.%noteOnLabel%(event)
            ;Gosub %noteOnLabel%
        }
        ; If (!event.eventHandled)
        ; {
        ;     TryBlackKeyChord(event, True)
        ; }
        If (!event.eventHandled)
        {
            TryWhiteKeyChord(event, True)
        }
        If (!event.eventHandled)
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
        if( AHKMT.IsSettingWindowVisible() )
        {
            If (!event.eventHandled)
            {
                ; Determine the octave of the note in the scale 
                ;noteOctaveNumber := Floor( event.noteNumber / MIDI_NOTE_SIZE )
                ; Create a friendly name for the note and octave, ie: "C4"
                newNoteName := MIDI_NOTES[ Mod( newNum, MIDI_NOTE_SIZE ) + 1 ] . AHKMidi.MIDI_OCTAVES[ Floor( newNum / MIDI_NOTE_SIZE ) + 1 ]
                logTxt := event.noteNumber . " (" . event.noteName . ") vel:" . event.velocity . " -> " . newNum . " (" . newNoteName . ") vel:" . newVel
            }
            else
            {
                logTxt := event.noteNumber . " (" . event.noteName . ") vel:" . event.velocity . " -> intercepted"
            }
            AHKMT.SLogTxt.Text := logTxt
        }
        event.eventHandled := True
    }

    MidiNoteOff(event)
    {
        ;event := midi.MidiIn()
        event.eventHandled := False
        noteOffLabel := "AMTMidiNoteOff"
        altLabel := noteOffLabel . event.noteNumber
        noteNameLabel := noteOffLabel . event.noteName
        If ( this.specificProcessCallback ){
            processPrefix := __GetProcessLabel()
        }else{
            processPrefix := False
        }

        If ( processPrefix ){
            processLabel := processPrefix . altLabel
            If ( HasMethod(this.delegate, processLabel, 1) )
            {
                event.eventHandled := True
                this.delegate.%processLabel%(event)
            }
            processLabel := processPrefix . noteNameLabel
            If (!event.eventHandled &&  HasMethod(this.delegate, processLabel, 1) )
            {
                event.eventHandled := True
                this.delegate.%processLabel%(event)
            }
            processLabel := processPrefix . noteOffLabel
            If (!event.eventHandled &&  HasMethod(this.delegate, processLabel, 1) )
            {
                event.eventHandled := True
                this.delegate.%processLabel%(event)
            }
        }

        If (!event.eventHandled && HasMethod(this.delegate, altLabel, 1))
        {
            event.eventHandled := True
            this.delegate.%altLabel%(event)
            ;Gosub %altLabel%
        }
        If (!event.eventHandled && HasMethod(this.delegate, noteNameLabel, 1))
        {
            event.eventHandled := True
            this.delegate.%noteNameLabel%(event)
            ;Gosub %noteNameLabel%
        }

        If (!event.eventHandled && HasMethod(this.delegate, noteOffLabel, 1))
        {
            ;event.eventHandled := True
            this.delegate.%noteOffLabel%(event)
            ;Gosub %noteOffLabel%
        }

        ; If (!event.eventHandled)
        ; {
        ;     TryBlackKeyChord(event, False)
        ; }
        If (!event.eventHandled)
        {
            TryWhiteKeyChord(event, False)
        }
        ; If (!event.eventHandled && HasMethod(this.delegate, noteOffLabel , 1))
        ; {
        ;     ;event.eventHandled := True
        ;     this.delegate.%noteOffLabel%(event)
        ;     ;Gosub %altLabel%
        ; }
        If (!event.eventHandled)
        {
            noteNumber := TransformMidiNoteNumber(event.noteNumber)
            Midi.MidiOut("N0", 1, noteNumber, event.velocity)
        }
        event.eventHandled := True
    }

    static settingGui := False
    static SFVSlidr := False
    static SFVTxt := False
    static SScaleKey := False
    static SScale := False
    static SLogTxt := False
    static SOctv := False
    static SBKCEnabled := False
    static SWKCEnabled := False
    static SBKCRoot := False
    static SBKCPitch := False
    static SVoicing := False

    static InitSettingGui(){
        AHKMT.settingGui := Gui("", "AHK-MIDI-Transformer Setting")
        AHKMT.settingGui.OnEvent("Escape", GuiEscape)
        
        voicingsList := []
        For Key, Value in VOICING_NAMES
        {
            voicingsList.Push(Value)
        }
        ;Gui 7: -MinimizeBox -MaximizeBox
        AHKMT.settingGui.SetFont("s12", "Segoe UI")

        AHKMT.settingGui.Add("Text", "x0 y16 w110 h30 +0x200 Right", "Fixed Velocity:")
        AHKMT.SFVSlidr := AHKMT.settingGui.Add("Slider", "x120 y16 w230 h32 +NoTicks +Center Range0-127", fixedVelocity)
        AHKMT.SFVSlidr.OnEvent("Change", SlidrChanged)
        ;Gui 7: Add, Slider, vSFVSlidr gSlidrChanged x120 y16 w230 h32 +NoTicks +Center Range0-127, %fixedVelocity%
        
        AHKMT.SFVTxt := AHKMT.settingGui.Add("Text", "vSFVTxt x380 y16 w53 h30 +0x200", fixedVelocity)
        ;Gui 7: Add, Text, vSFVTxt x380 y16 w53 h30 +0x200, %fixedVelocity%

        AHKMT.settingGui.Add("Text", "x0 y64 w110 h30 +0x200 Right", "Auto Scale:")
        AHKMT.SScaleKey :=AHKMT.settingGui.Add("DropDownList", "AltSubmit x120 y64 w78", ["C","C#/Db","D","D#/Eb","E","F","F#/Gb","G","G#/Ab","A","A#/Bb","B"])
        AHKMT.SScaleKey.OnEvent("Change", SScaleKeyChanged) 

        AHKMT.SScale :=AHKMT.settingGui.Add("DropDownList", "AltSubmit x208 y64 w90", ["Major","Minor","H-Minor","M-Minor"])
        AHKMT.SScale.OnEvent("Change", SScaleChanged)
        AHKMT.settingGui.Add("Text", "x302 y64 w64 h30 +0x200 +Right", "Octave:")
        
        AHKMT.SOctv :=AHKMT.settingGui.Add("DropDownList", "x374 y64 w50", ["-4","-3","-2","-1","0","1","2","3","4"])
        AHKMT.SOctv.OnEvent("Change", OctvChanged)

        ; AHKMT.SBKCEnabled :=AHKMT.settingGui.Add("CheckBox", "x16 y142 w156 h30", "Chord in Black Key")
        ; AHKMT.SBKCEnabled.OnEvent("Click", BKCChanged)

        ; AHKMT.settingGui.Add("Text", "x176 y142 w68 h30 +0x200 +Right", "Root C#:")
        ; AHKMT.SBKCRoot :=AHKMT.settingGui.Add("DropDownList", "x248 y142 w50", ["0","1","2","3","4","5"])
        ; AHKMT.SBKCRoot.OnEvent("Change", BKCChanged)

        ; AHKMT.settingGui.Add("Text", "x312 y142 w50 h30 +0x200 +Right", "Pitch:")
        ; AHKMT.SBKCPitch :=AHKMT.settingGui.Add("DropDownList", "x370 y142 w50", ["0","1","2","3","4","5"])
        ; AHKMT.SBKCPitch.OnEvent("Change", BKCChanged)

        AHKMT.SWKCEnabled :=AHKMT.settingGui.Add("CheckBox", "x16 y104 w160 h34", "Chord in White Key")
        AHKMT.SWKCEnabled.OnEvent("Click", WKCChanged)

        AHKMT.settingGui.Add("Text", "x230 y104 w76 h30 +0x200 +Right", "Voicing:")

        AHKMT.SVoicing :=AHKMT.settingGui.Add("DropDownList", "AltSubmit x320 y104 w110", voicingsList)
        AHKMT.SVoicing.OnEvent("Change", VoicingChanged)

        AHKMT.SLogTxt :=AHKMT.settingGui.Add("Text", "vSLogTxt x16 y190 w380 h26 +0x200", "")
        ;Gui 7: Font
    }
    static messagePanelGui := false

    static MsgTxt := false

    static InitSettingMessageGui()
    {
        AHKMT.messagePanelGui := Gui("", "message")
        AHKMT.messagePanelGui.OnEvent("Escape", GuiEscape)

        ;AHKMT.messagePanelGui
        ;Gui 9:-MinimizeBox -MaximizeBox
        AHKMT.messagePanelGui.SetFont("s60")
        ;Gui 9:Font, s60
        AHKMT.MsgTxt :=AHKMT.messagePanelGui.Add("Text", "x0 y16 w360 h62 +0x200 Center", fixedVelocity)
        ;Gui 9:Font
    }

    static IsSettingWindowVisible()
    {
        styl := WinGetStyle(AHKMT.settingGui.Hwnd)
        if (styl & 0x10000000){
            return true
        }
        return false
    }

}



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


; 白鍵でコードを弾く Chord In White Key
TryWhiteKeyChord(event, isNoteOn)
{
    If (whiteKeyChordEnabled)
    {
        MidiOutChord(event.noteNumber, event.velocity, isNoteOn)
        event.eventHandled := True
    }
}

; 黒鍵でコードを弾く Chord In Black Key
TryBlackKeyChord(event, isNoteOn)
{
    If (!blackKeyChordEnabled)
    {
        Return
    }
    If (InStr(event.note, "s") == 0){
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
        modVal := Mod(diff, 12)
        num := Floor((modVal==0 ? 0 : modVal-1)/2) + Floor(diff/12)*5
        keys := [0,1,3,5,7,8,10]
        key := keys[Mod(num, 7) + 1]
        if(num>=7){
            key := key + (Floor(num/7))*12
        }
        key := -key
    }
    
    MidiOutChord(key + rootPitch, event.velocity, isNoteOn)
    event.eventHandled := True
    ; if(isNoteOn){
    ;     ShowMessagePanel(num . ":" . key, "test")
    ; }
} 

; コードCルートのノートを渡すとAutoScale考慮してコードを鳴らす
MidiOutChord(noteNumber, vel, isNoteOn := True)
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
    For i, key In MAJOR_KEYS
    {
        if(diff<=key){
            diff2 := i-1
            Break
        }
    }
    
    noteNumber := noteNumber - diff
    noteNumber := TransformMidiNoteNumber(noteNumber)
    ; 度数
    if(VOICING_CHORDS[chordVoicing].Length >= 7){
        chord := VOICING_CHORDS[chordVoicing][diff2+1]
        oneChord := False
    }else{
        chord := VOICING_CHORDS[chordVoicing][1]
        oneChord := True
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
        chordNote := StrReplace(chordNote, "!", "", , &cnt)
        ;StringReplace, chordNote, chordNote, ! , , All 
        If (cnt > 0){
            octave := -1
        }
        chordNote := StrReplace(chordNote, "#", "", , &cnt)
        ;StringReplace, chordNote, chordNote, # , , All 
        If (cnt > 0){
            tone += 1
        }
        chordNote := StrReplace(chordNote, "b", "", , &cnt)
        ;StringReplace, chordNote, chordNote, b , , All 
        If (cnt > 0){
            tone -= 1
        }
        if(oneChord){
            chordNote += diff2
        }
        chordNote -= 1
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
SetFixedVelocityFromCC(event)
{
    global fixedVelocity
    If (CCMode==0){
        fixedVelocity := event.value
    }else{
        step := 1
        If (fixedVelocity <= 100 && fixedVelocityCCStep > 0 && fixedVelocityCCStep < 20){
            step := fixedVelocityCCStep
        }
        fixedVelocity := fixedVelocity + (event.value - 64)*step
    }
    If (fixedVelocity > 127){
        fixedVelocity := 127
    }Else if(fixedVelocity < 0){
        fixedVelocity := 0
    }

    ShowMessagePanel(fixedVelocity, "Fixed Velocity")
    updateSettingWindow()
}

SetAutoScale(key, scale, showPanel := False)
{
    global autoScaleKey
    global autoScale
    autoScaleKey := key
    autoScale := scale
    UpdateSettingWindow()
    If (showPanel){
        str := MIDI_NOTES[key] . " " . MIDI_SCALES_S[scale]
        ShowMessagePanel(str, "Auto Scale")
    }
}

IncreaseOctaveShift(num, showPanel := False)
{
    SetOctaveShift(octaveShift + num, showPanel)
    If (showPanel){
        str := octaveShift
        ShowMessagePanel(str, "Octave Shift")
    }}

SetOctaveShift(octv, showPanel := False)
{
    global octaveShift
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
    global blackKeyChordEnabled
    global blackKeyChordRootKey
    global blackKeyChordRootPitch
    blackKeyChordEnabled := (isEnabled ? 1:0)
    blackKeyChordRootKey := rootKey
    blackKeyChordRootPitch := rootPitch
    updateSettingWindow()
    SendAllNoteOff()
}

SetChordInBlackKeyEnabled(isEnabled, showPanel := False)
{
    global blackKeyChordEnabled
    blackKeyChordEnabled := (isEnabled ? 1:0)
    updateSettingWindow()
    If (showPanel){
        str := "CBK:" . (blackKeyChordEnabled ? "ON":"OFF")
        ShowMessagePanel(str, "ChordInBlackKey")
    }
    SendAllNoteOff()
}
SetChordInBlackKeyRootKey(rootKey)
{
    global blackKeyChordRootKey
    blackKeyChordRootKey := rootKey
    updateSettingWindow()
    SendAllNoteOff()
}
SetChordInBlackKeyRootPitch(rootPitch)
{
    global blackKeyChordRootPitch
    blackKeyChordRootPitch := rootPitch
    updateSettingWindow()
    SendAllNoteOff()
}
SetChordInWhiteKeyEnabled(isEnabled, showPanel := False)
{
    global whiteKeyChordEnabled
    whiteKeyChordEnabled := (isEnabled ? 1:0)
    updateSettingWindow()
    If (showPanel){
        str := "CWK:" . (whiteKeyChordEnabled ? "ON":"OFF")
        ShowMessagePanel(str, "ChordInWhiteKey")
    }
    SendAllNoteOff()
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
    ;GuiControl, 7:, SVoicing, %voicingsList%
    AHKMT.SVoicing.Text := voicingsList
}

SetVoicing(num)
{
    global chordVoicing
    chordVoicing := num
    updateSettingWindow()
}

; 設定ウィンドウ



; Esc押したら閉じる
GuiEscape(GuiObj){
    GuiObj.Hide()
; Gui ,7: Cancel
}


; 設定ウィンドウを表示
ShowSetting(ItemName := False, ItemPos := False, MyMenu := False)
{
    updateSettingWindow()
    ;Gui 7: Show, w440 h220, AHK-MIDI-Transformer Setting
    AHKMT.settingGui.Show("w440 h220")
    Return
}

UpdateSettingWindow()
{
    ;AHKMT.settingGui
    AHKMT.SFVSlidr.Value := fixedVelocity ;GuiControl , 7:, SFVSlidr, %fixedVelocity%
    AHKMT.SFVTxt.Text := fixedVelocity ;GuiControl , 7:Text, SFVTxt, %fixedVelocity%
    AHKMT.SScaleKey.Choose(autoScaleKey) ;GuiControl, 7:Choose, SScaleKey, %autoScaleKey%
    AHKMT.SScale.Choose(autoScale) ;GuiControl, 7:Choose, SScale, %autoScale%
    AHKMT.SOctv.Choose(String(octaveShift)) ;GuiControl, 7:ChooseString, SOctv, %octaveShift%
    ; AHKMT.SBKCEnabled.Value := blackKeyChordEnabled ;GuiControl, 7:, SBKCEnabled, %blackKeyChordEnabled%
    ; AHKMT.SBKCRoot.Choose(String(blackKeyChordRootKey)) ;GuiControl, 7:ChooseString, SBKCRoot, %blackKeyChordRootKey%
    ; AHKMT.SBKCPitch.Choose(String(blackKeyChordRootPitch)) ;GuiControl, 7:ChooseString, SBKCPitch, %blackKeyChordRootPitch%
    AHKMT.SVoicing.Choose(chordVoicing) ;GuiControl, 7:Choose, SVoicing, %chordVoicing%
    AHKMT.SWKCEnabled.Value := whiteKeyChordEnabled ;GuiControl, 7:, SWKCEnabled, %whiteKeyChordEnabled%

}

SScaleKeyChanged(GuiCtrlObj, Info){
    global autoScaleKey
    ; GuiControlGet, outputVar, 7:, SScaleKey
    ; autoScaleKey := outputVar
    autoScaleKey := AHKMT.SScaleKey.Value
    SendAllNoteOff()
}

SScaleChanged(GuiCtrlObj, Info){
    global autoScale
    ;GuiControlGet, outputVar, 7:, SScale
    autoScale := GuiCtrlObj.Value
    SendAllNoteOff()
}

OctvChanged(GuiCtrlObj, Info){
    global octaveShift
    ;GuiControlGet, outputVar, 7:, SOctv
    octaveShift := AHKMT.SOctv.Text
    SendAllNoteOff()
}

; BKCChanged(GuiCtrlObj, Info){
;     global blackKeyChordEnabled
;     global blackKeyChordRootKey
;     global blackKeyChordRootPitch
;     ;GuiControlGet, outputVar, 7:, SBKCEnabled
;     blackKeyChordEnabled := AHKMT.SBKCEnabled.Value
;     ;GuiControlGet, outputVar, 7:, SBKCRoot
;     blackKeyChordRootKey :=  AHKMT.SBKCRoot.Text
;     ;GuiControlGet, outputVar, 7:, SBKCPitch
;     blackKeyChordRootPitch :=  AHKMT.SBKCPitch.Text
;     SendAllNoteOff()
; }

WKCChanged(GuiCtrlObj, Info){
    global whiteKeyChordEnabled
    ;GuiControlGet, outputVar, 7:, SWKCEnabled
    whiteKeyChordEnabled := AHKMT.SWKCEnabled.Value
    SendAllNoteOff()
}

VoicingChanged(GuiCtrlObj, Info){
    global chordVoicing
    ;GuiControlGet, outputVar, 7:, SVoicing
    chordVoicing := GuiCtrlObj.Value
    SendAllNoteOff()
}

; 設定ウィンドウのスライダーが動いたら
SlidrChanged(GuiCtrlObj, Info){
    global fixedVelocity
    ;GuiControlGet, outputVar, 7:, SFVSlidr
    fixedVelocity := GuiCtrlObj.Value
    updateSettingWindow()
    ;; GuiControl, 7:Text, SFVTxt, %fixedVelocity%
    SendAllNoteOff()
}


; メッセージパネル

; Esc押したら閉じる
; 9GuiEscape:
;     ; Gui ,9: Cancel
; Return

ShowMessagePanel(txt, title := "Message")
{
    ;GuiControl, 9:Text, MsgTxt, %txt%
    AHKMT.MsgTxt.Text := String(txt)
    ;Gui 9:Show, w360 h100, %title%
    AHKMT.messagePanelGui.Title := title
    AHKMT.messagePanelGui.Show("w360 h100")
    SetTimer HideSettingCCFV, -1000
}

HideSettingCCFV(){
    ;Gui 9:Hide
    AHKMT.messagePanelGui.Hide()
    SetTimer HideSettingCCFV, 0
}




; 設定読み込み/保存
LoadSettingValue(name, defaultVal)
{
    If (not FileExist(settingFilePath)){
      return defaultVal
    }
    try{
        result := IniRead(settingFilePath, "mySettings", name)
        If (result != "ERROR"){
            return result
        }
        return defaultVal
    }catch{
    }
    return defaultVal
}

LoadSetting()
{
    global fixedVelocity
    global fixedVelocityCC
    global fixedVelocityCCStep
    global CCMode
    global blackKeyChordEnabled
    global blackKeyChordRootKey
    global blackKeyChordRootPitch
    global chordVoicing
    fixedVelocity := Integer(LoadSettingValue("fixedVelocity", fixedVelocity))
    fixedVelocityCC := Integer(LoadSettingValue("fixedVelocityCC", fixedVelocityCC))
    fixedVelocityCCStep := Integer(LoadSettingValue("fixedVelocityCCStep", fixedVelocityCCStep))
    CCMode := Integer(LoadSettingValue("CCMode", CCMode))
    blackKeyChordEnabled := Integer(LoadSettingValue("blackKeyChordEnabled", blackKeyChordEnabled))
    blackKeyChordRootKey := Integer(LoadSettingValue("blackKeyChordRootKey", blackKeyChordRootKey))
    blackKeyChordRootPitch := Integer(LoadSettingValue("blackKeyChordRootPitch", blackKeyChordRootPitch))
    chordVoicing := Integer(LoadSettingValue("chordVoicing", chordVoicing))

    If (VOICING_CHORDS.Length < chordVoicing){
        ;chordVoicing := 1
    }
}

SaveSettingValue(name, val)
{
    IniWrite val, settingFilePath, "mySettings", name
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
    ; IniWrite fixedVelocity, settingFilePath, "mySettings", "fixedVelocity"
}

ExitFunc(ExitReason, ExitCode){
    SaveSetting()
    midi.SaveIOSetting(settingFilePath)
}
