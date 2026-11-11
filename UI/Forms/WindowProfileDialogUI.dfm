object WindowProfileDialog: TWindowProfileDialog
  Left = 0
  Top = 0
  BorderStyle = bsDialog
  Caption = ''
  ClientHeight = 434
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
    OnChange = leIncludeChange
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
    OnChange = leExcludeChange
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
  object bPickClass: TButton
    Left = 12
    Top = 188
    Width = 220
    Height = 25
    Caption = 'Pick'
    TabOrder = 3
    OnClick = bPickClassClick
  end
  object lbHint: TLabel
    Left = 12
    Top = 218
    Width = 436
    Height = 30
    AutoSize = False
    Caption = ''
    WordWrap = True
  end
  object lvPreview: TListView
    Left = 12
    Top = 252
    Width = 436
    Height = 141
    Columns = <
      item
        Caption = 'Title'
        Width = 290
      end
      item
        Caption = 'Status'
        Width = 140
      end>
    HideSelection = False
    ReadOnly = True
    RowSelect = True
    TabOrder = 4
    ViewStyle = vsReport
  end
  object lbPreviewEmpty: TLabel
    Left = 16
    Top = 300
    Width = 428
    Height = 40
    AutoSize = False
    Caption = ''
    WordWrap = True
  end
  object pBottom: TPanel
    Left = 0
    Top = 393
    Width = 460
    Height = 41
    Align = alBottom
    BevelOuter = bvNone
    TabOrder = 5
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
      ModalResult = 2
      TabOrder = 1
    end
  end
end
