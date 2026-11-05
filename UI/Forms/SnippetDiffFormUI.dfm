object SnippetDiffForm: TSnippetDiffForm
  Left = 0
  Top = 0
  Caption = 'SnippetDiffForm'
  ClientHeight = 480
  ClientWidth = 720
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  FormStyle = fsStayOnTop
  Position = poScreenCenter
  TextHeight = 15
  object pBottom: TPanel
    Left = 0
    Top = 447
    Width = 720
    Height = 33
    Align = alBottom
    BevelOuter = bvNone
    TabOrder = 0
    DesignSize = (
      720
      33)
    object bClose: TButton
      Left = 618
      Top = 6
      Width = 89
      Height = 25
      Anchors = [akTop, akRight]
      Cancel = True
      Caption = 'bClose'
      ModalResult = 2
      TabOrder = 0
    end
  end
  object lbHeader: TLabel
    Left = 0
    Top = 0
    Width = 720
    Height = 24
    Align = alTop
    Alignment = taCenter
    AutoSize = False
    Caption = 'lbHeader'
    Layout = tlCenter
    WordWrap = True
    ExplicitWidth = 720
  end
  object mDiff: TSynEdit
    Left = 0
    Top = 24
    Width = 720
    Height = 423
    Align = alClient
    DoubleBuffered = True
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clWindowText
    Font.Height = -13
    Font.Name = 'Consolas'
    Font.Style = []
    Font.Quality = fqClearTypeNatural
    ParentDoubleBuffered = False
    ReadOnly = True
    TabOrder = 2
    OnSpecialLineColors = mDiffSpecialLineColors
    Gutter.Font.Charset = DEFAULT_CHARSET
    Gutter.Font.Color = clWindowText
    Gutter.Font.Height = -11
    Gutter.Font.Name = 'Consolas'
    Gutter.Font.Style = []
    Gutter.Font.Quality = fqClearTypeNatural
    Gutter.Visible = False
  end
end
