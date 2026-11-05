unit SnippetDiffFormUI;

// Просмотр изменений сниппета: unified-дифф содержимого и комментария в том
// же оформлении, что и в истории версий (HistoryFormUI). Вызывается по
// требованию кнопкой "Дифф" в редакторе, на сохранение не влияет.

interface

uses
    BaseFormUI,
    Core.Interfaces.App,
    Core.TextDiff,
    SynEdit,
    System.Classes,
    Vcl.Controls,
    Vcl.ExtCtrls,
    Vcl.Graphics,
    Vcl.StdCtrls
    ;

type
    TSnippetDiffForm = class(TBaseForm)
        lbHeader: TLabel;
        pBottom: TPanel;
        bClose: TButton;
        mDiff: TSynEdit;
        procedure mDiffSpecialLineColors(Sender: TObject; Line: Integer;
            var Special: Boolean; var FG, BG: TColor);
    protected
        procedure DoInitialize; override;
    private
        FDiffLines: TArray<TDiffLine>;

        procedure SetDiffLines(const ADiff: TArray<TDiffLine>);
    public
        class procedure Execute(Owner: TComponent; AppContext: IAppContext;
            const ADiffLines: TArray<TDiffLine>;
            const AOtherChanges: string);
    end;

implementation

{$R *.dfm}

uses
    SynThemeAdapter,
    System.SysUtils
    ;

{ TSnippetDiffForm }

class procedure TSnippetDiffForm.Execute(Owner: TComponent;
    AppContext: IAppContext; const ADiffLines: TArray<TDiffLine>;
    const AOtherChanges: string);
var
    Frm: TSnippetDiffForm;
begin
    Frm := TSnippetDiffForm.Create(Owner);
    try
        Frm.LockDrawing;
        try
            Frm.lbHeader.Caption := AOtherChanges;
            Frm.lbHeader.Visible := not AOtherChanges.IsEmpty;
            Frm.SetDiffLines(ADiffLines);
            Frm.Initialize(AppContext);
        finally
            Frm.UnlockDrawing;
        end;
        Frm.WarmUpPaint;
        Frm.PrepareGuardedShow;
        Frm.ShowModal;
    finally
        Frm.Free;
    end;
end;

procedure TSnippetDiffForm.DoInitialize;
begin
    inherited;
    TSynThemeAdapter.ApplyTheme(mDiff);
end;

procedure TSnippetDiffForm.SetDiffLines(const ADiff: TArray<TDiffLine>);
var
    Line: TDiffLine;
begin
    FDiffLines := ADiff;

    mDiff.Lines.BeginUpdate;
    try
        mDiff.Lines.Clear;
        for Line in ADiff do
            mDiff.Lines.Add(Line.Text);
        mDiff.TopLine := 1;
    finally
        mDiff.Lines.EndUpdate;
    end;
end;

procedure TSnippetDiffForm.mDiffSpecialLineColors(Sender: TObject;
    Line: Integer; var Special: Boolean; var FG, BG: TColor);
begin
    Special := False;
    if (Line >= 1) and (Line <= Length(FDiffLines)) then
        case FDiffLines[Line - 1].Kind of
            dlInsert:
                begin
                    Special := True;
                    FG := clGreen;
                    BG := TColor($D8F0D8);
                end;
            dlDelete:
                begin
                    Special := True;
                    FG := clRed;
                    BG := TColor($F0D8D8);
                end;
        end;
end;

end.
