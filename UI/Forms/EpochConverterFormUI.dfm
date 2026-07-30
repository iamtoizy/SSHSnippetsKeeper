object EpochConverterForm: TEpochConverterForm
  Left = 0
  Top = 0
  BorderStyle = bsDialog
  Caption = #1050#1086#1085#1074#1077#1088#1090#1077#1088' '#1101#1087#1086#1093
  ClientHeight = 438
  ClientWidth = 477
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  Position = poScreenCenter
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  OnResize = FormResize
  OnShow = FormShow
  TextHeight = 15
  object gbParse: TGroupBox
    Left = 0
    Top = 0
    Width = 477
    Height = 284
    Align = alClient
    Caption = #1048#1089#1093#1086#1076#1085#1099#1081' '#1090#1077#1082#1089#1090'/'#1083#1086#1075
    TabOrder = 0
    object lvParsed: TListView
      Left = 2
      Top = 148
      Width = 473
      Height = 134
      Align = alBottom
      Columns = <
        item
          Caption = 'Timestamp'
          Width = 150
        end
        item
          Caption = #1051#1086#1082#1072#1083#1100#1085#1086#1077' '#1074#1088#1077#1084#1103
          Tag = 1
          Width = 150
        end
        item
          Caption = #1054#1090#1085#1086#1089#1080#1090#1077#1083#1100#1085#1086
          Tag = 2
        end>
      ReadOnly = True
      RowSelect = True
      TabOrder = 1
      ViewStyle = vsReport
      OnClick = lvParsedClick
      OnResize = lvParsedResize
      OnSelectItem = lvParsedSelectItem
    end
    object mEpoch: TSynEdit
      Left = 2
      Top = 17
      Width = 473
      Height = 131
      Cursor = crDefault
      Align = alClient
      ParentFont = True
      PopupMenu = PopupMenu
      TabOrder = 0
      OnKeyDown = mEpochKeyDown
      OnMouseDown = mEpochMouseDown
      UseCodeFolding = False
      Gutter.Font.Charset = DEFAULT_CHARSET
      Gutter.Font.Color = clWindowText
      Gutter.Font.Height = -11
      Gutter.Font.Name = 'Consolas'
      Gutter.Font.Style = []
      Gutter.Font.Quality = fqClearTypeNatural
      Gutter.ShowLineNumbers = True
      Gutter.Bands = <
        item
          Kind = gbkMarks
          Width = 13
        end
        item
          Kind = gbkLineNumbers
        end
        item
          Kind = gbkFold
        end
        item
          Kind = gbkTrackChanges
        end
        item
          Kind = gbkMargin
          Width = 3
        end>
      HideSelection = True
      ScrollOptions = [eoDisableScrollArrows, eoHideShowScrollbars, eoScrollPastEol, eoShowScrollHint]
      ScrollbarAnnotations = <
        item
          AnnType = sbaCarets
          AnnPos = sbpFullWidth
          FullRow = False
        end
        item
          AnnType = sbaBookmark
          AnnPos = sbpLeft
          FullRow = True
        end
        item
          AnnType = sbaTrackChanges
          AnnPos = sbpRight
          FullRow = True
        end>
      OnChange = mEpochChange
      OnPaintTransient = mEpochPaintTransient
      RemovedKeystrokes = <
        item
          Command = ecSetMarker0
          ShortCut = 24624
        end
        item
          Command = ecSetMarker1
          ShortCut = 24625
        end
        item
          Command = ecSetMarker2
          ShortCut = 24626
        end
        item
          Command = ecSetMarker3
          ShortCut = 24627
        end
        item
          Command = ecSetMarker4
          ShortCut = 24628
        end
        item
          Command = ecSetMarker5
          ShortCut = 24629
        end
        item
          Command = ecSetMarker6
          ShortCut = 24630
        end
        item
          Command = ecSetMarker7
          ShortCut = 24631
        end
        item
          Command = ecSetMarker8
          ShortCut = 24632
        end
        item
          Command = ecSetMarker9
          ShortCut = 24633
        end>
      AddedKeystrokes = <
        item
          Command = ecSetMarker0
          ShortCut = 32816
        end
        item
          Command = ecSetMarker1
          ShortCut = 32817
        end
        item
          Command = ecSetMarker2
          ShortCut = 32818
        end
        item
          Command = ecSetMarker3
          ShortCut = 32819
        end
        item
          Command = ecSetMarker4
          ShortCut = 32820
        end
        item
          Command = ecSetMarker5
          ShortCut = 32821
        end
        item
          Command = ecSetMarker6
          ShortCut = 32822
        end
        item
          Command = ecSetMarker7
          ShortCut = 32823
        end
        item
          Command = ecSetMarker8
          ShortCut = 32824
        end
        item
          Command = ecSetMarker9
          ShortCut = 32825
        end>
    end
  end
  object pBottom: TPanel
    Left = 0
    Top = 284
    Width = 477
    Height = 154
    Align = alBottom
    BevelOuter = bvNone
    TabOrder = 1
    object gbDetectedDateTime: TGroupBox
      Left = 0
      Top = 0
      Width = 477
      Height = 154
      Align = alClient
      TabOrder = 0
      object lbISO: TLabel
        Left = 174
        Top = 128
        Width = 18
        Height = 15
        Caption = 'ISO'
      end
      object lbDetectedFormat: TLabel
        Left = 8
        Top = 11
        Width = 382
        Height = 15
        Alignment = taCenter
        AutoSize = False
        Caption = #1060#1086#1088#1084#1072#1090': ...'
        Font.Charset = DEFAULT_CHARSET
        Font.Color = clWindowText
        Font.Height = -12
        Font.Name = 'Segoe UI'
        Font.Style = [fsBold]
        ParentFont = False
      end
      object lbLocal: TLabel
        Left = 174
        Top = 99
        Width = 60
        Height = 15
        Caption = #1051#1086#1082#1072#1083#1100#1085#1086#1077
      end
      object lbRelative: TLabel
        Left = 8
        Top = 70
        Width = 150
        Height = 49
        Alignment = taCenter
        AutoSize = False
        Caption = 'lbRelative'
        Layout = tlCenter
        WordWrap = True
      end
      object lbUTC: TLabel
        Left = 174
        Top = 70
        Width = 22
        Height = 15
        Caption = 'UTC'
      end
      object lbSourceTime: TLabel
        Left = 174
        Top = 41
        Width = 53
        Height = 15
        Caption = #1048#1089#1093#1086#1076#1085#1086#1077
      end
      object bCopyISO: TButton
        Left = 396
        Top = 125
        Width = 23
        Height = 23
        Caption = #55357#56516
        CommandLinkHint = #55357#56516
        TabOrder = 9
        OnClick = CopyToClipboardClick
      end
      object bCopyUTC: TButton
        Left = 396
        Top = 67
        Width = 23
        Height = 23
        Caption = #55357#56516
        TabOrder = 5
        OnClick = CopyToClipboardClick
      end
      object bNow: TButton
        Left = 8
        Top = 125
        Width = 150
        Height = 23
        Caption = #1057#1077#1081#1095#1072#1089
        TabOrder = 10
        OnClick = bNowClick
      end
      object ebISO: TEdit
        Left = 269
        Top = 125
        Width = 121
        Height = 23
        ReadOnly = True
        TabOrder = 8
      end
      object ebLocal: TEdit
        Left = 269
        Top = 96
        Width = 121
        Height = 23
        ReadOnly = True
        TabOrder = 6
      end
      object ebUTC: TEdit
        Left = 269
        Top = 67
        Width = 121
        Height = 23
        ReadOnly = True
        TabOrder = 4
      end
      object ebSourceTime: TEdit
        Left = 269
        Top = 38
        Width = 121
        Height = 23
        ReadOnly = True
        TabOrder = 2
      end
      object dtpDate: TDateTimePicker
        Left = 8
        Top = 38
        Width = 81
        Height = 23
        Date = 46230.000000000000000000
        Time = 0.440494085647515000
        TabOrder = 0
        OnClick = dtpChange
      end
      object dtpTime: TDateTimePicker
        Left = 95
        Top = 38
        Width = 63
        Height = 23
        Date = 46230.000000000000000000
        Time = 0.440602685186604500
        Kind = dtkTime
        TabOrder = 1
        OnClick = dtpChange
      end
      object bCopySource: TButton
        Left = 396
        Top = 38
        Width = 23
        Height = 23
        Caption = #55357#56516
        TabOrder = 3
        OnClick = CopyToClipboardClick
      end
      object bCopyLocal: TButton
        Left = 396
        Top = 96
        Width = 23
        Height = 23
        Caption = #55357#56516
        TabOrder = 7
        OnClick = CopyToClipboardClick
      end
    end
  end
  object tmrLiveUpdate: TTimer
    Enabled = False
    OnTimer = tmrLiveUpdateTimer
    Left = 328
    Top = 48
  end
  object PopupMenu: TPopupMenu
    Left = 328
    Top = 112
    object nCut: TMenuItem
      Caption = #1042#1099#1088#1077#1079#1072#1090#1100
      OnClick = nCutClick
    end
    object nCopy: TMenuItem
      Caption = #1050#1086#1087#1080#1088#1086#1074#1072#1090#1100
      OnClick = nCopyClick
    end
    object nPaste: TMenuItem
      Caption = #1042#1089#1090#1072#1074#1080#1090#1100
      OnClick = nPasteClick
    end
    object N4: TMenuItem
      Caption = '-'
    end
    object nSelectAll: TMenuItem
      Caption = #1042#1099#1076#1077#1083#1080#1090#1100' '#1074#1089#1105
      OnClick = nSelectAllClick
    end
    object N1: TMenuItem
      Caption = '-'
    end
    object nToggleBookmark: TMenuItem
      Caption = #1057#1086#1079#1076#1072#1090#1100' '#1079#1072#1082#1083#1072#1076#1082#1091
      ShortCut = 16450
      OnClick = nToggleBookmarkClick
    end
    object nBookmarks: TMenuItem
      Caption = #1055#1077#1088#1077#1081#1090#1080' '#1082' '#1079#1072#1082#1083#1072#1076#1082#1077
    end
  end
end
