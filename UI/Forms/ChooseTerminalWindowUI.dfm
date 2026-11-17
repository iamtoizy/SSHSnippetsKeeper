object ChooseTerminalWindow: TChooseTerminalWindow
  Left = 0
  Top = 0
  BorderStyle = bsSizeToolWin
  Caption = #1042#1099#1073#1086#1088' '#1090#1077#1088#1084#1080#1085#1072#1083#1072
  ClientHeight = 333
  ClientWidth = 780
  Color = clBtnFace
  Constraints.MinHeight = 220
  Constraints.MinWidth = 480
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
  object splPreview: TSplitter
    Left = 0
    Top = 334
    Width = 780
    Height = 6
    Cursor = crVSplit
    Align = alTop
    AutoSnap = False
    MinSize = 90
    ResizeStyle = rsUpdate
    Visible = False
    OnCanResize = splPreviewCanResize
    OnMoved = splPreviewMoved
  end
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
      Width = 343
      Height = 24
      Align = alClient
      TabOrder = 0
      OnChange = ebFilterChange
      ExplicitHeight = 23
    end
    object pViewButtons: TPanel
      Left = 347
      Top = 5
      Width = 429
      Height = 24
      Align = alRight
      BevelOuter = bvNone
      TabOrder = 1
      object sbManager: TSpeedButton
        AlignWithMargins = True
        Left = 0
        Top = 0
        Width = 80
        Height = 24
        Margins.Left = 0
        Margins.Top = 0
        Margins.Right = 1
        Margins.Bottom = 0
        Align = alLeft
        Caption = #1052#1077#1085#1077#1076#1078#1077#1088
        OnClick = sbManagerClick
      end
      object sbTiles: TSpeedButton
        AlignWithMargins = True
        Left = 81
        Top = 0
        Width = 70
        Height = 24
        Margins.Left = 0
        Margins.Top = 0
        Margins.Right = 1
        Margins.Bottom = 0
        Align = alRight
        GroupIndex = 1
        Caption = #1055#1083#1080#1090#1082#1080
        OnClick = ViewButtonClick
        ExplicitLeft = 0
      end
      object sbTable: TSpeedButton
        AlignWithMargins = True
        Left = 152
        Top = 0
        Width = 73
        Height = 24
        Margins.Left = 0
        Margins.Top = 0
        Margins.Right = 1
        Margins.Bottom = 0
        Align = alRight
        GroupIndex = 1
        Caption = #1058#1072#1073#1083#1080#1094#1072
        OnClick = ViewButtonClick
        ExplicitLeft = 71
      end
      object sbGroup: TSpeedButton
        AlignWithMargins = True
        Left = 226
        Top = 0
        Width = 72
        Height = 24
        Margins.Left = 0
        Margins.Top = 0
        Margins.Right = 1
        Margins.Bottom = 0
        Align = alRight
        AllowAllUp = True
        GroupIndex = 2
        Caption = #1043#1088#1091#1087#1087#1099
        OnClick = sbGroupClick
        ExplicitLeft = 145
      end
      object sbPreview: TSpeedButton
        AlignWithMargins = True
        Left = 299
        Top = 0
        Width = 130
        Height = 24
        Margins.Left = 0
        Margins.Top = 0
        Margins.Right = 0
        Margins.Bottom = 0
        Align = alRight
        AllowAllUp = True
        GroupIndex = 3
        Caption = #9650' '#1055#1088#1077#1076#1087#1088#1086#1089#1084#1086#1090#1088
        OnClick = sbPreviewClick
        ExplicitLeft = 218
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
  object lvTerminalList: TListView
    Left = 0
    Top = 340
    Width = 780
    Height = 82
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
  object lbListEmpty: TLabel
    Left = 0
    Top = 340
    Width = 780
    Height = 82
    Align = alClient
    Alignment = taCenter
    AutoSize = False
    Caption = ''
    Layout = tlCenter
    Transparent = True
    Visible = False
    WordWrap = True
    OnClick = lbListEmptyClick
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
