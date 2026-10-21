object HistoryForm: THistoryForm
  Left = 0
  Top = 0
  Caption = 'HistoryForm'
  ClientHeight = 520
  ClientWidth = 784
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
    Top = 487
    Width = 784
    Height = 33
    Align = alBottom
    BevelOuter = bvNone
    TabOrder = 0
    DesignSize = (
      784
      33)
    object bRestore: TButton
      Left = 480
      Top = 6
      Width = 148
      Height = 25
      Anchors = [akTop, akRight]
      Caption = 'bRestore'
      Enabled = False
      TabOrder = 0
      OnClick = bRestoreClick
    end
    object bClose: TButton
      Left = 636
      Top = 6
      Width = 89
      Height = 25
      Anchors = [akTop, akRight]
      Cancel = True
      Caption = 'bClose'
      TabOrder = 1
      OnClick = bCloseClick
    end
  end
  object mDiff: TSynEdit
    Left = 0
    Top = 180
    Width = 784
    Height = 307
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
    TabOrder = 1
    OnSpecialLineColors = mDiffSpecialLineColors
    Gutter.Font.Charset = DEFAULT_CHARSET
    Gutter.Font.Color = clWindowText
    Gutter.Font.Height = -11
    Gutter.Font.Name = 'Consolas'
    Gutter.Font.Style = []
    Gutter.Font.Quality = fqClearTypeNatural
    Gutter.Visible = False
  end
  object lvVersions: TListView
    Left = 0
    Top = 0
    Width = 784
    Height = 180
    Align = alTop
    Columns = <
      item
        Caption = 'Date'
        Tag = 0
        Width = 150
      end
      item
        Caption = 'Title'
        Tag = 1
        Width = 460
      end
      item
        Caption = 'Size'
        Tag = 2
        Width = 90
      end>
    HideSelection = False
    ReadOnly = True
    RowSelect = True
    TabOrder = 2
    ViewStyle = vsReport
    OnSelectItem = lvVersionsSelectItem
  end
end
