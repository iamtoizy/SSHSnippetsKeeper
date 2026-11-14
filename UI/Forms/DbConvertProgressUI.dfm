object DbConvertProgressForm: TDbConvertProgressForm
  Left = 0
  Top = 0
  BorderIcons = []
  BorderStyle = bsDialog
  Caption = #1055#1088#1077#1086#1073#1088#1072#1079#1086#1074#1072#1085#1080#1077' '#1073#1072#1079#1099' '#1076#1072#1085#1085#1099#1093
  ClientHeight = 110
  ClientWidth = 320
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  FormStyle = fsStayOnTop
  Position = poScreenCenter
  OnCloseQuery = FormCloseQuery
  OnShow = FormShow
  TextHeight = 13
  object pnlMain: TPanel
    Left = 0
    Top = 0
    Width = 320
    Height = 110
    Align = alClient
    BevelOuter = bvNone
    TabOrder = 0
    DesignSize = (
      320
      110)
    object lbText: TLabel
      Left = 12
      Top = 14
      Width = 296
      Height = 48
      Anchors = [akLeft, akTop, akRight]
      AutoSize = False
      WordWrap = True
    end
    object pbWork: TProgressBar
      Left = 12
      Top = 76
      Width = 296
      Height = 17
      Anchors = [akLeft, akTop, akRight]
      Style = pbstMarquee
      TabOrder = 0
    end
  end
end
