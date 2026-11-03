object ChooseTerminalWindow: TChooseTerminalWindow
  Left = 0
  Top = 0
  BorderStyle = bsSizeToolWin
  Caption = #1042#1099#1073#1086#1088' '#1090#1077#1088#1084#1080#1085#1072#1083#1072
  ClientHeight = 333
  ClientWidth = 780
  Constraints.MinHeight = 220
  Constraints.MinWidth = 480
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
  OnResize = FormResize
  OnShow = FormShow
  TextHeight = 15
  object pTop: TPanel
    Left = 0
    Top = 0
    Width = 780
    Height = 34
    Align = alTop
    BevelOuter = bvNone
    Padding.Left = 4
    Padding.Top = 5
    Padding.Right = 4
    Padding.Bottom = 5
    TabOrder = 0
    object ebFilter: TEdit
      Left = 4
      Top = 5
      Width = 424
      Height = 24
      Align = alClient
      TabOrder = 0
      OnChange = ebFilterChange
    end
    object pViewButtons: TPanel
      Left = 428
      Top = 5
      Width = 348
      Height = 24
      Align = alRight
      BevelOuter = bvNone
      TabOrder = 1
      object sbTiles: TSpeedButton
        Left = 0
        Top = 0
        Width = 70
        Height = 24
        AlignWithMargins = True
        Margins.Left = 0
        Margins.Top = 0
        Margins.Right = 1
        Margins.Bottom = 0
        Align = alRight
        GroupIndex = 1
        Caption = #1055#1083#1080#1090#1082#1080
        OnClick = ViewButtonClick
      end
      object sbTable: TSpeedButton
        Left = 71
        Top = 0
        Width = 73
        Height = 24
        AlignWithMargins = True
        Margins.Left = 0
        Margins.Top = 0
        Margins.Right = 1
        Margins.Bottom = 0
        Align = alRight
        GroupIndex = 1
        Caption = #1058#1072#1073#1083#1080#1094#1072
        OnClick = ViewButtonClick
      end
      object sbGroup: TSpeedButton
        Left = 145
        Top = 0
        Width = 72
        Height = 24
        AlignWithMargins = True
        Margins.Left = 0
        Margins.Top = 0
        Margins.Right = 1
        Margins.Bottom = 0
        Align = alRight
        AllowAllUp = True
        GroupIndex = 2
        Caption = #1043#1088#1091#1087#1087#1099
        OnClick = sbGroupClick
      end
      object sbPreview: TSpeedButton
        Left = 218
        Top = 0
        Width = 130
        Height = 24
        AlignWithMargins = True
        Margins.Left = 0
        Margins.Top = 0
        Margins.Right = 0
        Margins.Bottom = 0
        Align = alRight
        AllowAllUp = True
        GroupIndex = 3
        Caption = #9650' '#1055#1088#1077#1076#1087#1088#1086#1089#1084#1086#1090#1088
        OnClick = sbPreviewClick
      end
    end
  end
  object pPreview: TPanel
    Left = 0
    Top = 34
    Width = 780
    Height = 300
    Align = alTop
    BevelOuter = bvNone
    Padding.Left = 6
    Padding.Top = 6
    Padding.Right = 6
    Padding.Bottom = 6
    TabOrder = 2
    Visible = False
    OnResize = pPreviewResize
    object lbPreviewEmpty: TLabel
      Left = 6
      Top = 6
      Width = 768
      Height = 288
      Align = alClient
      Alignment = taCenter
      AutoSize = False
      Caption = #1055#1088#1077#1076#1087#1088#1086#1089#1084#1086#1090#1088
      Layout = tlCenter
    end
  end
  object splPreview: TSplitter
    Left = 0
    Top = 334
    Width = 780
    Height = 6
    Align = alTop
    AutoSnap = False
    MinSize = 90
    ResizeStyle = rsUpdate
    Visible = False
    OnCanResize = splPreviewCanResize
    OnMoved = splPreviewMoved
    ExplicitTop = 334
    ExplicitWidth = 780
  end
  object lvTerminalList: TListView
    Left = 0
    Top = 34
    Width = 780
    Height = 280
    Align = alClient
    Columns = <
      item
        Caption = #1047#1072#1075#1086#1083#1086#1074#1086#1082
        Width = 195
      end
      item
        Caption = #1055#1088#1086#1094#1077#1089#1089
        Width = 120
      end
      item
        Caption = #1040#1082#1090#1080#1074#1080#1088#1086#1074#1072#1085#1086
        Width = 95
      end>
    TileOptions.SubLineCount = 1
    TileOptions.SizeType = tstFixedSize
    TileOptions.Height = 64
    TileOptions.Width = 200
    LargeImages = ilIcons
    ReadOnly = True
    RowSelect = True
    SmallImages = ilSmallIcons
    TabOrder = 1
    ViewStyle = vsTile
    OnColumnClick = lvTerminalListColumnClick
    OnDblClick = lvTerminalListDblClick
    OnSelectItem = lvTerminalListSelectItem
  end
  object sbBottom: TStatusBar
    Left = 0
    Top = 314
    Width = 780
    Height = 19
    Panels = <>
    SimplePanel = True
  end
  object ilIcons: TImageList
    ColorDepth = cd32Bit
    Height = 32
    Width = 32
    Left = 16
    Top = 64
  end
  object ilSmallIcons: TImageList
    ColorDepth = cd32Bit
    Left = 72
    Top = 64
  end
end
