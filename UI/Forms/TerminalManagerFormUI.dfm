object TerminalManagerForm: TTerminalManagerForm
  Left = 0
  Top = 0
  BorderStyle = bsDialog
  Caption = #1052#1077#1085#1077#1076#1078#1077#1088' '#1090#1077#1088#1084#1080#1085#1072#1083#1086#1074
  ClientHeight = 440
  ClientWidth = 625
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  Position = poScreenCenter
  OnShow = FormShow
  TextHeight = 15
  object pTop: TPanel
    Left = 0
    Top = 0
    Width = 625
    Height = 33
    Align = alTop
    BevelOuter = bvNone
    TabOrder = 0
    ExplicitWidth = 600
    object ebFilter: TEdit
      Left = 3
      Top = 5
      Width = 372
      Height = 23
      TabOrder = 0
      OnChange = ebFilterChange
    end
    object bSelectAll: TButton
      Left = 381
      Top = 5
      Width = 105
      Height = 25
      Caption = #1042#1099#1073#1088#1072#1090#1100' '#1074#1089#1077
      TabOrder = 1
      OnClick = bSelectAllClick
    end
    object bClearHistory: TButton
      Left = 492
      Top = 5
      Width = 133
      Height = 25
      Caption = #1054#1095#1080#1089#1090#1080#1090#1100' '#1080#1089#1090#1086#1088#1080#1102
      TabOrder = 2
      OnClick = bClearHistoryClick
    end
  end
  object pBottom: TPanel
    Left = 0
    Top = 399
    Width = 625
    Height = 41
    Align = alBottom
    BevelOuter = bvNone
    TabOrder = 1
    ExplicitWidth = 600
    object lbStatus: TLabel
      Left = 272
      Top = 15
      Width = 325
      Height = 15
      AutoSize = False
    end
    object bApply: TButton
      Left = 3
      Top = 8
      Width = 150
      Height = 25
      Caption = #1055#1088#1080#1084#1077#1085#1080#1090#1100
      Default = True
      ModalResult = 1
      TabOrder = 0
      OnClick = bApplyClick
    end
    object bCancel: TButton
      Left = 159
      Top = 8
      Width = 100
      Height = 25
      Cancel = True
      Caption = #1054#1090#1084#1077#1085#1072
      ModalResult = 2
      TabOrder = 1
    end
  end
  object lvWindows: TListView
    Left = 0
    Top = 33
    Width = 625
    Height = 366
    Align = alClient
    Checkboxes = True
    Columns = <
      item
        Caption = #1047#1072#1075#1086#1083#1086#1074#1086#1082
        Width = 300
      end
      item
        Caption = #1055#1088#1086#1094#1077#1089#1089
        Tag = 1
        Width = 160
      end
      item
        Caption = #1047#1072#1087#1086#1084#1085#1077#1085#1086
        Tag = 2
        Width = 120
      end>
    HideSelection = False
    ReadOnly = True
    RowSelect = True
    TabOrder = 2
    ViewStyle = vsReport
    OnDblClick = lvItemDblClick
    OnItemChecked = lvItemChecked
    ExplicitWidth = 600
  end
end
