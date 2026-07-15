object PasswordGenForm: TPasswordGenForm
  Left = 0
  Top = 0
  BorderStyle = bsDialog
  Caption = #1043#1077#1085#1077#1088#1072#1090#1086#1088' '#1087#1072#1088#1086#1083#1077#1081
  ClientHeight = 353
  ClientWidth = 521
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  FormStyle = fsStayOnTop
  Position = poScreenCenter
  OnCloseQuery = FormCloseQuery
  OnKeyDown = FormKeyDown
  OnShortCut = FormShortCut
  TextHeight = 15
  object lbLength: TLabel
    Left = 8
    Top = 3
    Width = 78
    Height = 15
    Caption = #1044#1083#1080#1085#1072' '#1087#1072#1088#1086#1083#1103
  end
  object lbEntropy: TLabel
    Left = 8
    Top = 54
    Width = 53
    Height = 15
    Caption = #1069#1085#1090#1088#1086#1087#1080#1103
  end
  object lbEntropyValue: TLabel
    Left = 72
    Top = 54
    Width = 6
    Height = 15
    Caption = '0'
  end
  object lbPresets: TLabel
    Left = 136
    Top = 3
    Width = 45
    Height = 15
    Caption = #1064#1072#1073#1083#1086#1085
  end
  object seLength: TSpinEdit
    Left = 8
    Top = 24
    Width = 105
    Height = 24
    MaxValue = 1024
    MinValue = 8
    TabOrder = 0
    Value = 32
    OnChange = seLengthChange
  end
  object cbPresets: TComboBox
    Left = 136
    Top = 24
    Width = 377
    Height = 23
    Style = csDropDownList
    DropDownCount = 20
    TabOrder = 1
    OnChange = cbPresetsChange
  end
  object bGenerate: TButton
    Left = 248
    Top = 83
    Width = 93
    Height = 25
    Caption = #1043#1077#1085#1077#1088#1080#1088#1086#1074#1072#1090#1100
    Default = True
    TabOrder = 3
    OnClick = bGenerateClick
  end
  object bInsertAndClose: TButton
    Left = 347
    Top = 83
    Width = 166
    Height = 25
    Caption = #1042#1089#1090#1072#1074#1080#1090#1100' '#1080' '#1079#1072#1082#1088#1099#1090#1100
    TabOrder = 4
    OnClick = bInsertAndCloseClick
  end
  object ebPassword: TEdit
    Left = 136
    Top = 54
    Width = 377
    Height = 23
    TabOrder = 2
    OnKeyPress = edIncludeKeyPress
  end
  object cbUnique: TCheckBox
    Left = 8
    Top = 83
    Width = 153
    Height = 17
    Caption = #1059#1085#1080#1082#1072#1083#1100#1085#1099#1077' '#1089#1080#1084#1074#1086#1083#1099
    DoubleBuffered = True
    ParentDoubleBuffered = False
    TabOrder = 5
  end
  object pcHost: TPageControl
    Left = 8
    Top = 114
    Width = 505
    Height = 237
    ActivePage = tsHistory
    TabOrder = 6
    OnChanging = pcHostChanging
    object tsHistory: TTabSheet
      Caption = #1048#1089#1090#1086#1088#1080#1103
      object lvHistory: TListView
        Left = 0
        Top = 0
        Width = 497
        Height = 207
        Align = alClient
        Columns = <
          item
            Caption = #1044#1072#1090#1072
            Width = 70
          end
          item
            Caption = #1042#1088#1077#1084#1103
            Width = 70
          end
          item
            Caption = #1055#1072#1088#1086#1083#1100
            Width = 150
          end
          item
            Caption = #1064#1072#1073#1083#1086#1085
            Width = 120
          end
          item
            Caption = #1069#1085#1090#1088#1086#1087#1080#1103
            Width = 80
          end>
        ReadOnly = True
        RowSelect = True
        TabOrder = 0
        ViewStyle = vsReport
        OnClick = lvHistoryClick
        OnDblClick = lvHistoryDblClick
      end
    end
    object tsCustomSettings: TTabSheet
      Caption = #1044#1086#1087#1086#1083#1085#1080#1090#1077#1083#1100#1085#1086
      ImageIndex = 1
      TabVisible = False
      object lbInclude: TLabel
        Left = 168
        Top = 8
        Width = 127
        Height = 15
        Caption = #1042#1082#1083#1102#1095#1072#1077#1084#1099#1077' '#1089#1080#1084#1074#1086#1083#1099
      end
      object ldExclude: TLabel
        Left = 168
        Top = 66
        Width = 135
        Height = 15
        Caption = #1048#1089#1082#1083#1102#1095#1072#1077#1084#1099#1077' '#1089#1080#1084#1074#1086#1083#1099
      end
      object bIncludePresets: TSpeedButton
        Left = 473
        Top = 24
        Width = 23
        Height = 23
        Caption = '+'
        OnClick = bIncludePresetsClick
      end
      object bExcludePresets: TSpeedButton
        Left = 473
        Top = 83
        Width = 23
        Height = 23
        Caption = '+'
        OnClick = bExcludePresetsClick
      end
      object cbLower: TCheckBox
        Left = 8
        Top = 16
        Width = 141
        Height = 17
        Caption = #1053#1080#1078#1085#1080#1081' '#1088#1077#1075#1080#1089#1090#1088
        Checked = True
        State = cbChecked
        TabOrder = 0
        OnClick = cbLowerClick
      end
      object cbUpper: TCheckBox
        Left = 8
        Top = 39
        Width = 121
        Height = 17
        Caption = #1042#1077#1088#1093#1085#1080#1081' '#1088#1077#1075#1080#1089#1090#1088
        Checked = True
        State = cbChecked
        TabOrder = 1
        OnClick = cbUpperClick
      end
      object cbNumbers: TCheckBox
        Left = 8
        Top = 62
        Width = 97
        Height = 17
        Caption = #1062#1080#1092#1088#1099
        Checked = True
        State = cbChecked
        TabOrder = 2
        OnClick = cbNumbersClick
      end
      object cbSymbols: TCheckBox
        Left = 8
        Top = 85
        Width = 141
        Height = 17
        Caption = #1057#1087#1077#1094#1089#1080#1084#1074#1086#1083#1099
        Checked = True
        State = cbChecked
        TabOrder = 3
        OnClick = cbSymbolsClick
      end
      object edInclude: TEdit
        Left = 168
        Top = 24
        Width = 303
        Height = 23
        TabOrder = 4
        OnChange = edIncludeChange
        OnKeyPress = edIncludeKeyPress
      end
      object edExclude: TEdit
        Left = 168
        Top = 83
        Width = 303
        Height = 23
        TabOrder = 5
        OnChange = edExcludeChange
        OnKeyPress = edIncludeKeyPress
      end
    end
    object tsBulkMode: TTabSheet
      Caption = #1052#1072#1089#1089#1086#1074#1072#1103' '#1075#1077#1085#1077#1088#1072#1094#1080#1103
      ImageIndex = 2
      object lbBulkCount: TLabel
        Left = 8
        Top = 6
        Width = 68
        Height = 15
        Caption = #1050#1086#1083#1080#1095#1077#1089#1090#1074#1086':'
      end
      object seBulkCount: TSpinEdit
        Left = 112
        Top = 3
        Width = 105
        Height = 24
        MaxValue = 100000
        MinValue = 2
        TabOrder = 0
        Value = 10
      end
      object mBulkResult: TMemo
        Left = 0
        Top = 33
        Width = 497
        Height = 152
        Font.Charset = DEFAULT_CHARSET
        Font.Color = clWindowText
        Font.Height = -12
        Font.Name = 'Consolas'
        Font.Style = []
        ParentFont = False
        ReadOnly = True
        ScrollBars = ssVertical
        TabOrder = 1
      end
      object bBulkGenerate: TButton
        Left = 256
        Top = 2
        Width = 122
        Height = 25
        Caption = #1057#1075#1077#1085#1077#1088#1080#1088#1086#1074#1072#1090#1100
        DropDownMenu = pmBulkGeneration
        TabOrder = 2
        OnClick = bBulkGenerateClick
      end
      object pbBulkProgress: TProgressBar
        Left = 3
        Top = 191
        Width = 494
        Height = 17
        TabOrder = 3
      end
      object bExport: TButton
        Left = 384
        Top = 2
        Width = 110
        Height = 25
        Caption = #1069#1082#1089#1087#1086#1088#1090
        DropDownMenu = pmBulkGeneration
        Style = bsSplitButton
        TabOrder = 4
      end
    end
  end
  object pmCharPresets: TPopupMenu
    Left = 376
    Top = 8
  end
  object pmBulkGeneration: TPopupMenu
    Left = 272
    Top = 8
    object N1: TMenuItem
      Caption = #1057#1082#1086#1087#1080#1088#1086#1074#1072#1090#1100' '#1074' '#1073#1091#1092#1077#1088
      OnClick = N1Click
    end
    object N2: TMenuItem
      Caption = #1057#1086#1093#1088#1072#1085#1080#1090#1100' '#1074' '#1092#1072#1081#1083
    end
  end
  object SaveDialog: TSaveDialog
    Filter = 'TEXT|*.txt|ALL|*.*'
    Left = 456
    Top = 8
  end
end
