object ChooseTerminalWindow: TChooseTerminalWindow
  Left = 0
  Top = 0
  BorderStyle = bsToolWindow
  Caption = #1042#1099#1073#1086#1088' '#1090#1077#1088#1084#1080#1085#1072#1083#1072
  ClientHeight = 333
  ClientWidth = 415
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  FormStyle = fsStayOnTop
  KeyPreview = True
  Position = poScreenCenter
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  OnKeyDown = FormKeyDown
  OnKeyPress = FormKeyPress
  OnShow = FormShow
  TextHeight = 15
  object pTop: TPanel
    Left = 0
    Top = 0
    Width = 415
    Height = 34
    Align = alTop
    BevelOuter = bvNone
    Padding.Left = 4
    Padding.Top = 5
    Padding.Right = 4
    Padding.Bottom = 5
    TabOrder = 1
    object ebFilter: TEdit
      Left = 4
      Top = 5
      Width = 260
      Height = 24
      Align = alClient
      TabOrder = 0
      OnChange = ebFilterChange
    end
    object pViewButtons: TPanel
      Left = 264
      Top = 5
      Width = 147
      Height = 24
      Align = alRight
      BevelOuter = bvNone
      TabOrder = 1
      object sbTiles: TSpeedButton
        Left = 0
        Top = 0
        Width = 70
        Height = 24
        GroupIndex = 1
        Caption = #1051#1083#1080#1090#1082#1080
        OnClick = ViewButtonClick
      end
      object sbTable: TSpeedButton
        Left = 74
        Top = 0
        Width = 73
        Height = 24
        GroupIndex = 1
        Caption = #1058#1072#1073#1083#1080#1094#1072
        OnClick = ViewButtonClick
      end
    end
  end
  object lvTerminalList: TListView
    Left = 0
    Top = 34
    Width = 415
    Height = 280
    Align = alClient
    Columns = <
      item
        Caption = #1047#1072#1075#1086#1083#1086#1074#1086#1082
        Width = 195
      end
      item
        Caption = #1051#1088#1086#1094#1077#1089#1089
        Width = 120
      end
      item
        Caption = #1040#1082#1090#1080#1074#1080#1088#1086#1074#1072#1085#1086
        Width = 95
      end>
    LargeImages = ilIcons
    SmallImages = ilSmallIcons
    TileOptions.SubLineCount = 1
    TileOptions.SizeType = tstFixedSize
    TileOptions.Width = 200
    TileOptions.Height = 64
    ReadOnly = True
    RowSelect = True
    TabOrder = 0
    ViewStyle = vsTile
    OnColumnClick = lvTerminalListColumnClick
    OnDblClick = lvTerminalListDblClick
  end
  object sbBottom: TStatusBar
    Left = 0
    Top = 314
    Width = 415
    Height = 19
    Panels = <>
    SimplePanel = True
  end
  object ilIcons: TImageList
    Height = 32
    Width = 32
    ColorDepth = cd32Bit
    Left = 16
    Top = 64
  end
  object ilSmallIcons: TImageList
    Height = 16
    Width = 16
    ColorDepth = cd32Bit
    Left = 72
    Top = 64
  end
end
