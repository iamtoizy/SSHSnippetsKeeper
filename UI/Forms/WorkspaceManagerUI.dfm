object WorkspaceManagerForm: TWorkspaceManagerForm
  Left = 0
  Top = 0
  Caption = #1059#1087#1088#1072#1074#1083#1077#1085#1080#1077' '#1087#1088#1086#1089#1090#1088#1072#1085#1089#1090#1074#1072#1084#1080
  ClientHeight = 400
  ClientWidth = 347
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  FormStyle = fsStayOnTop
  Menu = MainMenu
  Position = poScreenCenter
  OnCreate = FormCreate
  OnResize = FormResize
  OnShow = FormShow
  TextHeight = 15
  object lvWorkspaces: TListView
    Left = 0
    Top = 0
    Width = 347
    Height = 368
    Align = alClient
    Columns = <
      item
        Caption = #1048#1084#1103' '#1087#1088#1086#1089#1090#1088#1072#1085#1089#1090#1074#1072
        Width = 200
      end>
    RowSelect = True
    TabOrder = 0
    ViewStyle = vsReport
    OnDblClick = lvWorkspacesDblClick
    OnEdited = lvWorkspacesEdited
    OnResize = lvWorkspacesResize
  end
  object pBottom: TPanel
    Left = 0
    Top = 368
    Width = 347
    Height = 32
    Align = alBottom
    BevelOuter = bvNone
    TabOrder = 1
    DesignSize = (
      347
      32)
    object bOK: TButton
      Left = 184
      Top = 6
      Width = 75
      Height = 25
      Anchors = [akTop, akRight]
      Caption = 'OK'
      TabOrder = 0
      OnClick = bOKClick
    end
    object bCancel: TButton
      Left = 265
      Top = 6
      Width = 75
      Height = 25
      Anchors = [akTop, akRight]
      Caption = #1054#1090#1084#1077#1085#1072
      TabOrder = 1
      OnClick = bCancelClick
    end
  end
  object MainMenu: TMainMenu
    Left = 168
    Top = 208
    object N1: TMenuItem
      Caption = #1055#1088#1086#1089#1090#1088#1072#1085#1089#1090#1074#1072
      object nAdd: TMenuItem
        Caption = #1044#1086#1073#1072#1074#1080#1090#1100
        ShortCut = 16449
        OnClick = nAddClick
      end
      object nDelete: TMenuItem
        Caption = #1059#1076#1072#1083#1080#1090#1100
        ShortCut = 16452
        OnClick = nDeleteClick
      end
      object nRename: TMenuItem
        Caption = #1048#1079#1084#1077#1085#1080#1090#1100
        ShortCut = 16453
        OnClick = nRenameClick
      end
    end
  end
end
