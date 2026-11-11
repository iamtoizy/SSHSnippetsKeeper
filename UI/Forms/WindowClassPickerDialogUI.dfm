object WindowClassPickerDialog: TWindowClassPickerDialog
  Left = 0
  Top = 0
  BorderStyle = bsDialog
  Caption = ''
  ClientHeight = 440
  ClientWidth = 570
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  Position = poScreenCenter
  OnShow = FormShow
  TextHeight = 15
  object pTop: TPanel
    Left = 0
    Top = 0
    Width = 570
    Height = 33
    Align = alTop
    BevelOuter = bvNone
    TabOrder = 0
    object ebFilter: TEdit
      Left = 3
      Top = 5
      Width = 564
      Height = 23
      TabOrder = 0
      OnChange = ebFilterChange
    end
  end
  object pBottom: TPanel
    Left = 0
    Top = 399
    Width = 570
    Height = 41
    Align = alBottom
    BevelOuter = bvNone
    TabOrder = 1
    object bAdd: TButton
      Left = 3
      Top = 8
      Width = 150
      Height = 25
      Default = True
      ModalResult = 1
      TabOrder = 0
    end
    object bCancel: TButton
      Left = 159
      Top = 8
      Width = 100
      Height = 25
      Cancel = True
      ModalResult = 2
      TabOrder = 1
    end
    object lbStatus: TLabel
      Left = 272
      Top = 15
      Width = 295
      Height = 15
      AutoSize = False
      Caption = ''
    end
  end
  object lvClasses: TListView
    Left = 0
    Top = 33
    Width = 570
    Height = 366
    Align = alClient
    Checkboxes = True
    Columns = <
      item
        Caption = 'Process'
        Width = 160
      end
      item
        Caption = 'Class'
        Width = 180
      end
      item
        Caption = 'Title'
        Width = 220
      end>
    HideSelection = False
    ReadOnly = True
    RowSelect = True
    TabOrder = 2
    ViewStyle = vsReport
    OnDblClick = lvItemDblClick
  end
end
