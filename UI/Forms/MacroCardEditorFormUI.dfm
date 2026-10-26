object MacroCardEditorForm: TMacroCardEditorForm
  Left = 0
  Top = 0
  BorderStyle = bsDialog
  Caption = 'MacroCardEditor'
  ClientHeight = 336
  ClientWidth = 440
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  FormStyle = fsStayOnTop
  Position = poScreenCenter
  OnCreate = FormCreate
  TextHeight = 13
  object lbTitle: TLabel
    AlignWithMargins = True
    Left = 13
    Top = 0
    Width = 427
    Height = 30
    Margins.Left = 13
    Margins.Top = 0
    Margins.Right = 0
    Margins.Bottom = 0
    Align = alTop
    AutoSize = False
    EllipsisPosition = epEndEllipsis
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clWindowText
    Font.Height = -12
    Font.Name = 'Tahoma'
    Font.Style = [fsBold]
    ParentFont = False
    ParentShowHint = False
    ShowAccelChar = False
    ShowHint = True
    Layout = tlCenter
    ExplicitLeft = 0
    ExplicitWidth = 440
  end
  object pnlProps: TPanel
    Left = 0
    Top = 32
    Width = 440
    Height = 266
    Align = alClient
    BevelOuter = bvNone
    TabOrder = 0
    object lbStepType: TLabel
      Left = 10
      Top = 10
      Width = 58
      Height = 13
      Caption = 'Macro type:'
    end
    object lbPropType: TLabel
      Left = 10
      Top = 57
      Width = 3
      Height = 13
      Visible = False
    end
    object lbProp1: TLabel
      Left = 10
      Top = 104
      Width = 3
      Height = 13
      Visible = False
    end
    object lbProp2: TLabel
      Left = 10
      Top = 151
      Width = 3
      Height = 13
      Visible = False
    end
    object lbProp3: TLabel
      Left = 10
      Top = 198
      Width = 3
      Height = 13
      Visible = False
    end
    object cbStepType: TComboBox
      Left = 10
      Top = 26
      Width = 420
      Height = 21
      Style = csDropDownList
      TabOrder = 0
      OnChange = cbStepTypeChange
    end
    object cbPropType: TComboBox
      Left = 10
      Top = 73
      Width = 420
      Height = 21
      Style = csDropDownList
      TabOrder = 1
      Visible = False
      OnChange = PropChanged
    end
    object cbProp1: TComboBox
      Left = 10
      Top = 120
      Width = 420
      Height = 21
      TabOrder = 2
      Visible = False
      OnChange = PropChanged
    end
    object cbProp2: TComboBox
      Left = 10
      Top = 167
      Width = 420
      Height = 21
      TabOrder = 3
      Visible = False
      OnChange = PropChanged
    end
    object cbProp3: TComboBox
      Left = 10
      Top = 214
      Width = 420
      Height = 21
      TabOrder = 4
      Visible = False
      OnChange = PropChanged
    end
  end
  object pnlButtons: TPanel
    Left = 0
    Top = 298
    Width = 440
    Height = 38
    Align = alBottom
    BevelOuter = bvNone
    TabOrder = 1
    DesignSize = (
      440
      38)
    object lbError: TLabel
      Left = 10
      Top = 6
      Width = 225
      Height = 26
      AutoSize = False
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clRed
      Font.Height = -11
      Font.Name = 'Tahoma'
      Font.Style = []
      ParentFont = False
      Layout = tlCenter
      Visible = False
      WordWrap = True
    end
    object bCancel: TButton
      Left = 342
      Top = 6
      Width = 88
      Height = 25
      Anchors = [akRight, akBottom]
      Cancel = True
      Caption = 'Cancel'
      ModalResult = 2
      TabOrder = 0
    end
    object bOK: TButton
      Left = 245
      Top = 6
      Width = 88
      Height = 25
      Anchors = [akRight, akBottom]
      Caption = 'OK'
      Default = True
      TabOrder = 1
      OnClick = bOKClick
    end
  end
  object pTop: TPanel
    Left = 0
    Top = 30
    Width = 440
    Height = 2
    Align = alTop
    BevelOuter = bvLowered
    TabOrder = 2
  end
end
