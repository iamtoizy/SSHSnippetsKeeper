unit Common.DraftStore;

interface

uses
    System.SysUtils
    ;

const
    DRAFT_FORMAT_VERSION = 1;
    DRAFT_NEW_KEY = 'new';

type
    TDraftPayload = record
        Key: string;
        SavedAt: Int64;
        Title: string;
        Content: string;
        Comment: string;
        Language: string;
        LanguageLocked: Boolean;
        SecurityIgnore: Boolean;
        Tags: TArray<string>;
        Version: Integer;
    end;

    TDraftStore = class
    private
        FDir: string;
        function DraftPath(const AKey: string): string;
        function SanitizeKey(const AKey: string): string;
        function EnsureDir: Boolean;
        class function NowEpoch: Int64; static;
        class function ContainsId(const AIDs: TArray<Int64>; AID: Int64): Boolean; static;
    public
        constructor Create(const ADir: string);

        function SaveDraft(var APayload: TDraftPayload): Boolean;
        function LoadDraft(const AKey: string; out APayload: TDraftPayload): Boolean;
        function DeleteDraft(const AKey: string): Boolean;
        function DraftExists(const AKey: string): Boolean;
        function PurgeStale(ACutoffEpoch: Int64; const ALiveIDs: TArray<Int64>): Integer;

        property Directory: string read FDir;
    end;

implementation

uses
    Common.Settings,
    System.Classes,
    System.DateUtils,
    System.Generics.Collections,
    System.IOUtils,
    System.JSON,
    Winapi.Windows
    ;

constructor TDraftStore.Create(const ADir: string);
begin
    inherited Create;
    FDir := ADir;
end;

function TDraftStore.SanitizeKey(const AKey: string): string;
var
    Ch: Char;
begin
    Result := '';
    for Ch in AKey do
    begin
        if CharInSet(Ch, ['a'..'z', 'A'..'Z', '0'..'9', '_', '-']) then
            Result := Result + Ch
        else
            Result := Result + '_';
    end;
    if Result.IsEmpty then
        raise EArgumentException.Create('Draft key must not be empty');
end;

function TDraftStore.DraftPath(const AKey: string): string;
begin
    Result := TPath.Combine(FDir, SanitizeKey(AKey) + '.draft');
end;

function TDraftStore.EnsureDir: Boolean;
begin
    try
        Result := TDirectory.Exists(FDir) or ForceDirectories(FDir);
    except
        Result := False;
    end;
end;

class function TDraftStore.NowEpoch: Int64;
begin
    Result := DateTimeToUnix(Now, False);
end;

class function TDraftStore.ContainsId(const AIDs: TArray<Int64>; AID: Int64): Boolean;
var
    I: Integer;
begin
    Result := False;
    for I := 0 to High(AIDs) do
    begin
        if AIDs[I] = AID then
        begin
            Result := True;
            Break;
        end;
    end;
end;

function TDraftStore.SaveDraft(var APayload: TDraftPayload): Boolean;
var
    Js: TJSONObject;
    Arr: TJSONArray;
    Tag: string;
    Json, Enc, Target, TmpPath: string;
begin
    Result := False;
    APayload.Key := SanitizeKey(APayload.Key);
    if APayload.SavedAt <= 0 then
        APayload.SavedAt := NowEpoch;
    APayload.Version := DRAFT_FORMAT_VERSION;

    Js := TJSONObject.Create;
    try
        Js.AddPair('version', TJSONNumber.Create(APayload.Version));
        Js.AddPair('key', APayload.Key);
        Js.AddPair('savedAt', TJSONNumber.Create(APayload.SavedAt));
        Js.AddPair('title', APayload.Title);
        Js.AddPair('content', APayload.Content);
        Js.AddPair('comment', APayload.Comment);
        Js.AddPair('language', APayload.Language);
        Js.AddPair('languageLocked', TJSONBool.Create(APayload.LanguageLocked));
        Js.AddPair('securityIgnore', TJSONBool.Create(APayload.SecurityIgnore));
        Arr := TJSONArray.Create;
        for Tag in APayload.Tags do
            Arr.AddElement(TJSONString.Create(Tag));
        Js.AddPair('tags', Arr);
        Json := Js.ToJSON;
    finally
        Js.Free;
    end;

    try
        Enc := ProtectSecret(Json);
        if not IsProtectedSecret(Enc) then
            Exit;
        if not EnsureDir then
            Exit;
        Target := DraftPath(APayload.Key);
        TmpPath := Target + '.tmp';
        TFile.WriteAllText(TmpPath, Enc, TEncoding.UTF8);
        if not MoveFileEx(PChar(TmpPath), PChar(Target), MOVEFILE_REPLACE_EXISTING) then
        begin
            if TFile.Exists(TmpPath) then
                TFile.Delete(TmpPath);
            Exit;
        end;
        Result := True;
    except
        Result := False;
    end;
end;

function TDraftStore.LoadDraft(const AKey: string; out APayload: TDraftPayload): Boolean;
var
    Path, Enc: string;
    Plain: TBytes;
    V: TJSONValue;
    Obj: TJSONObject;
    Arr: TJSONArray;
    I: Integer;
begin
    Result := False;
    APayload := Default(TDraftPayload);
    Plain := nil;
    V := nil;
    try
        try
            Path := DraftPath(AKey);
            if not TFile.Exists(Path) then
                Exit;
            Enc := TFile.ReadAllText(Path, TEncoding.UTF8);
            if not IsProtectedSecret(Enc) then
                Exit;
            Plain := UnprotectSecretToBytes(Enc);
            if Length(Plain) = 0 then
                Exit;
            V := TJSONObject.ParseJSONValue(Plain, 0);
            if V = nil then
                Exit;
            if not (V is TJSONObject) then
                Exit;
            Obj := TJSONObject(V);
            if not Obj.TryGetValue<Integer>('version', APayload.Version) then
                Exit;
            if APayload.Version <> DRAFT_FORMAT_VERSION then
                Exit;
            Obj.TryGetValue<string>('key', APayload.Key);
            Obj.TryGetValue<Int64>('savedAt', APayload.SavedAt);
            Obj.TryGetValue<string>('title', APayload.Title);
            Obj.TryGetValue<string>('content', APayload.Content);
            Obj.TryGetValue<string>('comment', APayload.Comment);
            Obj.TryGetValue<string>('language', APayload.Language);
            Obj.TryGetValue<Boolean>('languageLocked', APayload.LanguageLocked);
            Obj.TryGetValue<Boolean>('securityIgnore', APayload.SecurityIgnore);
            if Obj.TryGetValue<TJSONArray>('tags', Arr) then
            begin
                SetLength(APayload.Tags, Arr.Count);
                for I := 0 to Arr.Count - 1 do
                    APayload.Tags[I] := Arr.Items[I].Value;
            end;
            Result := True;
        except
            Result := False;
        end;
    finally
        WipeSecretBytes(Plain);
        V.Free;
    end;
end;

function TDraftStore.DeleteDraft(const AKey: string): Boolean;
var
    Path: string;
    FS: TFileStream;
    Buf: TBytes;
    Remaining, Chunk: Integer;
begin
    Result := True;
    try
        Path := DraftPath(AKey);
        if not TFile.Exists(Path) then
            Exit;
        FS := TFileStream.Create(Path, fmOpenReadWrite or fmShareDenyWrite);
        try
            SetLength(Buf, 4096);
            if Length(Buf) > 0 then
                FillChar(Buf[0], Length(Buf), 0);
            Remaining := FS.Size;
            FS.Position := 0;
            while Remaining > 0 do
            begin
                if Remaining > Length(Buf) then
                    Chunk := Length(Buf)
                else
                    Chunk := Remaining;
                FS.WriteBuffer(Buf[0], Chunk);
                Dec(Remaining, Chunk);
            end;
        finally
            FS.Free;
        end;
        TFile.Delete(Path);
    except
        Result := False;
    end;
end;

function TDraftStore.DraftExists(const AKey: string): Boolean;
begin
    try
        Result := TFile.Exists(DraftPath(AKey));
    except
        Result := False;
    end;
end;

function TDraftStore.PurgeStale(ACutoffEpoch: Int64; const ALiveIDs: TArray<Int64>): Integer;
var
    FileEntries, TmpEntries: TArray<string>;
    FileEntry, Key: string;
    P: TDraftPayload;
    Id: Int64;
begin
    Result := 0;
    try
        if not TDirectory.Exists(FDir) then
            Exit;
        FileEntries := TDirectory.GetFiles(FDir, '*.draft');
        for FileEntry in FileEntries do
        begin
            Key := TPath.GetFileNameWithoutExtension(FileEntry);
            if not LoadDraft(Key, P) then
            begin
                if DeleteDraft(Key) then
                    Inc(Result);
                Continue;
            end;
            if TryStrToInt64(Key, Id) and not ContainsId(ALiveIDs, Id) then
            begin
                if DeleteDraft(Key) then
                    Inc(Result);
                Continue;
            end;
            if (P.SavedAt > 0) and (P.SavedAt < ACutoffEpoch) then
            begin
                if DeleteDraft(Key) then
                    Inc(Result);
            end;
        end;
        TmpEntries := TDirectory.GetFiles(FDir, '*.draft.tmp');
        for FileEntry in TmpEntries do
        begin
            try
                TFile.Delete(FileEntry);
                Inc(Result);
            except
            end;
        end;
    except
    end;
end;

end.
