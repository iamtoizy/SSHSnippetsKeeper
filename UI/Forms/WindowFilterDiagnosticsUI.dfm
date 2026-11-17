object WindowFilterDiagnosticsDialog: TWindowFilterDiagnosticsDialog
  Left = 0
  Top = 0
  BorderStyle = bsDialog
  Caption = ''
  ClientHeight = 480
  ClientWidth = 760
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  Position = poScreenCenter
  TextHeight = 15
  KeyPreview = True
  OnKeyDown = FormKeyDown
  object lblTitle: TLabel
    Left = 12
    Top = 12
    Width = 300
    Height = 15
    Caption = 'lblTitle'
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clWindowText
    Font.Height = -12
    Font.Name = 'Segoe UI'
    Font.Style = [fsBold]
    ParentFont = False
  end
  object lbHint: TLabel
    Left = 12
    Top = 34
    Width = 736
    Height = 28
    AutoSize = False
    Caption = ''
    WordWrap = True
  end
  object pList: TPanel
    Left = 0
    Top = 66
    Width = 760
    Height = 414
    BevelOuter = bvNone
    TabOrder = 0
    object lvTable: TListView
      Left = 8
      Top = 4
      Width = 744
      Height = 375
      Columns = <
        item
          Caption = 'App'
          Width = 130
        end
        item
          Caption = 'Title'
          Width = 250
        end
        item
          Caption = 'Class'
          Width = 150
        end
        item
          Caption = 'Status'
          Width = 200
        end>
      HideSelection = False
      ReadOnly = True
      RowSelect = True
      TabOrder = 0
      ViewStyle = vsReport
      OnDblClick = lvTableDblClick
      OnCustomDrawItem = lvTableCustomDrawItem
    end
    object lbTableEmpty: TLabel
      Left = 16
      Top = 170
      Width = 728
      Height = 40
      AutoSize = False
      Caption = ''
      Visible = False
      WordWrap = True
    end
    object pListButtons: TPanel
      Left = 0
      Top = 338
      Width = 760
      Height = 35
      Align = alBottom
      BevelOuter = bvNone
      TabOrder = 1
      object bRefresh: TButton
        Left = 8
        Top = 5
        Width = 110
        Height = 25
        Caption = 'Refresh'
        TabOrder = 0
        OnClick = bRefreshClick
      end
      object lbSummary: TLabel
        Left = 128
        Top = 11
        Width = 430
        Height = 15
        AutoSize = False
        Caption = ''
      end
      object chkAllProcesses: TCheckBox
        Left = 566
        Top = 10
        Width = 185
        Height = 17
        Caption = 'ShowAll'
        TabOrder = 1
        OnClick = chkAllProcessesClick
      end
    end
  end
  object ttAutoRefresh: TTimer
    Interval = 2000
    OnTimer = ttAutoRefreshTimer
    Left = 24
    Top = 56
  end
end
