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


; AHK-MIDI-Transformer が MidiNoteOn/MidiNoteOff ですべてのノートを処理しているため、個別のラベルを使うと両方実行されてしまう
; AMTMidiNoteOnノートナンバー:
; AMTMidiNoteOffノートナンバー:
; というラベルで受け取ることができる。C3などの文字ではなく数字なので注意。数字の確認はセッティングウィンドウを前面に出して鍵盤を押すと表示される
; このラベルが実行されると発音はされない

;左の黒鍵を押下してる間オクターブを下げる（KOMPLETE KONTROL M32）
AMTMidiNoteOn46:
	octaveShift := -1
Return
AMTMidiNoteOff46:
	octaveShift := 0
    SendAllNoteOff()
Return
AMTMidiNoteOn44:
	octaveShift := -2
Return
AMTMidiNoteOff44:
	octaveShift := 0
    SendAllNoteOff()
Return
AMTMidiNoteOn42:
	octaveShift := -3
    ;超低音域を鳴らすことはないし、キースイッチ系の領域なのでauto scaleはオフにする
    autoScaleOff := True
Return
AMTMidiNoteOff42:
	octaveShift := 0
    autoScaleOff := False
    SendAllNoteOff()
Return

;右の黒鍵を押下してる間オクターブを上げる（KOMPLETE KONTROL M32）
AMTMidiNoteOn66:
	octaveShift := 1
Return
AMTMidiNoteOff66:
	octaveShift := 0
    ;all note off
    SendAllNoteOff()
Return
AMTMidiNoteOn68:
	octaveShift := 2
Return
AMTMidiNoteOff68:
	octaveShift := 0
    SendAllNoteOff()
Return
AMTMidiNoteOn70:
	octaveShift := 3
    ;autoScaleOff := True
Return
AMTMidiNoteOff70:
	octaveShift := 0
    SendAllNoteOff()
Return

AMTMidiNoteOn:
    ;Ctrlを押しながら鍵盤を弾くとAutoScale設定を変更する
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
        setAutoScale(key + 1, scale, True)
    }
Return
