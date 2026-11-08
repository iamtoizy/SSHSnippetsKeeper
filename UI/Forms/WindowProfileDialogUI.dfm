object WindowProfileDialog: TWindowProfileDialog
  Left = 0
  Top = 0
  BorderStyle = bsDialog
  Caption = ''
  ClientHeight = 296
  ClientWidth = 460
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  Position = poScreenCenter
  TextHeight = 15
  object lblAppName: TLabel
    Left = 12
    Top = 12
    Width = 60
    Height = 15
    Caption = 'lblAppName'
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clWindowText
    Font.Height = -12
    Font.Name = 'Segoe UI'
    Font.Style = [fsBold]
    ParentFont = False
  end
  object leInclude: TLabeledEdit
    Left = 12
    Top = 56
    Width = 436
    Height = 23
    EditLabel.Width = 220
    EditLabel.Height = 15
    EditLabel.Caption = 'Include'
    LabelPosition = lpAbove
    TabOrder = 0
  end
  object leExclude: TLabeledEdit
    Left = 12
    Top = 108
    Width = 436
    Height = 23
    EditLabel.Width = 180
    EditLabel.Height = 15
    EditLabel.Caption = 'Exclude'
    LabelPosition = lpAbove
    TabOrder = 1
  end
  object leClasses: TLabeledEdit
    Left = 12
    Top = 160
    Width = 436
    Height = 23
    EditLabel.Width = 240
    EditLabel.Height = 15
    EditLabel.Caption = 'Classes'
    LabelPosition = lpAbove
    TabOrder = 2
  end
  object lbHint: TLabel
    Left = 12
    Top = 200
    Width = 436
    Height = 45
    AutoSize = False
    Caption = ''
    WordWrap = True
  end
  object pBottom: TPanel
    Left = 0
    Top = 255
    Width = 460
    Height = 41
    Align = alBottom
    BevelOuter = bvNone
    TabOrder = 3
    object bOK: TButton
      Left = 3
      Top = 8
      Width = 110
      Height = 25
      Caption = 'OK'
      Default = True
      TabOrder = 0
      OnClick = bOKClick
    end
    object bCancel: TButton
      Left = 119
      Top = 8
      Width = 110
      Height = 25
      Cancel = True
      Caption = #1054#1090#1084#1077#1085#1072
      ModalResult = 2
      TabOrder = 1
    end
  end
end
