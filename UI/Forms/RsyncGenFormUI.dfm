object RsyncGenForm: TRsyncGenForm
  Left = 0
  Top = 0
  BorderStyle = bsDialog
  Caption = #1050#1086#1085#1089#1090#1088#1091#1082#1090#1086#1088' '#1082#1086#1084#1072#1085#1076#1099' rsync'
  ClientHeight = 534
  ClientWidth = 900
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
  object pnlTop: TPanel
    Left = 0
    Top = 0
    Width = 900
    Height = 103
    Align = alTop
    BevelOuter = bvNone
    ParentBackground = False
    ShowCaption = False
    TabOrder = 0
    object lbTitle: TLabel
      Left = 4
      Top = 2
      Width = 85
      Height = 15
      Caption = #1050#1086#1084#1072#1085#1076#1072' rsync:'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWindowText
      Font.Height = -12
      Font.Name = 'Segoe UI'
      Font.Style = [fsBold]
      ParentFont = False
    end
    object lbValidation: TLabel
      Left = 320
      Top = 80
      Width = 576
      Height = 15
      AutoSize = False
      WordWrap = True
    end
    object mCommand: TMemo
      Left = 4
      Top = 20
      Width = 780
      Height = 52
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWindowText
      Font.Height = -12
      Font.Name = 'Consolas'
      Font.Style = []
      ParentFont = False
      ReadOnly = True
      ScrollBars = ssVertical
      TabOrder = 0
    end
    object bCopy: TButton
      Left = 790
      Top = 20
      Width = 106
      Height = 52
      Caption = #1057#1082#1086#1087#1080#1088#1086#1074#1072#1090#1100
      TabOrder = 1
      OnClick = bCopyClick
    end
    object cbMultiline: TCheckBox
      Left = 4
      Top = 78
      Width = 300
      Height = 17
      Hint =
        #1052#1085#1086#1075#1086#1089#1090#1088#1086#1095#1085#1099#1081' '#1074#1080#1076': '#1082#1072#1078#1076#1099#1081' '#1087#1072#1088#1072#1084#1077#1090#1088' '#1085#1072' '#1089#1074#1086#1077#1081' '#1089#1090#1088#1086#1082#1077' '#1089' '#1086#1073#1088#1072#1090#1085#1099#1084' '#1089#1083 +
        #1101#1096#1077#1084' '#1076#1083#1103' bash/zsh.'
      Caption = #1056#1072#1079#1073#1080#1074#1072#1090#1100' '#1087#1072#1088#1072#1084#1077#1090#1088#1099' '#1087#1086' '#1089#1090#1088#1086#1082#1072#1084' (\)'
      ParentShowHint = False
      ShowHint = True
      TabOrder = 2
      OnClick = OnFlagChange
    end
  end
  object gbCopyMode: TGroupBox
    AlignWithMargins = True
    Left = 4
    Top = 103
    Width = 892
    Height = 42
    Margins.Left = 4
    Margins.Top = 0
    Margins.Right = 4
    Margins.Bottom = 4
    Align = alTop
    Caption = #1056#1077#1078#1080#1084' '#1082#1086#1087#1080#1088#1086#1074#1072#1085#1080#1103':'
    TabOrder = 1
    object rbLocal: TRadioButton
      Left = 5
      Top = 17
      Width = 294
      Height = 17
      Hint = #1050#1086#1087#1080#1088#1086#1074#1072#1085#1080#1077' '#1074' '#1087#1088#1077#1076#1077#1083#1072#1093' '#1086#1076#1085#1086#1081' '#1084#1072#1096#1080#1085#1099': rsync SRC DEST'
      Caption = #1051#1086#1082#1072#1083#1100#1085#1086
      Checked = True
      ParentShowHint = False
      ShowHint = True
      TabOrder = 0
      TabStop = True
      OnClick = OnFlagChange
    end
    object rbPush: TRadioButton
      Left = 299
      Top = 17
      Width = 294
      Height = 17
      Hint = 'rsync SRC user@host:/DEST '#1089' '#1090#1088#1072#1085#1089#1087#1086#1088#1090#1086#1084' SSH'
      Caption = #1051#1086#1082#1072#1083#1100#1085#1086#1077' '#8594' '#1089#1077#1088#1074#1077#1088' (push)'
      ParentShowHint = False
      ShowHint = True
      TabOrder = 1
      OnClick = OnFlagChange
    end
    object rbPull: TRadioButton
      Left = 593
      Top = 17
      Width = 294
      Height = 17
      Hint = 'rsync user@host:/SRC DEST '#1089' '#1090#1088#1072#1085#1089#1087#1086#1088#1090#1086#1084' SSH'
      Caption = #1057#1077#1088#1074#1077#1088' '#8594' '#1083#1086#1082#1072#1083#1100#1085#1086#1077' (pull)'
      ParentShowHint = False
      ShowHint = True
      TabOrder = 2
      OnClick = OnFlagChange
    end
  end
  object gbParameters: TGroupBox
    AlignWithMargins = True
    Left = 4
    Top = 149
    Width = 892
    Height = 174
    Margins.Left = 4
    Margins.Top = 0
    Margins.Right = 4
    Margins.Bottom = 4
    Align = alTop
    TabOrder = 2
    DesignSize = (
      892
      174)
    object lbSource: TLabel
      Left = 8
      Top = 17
      Width = 57
      Height = 15
      Caption = #1048#1089#1090#1086#1095#1085#1080#1082':'
    end
    object lbDest: TLabel
      Left = 8
      Top = 45
      Width = 61
      Height = 15
      Caption = #1055#1088#1080#1105#1084#1085#1080#1082':'
    end
    object lbUser: TLabel
      Left = 8
      Top = 77
      Width = 104
      Height = 15
      Caption = 'SSH-'#1087#1086#1083#1100#1079#1086#1074#1072#1090#1077#1083#1100':'
    end
    object lbHost: TLabel
      Left = 468
      Top = 77
      Width = 28
      Height = 15
      Caption = #1061#1086#1089#1090':'
    end
    object lbPort: TLabel
      Left = 798
      Top = 77
      Width = 31
      Height = 15
      Caption = #1055#1086#1088#1090':'
    end
    object lbPresets: TLabel
      Left = 8
      Top = 109
      Width = 87
      Height = 15
      Caption = #1055#1088#1077#1076#1091#1089#1090#1072#1085#1086#1074#1082#1080':'
    end
    object lbExtra: TLabel
      Left = 8
      Top = 147
      Width = 91
      Height = 15
      Caption = #1044#1086#1087'. '#1072#1088#1075#1091#1084#1077#1085#1090#1099':'
    end
    object cbSource: TComboBox
      Left = 128
      Top = 14
      Width = 752
      Height = 23
      Hint =
        #1055#1091#1090#1100'-'#1080#1089#1090#1086#1095#1085#1080#1082'. '#1042' '#1088#1077#1078#1080#1084#1077' pull - '#1087#1091#1090#1100' '#1085#1072' '#1089#1077#1088#1074#1077#1088#1077' (user@host:/path ' +
        #1074#1074#1086#1076#1080#1090#1100' '#1085#1077' '#1085#1091#1078#1085#1086', host '#1073#1077#1088#1105#1090#1089#1103' '#1089#1087#1088#1072#1074#1072').'
      ParentShowHint = False
      ShowHint = True
      TabOrder = 0
      OnChange = OnFlagChange
    end
    object cbDest: TComboBox
      Left = 128
      Top = 42
      Width = 752
      Height = 23
      Hint = #1055#1091#1090#1100'-'#1087#1088#1080#1105#1084#1085#1080#1082'. '#1042' '#1088#1077#1078#1080#1084#1077' push - '#1087#1091#1090#1100' '#1085#1072' '#1089#1077#1088#1074#1077#1088#1077'.'
      ParentShowHint = False
      ShowHint = True
      TabOrder = 1
      OnChange = OnFlagChange
    end
    object ebUser: TEdit
      Left = 128
      Top = 74
      Width = 322
      Height = 21
      Hint =
        #1048#1084#1103' '#1087#1086#1083#1100#1079#1086#1074#1072#1090#1077#1083#1103' SSH ('#1085#1077#1086#1073#1103#1079#1072#1090#1077#1083#1100#1085#1086'). '#1055#1091#1089#1090#1086' - '#1090#1077#1082#1091#1097#1080#1081' '#1087#1086#1083#1100#1079#1086#1074#1072#1090#1077 +
        #1083#1100'.'
      ParentShowHint = False
      ShowHint = True
      TabOrder = 2
      OnChange = OnFlagChange
    end
    object ebHost: TEdit
      Left = 502
      Top = 74
      Width = 284
      Height = 21
      Hint = #1061#1086#1089#1090' '#1080#1083#1080' '#1072#1076#1088#1077#1089' '#1089#1077#1088#1074#1077#1088#1072'. '#1044#1083#1103' '#1083#1086#1082#1072#1083#1100#1085#1086#1075#1086' '#1088#1077#1078#1080#1084#1072' '#1085#1077' '#1080#1089#1087#1086#1083#1100#1079#1091#1077#1090#1089#1103'.'
      ParentShowHint = False
      ShowHint = True
      TabOrder = 3
      OnChange = OnFlagChange
    end
    object ebSshPort: TEdit
      Left = 828
      Top = 74
      Width = 52
      Height = 21
      Hint = #1055#1086#1088#1090' SSH. '#1055#1091#1089#1090#1086' - '#1089#1090#1072#1085#1076#1072#1088#1090#1085#1099#1081' 22 ('#1073#1077#1079' -p).'
      MaxLength = 5
      ParentShowHint = False
      ShowHint = True
      TabOrder = 4
      OnChange = ebSshPortChange
      OnKeyPress = ebSshPortKeyPress
    end
    object cbPresets: TComboBox
      Left = 128
      Top = 106
      Width = 420
      Height = 23
      Hint =
        #1043#1086#1090#1086#1074#1099#1077' '#1089#1094#1077#1085#1072#1088#1080#1080': '#1087#1088#1080#1084#1077#1085#1077#1085#1080#1077' '#1087#1088#1077#1076#1091#1089#1090#1072#1085#1086#1074#1082#1080' '#1079#1072#1087#1086#1083#1085#1080#1090' '#1092#1083#1072#1075#1080'. '#1055#1091#1090#1080' ' +
        #1080' SSH-'#1087#1086#1083#1103' '#1085#1077' '#1080#1079#1084#1077#1085#1103#1102#1090#1089#1103'.'
      Style = csDropDownList
      ParentShowHint = False
      ShowHint = True
      TabOrder = 5
      OnChange = cbPresetsChange
    end
    object bPresetSave: TButton
      Left = 556
      Top = 105
      Width = 23
      Height = 23
      Hint = #1057#1086#1093#1088#1072#1085#1080#1090#1100' '#1090#1077#1082#1091#1097#1080#1077' '#1092#1083#1072#1075#1080' '#1082#1072#1082' '#1087#1088#1077#1076#1091#1089#1090#1072#1085#1086#1074#1082#1091'.'
      Caption = #55357#56510
      ParentShowHint = False
      ShowHint = True
      TabOrder = 6
      OnClick = bPresetSaveClick
    end
    object bPresetRename: TButton
      Left = 583
      Top = 105
      Width = 23
      Height = 23
      Hint = #1055#1077#1088#1077#1080#1084#1077#1085#1086#1074#1072#1090#1100' '#1087#1086#1083#1100#1079#1086#1074#1072#1090#1077#1083#1100#1089#1082#1091#1102' '#1087#1088#1077#1076#1091#1089#1090#1072#1085#1086#1074#1082#1091'.'
      Caption = #55357#56581
      ParentShowHint = False
      ShowHint = True
      TabOrder = 7
      OnClick = bPresetRenameClick
    end
    object bPresetDelete: TButton
      Left = 610
      Top = 105
      Width = 23
      Height = 23
      Hint = #1059#1076#1072#1083#1080#1090#1100' '#1087#1086#1083#1100#1079#1086#1074#1072#1090#1077#1083#1100#1089#1082#1091#1102' '#1087#1088#1077#1076#1091#1089#1090#1072#1085#1086#1074#1082#1091'.'
      Caption = #55357#56785
      ParentShowHint = False
      ShowHint = True
      TabOrder = 8
      OnClick = bPresetDeleteClick
    end
    object bReset: TButton
      Left = 646
      Top = 105
      Width = 132
      Height = 25
      Hint = #1042#1077#1088#1085#1091#1090#1100' '#1092#1083#1072#1075#1080' '#1082' '#1089#1086#1089#1090#1086#1103#1085#1080#1102' '#1087#1086' '#1091#1084#1086#1083#1095#1072#1085#1080#1102' ('#1090#1086#1083#1100#1082#1086' -a).'
      Caption = #1057#1073#1088#1086#1089#1080#1090#1100
      ParentShowHint = False
      ShowHint = True
      TabOrder = 9
      OnClick = bResetClick
    end
    object ebExtra: TEdit
      Left = 128
      Top = 144
      Width = 752
      Height = 21
      Hint = #1044#1086#1087#1086#1083#1085#1080#1090#1077#1083#1100#1085#1099#1077' '#1072#1088#1075#1091#1084#1077#1085#1090#1099': '#1076#1086#1073#1072#1074#1083#1103#1102#1090#1089#1103' '#1074' '#1082#1086#1085#1077#1094' '#1082#1086#1084#1072#1085#1076#1099' '#1082#1072#1082' '#1077#1089#1090#1100'.'
      Anchors = [akLeft, akTop, akRight]
      ParentShowHint = False
      ShowHint = True
      TabOrder = 10
      OnChange = OnFlagChange
    end
  end
  object pgcOptions: TPageControl
    Left = 0
    Top = 327
    Width = 900
    Height = 207
    ActivePage = tsMain
    Align = alClient
    TabOrder = 3
    object tsMain: TTabSheet
      Caption = #1054#1089#1085#1086#1074#1085#1086#1077
      object cbArchive: TCheckBox
        Left = 6
        Top = 4
        Width = 264
        Height = 17
        Hint =
          #1050#1083#1102#1095': -a. '#1069#1082#1074#1080#1074#1072#1083#1077#1085#1090' -rlptgoD: '#1088#1077#1082#1091#1088#1089#1080#1103', '#1089#1080#1084#1074#1086#1083#1080#1095#1077#1089#1082#1080#1077' '#1089#1089#1099#1083#1082#1080', '#1087 +
          #1088#1072#1074#1072', '#1074#1088#1077#1084#1077#1085#1072', '#1074#1083#1072#1076#1077#1083#1077#1094', '#1075#1088#1091#1087#1087#1072', '#1091#1089#1090#1088#1086#1081#1089#1090#1074#1072'. '#1057#1072#1084#1099#1081' '#1095#1072#1089#1090#1099#1081' '#1073#1072#1079#1086#1074#1099 +
          #1081' '#1088#1077#1078#1080#1084'.'
        Caption = #1040#1088#1093#1080#1074#1085#1099#1081' '#1088#1077#1078#1080#1084
        ParentShowHint = False
        ShowHint = True
        TabOrder = 1
        OnClick = OnFlagChange
      end
      object cbRecursive: TCheckBox
        Left = 296
        Top = 4
        Width = 264
        Height = 17
        Hint = #1050#1083#1102#1095': -r. '#1056#1077#1082#1091#1088#1089#1080#1074#1085#1099#1081' '#1086#1073#1093#1086#1076' '#1076#1080#1088#1077#1082#1090#1086#1088#1080#1081'.'
        Caption = #1056#1077#1082#1091#1088#1089#1080#1074#1085#1086
        ParentShowHint = False
        ShowHint = True
        TabOrder = 2
        OnClick = OnFlagChange
      end
      object cbLinks: TCheckBox
        Left = 596
        Top = 4
        Width = 264
        Height = 17
        Hint = #1050#1083#1102#1095': -l. '#1050#1086#1087#1080#1088#1086#1074#1072#1090#1100' '#1089#1080#1084#1083#1080#1085#1082#1080' '#1082#1072#1082' '#1089#1089#1099#1083#1082#1080', '#1072' '#1085#1077' '#1082#1072#1082' '#1086#1073#1098#1077#1082#1090#1099'-'#1094#1077#1083#1080'.'
        Caption = #1057#1080#1084#1074#1086#1083#1080#1095#1077#1089#1082#1080#1077' '#1089#1089#1099#1083#1082#1080
        ParentShowHint = False
        ShowHint = True
        TabOrder = 3
        OnClick = OnFlagChange
      end
      object cbPerms: TCheckBox
        Left = 6
        Top = 30
        Width = 264
        Height = 17
        Hint = #1050#1083#1102#1095': -p. '#1057#1086#1093#1088#1072#1085#1103#1090#1100' '#1087#1088#1072#1074#1072' '#1076#1086#1089#1090#1091#1087#1072' (chmod).'
        Caption = #1055#1088#1072#1074#1072' '#1076#1086#1089#1090#1091#1087#1072
        ParentShowHint = False
        ShowHint = True
        TabOrder = 4
        OnClick = OnFlagChange
      end
      object cbTimes: TCheckBox
        Left = 296
        Top = 30
        Width = 264
        Height = 17
        Hint = #1050#1083#1102#1095': -t. '#1057#1086#1093#1088#1072#1085#1103#1090#1100' '#1074#1088#1077#1084#1077#1085#1072' '#1084#1086#1076#1080#1092#1080#1082#1072#1094#1080#1080' '#1092#1072#1081#1083#1086#1074'.'
        Caption = #1042#1088#1077#1084#1103' '#1084#1086#1076#1080#1092#1080#1082#1072#1094#1080#1080
        ParentShowHint = False
        ShowHint = True
        TabOrder = 5
        OnClick = OnFlagChange
      end
      object cbGroup: TCheckBox
        Left = 596
        Top = 30
        Width = 264
        Height = 17
        Hint = #1050#1083#1102#1095': -g. '#1057#1086#1093#1088#1072#1085#1103#1090#1100' '#1075#1088#1091#1087#1087#1091' '#1092#1072#1081#1083#1072'.'
        Caption = #1043#1088#1091#1087#1087#1072
        ParentShowHint = False
        ShowHint = True
        TabOrder = 6
        OnClick = OnFlagChange
      end
      object cbOwner: TCheckBox
        Left = 6
        Top = 56
        Width = 264
        Height = 17
        Hint = #1050#1083#1102#1095': -o. '#1057#1086#1093#1088#1072#1085#1103#1090#1100' '#1074#1083#1072#1076#1077#1083#1100#1094#1072' ('#1085#1091#1078#1085#1086' '#1073#1099#1090#1100' root).'
        Caption = #1042#1083#1072#1076#1077#1083#1077#1094
        ParentShowHint = False
        ShowHint = True
        TabOrder = 7
        OnClick = OnFlagChange
      end
      object cbDevices: TCheckBox
        Left = 296
        Top = 56
        Width = 264
        Height = 17
        Hint =
          #1050#1083#1102#1095': -D. '#1050#1086#1087#1080#1088#1086#1074#1072#1090#1100' '#1092#1072#1081#1083#1099' '#1091#1089#1090#1088#1086#1081#1089#1090#1074' '#1080' '#1089#1087#1077#1094'-'#1092#1072#1081#1083#1099' ('#1087#1086#1076#1088#1072#1079#1091#1084#1077#1074#1072#1077#1090 +
          ' --specials).'
        Caption = #1059#1089#1090#1088#1086#1081#1089#1090#1074#1072
        ParentShowHint = False
        ShowHint = True
        TabOrder = 8
        OnClick = OnFlagChange
      end
      object cbSpecials: TCheckBox
        Left = 596
        Top = 56
        Width = 264
        Height = 17
        Hint = #1050#1083#1102#1095': -s. '#1050#1086#1087#1080#1088#1086#1074#1072#1090#1100' '#1089#1086#1082#1077#1090#1099', FIFO '#1080' '#1076#1088#1091#1075#1080#1077' '#1089#1087#1077#1094'-'#1092#1072#1081#1083#1099'.'
        Caption = #1057#1087#1077#1094'-'#1092#1072#1081#1083#1099
        ParentShowHint = False
        ShowHint = True
        TabOrder = 9
        OnClick = OnFlagChange
      end
      object cbHardLinks: TCheckBox
        Left = 6
        Top = 82
        Width = 264
        Height = 17
        Hint = #1050#1083#1102#1095': -H. '#1057#1086#1093#1088#1072#1085#1103#1090#1100' '#1078#1105#1089#1090#1082#1080#1077' '#1089#1089#1099#1083#1082#1080' ('#1079#1072#1084#1077#1076#1083#1103#1077#1090' '#1087#1077#1088#1077#1076#1072#1095#1091').'
        Caption = #1046#1105#1089#1090#1082#1080#1077' '#1089#1089#1099#1083#1082#1080
        ParentShowHint = False
        ShowHint = True
        TabOrder = 10
        OnClick = OnFlagChange
      end
      object cbAcls: TCheckBox
        Left = 296
        Top = 82
        Width = 264
        Height = 17
        Hint =
          #1050#1083#1102#1095': -A. '#1057#1086#1093#1088#1072#1085#1103#1090#1100' POSIX ACL ('#1085#1091#1078#1085#1072' '#1087#1086#1076#1076#1077#1088#1078#1082#1072' '#1085#1072' '#1086#1073#1077#1080#1093' '#1089#1090#1086#1088#1086#1085#1072#1093 +
          ').'
        Caption = 'ACL'
        ParentShowHint = False
        ShowHint = True
        TabOrder = 11
        OnClick = OnFlagChange
      end
      object cbXattrs: TCheckBox
        Left = 596
        Top = 82
        Width = 264
        Height = 17
        Hint = #1050#1083#1102#1095': -X. '#1057#1086#1093#1088#1072#1085#1103#1090#1100' xattr ('#1085#1091#1078#1085#1072' '#1087#1086#1076#1076#1077#1088#1078#1082#1072' '#1085#1072' '#1086#1073#1077#1080#1093' '#1089#1090#1086#1088#1086#1085#1072#1093').'
        Caption = #1056#1072#1089#1096#1080#1088#1077#1085#1085#1099#1077' '#1072#1090#1088#1080#1073#1091#1090#1099
        ParentShowHint = False
        ShowHint = True
        TabOrder = 12
        OnClick = OnFlagChange
      end
      object cbDirs: TCheckBox
        Left = 6
        Top = 108
        Width = 264
        Height = 17
        Hint = #1050#1083#1102#1095': -d. '#1050#1086#1087#1080#1088#1086#1074#1072#1090#1100' '#1076#1080#1088#1077#1082#1090#1086#1088#1080#1080' '#1073#1077#1079' '#1089#1086#1076#1077#1088#1078#1080#1084#1086#1075#1086'.'
        Caption = #1058#1086#1083#1100#1082#1086' '#1076#1080#1088#1077#1082#1090#1086#1088#1080#1080
        ParentShowHint = False
        ShowHint = True
        TabOrder = 13
        OnClick = OnFlagChange
      end
      object cbDryRun: TCheckBox
        Left = 296
        Top = 108
        Width = 264
        Height = 17
        Hint =
          #1050#1083#1102#1095': -n. '#1058#1086#1083#1100#1082#1086' '#1087#1086#1082#1072#1079#1072#1090#1100', '#1095#1090#1086' '#1073#1091#1076#1077#1090' '#1089#1076#1077#1083#1072#1085#1086', '#1085#1080#1095#1077#1075#1086' '#1085#1077' '#1084#1077#1085#1103#1090#1100'. ' +
          #1055#1086#1083#1077#1079#1085#1086' '#1087#1088#1086#1074#1077#1088#1103#1090#1100' '#1087#1077#1088#1077#1076' --delete.'
        Caption = #1057#1091#1093#1086#1081' '#1087#1088#1086#1075#1086#1085
        ParentShowHint = False
        ShowHint = True
        TabOrder = 14
        OnClick = OnFlagChange
      end
      object cbOmitDirTimes: TCheckBox
        Left = 596
        Top = 108
        Width = 264
        Height = 17
        Hint =
          #1050#1083#1102#1095': -O. '#1053#1077' '#1089#1086#1093#1088#1072#1085#1103#1090#1100' '#1074#1088#1077#1084#1077#1085#1072' '#1076#1080#1088#1077#1082#1090#1086#1088#1080#1081' ('#1087#1086#1083#1077#1079#1085#1086' '#1089' --sparse '#1080#1083 +
          #1080' '#1085#1072' FAT).'
        Caption = #1042#1088#1077#1084#1103' '#1082#1072#1090#1072#1083#1086#1075#1086#1074' '#1085#1077' '#1084#1077#1085#1103#1090#1100
        ParentShowHint = False
        ShowHint = True
        TabOrder = 0
        OnClick = OnFlagChange
      end
    end
    object tsTransfer: TTabSheet
      Caption = #1055#1077#1088#1077#1076#1072#1095#1072
      object cbWholeFile: TCheckBox
        Left = 6
        Top = 4
        Width = 264
        Height = 17
        Hint =
          #1050#1083#1102#1095': -W. '#1050#1086#1087#1080#1088#1086#1074#1072#1090#1100' '#1092#1072#1081#1083' '#1094#1077#1083#1080#1082#1086#1084' '#1074#1084#1077#1089#1090#1086' '#1072#1083#1075#1086#1088#1080#1090#1084#1072' '#1076#1077#1083#1100#1090#1072'-'#1076#1080#1092#1092#1072' ' +
          '('#1073#1099#1089#1090#1088#1077#1077' '#1087#1086' '#1083#1086#1082#1072#1083#1100#1085#1086#1081' '#1089#1077#1090#1080').'
        Caption = #1062#1077#1083#1080#1082#1086#1084' '#1073#1077#1079' '#1076#1077#1083#1100#1090
        ParentShowHint = False
        ShowHint = True
        TabOrder = 1
        OnClick = OnFlagChange
      end
      object cbChecksum: TCheckBox
        Left = 296
        Top = 4
        Width = 264
        Height = 17
        Hint =
          #1050#1083#1102#1095': -c. '#1057#1088#1072#1074#1085#1077#1085#1080#1077' '#1087#1086' checksum '#1074#1084#1077#1089#1090#1086' '#1088#1072#1079#1084#1077#1088#1072'+'#1074#1088#1077#1084#1077#1085#1080' ('#1084#1077#1076#1083#1077#1085#1085#1086 +
          ', '#1085#1086' '#1085#1072#1076#1105#1078#1085#1086').'
        Caption = #1057#1088#1072#1074#1085#1080#1074#1072#1090#1100' '#1087#1086' '#1089#1091#1084#1084#1077
        ParentShowHint = False
        ShowHint = True
        TabOrder = 2
        OnClick = OnFlagChange
      end
      object cbSizeOnly: TCheckBox
        Left = 596
        Top = 4
        Width = 264
        Height = 17
        Hint = #1050#1083#1102#1095': --size-only. '#1057#1088#1072#1074#1085#1080#1074#1072#1090#1100' '#1090#1086#1083#1100#1082#1086' '#1087#1086' '#1088#1072#1079#1084#1077#1088#1091' '#1092#1072#1081#1083#1072'.'
        Caption = #1058#1086#1083#1100#1082#1086' '#1088#1072#1079#1084#1077#1088
        ParentShowHint = False
        ShowHint = True
        TabOrder = 3
        OnClick = OnFlagChange
      end
      object cbIgnoreTimes: TCheckBox
        Left = 6
        Top = 30
        Width = 264
        Height = 17
        Hint =
          #1050#1083#1102#1095': -I. '#1053#1077' '#1087#1088#1086#1087#1091#1089#1082#1072#1090#1100' '#1092#1072#1081#1083#1099' '#1089' '#1089#1086#1074#1087#1072#1076#1072#1102#1097#1080#1084' '#1074#1088#1077#1084#1077#1085#1077#1084' - '#1089#1088#1072#1074#1085#1080#1074#1072#1090 +
          #1100' '#1074#1089#1077'.'
        Caption = #1048#1075#1085#1086#1088#1080#1088#1086#1074#1072#1090#1100' '#1074#1088#1077#1084#1103
        ParentShowHint = False
        ShowHint = True
        TabOrder = 4
        OnClick = OnFlagChange
      end
      object cbModifyWindow: TCheckBox
        Left = 296
        Top = 30
        Width = 212
        Height = 17
        Hint =
          #1050#1083#1102#1095': --modify-window=N. '#1044#1086#1087#1091#1089#1082' '#1088#1072#1089#1089#1080#1085#1093#1088#1086#1085#1072' '#1074#1088#1077#1084#1077#1085#1080' '#1074' N '#1089#1077#1082#1091#1085#1076' (' +
          #1076#1083#1103' FAT: --modify-window=1).'
        Caption = #1054#1082#1085#1086' '#1074#1088#1077#1084#1077#1085#1080
        ParentShowHint = False
        ShowHint = True
        TabOrder = 5
        OnClick = OnFlagChange
      end
      object edModifyWindow: TEdit
        Left = 520
        Top = 28
        Width = 74
        Height = 21
        TabOrder = 6
        Text = '1'
        OnChange = OnFlagChange
      end
      object cbAppend: TCheckBox
        Left = 596
        Top = 30
        Width = 264
        Height = 17
        Hint =
          #1050#1083#1102#1095': --append. '#1044#1086#1087#1080#1089#1099#1074#1072#1090#1100' '#1090#1086#1083#1100#1082#1086' '#1085#1077#1076#1086#1089#1090#1072#1102#1097#1080#1081' '#1093#1074#1086#1089#1090' '#1073#1086#1083#1100#1096#1080#1093' '#1092#1072#1081#1083 +
          #1086#1074' ('#1073#1077#1079' '#1087#1088#1086#1074#1077#1088#1082#1080' '#1089#1086#1076#1077#1088#1078#1080#1084#1086#1075#1086').'
        Caption = #1044#1086#1087#1080#1089#1099#1074#1072#1090#1100
        ParentShowHint = False
        ShowHint = True
        TabOrder = 7
        OnClick = OnFlagChange
      end
      object cbAppendVerify: TCheckBox
        Left = 6
        Top = 56
        Width = 264
        Height = 17
        Hint =
          #1050#1083#1102#1095': --append-verify. '#1044#1086#1087#1080#1089#1099#1074#1072#1090#1100' '#1093#1074#1086#1089#1090' '#1089' '#1087#1088#1086#1074#1077#1088#1082#1086#1081' '#1082#1086#1085#1090#1088#1086#1083#1100#1085#1086#1081' ' +
          #1089#1091#1084#1084#1099'.'
        Caption = #1044#1086#1087#1080#1089#1099#1074#1072#1090#1100' '#1089' '#1087#1088#1086#1074#1077#1088#1082#1086#1081
        ParentShowHint = False
        ShowHint = True
        TabOrder = 8
        OnClick = OnFlagChange
      end
      object cbUpdate: TCheckBox
        Left = 296
        Top = 56
        Width = 264
        Height = 17
        Hint = #1050#1083#1102#1095': -u. '#1055#1088#1086#1087#1091#1089#1082#1072#1090#1100' '#1092#1072#1081#1083#1099', '#1091' '#1082#1086#1090#1086#1088#1099#1093' '#1087#1088#1080#1105#1084#1085#1080#1082' '#1085#1086#1074#1077#1077' '#1080#1089#1090#1086#1095#1085#1080#1082#1072'.'
        Caption = #1058#1086#1083#1100#1082#1086' '#1085#1086#1074#1099#1077
        ParentShowHint = False
        ShowHint = True
        TabOrder = 9
        OnClick = OnFlagChange
      end
      object cbExisting: TCheckBox
        Left = 596
        Top = 56
        Width = 264
        Height = 17
        Hint =
          #1050#1083#1102#1095': --existing. '#1054#1073#1085#1086#1074#1083#1103#1090#1100' '#1090#1086#1083#1100#1082#1086' '#1092#1072#1081#1083#1099', '#1091#1078#1077' '#1089#1091#1097#1077#1089#1090#1074#1091#1102#1097#1080#1077' '#1074' '#1087#1088#1080 +
          #1105#1084#1085#1080#1082#1077'.'
        Caption = #1058#1086#1083#1100#1082#1086' '#1089#1091#1097#1077#1089#1090#1074#1091#1102#1097#1080#1077
        ParentShowHint = False
        ShowHint = True
        TabOrder = 10
        OnClick = OnFlagChange
      end
      object cbIgnoreExisting: TCheckBox
        Left = 6
        Top = 82
        Width = 264
        Height = 17
        Hint =
          #1050#1083#1102#1095': --ignore-existing. '#1053#1077' '#1086#1073#1085#1086#1074#1083#1103#1090#1100' '#1092#1072#1081#1083#1099', '#1082#1086#1090#1086#1088#1099#1077' '#1091#1078#1077' '#1077#1089#1090#1100' '#1074' ' +
          #1087#1088#1080#1105#1084#1085#1080#1082#1077'.'
        Caption = #1048#1075#1085#1086#1088#1080#1088#1086#1074#1072#1090#1100' '#1089#1091#1097#1077#1089#1090#1074#1091#1102#1097#1080#1077
        ParentShowHint = False
        ShowHint = True
        TabOrder = 11
        OnClick = OnFlagChange
      end
      object cbBackup: TCheckBox
        Left = 296
        Top = 82
        Width = 264
        Height = 17
        Hint =
          #1050#1083#1102#1095': --backup. '#1057#1086#1093#1088#1072#1085#1103#1090#1100' '#1087#1077#1088#1077#1079#1072#1087#1080#1089#1099#1074#1072#1077#1084#1099#1077'/'#1091#1076#1072#1083#1103#1077#1084#1099#1077' '#1092#1072#1081#1083#1099' '#1074' '#1073#1101#1082 +
          #1072#1087'-'#1076#1080#1088#1077#1082#1090#1086#1088#1080#1102'.'
        Caption = #1056#1077#1079#1077#1088#1074#1085#1099#1077' '#1082#1086#1087#1080#1080
        ParentShowHint = False
        ShowHint = True
        TabOrder = 12
        OnClick = OnFlagChange
      end
      object cbBackupDir: TCheckBox
        Left = 596
        Top = 82
        Width = 212
        Height = 17
        Hint =
          #1050#1083#1102#1095': --backup-dir=DIR. '#1050#1091#1076#1072' '#1089#1082#1083#1072#1076#1099#1074#1072#1090#1100' '#1088#1077#1079#1077#1088#1074#1085#1099#1077' '#1082#1086#1087#1080#1080' ('#1085#1072#1087#1088#1080#1084#1077 +
          #1088' /var/backup/prev).'
        Caption = #1041#1101#1082#1072#1087'-'#1076#1080#1088#1077#1082#1090#1086#1088#1080#1103
        ParentShowHint = False
        ShowHint = True
        TabOrder = 13
        OnClick = OnFlagChange
      end
      object edBackupDir: TEdit
        Left = 820
        Top = 80
        Width = 74
        Height = 21
        TabOrder = 14
        OnChange = OnFlagChange
      end
      object cbSuffix: TCheckBox
        Left = 6
        Top = 108
        Width = 212
        Height = 17
        Hint = #1050#1083#1102#1095': --suffix=SUFFIX. '#1057#1091#1092#1092#1080#1082#1089' '#1088#1077#1079#1077#1088#1074#1085#1099#1093' '#1082#1086#1087#1080#1081' ('#1087#1086' '#1091#1084#1086#1083#1095#1072#1085#1080#1102' ~).'
        Caption = #1057#1091#1092#1092#1080#1082#1089' '#1073#1101#1082#1072#1087#1072
        ParentShowHint = False
        ShowHint = True
        TabOrder = 15
        OnClick = OnFlagChange
      end
      object edSuffix: TEdit
        Left = 220
        Top = 106
        Width = 74
        Height = 21
        TabOrder = 16
        Text = '~'
        OnChange = OnFlagChange
      end
      object cbRemoveSourceFiles: TCheckBox
        Left = 296
        Top = 108
        Width = 264
        Height = 17
        Hint =
          #1050#1083#1102#1095': --remove-source-files. '#1059#1076#1072#1083#1103#1090#1100' '#1092#1072#1081#1083#1099'-'#1080#1089#1090#1086#1095#1085#1080#1082#1080' '#1087#1086#1089#1083#1077' '#1091#1089#1087#1077#1096 +
          #1085#1086#1081' '#1087#1077#1088#1077#1076#1072#1095#1080' ('#1087#1077#1088#1077#1085#1086#1089').'
        Caption = #1059#1076#1072#1083#1103#1090#1100' '#1080#1089#1090#1086#1095#1085#1080#1082
        ParentShowHint = False
        ShowHint = True
        TabOrder = 17
        OnClick = OnFlagChange
      end
      object cbPartial: TCheckBox
        Left = 596
        Top = 108
        Width = 264
        Height = 17
        Hint =
          #1050#1083#1102#1095': --partial. '#1054#1089#1090#1072#1074#1083#1103#1090#1100' '#1085#1077#1076#1086#1087#1077#1088#1077#1076#1072#1085#1085#1099#1077' '#1092#1072#1081#1083#1099' '#1076#1083#1103' '#1087#1088#1086#1076#1086#1083#1078#1077#1085#1080#1103' ' +
          #1087#1086#1090#1086#1084'.'
        Caption = #1063#1072#1089#1090#1080#1095#1085#1099#1077' '#1092#1072#1081#1083#1099
        ParentShowHint = False
        ShowHint = True
        TabOrder = 0
        OnClick = OnFlagChange
      end
    end
    object tsDelete: TTabSheet
      Caption = #1059#1076#1072#1083#1077#1085#1080#1077
      object cbDelete: TCheckBox
        Left = 6
        Top = 4
        Width = 264
        Height = 17
        Hint =
          #1050#1083#1102#1095': --delete. '#1059#1076#1072#1083#1103#1090#1100' '#1074' '#1087#1088#1080#1105#1084#1085#1080#1082#1077' '#1092#1072#1081#1083#1099', '#1082#1086#1090#1086#1088#1099#1093' '#1085#1077#1090' '#1074' '#1080#1089#1090#1086#1095#1085#1080 +
          #1082#1077' ('#1079#1077#1088#1082#1072#1083#1080#1088#1086#1074#1072#1085#1080#1077'). '#1054#1089#1090#1086#1088#1086#1078#1085#1086'!'
        Caption = #1059#1076#1072#1083#1080#1090#1100' '#1083#1080#1096#1085#1077#1077
        ParentShowHint = False
        ShowHint = True
        TabOrder = 1
        OnClick = OnFlagChange
      end
      object cbDeleteBefore: TCheckBox
        Left = 296
        Top = 4
        Width = 264
        Height = 17
        Hint = #1050#1083#1102#1095': --delete-before. '#1059#1076#1072#1083#1080#1090#1100' '#1083#1080#1096#1085#1077#1077' '#1076#1086' '#1085#1072#1095#1072#1083#1072' '#1087#1077#1088#1077#1076#1072#1095#1080'.'
        Caption = #1059#1076#1072#1083#1103#1090#1100' '#1076#1086' '#1087#1077#1088#1077#1076#1072#1095#1080
        ParentShowHint = False
        ShowHint = True
        TabOrder = 2
        OnClick = OnFlagChange
      end
      object cbDeleteDelay: TCheckBox
        Left = 596
        Top = 4
        Width = 264
        Height = 17
        Hint =
          #1050#1083#1102#1095': --delete-delay. '#1059#1076#1072#1083#1080#1090#1100' '#1083#1080#1096#1085#1077#1077' '#1074' '#1082#1086#1085#1094#1077' '#1087#1077#1088#1077#1076#1072#1095#1080' ('#1086#1076#1085#1080#1084' '#1087#1088#1086 +
          #1093#1086#1076#1086#1084', '#1073#1099#1089#1090#1088#1077#1077' than-during).'
        Caption = #1059#1076#1072#1083#1103#1090#1100' '#1074' '#1082#1086#1085#1094#1077
        ParentShowHint = False
        ShowHint = True
        TabOrder = 3
        OnClick = OnFlagChange
      end
      object cbDeleteAfter: TCheckBox
        Left = 6
        Top = 30
        Width = 264
        Height = 17
        Hint = #1050#1083#1102#1095': --delete-after. '#1059#1076#1072#1083#1080#1090#1100' '#1083#1080#1096#1085#1077#1077' '#1087#1086#1089#1083#1077' '#1074#1089#1077#1093' '#1087#1077#1088#1077#1076#1072#1095'.'
        Caption = #1059#1076#1072#1083#1103#1090#1100' '#1087#1086#1089#1083#1077' '#1087#1077#1088#1077#1076#1072#1095#1080
        ParentShowHint = False
        ShowHint = True
        TabOrder = 4
        OnClick = OnFlagChange
      end
      object cbDeleteExcluded: TCheckBox
        Left = 296
        Top = 30
        Width = 264
        Height = 17
        Hint =
          #1050#1083#1102#1095': --delete-excluded. '#1058#1072#1082#1078#1077' '#1091#1076#1072#1083#1103#1090#1100' '#1074' '#1087#1088#1080#1105#1084#1085#1080#1082#1077' '#1092#1072#1081#1083#1099', '#1087#1086#1087#1072#1076#1072 +
          #1102#1097#1080#1077' '#1087#1086#1076' exclude/include.'
        Caption = #1059#1076#1072#1083#1103#1090#1100' '#1080#1089#1082#1083#1102#1095#1105#1085#1085#1099#1077
        ParentShowHint = False
        ShowHint = True
        TabOrder = 5
        OnClick = OnFlagChange
      end
      object cbForce: TCheckBox
        Left = 596
        Top = 30
        Width = 264
        Height = 17
        Hint =
          #1050#1083#1102#1095': --force. '#1059#1076#1072#1083#1103#1090#1100' '#1082#1072#1090#1072#1083#1086#1075#1080' '#1074' '#1087#1088#1080#1105#1084#1085#1080#1082#1077', '#1076#1072#1078#1077' '#1077#1089#1083#1080' '#1086#1085#1080' '#1085#1077' '#1087#1091 +
          #1089#1090#1099'.'
        Caption = #1055#1088#1080#1085#1091#1076#1080#1090#1077#1083#1100#1085#1086' '#1087#1086' '#1082#1072#1090#1072#1083#1086#1075#1072#1084
        ParentShowHint = False
        ShowHint = True
        TabOrder = 6
        OnClick = OnFlagChange
      end
      object cbIgnoreErrors: TCheckBox
        Left = 6
        Top = 56
        Width = 264
        Height = 17
        Hint =
          #1050#1083#1102#1095': --ignore-errors. '#1055#1088#1086#1076#1086#1083#1078#1072#1090#1100' '#1091#1076#1072#1083#1077#1085#1080#1077' '#1076#1072#1078#1077' '#1087#1088#1080' '#1086#1096#1080#1073#1082#1072#1093' '#1087#1077#1088#1077 +
          #1076#1072#1095#1080'.'
        Caption = #1048#1075#1085#1086#1088#1080#1088#1086#1074#1072#1090#1100' '#1086#1096#1080#1073#1082#1080
        ParentShowHint = False
        ShowHint = True
        TabOrder = 7
        OnClick = OnFlagChange
      end
      object cbMaxDelete: TCheckBox
        Left = 296
        Top = 56
        Width = 212
        Height = 17
        Hint =
          #1050#1083#1102#1095': --max-delete=N. '#1053#1077' '#1091#1076#1072#1083#1103#1090#1100' '#1073#1086#1083#1100#1096#1077' N '#1092#1072#1081#1083#1086#1074' ('#1089#1090#1088#1072#1093#1086#1074#1082#1072' '#1087#1088#1080' ' +
          '--delete).'
        Caption = #1051#1080#1084#1080#1090' '#1091#1076#1072#1083#1077#1085#1080#1081
        ParentShowHint = False
        ShowHint = True
        TabOrder = 8
        OnClick = OnFlagChange
      end
      object edMaxDelete: TEdit
        Left = 520
        Top = 54
        Width = 74
        Height = 21
        TabOrder = 9
        Text = '500'
        OnChange = OnFlagChange
      end
      object cbDelayUpdates: TCheckBox
        Left = 596
        Top = 56
        Width = 264
        Height = 17
        Hint =
          #1050#1083#1102#1095': --delay-updates. '#1053#1072#1082#1086#1087#1080#1090#1100' '#1074#1088#1077#1084#1077#1085#1085#1099#1077' '#1092#1072#1081#1083#1099' '#1080' '#1087#1077#1088#1077#1080#1084#1077#1085#1086#1074#1072#1090#1100' ' +
          #1074' '#1082#1086#1085#1094#1077' ('#1072#1090#1086#1084#1072#1088#1085#1077#1077').'
        Caption = #1054#1090#1083#1086#1078#1080#1090#1100' '#1086#1073#1085#1086#1074#1083#1077#1085#1080#1103
        ParentShowHint = False
        ShowHint = True
        TabOrder = 0
        OnClick = OnFlagChange
      end
    end
    object tsFilters: TTabSheet
      Caption = #1060#1080#1083#1100#1090#1088#1099
      object cbExclude: TCheckBox
        Left = 6
        Top = 4
        Width = 300
        Height = 17
        Hint =
          #1050#1083#1102#1095': --exclude=PATTERN. '#1052#1072#1089#1082#1080' '#1080#1089#1082#1083#1102#1095#1077#1085#1080#1103', '#1087#1086' '#1086#1076#1085#1086#1081' '#1085#1072' '#1089#1090#1088#1086#1082#1091'. '#1055 +
          #1088#1080#1084#1077#1088#1099': *.log, cache/*, .git/'
        Caption = #1048#1089#1082#1083#1102#1095#1080#1090#1100
        ParentShowHint = False
        ShowHint = True
        TabOrder = 1
        OnClick = OnFlagChange
      end
      object mExclude: TMemo
        Left = 6
        Top = 22
        Width = 880
        Height = 58
        ParentShowHint = False
        ScrollBars = ssVertical
        ShowHint = True
        TabOrder = 2
        OnChange = OnFlagChange
      end
      object cbInclude: TCheckBox
        Left = 6
        Top = 84
        Width = 300
        Height = 17
        Hint =
          #1050#1083#1102#1095': --include=PATTERN. '#1052#1072#1089#1082#1080' '#1074#1082#1083#1102#1095#1077#1085#1080#1103' ('#1087#1077#1088#1077#1082#1088#1099#1074#1072#1102#1090' exclude). ' +
          #1055#1086' '#1086#1076#1085#1086#1081' '#1085#1072' '#1089#1090#1088#1086#1082#1091'.'
        Caption = #1042#1082#1083#1102#1095#1080#1090#1100
        ParentShowHint = False
        ShowHint = True
        TabOrder = 3
        OnClick = OnFlagChange
      end
      object mInclude: TMemo
        Left = 6
        Top = 102
        Width = 880
        Height = 58
        ParentShowHint = False
        ScrollBars = ssVertical
        ShowHint = True
        TabOrder = 4
        OnChange = OnFlagChange
      end
      object cbExcludeFrom: TCheckBox
        Left = 6
        Top = 164
        Width = 212
        Height = 17
        Hint = #1050#1083#1102#1095': --exclude-from=FILE. '#1060#1072#1081#1083' '#1089#1086' '#1089#1087#1080#1089#1082#1086#1084' '#1084#1072#1089#1086#1082' '#1080#1089#1082#1083#1102#1095#1077#1085#1080#1103'.'
        Caption = #1048#1089#1082#1083#1102#1095#1080#1090#1100' '#1080#1079' '#1092#1072#1081#1083#1072
        ParentShowHint = False
        ShowHint = True
        TabOrder = 5
        OnClick = OnFlagChange
      end
      object edExcludeFrom: TEdit
        Left = 220
        Top = 162
        Width = 74
        Height = 21
        TabOrder = 6
        OnChange = OnFlagChange
      end
      object cbIncludeFrom: TCheckBox
        Left = 296
        Top = 164
        Width = 212
        Height = 17
        Hint = #1050#1083#1102#1095': --include-from=FILE. '#1060#1072#1081#1083' '#1089#1086' '#1089#1087#1080#1089#1082#1086#1084' '#1084#1072#1089#1086#1082' '#1074#1082#1083#1102#1095#1077#1085#1080#1103'.'
        Caption = #1042#1082#1083#1102#1095#1080#1090#1100' '#1080#1079' '#1092#1072#1081#1083#1072
        ParentShowHint = False
        ShowHint = True
        TabOrder = 7
        OnClick = OnFlagChange
      end
      object edIncludeFrom: TEdit
        Left = 520
        Top = 162
        Width = 74
        Height = 21
        TabOrder = 8
        OnChange = OnFlagChange
      end
      object cbFilter: TCheckBox
        Left = 596
        Top = 164
        Width = 212
        Height = 17
        Hint =
          #1050#1083#1102#1095': --filter=RULE. '#1071#1074#1085#1086#1077' '#1087#1088#1072#1074#1080#1083#1086' '#1092#1080#1083#1100#1090#1088#1072' rsync, '#1085#1072#1087#1088#1080#1084#1077#1088' '#39'dir-' +
          'merge /.rsync-filter'#39'.'
        Caption = #1055#1088#1072#1074#1080#1083#1086' '#1092#1080#1083#1100#1090#1088#1072
        ParentShowHint = False
        ShowHint = True
        TabOrder = 9
        OnClick = OnFlagChange
      end
      object edFilter: TEdit
        Left = 820
        Top = 162
        Width = 74
        Height = 21
        TabOrder = 10
        OnChange = OnFlagChange
      end
      object cbFilesFrom: TCheckBox
        Left = 6
        Top = 190
        Width = 212
        Height = 17
        Hint =
          #1050#1083#1102#1095': --files-from=FILE. '#1055#1077#1088#1077#1076#1072#1090#1100' '#1090#1086#1083#1100#1082#1086' '#1092#1072#1081#1083#1099' '#1080#1079' '#1089#1087#1080#1089#1082#1072' ('#1087#1086#1076#1088#1072#1079 +
          #1091#1084#1077#1074#1072#1077#1090' --relative).'
        Caption = #1057#1087#1080#1089#1086#1082' '#1092#1072#1081#1083#1086#1074
        ParentShowHint = False
        ShowHint = True
        TabOrder = 11
        OnClick = OnFlagChange
      end
      object edFilesFrom: TEdit
        Left = 220
        Top = 188
        Width = 74
        Height = 21
        TabOrder = 12
        OnChange = OnFlagChange
      end
      object cbMaxSize: TCheckBox
        Left = 296
        Top = 190
        Width = 212
        Height = 17
        Hint =
          #1050#1083#1102#1095': --max-size=SIZE. '#1053#1077' '#1087#1077#1088#1077#1076#1072#1074#1072#1090#1100' '#1092#1072#1081#1083#1099' '#1073#1086#1083#1100#1096#1077' '#1091#1082#1072#1079#1072#1085#1085#1086#1075#1086' ('#1085#1072 +
          #1087#1088#1080#1084#1077#1088' 100M).'
        Caption = #1052#1072#1082#1089'. '#1088#1072#1079#1084#1077#1088
        ParentShowHint = False
        ShowHint = True
        TabOrder = 13
        OnClick = OnFlagChange
      end
      object edMaxSize: TEdit
        Left = 520
        Top = 188
        Width = 74
        Height = 21
        TabOrder = 14
        Text = '100M'
        OnChange = OnFlagChange
      end
      object cbMinSize: TCheckBox
        Left = 596
        Top = 190
        Width = 212
        Height = 17
        Hint =
          #1050#1083#1102#1095': --min-size=SIZE. '#1053#1077' '#1087#1077#1088#1077#1076#1072#1074#1072#1090#1100' '#1092#1072#1081#1083#1099' '#1084#1077#1085#1100#1096#1077' '#1091#1082#1072#1079#1072#1085#1085#1086#1075#1086' ('#1085#1072 +
          #1087#1088#1080#1084#1077#1088' 1M).'
        Caption = #1052#1080#1085'. '#1088#1072#1079#1084#1077#1088
        ParentShowHint = False
        ShowHint = True
        TabOrder = 15
        OnClick = OnFlagChange
      end
      object edMinSize: TEdit
        Left = 820
        Top = 188
        Width = 74
        Height = 21
        TabOrder = 16
        Text = '1M'
        OnChange = OnFlagChange
      end
      object cbPruneEmptyDirs: TCheckBox
        Left = 6
        Top = 216
        Width = 264
        Height = 17
        Hint = #1050#1083#1102#1095': -m. '#1053#1077' '#1089#1086#1079#1076#1072#1074#1072#1090#1100' '#1087#1091#1089#1090#1099#1077' '#1094#1077#1087#1086#1095#1082#1080' '#1082#1072#1090#1072#1083#1086#1075#1086#1074' '#1074' '#1087#1088#1080#1105#1084#1085#1080#1082#1077'.'
        Caption = #1059#1073#1080#1088#1072#1090#1100' '#1087#1091#1089#1090#1099#1077' '#1082#1072#1090#1072#1083#1086#1075#1080
        ParentShowHint = False
        ShowHint = True
        TabOrder = 17
        OnClick = OnFlagChange
      end
      object cbCvsExclude: TCheckBox
        Left = 296
        Top = 216
        Width = 264
        Height = 17
        Hint = #1050#1083#1102#1095': -C. '#1040#1074#1090#1086'-'#1080#1089#1082#1083#1102#1095#1077#1085#1080#1077' '#1087#1086' '#1087#1088#1072#1074#1080#1083#1072#1084' CVS (RCS, .git '#1080' '#1090'.'#1087'.).'
        Caption = #1050#1072#1082' '#1074' CVS'
        ParentShowHint = False
        ShowHint = True
        TabOrder = 18
        OnClick = OnFlagChange
      end
      object cbRelative: TCheckBox
        Left = 596
        Top = 216
        Width = 264
        Height = 17
        Hint = #1050#1083#1102#1095': -R. '#1057#1086#1093#1088#1072#1085#1103#1090#1100' '#1089#1090#1088#1091#1082#1090#1091#1088#1091' '#1087#1091#1090#1077#1081' '#1080#1089#1090#1086#1095#1085#1080#1082#1072' '#1074' '#1087#1088#1080#1105#1084#1085#1080#1082#1077'.'
        Caption = #1054#1090#1085#1086#1089#1080#1090#1077#1083#1100#1085#1099#1077' '#1087#1091#1090#1080
        ParentShowHint = False
        ShowHint = True
        TabOrder = 19
        OnClick = OnFlagChange
      end
      object cbNoImpliedDirs: TCheckBox
        Left = 6
        Top = 242
        Width = 264
        Height = 17
        Hint =
          #1050#1083#1102#1095': --no-implied-dirs. '#1053#1077' '#1089#1086#1079#1076#1072#1074#1072#1090#1100' '#1082#1072#1090#1072#1083#1086#1075#1080', '#1074#1086#1079#1085#1080#1082#1096#1080#1077' '#1080#1079' '#1086#1090#1085 +
          #1086#1089#1080#1090#1077#1083#1100#1085#1086#1075#1086' '#1087#1091#1090#1080', '#1077#1089#1083#1080' '#1085#1077#1090' '#1092#1072#1081#1083#1086#1074'.'
        Caption = #1041#1077#1079' implied-'#1082#1072#1090#1072#1083#1086#1075#1086#1074
        ParentShowHint = False
        ShowHint = True
        TabOrder = 0
        OnClick = OnFlagChange
      end
    end
    object tsPerms: TTabSheet
      Caption = #1055#1088#1072#1074#1072' '#1080' '#1089#1089#1099#1083#1082#1080
      object cbChmod: TCheckBox
        Left = 6
        Top = 4
        Width = 212
        Height = 17
        Hint = #1050#1083#1102#1095': --chmod=CHMOD. '#1055#1077#1088#1077#1086#1087#1088#1077#1076#1077#1083#1080#1090#1100' '#1087#1088#1072#1074#1072', '#1085#1072#1087#1088#1080#1084#1077#1088' D755,F644.'
        Caption = #1055#1088#1072#1074#1072' '#1074' '#1103#1074#1085#1086#1084' '#1074#1080#1076#1077
        ParentShowHint = False
        ShowHint = True
        TabOrder = 1
        OnClick = OnFlagChange
      end
      object edChmod: TEdit
        Left = 220
        Top = 2
        Width = 74
        Height = 21
        TabOrder = 2
        OnChange = OnFlagChange
      end
      object cbNumericIds: TCheckBox
        Left = 296
        Top = 4
        Width = 264
        Height = 17
        Hint = #1050#1083#1102#1095': --numeric-ids. '#1053#1077' '#1087#1088#1077#1086#1073#1088#1072#1079#1086#1074#1099#1074#1072#1090#1100' uid/gid '#1074' '#1080#1084#1077#1085#1072'.'
        Caption = #1063#1080#1089#1083#1086#1074#1099#1077' ID'
        ParentShowHint = False
        ShowHint = True
        TabOrder = 3
        OnClick = OnFlagChange
      end
      object cbSuper: TCheckBox
        Left = 596
        Top = 4
        Width = 264
        Height = 17
        Hint =
          #1050#1083#1102#1095': --super. '#1056#1072#1073#1086#1090#1072#1090#1100' '#1082#1072#1082' root, '#1076#1072#1078#1077' '#1077#1089#1083#1080' '#1101#1090#1086' '#1085#1077' '#1090#1072#1082' ('#1076#1083#1103' rsyn' +
          'c-'#1076#1077#1084#1086#1085#1072').'
        Caption = #1048#1075#1085#1086#1088#1080#1088#1086#1074#1072#1090#1100' '#1085#1077'-root'
        ParentShowHint = False
        ShowHint = True
        TabOrder = 4
        OnClick = OnFlagChange
      end
      object cbFakeSuper: TCheckBox
        Left = 6
        Top = 30
        Width = 264
        Height = 17
        Hint =
          #1050#1083#1102#1095': --fake-super. '#1057#1086#1093#1088#1072#1085#1103#1090#1100' '#1087#1088#1072#1074#1072'/'#1074#1083#1072#1076#1077#1083#1100#1094#1072' '#1074' xattr '#1073#1077#1079' '#1088#1077#1072#1083#1100#1085 +
          #1086#1075#1086' root.'
        Caption = #1069#1084#1091#1083#1103#1094#1080#1103' root'
        ParentShowHint = False
        ShowHint = True
        TabOrder = 5
        OnClick = OnFlagChange
      end
      object cbUsermap: TCheckBox
        Left = 296
        Top = 30
        Width = 212
        Height = 17
        Hint =
          #1050#1083#1102#1095': --usermap=MAP. '#1055#1088#1072#1074#1080#1083#1086' '#1079#1072#1084#1077#1085#1099' '#1074#1083#1072#1076#1077#1083#1100#1094#1072', '#1085#1072#1087#1088#1080#1084#1077#1088' root:www' +
          '-data.'
        Caption = #1047#1072#1084#1077#1085#1072' '#1074#1083#1072#1076#1077#1083#1100#1094#1072
        ParentShowHint = False
        ShowHint = True
        TabOrder = 6
        OnClick = OnFlagChange
      end
      object edUsermap: TEdit
        Left = 520
        Top = 28
        Width = 74
        Height = 21
        TabOrder = 7
        OnChange = OnFlagChange
      end
      object cbGroupmap: TCheckBox
        Left = 596
        Top = 30
        Width = 212
        Height = 17
        Hint = #1050#1083#1102#1095': --groupmap=MAP. '#1055#1088#1072#1074#1080#1083#1086' '#1079#1072#1084#1077#1085#1099' '#1075#1088#1091#1087#1087#1099'.'
        Caption = #1047#1072#1084#1077#1085#1072' '#1075#1088#1091#1087#1087#1099
        ParentShowHint = False
        ShowHint = True
        TabOrder = 8
        OnClick = OnFlagChange
      end
      object edGroupmap: TEdit
        Left = 820
        Top = 28
        Width = 74
        Height = 21
        TabOrder = 9
        OnChange = OnFlagChange
      end
      object cbSafeLinks: TCheckBox
        Left = 6
        Top = 56
        Width = 264
        Height = 17
        Hint =
          #1050#1083#1102#1095': --safe-links. '#1048#1075#1085#1086#1088#1080#1088#1086#1074#1072#1090#1100' '#1089#1080#1084#1083#1080#1085#1082#1080', '#1091#1082#1072#1079#1099#1074#1072#1102#1097#1080#1077' '#1079#1072' '#1087#1088#1077#1076#1077#1083 +
          #1099' '#1076#1077#1088#1077#1074#1072'.'
        Caption = #1041#1077#1079#1086#1087#1072#1089#1085#1099#1077' '#1089#1089#1099#1083#1082#1080
        ParentShowHint = False
        ShowHint = True
        TabOrder = 10
        OnClick = OnFlagChange
      end
      object cbCopyUnsafeLinks: TCheckBox
        Left = 296
        Top = 56
        Width = 264
        Height = 17
        Hint =
          #1050#1083#1102#1095': --copy-unsafe-links. '#1057#1080#1084#1083#1080#1085#1082' '#1079#1072' '#1087#1088#1077#1076#1077#1083#1099' '#1076#1077#1088#1077#1074#1072' '#1079#1072#1084#1077#1085#1103#1077#1090#1089#1103' ' +
          #1082#1086#1087#1080#1077#1081' '#1077#1075#1086' '#1094#1077#1083#1080'.'
        Caption = #1050#1086#1087#1080#1088#1086#1074#1072#1090#1100' '#1094#1077#1083#1080' '#1085#1077#1085#1072#1076#1105#1078#1085#1099#1093' '#1089#1089#1099#1083#1086#1082
        ParentShowHint = False
        ShowHint = True
        TabOrder = 11
        OnClick = OnFlagChange
      end
      object cbCopyDirlinks: TCheckBox
        Left = 596
        Top = 56
        Width = 264
        Height = 17
        Hint =
          #1050#1083#1102#1095': --copy-dirlinks. '#1057#1080#1084#1083#1080#1085#1082' '#1085#1072' '#1082#1072#1090#1072#1083#1086#1075' '#1082#1086#1087#1080#1088#1086#1074#1072#1090#1100' '#1082#1072#1082' '#1089#1080#1084#1083#1080#1085#1082 +
          '.'
        Caption = #1057#1089#1099#1083#1082#1080' '#1085#1072' '#1082#1072#1090#1072#1083#1086#1075#1080' '#1082#1086#1087#1080#1088#1086#1074#1072#1090#1100
        ParentShowHint = False
        ShowHint = True
        TabOrder = 12
        OnClick = OnFlagChange
      end
      object cbKeepDirlinks: TCheckBox
        Left = 6
        Top = 82
        Width = 264
        Height = 17
        Hint =
          #1050#1083#1102#1095': -k. '#1045#1089#1083#1080' '#1074' '#1087#1088#1080#1105#1084#1085#1080#1082#1077' '#1085#1072' '#1084#1077#1089#1090#1077' '#1082#1072#1090#1072#1083#1086#1075#1072' '#1089#1080#1084#1083#1080#1085#1082' - '#1087#1077#1088#1077#1076#1072#1074#1072#1090 +
          #1100' '#1074' '#1077#1075#1086' '#1094#1077#1083#1100'.'
        Caption = #1050#1072#1090#1072#1083#1086#1075'-'#1089#1089#1099#1083#1082#1091' '#1086#1089#1090#1072#1074#1080#1090#1100
        ParentShowHint = False
        ShowHint = True
        TabOrder = 0
        OnClick = OnFlagChange
      end
    end
    object tsSSH: TTabSheet
      Caption = 'SSH '#1080' '#1089#1077#1090#1100
      object cbCompress: TCheckBox
        Left = 6
        Top = 4
        Width = 264
        Height = 17
        Hint =
          #1050#1083#1102#1095': -z. '#1057#1078#1080#1084#1072#1090#1100' '#1076#1072#1085#1085#1099#1077' '#1087#1088#1080' '#1087#1077#1088#1077#1076#1072#1095#1077' ('#1087#1086#1083#1077#1079#1085#1086' '#1087#1086' '#1084#1077#1076#1083#1077#1085#1085#1086#1084#1091' '#1082#1072#1085 +
          #1072#1083#1091').'
        Caption = #1057#1078#1072#1090#1080#1077
        ParentShowHint = False
        ShowHint = True
        TabOrder = 1
        OnClick = OnFlagChange
      end
      object cbCompressLevel: TCheckBox
        Left = 296
        Top = 4
        Width = 212
        Height = 17
        Hint = #1050#1083#1102#1095': --compress-level=N. '#1071#1074#1085#1099#1081' '#1091#1088#1086#1074#1077#1085#1100' zlib (1..9).'
        Caption = #1059#1088#1086#1074#1077#1085#1100' '#1089#1078#1072#1090#1080#1103
        ParentShowHint = False
        ShowHint = True
        TabOrder = 2
        OnClick = OnFlagChange
      end
      object edCompressLevel: TEdit
        Left = 520
        Top = 2
        Width = 74
        Height = 21
        TabOrder = 3
        Text = '6'
        OnChange = OnFlagChange
      end
      object cbRsh: TCheckBox
        Left = 596
        Top = 4
        Width = 212
        Height = 17
        Hint =
          #1050#1083#1102#1095': --rsh=CMD. '#1055#1077#1088#1077#1086#1087#1088#1077#1076#1077#1083#1103#1077#1090' SSH-'#1089#1090#1088#1086#1082#1091' '#1094#1077#1083#1080#1082#1086#1084', '#1085#1072#1087#1088#1080#1084#1077#1088' '#39'ss' +
          'h -p 2222 -i /home/user/.ssh/id_ed25519'#39'. '#1045#1089#1083#1080' '#1079#1072#1076#1072#1085' - '#1087#1086#1083#1103' '#1088#1077#1078#1080 +
          #1084#1072' SSH '#1080#1075#1085#1086#1088#1080#1088#1091#1102#1090#1089#1103'.'
        Caption = #1057#1074#1086#1081' '#1090#1088#1072#1085#1089#1087#1086#1088#1090
        ParentShowHint = False
        ShowHint = True
        TabOrder = 4
        OnClick = OnFlagChange
      end
      object edRsh: TEdit
        Left = 820
        Top = 2
        Width = 74
        Height = 21
        TabOrder = 5
        OnChange = OnFlagChange
      end
      object cbTimeout: TCheckBox
        Left = 6
        Top = 30
        Width = 212
        Height = 17
        Hint =
          #1050#1083#1102#1095': --timeout=SECONDS. '#1055#1088#1077#1088#1074#1072#1090#1100' '#1074#1080#1089#1103#1097#1091#1102' '#1087#1077#1088#1077#1076#1072#1095#1091' '#1095#1077#1088#1077#1079' N '#1089#1077#1082#1091#1085 +
          #1076'.'
        Caption = #1058#1072#1081#1084#1072#1091#1090
        ParentShowHint = False
        ShowHint = True
        TabOrder = 6
        OnClick = OnFlagChange
      end
      object edTimeout: TEdit
        Left = 220
        Top = 28
        Width = 74
        Height = 21
        TabOrder = 7
        Text = '300'
        OnChange = OnFlagChange
      end
      object cbBwlimit: TCheckBox
        Left = 296
        Top = 30
        Width = 212
        Height = 17
        Hint =
          #1050#1083#1102#1095': --bwlimit=KBPS. '#1054#1075#1088#1072#1085#1080#1095#1077#1085#1080#1077' '#1089#1082#1086#1088#1086#1089#1090#1080' '#1074' KiB/s ('#1085#1072#1087#1088#1080#1084#1077#1088' 100' +
          '00 = ~10 '#1052#1041'/'#1089').'
        Caption = #1054#1075#1088#1072#1085#1080#1095#1077#1085#1080#1077' '#1082#1072#1085#1072#1083#1072
        ParentShowHint = False
        ShowHint = True
        TabOrder = 8
        OnClick = OnFlagChange
      end
      object edBwlimit: TEdit
        Left = 520
        Top = 28
        Width = 74
        Height = 21
        TabOrder = 9
        Text = '10000'
        OnChange = OnFlagChange
      end
      object cbIpv4: TCheckBox
        Left = 596
        Top = 30
        Width = 264
        Height = 17
        Hint = #1050#1083#1102#1095': -4. '#1055#1088#1077#1076#1087#1086#1095#1080#1090#1072#1090#1100' IPv4-'#1072#1076#1088#1077#1089#1072'.'
        Caption = #1058#1086#1083#1100#1082#1086' IPv4'
        ParentShowHint = False
        ShowHint = True
        TabOrder = 10
        OnClick = OnFlagChange
      end
      object cbIpv6: TCheckBox
        Left = 6
        Top = 56
        Width = 264
        Height = 17
        Hint = #1050#1083#1102#1095': -6. '#1055#1088#1077#1076#1087#1086#1095#1080#1090#1072#1090#1100' IPv6-'#1072#1076#1088#1077#1089#1072'.'
        Caption = #1058#1086#1083#1100#1082#1086' IPv6'
        ParentShowHint = False
        ShowHint = True
        TabOrder = 11
        OnClick = OnFlagChange
      end
      object cbPasswordFile: TCheckBox
        Left = 296
        Top = 56
        Width = 212
        Height = 17
        Hint =
          #1050#1083#1102#1095': --password-file=FILE. '#1055#1072#1088#1086#1083#1100' '#1076#1083#1103' rsync-'#1076#1077#1084#1086#1085#1072' '#1080#1079' '#1092#1072#1081#1083#1072' ('#1085#1077 +
          ' '#1076#1083#1103' SSH-'#1082#1083#1102#1095#1077#1081').'
        Caption = #1060#1072#1081#1083' '#1087#1072#1088#1086#1083#1103
        ParentShowHint = False
        ShowHint = True
        TabOrder = 12
        OnClick = OnFlagChange
      end
      object edPasswordFile: TEdit
        Left = 520
        Top = 54
        Width = 74
        Height = 21
        TabOrder = 13
        OnChange = OnFlagChange
      end
      object cbRsyncPath: TCheckBox
        Left = 596
        Top = 56
        Width = 212
        Height = 17
        Hint =
          #1050#1083#1102#1095': --rsync-path=PATH. '#1055#1091#1090#1100' '#1082' rsync '#1085#1072' '#1091#1076#1072#1083#1105#1085#1085#1086#1081' '#1089#1090#1086#1088#1086#1085#1077', '#1085#1072#1087#1088 +
          #1080#1084#1077#1088' /usr/local/bin/rsync.'
        Caption = #1055#1091#1090#1100' '#1085#1072' '#1089#1077#1088#1074#1077#1088#1077
        ParentShowHint = False
        ShowHint = True
        TabOrder = 14
        OnClick = OnFlagChange
      end
      object edRsyncPath: TEdit
        Left = 820
        Top = 54
        Width = 74
        Height = 21
        TabOrder = 15
        OnChange = OnFlagChange
      end
      object cbSshKey: TCheckBox
        Left = 6
        Top = 82
        Width = 212
        Height = 17
        Hint =
          #1050#1083#1102#1095': --rsh '#1089' -i. '#1044#1086#1073#1072#1074#1080#1090#1100' '#1082' SSH-'#1089#1090#1088#1086#1082#1077' '#1087#1088#1080#1074#1072#1090#1085#1099#1081' '#1082#1083#1102#1095': ssh -i F' +
          'ILE.'
        Caption = #1050#1083#1102#1095' SSH'
        ParentShowHint = False
        ShowHint = True
        TabOrder = 16
        OnClick = OnFlagChange
      end
      object edSshKey: TEdit
        Left = 220
        Top = 80
        Width = 74
        Height = 21
        TabOrder = 17
        OnChange = OnFlagChange
      end
      object cbSshNoStrict: TCheckBox
        Left = 296
        Top = 82
        Width = 212
        Height = 17
        Hint =
          #1044#1086#1073#1072#1074#1080#1090#1100' '#1082' SSH-'#1089#1090#1088#1086#1082#1077' -o StrictHostKeyChecking=accept-new ('#1084#1077#1085#1100#1096 +
          #1077' '#1080#1085#1090#1077#1088#1072#1082#1090#1080#1074#1085#1099#1093' '#1074#1086#1087#1088#1086#1089#1086#1074').'
        Caption = #1054#1090#1082#1083#1102#1095#1080#1090#1100' strict host checking'
        ParentShowHint = False
        ShowHint = True
        TabOrder = 0
        OnClick = OnFlagChange
      end
    end
    object tsLog: TTabSheet
      Caption = #1042#1099#1074#1086#1076' '#1080' '#1083#1086#1075
      object cbVerbose: TCheckBox
        Left = 6
        Top = 4
        Width = 264
        Height = 17
        Hint = #1050#1083#1102#1095': -v. '#1055#1086#1082#1072#1079#1099#1074#1072#1090#1100', '#1082#1072#1082#1080#1077' '#1092#1072#1081#1083#1099' '#1087#1077#1088#1077#1076#1072#1102#1090#1089#1103'.'
        Caption = #1055#1086#1076#1088#1086#1073#1085#1086
        ParentShowHint = False
        ShowHint = True
        TabOrder = 1
        OnClick = OnFlagChange
      end
      object cbQuiet: TCheckBox
        Left = 296
        Top = 4
        Width = 264
        Height = 17
        Hint = #1050#1083#1102#1095': -q. '#1055#1086#1076#1072#1074#1083#1103#1090#1100' '#1080#1085#1092#1086#1088#1084#1072#1094#1080#1086#1085#1085#1099#1077' '#1089#1086#1086#1073#1097#1077#1085#1080#1103'.'
        Caption = #1058#1080#1093#1080#1081' '#1088#1077#1078#1080#1084
        ParentShowHint = False
        ShowHint = True
        TabOrder = 2
        OnClick = OnFlagChange
      end
      object cbItemize: TCheckBox
        Left = 596
        Top = 4
        Width = 264
        Height = 17
        Hint =
          #1050#1083#1102#1095': -i. '#1042#1099#1074#1086#1076#1080#1090#1100' '#1080#1079#1084#1077#1085#1077#1085#1080#1077' '#1087#1086#1089#1090#1088#1086#1095#1085#1086' '#1074' '#1090#1072#1073#1083#1080#1094#1077' '#1082#1086#1076#1086#1074' ('#1087#1086#1083#1077#1079#1085#1086' ' +
          #1089' -v).'
        Caption = #1057#1087#1080#1089#1086#1082' '#1080#1079#1084#1077#1085#1077#1085#1080#1081
        ParentShowHint = False
        ShowHint = True
        TabOrder = 3
        OnClick = OnFlagChange
      end
      object cbStats: TCheckBox
        Left = 6
        Top = 30
        Width = 264
        Height = 17
        Hint =
          #1050#1083#1102#1095': --stats. '#1042#1099#1074#1077#1089#1090#1080' '#1089#1074#1086#1076#1082#1091' '#1074' '#1082#1086#1085#1094#1077': '#1089#1082#1086#1088#1086#1089#1090#1100', '#1086#1073#1098#1105#1084', '#1091#1076#1072#1083#1077#1085#1080#1103 +
          '.'
        Caption = #1057#1090#1072#1090#1080#1089#1090#1080#1082#1072
        ParentShowHint = False
        ShowHint = True
        TabOrder = 4
        OnClick = OnFlagChange
      end
      object cbHumanReadable: TCheckBox
        Left = 296
        Top = 30
        Width = 264
        Height = 17
        Hint = #1050#1083#1102#1095': -h. '#1056#1072#1079#1084#1077#1088#1099' '#1074' K/M/G '#1074#1084#1077#1089#1090#1086' '#1073#1072#1081#1090'.'
        Caption = #1063#1077#1083#1086#1074#1077#1082#1086#1095#1080#1090#1072#1077#1084#1099#1077' '#1088#1072#1079#1084#1077#1088#1099
        ParentShowHint = False
        ShowHint = True
        TabOrder = 5
        OnClick = OnFlagChange
      end
      object cbProgress: TCheckBox
        Left = 596
        Top = 30
        Width = 264
        Height = 17
        Hint = #1050#1083#1102#1095': --progress. '#1055#1086#1082#1072#1079#1099#1074#1072#1090#1100' '#1087#1088#1086#1075#1088#1077#1089#1089' '#1087#1086' '#1082#1072#1078#1076#1086#1084#1091' '#1092#1072#1081#1083#1091'.'
        Caption = #1055#1088#1086#1075#1088#1077#1089#1089
        ParentShowHint = False
        ShowHint = True
        TabOrder = 6
        OnClick = OnFlagChange
      end
      object cbListOnly: TCheckBox
        Left = 6
        Top = 56
        Width = 264
        Height = 17
        Hint =
          #1050#1083#1102#1095': --list-only. '#1055#1086#1082#1072#1079#1072#1090#1100' '#1089#1087#1080#1089#1086#1082' '#1092#1072#1081#1083#1086#1074' '#1080#1089#1090#1086#1095#1085#1080#1082#1072' '#1073#1077#1079' '#1087#1077#1088#1077#1076#1072#1095#1080 +
          '.'
        Caption = #1058#1086#1083#1100#1082#1086' '#1089#1087#1080#1089#1086#1082
        ParentShowHint = False
        ShowHint = True
        TabOrder = 7
        OnClick = OnFlagChange
      end
      object cbOutFormat: TCheckBox
        Left = 296
        Top = 56
        Width = 212
        Height = 17
        Hint = #1050#1083#1102#1095': --out-format=FORMAT. '#1057#1074#1086#1103' '#1089#1090#1088#1086#1082#1072' '#1085#1072' '#1092#1072#1081#1083': %f %b %t '#1080' '#1090'.'#1076'.'
        Caption = #1060#1086#1088#1084#1072#1090' '#1074#1099#1074#1086#1076#1072
        ParentShowHint = False
        ShowHint = True
        TabOrder = 8
        OnClick = OnFlagChange
      end
      object edOutFormat: TEdit
        Left = 520
        Top = 54
        Width = 74
        Height = 21
        TabOrder = 9
        OnChange = OnFlagChange
      end
      object cbLogFile: TCheckBox
        Left = 596
        Top = 56
        Width = 212
        Height = 17
        Hint = #1050#1083#1102#1095': --log-file=FILE. '#1055#1080#1089#1072#1090#1100' '#1083#1086#1075' '#1087#1077#1088#1077#1076#1072#1095#1080' '#1074' '#1092#1072#1081#1083'.'
        Caption = #1051#1086#1075'-'#1092#1072#1081#1083
        ParentShowHint = False
        ShowHint = True
        TabOrder = 10
        OnClick = OnFlagChange
      end
      object edLogFile: TEdit
        Left = 820
        Top = 54
        Width = 74
        Height = 21
        TabOrder = 11
        OnChange = OnFlagChange
      end
      object cbLogFileFormat: TCheckBox
        Left = 6
        Top = 82
        Width = 212
        Height = 17
        Hint = #1050#1083#1102#1095': --log-file-format=FORMAT. '#1060#1086#1088#1084#1072#1090' '#1089#1090#1088#1086#1082' '#1076#1083#1103' --log-file.'
        Caption = #1060#1086#1088#1084#1072#1090' '#1083#1086#1075#1072
        ParentShowHint = False
        ShowHint = True
        TabOrder = 12
        OnClick = OnFlagChange
      end
      object edLogFileFormat: TEdit
        Left = 220
        Top = 80
        Width = 74
        Height = 21
        TabOrder = 0
        OnChange = OnFlagChange
      end
    end
    object tsMisc: TTabSheet
      Caption = #1055#1088#1086#1095#1077#1077
      object cbSparse: TCheckBox
        Left = 6
        Top = 4
        Width = 264
        Height = 17
        Hint = #1050#1083#1102#1095': -S. '#1069#1092#1092#1077#1082#1090#1080#1074#1085#1086' '#1082#1086#1087#1080#1088#1086#1074#1072#1090#1100' '#1092#1072#1081#1083#1099' '#1089' '#1076#1099#1088#1082#1072#1084#1080' (sparse).'
        Caption = #1056#1072#1079#1088#1077#1078#1105#1085#1085#1099#1077' '#1092#1072#1081#1083#1099
        ParentShowHint = False
        ShowHint = True
        TabOrder = 1
        OnClick = OnFlagChange
      end
      object cbInplace: TCheckBox
        Left = 296
        Top = 4
        Width = 264
        Height = 17
        Hint =
          #1050#1083#1102#1095': --inplace. '#1054#1073#1085#1086#1074#1083#1103#1090#1100' '#1092#1072#1081#1083' '#1074' '#1077#1075#1086' '#1073#1083#1086#1082#1072#1093' ('#1076#1083#1103' '#1073#1086#1083#1100#1096#1080#1093' '#1092#1072#1081#1083#1086#1074 +
          ', '#1076#1080#1089#1082#1086#1074' '#1089' '#1086#1075#1088#1072#1085#1080#1095#1077#1085#1080#1077#1084' '#1084#1077#1089#1090#1072').'
        Caption = #1053#1072' '#1084#1077#1089#1090#1077
        ParentShowHint = False
        ShowHint = True
        TabOrder = 2
        OnClick = OnFlagChange
      end
      object cbIconv: TCheckBox
        Left = 596
        Top = 4
        Width = 212
        Height = 17
        Hint =
          #1050#1083#1102#1095': --iconv=FROM,TO. '#1050#1086#1085#1074#1077#1088#1089#1080#1103' '#1080#1084#1105#1085' '#1092#1072#1081#1083#1086#1074', '#1085#1072#1087#1088#1080#1084#1077#1088' utf8,cp12' +
          '51.'
        Caption = #1050#1086#1076#1080#1088#1086#1074#1082#1072
        ParentShowHint = False
        ShowHint = True
        TabOrder = 3
        OnClick = OnFlagChange
      end
      object edIconv: TEdit
        Left = 820
        Top = 2
        Width = 74
        Height = 21
        TabOrder = 4
        Text = 'utf8,cp1251'
        OnChange = OnFlagChange
      end
      object cbCompareDest: TCheckBox
        Left = 6
        Top = 30
        Width = 212
        Height = 17
        Hint =
          #1050#1083#1102#1095': --compare-dest=DIR. '#1060#1072#1081#1083#1099', '#1089#1086#1074#1087#1072#1076#1072#1102#1097#1080#1077' '#1089' DIR, '#1085#1077' '#1087#1077#1088#1077#1076#1072#1102#1090#1089 +
          #1103' ('#1076#1083#1103' '#1089#1088#1072#1074#1085#1077#1085#1080#1103' '#1089' '#1073#1101#1082#1072#1087#1086#1084').'
        Caption = #1053#1077' '#1090#1088#1086#1075#1072#1090#1100' '#1089#1086#1074#1087#1072#1076#1077#1085#1080#1103
        ParentShowHint = False
        ShowHint = True
        TabOrder = 5
        OnClick = OnFlagChange
      end
      object edCompareDest: TEdit
        Left = 220
        Top = 28
        Width = 74
        Height = 21
        TabOrder = 6
        OnChange = OnFlagChange
      end
      object cbLinkDest: TCheckBox
        Left = 296
        Top = 30
        Width = 212
        Height = 17
        Hint =
          #1050#1083#1102#1095': --link-dest=DIR. '#1048#1085#1082#1088#1077#1084#1077#1085#1090#1072#1083#1100#1085#1099#1081' '#1073#1101#1082#1072#1087': '#1085#1077#1080#1079#1084#1077#1085#1080#1074#1096#1080#1077#1089#1103' '#1092#1072#1081 +
          #1083#1099' '#1093#1072#1088#1076#1083#1080#1085#1082#1091#1102#1090#1089#1103' '#1080#1079' DIR.'
        Caption = #1061#1072#1088#1076#1083#1080#1085#1082#1080' '#1080#1079' DIR'
        ParentShowHint = False
        ShowHint = True
        TabOrder = 7
        OnClick = OnFlagChange
      end
      object edLinkDest: TEdit
        Left = 520
        Top = 28
        Width = 74
        Height = 21
        TabOrder = 8
        OnChange = OnFlagChange
      end
      object cbCopyDest: TCheckBox
        Left = 596
        Top = 30
        Width = 212
        Height = 17
        Hint = #1050#1083#1102#1095': --copy-dest=DIR. '#1050#1072#1082' --link-dest, '#1085#1086' '#1082#1086#1087#1080#1088#1086#1074#1072#1085#1080#1077#1084'.'
        Caption = #1050#1086#1087#1080#1080' '#1080#1079' DIR'
        ParentShowHint = False
        ShowHint = True
        TabOrder = 9
        OnClick = OnFlagChange
      end
      object edCopyDest: TEdit
        Left = 820
        Top = 28
        Width = 74
        Height = 21
        TabOrder = 0
        OnChange = OnFlagChange
      end
    end
  end
end
