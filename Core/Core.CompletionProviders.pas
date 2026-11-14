unit Core.CompletionProviders;

// Провайдеры автодополнения второго уровня: контекстные динамические
// предложения поверх статического дерева из autocomplete.json. Провайдер
// сопоставляется с префиксом пути команды (например, "git commit") и
// добавляет свои пункты в список: статические наборы флагов для git и
// установленные пакеты для winget install/uninstall/upgrade (запрос
// реестра с кэшированием)

interface

uses
    System.Classes,
    System.Generics.Collections,
    System.SysUtils,
    Winapi.Windows
    ;

type
    // Заполняет ItemList/InsertList предложениями для совпавшего контекста
    TCompletionContextFunc = reference to procedure(ItemList, InsertList: TStrings);

    TContextProviderEntry = class
    public
        Language: string;
        Path: TArray<string>;
        Func: TCompletionContextFunc;
        constructor Create(const ALanguage: string; const APath: array of string;
            AFunc: TCompletionContextFunc);
        // Path - префикс AContext (сравнение без учёта регистра)
        function Matches(const ALanguage: string; const AContext: TArray<string>): Boolean;
    end;

    TCompletionProviderRegistry = class
    private
        FEntries: TObjectList<TContextProviderEntry>;
    public
        constructor Create;
        destructor Destroy; override;

        // ALanguage - id секции (bash/bat/powershell); APath не должен
        // быть пустым
        procedure RegisterProvider(const ALanguage: string; const APath: array of string;
            AFunc: TCompletionContextFunc);
        // Собирает предложения всех подходящих провайдеров; ошибка одного
        // провайдера логируется и не прерывает остальные
        procedure Fill(const ALanguage: string; const AContext: TArray<string>;
            ItemList, InsertList: TStrings);

        property Entries: TObjectList<TContextProviderEntry> read FEntries;
    end;

// Встроенные провайдеры для всех языков автодополнения
// (git-флаги + пакеты winget)
procedure RegisterBuiltinProviders(ARegistry: TCompletionProviderRegistry);

type
    // Кэшированный список display name установленных пакетов, собирается
    // из ключей реестра Uninstall (HKLM 64/32-битные представления + HKCU)
    TWingetPackageCache = class
    private const
        CACHE_LIFETIME_MS = 60000;
    private
        class var FNames: TStringList;
        class var FCollectedAt: TDateTime;
        class var FLock: TObject;
        class procedure CollectInto(List: TStringList);
        class procedure CollectView(RootKey: HKEY; View: Cardinal; List: TStringList);
    public
        class constructor Create;
        class destructor Destroy;
        // Возвращает общий кэшированный список; освобождать нельзя
        class function GetNames: TStringList;
    end;

implementation

uses
    System.DateUtils,
    System.Win.Registry,
    Common.Helpers,
    Common.SnippetLanguages
    ;

const
    UNINSTALL_KEY = 'Software\Microsoft\Windows\CurrentVersion\Uninstall';

var
    // Общие статические списки флагов, заполняются один раз
    GitCommitFlags: TStringList;
    GitPushFlags: TStringList;
    GitAddFlags: TStringList;

procedure EnsureGitFlagLists;
    procedure FillFlags(List: TStringList; const Values: array of string);
    var
        V: string;
    begin
        for V in Values do
            List.Add(V);
    end;
begin
    if Assigned(GitCommitFlags) then
        Exit;

    GitCommitFlags := TStringList.Create;
    FillFlags(GitCommitFlags, ['--amend', '--amend --no-edit', '-m', '--message=',
        '--no-edit', '--no-verify', '-a', '--all', '-s']);

    GitPushFlags := TStringList.Create;
    FillFlags(GitPushFlags, ['--force-with-lease', '--force', '-u', '--set-upstream',
        '--dry-run', '--tags']);

    GitAddFlags := TStringList.Create;
    FillFlags(GitAddFlags, ['-A', '--all', '-u', '--update', '-p', '--patch',
        '-f', '--force', '-n', '--dry-run', '-i', '--interactive']);
end;

procedure AddFlagProposals(Flags: TStringList; ItemList, InsertList: TStrings);
var
    I: Integer;
begin
    for I := 0 to Flags.Count - 1 do
    begin
        ItemList.Add(Flags[I]);
        InsertList.Add(Flags[I] + ' ');
    end;
end;

procedure GitCommitProvider(ItemList, InsertList: TStrings);
begin
    AddFlagProposals(GitCommitFlags, ItemList, InsertList);
end;

procedure GitPushProvider(ItemList, InsertList: TStrings);
begin
    AddFlagProposals(GitPushFlags, ItemList, InsertList);
end;

procedure GitAddProvider(ItemList, InsertList: TStrings);
begin
    AddFlagProposals(GitAddFlags, ItemList, InsertList);
end;

procedure WingetPackageProvider(ItemList, InsertList: TStrings);
var
    Names: TStringList;
    Name: string;
begin
    Names := TWingetPackageCache.GetNames;
    for Name in Names do
    begin
        ItemList.Add(Name);
        InsertList.Add(Name + ' ');
    end;
end;

procedure RegisterBuiltinProviders(ARegistry: TCompletionProviderRegistry);
var
    Langs: array [0..2] of string;
    Lang: string;
begin
    EnsureGitFlagLists;

    Langs[0] := SNIPPET_LANG_BASH;
    Langs[1] := SNIPPET_LANG_BAT;
    Langs[2] := SNIPPET_LANG_POWERSHELL;

    for Lang in Langs do
    begin
        ARegistry.RegisterProvider(Lang, ['git', 'commit'], GitCommitProvider);
        ARegistry.RegisterProvider(Lang, ['git', 'push'], GitPushProvider);
        ARegistry.RegisterProvider(Lang, ['git', 'add'], GitAddProvider);

        ARegistry.RegisterProvider(Lang, ['winget', 'install'], WingetPackageProvider);
        ARegistry.RegisterProvider(Lang, ['winget', 'uninstall'], WingetPackageProvider);
        ARegistry.RegisterProvider(Lang, ['winget', 'upgrade'], WingetPackageProvider);
    end;
end;

{ TContextProviderEntry }

constructor TContextProviderEntry.Create(const ALanguage: string;
    const APath: array of string; AFunc: TCompletionContextFunc);
var
    I: Integer;
begin
    inherited Create;
    Language := LowerCase(ALanguage);
    SetLength(Path, Length(APath));
    for I := 0 to Length(APath) - 1 do
        Path[I] := LowerCase(Trim(APath[I]));
    Func := AFunc;
end;

function TContextProviderEntry.Matches(const ALanguage: string;
    const AContext: TArray<string>): Boolean;
var
    I: Integer;
begin
    Result := (Length(Path) > 0) and (Length(Path) <= Length(AContext));
    if not Result then
        Exit;
    if Language <> LowerCase(ALanguage) then
        Exit(False);
    for I := 0 to Length(Path) - 1 do
        if Path[I] <> LowerCase(AContext[I]) then
            Exit(False);
end;

{ TCompletionProviderRegistry }

constructor TCompletionProviderRegistry.Create;
begin
    inherited Create;
    FEntries := TObjectList<TContextProviderEntry>.Create(True);
end;

destructor TCompletionProviderRegistry.Destroy;
begin
    FEntries.Free;
    inherited;
end;

procedure TCompletionProviderRegistry.RegisterProvider(const ALanguage: string;
    const APath: array of string; AFunc: TCompletionContextFunc);
begin
    if Length(APath) = 0 then
        raise EArgumentException.Create('Context path must not be empty');
    if not Assigned(AFunc) then
        raise EArgumentNilException.Create('Provider function must not be nil');
    FEntries.Add(TContextProviderEntry.Create(ALanguage, APath, AFunc));
end;

procedure TCompletionProviderRegistry.Fill(const ALanguage: string;
    const AContext: TArray<string>; ItemList, InsertList: TStrings);
var
    Entry: TContextProviderEntry;
begin
    for Entry in FEntries do
    begin
        if not Entry.Matches(ALanguage, AContext) then
            Continue;
        try
            Entry.Func(ItemList, InsertList);
        except
            // сломанный провайдер не должен ронять автодополнение целиком
            on E: Exception do
                LogException('CompletionProvider.' + Entry.Path[0], E);
        end;
    end;
end;

{ TWingetPackageCache }

class constructor TWingetPackageCache.Create;
begin
    FLock := TObject.Create;
end;

class destructor TWingetPackageCache.Destroy;
begin
    FreeAndNil(FNames);
    FreeAndNil(FLock);
end;

class procedure TWingetPackageCache.CollectView(RootKey: HKEY; View: Cardinal;
    List: TStringList);
var
    Reg: TRegistry;
    KeyNames: TStringList;
    Sub, DisplayName: string;
begin
    Reg := TRegistry.Create(KEY_READ or View);
    KeyNames := TStringList.Create;
    try
        Reg.RootKey := RootKey;
        if not Reg.OpenKeyReadOnly(UNINSTALL_KEY) then
            Exit;
        try
            Reg.GetKeyNames(KeyNames);
        finally
            Reg.CloseKey;
        end;

        for Sub in KeyNames do
        begin
            if not Reg.OpenKeyReadOnly(UNINSTALL_KEY + '\' + Sub) then
                Continue;
            try
                if Reg.ValueExists('DisplayName') then
                begin
                    DisplayName := Trim(Reg.ReadString('DisplayName'));
                    if DisplayName <> '' then
                        List.Add(DisplayName);
                end;
            finally
                Reg.CloseKey;
            end;
        end;
    finally
        KeyNames.Free;
        Reg.Free;
    end;
end;

class procedure TWingetPackageCache.CollectInto(List: TStringList);
begin
    CollectView(HKEY_LOCAL_MACHINE, KEY_WOW64_64KEY, List);
    CollectView(HKEY_LOCAL_MACHINE, KEY_WOW64_32KEY, List);
    CollectView(HKEY_CURRENT_USER, 0, List);
    List.Sort;
end;

class function TWingetPackageCache.GetNames: TStringList;
var
    CurTime: TDateTime;
begin
    TMonitor.Enter(FLock);
    try
        CurTime := Now;
        if (not Assigned(FNames)) or
           (FCollectedAt = 0) or (MilliSecondsBetween(CurTime, FCollectedAt) > CACHE_LIFETIME_MS) then
        begin
            FreeAndNil(FNames);
            FNames := TStringList.Create;
            FNames.Sorted := True;
            FNames.Duplicates := dupIgnore;
            try
                CollectInto(FNames);
            except
                // при сбое реестра отдаём пустой список вместо исключения
                on E: Exception do
                begin
                    LogException('WingetPackageCache.Collect', E);
                    FreeAndNil(FNames);
                    FNames := TStringList.Create;
                end;
            end;
            FCollectedAt := CurTime;
        end;
        Result := FNames;
    finally
        TMonitor.Exit(FLock);
    end;
end;

initialization
    EnsureGitFlagLists;

finalization
    FreeAndNil(GitCommitFlags);
    FreeAndNil(GitPushFlags);
    FreeAndNil(GitAddFlags);

end.
