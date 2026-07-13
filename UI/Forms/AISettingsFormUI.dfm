object AISettingsForm: TAISettingsForm
  Left = 0
  Top = 0
  BorderStyle = bsDialog
  Caption = #1053#1072#1089#1090#1088#1086#1081#1082#1080' '#1048#1048
  ClientHeight = 372
  ClientWidth = 624
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  FormStyle = fsStayOnTop
  Menu = MainMenu
  Position = poScreenCenter
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  TextHeight = 15
  object spLeft: TSplitter
    Left = 185
    Top = 0
    Height = 372
    ExplicitLeft = 504
    ExplicitTop = 296
    ExplicitHeight = 100
  end
  object pnlLeft: TPanel
    Left = 0
    Top = 0
    Width = 185
    Height = 372
    Align = alLeft
    BevelOuter = bvNone
    TabOrder = 0
    ExplicitHeight = 441
    object tvAIStructure: TTreeView
      Left = 0
      Top = 0
      Width = 185
      Height = 372
      Align = alClient
      Indent = 19
      TabOrder = 0
      OnChange = tvAIStructureChange
      ExplicitHeight = 441
    end
  end
  object pnlClient: TPanel
    Left = 188
    Top = 0
    Width = 436
    Height = 372
    Align = alClient
    BevelOuter = bvNone
    TabOrder = 1
    ExplicitHeight = 441
  end
  object pcDetails: TPageControl
    Left = 188
    Top = 0
    Width = 436
    Height = 372
    ActivePage = tsHub
    Align = alClient
    TabOrder = 2
    ExplicitHeight = 441
    object tsHub: TTabSheet
      Caption = 'tsHub'
      TabVisible = False
      object lbHubName: TLabel
        Left = 3
        Top = 3
        Width = 68
        Height = 15
        Caption = #1048#1084#1103' '#1075#1088#1091#1087#1087#1099
      end
      object lbHubURL: TLabel
        Left = 3
        Top = 50
        Width = 21
        Height = 15
        Caption = 'URL'
      end
      object lbHubComment: TLabel
        Left = 3
        Top = 99
        Width = 77
        Height = 15
        Caption = #1050#1086#1084#1084#1077#1085#1090#1072#1088#1080#1081
      end
      object ebHubName: TEdit
        Left = 2
        Top = 21
        Width = 423
        Height = 23
        TabOrder = 0
      end
      object ebHubURL: TEdit
        Left = 3
        Top = 69
        Width = 422
        Height = 23
        TabOrder = 1
      end
      object mHubComment: TMemo
        Left = 2
        Top = 120
        Width = 423
        Height = 241
        ScrollBars = ssVertical
        TabOrder = 2
      end
    end
    object tsModel: TTabSheet
      Caption = 'tsModel'
      ImageIndex = 1
      TabVisible = False
      object lbModelName: TLabel
        Left = 3
        Top = 3
        Width = 97
        Height = 15
        Caption = #1053#1072#1079#1074#1072#1085#1080#1077' '#1084#1086#1076#1077#1083#1080
      end
      object lbAPIKey: TLabel
        Left = 3
        Top = 48
        Width = 52
        Height = 15
        Caption = #1050#1083#1102#1095' API'
      end
      object lbFolderID: TLabel
        Left = 3
        Top = 95
        Width = 43
        Height = 15
        Caption = #1050#1072#1090#1072#1083#1086#1075
      end
      object lbAgentID: TLabel
        Left = 235
        Top = 49
        Width = 51
        Height = 15
        Caption = 'ID '#1040#1075#1077#1085#1090#1072
      end
      object lbTemperature: TLabel
        Left = 235
        Top = 95
        Width = 72
        Height = 15
        Caption = #1058#1077#1084#1087#1077#1088#1072#1090#1091#1088#1072
      end
      object lbMaxTokens: TLabel
        Left = 235
        Top = 142
        Width = 133
        Height = 15
        Caption = #1054#1075#1088#1072#1085#1080#1095#1077#1085#1080#1077' '#1085#1072' '#1090#1086#1082#1077#1085#1099
      end
      object lbSystemPrompt: TLabel
        Left = 3
        Top = 190
        Width = 109
        Height = 15
        Caption = #1057#1080#1089#1090#1077#1084#1085#1099#1081' '#1087#1088#1086#1084#1087#1090
      end
      object lbModelPath: TLabel
        Left = 3
        Top = 142
        Width = 43
        Height = 15
        Caption = #1052#1086#1076#1077#1083#1100
      end
      object ebModelName: TEdit
        Left = 3
        Top = 21
        Width = 422
        Height = 23
        TabOrder = 0
      end
      object ebAPIKey: TEdit
        Left = 3
        Top = 67
        Width = 218
        Height = 23
        TabOrder = 1
      end
      object ebFolderID: TEdit
        Left = 2
        Top = 114
        Width = 219
        Height = 23
        TabOrder = 2
      end
      object ebAgentID: TEdit
        Left = 235
        Top = 67
        Width = 190
        Height = 23
        TabOrder = 3
      end
      object ebTemperature: TEdit
        Left = 235
        Top = 114
        Width = 190
        Height = 23
        TabOrder = 4
      end
      object ebMaxTokens: TEdit
        Left = 235
        Top = 161
        Width = 190
        Height = 23
        TabOrder = 5
      end
      object mSystemPrompt: TMemo
        Left = 2
        Top = 211
        Width = 422
        Height = 150
        ScrollBars = ssVertical
        TabOrder = 6
      end
      object ebModelPath: TEdit
        Left = 3
        Top = 161
        Width = 218
        Height = 23
        TabOrder = 7
      end
    end
  end
  object MainMenu: TMainMenu
    Left = 520
    Top = 16
    object N9: TMenuItem
      Caption = #1060#1072#1081#1083
      object N10: TMenuItem
        Caption = #1057#1086#1093#1088#1072#1085#1080#1090#1100
        ShortCut = 16467
        OnClick = N10Click
      end
    end
    object N1: TMenuItem
      Caption = #1055#1088#1086#1074#1072#1081#1076#1077#1088
      object N2: TMenuItem
        Caption = #1057#1086#1079#1076#1072#1090#1100
        ShortCut = 16462
        OnClick = N2Click
      end
      object N3: TMenuItem
        Caption = #1059#1076#1072#1083#1080#1090#1100
        ShortCut = 16452
        OnClick = N3Click
      end
      object N4: TMenuItem
        Caption = #1048#1079#1084#1077#1085#1080#1090#1100
        ShortCut = 16453
      end
    end
    object N5: TMenuItem
      Caption = #1052#1086#1076#1077#1083#1100
      object N6: TMenuItem
        Caption = #1057#1086#1079#1076#1072#1090#1100
        ShortCut = 24654
        OnClick = N6Click
      end
      object N7: TMenuItem
        Caption = #1059#1076#1072#1083#1080#1090#1100
        ShortCut = 24644
      end
      object N8: TMenuItem
        Caption = #1048#1079#1084#1077#1085#1080#1090#1100
        ShortCut = 24645
      end
    end
  end
end
