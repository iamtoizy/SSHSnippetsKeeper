unit AppStateManager;

interface

uses
    Vcl.Forms,
    BaseFormUI
    ;

type
    TStateMgr = class
    private
        FConnected: Boolean;
        FState: TBaseFormState;
        procedure ChangeState(const State: TBaseFormState);
    protected
        constructor Create; // скрытый конструктор
    public
        destructor Destroy; override;

        // Основная точка доступа
        class function Instance: TStateMgr; static;

        procedure FirstRun;
        procedure CreateDatabase;
        procedure OpenDatabase;
        procedure CloseDatabase;

        property State: TBaseFormState read FState;
    end;

implementation

var
    _StateMgrInstance: TStateMgr = nil; // Синглтон

constructor TStateMgr.Create;
begin
    inherited Create;
    FConnected := False;
end;

destructor TStateMgr.Destroy;
begin
    inherited;
end;

class function TStateMgr.Instance: TStateMgr;
begin
    if _StateMgrInstance = nil then
        _StateMgrInstance := TStateMgr.Create;
    Result := _StateMgrInstance;
end;

procedure TStateMgr.ChangeState(const State: TBaseFormState);
begin
    if FState <> State then
    begin
        FState := State;

        // Обновляем все открытые формы, наследующиеся от TBaseForm
        for var i := 0 to Screen.FormCount - 1 do
            if Screen.Forms[i] is TBaseForm then
                TBaseForm(Screen.Forms[i]).UpdateUI(State);
    end;
end;

procedure TStateMgr.FirstRun;
begin
    ChangeState(bfsDBDisconnected);
end;

procedure TStateMgr.CreateDatabase;
begin
    ChangeState(bfsDBConnected);
end;

procedure TStateMgr.OpenDatabase;
begin
    ChangeState(bfsDBOpen);
end;

procedure TStateMgr.CloseDatabase;
begin
    ChangeState(bfsDBDisconnected);
end;

initialization

// Пусто - экземпляр создаётся лениво при первом вызове Instance

finalization

_StateMgrInstance.Free;
_StateMgrInstance := nil; // на всякий случай

end.
