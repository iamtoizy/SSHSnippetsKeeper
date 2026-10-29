object QuickSearchForm: TQuickSearchForm
  Left = 0
  Top = 0
  AlphaBlend = True
  AlphaBlendValue = 230
  BorderStyle = bsNone
  Caption = #1041#1099#1089#1090#1088#1099#1081' '#1087#1086#1080#1089#1082
  ClientHeight = 200
  ClientWidth = 667
  Color = clBtnFace
  Constraints.MinHeight = 200
  Constraints.MinWidth = 200
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  FormStyle = fsStayOnTop
  KeyPreview = True
  Padding.Left = 3
  Padding.Top = 3
  Padding.Right = 3
  Padding.Bottom = 3
  Position = poScreenCenter
  RoundedCorners = rcSmall
  ScreenSnap = True
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  OnHide = FormHide
  OnKeyDown = FormKeyDown
  OnResize = FormResize
  TextHeight = 15
  object pnlTop: TPanel
    Left = 3
    Top = 3
    Width = 661
    Height = 27
    Align = alTop
    BevelOuter = bvNone
    TabOrder = 0
    OnResize = pnlTopResize
    object ebQuickSearch: TEdit
      Left = 0
      Top = 2
      Width = 164
      Height = 23
      TabOrder = 0
      OnChange = ebQuickSearchChange
    end
    object rbText: TRadioButton
      Left = 170
      Top = 5
      Width = 125
      Height = 17
      Caption = #1058#1077#1082#1089#1090#1086#1074#1099#1081
      Checked = True
      TabOrder = 1
      TabStop = True
    end
    object rbFTS: TRadioButton
      Left = 301
      Top = 5
      Width = 108
      Height = 17
      Caption = 'FTS'
      TabOrder = 2
    end
    object cbUser: TComboBox
      Left = 415
      Top = 2
      Width = 220
      Height = 23
      Hint = #1058#1077#1082#1091#1097#1077#1077' '#1087#1088#1086#1089#1090#1088#1072#1085#1089#1090#1074#1086
      Style = csDropDownList
      DropDownCount = 18
      ParentShowHint = False
      ShowHint = True
      TabOrder = 3
      OnChange = cbUserChange
    end
  end
  object lvQuickResults: TListView
    Left = 3
    Top = 30
    Width = 661
    Height = 166
    Columns = <>
    ParentShowHint = False
    ShowHint = True
    TabOrder = 1
    ViewStyle = vsList
    OnDblClick = lvQuickResultsDblClick
    OnDeletion = lvQuickResultsDeletion
    OnEnter = lvQuickResultsEnter
    OnKeyDown = lvQuickResultsKeyDown
  end
end
