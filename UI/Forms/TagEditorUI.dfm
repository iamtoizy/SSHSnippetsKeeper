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
    MultiSelect = True
    SortType = stText
    TabOrder = 1
    ViewStyle = vsSmallIcon
    OnEdited = lvTagsEdited
  end
  object MainMenu: TMainMenu
    Left = 232
    Top = 96
    object nActions: TMenuItem
      Caption = #1044#1077#1081#1089#1090#1074#1080#1103
      object nTagAdd: TMenuItem
        Action = actAddTag
      end
      object nTagDelete: TMenuItem
        Action = actDeleteTag
      end
      object nTagRename: TMenuItem
        Action = actEditTag
      end
    end
  end
  object ActionList: TActionList
    Left = 232
    Top = 32
    object actAddTag: TAction
      Caption = 'actAddTag'
      OnExecute = actAddTagExecute
    end
    object actDeleteTag: TAction
      Caption = 'actDeleteTag'
      OnExecute = actDeleteTagExecute
    end
    object actEditTag: TAction
      Caption = 'actEditTag'
      OnExecute = actEditTagExecute
    end
  end
end
