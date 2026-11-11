unit Tests.MacroThread;

interface

uses
    DUnitX.TestFramework,
    MacroInputTypes,
    MacroThread,
    System.SysUtils
    ;

type
    // Заглушка владельца: Detach не должен оставить поток без Executor,
    // но обязан снять саму ссылку
    TTestExecutor = class(TInterfacedObject, ITextExecutor)
    public
        procedure TypeRawText(const Text: string; Context: TMacroContext);
        procedure PressEnter(Context: TMacroContext);
        procedure PressKey(Key: Word; Modifiers: Word; Context: TMacroContext);
    end;

    [TestFixture]
    TMacroThreadTests = class(TObject)
    public
        [Test]
        procedure Detach_SeversExecutorAndCallbacks;
    end;

implementation

uses
    System.Classes,
    System.SyncObjs
    ;

{ TTestExecutor }

procedure TTestExecutor.TypeRawText(const Text: string; Context: TMacroContext);
begin
end;

procedure TTestExecutor.PressEnter(Context: TMacroContext);
begin
end;

procedure TTestExecutor.PressKey(Key: Word; Modifiers: Word; Context: TMacroContext);
begin
end;

{ TMacroThreadTests }

procedure TMacroThreadTests.Detach_SeversExecutorAndCallbacks;
var
    Context: TMacroContext;
    Executor: ITextExecutor;
    Thread: TMacroThread;
begin
    Executor := TTestExecutor.Create;
    Context := TMacroContext.Create;
    try
        Context.Executor := Executor;
        Context.SnippetID := 0;  // без записи прогона: Synchronize из потока не нужен
        Context.OnTypingFinished :=
            procedure
            begin
            end;
        Context.OnFocusLost :=
            procedure
            begin
            end;

        Thread := TMacroThread.Create([], Context, nil, True);
        try
            Thread.Detach;

            // Поток больше не может звать владельца: он освобождается
            // сразу после StopActiveThread
            Assert.IsFalse(Assigned(Context.Executor));
            Assert.IsFalse(Assigned(Context.OnTypingFinished));
            Assert.IsFalse(Assigned(Context.OnFocusLost));
            Assert.AreEqual(1, Integer(TInterlocked.Add(Context.Canceled, 0)));

            // Запускаем оторванный поток: коллбэков нет, контекст он
            // освободит сам, Synchronize не понадобится
            Thread.Start;
            Thread.WaitFor;
        finally
            Thread.Free;
        end;
    finally
        // Context освобождён потоком; здесь трогать его нельзя
    end;
end;

end.
