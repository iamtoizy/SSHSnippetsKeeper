unit Tests.WindowHelper;

interface

uses
    DUnitX.TestFramework,
    Core.Interfaces.Settings,
    MacroInputTypes,
    System.Classes,
    System.SyncObjs,
    System.SysUtils,
    Winapi.Windows,
    WindowHelper
    ;

type
    TWinStubSettings = class(TInterfacedObject, ISettingsManager)
    private
        FBash: TStringList;
        function GetSettings: TAppSettings;
        procedure SetSettings(const Value: TAppSettings);
        function GetCurrentLanguage: string;
        procedure SetCurrentLanguage(const Value: string);
        function GetBashAutocomplete: TStringList;
    public
        Data: TAppSettings;
        constructor Create;
        destructor Destroy; override;
        procedure Load;
        procedure Save;
    end;

    TMacroFreeFlag = class
    public
        Value: Integer;
    end;

    TRecordingContext = class(TMacroContext)
    public
        FreeFlag: TMacroFreeFlag;
        destructor Destroy; override;
    end;

    [TestFixture]
    TWindowHelperTests = class(TObject)
    private
        FSettings: TWinStubSettings;
        FHelper: TWindowHelper;
        FFocusLost: Integer;
        class function WaitFor(const ACheck: TFunc<Boolean>; ATimeoutMs: Cardinal): Boolean; static;
    public
        [Setup]
        procedure Setup;
        [TearDown]
        procedure TearDown;

        [Test]
        procedure InitialState_Idle_NoTarget;
        [Test]
        procedure EstimateTypingMs_MeasuresTokensFromSettings;
        [Test]
        procedure EstimateTypingMs_ReflectsRefreshedSettings;
        [Test]
        procedure FindUnknownCommands_ReportsOnlyUnknown;
        [Test]
        procedure CancelTyping_StopsRunningSleepMacro;
        [Test]
        procedure ReplaceActiveMacro_OldThreadStopped;
        [Test]
        procedure FocusLoss_AbortsBeforeFirstKeystroke;
        [Test]
        procedure EmptyText_FreesContextWithoutThread;
        [Test]
        procedure Shutdown_Idle_Safe;
    end;

implementation

{ TWinStubSettings }

constructor TWinStubSettings.Create;
begin
    inherited Create;
    FBash := TStringList.Create;
end;

destructor TWinStubSettings.Destroy;
begin
    FBash.Free;
    inherited;
end;

function TWinStubSettings.GetSettings: TAppSettings;
begin
    Result := Data;
end;

procedure TWinStubSettings.SetSettings(const Value: TAppSettings);
begin
    Data := Value;
end;

function TWinStubSettings.GetCurrentLanguage: string;
begin
    Result := Data.CurrentLanguage;
end;

procedure TWinStubSettings.SetCurrentLanguage(const Value: string);
begin
    Data.CurrentLanguage := Value;
end;

function TWinStubSettings.GetBashAutocomplete: TStringList;
begin
    Result := FBash;
end;

procedure TWinStubSettings.Load;
begin
end;

procedure TWinStubSettings.Save;
begin
end;

{ TRecordingContext }

destructor TRecordingContext.Destroy;
begin
    if Assigned(FreeFlag) then
        TInterlocked.Increment(FreeFlag.Value);
    inherited;
end;

{ TWindowHelperTests }

procedure TWindowHelperTests.Setup;
begin
    FSettings := TWinStubSettings.Create;
    FSettings.Data := Default(TAppSettings);
    FSettings.Data.WindowHelper.KeyPressInterval := 10;
    FSettings.Data.WindowHelper.ActivationDelay := 100;
    FSettings.Data.WindowHelper.SetFocusDelay := 50;
    FHelper := TWindowHelper.Create(FSettings);
end;

procedure TWindowHelperTests.TearDown;
begin
    FreeAndNil(FHelper);
    FSettings := nil;
end;

class function TWindowHelperTests.WaitFor(const ACheck: TFunc<Boolean>;
    ATimeoutMs: Cardinal): Boolean;
var
    StartTick: Cardinal;
begin
    StartTick := GetTickCount;
    repeat
        if ACheck() then
            Exit(True);
        Sleep(15);
    until (GetTickCount - StartTick) > ATimeoutMs;
    Result := False;
end;

procedure TWindowHelperTests.InitialState_Idle_NoTarget;
begin
    Assert.IsFalse(FHelper.IsTypingBusy);
    Assert.IsTrue(FHelper.GetWindowInfo.Handle = 0);
end;

procedure TWindowHelperTests.EstimateTypingMs_MeasuresTokensFromSettings;
begin
    // Текстовый токен: Len*KeyPressInterval + ActivationDelay + SetFocusDelay
    Assert.AreEqual(170, FHelper.EstimateTypingMs('AB'));
    Assert.AreEqual(500, FHelper.EstimateTypingMs('{SLEEP 500}'));
    // Сон + хвостовой текстовый токен 'X' (1*10 + 100 + 50)
    Assert.AreEqual(660, FHelper.EstimateTypingMs('{SLEEP 500}X'));
end;

procedure TWindowHelperTests.EstimateTypingMs_ReflectsRefreshedSettings;
begin
    FHelper.TypeTextIntoWindow('{SLEEP 30}');
    Assert.IsTrue(WaitFor(function: Boolean
        begin
            Result := not FHelper.IsTypingBusy;
        end, 2000));

    FSettings.Data.WindowHelper.KeyPressInterval := 25;
    FHelper.TypeTextIntoWindow('{SLEEP 30}');
    Assert.IsTrue(WaitFor(function: Boolean
        begin
            Result := not FHelper.IsTypingBusy;
        end, 2000));

    // 2*25 + 100 + 50: настройки перечитаны из менеджера при старте макроса
    Assert.AreEqual(200, FHelper.EstimateTypingMs('AB'));
end;

procedure TWindowHelperTests.FindUnknownCommands_ReportsOnlyUnknown;
var
    Unknown: TArray<string>;
begin
    Assert.AreEqual(0, Integer(Length(FHelper.FindUnknownCommands(''))));
    Assert.AreEqual(0, Integer(Length(FHelper.FindUnknownCommands('echo hi {SLEEP 50} {CLEAR_LINE}'))));

    Unknown := FHelper.FindUnknownCommands('{WRONG_CMD} ok');
    Assert.AreEqual(1, Integer(Length(Unknown)));
    Assert.IsTrue(Unknown[0].Contains('WRONG_CMD'));
end;

procedure TWindowHelperTests.CancelTyping_StopsRunningSleepMacro;
begin
    FHelper.TypeTextIntoWindow('{SLEEP 5000}');
    Assert.IsTrue(FHelper.IsTypingBusy);

    FHelper.CancelTyping;
    Assert.IsTrue(WaitFor(function: Boolean
        begin
            Result := not FHelper.IsTypingBusy;
        end, 2000));
end;

procedure TWindowHelperTests.ReplaceActiveMacro_OldThreadStopped;
begin
    FHelper.TypeTextIntoWindow('{SLEEP 5000}');
    Assert.IsTrue(FHelper.IsTypingBusy);

    // Второй старт гасит предыдущий поток через StopActiveThread
    FHelper.TypeTextIntoWindow('{SLEEP 100}');
    Assert.IsTrue(WaitFor(function: Boolean
        begin
            Result := not FHelper.IsTypingBusy;
        end, 2500));
end;

procedure TWindowHelperTests.FocusLoss_AbortsBeforeFirstKeystroke;
var
    Flag: TMacroFreeFlag;
    Ctx: TRecordingContext;
    Wnd: HWND;
begin
    FSettings.Data.WindowHelper.ActivationDelay := 0;
    FSettings.Data.WindowHelper.SetFocusDelay := 0;
    FFocusLost := 0;
    Flag := TMacroFreeFlag.Create;
    try
        Wnd := CreateWindowEx(0, 'STATIC', '', 0, 0, 0, 0, 0, 0, 0, HInstance, nil);
        Assert.IsTrue(Wnd <> 0);

        FHelper.SetTargetWindow(Wnd);
        DestroyWindow(Wnd);

        Ctx := TRecordingContext.Create;
        Ctx.FreeFlag := Flag;
        Ctx.OnFocusLost :=
            procedure
            begin
                TInterlocked.Increment(FFocusLost);
            end;

        // Целевое окно уничтожено: TypeRawText обязан прерваться до печати
        FHelper.TypeTextIntoWindowWithContext('AB', Ctx);

        Assert.IsTrue(WaitFor(function: Boolean
            begin
                Result := not FHelper.IsTypingBusy;
            end, 2000));
        Assert.AreEqual(1, FFocusLost);
        Assert.AreEqual(1, Flag.Value);
    finally
        Flag.Free;
    end;
end;

procedure TWindowHelperTests.EmptyText_FreesContextWithoutThread;
var
    Flag: TMacroFreeFlag;
    Ctx: TRecordingContext;
begin
    Flag := TMacroFreeFlag.Create;
    try
        Ctx := TRecordingContext.Create;
        Ctx.FreeFlag := Flag;

        FHelper.TypeTextIntoWindowWithContext('', Ctx);

        Assert.IsFalse(FHelper.IsTypingBusy);
        Assert.AreEqual(1, Flag.Value);
    finally
        Flag.Free;
    end;
end;

procedure TWindowHelperTests.Shutdown_Idle_Safe;
begin
    FHelper.Shutdown;
    Assert.IsFalse(FHelper.IsTypingBusy);
end;

end.
