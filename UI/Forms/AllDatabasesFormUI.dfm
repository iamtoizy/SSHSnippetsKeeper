object AllDatabasesForm: TAllDatabasesForm
  Left = 0
  Top = 0
  BorderIcons = [biSystemMenu]
  BorderStyle = bsDialog
  Caption = 'AllDatabases'
  ClientHeight = 440
  ClientWidth = 620
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  Position = poScreenCenter
  OnShow = FormShow
  TextHeight = 13
  object lvDatabases: TListView
    Left = 12
    Top = 12
    Width = 596
    Height = 364
    Columns = <>
    MultiSelect = True
    ReadOnly = True
    RowSelect = True
    TabOrder = 0
    ViewStyle = vsReport
    OnDblClick = lvDatabasesDblClick
    OnSelectItem = lvDatabasesSelectItem
  end
  object bOpen: TButton
    Left = 12
    Top = 396
    Width = 110
    Height = 25
    TabOrder = 1
    OnClick = bOpenClick
  end
  object bCleanup: TButton
    Left = 132
    Top = 396
    Width = 190
    Height = 25
    TabOrder = 2
    OnClick = bCleanupClick
  end
  object bDelete: TButton
    Left = 332
    Top = 396
    Width = 130
    Height = 25
    TabOrder = 3
    OnClick = bDeleteClick
  end
  object bClose: TButton
    Left = 458
    Top = 396
    Width = 150
    Height = 25
    TabOrder = 4
  end
end
