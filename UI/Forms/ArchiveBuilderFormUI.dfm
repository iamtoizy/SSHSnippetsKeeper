object ArchiveBuilderForm: TArchiveBuilderForm
  Left = 0
  Top = 0
  BorderStyle = bsDialog
  Caption = #1040#1088#1093#1080#1074#1072#1090#1086#1088' / Archive Builder'
  ClientHeight = 342
  ClientWidth = 472
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
  object pcMain: TPageControl
    Left = 0
    Top = 0
    Width = 472
    Height = 297
    ActivePage = tsCreate
    Align = alTop
    TabOrder = 0
    OnChange = pcMainChange
    object tsCreate: TTabSheet
      Caption = #1057#1086#1079#1076#1072#1090#1100' '#1072#1088#1093#1080#1074
      DesignSize = (
        464
        267)
      object lbSourcePath: TLabel
        Left = 3
        Top = 3
        Width = 92
        Height = 15
        Caption = #1063#1090#1086' '#1072#1088#1093#1080#1074#1080#1088#1091#1077#1084':'
      end
      object lbDestPath: TLabel
        Left = 235
        Top = 3
        Width = 67
        Height = 15
        Caption = #1048#1084#1103' '#1072#1088#1093#1080#1074#1072':'
      end
      object lbExclude: TLabel
        Left = 3
        Top = 50
        Width = 66
        Height = 15
        Caption = #1048#1089#1082#1083#1102#1095#1080#1090#1100':'
      end
      object lbFormat: TLabel
        Left = 235
        Top = 50
        Width = 46
        Height = 15
        Caption = #1060#1086#1088#1084#1072#1090':'
      end
      object lbPresets: TLabel
        Left = 3
        Top = 223
        Width = 84
        Height = 15
        Caption = #1055#1088#1077#1076#1091#1089#1090#1072#1085#1086#1074#1082#1080
      end
      object lbPassword: TLabel
        Left = 235
        Top = 98
        Width = 134
        Height = 15
        Caption = #1055#1072#1088#1086#1083#1100' ('#1090#1086#1083#1100#1082#1086' zip / 7z):'
      end
      object cbSourcePath: TComboBox
        Left = 3
        Top = 24
        Width = 226
        Height = 23
        Anchors = [akLeft, akTop, akRight]
        TabOrder = 0
        Text = '/var/www/site/public_html'
        OnChange = OnUIChange
      end
      object cbDestPath: TComboBox
        Left = 235
        Top = 24
        Width = 226
        Height = 23
        Anchors = [akLeft, akTop, akRight]
        TabOrder = 1
        Text = 'backup.tar.gz'
        OnChange = cbDestPathChange
      end
      object cbFormatCreate: TComboBox
        Left = 235
        Top = 69
        Width = 226
        Height = 23
        Style = csDropDownList
        ItemIndex = 1
        TabOrder = 3
        Text = 'tar.gz'
        OnChange = cbFormatCreateChange
        Items.Strings = (
          'zip'
          'tar.gz'
          'tar.bz2'
          'tar.xz'
          'tar.zst (Zstandard)'
          'tar.lz4'
          '7z')
      end
      object cbMaxCompression: TCheckBox
        Left = 235
        Top = 148
        Width = 226
        Height = 17
        Caption = #1052#1072#1082#1089#1080#1084#1072#1083#1100#1085#1086#1077' '#1089#1078#1072#1090#1080#1077
        TabOrder = 5
        OnClick = OnUIChange
      end
      object cbRelativePath: TCheckBox
        Left = 235
        Top = 171
        Width = 226
        Height = 17
        Caption = #1041#1077#1079' '#1089#1090#1088#1091#1082#1090#1091#1088#1099' '#1087#1072#1087#1086#1082' ('#1086#1090#1085#1086#1089#1080#1090#1077#1083#1100#1085#1086')'
        TabOrder = 6
        OnClick = OnUIChange
      end
      object ebPassword: TEdit
        Left = 235
        Top = 119
        Width = 226
        Height = 23
        TabOrder = 4
        OnChange = OnUIChange
      end
      object cbSplit: TCheckBox
        Left = 235
        Top = 194
        Width = 160
        Height = 17
        Caption = #1056#1072#1079#1073#1080#1090#1100' '#1085#1072' '#1090#1086#1084#1072' ('#1052#1041'):'
        TabOrder = 7
        OnClick = OnUIChange
      end
      object cbPresets: TComboBox
        Left = 3
        Top = 244
        Width = 400
        Height = 23
        Style = csDropDownList
        TabOrder = 9
        OnChange = cbPresetsChange
      end
      object bSavePreset: TButton
        Left = 409
        Top = 243
        Width = 23
        Height = 23
        Caption = #55357#56510
        TabOrder = 10
        OnClick = bSavePresetClick
      end
      object bDeletePreset: TButton
        Left = 438
        Top = 243
        Width = 23
        Height = 23
        Caption = #55357#56785
        TabOrder = 11
        OnClick = bDeletePresetClick
      end
      object mExclude: TMemo
        Left = 3
        Top = 69
        Width = 226
        Height = 148
        Anchors = [akLeft, akTop, akRight]
        ScrollBars = ssBoth
        TabOrder = 2
        OnChange = OnUIChange
      end
      object seSplitSize: TSpinEdit
        Left = 392
        Top = 191
        Width = 69
        Height = 24
        MaxValue = 0
        MinValue = 0
        TabOrder = 8
        Value = 0
        OnChange = seSplitSizeChange
      end
    end
    object tsExtract: TTabSheet
      Caption = #1056#1072#1089#1087#1072#1082#1086#1074#1072#1090#1100
      ImageIndex = 1
      DesignSize = (
        464
        267)
      object lbExtSourcePath: TLabel
        Left = 3
        Top = 3
        Width = 78
        Height = 15
        Caption = #1055#1091#1090#1100' '#1082' '#1072#1088#1093#1080#1074#1091':'
      end
      object lbExtDestPath: TLabel
        Left = 3
        Top = 53
        Width = 331
        Height = 15
        Caption = #1050#1091#1076#1072' '#1088#1072#1089#1087#1072#1082#1086#1074#1072#1090#1100' ('#1086#1089#1090#1072#1074#1100' '#1087#1091#1089#1090#1099#1084' '#1076#1083#1103' '#1090#1077#1082#1091#1097#1077#1081' '#1076#1080#1088#1077#1082#1090#1086#1088#1080#1080'):'
      end
      object lbExtFormat: TLabel
        Left = 3
        Top = 103
        Width = 44
        Height = 15
        Caption = #1059#1090#1080#1083#1080#1090#1072
      end
      object lbExtPassword: TLabel
        Left = 226
        Top = 103
        Width = 134
        Height = 15
        Caption = #1055#1072#1088#1086#1083#1100' ('#1090#1086#1083#1100#1082#1086' zip / 7z):'
      end
      object cbSourceExtract: TComboBox
        Left = 3
        Top = 24
        Width = 458
        Height = 23
        Anchors = [akLeft, akTop, akRight]
        TabOrder = 0
        Text = 'archive.zip'
        OnChange = OnUIChange
      end
      object cbDestExtract: TComboBox
        Left = 3
        Top = 74
        Width = 458
        Height = 23
        Anchors = [akLeft, akTop, akRight]
        TabOrder = 1
        OnChange = OnUIChange
      end
      object cbFormatExtract: TComboBox
        Left = 0
        Top = 124
        Width = 220
        Height = 23
        Style = csDropDownList
        TabOrder = 2
        OnChange = OnUIChange
      end
      object ebExtPassword: TEdit
        Left = 226
        Top = 124
        Width = 235
        Height = 23
        PasswordChar = '*'
        TabOrder = 3
        OnChange = OnUIChange
      end
      object cbListOnly: TCheckBox
        Left = 3
        Top = 161
        Width = 300
        Height = 17
        Caption = #1058#1086#1083#1100#1082#1086' '#1087#1088#1086#1089#1084#1086#1090#1088' '#1089#1086#1076#1077#1088#1078#1080#1084#1086#1075#1086' (Dry Run / List)'
        TabOrder = 4
        OnClick = OnUIChange
      end
    end
  end
  object pnBottom: TPanel
    Left = 0
    Top = 301
    Width = 472
    Height = 41
    Align = alBottom
    BevelOuter = bvNone
    TabOrder = 1
    DesignSize = (
      472
      41)
    object ebCommand: TLabeledEdit
      Left = 4
      Top = 18
      Width = 432
      Height = 23
      Anchors = [akLeft, akRight, akBottom]
      EditLabel.Width = 104
      EditLabel.Height = 15
      EditLabel.Caption = #1048#1090#1086#1075#1086#1074#1072#1103' '#1082#1086#1084#1072#1085#1076#1072':'
      ReadOnly = True
      TabOrder = 0
      Text = ''
    end
    object bCopyCommand: TButton
      Left = 442
      Top = 18
      Width = 23
      Height = 23
      Anchors = [akRight, akBottom]
      Caption = #55357#56523
      TabOrder = 1
      OnClick = bCopyCommandClick
    end
  end
end
