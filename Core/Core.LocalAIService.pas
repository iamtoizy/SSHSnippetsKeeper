unit Core.LocalAIService;

interface

uses
    Core.Interfaces.Tools,
    PythonEngine,
    System.Classes,
    System.IOUtils,
    System.SysUtils,
    VarPyth
    ;

type
    TLocalAIService = class(TInterfacedObject, ILocalAIService)
    private
        FEngine: TPythonEngine;
        FIsLoaded: Boolean;
        FOwnsEngine: Boolean;
    public
        constructor Create(Engine: TPythonEngine = nil);
        destructor Destroy; override;

        function LoadModel(const GgufPath: string): Boolean;
        function IsModelLoaded: Boolean;
        function Ask(const SystemPrompt, UserPrompt: string): string;
        function IsPythonAvailable: Boolean;
        function IsLlamaModuleInstalled: Boolean;
        function InstallLlamaModule(out Log: string): Boolean;
    end;

implementation

uses
    Common.Helpers,
    Common.Localization
    ;

constructor TLocalAIService.Create(Engine: TPythonEngine);
begin
    inherited Create;
    FIsLoaded := False;

    if Assigned(Engine) then
    begin
        FEngine := Engine;
        FOwnsEngine := False;
    end
    else
    begin
        FEngine := TPythonEngine.Create(nil);
        FOwnsEngine := True;

        // Отключаем жесткую привязку
        FEngine.AutoLoad := False;
        FEngine.FatalAbort := False; // Не убивать программу при ошибках

        // Включаем умный поиск в реестре (HKLM и HKCU)
        FEngine.UseLastKnownVersion := True;

        // Опционально: можно ограничить минимальную версию, например 3.8
        // FEngine.RegVersion := '3.8';

        try
            FEngine.LoadDll; // P4D сам найдет самую свежую версию DLL в системе
        except
            on E: Exception do
                LogException('TLocalAIService.LoadDll', E);
        end;
    end;
end;

destructor TLocalAIService.Destroy;
begin
    if FOwnsEngine and Assigned(FEngine) then
        FEngine.Free;
    inherited Destroy;
end;

function TLocalAIService.InstallLlamaModule(out Log: string): Boolean;
var
    PySys: Variant;
    PythonExePath, Command: string;
begin
    Result := False;
    Log := '';
    if not IsPythonAvailable then Exit;

    try
        // 1. Узнаем у Python путь к его родному python.exe
        FEngine.ExecString('import sys');
        PySys := Import('sys');
        PythonExePath := PySys.executable;

        // 2. Формируем команду для корпоративного pip
        // Флаг -m pip гарантирует, что pip вызовется именно для этой версии Python
        Command := ' -m pip install llama-cpp-python';

        // 3. Вызываем процесс (используем ваш хелпер из Common.Helpers, который мы писали для Git)
        // Для этого нужно будет немного адаптировать функцию RunGitCommand в RunConsoleCommand
        Result := RunCmdCommand(ExtractFilePath(PythonExePath), '"' + PythonExePath + '"' + Command, Log);

    except
        on E: Exception do
            Log := TUIStateLoader.GetMessage('AI.PipCallError', [E.Message]);
    end;
end;

function TLocalAIService.IsLlamaModuleInstalled: Boolean;
begin
    if not IsPythonAvailable then Exit(False);
    try
        // Пытаемся импортировать библиотеку
        FEngine.ExecString('import llama_cpp');
        Result := True;
    except
        // Если падает ошибка, значит библиотеки нет
        Result := False;
    end;
end;

function TLocalAIService.IsModelLoaded: Boolean;
begin
    Result := FIsLoaded;
end;

function TLocalAIService.IsPythonAvailable: Boolean;
begin
    Result := Assigned(FEngine) and FEngine.IsHandleValid;
end;

function TLocalAIService.LoadModel(const GgufPath: string): Boolean;
var
    PyMain: Variant;
    PyResult: string;
begin
    if FIsLoaded then Exit(True);

    if not FEngine.IsHandleValid then
        raise Exception.Create(TUIStateLoader.GetMessage('AI.PythonNotFound'));

    try
        PyMain := Import('__main__');

        // --- НОВЫЙ БЛОК: Учим Python видеть папку с нашим EXE ---
        FEngine.ExecString('import sys');
        // Передаем путь к папке с программой в Python
        PyMain.app_dir := ExtractFilePath(ParamStr(0));
        // Добавляем эту папку в системный путь Python
        FEngine.ExecString('if app_dir not in sys.path: sys.path.append(app_dir)');
        // --------------------------------------------------------

        // Прокидываем путь к модели GGUF
        PyMain.model_path := GgufPath;

        // Теперь Python найдет наш local_ai.py!
        FEngine.ExecString('import local_ai');
        FEngine.ExecString('load_result = local_ai.load_model(model_path)');

        PyResult := PyMain.load_result;
        FIsLoaded := (PyResult = 'OK');
        Result := FIsLoaded;
    except
        on E: Exception do
        begin
            LogException('TLocalAIService.LoadModel', E);
            Result := False;
        end;
    end;
end;

function TLocalAIService.Ask(const SystemPrompt, UserPrompt: string): string;
var
    PyMain: Variant;
begin
    if not FIsLoaded then
        Exit(TUIStateLoader.GetMessage('AI.ModelNotLoaded'));

    try
        PyMain := Import('__main__');
        PyMain.sys_p := SystemPrompt;
        PyMain.usr_p := UserPrompt;

        FEngine.ExecString('ans = local_ai.ask_model(sys_p, usr_p)');

        Result := PyMain.ans;
    except
        on E: Exception do
            Result := TUIStateLoader.GetMessage('AI.AskCallError', [E.Message]);
    end;
end;

end.
