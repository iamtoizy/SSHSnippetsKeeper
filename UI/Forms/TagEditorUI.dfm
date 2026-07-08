object TagEditorForm: TTagEditorForm
  Left = 0
  Top = 0
  Caption = #1056#1077#1076#1072#1082#1090#1086#1088' '#1090#1077#1075#1086#1074
  ClientHeight = 385
  ClientWidth = 367
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
  OnDestroy = FormDestroy
  TextHeight = 15
  object pBottom: TPanel
    Left = 0
    Top = 352
    Width = 367
    Height = 33
    Align = alBottom
    BevelOuter = bvNone
    TabOrder = 0
    DesignSize = (
      367
      33)
    object bOK: TButton
      Left = 178
      Top = 6
      Width = 89
      Height = 25
      Anchors = [akTop, akRight]
      Caption = 'OK'
      TabOrder = 0
      OnClick = bOKClick
    end
    object bCancel: TButton
      Left = 273
      Top = 6
      Width = 89
      Height = 25
      Anchors = [akTop, akRight]
      Caption = #1054#1090#1084#1077#1085#1072
      TabOrder = 1
      OnClick = bCancelClick
    end
  end
  object lvTags: TListView
    Left = 0
    Top = 0
    Width = 367
    Height = 352
    Align = alClient
    Columns = <>
    Items.ItemData = {
      052D0100000900000000000000FFFFFFFFFFFFFFFF01000000FFFFFFFF000000
      00036400710077000020D97B2200000000FFFFFFFFFFFFFFFF00000000FFFFFF
      FF000000000666006400670064006600670000000000FFFFFFFFFFFFFFFF0000
      0000FFFFFFFF000000000371007700650000000000FFFFFFFFFFFFFFFF000000
      00FFFFFFFF000000000371007700650000000000FFFFFFFFFFFFFFFF00000000
      FFFFFFFF000000000371007700650000000000FFFFFFFFFFFFFFFF00000000FF
      FFFFFF000000000371007700650000000000FFFFFFFFFFFFFFFF00000000FFFF
      FFFF000000000371007700650000000000FFFFFFFFFFFFFFFF00000000FFFFFF
      FF000000000377007100650000000000FFFFFFFFFFFFFFFF00000000FFFFFFFF
      0000000003770071006500FFFF}
    MultiSelect = True
    SortType = stText
    StateImages = DataModuleCommon.ilTags
    TabOrder = 1
    ViewStyle = vsSmallIcon
    OnEdited = lvTagsEdited
    OnKeyDown = lvTagsKeyDown
  end
  object MainMenu: TMainMenu
    Left = 232
    Top = 96
    object nActions: TMenuItem
      Caption = #1044#1077#1081#1089#1090#1074#1080#1103
      object nAdd: TMenuItem
        Caption = #1044#1086#1073#1072#1074#1080#1090#1100' '#1090#1077#1075
        ShortCut = 16449
        OnClick = nAddClick
      end
      object nDelete: TMenuItem
        Caption = #1059#1076#1072#1083#1080#1090#1100' '#1090#1077#1075
        ShortCut = 16452
        OnClick = nDeleteClick
      end
      object nRename: TMenuItem
        Caption = #1055#1077#1088#1077#1080#1084#1077#1085#1086#1074#1072#1090#1100' '#1090#1077#1075
        ShortCut = 16466
        OnClick = nRenameClick
      end
    end
  end
end
