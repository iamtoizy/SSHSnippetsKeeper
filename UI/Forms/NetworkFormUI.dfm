object NetworkForm: TNetworkForm
  Left = 0
  Top = 0
  BorderStyle = bsDialog
  Caption = 'IP/CIDR '#1050#1072#1083#1100#1082#1091#1083#1103#1090#1086#1088
  ClientHeight = 336
  ClientWidth = 480
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  Position = poScreenCenter
  OnClose = FormClose
  OnCreate = FormCreate
  TextHeight = 15
  object gbTop: TGroupBox
    Left = 0
    Top = 0
    Width = 480
    Height = 57
    Align = alTop
    Caption = #1042#1074#1086#1076' '#1076#1072#1085#1085#1099#1093
    TabOrder = 0
    ExplicitWidth = 486
    object seMask: TSpinEdit
      Left = 405
      Top = 27
      Width = 68
      Height = 24
      MaxLength = 2
      MaxValue = 32
      MinValue = 0
      TabOrder = 1
      Value = 25
      OnChange = seMaskChange
    end
    object cbIPInput: TComboBox
      Left = 3
      Top = 27
      Width = 396
      Height = 23
      TabOrder = 0
      OnChange = cbIPInputChange
      OnKeyPress = cbIPInputKeyPress
    end
  end
  object pcMain: TPageControl
    Left = 0
    Top = 57
    Width = 480
    Height = 260
    ActivePage = tsVLSM
    Align = alClient
    TabOrder = 1
    OnChange = pcMainChange
    ExplicitWidth = 527
    ExplicitHeight = 283
    object tsInfo: TTabSheet
      Caption = #1048#1085#1092#1086#1088#1084#1072#1094#1080#1103
      object bCopyAll: TButton
        Left = 239
        Top = 199
        Width = 230
        Height = 25
        Caption = #55357#56516' '#1050#1086#1087#1080#1088#1086#1074#1072#1090#1100' '#1074#1089#1105
        TabOrder = 0
        OnClick = bCopyAllClick
      end
      object bCopyBinaryView: TButton
        Tag = 7
        Left = 446
        Top = 168
        Width = 23
        Height = 23
        Caption = #55357#56516
        TabOrder = 1
        OnClick = bCopyNetworkAddressClick
      end
      object bCopyBroadcastAddress: TButton
        Tag = 2
        Left = 210
        Top = 120
        Width = 23
        Height = 23
        Caption = #55357#56516
        TabOrder = 2
        OnClick = bCopyNetworkAddressClick
      end
      object bCopyHostRange: TButton
        Tag = 1
        Left = 210
        Top = 72
        Width = 23
        Height = 23
        Caption = #55357#56516
        TabOrder = 3
        OnClick = bCopyNetworkAddressClick
      end
      object bCopyNetmask: TButton
        Tag = 4
        Left = 446
        Top = 24
        Width = 23
        Height = 23
        Caption = #55357#56516
        TabOrder = 4
        OnClick = bCopyNetworkAddressClick
      end
      object bCopyNetworkAddress: TButton
        Left = 210
        Top = 24
        Width = 23
        Height = 23
        Caption = #55357#56516
        TabOrder = 5
        OnClick = bCopyNetworkAddressClick
      end
      object bCopyNetworkType: TButton
        Tag = 6
        Left = 446
        Top = 120
        Width = 23
        Height = 23
        Caption = #55357#56516
        TabOrder = 6
        OnClick = bCopyNetworkAddressClick
      end
      object bCopyTotalhosts: TButton
        Tag = 3
        Left = 210
        Top = 168
        Width = 23
        Height = 23
        Caption = #55357#56516
        TabOrder = 7
        OnClick = bCopyNetworkAddressClick
      end
      object bCopyWildcardMask: TButton
        Tag = 5
        Left = 446
        Top = 72
        Width = 23
        Height = 23
        Caption = #55357#56516
        TabOrder = 8
        OnClick = bCopyNetworkAddressClick
      end
      object ledBinaryView: TLabeledEdit
        Tag = 7
        Left = 239
        Top = 168
        Width = 201
        Height = 23
        EditLabel.Width = 60
        EditLabel.Height = 15
        EditLabel.Caption = 'Binary view'
        TabOrder = 9
        Text = ''
      end
      object ledBroadcastAddress: TLabeledEdit
        Tag = 2
        Left = 3
        Top = 120
        Width = 201
        Height = 23
        EditLabel.Width = 95
        EditLabel.Height = 15
        EditLabel.Caption = 'Broadcast address'
        TabOrder = 10
        Text = ''
      end
      object ledHostRange: TLabeledEdit
        Tag = 1
        Left = 3
        Top = 72
        Width = 201
        Height = 23
        EditLabel.Width = 58
        EditLabel.Height = 15
        EditLabel.Caption = 'Host range'
        TabOrder = 11
        Text = ''
      end
      object ledNetmask: TLabeledEdit
        Tag = 4
        Left = 239
        Top = 24
        Width = 201
        Height = 23
        EditLabel.Width = 47
        EditLabel.Height = 15
        EditLabel.Caption = 'Netmask'
        TabOrder = 12
        Text = ''
      end
      object ledNetworkAddress: TLabeledEdit
        Left = 3
        Top = 24
        Width = 201
        Height = 23
        EditLabel.Width = 88
        EditLabel.Height = 15
        EditLabel.Caption = 'Network address'
        TabOrder = 13
        Text = ''
      end
      object ledNetworkType: TLabeledEdit
        Tag = 6
        Left = 239
        Top = 120
        Width = 201
        Height = 23
        EditLabel.Width = 71
        EditLabel.Height = 15
        EditLabel.Caption = 'Network type'
        TabOrder = 14
        Text = ''
      end
      object ledUsableHosts: TLabeledEdit
        Tag = 3
        Left = 3
        Top = 168
        Width = 201
        Height = 23
        EditLabel.Width = 57
        EditLabel.Height = 15
        EditLabel.Caption = 'Total hosts'
        TabOrder = 15
        Text = ''
      end
      object ledWildcardMask: TLabeledEdit
        Tag = 5
        Left = 239
        Top = 72
        Width = 201
        Height = 23
        EditLabel.Width = 78
        EditLabel.Height = 15
        EditLabel.Caption = 'Wildcard mask'
        TabOrder = 16
        Text = ''
      end
    end
    object tsVLSM: TTabSheet
      Caption = #1056#1072#1079#1073#1080#1077#1085#1080#1077' (VLSM)'
      ImageIndex = 1
      object pnlVLSMTop: TPanel
        Left = 0
        Top = 0
        Width = 472
        Height = 30
        Align = alTop
        BevelOuter = bvNone
        TabOrder = 0
        ExplicitWidth = 519
        object lbVLSMMask: TLabel
          Left = 16
          Top = 5
          Width = 73
          Height = 15
          Caption = #1053#1086#1074#1072#1103' '#1084#1072#1089#1082#1072':'
        end
        object lbVLSMHostCount: TLabel
          Left = 192
          Top = 5
          Width = 98
          Height = 15
          Caption = 'lbVLSMHostCount'
        end
        object seVLSM: TSpinEdit
          Left = 102
          Top = 2
          Width = 75
          Height = 24
          MaxLength = 2
          MaxValue = 0
          MinValue = 32
          TabOrder = 0
          Value = 0
          OnChange = seVLSMChange
        end
        object bCopyVLSM: TButton
          Left = 352
          Top = 1
          Width = 117
          Height = 25
          Caption = #1050#1086#1087#1080#1088#1086#1074#1072#1090#1100
          TabOrder = 1
          OnClick = bCopyVLSMClick
        end
      end
      object lvVLSM: TListView
        Left = 0
        Top = 30
        Width = 472
        Height = 200
        Align = alClient
        Columns = <
          item
            Caption = '#'
          end
          item
            Caption = #1055#1086#1076#1089#1077#1090#1100
            Tag = 1
          end
          item
            Caption = #1044#1080#1072#1087#1072#1079#1086#1085' '#1093#1086#1089#1090#1086#1074
            Tag = 2
          end
          item
            Caption = 'Broadcast'
            MaxWidth = 3
          end>
        MultiSelect = True
        ReadOnly = True
        RowSelect = True
        TabOrder = 1
        ViewStyle = vsReport
        OnKeyDown = lvVLSMKeyDown
        OnResize = lvVLSMResize
      end
    end
  end
  object sbBottom: TStatusBar
    Left = 0
    Top = 317
    Width = 480
    Height = 19
    Panels = <>
    SimplePanel = True
    ExplicitLeft = 208
    ExplicitTop = 24
    ExplicitWidth = 0
  end
  object tmrEraseStatusBar: TTimer
    Enabled = False
    Interval = 3000
    OnTimer = tmrEraseStatusBarTimer
    Left = 272
    Top = 16
  end
end
