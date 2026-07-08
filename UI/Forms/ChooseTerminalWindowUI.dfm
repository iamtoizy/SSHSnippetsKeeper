object ChooseTerminalWindow: TChooseTerminalWindow
  Left = 0
  Top = 0
  BorderStyle = bsToolWindow
  Caption = #1042#1099#1073#1086#1088' '#1090#1077#1088#1084#1080#1085#1072#1083#1072
  ClientHeight = 299
  ClientWidth = 415
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  FormStyle = fsStayOnTop
  Position = poScreenCenter
  OnCreate = FormCreate
  OnShow = FormShow
  TextHeight = 15
  object lvTerminalList: TListView
    Left = 0
    Top = 0
    Width = 415
    Height = 280
    Align = alClient
    Columns = <>
    TileOptions.SubLineCount = 1
    ReadOnly = True
    RowSelect = True
    TabOrder = 0
    ViewStyle = vsTile
    OnDblClick = lvTerminalListDblClick
  end
  object sbBottom: TStatusBar
    Left = 0
    Top = 280
    Width = 415
    Height = 19
    Panels = <>
    SimplePanel = True
  end
end
