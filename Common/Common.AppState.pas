unit Common.AppState;

interface

uses
    System.Classes, System.JSON, System.SysUtils
    ;

type
    TAppStateStore = class
    private
        FFilePath: string;
        FLock: TObject;
        FDoc: TJSONObject;
        FLoaded: Boolean;
        procedure EnsureLoadedLocked;
        procedure LoadLocked;
        procedure SaveLocked;
    public
        constructor Create(const AFilePath: string);
        destructor Destroy; override;
        function ReadSection(const AName: string): TJSONValue;
        procedure WriteSection(const AName: string; AValue: TJSONValue);
        property FilePath: string read FFilePath;
    end;

function AppState: TAppStateStore;

implementation

uses
    Common.Helpers, System.IOUtils, Winapi.Windows
    ;

var
    GState: TAppStateStore;

function AppState: TAppStateStore;
begin
    Result := GState;
end;

procedure MigrateLegacyCounters;
var
    Json, Section: TJSONValue;
    LegacyPath: string;
begin
    try
        if TFile.Exists(GState.FilePath) then
            Exit;
        LegacyPath := ResolvePath('counters.json');
        if not TFile.Exists(LegacyPath) then
            Exit;
        Json := TJSONObject.ParseJSONValue(TFile.ReadAllText(LegacyPath, TEncoding.UTF8));
        if Json = nil then
            Exit;
        try
            Section := Json.FindValue('counters');
            if Section is TJSONArray then
            begin
                GState.WriteSection('counters', TJSONArray(Section.Clone));
                if TFile.Exists(GState.FilePath) then
                    TFile.Delete(LegacyPath);
            end;
        finally
            Json.Free;
        end;
    except
        on E: Exception do
            LogException('MigrateLegacyCounters', E);
    end;
end;

{ TAppStateStore }

constructor TAppStateStore.Create(const AFilePath: string);
begin
    inherited Create;
    FFilePath := AFilePath;
    FLock := TObject.Create;
    FDoc := TJSONObject.Create;
    FDoc.AddPair('version', TJSONNumber.Create(1));
    FLoaded := False;
end;

destructor TAppStateStore.Destroy;
begin
    FDoc.Free;
    FLock.Free;
    inherited;
end;

procedure TAppStateStore.EnsureLoadedLocked;
begin
    if not FLoaded then
        LoadLocked;
end;

procedure TAppStateStore.LoadLocked;
var
    Json: TJSONValue;
begin
    FLoaded := True;
    if not TFile.Exists(FFilePath) then
        Exit;

    try
        Json := TJSONObject.ParseJSONValue(TFile.ReadAllText(FFilePath, TEncoding.UTF8));
    except
        on E: Exception do
        begin
            LogException('TAppStateStore.LoadLocked', E);
            Json := nil;
        end;
    end;
    if Json = nil then
        Exit;

    try
        if not (Json is TJSONObject) then
            Exit;
        FDoc.Free;
        FDoc := TJSONObject(Json);
        Json := nil;
        if FDoc.FindValue('version') = nil then
            FDoc.AddPair('version', TJSONNumber.Create(1));
    finally
        Json.Free;
    end;
end;

procedure TAppStateStore.SaveLocked;
var
    TmpPath: string;
begin
    TmpPath := FFilePath + '.tmp';
    try
        TFile.WriteAllText(TmpPath, FDoc.ToJSON, TEncoding.UTF8);
        if not MoveFileEx(PChar(TmpPath), PChar(FFilePath), MOVEFILE_REPLACE_EXISTING) then
            if TFile.Exists(TmpPath) then
                TFile.Delete(TmpPath);
    except
        on E: Exception do
            LogException('TAppStateStore.SaveLocked', E);
    end;
end;

function TAppStateStore.ReadSection(const AName: string): TJSONValue;
var
    Item: TJSONValue;
begin
    Result := nil;
    TMonitor.Enter(FLock);
    try
        EnsureLoadedLocked;
        Item := FDoc.FindValue(AName);
        if Item <> nil then
            Result := Item.Clone as TJSONValue;
    finally
        TMonitor.Exit(FLock);
    end;
end;

procedure TAppStateStore.WriteSection(const AName: string; AValue: TJSONValue);
var
    Pair: TJSONPair;
begin
    if AValue = nil then
        Exit;
    TMonitor.Enter(FLock);
    try
        EnsureLoadedLocked;
        Pair := FDoc.RemovePair(AName);
        Pair.Free;
        FDoc.AddPair(AName, AValue);
        SaveLocked;
    finally
        TMonitor.Exit(FLock);
    end;
end;

initialization
    GState := TAppStateStore.Create(ResolvePath('appstate.json'));
    MigrateLegacyCounters;

finalization
    FreeAndNil(GState);

end.
