unit Tests.HotkeyService;

interface

uses
    DUnitX.TestFramework,
    Core.Interfaces.Settings, Core.Interfaces.Services,
    HotkeyService
    ;

type
    [TestFixture]
    THotkeyServiceTests = class(TObject)
    private
        function NewService: THotkeyService;
    public
        [Test]
        procedure Constructor_RunsRegistryValidation;
        [Test]
        procedure KnownAction_HasDefaultShortCut;
        [Test]
        procedure SnippetMenuActions_RegisteredWithDefaults;
        [Test]
        procedure UnknownAction_ReturnsZeroShortCut;
        [Test]
        procedure Conflict_DetectedWithinSameForm;
        [Test]
        procedure NoConflict_AcrossForms;
        [Test]
        procedure SaveToSettings_EmptyByDefault;
        [Test]
        procedure LoadFromSettings_AppliesOverrideAndSavesDiffOnly;
    end;

implementation

uses
    System.SysUtils, Vcl.Menus
    ;

{ THotkeyServiceTests }

function THotkeyServiceTests.NewService: THotkeyService;
begin
    Result := THotkeyService.Create;
end;

procedure THotkeyServiceTests.Constructor_RunsRegistryValidation;
var
    Svc: THotkeyService;
begin
    Svc := NewService;
    try
        Assert.IsNotNull(Svc);
    finally
        Svc.Free;
    end;
end;

procedure THotkeyServiceTests.KnownAction_HasDefaultShortCut;
var
    Svc: THotkeyService;
begin
    Svc := NewService;
    try
        Assert.IsTrue(Svc.GetActionShortCut('TMainForm.actAddSnippet') <> 0);
    finally
        Svc.Free;
    end;
end;

procedure THotkeyServiceTests.SnippetMenuActions_RegisteredWithDefaults;
var
    Svc: THotkeyService;
begin
    Svc := NewService;
    try
        Assert.AreEqual(Integer(TextToShortCut('Ctrl+R')),
            Integer(Svc.GetActionShortCut('TMainForm.actRunSnippet')));
        Assert.AreEqual(Integer(TextToShortCut('Ctrl+P')),
            Integer(Svc.GetActionShortCut('TMainForm.actDryRunSnippet')));
        Assert.AreEqual(Integer(TextToShortCut('Ctrl+Shift+R')),
            Integer(Svc.GetActionShortCut('TMainForm.actRunSequence')));
        Assert.AreEqual(Integer(TextToShortCut('Ctrl+Alt+C')),
            Integer(Svc.GetActionShortCut('TMainForm.actChainCreateFromSnippet')));
        Assert.AreEqual(Integer(TextToShortCut('Ctrl+H')),
            Integer(Svc.GetActionShortCut('TMainForm.actSnippetHistory')));
        Assert.AreEqual(Integer(TextToShortCut('Ctrl+Alt+T')),
            Integer(Svc.GetActionShortCut('TMainForm.actAddTagToSnippets')));
        Assert.AreEqual(Integer(TextToShortCut('Ctrl+Alt+R')),
            Integer(Svc.GetActionShortCut('TMainForm.actRemoveTagFromSnippets')));
        Assert.AreEqual(Integer(TextToShortCut('Ctrl+Alt+M')),
            Integer(Svc.GetActionShortCut('TMainForm.actMoveToCategory')));
        Assert.AreEqual(Integer(TextToShortCut('Ctrl+E')),
            Integer(Svc.GetActionShortCut('TMainForm.actExportSnippets')));
    finally
        Svc.Free;
    end;
end;

procedure THotkeyServiceTests.UnknownAction_ReturnsZeroShortCut;
var
    Svc: THotkeyService;
begin
    Svc := NewService;
    try
        Assert.AreEqual(Integer(0), Integer(Svc.GetActionShortCut('TNoSuchForm.actNope')));
    finally
        Svc.Free;
    end;
end;

procedure THotkeyServiceTests.Conflict_DetectedWithinSameForm;
var
    Svc: THotkeyService;
    ConflictingName: string;
begin
    Svc := NewService;
    try
        Assert.IsTrue(Svc.IsShortCutInUse(
            'TMainForm.actDeleteSnippet',
            Svc.GetActionShortCut('TMainForm.actAddSnippet'),
            ConflictingName));
        Assert.IsNotEmpty(ConflictingName);
    finally
        Svc.Free;
    end;
end;

procedure THotkeyServiceTests.NoConflict_AcrossForms;
var
    Svc: THotkeyService;
    ConflictingName: string;
begin
    Svc := NewService;
    try
        Assert.IsFalse(Svc.IsShortCutInUse(
            'TMainForm.actSettings',
            Svc.GetActionShortCut('TAddEditSnippetForm.actShowAIForm'),
            ConflictingName));
    finally
        Svc.Free;
    end;
end;

procedure THotkeyServiceTests.SaveToSettings_EmptyByDefault;
var
    Svc: THotkeyService;
begin
    Svc := NewService;
    try
        Assert.AreEqual(0, Integer(Length(Svc.SaveToSettings)));
    finally
        Svc.Free;
    end;
end;

procedure THotkeyServiceTests.LoadFromSettings_AppliesOverrideAndSavesDiffOnly;
var
    Svc: THotkeyService;
    OverrideSC: TCustomShortCut;
    Saved: TArray<TCustomShortCut>;
begin
    Svc := NewService;
    try
        OverrideSC.ActionName := 'TMainForm.actAddSnippet';
        OverrideSC.ShortCutValue := TextToShortCut('Ctrl+Alt+X');
        Svc.LoadFromSettings([OverrideSC]);
        Assert.AreEqual(Integer(TextToShortCut('Ctrl+Alt+X')),
            Integer(Svc.GetActionShortCut('TMainForm.actAddSnippet')));
        Saved := Svc.SaveToSettings;
        Assert.AreEqual(1, Integer(Length(Saved)));
        Assert.AreEqual('TMainForm.actAddSnippet', Saved[0].ActionName);
    finally
        Svc.Free;
    end;
end;

end.
