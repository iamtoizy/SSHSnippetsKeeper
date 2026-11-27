unit PunycodeFormUI;

interface

uses
    BaseFormUI,
    System.Classes,
    Vcl.Controls,
    Vcl.ExtCtrls,
    Vcl.StdCtrls;

type
    TPunycodeForm = class(TBaseForm)
        lblMode: TLabel;
        cbMode: TComboBox;
        lblInput: TLabel;
        mInput: TMemo;
        tmrConvert: TTimer;
        lblResult: TLabel;
        mResult: TMemo;
        bCopy: TButton;
        lblErrors: TLabel;
        mErrors: TMemo;
        procedure tmrConvertTimer(Sender: TObject);
        procedure FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
        procedure bCopyClick(Sender: TObject);
        procedure InputChanged(Sender: TObject);
    protected
        procedure DoInitialize; override;
    public
        procedure ApplyLanguage; override;
    end;

var
    PunycodeForm: TPunycodeForm;

implementation

uses
    Common.Helpers,
    Common.Localization,
    PunycodeService,
    System.SysUtils,
    Winapi.Windows;

{$R *.dfm}

const
    MessagePrefix = 'PunycodeForm.';

procedure TPunycodeForm.DoInitialize;
begin
    inherited;
    ApplyLanguage;
    ActiveControl := mInput;
end;

procedure TPunycodeForm.ApplyLanguage;
var
    Index: Integer;
begin
    inherited;
    Index := cbMode.ItemIndex;
    cbMode.Items.BeginUpdate;
    try
        cbMode.Items.Clear;
        cbMode.Items.Add(TUIStateLoader.GetMessage(MessagePrefix + 'Auto'));
        cbMode.Items.Add(TUIStateLoader.GetMessage(MessagePrefix + 'ToAscii'));
        cbMode.Items.Add(TUIStateLoader.GetMessage(MessagePrefix + 'ToUnicode'));
        if Index < 0 then
            Index := Ord(pmAuto);
        cbMode.ItemIndex := Index;
    finally
        cbMode.Items.EndUpdate;
    end;
    InputChanged(Self);
end;

procedure TPunycodeForm.FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
    if (Key = VK_ESCAPE) and (Shift = []) and not cbMode.DroppedDown then
    begin
        Key := 0;
        Close;
    end;
end;

procedure TPunycodeForm.InputChanged(Sender: TObject);
begin
    tmrConvert.Enabled := False;
    bCopy.Enabled := False;
    if Trim(mInput.Text) = '' then
    begin
        mResult.Clear;
        mErrors.Clear;
    end
    else
        tmrConvert.Enabled := True;
end;

procedure TPunycodeForm.tmrConvertTimer(Sender: TObject);
var
    Item: TPunycodeResult;
    Mode: TPunycodeMode;
begin
    tmrConvert.Enabled := False;
    Mode := pmAuto;
    if cbMode.ItemIndex >= 0 then
        Mode := TPunycodeMode(cbMode.ItemIndex);
    mResult.Lines.BeginUpdate;
    mErrors.Lines.BeginUpdate;
    try
        mResult.Clear;
        mErrors.Clear;
        for Item in ConvertDomains(mInput.Text, Mode) do
            if Item.Valid then
                mResult.Lines.Add(Item.Value)
            else
                mErrors.Lines.Add(TUIStateLoader.GetMessage(MessagePrefix + 'InvalidLine', [Item.LineNumber]));
    finally
        mErrors.Lines.EndUpdate;
        mResult.Lines.EndUpdate;
    end;
    bCopy.Enabled := mResult.Lines.Count > 0;
end;

procedure TPunycodeForm.bCopyClick(Sender: TObject);
begin
    if not bCopy.Enabled then
        Exit;
    CopyToClipboardSecure(TrimRight(mResult.Text));
    ShowSimpleToast(TUIStateLoader.GetMessage('Common.CopiedToClipboard'));
end;

end.
