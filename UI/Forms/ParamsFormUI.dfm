object ParamsForm: TParamsForm
  Left = 0
  Top = 0
  BorderStyle = bsDialog
  Caption = #1055#1072#1088#1072#1084#1077#1090#1088#1099' '#1089#1085#1080#1087#1087#1077#1090#1072
  ClientHeight = 191
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
  TextHeight = 13
  object pnlMain: TPanel
    Left = 0
    Top = 0
    Width = 347
    Height = 191
    Align = alClient
    BevelOuter = bvNone
    TabOrder = 0
    DesignSize = (
      347
      191)
    object lbPrompt: TLabel
      Left = 8
      Top = 8
      Width = 61
      Height = 13
      Caption = #1055#1072#1088#1072#1084#1077#1090#1088#1099':'
    end
    object sbRows: TScrollBox
      Left = 8
      Top = 27
      Width = 331
      Height = 100
      Anchors = [akLeft, akTop, akRight, akBottom]
      BevelInner = bvNone
      BevelOuter = bvNone
      BorderStyle = bsNone
      TabOrder = 0
    end
    object bOK: TButton
      Left = 202
      Top = 131
      Width = 72
      Height = 25
      Anchors = [akRight, akBottom]
      Caption = 'OK'
      TabOrder = 1
      OnClick = bOKClick
    end
    object bCancel: TButton
      Left = 280
      Top = 131
      Width = 67
      Height = 25
      Anchors = [akRight, akBottom]
      Caption = #1054#1090#1084#1077#1085#1072
      ModalResult = 2
      TabOrder = 2
      OnClick = bCancelClick
    end
    object sbBottom: TStatusBar
      Left = 0
      Top = 172
      Width = 347
      Height = 19
      Panels = <>
      SimplePanel = True
      SizeGrip = False
    end
  end
end
