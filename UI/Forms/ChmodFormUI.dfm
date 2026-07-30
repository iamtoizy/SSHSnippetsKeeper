object ChmodForm: TChmodForm
  Left = 0
  Top = 0
  BorderStyle = bsDialog
  Caption = #1050#1072#1083#1100#1082#1091#1083#1103#1090#1086#1088' '#1087#1088#1072#1074' '#1076#1086#1089#1090#1091#1087#1072' (chmod)'
  ClientHeight = 408
  ClientWidth = 521
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  Position = poScreenCenter
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  TextHeight = 15
  object gbOwner: TGroupBox
    Left = 0
    Top = 0
    Width = 169
    Height = 97
    Caption = #1042#1083#1072#1076#1077#1083#1077#1094
    TabOrder = 0
    object cbUr: TCheckBox
      Left = 16
      Top = 24
      Width = 145
      Height = 17
      Caption = #1063#1090#1077#1085#1080#1077' (r)'
      TabOrder = 0
    end
    object cbUw: TCheckBox
      Left = 16
      Top = 47
      Width = 145
      Height = 17
      Caption = #1047#1072#1087#1080#1089#1100' (w)'
      TabOrder = 1
    end
    object cbUx: TCheckBox
      Left = 16
      Top = 70
      Width = 145
      Height = 17
      Caption = #1042#1099#1087#1086#1083#1085#1077#1085#1080#1077' (x)'
      TabOrder = 2
    end
  end
  object gbGroup: TGroupBox
    Left = 0
    Top = 103
    Width = 169
    Height = 97
    Caption = #1043#1088#1091#1087#1087#1072
    TabOrder = 1
    object cbGr: TCheckBox
      Left = 16
      Top = 24
      Width = 145
      Height = 17
      Caption = #1063#1090#1077#1085#1080#1077' (r)'
      TabOrder = 0
    end
    object cbGw: TCheckBox
      Left = 16
      Top = 47
      Width = 145
      Height = 17
      Caption = #1063#1090#1077#1085#1080#1077' (r)'
      TabOrder = 1
    end
    object cbGx: TCheckBox
      Left = 16
      Top = 70
      Width = 145
      Height = 17
      Caption = #1042#1099#1087#1086#1083#1085#1077#1085#1080#1077' (x)'
      TabOrder = 2
    end
  end
  object gbPublic: TGroupBox
    Left = 0
    Top = 206
    Width = 169
    Height = 97
    Caption = #1054#1089#1090#1072#1083#1100#1085#1099#1077' (Public)'
    TabOrder = 2
    object cbOr: TCheckBox
      Left = 16
      Top = 24
      Width = 145
      Height = 17
      Caption = #1063#1090#1077#1085#1080#1077' (r)'
      TabOrder = 0
    end
    object cbOw: TCheckBox
      Left = 16
      Top = 47
      Width = 145
      Height = 17
      Caption = #1063#1090#1077#1085#1080#1077' (r)'
      TabOrder = 1
    end
    object cbOx: TCheckBox
      Left = 16
      Top = 70
      Width = 145
      Height = 17
      Caption = #1042#1099#1087#1086#1083#1085#1077#1085#1080#1077' (x)'
      TabOrder = 2
    end
  end
  object gbSpecialBits: TGroupBox
    Left = 0
    Top = 311
    Width = 169
    Height = 97
    Caption = #1057#1087#1077#1094#1080#1072#1083#1100#1085#1099#1077' '#1073#1080#1090#1099
    TabOrder = 3
    object cbSuid: TCheckBox
      Left = 15
      Top = 48
      Width = 145
      Height = 17
      Caption = 'SUID'
      TabOrder = 0
    end
    object cbSgid: TCheckBox
      Left = 15
      Top = 24
      Width = 145
      Height = 17
      Caption = 'SGID'
      TabOrder = 1
    end
    object cbSticky: TCheckBox
      Left = 15
      Top = 71
      Width = 145
      Height = 17
      Caption = 'Sticky'
      TabOrder = 2
    end
  end
  object gbCommand: TGroupBox
    Left = 175
    Top = 0
    Width = 346
    Height = 408
    Caption = #1050#1086#1084#1072#1085#1076#1072
    TabOrder = 4
    object lbUser: TLabel
      Left = 11
      Top = 113
      Width = 102
      Height = 15
      Caption = #1048#1084#1103' '#1087#1086#1083#1100#1079#1086#1074#1072#1090#1077#1083#1103
    end
    object lbGroup: TLabel
      Left = 167
      Top = 113
      Width = 68
      Height = 15
      Caption = #1048#1084#1103' '#1075#1088#1091#1087#1087#1099
    end
    object lbFilename: TLabel
      Left = 11
      Top = 158
      Width = 132
      Height = 15
      Caption = #1048#1084#1103' '#1092#1072#1081#1083#1072'/'#1076#1080#1088#1077#1082#1090#1086#1088#1080#1080
    end
    object lbPresets: TLabel
      Left = 11
      Top = 24
      Width = 84
      Height = 15
      Caption = #1055#1088#1077#1076#1091#1089#1090#1072#1085#1086#1074#1082#1080
    end
    object ebOctal: TLabeledEdit
      Left = 11
      Top = 88
      Width = 150
      Height = 23
      EditLabel.Width = 85
      EditLabel.Height = 15
      EditLabel.Caption = #1042#1086#1089#1100#1084#1077#1088#1080#1095#1085#1099#1081
      TabOrder = 0
      Text = 'ebOctal'
      OnChange = edOctalChange
    end
    object ebSymbolic: TLabeledEdit
      Left = 167
      Top = 88
      Width = 172
      Height = 23
      EditLabel.Width = 73
      EditLabel.Height = 15
      EditLabel.Caption = #1057#1080#1084#1074#1086#1083#1100#1085#1099#1081
      TabOrder = 1
      Text = 'ebSymbolic'
      OnChange = edSymbolicChange
    end
    object ebCommand: TLabeledEdit
      Left = 11
      Top = 376
      Width = 299
      Height = 23
      EditLabel.Width = 101
      EditLabel.Height = 15
      EditLabel.Caption = #1048#1090#1086#1075#1086#1074#1072#1103' '#1082#1086#1084#1072#1085#1076#1072
      TabOrder = 5
      Text = 'ebCommand'
    end
    object bCopyCommand: TButton
      Left = 316
      Top = 375
      Width = 23
      Height = 23
      Caption = #55357#56523
      TabOrder = 6
      OnClick = bCopyCommandClick
    end
    object cbIsDir: TCheckBox
      Left = 11
      Top = 210
      Width = 318
      Height = 17
      Caption = #1069#1090#1086' '#1076#1080#1088#1077#1082#1090#1086#1088#1080#1103' (Directory)'
      TabOrder = 7
    end
    object cbRecursive: TCheckBox
      Left = 11
      Top = 233
      Width = 318
      Height = 17
      Caption = #1056#1077#1082#1091#1088#1089#1080#1074#1085#1086' (-R)'
      TabOrder = 8
      OnClick = cbRecursiveClick
    end
    object cbUser: TComboBox
      Left = 11
      Top = 132
      Width = 150
      Height = 23
      TabOrder = 2
      Text = 'root'
      OnChange = edSymbolicChange
    end
    object cbGroup: TComboBox
      Left = 167
      Top = 132
      Width = 172
      Height = 23
      TabOrder = 3
      Text = 'root'
    end
    object cbFileName: TComboBox
      Left = 11
      Top = 178
      Width = 328
      Height = 23
      TabOrder = 4
    end
    object cbPresets: TComboBox
      Left = 11
      Top = 45
      Width = 274
      Height = 23
      Style = csDropDownList
      TabOrder = 9
    end
    object bSavePreset: TButton
      Left = 289
      Top = 44
      Width = 23
      Height = 23
      Caption = #55357#56510
      TabOrder = 10
      OnClick = bSavePresetClick
    end
    object bDeletePreset: TButton
      Left = 316
      Top = 44
      Width = 23
      Height = 23
      Caption = #55357#56785
      TabOrder = 11
      OnClick = bSavePresetClick
    end
    object cbSudo: TCheckBox
      Left = 11
      Top = 256
      Width = 318
      Height = 17
      Caption = 'sudo'
      TabOrder = 12
      OnClick = OnChownOrFlagChange
    end
    object cbSmartExecute: TCheckBox
      Left = 11
      Top = 279
      Width = 318
      Height = 17
      Caption = #1059#1084#1085#1099#1081' X '#1076#1083#1103' '#1076#1080#1088#1077#1082#1090#1086#1088#1080#1081' (+X)'
      TabOrder = 13
      OnClick = cbSmartExecuteClick
    end
    object cbSeparateMode: TCheckBox
      Left = 11
      Top = 302
      Width = 318
      Height = 17
      Caption = #1056#1072#1079#1076#1077#1083#1100#1085#1086' '#1092#1072#1081#1083#1099' (644) '#1080' '#1076#1080#1088#1077#1082#1090#1086#1088#1080#1080' (755)'
      TabOrder = 14
      OnClick = cbSeparateModeClick
    end
  end
end
