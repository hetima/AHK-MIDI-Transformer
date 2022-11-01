; AHK-MIDI-Transformer を拡張するサンプル
; このファイルを実行すれば AHK-MIDI-Transformer も読み込まれる

#NoEnv  ; Recommended for performance and compatibility with future AutoHotkey releases.
; #Warn  ; Enable warnings to assist with detecting common errors.
SendMode Input  ; Recommended for new scripts due to its superior speed and reliability.
SetWorkingDir %A_ScriptDir%  ; Ensures a consistent starting directory.

; AHK-MIDI-Transformer.ahk を読み込む前に Global settingFilePath を設定しておけば設定ファイルの場所を上書き可能
Global settingFilePath := A_ScriptDir . "\SampleExpansion.ini"
#include ./AHK-MIDI-Transformer.ahk



; 設定ウィンドウを出すショートカット
^+M::
    showSetting()
Return

; Ctrl + 鍵盤で Setting ウィンドウ表示
AMTMidiNoteOn42Ctrl:
    showSetting()
Return

;端の黒鍵を押下してる間オクターブを上げ下げ
AMTMidiNoteOn70:
    SendAllNoteOff()
	octaveShift -= 2
Return
AMTMidiNoteOff70:
	octaveShift += 2
    SendAllNoteOff()
Return
AMTMidiNoteOn42:
    SendAllNoteOff()
	octaveShift += 2
Return
AMTMidiNoteOff42:
	octaveShift -= 2
    SendAllNoteOff()
Return

; Ctrl + 鍵盤でオクターブシフト
AMTMidiNoteOn41Ctrl:
    ; シフトも押すとリセット
    If (GetKeyState("Shift")){
        SetOctaveShift(0, True)
    }else{
        IncreaseOctaveShift(-1, True)
    }
Return
AMTMidiNoteOn43Ctrl:
    ; シフトも押すとリセット
    If (GetKeyState("Shift")){
        SetOctaveShift(0, True)
    }else{
        IncreaseOctaveShift(1, True)
    }
Return

; Ctrl + 鍵盤で Chord In Black Key のオンオフ切り替え
AMTMidiNoteOn44Ctrl:
    SetChordInBlackKeyEnabled(blackKeyChordEnabled ? 0:1, True)
Return

;Ctrlを押しながら鍵盤を弾くとAutoScale設定を変更する
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
    setAutoScale(key + 1, scale, True)
Return
