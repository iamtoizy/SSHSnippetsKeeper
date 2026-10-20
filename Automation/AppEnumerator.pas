unit AppEnumerator;

interface

uses
    System.SysUtils
    ;

type
    TAppEntry = record
        ExeName: string;
        FullPath: string;
        WindowTitle: string;
        LastRun: TDateTime;
    end;

function GetRunningApplications: TArray<TAppEntry>;
function GetRecentApplications(const AMaxCount: Integer = 100): TArray<TAppEntry>;

implementation

uses
    System.Classes,
    System.Generics.Collections,
    System.Generics.Defaults,
    System.Win.Registry,
    Winapi.DwmApi,
    Winapi.Windows
    ;

const
    PROCESS_QUERY_LIMITED_INFORMATION = $1000;

function QueryFullProcessImageNameW(hProcess: THandle; dwFlags: DWORD; lpExeName: PWideChar; var lpdwSize: DWORD): BOOL; stdcall; external kernel32 name 'QueryFullProcessImageNameW';

var
    GEntries: TList<TAppEntry>;
    GKnown: TDictionary<string, Boolean>;

procedure AddWindow(Wnd: HWND);
var
    PID: DWORD;
    hProc: THandle;
    PathLen: DWORD;
    Path, Title: string;
    Len: Integer;
    Cloaked: DWORD;
    Entry: TAppEntry;
begin
    if not IsWindowVisible(Wnd) then
        Exit;

    if (GetWindowLong(Wnd, GWL_EXSTYLE) and WS_EX_TOOLWINDOW) <> 0 then
        Exit;

    Len := GetWindowTextLength(Wnd);
    if Len <= 0 then
        Exit;

    Cloaked := 0;
    if (DwmGetWindowAttribute(Wnd, DWMWA_CLOAKED, @Cloaked, SizeOf(Cloaked)) = S_OK) and (Cloaked <> 0) then
        Exit;

    SetLength(Title, Len);
    Len := GetWindowText(Wnd, PChar(Title), Len + 1);
    if Len <= 0 then
        Exit;
    SetLength(Title, Len);

    PID := 0;
    GetWindowThreadProcessId(Wnd, PID);
    if PID = 0 then
        Exit;

    hProc := OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, False, PID);
    if hProc = 0 then
        Exit;
    try
        SetLength(Path, MAX_PATH * 4);
        PathLen := Length(Path);
        if (not QueryFullProcessImageNameW(hProc, 0, PChar(Path), PathLen)) or (PathLen = 0) then
            Exit;
        SetLength(Path, PathLen);
    finally
        CloseHandle(hProc);
    end;

    if SameText(ExtractFileName(Path), ExtractFileName(ParamStr(0))) then
        Exit;

    if GKnown.ContainsKey(Path.ToLower) then
        Exit;

    Entry.ExeName := ExtractFileName(Path);
    Entry.FullPath := Path;
    Entry.WindowTitle := Title;
    Entry.LastRun := 0;

    GKnown.Add(Path.ToLower, True);
    GEntries.Add(Entry);
end;

function EnumProc(Wnd: HWND; LParam: LPARAM): BOOL; stdcall;
begin
    AddWindow(Wnd);
    Result := True;
end;

function GetRunningApplications: TArray<TAppEntry>;
begin
    Result := nil;
    GEntries := TList<TAppEntry>.Create;
    GKnown := TDictionary<string, Boolean>.Create;
    try
        EnumWindows(@EnumProc, 0);
        Result := GEntries.ToArray;
    finally
        GKnown.Free;
        GEntries.Free;
    end;
end;

function Rot13Decode(const S: string): string;
var
    I: Integer;
    C: Char;
begin
    Result := S;
    for I := 1 to Length(Result) do
    begin
        C := Result[I];
        case C of
            'A'..'Z':
                Result[I] := Chr(Ord('A') + (Ord(C) - Ord('A') + 13) mod 26);
            'a'..'z':
                Result[I] := Chr(Ord('a') + (Ord(C) - Ord('a') + 13) mod 26);
        end;
    end;
end;

function FileTimeToDateTime(const AFileTime: UInt64): TDateTime;
begin
    Result := AFileTime / 864000000000.0 - 109205.0;
end;

function GetRecentApplications(const AMaxCount: Integer): TArray<TAppEntry>;
const
    USERASSIST_KEY = 'Software\Microsoft\Windows\CurrentVersion\Explorer\UserAssist\{CEBFF5CD-ACE2-4F4F-9178-9926F41749EA}\Count';
    MIN_VALID_FILETIME: UInt64 = 125911584000000000;
var
    Reg: TRegistry;
    Names: TStringList;
    ValueName, Decoded: string;
    Info: TRegDataInfo;
    Data: TBytes;
    I, Idx: Integer;
    FT, BestFT, NowFT: UInt64;
    BestDT: TDateTime;
    Entry: TAppEntry;
    Known: TDictionary<string, Integer>;
    List: TList<TAppEntry>;
    NowFTRec: TFileTime;
begin
    Result := nil;
    List := TList<TAppEntry>.Create;
    Known := TDictionary<string, Integer>.Create;
    try
        GetSystemTimeAsFileTime(NowFTRec);
        NowFT := (UInt64(NowFTRec.dwHighDateTime) shl 32) or UInt64(NowFTRec.dwLowDateTime);

        Reg := TRegistry.Create(KEY_READ);
        try
            if not Reg.OpenKeyReadOnly(USERASSIST_KEY) then
                Exit;

            Names := TStringList.Create;
            try
                Reg.GetValueNames(Names);

                for ValueName in Names do
                begin
                    Decoded := Rot13Decode(ValueName);
                    if not Decoded.ToLower.EndsWith('.exe') then
                        Continue;
                    if (Pos('\', Decoded) = 0) and (Pos('/', Decoded) = 0) then
                        Continue;

                    if not Reg.GetDataInfo(ValueName, Info) then
                        Continue;
                    if (Info.RegData <> rdBinary) or (Info.DataSize < 16) then
                        Continue;

                    SetLength(Data, Info.DataSize);
                    try
                        if Reg.ReadBinaryData(ValueName, Data[0], Info.DataSize) <> Info.DataSize then
                            Continue;
                    except
                        Continue;
                    end;

                    BestFT := 0;
                    for I := 0 to Info.DataSize - 8 do
                    begin
                        FT := UInt64(Data[I])
                            or (UInt64(Data[I + 1]) shl 8)
                            or (UInt64(Data[I + 2]) shl 16)
                            or (UInt64(Data[I + 3]) shl 24)
                            or (UInt64(Data[I + 4]) shl 32)
                            or (UInt64(Data[I + 5]) shl 40)
                            or (UInt64(Data[I + 6]) shl 48)
                            or (UInt64(Data[I + 7]) shl 56);
                        if (FT > MIN_VALID_FILETIME) and (FT <= NowFT) and (FT > BestFT) then
                            BestFT := FT;
                    end;

                    if BestFT = 0 then
                        Continue;

                    BestDT := FileTimeToDateTime(BestFT);

                    if Known.TryGetValue(ExtractFileName(Decoded).ToLower, Idx) then
                    begin
                        if BestDT > List[Idx].LastRun then
                        begin
                            Entry := List[Idx];
                            Entry.FullPath := Decoded;
                            Entry.LastRun := BestDT;
                            List[Idx] := Entry;
                        end;
                        Continue;
                    end;

                    Entry.ExeName := ExtractFileName(Decoded);
                    Entry.FullPath := Decoded;
                    Entry.WindowTitle := '';
                    Entry.LastRun := BestDT;

                    Known.Add(ExtractFileName(Decoded).ToLower, List.Count);
                    List.Add(Entry);
                end;
            finally
                Names.Free;
            end;
        finally
            Reg.Free;
        end;

        List.Sort(TComparer<TAppEntry>.Construct(
            function(const ALeft, ARight: TAppEntry): Integer
            begin
                if ALeft.LastRun > ARight.LastRun then
                    Result := -1
                else if ALeft.LastRun < ARight.LastRun then
                    Result := 1
                else
                    Result := 0;
            end));

        if (AMaxCount > 0) and (List.Count > AMaxCount) then
            List.Count := AMaxCount;

        Result := List.ToArray;
    finally
        Known.Free;
        List.Free;
    end;
end;

end.
