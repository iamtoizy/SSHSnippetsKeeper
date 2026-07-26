object CronGenForm: TCronGenForm
  Left = 0
  Top = 0
  BorderStyle = bsDialog
  Caption = #1043#1077#1085#1077#1088#1072#1090#1086#1088' '#1080' '#1087#1072#1088#1089#1077#1088' Cron-'#1079#1072#1076#1072#1095
  ClientHeight = 513
  ClientWidth = 650
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  Position = poScreenCenter
  OnCreate = FormCreate
  OnShow = FormShow
  TextHeight = 15
  object pnlTop: TPanel
    Left = 0
    Top = 0
    Width = 650
    Height = 169
    Align = alTop
    BevelOuter = bvNone
    ShowCaption = False
    TabOrder = 0
    object lbTitle: TLabel
      Left = 4
      Top = 2
      Width = 103
      Height = 15
      Caption = 'Cron-'#1074#1099#1088#1072#1078#1077#1085#1080#1077':'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWindowText
      Font.Height = -12
      Font.Name = 'Segoe UI'
      Font.Style = [fsBold]
      ParentFont = False
    end
    object edtCronExpression: TEdit
      Left = 4
      Top = 21
      Width = 500
      Height = 21
      AutoSize = False
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWindowText
      Font.Height = -12
      Font.Name = 'Consolas'
      Font.Style = []
      ParentFont = False
      TabOrder = 0
      OnChange = edtCronExpressionChange
    end
    object bCopy: TButton
      Left = 510
      Top = 20
      Width = 140
      Height = 23
      Caption = #1057#1082#1086#1087#1080#1088#1086#1074#1072#1090#1100
      TabOrder = 1
      OnClick = bCopyClick
    end
    object mHumanText: TMemo
      Left = 4
      Top = 48
      Width = 646
      Height = 115
      ReadOnly = True
      ScrollBars = ssVertical
      TabOrder = 2
    end
  end
  object pgcBuilder: TPageControl
    Left = 0
    Top = 169
    Width = 650
    Height = 344
    ActivePage = tsMinutes
    Align = alClient
    TabOrder = 1
    object tsMinutes: TTabSheet
      Caption = #1052#1080#1085#1091#1090#1099
      DesignSize = (
        642
        314)
      object rbMinEvery: TRadioButton
        Left = 3
        Top = -3
        Width = 186
        Height = 24
        Caption = #1050#1072#1078#1076#1091#1102' '#1084#1080#1085#1091#1090#1091' (*)'
        Checked = True
        TabOrder = 0
        TabStop = True
        OnClick = OnBuilderControlChange
      end
      object rbMinStep: TRadioButton
        Left = 3
        Top = 21
        Width = 186
        Height = 24
        Caption = #1064#1072#1075' ('#1082#1072#1078#1076#1099#1077'):'
        TabOrder = 1
        OnClick = OnBuilderControlChange
      end
      object cboMinStep: TComboBox
        Left = 196
        Top = 21
        Width = 117
        Height = 23
        Style = csDropDownList
        TabOrder = 2
        OnChange = OnBuilderControlChange
      end
      object rbMinRange: TRadioButton
        Left = 3
        Top = 45
        Width = 186
        Height = 24
        Caption = #1044#1080#1072#1087#1072#1079#1086#1085' '#1089':'
        TabOrder = 3
        OnClick = OnBuilderControlChange
      end
      object cboMinRange1: TComboBox
        Left = 196
        Top = 45
        Width = 117
        Height = 23
        Style = csDropDownList
        TabOrder = 4
        OnChange = OnBuilderControlChange
      end
      object cboMinRange2: TComboBox
        Left = 314
        Top = 45
        Width = 117
        Height = 23
        Style = csDropDownList
        TabOrder = 5
        OnChange = OnBuilderControlChange
      end
      object rbMinSpec: TRadioButton
        Left = 3
        Top = 69
        Width = 186
        Height = 24
        Caption = #1059#1082#1072#1079#1072#1090#1100' '#1090#1086#1095#1085#1099#1077' '#1079#1085#1072#1095#1077#1085#1080#1103':'
        TabOrder = 6
        OnClick = OnBuilderControlChange
      end
      object clbMin: TCheckListBox
        Left = 3
        Top = 95
        Width = 636
        Height = 216
        Anchors = [akLeft, akTop, akRight, akBottom]
        Columns = 10
        ItemHeight = 18
        ParentShowHint = False
        ShowHint = False
        TabOrder = 7
        OnClick = OnBuilderControlChange
      end
    end
    object tsHours: TTabSheet
      Caption = #1063#1072#1089#1099
      DesignSize = (
        642
        314)
      object rbHourEvery: TRadioButton
        Left = 3
        Top = 0
        Width = 186
        Height = 17
        Caption = #1050#1072#1078#1076#1099#1081' '#1095#1072#1089' (*)'
        Checked = True
        TabOrder = 0
        TabStop = True
        OnClick = OnBuilderControlChange
      end
      object rbHourStep: TRadioButton
        Left = 3
        Top = 24
        Width = 186
        Height = 17
        Caption = #1064#1072#1075' ('#1082#1072#1078#1076#1099#1077'):'
        TabOrder = 1
        OnClick = OnBuilderControlChange
      end
      object cboHourStep: TComboBox
        Left = 196
        Top = 21
        Width = 117
        Height = 23
        Style = csDropDownList
        TabOrder = 2
        OnChange = OnBuilderControlChange
      end
      object rbHourRange: TRadioButton
        Left = 3
        Top = 48
        Width = 186
        Height = 17
        Caption = #1044#1080#1072#1087#1072#1079#1086#1085' '#1089':'
        TabOrder = 3
        OnClick = OnBuilderControlChange
      end
      object cboHourRange1: TComboBox
        Left = 196
        Top = 45
        Width = 117
        Height = 23
        Style = csDropDownList
        TabOrder = 4
        OnChange = OnBuilderControlChange
      end
      object cboHourRange2: TComboBox
        Left = 314
        Top = 45
        Width = 117
        Height = 23
        Style = csDropDownList
        TabOrder = 5
        OnChange = OnBuilderControlChange
      end
      object rbHourSpec: TRadioButton
        Left = 3
        Top = 72
        Width = 186
        Height = 17
        Caption = #1059#1082#1072#1079#1072#1090#1100' '#1090#1086#1095#1085#1099#1077' '#1079#1085#1072#1095#1077#1085#1080#1103':'
        TabOrder = 6
        OnClick = OnBuilderControlChange
      end
      object clbHour: TCheckListBox
        Left = 3
        Top = 95
        Width = 636
        Height = 216
        Anchors = [akLeft, akTop, akRight, akBottom]
        Columns = 6
        ItemHeight = 18
        TabOrder = 7
        OnClick = OnBuilderControlChange
        ExplicitHeight = 167
      end
    end
    object tsDaysOfMonth: TTabSheet
      Caption = #1044#1085#1080' '#1084#1077#1089#1103#1094#1072
      DesignSize = (
        642
        314)
      object rbDomEvery: TRadioButton
        Left = 3
        Top = -3
        Width = 186
        Height = 24
        Caption = #1050#1072#1078#1076#1099#1081' '#1076#1077#1085#1100' (*)'
        Checked = True
        TabOrder = 0
        TabStop = True
        OnClick = OnBuilderControlChange
      end
      object rbDomStep: TRadioButton
        Left = 3
        Top = 21
        Width = 186
        Height = 24
        Caption = #1064#1072#1075' ('#1082#1072#1078#1076#1099#1077'):'
        TabOrder = 1
        OnClick = OnBuilderControlChange
      end
      object cboDomStep: TComboBox
        Left = 196
        Top = 21
        Width = 117
        Height = 23
        Style = csDropDownList
        TabOrder = 2
        OnChange = OnBuilderControlChange
      end
      object rbDomRange: TRadioButton
        Left = 3
        Top = 45
        Width = 186
        Height = 24
        Caption = #1044#1080#1072#1087#1072#1079#1086#1085' '#1089':'
        TabOrder = 3
        OnClick = OnBuilderControlChange
      end
      object cboDomRange1: TComboBox
        Left = 196
        Top = 45
        Width = 117
        Height = 23
        Style = csDropDownList
        TabOrder = 4
        OnChange = OnBuilderControlChange
      end
      object cboDomRange2: TComboBox
        Left = 314
        Top = 45
        Width = 117
        Height = 23
        Style = csDropDownList
        TabOrder = 5
        OnChange = OnBuilderControlChange
      end
      object rbDomSpec: TRadioButton
        Left = 3
        Top = 69
        Width = 186
        Height = 24
        Caption = #1059#1082#1072#1079#1072#1090#1100' '#1090#1086#1095#1085#1099#1077' '#1079#1085#1072#1095#1077#1085#1080#1103':'
        TabOrder = 6
        OnClick = OnBuilderControlChange
      end
      object clbDom: TCheckListBox
        Left = 3
        Top = 95
        Width = 636
        Height = 216
        Anchors = [akLeft, akTop, akRight, akBottom]
        Columns = 7
        ItemHeight = 18
        TabOrder = 7
        OnClick = OnBuilderControlChange
        ExplicitHeight = 167
      end
    end
    object tsMonths: TTabSheet
      Caption = #1052#1077#1089#1103#1094#1099
      DesignSize = (
        642
        314)
      object rbMonEvery: TRadioButton
        Left = 3
        Top = -3
        Width = 186
        Height = 24
        Caption = #1050#1072#1078#1076#1099#1081' '#1084#1077#1089#1103#1094' (*)'
        Checked = True
        TabOrder = 0
        TabStop = True
        OnClick = OnBuilderControlChange
      end
      object rbMonStep: TRadioButton
        Left = 3
        Top = 21
        Width = 186
        Height = 24
        Caption = #1064#1072#1075' ('#1082#1072#1078#1076#1099#1077'):'
        TabOrder = 1
        OnClick = OnBuilderControlChange
      end
      object cboMonStep: TComboBox
        Left = 196
        Top = 21
        Width = 117
        Height = 23
        Style = csDropDownList
        TabOrder = 2
        OnChange = OnBuilderControlChange
      end
      object rbMonRange: TRadioButton
        Left = 3
        Top = 45
        Width = 186
        Height = 24
        Caption = #1044#1080#1072#1087#1072#1079#1086#1085' '#1089':'
        TabOrder = 3
        OnClick = OnBuilderControlChange
      end
      object cboMonRange1: TComboBox
        Left = 196
        Top = 45
        Width = 117
        Height = 23
        Style = csDropDownList
        TabOrder = 4
        OnChange = OnBuilderControlChange
      end
      object cboMonRange2: TComboBox
        Left = 314
        Top = 45
        Width = 117
        Height = 23
        Style = csDropDownList
        TabOrder = 5
        OnChange = OnBuilderControlChange
      end
      object rbMonSpec: TRadioButton
        Left = 3
        Top = 69
        Width = 186
        Height = 24
        Caption = #1059#1082#1072#1079#1072#1090#1100' '#1090#1086#1095#1085#1099#1077' '#1079#1085#1072#1095#1077#1085#1080#1103':'
        TabOrder = 6
        OnClick = OnBuilderControlChange
      end
      object clbMon: TCheckListBox
        Left = 3
        Top = 95
        Width = 636
        Height = 216
        Anchors = [akLeft, akTop, akRight, akBottom]
        Columns = 7
        ItemHeight = 18
        TabOrder = 7
        OnClick = OnBuilderControlChange
      end
    end
    object tsDaysOfWeek: TTabSheet
      Caption = #1044#1085#1080' '#1085#1077#1076#1077#1083#1080
      DesignSize = (
        642
        314)
      object rbDowEvery: TRadioButton
        Left = 3
        Top = -3
        Width = 186
        Height = 24
        Caption = #1051#1102#1073#1086#1081' '#1076#1077#1085#1100' '#1085#1077#1076#1077#1083#1080' (*)'
        Checked = True
        TabOrder = 0
        TabStop = True
        OnClick = OnBuilderControlChange
      end
      object rbDowStep: TRadioButton
        Left = 3
        Top = 21
        Width = 186
        Height = 24
        Caption = #1064#1072#1075' ('#1082#1072#1078#1076#1099#1077'):'
        TabOrder = 1
        OnClick = OnBuilderControlChange
      end
      object cboDowStep: TComboBox
        Left = 196
        Top = 21
        Width = 117
        Height = 23
        Style = csDropDownList
        TabOrder = 2
        OnChange = OnBuilderControlChange
      end
      object rbDowRange: TRadioButton
        Left = 3
        Top = 45
        Width = 186
        Height = 24
        Caption = #1044#1080#1072#1087#1072#1079#1086#1085' '#1089':'
        TabOrder = 3
        OnClick = OnBuilderControlChange
      end
      object cboDowRange1: TComboBox
        Left = 196
        Top = 45
        Width = 117
        Height = 23
        Style = csDropDownList
        TabOrder = 4
        OnChange = OnBuilderControlChange
      end
      object cboDowRange2: TComboBox
        Left = 314
        Top = 45
        Width = 117
        Height = 23
        Style = csDropDownList
        TabOrder = 5
        OnChange = OnBuilderControlChange
      end
      object rbDowSpec: TRadioButton
        Left = 3
        Top = 69
        Width = 186
        Height = 24
        Caption = #1059#1082#1072#1079#1072#1090#1100' '#1090#1086#1095#1085#1099#1077' '#1079#1085#1072#1095#1077#1085#1080#1103':'
        TabOrder = 6
        OnClick = OnBuilderControlChange
      end
      object clbDow: TCheckListBox
        Left = 3
        Top = 95
        Width = 636
        Height = 216
        Anchors = [akLeft, akTop, akRight, akBottom]
        Columns = 7
        ItemHeight = 18
        TabOrder = 7
        OnClick = OnBuilderControlChange
        ExplicitHeight = 167
      end
    end
  end
end
