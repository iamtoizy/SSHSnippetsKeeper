object PassphraseForm: TPassphraseForm
  Left = 0
  Top = 0
  BorderStyle = bsDialog
  Caption = #1055#1072#1088#1086#1083#1100#1085#1072#1103' '#1092#1088#1072#1079#1072
  ClientHeight = 158
  ClientWidth = 347
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  FormStyle = fsStayOnTop
  Position = poScreenCenter
  OnShow = FormShow
  TextHeight = 13
  object pnlMain: TPanel
    Left = 0
    Top = 0
    Width = 347
    Height = 158
    Align = alClient
    BevelOuter = bvNone
    TabOrder = 0
    DesignSize = (
      347
      158)
    object lbPrompt: TLabel
      Left = 8
      Top = 8
      Width = 137
      Height = 13
      Caption = #1042#1074#1077#1076#1080#1090#1077' '#1087#1072#1088#1086#1083#1100#1085#1091#1102' '#1092#1088#1072#1079#1091
    end
    object bOK: TButton
      Left = 202
      Top = 108
      Width = 72
      Height = 25
      Anchors = [akTop, akRight]
      Caption = 'OK'
      Enabled = False
      TabOrder = 0
      OnClick = bOKClick
    end
    object bCancel: TButton
      Left = 280
      Top = 108
      Width = 67
      Height = 25
      Anchors = [akTop, akRight]
      Caption = #1054#1090#1084#1077#1085#1072
      ModalResult = 2
      TabOrder = 1
    end
    object sbBottom: TStatusBar
      Left = 0
      Top = 139
      Width = 347
      Height = 19
      Panels = <>
      SimplePanel = True
      SizeGrip = False
    end
    object ebPass: TEdit
      Left = 8
      Top = 27
      Width = 331
      Height = 21
      Anchors = [akLeft, akTop, akRight]
      PasswordChar = '*'
      TabOrder = 2
      OnChange = ebPassChange
      OnKeyDown = ebPassKeyDown
    end
    object lbConfirm: TLabel
      Left = 8
      Top = 58
      Width = 150
      Height = 13
      Caption = #1055#1086#1074#1090#1086#1088#1080#1090#1077' '#1087#1072#1088#1086#1083#1100#1085#1091#1102' '#1092#1088#1072#1079#1091
    end
    object ebConfirm: TEdit
      Left = 8
      Top = 77
      Width = 331
      Height = 21
      Anchors = [akLeft, akTop, akRight]
      PasswordChar = '*'
      TabOrder = 3
      OnChange = ebConfirmChange
      OnKeyDown = ebConfirmKeyDown
    end
  end
end
