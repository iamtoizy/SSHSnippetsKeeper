object ChainEditorForm: TChainEditorForm
  Left = 0
  Top = 0
  BorderIcons = [biSystemMenu]
  BorderStyle = bsDialog
  Caption = 'ChainEditorForm'
  ClientHeight = 505
  ClientWidth = 700
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
  TextHeight = 15
  object lblName: TLabel
    Left = 12
    Top = 15
    Width = 35
    Height = 15
    Caption = 'Name:'
  end
  object lblSteps: TLabel
    Left = 12
    Top = 47
    Width = 61
    Height = 15
    Caption = 'Chain steps'
  end
  object lblPause: TLabel
    Left = 12
    Top = 350
    Width = 109
    Height = 15
    Caption = 'Pause after step, sec:'
  end
  object lblPauseHint: TLabel
    Left = 12
    Top = 378
    Width = 320
    Height = 30
    AutoSize = False
    Caption = 'Delay after the selected step before the next one'
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clGray
    Font.Height = -11
    Font.Name = 'Segoe UI'
    Font.Style = []
    ParentFont = False
    WordWrap = True
  end
  object lblLibrary: TLabel
    Left = 352
    Top = 47
    Width = 76
    Height = 15
    Caption = 'Snippet library'
  end
  object lblLibraryHint: TLabel
    Left = 352
    Top = 380
    Width = 336
    Height = 15
    AutoSize = False
    Caption = 'Or double-click a snippet'
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clGray
    Font.Height = -11
    Font.Name = 'Segoe UI'
    Font.Style = []
    ParentFont = False
  end
  object edName: TEdit
    Left = 90
    Top = 12
    Width = 598
    Height = 23
    TabOrder = 0
  end
  object lvSteps: TListView
    Left = 12
    Top = 67
    Width = 320
    Height = 272
    Columns = <
      item
        Caption = 'No'
        Width = 40
      end
      item
        Caption = 'Snippet'
        Width = 200
      end
      item
        Caption = 'Pause, sec'
        Width = 72
      end>
    DragMode = dmAutomatic
    GridLines = True
    HideSelection = False
    ReadOnly = True
    RowSelect = True
    TabOrder = 1
    ViewStyle = vsReport
    OnDragDrop = lvStepsDragDrop
    OnDragOver = lvStepsDragOver
    OnSelectItem = lvStepsSelectItem
  end
  object edPause: TEdit
    Left = 272
    Top = 345
    Width = 60
    Height = 23
    MaxLength = 5
    NumbersOnly = True
    TabOrder = 2
    OnExit = edPauseExit
  end
  object btnMoveUp: TButton
    Left = 12
    Top = 414
    Width = 64
    Height = 28
    Caption = 'Up'
    TabOrder = 3
    OnClick = btnMoveUpClick
  end
  object btnMoveDown: TButton
    Left = 82
    Top = 414
    Width = 64
    Height = 28
    Caption = 'Down'
    TabOrder = 4
    OnClick = btnMoveDownClick
  end
  object btnRemoveStep: TButton
    Left = 228
    Top = 414
    Width = 104
    Height = 28
    Caption = 'Remove step'
    TabOrder = 5
    OnClick = btnRemoveStepClick
  end
  object edSearch: TEdit
    Left = 352
    Top = 67
    Width = 336
    Height = 23
    TabOrder = 6
    TextHint = 'Search...'
    OnChange = edSearchChange
  end
  object lvLibrary: TListView
    Left = 352
    Top = 94
    Width = 336
    Height = 245
    Columns = <
      item
        Caption = 'Snippet'
        Width = 210
      end
      item
        Caption = 'Workspace'
        Width = 118
      end>
    GridLines = True
    HideSelection = False
    ReadOnly = True
    RowSelect = True
    TabOrder = 7
    ViewStyle = vsReport
    OnDblClick = lvLibraryDblClick
    OnSelectItem = lvLibrarySelectItem
  end
  object btnAddStep: TButton
    Left = 352
    Top = 345
    Width = 140
    Height = 28
    Caption = 'Add step'
    Enabled = False
    TabOrder = 8
    OnClick = btnAddStepClick
  end
  object btnOK: TButton
    Left = 492
    Top = 466
    Width = 94
    Height = 28
    Caption = 'OK'
    Default = True
    TabOrder = 9
    OnClick = btnOKClick
  end
  object btnCancel: TButton
    Left = 594
    Top = 466
    Width = 94
    Height = 28
    Cancel = True
    Caption = 'Cancel'
    ModalResult = 2
    TabOrder = 10
  end
end
