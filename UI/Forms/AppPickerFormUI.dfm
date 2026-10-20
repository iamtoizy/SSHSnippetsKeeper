object AppPickerForm: TAppPickerForm
  Left = 0
  Top = 0
  BorderStyle = bsDialog
  Caption = #1044#1086#1073#1072#1074#1083#1077#1085#1080#1077' '#1087#1088#1080#1083#1086#1078#1077#1085#1080#1081
  ClientHeight = 440
  ClientWidth = 570
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
    Width = 570
    Height = 33
    Align = alTop
    BevelOuter = bvNone
    TabOrder = 0
    object ebFilter: TEdit
      Left = 3
      Top = 5
      Width = 564
      Height = 23
      TabOrder = 0
      TextHint = #1060#1080#1083#1100#1090#1088' '#1087#1086' '#1080#1084#1077#1085#1080'...'
      OnChange = ebFilterChange
    end
  end
  object pBottom: TPanel
    Left = 0
    Top = 399
    Width = 570
    Height = 41
    Align = alBottom
    BevelOuter = bvNone
    TabOrder = 1
    object bAdd: TButton
      Left = 3
      Top = 8
      Width = 150
      Height = 25
      Caption = #1044#1086#1073#1072#1074#1080#1090#1100' '#1074#1099#1073#1088#1072#1085#1085#1099#1077
      Default = True
      ModalResult = 1
      TabOrder = 0
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
    object lbStatus: TLabel
      Left = 272
      Top = 15
      Width = 295
      Height = 15
      AutoSize = False
      Caption = ''
    end
  end
  object pcSources: TPageControl
    Left = 0
    Top = 33
    Width = 570
    Height = 366
    Align = alClient
    TabOrder = 2
    OnChange = pcSourcesChange
    object tsRunning: TTabSheet
      Caption = #1047#1072#1087#1091#1097#1077#1085#1085#1099#1077' '#1089#1077#1081#1095#1072#1089
      object lvRunning: TListView
        Left = 0
        Top = 0
        Width = 562
        Height = 338
        Align = alClient
        Checkboxes = True
        Columns = <
          item
            Caption = #1055#1088#1080#1083#1086#1078#1077#1085#1080#1077
            Width = 250
          end
          item
            Caption = #1055#1088#1086#1094#1077#1089#1089
            Tag = 1
            Width = 290
          end>
        HideSelection = False
        ReadOnly = True
        RowSelect = True
        TabOrder = 0
        ViewStyle = vsReport
        OnDblClick = lvItemDblClick
      end
    end
    object tsRecent: TTabSheet
      Caption = #1053#1077#1076#1072#1074#1085#1080#1077
      object lvRecent: TListView
        Left = 0
        Top = 0
        Width = 562
        Height = 338
        Align = alClient
        Checkboxes = True
        Columns = <
          item
            Caption = #1055#1088#1080#1083#1086#1078#1077#1085#1080#1077
            Width = 250
          end
          item
            Caption = #1055#1086#1089#1083#1077#1076#1085#1080#1081' '#1079#1072#1087#1091#1089#1082
            Tag = 1
            Width = 290
          end>
        HideSelection = False
        ReadOnly = True
        RowSelect = True
        TabOrder = 0
        ViewStyle = vsReport
        OnDblClick = lvItemDblClick
      end
    end
  end
end
