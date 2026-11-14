unit Tests.CompletionProviders;

interface

uses
    DUnitX.TestFramework,
    System.Classes,
    System.SysUtils
    ;

type
    [TestFixture]
    TCompletionProvidersTests = class(TObject)
    public
        [Test]
        procedure Register_EmptyPath_Raises;
        [Test]
        procedure Register_NilFunc_Raises;
        [Test]
        procedure Fill_LanguageMustMatch;
        [Test]
        procedure Fill_PathIsPrefixOfContext;
        [Test]
        procedure Fill_LongerPath_DoesNotMatchShortContext;
        [Test]
        procedure Fill_ProviderError_DoesNotAbortOthers;
        [Test]
        procedure Builtin_GitFlagProvidersRegistered;
        [Test]
        procedure WingetCache_ReturnsCachedList;
    end;

implementation

uses
    Core.CompletionProviders,
    System.Generics.Collections
    ;

procedure TCompletionProvidersTests.Register_EmptyPath_Raises;
var
    Registry: TCompletionProviderRegistry;
begin
    Registry := TCompletionProviderRegistry.Create;
    try
        Assert.WillRaise(
            procedure
            begin
                Registry.RegisterProvider('bash', [], nil);
            end,
            EArgumentException);
    finally
        Registry.Free;
    end;
end;

procedure TCompletionProvidersTests.Register_NilFunc_Raises;
var
    Registry: TCompletionProviderRegistry;
begin
    Registry := TCompletionProviderRegistry.Create;
    try
        Assert.WillRaise(
            procedure
            begin
                Registry.RegisterProvider('bash', ['git'], nil);
            end,
            EArgumentNilException);
    finally
        Registry.Free;
    end;
end;

procedure TCompletionProvidersTests.Fill_LanguageMustMatch;
var
    Registry: TCompletionProviderRegistry;
    Items, Inserts: TStringList;
begin
    Registry := TCompletionProviderRegistry.Create;
    Items := TStringList.Create;
    Inserts := TStringList.Create;
    try
        Registry.RegisterProvider('bash', ['git', 'commit'],
            procedure(AItems, AInserts: TStrings)
            begin
                AItems.Add('--amend');
            end);

        Registry.Fill('bat', ['git', 'commit'], Items, Inserts);
        Assert.AreEqual(0, Items.Count);

        Registry.Fill('BASH', ['git', 'commit'], Items, Inserts);
        Assert.AreEqual(1, Items.Count);
        Assert.AreEqual('--amend', Items[0]);
    finally
        Inserts.Free;
        Items.Free;
        Registry.Free;
    end;
end;

procedure TCompletionProvidersTests.Fill_PathIsPrefixOfContext;
var
    Registry: TCompletionProviderRegistry;
    Items, Inserts: TStringList;
begin
    Registry := TCompletionProviderRegistry.Create;
    Items := TStringList.Create;
    Inserts := TStringList.Create;
    try
        Registry.RegisterProvider('bash', ['git', 'commit'],
            procedure(AItems, AInserts: TStrings)
            begin
                AItems.Add('--amend');
            end);

        // точное совпадение контекста
        Registry.Fill('bash', ['git', 'commit'], Items, Inserts);
        Assert.AreEqual(1, Items.Count);

        // провайдер срабатывает и на продолжении контекста
        Items.Clear;
        Registry.Fill('bash', ['git', 'commit', '-m'], Items, Inserts);
        Assert.AreEqual(1, Items.Count);

        // чужой контекст
        Items.Clear;
        Registry.Fill('bash', ['git', 'push'], Items, Inserts);
        Assert.AreEqual(0, Items.Count);
    finally
        Inserts.Free;
        Items.Free;
        Registry.Free;
    end;
end;

procedure TCompletionProvidersTests.Fill_LongerPath_DoesNotMatchShortContext;
var
    Registry: TCompletionProviderRegistry;
    Items, Inserts: TStringList;
begin
    Registry := TCompletionProviderRegistry.Create;
    Items := TStringList.Create;
    Inserts := TStringList.Create;
    try
        Registry.RegisterProvider('bash', ['git', 'commit', 'extra'],
            procedure(AItems, AInserts: TStrings)
            begin
                AItems.Add('x');
            end);

        Registry.Fill('bash', ['git', 'commit'], Items, Inserts);
        Assert.AreEqual(0, Items.Count);
    finally
        Inserts.Free;
        Items.Free;
        Registry.Free;
    end;
end;

procedure TCompletionProvidersTests.Fill_ProviderError_DoesNotAbortOthers;
var
    Registry: TCompletionProviderRegistry;
    Items, Inserts: TStringList;
begin
    Registry := TCompletionProviderRegistry.Create;
    Items := TStringList.Create;
    Inserts := TStringList.Create;
    try
        Registry.RegisterProvider('bash', ['cmd'],
            procedure(AItems, AInserts: TStrings)
            begin
                raise Exception.Create('provider boom');
            end);
        Registry.RegisterProvider('bash', ['cmd'],
            procedure(AItems, AInserts: TStrings)
            begin
                AItems.Add('after-error');
            end);

        Registry.Fill('bash', ['cmd'], Items, Inserts);
        Assert.AreEqual(1, Items.Count);
        Assert.AreEqual('after-error', Items[0]);
    finally
        Inserts.Free;
        Items.Free;
        Registry.Free;
    end;
end;

procedure TCompletionProvidersTests.Builtin_GitFlagProvidersRegistered;
var
    Registry: TCompletionProviderRegistry;
    Langs: array [0..2] of string;
    Lang: string;
    Items, Inserts: TStringList;
    HasWinget: Boolean;
    Entry: TContextProviderEntry;
begin
    // Провайдеры проверяем через Fill: git-флаги должны приходить
    // во всех секциях без загрузки JSON
    Langs[0] := 'bash';
    Langs[1] := 'bat';
    Langs[2] := 'powershell';
    Items := TStringList.Create;
    Inserts := TStringList.Create;
    Registry := TCompletionProviderRegistry.Create;
    try
        RegisterBuiltinProviders(Registry);

        for Lang in Langs do
        begin
            Items.Clear;
            Registry.Fill(Lang, ['git', 'commit'], Items, Inserts);
            Assert.IsTrue(Items.IndexOf('--amend') >= 0, Lang + ': --amend');

            Items.Clear;
            Registry.Fill(Lang, ['git', 'push'], Items, Inserts);
            Assert.IsTrue(Items.IndexOf('--force-with-lease') >= 0, Lang + ': --force-with-lease');

            Items.Clear;
            Registry.Fill(Lang, ['git', 'add'], Items, Inserts);
            Assert.IsTrue(Items.IndexOf('-A') >= 0, Lang + ': -A');

            // winget-провайдеры зарегистрированы (не вызываем: реальный реестр)
            HasWinget := False;
            for Entry in Registry.Entries do
                if (Entry.Language = Lang) and (Length(Entry.Path) = 2) and
                   (Entry.Path[0] = 'winget') and (Entry.Path[1] = 'install') then
                    HasWinget := True;
            Assert.IsTrue(HasWinget, Lang + ': winget install');
        end;
    finally
        Inserts.Free;
        Items.Free;
        Registry.Free;
    end;
end;

procedure TCompletionProvidersTests.WingetCache_ReturnsCachedList;
var
    First, Second: TStringList;
begin
    First := TWingetPackageCache.GetNames;
    Second := TWingetPackageCache.GetNames;
    Assert.AreSame(First, Second);
    Assert.IsTrue(First.Count >= 0);
end;

end.
