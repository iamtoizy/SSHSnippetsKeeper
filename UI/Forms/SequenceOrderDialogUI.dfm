object SequenceOrderForm: TSequenceOrderForm
  Left = 0
  Top = 0
  BorderIcons = [biSystemMenu]
  BorderStyle = bsDialog
  Caption = 'SequenceOrder'
  ClientHeight = 400
  ClientWidth = 420
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  KeyPreview = True
  Position = poMainFormCenter
  OnDestroy = FormDestroy
  OnKeyDown = FormKeyDown
  PixelsPerInch = 96
  TextHeight = 15
  object lblHint: TLabel
    Left = 12
    Top = 10
    Width = 396
    Height = 32
    AutoSize = False
    WordWrap = True
  end
  object lvOrder: TListView
    Left = 12
    Top = 48
    Width = 396
    Height = 262
    Columns = <
      item
        Caption = '#'
        Width = 50
      end
      item
        Caption = 'Snippet'
        Width = 320
      end>
    HideSelection = False
    ReadOnly = True
    RowSelect = True
    TabOrder = 0
    ViewStyle = vsReport
    OnDblClick = lvOrderDblClick
    OnSelectItem = lvOrderSelectItem
  end
  object btnUp: TButton
    Left = 12
    Top = 318
    Width = 124
    Height = 28
    Caption = 'Up'
    TabOrder = 1
    OnClick = btnUpClick
  end
  object btnDown: TButton
    Left = 148
    Top = 318
    Width = 124
    Height = 28
    Caption = 'Down'
    TabOrder = 2
    OnClick = btnDownClick
  end
  object btnRemove: TButton
    Left = 284
    Top = 318
    Width = 124
    Height = 28
    Caption = 'Remove'
    TabOrder = 3
    OnClick = btnRemoveClick
  end
  object btnRun: TButton
    Left = 12
    Top = 356
    Width = 190
    Height = 30
    Caption = 'Run'
    Default = True
    TabOrder = 4
    OnClick = btnRunClick
  end
  object btnCancel: TButton
    Left = 218
    Top = 356
    Width = 190
    Height = 30
    Cancel = True
    Caption = 'Cancel'
    ModalResult = 2
    TabOrder = 5
  end
end
