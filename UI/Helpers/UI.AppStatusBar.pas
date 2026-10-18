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
end;

procedure TAppStatusBar.SetDirty(ADirty: Boolean);
begin
    FDirty := ADirty;
    if ADirty then
        FStatusBar.Panels[SB_PANEL_DIRTY].Text := TUIStateLoader.GetMessage('Common.StatusDbDirty')
    else
        FStatusBar.Panels[SB_PANEL_DIRTY].Text := '';
end;

procedure TAppStatusBar.SetSnippetCount(Total, Selected: Integer);
begin
    if Selected > 0 then
        FStatusBar.Panels[SB_PANEL_COUNT].Text := TUIStateLoader.GetMessage('Common.StatusSnippetCountSel', [Total, Selected])
    else
        FStatusBar.Panels[SB_PANEL_COUNT].Text := TUIStateLoader.GetMessage('Common.StatusSnippetCount', [Total]);
end;

procedure TAppStatusBar.Layout;
var
    I: Integer;
    Fixed: Integer;
begin
    Fixed := 0;
    for I := SB_PANEL_DATABASE to SB_PANEL_LANG do
        Fixed := Fixed + FStatusBar.Panels[I].Width;
    FStatusBar.Panels[SB_PANEL_EVENTS].Width := Max(50, FStatusBar.ClientWidth - Fixed);
end;

procedure TAppStatusBar.ForceUpdate;
begin
    FStatusBar.Update;
end;

end.
