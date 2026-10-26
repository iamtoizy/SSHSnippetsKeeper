unit DryRunFormUI;

interface

uses
    BaseFormUI,
    Core.Entities.Snippet,
    Core.Interfaces.App,
    MacroInputTypes,
    System.Classes,
    Vcl.ComCtrls,
    Vcl.Controls,
    Vcl.ExtCtrls,
    Vcl.Forms,
    Vcl.StdCtrls
    ;

type
    TDryRunForm = class(TBaseForm)
        pnlMain: TPanel;
        rePreview: TRichEdit;
        bRun: TButton;
        bClose: TButton;
        sbBottom: TStatusBar;
    private
        FSnippet: TSnippetDTO;
        FLines: TArray<TTranscriptLine>;
        function TypeNameText(AInputType: TMacroInputType): string;
        function LineText(const Line: TTranscriptLine): string;
        procedure ColorWarningLines;
        procedure FillPreview;
    end;

function ShowDryRunForm(const Snippet: TSnippetDTO; const AppContext: IAppContext): TModalResult;

implementation

uses
    Common.Localization,
    MacroEngine,
    System.SysUtils,
    Vcl.Graphics,
    Winapi.Messages,
    Winapi.Windows
    ;

{$R *.dfm}

function ShowDryRunForm(const Snippet: TSnippetDTO; const AppContext: IAppContext): TModalResult;
var
    Form: TDryRunForm;
    Engine: TMacroEngine;
    Context: TMacroContext;
begin
    Engine := TMacroEngine.Create;
    try
        Context := TMacroContext.Create;
        try
            Context.SnippetID := Snippet.ID;

            Form := TDryRunForm.Create(nil);
            try
                Form.Initialize(AppContext);
                Form.FSnippet := Snippet;
                Form.FLines := Engine.DryRunTranscript(Snippet.Content, Context);
                Form.Caption := TUIStateLoader.GetMessage('DryRun.PreviewTitle', [Snippet.Title]);
                Form.FillPreview;
                Form.ActiveControl := Form.bRun;
                Form.WarmUpPaint;
                Form.PrepareGuardedShow;
                Result := Form.ShowModal;
            finally
                Form.Free;
            end;
        finally
            Context.Free;
        end;
    finally
        Engine.Free;
    end;
end;

function TDryRunForm.TypeNameText(AInputType: TMacroInputType): string;
begin
    case AInputType of
        mitString: Result := TUIStateLoader.GetMessage('DryRun.TypeName.String');
        mitNumber: Result := TUIStateLoader.GetMessage('DryRun.TypeName.Number');
        mitHex: Result := TUIStateLoader.GetMessage('DryRun.TypeName.Hex');
        mitFloat: Result := TUIStateLoader.GetMessage('DryRun.TypeName.Float');
        mitPassword: Result := TUIStateLoader.GetMessage('DryRun.TypeName.Password');
        mitDate: Result := TUIStateLoader.GetMessage('DryRun.TypeName.Date');
        mitTime: Result := TUIStateLoader.GetMessage('DryRun.TypeName.Time');
        mitDateTime: Result := TUIStateLoader.GetMessage('DryRun.TypeName.DateTime');
        mitConfirm: Result := TUIStateLoader.GetMessage('DryRun.TypeName.Confirm');
    else
        Result := TUIStateLoader.GetMessage('DryRun.TypeName.Select');
    end;
end;

function TDryRunForm.LineText(const Line: TTranscriptLine): string;
begin
    case Line.Kind of
        tlText:
            Result := Line.Detail;

        tlEnter:
            Result := TUIStateLoader.GetMessage('DryRun.Line.Enter');

        tlSleep:
            Result := TUIStateLoader.GetMessage('DryRun.Line.Sleep', [Line.Detail]);

        tlInput:
            begin
                Result := TUIStateLoader.GetMessage('DryRun.Line.Input', [Line.Name, TypeNameText(Line.InputType)]);
                if Line.Detail <> '' then
                    Result := Result + ' ' + TUIStateLoader.GetMessage('DryRun.Line.Default', [Line.Detail]);
            end;

        tlConfirm:
            Result := TUIStateLoader.GetMessage('DryRun.Line.Confirm', [Line.Name]);

        tlSendKey:
            Result := TUIStateLoader.GetMessage('DryRun.Line.SendKey', [Line.Detail]);

        tlValue:
            begin
                Result := TUIStateLoader.GetMessage('DryRun.Line.Value', [Line.Name, Line.Detail]);
                if Line.Name = 'COUNTER' then
                    Result := Result + ' ' + TUIStateLoader.GetMessage('DryRun.Line.CounterNote');
            end;

        tlClearLine:
            Result := TUIStateLoader.GetMessage('DryRun.Line.ClearLine');

        tlKeyDelay:
            Result := TUIStateLoader.GetMessage('DryRun.Line.KeyDelay', [Line.Detail]);

        tlWarning:
            Result := TUIStateLoader.GetMessage('DryRun.Warn.Unknown', [Line.Macro]);
    end;
end;

procedure TDryRunForm.ColorWarningLines;
var
    I: Integer;
begin
    rePreview.SelStart := 0;
    rePreview.SelLength := 0;
    for I := 0 to Length(FLines) - 1 do
    begin
        if (FLines[I].Warning = '') and (FLines[I].Kind <> tlWarning) then
            Continue;

        rePreview.SelStart := rePreview.Perform(EM_LINEINDEX, I, 0);
        rePreview.SelLength := Length(rePreview.Lines[I]);
        rePreview.SelAttributes.Color := RGB(190, 30, 30);
    end;
    rePreview.SelStart := 0;
    rePreview.SelLength := 0;
end;

procedure TDryRunForm.FillPreview;
var
    Line: TTranscriptLine;
    Total, Warnings: Integer;
begin
    rePreview.Lines.BeginUpdate;
    try
        rePreview.Lines.Clear;
        Total := 0;
        Warnings := 0;

        for Line in FLines do
        begin
            Inc(Total);
            rePreview.Lines.Add(LineText(Line));
            if (Line.Warning <> '') or (Line.Kind = tlWarning) then
                Inc(Warnings);
        end;

        ColorWarningLines;
        sbBottom.SimpleText := TUIStateLoader.GetMessage('DryRun.Summary', [Total, Warnings]);
    finally
        rePreview.Lines.EndUpdate;
    end;
end;

end.
