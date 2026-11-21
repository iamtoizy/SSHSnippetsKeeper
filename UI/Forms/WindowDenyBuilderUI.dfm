object WindowDenyBuilderDialog: TWindowDenyBuilderDialog
  Left = 0
  Top = 0
  BorderStyle = bsDialog
  Caption = ''
  ClientHeight = 680
  ClientWidth = 520
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  Position = poScreenCenter
  TextHeight = 15
  object lblTitle: TLabel
    Left = 12
    Top = 12
    Width = 260
    Height = 15
    Caption = 'lblTitle'
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clWindowText
    Font.Height = -12
    Font.Name = 'Segoe UI'
    Font.Style = [fsBold]
    ParentFont = False
  end
  object pTemplates: TPanel
    Left = 0
    Top = 32
    Width = 520
    Height = 30
    BevelOuter = bvNone
    TabOrder = 0
    object cbTemplates: TComboBox
      Left = 8
      Top = 3
      Width = 340
      Height = 23
      Style = csDropDownList
      TabOrder = 0
      OnChange = cbTemplatesChange
    end
    object bSaveTemplate: TButton
      Left = 356
      Top = 3
      Width = 156
      Height = 25
      Caption = 'SaveTemplate'
      TabOrder = 1
      OnClick = bSaveTemplateClick
    end
  end
  object pList: TPanel
    Left = 0
    Top = 62
    Width = 520
    Height = 142
    BevelOuter = bvNone
    TabOrder = 1
    object pListButtons: TPanel
      Left = 0
      Top = 111
      Width = 520
      Height = 31
      Align = alBottom
      BevelOuter = bvNone
      TabOrder = 0
      object bAdd: TButton
        Left = 8
        Top = 3
        Width = 110
        Height = 25
        Caption = 'Add'
        TabOrder = 0
        OnClick = bAddClick
      end
      object bDelete: TButton
        Left = 124
        Top = 3
        Width = 110
        Height = 25
        Caption = 'Delete'
        TabOrder = 1
        OnClick = bDeleteClick
      end
    end
    object lvRules: TListView
      Left = 8
      Top = 0
      Width = 504
      Height = 108
      Columns = <
        item
          Caption = 'Name'
          Width = 150
        end
        item
          Caption = 'Regex'
          Width = 250
        end
        item
          Caption = 'On'
          Width = 60
        end>
      HideSelection = False
      ReadOnly = True
      RowSelect = True
      TabOrder = 1
      ViewStyle = vsReport
      OnSelectItem = lvRulesSelectItem
    end
  end
  object pEditor: TPanel
    Left = 0
    Top = 204
    Width = 520
    Height = 262
    BevelOuter = bvNone
    TabOrder = 2
    object leName: TLabeledEdit
      Left = 12
      Top = 26
      Width = 496
      Height = 23
      EditLabel.Width = 150
      EditLabel.Height = 15
      EditLabel.Caption = 'Name'
      LabelPosition = lpAbove
      TabOrder = 0
      OnChange = leNameChange
    end
    object lblMode: TLabel
      Left = 12
      Top = 68
      Width = 40
      Height = 15
      Caption = 'Mode'
    end
    object cbMode: TComboBox
      Left = 12
      Top = 86
      Width = 220
      Height = 23
      Style = csDropDownList
      TabOrder = 1
      OnChange = cbModeChange
    end
    object bCapture: TButton
      Left = 246
      Top = 85
      Width = 150
      Height = 25
      Caption = 'Capture'
      TabOrder = 2
      OnClick = bCaptureClick
    end
    object leText: TLabeledEdit
      Left = 12
      Top = 130
      Width = 496
      Height = 23
      EditLabel.Width = 140
      EditLabel.Height = 15
      EditLabel.Caption = 'Text'
      LabelPosition = lpAbove
      TabOrder = 3
      OnChange = leTextChange
    end
    object chkCase: TCheckBox
      Left = 12
      Top = 158
      Width = 170
      Height = 17
      Caption = 'Case'
      TabOrder = 4
      OnClick = chkCaseClick
    end
    object chkEnabled: TCheckBox
      Left = 210
      Top = 158
      Width = 170
      Height = 17
      Caption = 'Enabled'
      Checked = True
      State = cbChecked
      TabOrder = 5
      OnClick = chkEnabledClick
    end
    object lePattern: TLabeledEdit
      Left = 12
      Top = 196
      Width = 496
      Height = 23
      EditLabel.Width = 160
      EditLabel.Height = 15
      EditLabel.Caption = 'Generated'
      LabelPosition = lpAbove
      ReadOnly = True
      TabOrder = 6
    end
    object lbHint: TLabel
      Left = 12
      Top = 226
      Width = 496
      Height = 30
      AutoSize = False
      Caption = ''
      WordWrap = True
    end
  end
  object pPreview: TPanel
    Left = 0
    Top = 470
    Width = 520
    Height = 169
    BevelOuter = bvNone
    TabOrder = 3
    object lvPreview: TListView
      Left = 8
      Top = 4
      Width = 504
      Height = 161
      Columns = <
        item
          Caption = 'Title'
          Width = 300
        end
        item
          Caption = 'Status'
          Width = 190
        end>
      HideSelection = False
      ReadOnly = True
      RowSelect = True
      TabOrder = 0
      ViewStyle = vsReport
      OnDblClick = lvPreviewDblClick
    end
    object lbPreviewEmpty: TLabel
      Left = 16
      Top = 80
      Width = 488
      Height = 30
      AutoSize = False
      Caption = ''
      Visible = False
      WordWrap = True
    end
  end
  object pBottom: TPanel
    Left = 0
    Top = 639
    Width = 520
    Height = 41
    Align = alBottom
    BevelOuter = bvNone
    TabOrder = 4
    object bOK: TButton
      Left = 282
      Top = 8
      Width = 110
      Height = 25
      Anchors = [akTop, akRight]
      Caption = 'OK'
      Default = True
      TabOrder = 0
      OnClick = bOKClick
    end
    object bCancel: TButton
      Left = 398
      Top = 8
      Width = 110
      Height = 25
      Anchors = [akTop, akRight]
      Cancel = True
      ModalResult = 2
      TabOrder = 1
    end
  end
end
