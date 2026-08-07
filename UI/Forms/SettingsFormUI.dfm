object SettingsForm: TSettingsForm
  Left = 0
  Top = 0
  BorderStyle = bsDialog
  Caption = #1053#1072#1089#1090#1088#1086#1081#1082#1080
  ClientHeight = 441
  ClientWidth = 624
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  Position = poScreenCenter
  TextHeight = 15
  object pcSettings: TPageControl
    Left = 0
    Top = 0
    Width = 624
    Height = 408
    ActivePage = tsHotkeys
    Align = alClient
    TabOrder = 0
    object tsHotkeys: TTabSheet
      Caption = #1043#1086#1088#1103#1095#1080#1077' '#1082#1083#1072#1074#1080#1096#1080
      object gbGlobalHotkeys: TGroupBox
        Left = 0
        Top = 0
        Width = 616
        Height = 81
        Align = alTop
        Caption = #1043#1083#1086#1073#1072#1083#1100#1085#1099#1077
        TabOrder = 0
        object hkQuickSearch: THotKey
          Left = 420
          Top = 18
          Width = 193
          Height = 23
          HotKey = 32833
          TabOrder = 0
        end
        object hkPassGen: THotKey
          Left = 420
          Top = 47
          Width = 193
          Height = 23
          HotKey = 32833
          TabOrder = 1
        end
        object chkEnableQuickSearch: TCheckBox
          Left = 16
          Top = 21
          Width = 398
          Height = 17
          Caption = #1043#1083#1086#1073#1072#1083#1100#1085#1099#1081' '#1074#1099#1079#1086#1074' "'#1055#1072#1085#1077#1083#1080' '#1073#1099#1089#1090#1088#1086#1075#1086' '#1087#1086#1080#1089#1082#1072'"'
          TabOrder = 2
        end
        object chkEnablePassGen: TCheckBox
          Left = 16
          Top = 50
          Width = 398
          Height = 17
          Caption = #1043#1083#1086#1073#1072#1083#1100#1085#1099#1081' '#1074#1099#1079#1086#1074' "'#1043#1077#1085#1077#1088#1072#1090#1086#1088#1072' '#1087#1072#1088#1086#1083#1077#1081'"'
          TabOrder = 3
        end
      end
      object gbAppHotkeys: TGroupBox
        Left = 0
        Top = 81
        Width = 616
        Height = 297
        Align = alClient
        Caption = #1051#1086#1082#1072#1083#1100#1085#1099#1077
        TabOrder = 1
        object lvHotkeys: TListView
          Left = 2
          Top = 40
          Width = 612
          Height = 168
          Align = alClient
          Columns = <
            item
              Caption = #1050#1072#1090#1077#1075#1086#1088#1080#1103
              Width = 100
            end
            item
              Caption = #1044#1077#1081#1089#1090#1074#1080#1077
              Tag = 1
              Width = 100
            end
            item
              Caption = #1050#1083#1072#1074#1080#1096#1080
              Tag = 2
              Width = 100
            end>
          HideSelection = False
          ReadOnly = True
          RowSelect = True
          TabOrder = 0
          ViewStyle = vsReport
          OnCompare = lvHotkeysCompare
          OnDeletion = lvHotkeysDeletion
          OnSelectItem = lvHotkeysSelectItem
        end
        object pEditor: TPanel
          Left = 2
          Top = 208
          Width = 612
          Height = 87
          Align = alBottom
          BevelOuter = bvNone
          TabOrder = 1
          object lbHotkey: TLabel
            Left = 5
            Top = 10
            Width = 100
            Height = 15
            Caption = #1043#1086#1088#1103#1095#1072#1103' '#1082#1083#1072#1074#1080#1096#1072':'
          end
          object lbAction: TLabel
            Left = 5
            Top = 36
            Width = 54
            Height = 15
            Caption = #1044#1077#1081#1089#1090#1074#1080#1077':'
          end
          object lbActionID: TLabel
            Left = 5
            Top = 63
            Width = 90
            Height = 15
            Caption = #1048#1076#1077#1085#1090#1080#1092#1080#1082#1072#1090#1086#1088':'
          end
          object hkEditor: THotKey
            Left = 171
            Top = 6
            Width = 380
            Height = 23
            HotKey = 32833
            TabOrder = 0
          end
          object bApplyShortcut: TButton
            Left = 557
            Top = 6
            Width = 23
            Height = 23
            Caption = #55357#56510
            TabOrder = 1
            OnClick = bApplyShortcutClick
          end
          object bResetShortcut: TButton
            Left = 586
            Top = 6
            Width = 23
            Height = 23
            Caption = #8634
            TabOrder = 2
            OnClick = bResetShortcutClick
          end
          object ebAction: TEdit
            Left = 171
            Top = 33
            Width = 438
            Height = 23
            ReadOnly = True
            TabOrder = 3
          end
          object ebActionID: TEdit
            Left = 171
            Top = 60
            Width = 438
            Height = 23
            ReadOnly = True
            TabOrder = 4
          end
        end
        object ebSearchHotkeys: TEdit
          Left = 2
          Top = 17
          Width = 612
          Height = 23
          Align = alTop
          TabOrder = 2
          OnChange = ebSearchHotkeysChange
        end
      end
    end
  end
  object pBottom: TPanel
    Left = 0
    Top = 408
    Width = 624
    Height = 33
    Align = alBottom
    BevelOuter = bvNone
    TabOrder = 1
    object bSave: TButton
      Left = 384
      Top = 6
      Width = 115
      Height = 25
      Caption = #1057#1086#1093#1088#1072#1085#1080#1090#1100
      TabOrder = 0
      OnClick = bSaveClick
    end
    object bCancel: TButton
      Left = 505
      Top = 6
      Width = 110
      Height = 25
      Caption = #1054#1090#1084#1077#1085#1072
      TabOrder = 1
      OnClick = bCancelClick
    end
    object bResetAll: TButton
      Left = 0
      Top = 6
      Width = 145
      Height = 25
      Caption = #1057#1073#1088#1086#1089#1080#1090#1100' '#1074#1089#1105
      TabOrder = 2
      OnClick = bResetAllClick
    end
  end
end
