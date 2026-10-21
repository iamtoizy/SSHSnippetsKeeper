object TagSelectForm: TTagSelectForm
  Left = 0
  Top = 0
  BorderIcons = [biSystemMenu]
  BorderStyle = bsDialog
  Caption = 'TagSelect'
  ClientHeight = 400
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
  object lblHint: TLabel
    Left = 12
    Top = 42
    Width = 336
    Height = 32
    AutoSize = False
    WordWrap = True
  end
  object lvTags: TListView
    Left = 12
    Top = 80
    Width = 336
    Height = 272
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
    Top = 358
    Width = 120
    Height = 30
    Caption = 'OK'
    Default = True
    TabOrder = 2
    OnClick = btnOKClick
  end
  object btnCancel: TButton
    Left = 228
    Top = 358
    Width = 120
    Height = 30
    Cancel = True
    Caption = 'Cancel'
    ModalResult = 2
    TabOrder = 3
  end
end
