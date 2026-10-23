object MacroBuilderForm: TMacroBuilderForm
  Left = 0
  Top = 0
  BorderStyle = bsDialog
  Caption = #1050#1086#1085#1089#1090#1088#1091#1082#1090#1086#1088' '#1084#1072#1082#1088#1086#1089#1086#1074
  ClientHeight = 500
  ClientWidth = 630
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  FormStyle = fsStayOnTop
  Position = poScreenCenter
  OnCreate = FormCreate
  TextHeight = 13
  object pnlSteps: TPanel
    Left = 0
    Top = 0
    Width = 372
    Height = 298
    Align = alClient
    BevelOuter = bvNone
    TabOrder = 0
    object lbHint: TLabel
      Left = 8
      Top = 6
      Width = 96
      Height = 13
      Align = alTop
      AutoSize = False
      Caption = #1064#1072#1075#1080' '#1084#1072#1082#1088#1086#1089#1072':'
    end
    object lvSteps: TListView
      Left = 8
      Top = 26
      Width = 356
      Height = 264
      Align = alClient
      Columns = <
        item
          Caption = '#'
          Tag = 0
          Width = 34
        end
        item
          Caption = #1058#1080#1087
          Tag = 1
          Width = 110
        end
        item
          Caption = #1064#1072#1075
          Tag = 2
          Width = 210
        end>
      GridLines = True
      HideSelection = False
      ReadOnly = True
      RowSelect = True
      TabOrder = 0
      ViewStyle = vsReport
      OnSelectItem = lvStepsSelectItem
    end
  end
  object pnlProps: TPanel
    Left = 372
    Top = 0
    Width = 258
    Height = 298
    Align = alRight
    BevelOuter = bvNone
    TabOrder = 1
    object lbPropType: TLabel
      Left = 8
      Top = 10
      Width = 60
      Height = 13
      Caption = #1058#1080#1087':'
    end
    object cbPropType: TComboBox
      Left = 8
      Top = 26
      Width = 234
      Height = 21
      Style = csDropDownList
      ItemHeight = 13
      TabOrder = 0
      OnChange = PropChanged
    end
    object lbProp1: TLabel
      Left = 8
      Top = 58
      Width = 30
      Height = 13
    end
    object ebProp1: TEdit
      Left = 8
      Top = 74
      Width = 234
      Height = 21
      TabOrder = 1
      OnChange = PropChanged
    end
    object lbProp2: TLabel
      Left = 8
      Top = 106
      Width = 30
      Height = 13
    end
    object ebProp2: TEdit
      Left = 8
      Top = 122
      Width = 234
      Height = 21
      TabOrder = 2
      OnChange = PropChanged
    end
    object lbProp3: TLabel
      Left = 8
      Top = 154
      Width = 30
      Height = 13
    end
    object ebProp3: TEdit
      Left = 8
      Top = 170
      Width = 234
      Height = 21
      TabOrder = 3
      OnChange = PropChanged
    end
  end
  object pnlAdd: TPanel
    Left = 0
    Top = 298
    Width = 630
    Height = 38
    Align = alBottom
    BevelOuter = bvNone
    TabOrder = 2
    object lbAddType: TLabel
      Left = 8
      Top = 12
      Width = 60
      Height = 13
      Caption = #1058#1080#1087' '#1096#1072#1075#1072':'
    end
    object cbStepType: TComboBox
      Left = 80
      Top = 8
      Width = 150
      Height = 21
      Style = csDropDownList
      ItemHeight = 13
      TabOrder = 0
    end
    object bAddStep: TButton
      Left = 240
      Top = 7
      Width = 84
      Height = 23
      Caption = #1044#1086#1073#1072#1074#1080#1090#1100
      TabOrder = 1
      OnClick = bAddStepClick
    end
    object bStepUp: TButton
      Left = 336
      Top = 7
      Width = 30
      Height = 23
      Caption = #8593
      TabOrder = 2
      OnClick = bStepUpClick
    end
    object bStepDown: TButton
      Left = 370
      Top = 7
      Width = 30
      Height = 23
      Caption = #8595
      TabOrder = 3
      OnClick = bStepDownClick
    end
    object bStepDelete: TButton
      Left = 410
      Top = 7
      Width = 90
      Height = 23
      Caption = #1059#1076#1072#1083#1080#1090#1100
      TabOrder = 4
      OnClick = bStepDeleteClick
    end
  end
  object pnlPreview: TPanel
    Left = 0
    Top = 336
    Width = 630
    Height = 126
    Align = alBottom
    BevelOuter = bvNone
    TabOrder = 3
    object lbPreview: TLabel
      Left = 8
      Top = 4
      Width = 50
      Height = 13
      Caption = #1055#1088#1077#1074#1100#1102':'
    end
    object mPreview: TMemo
      Left = 8
      Top = 22
      Width = 614
      Height = 96
      Anchors = [akLeft, akTop, akRight, akBottom]
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWindowText
      Font.Height = -11
      Font.Name = 'Consolas'
      Font.Style = []
      ParentFont = False
      ReadOnly = True
      ScrollBars = ssVertical
      TabOrder = 0
    end
  end
  object pnlButtons: TPanel
    Left = 0
    Top = 462
    Width = 630
    Height = 38
    Align = alBottom
    BevelOuter = bvNone
    TabOrder = 4
    object bCancel: TButton
      Left = 130
      Top = 7
      Width = 80
      Height = 25
      Anchors = [akRight, akBottom]
      Caption = #1054#1090#1084#1077#1085#1072
      ModalResult = 2
      TabOrder = 0
    end
    object bReplaceAll: TButton
      Left = 220
      Top = 7
      Width = 130
      Height = 25
      Anchors = [akRight, akBottom]
      Caption = #1047#1072#1084#1077#1085#1080#1090#1100' '#1074#1089#1105
      TabOrder = 1
      OnClick = bReplaceAllClick
    end
    object bInsert: TButton
      Left = 360
      Top = 7
      Width = 150
      Height = 25
      Anchors = [akRight, akBottom]
      Caption = #1042#1089#1090#1072#1074#1080#1090#1100' '#1074' '#1082#1091#1088#1089#1086#1088
      TabOrder = 2
      OnClick = bInsertClick
    end
  end
end
