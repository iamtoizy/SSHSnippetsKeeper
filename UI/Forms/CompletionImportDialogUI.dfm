object CompletionImportForm: TCompletionImportForm
  Left = 0
  Top = 0
  BorderIcons = [biSystemMenu]
  BorderStyle = bsDialog
  Caption = 'CompletionImport'
  ClientHeight = 480
  ClientWidth = 380
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
    Width = 325
    Height = 23
    TabOrder = 0
    OnChange = edSearchChange
  end
  object btnHelp: TButton
    Left = 345
    Top = 12
    Width = 23
    Height = 23
    Caption = '?'
    TabOrder = 1
    OnClick = btnHelpClick
  end
  object lblPrompt: TLabel
    Left = 12
    Top = 44
    Width = 356
    Height = 15
    AutoSize = False
  end
  object clbItems: TCheckListBox
    Left = 12
    Top = 66
    Width = 356
    Height = 300
    ItemHeight = 15
    TabOrder = 2
    OnClickCheck = clbItemsClickCheck
  end
  object pMode: TPanel
    Left = 12
    Top = 372
    Width = 356
    Height = 40
    BevelOuter = bvNone
    TabOrder = 3
    object rbMerge: TRadioButton
      Left = 4
      Top = 8
      Width = 160
      Height = 17
      Caption = 'Merge'
      Checked = True
      TabOrder = 0
      TabStop = True
    end
    object rbReplace: TRadioButton
      Left = 180
      Top = 8
      Width = 160
      Height = 17
      Caption = 'Replace'
      TabOrder = 1
    end
  end
  object pButtons: TPanel
    Left = 12
    Top = 427
    Width = 356
    Height = 39
    BevelOuter = bvNone
    TabOrder = 4
    object btnAll: TButton
      Left = 4
      Top = 8
      Width = 100
      Height = 23
      Caption = 'All'
      TabOrder = 0
      OnClick = btnAllClick
    end
    object btnNone: TButton
      Left = 112
      Top = 8
      Width = 100
      Height = 23
      Caption = 'None'
      TabOrder = 1
      OnClick = btnNoneClick
    end
    object btnOK: TButton
      Left = 228
      Top = 8
      Width = 60
      Height = 23
      Caption = 'OK'
      Default = True
      TabOrder = 2
      OnClick = btnOKClick
    end
    object btnCancel: TButton
      Left = 296
      Top = 8
      Width = 60
      Height = 23
      Cancel = True
      Caption = 'Cancel'
      ModalResult = 2
      TabOrder = 3
    end
  end
end
