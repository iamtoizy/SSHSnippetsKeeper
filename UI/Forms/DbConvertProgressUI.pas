unit DbConvertProgressUI;

interface

uses
    BaseFormUI,
    Core.Interfaces.App,
    System.Classes,
    Vcl.ComCtrls,
    Vcl.Controls,
    Vcl.ExtCtrls,
    Vcl.Forms,
    Vcl.StdCtrls
    ;

type
    TDbConvertProgressForm = class(TBaseForm)
        pnlMain: TPanel;
        lbText: TLabel;
        pbWork: TProgressBar;
        procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
        procedure FormShow(Sender: TObject);
    private
        FDbFile: string;
        FOldKey: string;
        FNewKey: string;
        FErrorMessage: string;
        FDone: Boolean;
        procedure StartWork;
    public
        procedure Setup(const ACaption, AText, ADbFile, AOldKey, ANewKey: string);
        property ErrorMessage: string read FErrorMessage;
    end;

function ConvertDbWithProgress(const ACaption, AText, ADbFile, AOldKey, ANewKey: string;
    const AppContext: IAppContext; out AErrMsg: string): Boolean;

implementation

uses
    Data.Database.Security,
    System.SysUtils
    ;

{$R *.dfm}

function ConvertDbWithProgress(const ACaption, AText, ADbFile, AOldKey, ANewKey: string;
    const AppContext: IAppContext; out AErrMsg: string): Boolean;
var
    Form: TDbConvertProgressForm;
begin
    Form := TDbConvertProgressForm.Create(nil);
    try
        Form.Initialize(AppContext);
        Form.Setup(ACaption, AText, ADbFile, AOldKey, ANewKey);
        Form.WarmUpPaint;
        Form.PrepareGuardedShow;

        Result := Form.ShowModal = mrOk;
        AErrMsg := Form.ErrorMessage;
    finally
        Form.Free;
    end;
end;

procedure TDbConvertProgressForm.Setup(const ACaption, AText, ADbFile, AOldKey, ANewKey: string);
begin
    Caption := ACaption;
    lbText.Caption := AText;
    FDbFile := ADbFile;
    FOldKey := AOldKey;
    FNewKey := ANewKey;
end;

procedure TDbConvertProgressForm.FormCloseQuery(Sender: TObject; var CanClose: Boolean);
begin
    // Во время rekey закрывать окно нельзя - прерывание конверсии небезопасно
    CanClose := FDone;
end;

procedure TDbConvertProgressForm.FormShow(Sender: TObject);
begin
    if not FDone then
        StartWork;
end;

procedure TDbConvertProgressForm.StartWork;
begin
    TThread.CreateAnonymousThread(
        procedure
        begin
            try
                ConvertDatabaseEncryption(FDbFile, FOldKey, FNewKey);
                FDone := True;
                TThread.Synchronize(nil,
                    procedure
                    begin
                        ModalResult := mrOk;
                    end);
            except
                on E: Exception do
                begin
                    FErrorMessage := E.Message;
                    FDone := True;
                    TThread.Synchronize(nil,
                        procedure
                        begin
                            ModalResult := mrAbort;
                        end);
                end;
            end;
        end).Start;
end;

end.
