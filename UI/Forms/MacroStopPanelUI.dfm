object MacroStopPanel: TMacroStopPanel
  Left = 0
  Top = 0
  BorderIcons = []
  BorderStyle = bsSingle
  Caption = 'MacroStopPanel'
  ClientHeight = 80
  ClientWidth = 300
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  Position = poDesigned
  PixelsPerInch = 96
  TextHeight = 15
  object lblInfo: TLabel
    Left = 12
    Top = 12
    Width = 276
    Height = 30
    AutoSize = False
    WordWrap = True
  end
  object btnStop: TButton
    Left = 198
    Top = 46
    Width = 90
    Height = 28
    Caption = 'Stop'
    TabOrder = 0
    OnClick = btnStopClick
  end
  object tmTopMost: TTimer
    Interval = 200
    OnTimer = tmTopMostTimer
    Left = 8
    Top = 44
  end
end
