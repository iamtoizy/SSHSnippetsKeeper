object CustomHelpForm: TCustomHelpForm
  Left = 0
  Top = 0
  BorderStyle = bsSizeable
  Caption = #1057#1087#1088#1072#1074#1086#1095#1085#1072#1103' '#1080#1085#1092#1086#1088#1084#1072#1094#1080#1103
  ClientHeight = 372
  ClientWidth = 460
  Color = clBtnFace
  Constraints.MinHeight = 260
  Constraints.MinWidth = 400
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  KeyPreview = True
  Position = poMainFormCenter
  OnCreate = FormCreate
  OnKeyDown = FormKeyDown
  OnShow = FormShow
  TextHeight = 15
  object pBottom: TPanel
    Left = 0
    Top = 339
    Width = 460
    Height = 33
    Align = alBottom
    BevelOuter = bvNone
    TabOrder = 0
    object bCopyText: TButton
      Left = 3
      Top = 5
      Width = 140
      Height = 25
      Caption = 'Copy text'
      TabOrder = 0
      OnClick = bCopyTextClick
    end
  end
end
