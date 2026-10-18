unit UI.AppStatusBar;

interface

uses
    System.Classes,
    System.SysUtils,
    Vcl.ComCtrls,
    Vcl.ExtCtrls
    ;

type
    TAppStatusBar = class
    public
        const
            SB_PANEL_EVENTS = 0;
            SB_PANEL_DATABASE = 1;
            SB_PANEL_DIRTY = 2;
            SB_PANEL_COUNT = 3;
            SB_PANEL_LANG = 4;
    private
        FStatusBar: TStatusBar;
        FTimer: TTimer;
        FDirty: Boolean;
        procedure OnEraseTimer(Sender: TObject);
    public
        constructor Create(AStatusBar: TStatusBar; EraseTimeoutMs: Integer = 3000);
        destructor Destroy; override;

        procedure Flash(const Text: string);
        procedure SetEvent(const Text: string);
        procedure SetDatabase(const DbFileName: string);
        procedure SetDirty(ADirty: Boolean);
        procedure SetSnippetCount(Total, Selected: Integer);
        procedure SetLanguage(const Text: string);
        procedure Layout;
        procedure ForceUpdate;

        property Dirty: Boolean read FDirty;
    end;

implementation

uses
    Common.Localization,
    System.Math
    ;

constructor TAppStatusBar.Create(AStatusBar: TStatusBar; EraseTimeoutMs: Integer);
begin
    inherited Create;
    FStatusBar := AStatusBar;
    FDirty := False;
    FTimer := TTimer.Create(nil);
    FTimer.Interval := EraseTimeoutMs;
    FTimer.Enabled := False;
    FTimer.OnTimer := OnEraseTimer;
end;

destructor TAppStatusBar.Destroy;
begin
    FTimer.Free;
    inherited Destroy;
end;

procedure TAppStatusBar.OnEraseTimer(Sender: TObject);
begin
    FTimer.Enabled := False;
    FStatusBar.Panels[SB_PANEL_EVENTS].Text := '';
end;

procedure TAppStatusBar.Flash(const Text: string);
begin
    FStatusBar.Panels[SB_PANEL_EVENTS].Text := Text;
    FTimer.Enabled := False;
    FTimer.Enabled := True;
end;

procedure TAppStatusBar.SetEvent(const Text: string);
begin
    FTimer.Enabled := False;
    FStatusBar.Panels[SB_PANEL_EVENTS].Text := Text;
end;

procedure TAppStatusBar.SetDatabase(const DbFileName: string);
begin
    if DbFileName = '' then
        FStatusBar.Panels[SB_PANEL_DATABASE].Text := TUIStateLoader.GetMessage('Common.StatusDbNotOpen')
    else
        FStatusBar.Panels[SB_PANEL_DATABASE].Text := DbFileName;
    Layout;
end;

procedure TAppStatusBar.SetDirty(ADirty: Boolean);
begin
    FDirty := ADirty;
    if ADirty then
        FStatusBar.Panels[SB_PANEL_DIRTY].Text := TUIStateLoader.GetMessage('Common.StatusDbDirty')
    else
        FStatusBar.Panels[SB_PANEL_DIRTY].Text := '';
    Layout;
end;

procedure TAppStatusBar.SetLanguage(const Text: string);
begin
    FStatusBar.Panels[SB_PANEL_LANG].Text := Text;
    Layout;
end;

procedure TAppStatusBar.SetSnippetCount(Total, Selected: Integer);
begin
    if Selected > 0 then
        FStatusBar.Panels[SB_PANEL_COUNT].Text := TUIStateLoader.GetMessage('Common.StatusSnippetCountSel', [Total, Selected])
    else
        FStatusBar.Panels[SB_PANEL_COUNT].Text := TUIStateLoader.GetMessage('Common.StatusSnippetCount', [Total]);
    Layout;
end;

procedure TAppStatusBar.Layout;

    function FitWidth(const Text: string; MinWidth, MaxWidth: Integer): Integer;
    begin
        if Text = '' then
            Exit(0);
        Result := Max(MinWidth, Min(FStatusBar.Canvas.TextWidth(Text) + 26, MaxWidth));
    end;

begin
    FStatusBar.Panels[SB_PANEL_DATABASE].Width := FitWidth(
        FStatusBar.Panels[SB_PANEL_DATABASE].Text, 120, FStatusBar.ClientWidth div 2);
    FStatusBar.Panels[SB_PANEL_DIRTY].Width := FitWidth(
        FStatusBar.Panels[SB_PANEL_DIRTY].Text, 0, 300);
    FStatusBar.Panels[SB_PANEL_COUNT].Width := FitWidth(
        FStatusBar.Panels[SB_PANEL_COUNT].Text, 110, 300);
    FStatusBar.Panels[SB_PANEL_LANG].Width := FitWidth(
        FStatusBar.Panels[SB_PANEL_LANG].Text, 0, 120);

    FStatusBar.Panels[SB_PANEL_EVENTS].Width := Max(50,
        FStatusBar.ClientWidth
        - FStatusBar.Panels[SB_PANEL_DATABASE].Width
        - FStatusBar.Panels[SB_PANEL_DIRTY].Width
        - FStatusBar.Panels[SB_PANEL_COUNT].Width
        - FStatusBar.Panels[SB_PANEL_LANG].Width);
end;

procedure TAppStatusBar.ForceUpdate;
begin
    FStatusBar.Update;
end;

end.
