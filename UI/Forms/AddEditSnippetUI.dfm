object AddEditSnippet: TAddEditSnippet
  Left = 0
  Top = 0
  Caption = #1044#1086#1073#1072#1074#1080#1090#1100'/'#1080#1079#1084#1077#1085#1080#1090#1100' '#1089#1085#1080#1087#1087#1077#1090
  ClientHeight = 498
  ClientWidth = 730
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  FormStyle = fsStayOnTop
  Menu = MainMenu
  Position = poScreenCenter
  OnClose = FormClose
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  OnShow = FormShow
  TextHeight = 15
  object pLeft: TPanel
    Left = 0
    Top = 0
    Width = 201
    Height = 447
    Align = alLeft
    BevelOuter = bvNone
    TabOrder = 0
    object lbCaption: TLabel
      Left = 0
      Top = 0
      Width = 78
      Height = 15
      Caption = #1048#1084#1103' '#1089#1085#1080#1087#1087#1077#1090#1072
    end
    object lbTag: TLabel
      Left = 0
      Top = 46
      Width = 87
      Height = 15
      Caption = #1044#1086#1089#1090#1091#1087#1085#1099#1077' '#1090#1077#1075#1080
    end
    object Label1: TLabel
      Left = 0
      Top = 219
      Width = 79
      Height = 15
      Caption = #1058#1077#1075#1080' '#1089#1085#1080#1087#1087#1077#1090#1072
    end
    object ebTitle: TEdit
      Left = 0
      Top = 18
      Width = 193
      Height = 23
      DoubleBuffered = True
      ParentDoubleBuffered = False
      TabOrder = 0
    end
    object lvSelectedTags: TListView
      Left = 0
      Top = 236
      Width = 193
      Height = 158
      Columns = <>
      HideSelection = False
      MultiSelect = True
      ReadOnly = True
      RowSelect = True
      SortType = stText
      TabOrder = 1
      ViewStyle = vsList
      OnDblClick = lvAllTagsDblClick
      OnDragDrop = lvAllTagsDragDrop
      OnDragOver = lvAllTagsDragOver
      OnMouseDown = lvAllTagsMouseDown
    end
    object lvAllTags: TListView
      Left = 0
      Top = 64
      Width = 195
      Height = 145
      Columns = <>
      HideSelection = False
      MultiSelect = True
      ReadOnly = True
      RowSelect = True
      SortType = stText
      TabOrder = 2
      ViewStyle = vsList
      OnDblClick = lvAllTagsDblClick
      OnDragDrop = lvAllTagsDragDrop
      OnDragOver = lvAllTagsDragOver
      OnMouseDown = lvAllTagsMouseDown
    end
    object cbIgnoreSecurityChecks: TCheckBox
      Left = 0
      Top = 400
      Width = 193
      Height = 41
      Caption = #1044#1086#1074#1077#1088#1103#1090#1100' '#1101#1090#1086#1084#1091' '#1089#1085#1080#1087#1087#1077#1090#1091' ('#1086#1090#1082#1083#1102#1095#1080#1090#1100' '#1087#1088#1086#1074#1077#1088#1082#1091' '#1073#1077#1079#1086#1087#1072#1089#1085#1086#1089#1090#1080')'
      TabOrder = 3
      WordWrap = True
      OnClick = cbIgnoreSecurityChecksClick
    end
  end
  object pBottom: TPanel
    Left = 0
    Top = 447
    Width = 730
    Height = 32
    Align = alBottom
    BevelOuter = bvNone
    TabOrder = 1
    DesignSize = (
      730
      32)
    object bOK: TButton
      Left = 545
      Top = 3
      Width = 90
      Height = 25
      Anchors = [akTop, akRight]
      Caption = 'OK'
      TabOrder = 0
      OnClick = bOKClick
    end
    object bCancel: TButton
      Left = 641
      Top = 3
      Width = 89
      Height = 25
      Anchors = [akTop, akRight]
      Caption = #1054#1090#1084#1077#1085#1072
      TabOrder = 1
      OnClick = bCancelClick
    end
  end
  object sbBottom: TStatusBar
    Left = 0
    Top = 479
    Width = 730
    Height = 19
    Panels = <>
    SimplePanel = True
  end
  object pnlClient: TPanel
    Left = 201
    Top = 0
    Width = 529
    Height = 447
    Align = alClient
    BevelOuter = bvNone
    TabOrder = 3
    object pTop: TPanel
      Left = 0
      Top = 0
      Width = 529
      Height = 23
      Align = alTop
      BevelOuter = bvNone
      TabOrder = 0
      object spTopLeft: TSplitter
        Left = 240
        Top = 0
        Height = 23
        ExplicitLeft = 312
        ExplicitTop = 16
        ExplicitHeight = 100
      end
      object bAISettings: TButton
        Left = 506
        Top = 0
        Width = 23
        Height = 23
        Align = alRight
        Caption = #9881
        TabOrder = 0
        OnClick = bAISettingsClick
      end
      object cbAIModel: TComboBox
        Left = 243
        Top = 0
        Width = 263
        Height = 23
        Align = alClient
        Style = csDropDownList
        TabOrder = 1
        OnChange = cbAIModelChange
      end
      object cbAIHub: TComboBox
        Left = 0
        Top = 0
        Width = 240
        Height = 23
        Align = alLeft
        Style = csDropDownList
        TabOrder = 2
        OnChange = cbAIHubChange
      end
    end
    object pcSnippet: TPageControl
      Left = 0
      Top = 23
      Width = 529
      Height = 424
      ActivePage = tsSnippet
      Align = alClient
      TabOrder = 1
      object tsSnippet: TTabSheet
        Caption = #1057#1086#1076#1077#1088#1078#1080#1084#1086#1077' '#1089#1085#1080#1087#1087#1077#1090#1072
        object sMiddle: TSplitter
          Left = 0
          Top = 169
          Width = 521
          Height = 3
          Cursor = crVSplit
          Align = alBottom
          ExplicitLeft = 3
          ExplicitTop = 280
        end
        object pAIOverlay: TPanel
          Left = 0
          Top = 0
          Width = 521
          Height = 169
          Align = alClient
          BevelOuter = bvNone
          TabOrder = 1
          Visible = False
          object pbLoading: TProgressBar
            Left = 0
            Top = 152
            Width = 521
            Height = 17
            Align = alBottom
            Style = pbstMarquee
            TabOrder = 1
          end
          object mAIPrompt: TSynEdit
            Left = 0
            Top = 0
            Width = 521
            Height = 152
            Cursor = crDefault
            Align = alClient
            CaseSensitive = True
            ParentFont = True
            ParentShowHint = False
            ShowHint = False
            TabOrder = 0
            TextHint = #1042#1074#1077#1076#1080' '#1079#1072#1087#1088#1086#1089' '#1082' '#1048#1048
            OnKeyDown = mAIPromptKeyDown
            UseCodeFolding = False
            Gutter.Font.Charset = DEFAULT_CHARSET
            Gutter.Font.Color = clWindowText
            Gutter.Font.Height = -11
            Gutter.Font.Name = 'Consolas'
            Gutter.Font.Style = []
            Gutter.Font.Quality = fqClearTypeNatural
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
            Highlighter = SynMarkdownSyn
            ScrollBars = ssVertical
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
            WordWrap = True
          end
        end
        object mComment: TSynEdit
          Left = 0
          Top = 172
          Width = 521
          Height = 222
          Cursor = crDefault
          Align = alBottom
          DoubleBuffered = True
          Font.Charset = DEFAULT_CHARSET
          Font.Color = clWindowText
          Font.Height = -12
          Font.Name = 'Consolas'
          Font.Style = []
          Font.Quality = fqClearTypeNatural
          ParentDoubleBuffered = False
          TabOrder = 0
          TextHint = #1050#1086#1084#1084#1077#1085#1090#1072#1088#1080#1081' '#1082' '#1089#1085#1080#1087#1087#1077#1090#1091' '#1074#1074#1086#1076#1080' '#1089#1102#1076#1072'...'
          UseCodeFolding = False
          Gutter.Font.Charset = DEFAULT_CHARSET
          Gutter.Font.Color = clWindowText
          Gutter.Font.Height = -11
          Gutter.Font.Name = 'Consolas'
          Gutter.Font.Style = []
          Gutter.Font.Quality = fqClearTypeNatural
          Gutter.Visible = False
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
          WordWrap = True
        end
        object mContent: TSynEdit
          Left = 0
          Top = 0
          Width = 521
          Height = 169
          Align = alClient
          DoubleBuffered = True
          Font.Charset = DEFAULT_CHARSET
          Font.Color = clWindowText
          Font.Height = -13
          Font.Name = 'Consolas'
          Font.Style = []
          Font.Quality = fqClearTypeNatural
          ParentDoubleBuffered = False
          TabOrder = 2
          TextHint = #1050#1086#1076' '#1089#1085#1080#1087#1087#1077#1090#1072' '#1074#1074#1086#1076#1080' '#1079#1076#1077#1089#1100'...'
          OnKeyDown = mContentKeyDown
          UseCodeFolding = False
          Gutter.DigitCount = 2
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
          Highlighter = SynUNIXShellScriptSyn
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
          SearchEngine = SynEditRegexSearch
          TabWidth = 4
          WantTabs = True
          OnChange = mContentChange
          OnProcessCommand = mContentProcessCommand
          ExplicitHeight = 152
        end
      end
      object tsHelp: TTabSheet
        Caption = #1052#1072#1082#1088#1086#1089#1099
        ImageIndex = 1
        object mInfo: TMemo
          Left = 0
          Top = 0
          Width = 521
          Height = 394
          Align = alClient
          Font.Charset = DEFAULT_CHARSET
          Font.Color = clWindowText
          Font.Height = -12
          Font.Name = 'Consolas'
          Font.Style = []
          Lines.Strings = (
            #1058#1077#1089#1090#1086#1074#1099#1077' '#1084#1072#1082#1088#1086#1089#1099' '#1085#1072' '#1090#1077#1082#1091#1097#1080#1081' '#1084#1086#1084#1077#1085#1090':'
            ''
            '{SLEEP N} - '#1047#1072#1076#1077#1088#1078#1082#1072' '#1074#1099#1087#1086#1083#1085#1077#1085#1080#1103' '#1085#1072' N '#1084#1080#1083#1083#1080#1089#1077#1082#1091#1085#1076'.'
            '{ENTER} - '#1054#1090#1087#1088#1072#1074#1082#1072' '#1085#1072#1078#1072#1090#1080#1103' '#1082#1083#1072#1074#1080#1096#1080' ENTER.'
            '{SENDKEY X} - '#1054#1090#1087#1088#1072#1074#1082#1072' '#1089#1080#1084#1074#1086#1083#1072' X '#1074' '#1094#1077#1083#1077#1074#1086#1077' '#1086#1082#1085#1086'.'
            
              '{INPUT['#1058#1048#1055':'#1047#1053#1040#1063#1045#1053#1048#1045'-'#1055#1054'-'#1059#1052#1054#1051#1063#1040#1053#1048#1070'] '#1048#1052#1071'} - '#1054#1090#1086#1073#1088#1072#1079#1080#1090#1100' '#1086#1082#1085#1086' '#1074#1074#1086#1076#1072' '#1090 +
              #1077#1082#1089#1090#1072' '
            #1089' '
            #1087#1086#1076#1089#1090#1072#1085#1086#1074#1082#1086#1081' '#1074' '#1084#1077#1089#1090#1086' '#1088#1072#1089#1087#1086#1083#1086#1078#1077#1085#1080#1103' '#1084#1072#1082#1088#1086#1089#1072'. '#1055#1088#1080#1084#1077#1088#1099':'
            #9'{INPUT '#1048#1084#1103'}'
            #9'{INPUT[STRING:test string] '#1048#1084#1103'}'
            #9'{INPUT[NUMBER:100] '#1056#1072#1079#1084#1077#1088'}'
            #9'{INPUT[FLOAT:3.14] '#1056#1072#1079#1084#1077#1088'}'
            #9'{INPUT[Hex:FF] '#1062#1074#1077#1090'}'
            #9'{INPUT[Password] '#1055#1072#1088#1086#1083#1100'}'
            #9'{INPUT[DATE:2026-01-31] '#1044#1072#1090#1072'}'
            
              '{INPUT[Confirm] '#1058#1077#1082#1089#1090' '#1076#1083#1103' '#1087#1086#1083#1100#1079#1086#1074#1072#1090#1077#1083#1103'} - '#1055#1088#1080#1086#1089#1090#1072#1085#1086#1074#1080#1090#1100' '#1074#1099#1087#1086#1083#1085#1077#1085 +
              #1080#1077' '#1080' '
            #1078#1076#1072#1090#1100' '
            #1087#1086#1076#1090#1074#1077#1088#1078#1076#1077#1085#1080#1103' '#1086#1090' '#1087#1086#1083#1100#1079#1086#1074#1072#1090#1077#1083#1103'.'
            #9
            '...')
          ParentFont = False
          ScrollBars = ssVertical
          TabOrder = 0
        end
      end
    end
  end
  object SynUNIXShellScriptSyn: TSynUNIXShellScriptSyn
    Left = 589
    Top = 106
  end
  object SynEditRegexSearch: TSynEditRegexSearch
    Left = 589
    Top = 178
  end
  object SynCompletionProposal: TSynCompletionProposal
    Options = [scoLimitToMatchedText, scoUseInsertList, scoUseBuiltInTimer, scoEndCharCompletion, scoCompleteWithTab, scoCompleteWithEnter]
    Width = 450
    EndOfTokenChr = '()[]. '
    TriggerChars = '.'
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clWindowText
    Font.Height = -12
    Font.Name = 'Consolas'
    Font.Style = []
    TitleFont.Charset = DEFAULT_CHARSET
    TitleFont.Color = clBtnText
    TitleFont.Height = -12
    TitleFont.Name = 'Segoe UI'
    TitleFont.Style = [fsBold]
    GripperFont.Charset = DEFAULT_CHARSET
    GripperFont.Color = clBtnText
    GripperFont.Height = -12
    GripperFont.Name = 'Segoe UI'
    GripperFont.Style = []
    Columns = <>
    Resizeable = True
    ShowGripper = True
    OnExecute = SynCompletionProposalExecute
    ShortCut = 16416
    Left = 589
    Top = 250
  end
  object tmrReloadCommands: TTimer
    Enabled = False
    Interval = 2000
    OnTimer = tmrReloadCommandsTimer
    Left = 589
    Top = 50
  end
  object SynMarkdownSyn: TSynMarkdownSyn
    Brackets = '<>()[]{}'
    BlockQuoteAttri.Background = clNone
    BlockQuoteAttri.Foreground = clDimgray
    CodeAttri.Background = clNone
    CodeAttri.Foreground = clFirebrick
    DeleteAttri.Background = clNone
    DeleteAttri.Foreground = clDimgray
    EmphasisAttri.Background = clNone
    EmphasisAttri.Foreground = clDeeppink
    EntityReferenceAttri.Background = clNone
    EntityReferenceAttri.Foreground = clGreen
    HeadingAttri.Background = clNone
    HeadingAttri.Foreground = clMediumblue
    HtmlAttrNametAttri.Background = clNone
    HtmlAttrNametAttri.Foreground = clMediumblue
    HtmlAttrValueAttri.Background = clNone
    HtmlAttrValueAttri.Foreground = clCrimson
    HtmlCommentAttri.Background = clNone
    HtmlCommentAttri.Foreground = clDimgray
    HtmlTagAttri.Background = clNone
    HtmlTagAttri.Foreground = clDarkviolet
    LinkAttri.Background = clNone
    LinkAttri.Foreground = clBlue
    ListAttri.Background = clNone
    ListAttri.Foreground = clDeeppink
    SpaceAttri.Background = clNone
    SpaceAttri.Foreground = clCornflowerblue
    TextAttri.Background = clNone
    TextAttri.Foreground = clNone
    Left = 589
    Top = 314
  end
  object MainMenu: TMainMenu
    Left = 592
    Top = 376
    object AI1: TMenuItem
      Caption = #1048#1048' '#1087#1086#1084#1086#1097#1085#1080#1082
      object nShowAIPrompt: TMenuItem
        Caption = #1042#1099#1079#1074#1072#1090#1100' '#1048#1048
        ShortCut = 16457
        OnClick = nShowAIPromptClick
      end
      object nAISettings: TMenuItem
        Caption = #1050#1086#1085#1092#1080#1075#1091#1088#1072#1094#1080#1103' '#1048#1048
        ShortCut = 49225
        OnClick = nAISettingsClick
      end
    end
  end
  object tmrSecurityScan: TTimer
    Interval = 400
    OnTimer = tmrSecurityScanTimer
    Left = 485
    Top = 49
  end
end
