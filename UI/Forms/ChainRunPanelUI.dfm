object ChainRunPanel: TChainRunPanel
  Left = 0
  Top = 0
  BorderIcons = [biSystemMenu]
  BorderStyle = bsSingle
  Caption = 'ChainRunPanel'
  ClientHeight = 96
  ClientWidth = 380
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  FormStyle = fsStayOnTop
  KeyPreview = True
  Position = poDesigned
  OnKeyDown = FormKeyDown
  PixelsPerInch = 96
  TextHeight = 15
  object lblProgress: TLabel
    Left = 12
    Top = 12
    Width = 356
    Height = 44
    AutoSize = False
    WordWrap = True
  end
  object btnStop: TButton
    Left = 278
    Top = 60
    Width = 90
    Height = 28
    Cancel = True
    Caption = 'Stop'
    TabOrder = 0
    OnClick = btnStopClick
  end
end
