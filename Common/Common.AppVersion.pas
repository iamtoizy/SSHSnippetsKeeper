unit Common.AppVersion;

interface

// Full ProductVersion string from the exe VERSIONINFO resource,
// for example: 1.0.0.123 (a1b2c3d, 2026-11-03, Debug)
function GetAppVersionInfo: string;

// Short version for UI captions, for example: v1.0.0.123
// (the trailing build number maps 1:1 to a git commit)
function GetAppVersionShort: string;

implementation

uses
    System.SysUtils,
    Winapi.Windows;

function VersionResourceString(const Key: string): string;
var
    ModuleName: array [0 .. MAX_PATH - 1] of Char;
    Dummy: DWORD;
    Size: DWORD;
    Data: Pointer;
    Buffer: Pointer;
    Len: UINT;
begin
    Result := '';
    if GetModuleFileName(HInstance, ModuleName, MAX_PATH) = 0 then
        Exit;
    Size := GetFileVersionInfoSize(ModuleName, Dummy);
    if Size = 0 then
        Exit;
    GetMem(Data, Size);
    try
        if not GetFileVersionInfo(ModuleName, Dummy, Size, Data) then
            Exit;
        if VerQueryValue(Data, PChar('\StringFileInfo\040904B0\' + Key), Buffer, Len) and (Len > 0) then
            Result := PChar(Buffer);
    finally
        FreeMem(Data);
    end;
end;

function GetAppVersionInfo: string;
begin
    Result := VersionResourceString('ProductVersion');
    if Result = '' then
        Result := VersionResourceString('FileVersion');
end;

function GetAppVersionShort: string;
var
    V: string;
begin
    V := VersionResourceString('FileVersion');
    if V = '' then
        V := '0.0.0.0';
    Result := 'v' + V;
end;

end.
