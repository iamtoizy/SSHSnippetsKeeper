object InputForm: TInputForm
  Left = 0
  Top = 0
  BorderStyle = bsDialog
  Caption = #1042#1074#1086#1076' '#1079#1085#1072#1095#1077#1085#1080#1103
  ClientHeight = 103
  ClientWidth = 347
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  FormStyle = fsStayOnTop
  Position = poScreenCenter
  OnCreate = FormCreate
  OnShow = FormShow
  TextHeight = 13
  object pnlMain: TPanel
    Left = 0
    Top = 0
    Width = 347
    Height = 103
    Align = alClient
    BevelOuter = bvNone
    TabOrder = 0
    object lbPrompt: TLabel
      Left = 8
      Top = 8
      Width = 85
      Height = 13
      Caption = #1042#1074#1077#1076#1080' '#1079#1085#1072#1095#1077#1085#1080#1077':'
    end
    object bOK: TButton
      Left = 202
      Top = 53
      Width = 72
      Height = 25
      Caption = 'OK'
      TabOrder = 0
      OnClick = bOKClick
    end
    object bCancel: TButton
      Left = 280
      Top = 53
      Width = 67
      Height = 25
      Caption = #1054#1090#1084#1077#1085#1072
      ModalResult = 2
      TabOrder = 1
      OnClick = bCancelClick
    end
    object sbBottom: TStatusBar
      Left = 0
      Top = 84
      Width = 347
      Height = 19
      Panels = <>
      SimplePanel = True
      SizeGrip = False
    end
    object ebEdit: TEdit
      Left = 8
      Top = 27
      Width = 339
      Height = 21
      TabOrder = 3
      OnChange = ebEditChange
      OnKeyDown = ebEditKeyDown
    end
  end
end
