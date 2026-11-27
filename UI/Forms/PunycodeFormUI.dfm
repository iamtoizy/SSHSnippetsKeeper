object PunycodeForm: TPunycodeForm
  Caption = 'Punycode'
  ClientHeight = 520
  ClientWidth = 680
  Constraints.MinHeight = 500
  Constraints.MinWidth = 590
  Position = poScreenCenter
  Font.Name = 'Segoe UI'
  Font.Height = -12
  KeyPreview = True
  OnKeyDown = FormKeyDown
  PixelsPerInch = 96
  object lblMode: TLabel
    Left = 12
    Top = 15
    Caption = 'Mode:'
    FocusControl = cbMode
  end
  object cbMode: TComboBox
    Left = 112
    Top = 11
    Width = 240
    Height = 23
    Style = csDropDownList
    TabOrder = 0
    OnChange = InputChanged
  end
  object lblInput: TLabel
    Left = 12
    Top = 45
    Caption = 'Input (one domain per line)'
    FocusControl = mInput
  end
  object mInput: TMemo
    Left = 12
    Top = 66
    Width = 656
    Height = 139
    Anchors = [akLeft, akTop, akRight]
    ScrollBars = ssBoth
    TabOrder = 1
    WordWrap = False
    OnChange = InputChanged
  end
  object lblResult: TLabel
    Left = 12
    Top = 218
    Caption = 'Successful results'
    FocusControl = mResult
  end
  object bCopy: TButton
    Left = 548
    Top = 211
    Width = 120
    Height = 25
    Anchors = [akTop, akRight]
    Caption = 'Copy results'
    Enabled = False
    TabOrder = 2
    OnClick = bCopyClick
  end
  object mResult: TMemo
    Left = 12
    Top = 242
    Width = 656
    Height = 147
    Anchors = [akLeft, akTop, akRight, akBottom]
    ReadOnly = True
    ScrollBars = ssBoth
    TabOrder = 3
    WordWrap = False
  end
  object lblErrors: TLabel
    Left = 12
    Top = 403
    Anchors = [akLeft, akBottom]
    Caption = 'Errors by input line'
    FocusControl = mErrors
  end
  object mErrors: TMemo
    Left = 12
    Top = 424
    Width = 656
    Height = 84
    Anchors = [akLeft, akRight, akBottom]
    ReadOnly = True
    ScrollBars = ssVertical
    TabOrder = 4
  end
  object tmrConvert: TTimer
    Enabled = False
    Interval = 250
    OnTimer = tmrConvertTimer
    Left = 592
    Top = 16
  end
end
