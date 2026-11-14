object CompletionManagerForm: TCompletionManagerForm
  Left = 0
  Top = 0
  BorderIcons = [biSystemMenu]
  BorderStyle = bsDialog
  Caption = #1052#1077#1085#1077#1076#1078#1077#1088' '#1072#1074#1090#1086#1076#1086#1087#1086#1083#1085#1077#1085#1080#1103
  ClientHeight = 565
  ClientWidth = 640
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  Position = poScreenCenter
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  TextHeight = 15
  object pcMain: TPageControl
    Left = 0
    Top = 0
    Width = 640
    Height = 448
    ActivePage = tsBash
    Align = alClient
    TabOrder = 0
    OnChange = pcMainChange
    ExplicitHeight = 431
    object tsBash: TTabSheet
      Caption = 'Bash'
      object pBashCmds: TPanel
        Left = 402
        Top = 0
        Width = 230
        Height = 418
        Align = alRight
        BevelOuter = bvNone
        TabOrder = 0
        ExplicitHeight = 401
        object lvBashCmds: TListView
          Left = 0
          Top = 0
          Width = 230
          Height = 418
          Align = alClient
          Columns = <>
          ReadOnly = True
          TabOrder = 0
          ViewStyle = vsList
          OnSelectItem = lvSelectItem
          ExplicitHeight = 401
        end
      end
      object tvBash: TTreeView
        Left = 0
        Top = 0
        Width = 402
        Height = 418
        Align = alClient
        DragMode = dmAutomatic
        HideSelection = False
        Indent = 19
        TabOrder = 1
        OnChange = tvChange
        OnDragDrop = tvDragDrop
        OnDragOver = tvDragOver
        ExplicitLeft = 5
        ExplicitWidth = 397
        ExplicitHeight = 401
      end
    end
    object tsBat: TTabSheet
      Caption = 'CMD'
      ImageIndex = 1
      object pBatCmds: TPanel
        Left = 402
        Top = 0
        Width = 230
        Height = 418
        Align = alRight
        BevelOuter = bvNone
        TabOrder = 0
        ExplicitHeight = 401
        object lvBatCmds: TListView
          Left = 0
          Top = 0
          Width = 230
          Height = 418
          Align = alClient
          Columns = <>
          ReadOnly = True
          TabOrder = 0
          ViewStyle = vsList
          OnSelectItem = lvSelectItem
          ExplicitHeight = 401
        end
      end
      object tvBat: TTreeView
        Left = 0
        Top = 0
        Width = 402
        Height = 418
        Align = alClient
        DragMode = dmAutomatic
        HideSelection = False
        Indent = 19
        TabOrder = 1
        OnChange = tvChange
        OnDragDrop = tvDragDrop
        OnDragOver = tvDragOver
        ExplicitLeft = 5
        ExplicitWidth = 397
        ExplicitHeight = 401
      end
    end
    object tsPowerShell: TTabSheet
      Caption = 'PowerShell'
      ImageIndex = 2
      object pPSCmds: TPanel
        Left = 402
        Top = 0
        Width = 230
        Height = 418
        Align = alRight
        BevelOuter = bvNone
        TabOrder = 0
        ExplicitHeight = 401
        object lvPSCmds: TListView
          Left = 0
          Top = 0
          Width = 230
          Height = 418
          Align = alClient
          Columns = <>
          ReadOnly = True
          TabOrder = 0
          ViewStyle = vsList
          OnSelectItem = lvSelectItem
          ExplicitHeight = 401
        end
      end
      object tvPS: TTreeView
        Left = 0
        Top = 0
        Width = 402
        Height = 418
        Align = alClient
        DragMode = dmAutomatic
        HideSelection = False
        Indent = 19
        TabOrder = 1
        OnChange = tvChange
        OnDragDrop = tvDragDrop
        OnDragOver = tvDragOver
        ExplicitLeft = 5
        ExplicitWidth = 397
        ExplicitHeight = 401
      end
    end
  end
  object pEdit: TPanel
    Left = 0
    Top = 448
    Width = 640
    Height = 80
    Align = alBottom
    BevelOuter = bvNone
    TabOrder = 1
    ExplicitTop = 431
    object gbTree: TGroupBox
      Left = 0
      Top = 0
      Width = 375
      Height = 80
      Align = alLeft
      Caption = #1044#1077#1088#1077#1074#1086
      TabOrder = 0
      object pTreeBtns: TPanel
        AlignWithMargins = True
        Left = 10
        Top = 19
        Width = 355
        Height = 23
        Margins.Left = 8
        Margins.Top = 2
        Margins.Right = 8
        Margins.Bottom = 2
        Align = alTop
        BevelOuter = bvNone
        TabOrder = 0
        object btnDelete: TButton
          Left = 292
          Top = 0
          Width = 63
          Height = 23
          Align = alRight
          Caption = #1059#1076#1072#1083#1080#1090#1100
          TabOrder = 0
          OnClick = btnDeleteClick
        end
        object btnAddChild: TButton
          Left = 200
          Top = 0
          Width = 92
          Height = 23
          Align = alRight
          Caption = #1044#1086#1073#1072#1074#1080#1090#1100' '#1074#1083#1086#1078'.'
          TabOrder = 1
          OnClick = btnAddChildClick
        end
        object btnAdd: TButton
          Left = 132
          Top = 0
          Width = 68
          Height = 23
          Align = alRight
          Caption = #1044#1086#1073#1072#1074#1080#1090#1100
          TabOrder = 2
          OnClick = btnAddClick
        end
        object edTreeFilter: TEdit
          Left = 0
          Top = 0
          Width = 132
          Height = 23
          Align = alClient
          TabOrder = 3
          TextHint = #1060#1080#1083#1100#1090#1088' '#1076#1077#1088#1077#1074#1072
          OnChange = edTreeFilterChange
        end
      end
      object pTreeRow: TPanel
        AlignWithMargins = True
        Left = 10
        Top = 46
        Width = 355
        Height = 23
        Margins.Left = 8
        Margins.Top = 2
        Margins.Right = 8
        Margins.Bottom = 2
        Align = alTop
        BevelOuter = bvNone
        TabOrder = 1
        object btnApply: TButton
          Left = 275
          Top = 0
          Width = 80
          Height = 23
          Align = alRight
          Caption = #1055#1088#1080#1084#1077#1085#1080#1090#1100
          TabOrder = 0
          OnClick = btnApplyClick
        end
        object edName: TEdit
          Left = 0
          Top = 0
          Width = 110
          Height = 23
          Align = alLeft
          TabOrder = 1
          TextHint = #1048#1084#1103
        end
        object edInsert: TEdit
          Left = 110
          Top = 0
          Width = 165
          Height = 23
          Align = alClient
          TabOrder = 2
          TextHint = #1042#1089#1090#1072#1074#1082#1072
        end
      end
    end
    object gbCommands: TGroupBox
      Left = 375
      Top = 0
      Width = 265
      Height = 80
      Align = alClient
      Caption = #1050#1086#1084#1072#1085#1076#1099
      TabOrder = 1
      object pCmdRow: TPanel
        AlignWithMargins = True
        Left = 10
        Top = 46
        Width = 245
        Height = 23
        Margins.Left = 8
        Margins.Top = 2
        Margins.Right = 8
        Margins.Bottom = 2
        Align = alTop
        BevelOuter = bvNone
        TabOrder = 0
        object btnCmdDelete: TButton
          Left = 170
          Top = 0
          Width = 75
          Height = 23
          Align = alRight
          Caption = #1059#1076#1072#1083#1080#1090#1100
          TabOrder = 0
          OnClick = btnCmdDeleteClick
        end
        object btnCmdAdd: TButton
          Left = 95
          Top = 0
          Width = 75
          Height = 23
          Align = alRight
          Caption = #1044#1086#1073#1072#1074#1080#1090#1100
          TabOrder = 1
          OnClick = btnCmdAddClick
        end
        object edCommand: TEdit
          Left = 0
          Top = 0
          Width = 95
          Height = 23
          Align = alClient
          TabOrder = 2
          TextHint = #1053#1086#1074#1072#1103' '#1082#1086#1084#1072#1085#1076#1072
        end
      end
      object edCmdFilter: TEdit
        AlignWithMargins = True
        Left = 10
        Top = 19
        Width = 245
        Height = 23
        Margins.Left = 8
        Margins.Top = 2
        Margins.Right = 8
        Margins.Bottom = 2
        Align = alTop
        TabOrder = 1
        TextHint = #1060#1080#1083#1100#1090#1088' '#1082#1086#1084#1072#1085#1076
        OnChange = edCmdFilterChange
      end
    end
  end
  object pBottom: TPanel
    Left = 0
    Top = 528
    Width = 640
    Height = 37
    Align = alBottom
    BevelOuter = bvNone
    TabOrder = 2
    DesignSize = (
      640
      37)
    object btnImport: TButton
      Left = 6
      Top = 6
      Width = 75
      Height = 23
      Caption = #1048#1084#1087#1086#1088#1090
      TabOrder = 0
      OnClick = btnImportClick
    end
    object btnExport: TButton
      Left = 88
      Top = 6
      Width = 75
      Height = 23
      Caption = #1069#1082#1089#1087#1086#1088#1090
      TabOrder = 1
      OnClick = btnExportClick
    end
    object btnSave: TButton
      Left = 454
      Top = 6
      Width = 88
      Height = 23
      Anchors = [akTop, akRight]
      Caption = #1057#1086#1093#1088#1072#1085#1080#1090#1100
      TabOrder = 2
      OnClick = btnSaveClick
    end
    object btnClose: TButton
      Left = 548
      Top = 6
      Width = 82
      Height = 23
      Anchors = [akTop, akRight]
      Cancel = True
      Caption = #1047#1072#1082#1088#1099#1090#1100
      TabOrder = 3
      OnClick = btnCloseClick
    end
  end
end
