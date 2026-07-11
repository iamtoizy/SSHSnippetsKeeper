object QuickSearchForm: TQuickSearchForm
  Left = 0
  Top = 0
  AlphaBlend = True
  AlphaBlendValue = 230
  BorderStyle = bsNone
  Caption = #1041#1099#1089#1090#1088#1099#1081' '#1087#1086#1080#1089#1082
  ClientHeight = 199
  ClientWidth = 667
  Color = clBtnFace
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
  DesignSize = (
    667
    199)
  TextHeight = 15
  object lvQuickResults: TListView
    Left = 1
    Top = 25
    Width = 663
    Height = 172
    Anchors = [akLeft, akTop, akRight, akBottom]
    Columns = <>
    ParentShowHint = False
    ShowHint = True
    TabOrder = 1
    ViewStyle = vsList
    OnDblClick = lvQuickResultsDblClick
    OnEnter = lvQuickResultsEnter
    OnKeyDown = lvQuickResultsKeyDown
  end
  object cbUser: TComboBox
    Left = 444
    Top = 1
    Width = 220
    Height = 23
    Hint = #1058#1077#1082#1091#1097#1077#1077' '#1087#1088#1086#1089#1090#1088#1072#1085#1089#1090#1074#1086'. '#1053#1072#1078#1084#1080' '#9881' '#1076#1083#1103' '#1091#1087#1088#1072#1074#1083#1077#1085#1080#1103'.'
    Style = csDropDownList
    Anchors = [akTop, akRight]
    DropDownCount = 18
    ParentShowHint = False
    ShowHint = True
    TabOrder = 2
    OnChange = cbUserChange
  end
  object ebQuickSearch: TEdit
    Left = 1
    Top = 1
    Width = 296
    Height = 23
    Anchors = [akLeft, akTop, akRight]
    TabOrder = 0
    OnChange = ebQuickSearchChange
    ExplicitWidth = 297
  end
  object rbFTS: TRadioButton
    Left = 393
    Top = 4
    Width = 42
    Height = 17
    Anchors = [akTop, akRight]
    Caption = 'FTS'
    TabOrder = 3
    ExplicitLeft = 394
  end
  object rbText: TRadioButton
    Left = 304
    Top = 4
    Width = 83
    Height = 17
    Anchors = [akTop, akRight]
    Caption = #1058#1077#1082#1089#1090#1086#1074#1099#1081
    Checked = True
    TabOrder = 4
    TabStop = True
    ExplicitLeft = 305
  end
end
