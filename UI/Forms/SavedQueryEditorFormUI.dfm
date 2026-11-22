object SavedQueryEditorForm: TSavedQueryEditorForm
  Left = 0
  Top = 0
  BorderIcons = [biSystemMenu]
  BorderStyle = bsDialog
  Caption = 'SavedQueryEditor'
  ClientHeight = 190
  ClientWidth = 420
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
  object lblName: TLabel
    Left = 12
    Top = 12
    Width = 60
    Height = 15
    Caption = 'Name:'
  end
  object edName: TEdit
    Left = 12
    Top = 32
    Width = 396
    Height = 23
    TabOrder = 0
  end
  object lblQuery: TLabel
    Left = 12
    Top = 64
    Width = 42
    Height = 15
    Caption = 'Query:'
  end
  object edQuery: TEdit
    Left = 12
    Top = 84
    Width = 396
    Height = 23
    TabOrder = 1
  end
  object lblHint: TLabel
    Left = 12
    Top = 114
    Width = 396
    Height = 30
    AutoSize = False
    WordWrap = True
  end
  object btnOK: TButton
    Left = 12
    Top = 148
    Width = 120
    Height = 30
    Caption = 'OK'
    Default = True
    TabOrder = 2
    OnClick = btnOKClick
  end
  object btnCancel: TButton
    Left = 288
    Top = 148
    Width = 120
    Height = 30
    Cancel = True
    Caption = 'Cancel'
    ModalResult = 2
    TabOrder = 3
  end
end
