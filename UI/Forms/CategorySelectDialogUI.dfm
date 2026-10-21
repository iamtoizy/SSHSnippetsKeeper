object CategorySelectForm: TCategorySelectForm
  Left = 0
  Top = 0
  BorderIcons = [biSystemMenu]
  BorderStyle = bsDialog
  Caption = 'CategorySelect'
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
  object tvCategories: TTreeView
    Left = 12
    Top = 12
    Width = 336
    Height = 299
    HideSelection = False
    Indent = 19
    ReadOnly = True
    TabOrder = 0
    OnDblClick = tvCategoriesDblClick
  end
  object btnOK: TButton
    Left = 12
    Top = 324
    Width = 120
    Height = 30
    Caption = 'OK'
    Default = True
    TabOrder = 1
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
    TabOrder = 2
  end
end
