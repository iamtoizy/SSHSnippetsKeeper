unit WindowProfileDialogUI;

interface

uses
    BaseFormUI,
    Core.Interfaces.App,
    Core.Interfaces.Settings,
    System.Classes,
    System.RegularExpressions,
    System.SysUtils,
    Vcl.Controls,
    Vcl.ExtCtrls,
    Vcl.Forms,
    Vcl.StdCtrls
    ;

type
    // Профиль окна разрешённого приложения: классы окон и regex заголовков
    TWindowProfileDialog = class(TBaseForm)
        lblAppName: TLabel;
        leInclude: TLabeledEdit;
        leExclude: TLabeledEdit;
        leClasses: TLabeledEdit;
        lbHint: TLabel;
        pBottom: TPanel;
        bOK: TButton;
        bCancel: TButton;
        procedure bOKClick(Sender: TObject);
    private
        procedure ApplyToProfile(var AProfile: TAllowedApplicationsItem);
        function ClassesTextToClasses: TArray<string>;
        function IsValidRegex(const APattern: string): Boolean;
    public
        class function Execute(AOwner: TComponent; AppContext: IAppContext; const AExeName: string; var AProfile: TAllowedApplicationsItem): Boolean;
    end;

var
    WindowProfileDialog: TWindowProfileDialog;

implementation

uses
    Common.Localization
    ;

{$R *.dfm}

class function TWindowProfileDialog.Execute(AOwner: TComponent; AppContext: IAppContext; const AExeName: string; var AProfile: TAllowedApplicationsItem): Boolean;
var
    Instance: TWindowProfileDialog;
    C: string;
    SB: TStringBuilder;
begin
    Result := False;
    Instance := TWindowProfileDialog.Create(AOwner);
    try
        Instance.Initialize(AppContext);

        Instance.Caption := TUIStateLoader.GetMessage('Settings.ApplicationsProfileTitle', [AExeName]);
        Instance.lblAppName.Caption := AExeName;
        Instance.leInclude.EditLabel.Caption := TUIStateLoader.GetMessage('Settings.ApplicationsProfileInclude');
        Instance.leExclude.EditLabel.Caption := TUIStateLoader.GetMessage('Settings.ApplicationsProfileExclude');
        Instance.leClasses.EditLabel.Caption := TUIStateLoader.GetMessage('Settings.ApplicationsProfileClasses');
        Instance.lbHint.Caption := TUIStateLoader.GetMessage('Settings.ApplicationsProfileHint');

        Instance.leInclude.Text := AProfile.TitleIncludeRegex;
        Instance.leExclude.Text := AProfile.TitleExcludeRegex;

        SB := TStringBuilder.Create;
        try
            for C in AProfile.WindowClasses do
            begin
                if SB.Length > 0 then
                    SB.Append(', ');
                SB.Append(C);
            end;
            Instance.leClasses.Text := SB.ToString;
        finally
            SB.Free;
        end;

        Instance.WarmUpPaint;
        Instance.PrepareGuardedShow;

        if Instance.ShowModal = mrOk then
        begin
            Instance.ApplyToProfile(AProfile);
            Result := True;
        end;
    finally
        Instance.Free;
    end;
end;

procedure TWindowProfileDialog.bOKClick(Sender: TObject);
var
    Pattern: string;
begin
    Pattern := Trim(leInclude.Text);
    if not IsValidRegex(Pattern) then
    begin
        MessagesHandler.ShowError(TUIStateLoader.GetMessage('Settings.ApplicationsProfileInvalidRegex', [Pattern]));
        leInclude.SetFocus;
        Exit;
    end;

    Pattern := Trim(leExclude.Text);
    if not IsValidRegex(Pattern) then
    begin
        MessagesHandler.ShowError(TUIStateLoader.GetMessage('Settings.ApplicationsProfileInvalidRegex', [Pattern]));
        leExclude.SetFocus;
        Exit;
    end;

    ModalResult := mrOk;
end;

function TWindowProfileDialog.IsValidRegex(const APattern: string): Boolean;
begin
    Result := True;
    if APattern = '' then
        Exit;

    try
        TRegEx.IsMatch('', APattern);
    except
        Result := False;
    end;
end;

function TWindowProfileDialog.ClassesTextToClasses: TArray<string>;
var
    S, Token: string;
    P, SepP, Count: Integer;
begin
    SetLength(Result, 0);
    Count := 0;
    S := leClasses.Text;

    while S <> '' do
    begin
        P := Pos(',', S);
        SepP := Pos(';', S);
        if (SepP > 0) and ((P = 0) or (SepP < P)) then
            P := SepP;

        if P = 0 then
        begin
            Token := Trim(S);
            S := '';
        end
        else
        begin
            Token := Trim(Copy(S, 1, P - 1));
            Delete(S, 1, P);
        end;

        if Token <> '' then
        begin
            Inc(Count);
            SetLength(Result, Count);
            Result[Count - 1] := Token;
        end;
    end;
end;

procedure TWindowProfileDialog.ApplyToProfile(var AProfile: TAllowedApplicationsItem);
begin
    AProfile.TitleIncludeRegex := Trim(leInclude.Text);
    AProfile.TitleExcludeRegex := Trim(leExclude.Text);
    AProfile.WindowClasses := ClassesTextToClasses;
end;

end.
