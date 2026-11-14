object DbProfilesForm: TDbProfilesForm
  Left = 0
  Top = 0
  BorderIcons = [biSystemMenu]
  BorderStyle = bsDialog
  Caption = 'DbProfiles'
  ClientHeight = 360
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
  object lvProfiles: TListView
    Left = 12
    Top = 12
    Width = 596
    Height = 284
    Columns = <>
    MultiSelect = False
    ReadOnly = True
    RowSelect = True
    TabOrder = 0
    ViewStyle = vsReport
    OnSelectItem = lvProfilesSelectItem
  end
  object bCleanup: TButton
    Left = 12
    Top = 316
    Width = 220
    Height = 25
    TabOrder = 1
    OnClick = bCleanupClick
  end
  object bDelete: TButton
    Left = 240
    Top = 316
    Width = 150
    Height = 25
    TabOrder = 2
    OnClick = bDeleteClick
  end
  object bClose: TButton
    Left = 458
    Top = 316
    Width = 150
    Height = 25
    TabOrder = 3
  end
end
