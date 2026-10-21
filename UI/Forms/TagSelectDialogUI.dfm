object TagSelectForm: TTagSelectForm
  Left = 0
  Top = 0
  BorderIcons = [biSystemMenu]
  BorderStyle = bsDialog
  Caption = 'TagSelect'
  ClientHeight = 368
  ClientWidth = 360
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  KeyPreview = True
  Position = poMainFormCenter
  OnKeyDown = FormKeyDown
  PixelsPerInch = 96
  TextHeight = 15
  object edSearch: TEdit
    Left = 12
    Top = 12
    Width = 336
    Height = 23
    TabOrder = 0
    OnChange = edSearchChange
  end
  object lvTags: TListView
    Left = 12
    Top = 43
    Width = 336
    Height = 268
    Columns = <
      item
        Caption = 'Tag'
        Width = 310
      end>
    HideSelection = False
    ReadOnly = True
    RowSelect = True
    TabOrder = 1
    ViewStyle = vsReport
    OnDblClick = lvTagsDblClick
  end
  object btnOK: TButton
    Left = 12
    Top = 324
    Width = 120
    Height = 30
    Caption = 'OK'
    Default = True
    TabOrder = 2
    OnClick = btnOKClick
  end
  object btnCancel: TButton
    Left = 228
    Top = 324
    Width = 120
    Height = 30
    Cancel = True
    Caption = 'Cancel'
    ModalResult = 2
    TabOrder = 3
  end
end
