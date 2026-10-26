object DryRunForm: TDryRunForm
  Left = 0
  Top = 0
  BorderStyle = bsDialog
  Caption = 'Dry run'
  ClientHeight = 420
  ClientWidth = 560
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  FormStyle = fsStayOnTop
  Position = poScreenCenter
  Scaled = True
  TextHeight = 13
  object pnlMain: TPanel
    Left = 0
    Top = 0
    Width = 560
    Height = 420
    Align = alClient
    BevelOuter = bvNone
    TabOrder = 0
    object rePreview: TRichEdit
      Left = 8
      Top = 8
      Width = 544
      Height = 355
      Anchors = [akLeft, akTop, akRight, akBottom]
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWindowText
      Font.Height = -12
      Font.Name = 'Consolas'
      Font.Style = []
      Lines.Strings = ()
      ParentFont = False
      ReadOnly = True
      ScrollBars = ssBoth
      TabOrder = 0
      WordWrap = False
    end
    object bRun: TButton
      Left = 370
      Top = 368
      Width = 90
      Height = 25
      Anchors = [akRight, akBottom]
      Caption = 'Run'
      Default = True
      ModalResult = 1
      TabOrder = 1
    end
    object bClose: TButton
      Left = 468
      Top = 368
      Width = 84
      Height = 25
      Anchors = [akRight, akBottom]
      Cancel = True
      Caption = 'Close'
      ModalResult = 2
      TabOrder = 2
    end
    object sbBottom: TStatusBar
      Left = 0
      Top = 401
      Width = 560
      Height = 19
      Panels = <>
      SimplePanel = True
      SizeGrip = False
    end
  end
end
