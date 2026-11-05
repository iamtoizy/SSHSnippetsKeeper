object SecurityReportForm: TSecurityReportForm
  Left = 0
  Top = 0
  Caption = 'SecurityReportForm'
  ClientHeight = 520
  ClientWidth = 760
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  FormStyle = fsStayOnTop
  Position = poScreenCenter
  TextHeight = 15
  object lbSummary: TLabel
    Left = 0
    Top = 0
    Width = 760
    Height = 30
    Align = alTop
    Alignment = taCenter
    AutoSize = False
    Caption = 'lbSummary'
    Layout = tlCenter
    WordWrap = True
    ExplicitWidth = 720
  end
  object lvFindings: TListView
    Left = 0
    Top = 30
    Width = 760
    Height = 457
    Align = alClient
    Columns = <
      item
        Caption = 'colSnippet'
        Tag = 1
        Width = 220
      end
      item
        Caption = 'colCategory'
        Tag = 2
        Width = 140
      end
      item
        Caption = 'colReason'
        Tag = 3
        Width = 280
      end
      item
        Caption = 'colTrusted'
        Tag = 4
        Width = 90
      end>
    DoubleBuffered = True
    GridLines = True
    HideSelection = False
    ParentDoubleBuffered = False
    ReadOnly = True
    RowSelect = True
    ShowHint = False
    TabOrder = 1
    ViewStyle = vsReport
    OnDblClick = lvFindingsDblClick
  end
  object pBottom: TPanel
    Left = 0
    Top = 487
    Width = 760
    Height = 33
    Align = alBottom
    BevelOuter = bvNone
    TabOrder = 0
    DesignSize = (
      760
      33)
    object bClose: TButton
      Left = 658
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
end
