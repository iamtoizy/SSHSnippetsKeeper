unit UI.Services.AppStateManager;

interface

uses
    BaseFormUI
    ;

type
    TStateMgr = class
    private
        FConnected: Boolean;
        FState: TBaseFormState;
        procedure ChangeState(const State: TBaseFormState);
    protected
        constructor Create; // ������� �����������
    public
        destructor Destroy; override;

        // �������� ����� �������
        class function Instance: TStateMgr; static;

        procedure FirstRun;
        procedure CreateDatabase;
        procedure OpenDatabase;
        procedure CloseDatabase;

        property State: TBaseFormState read FState;
    end;

implementation

uses
    Vcl.Forms
    ;

var
    GStateMgrInstance: TStateMgr = nil; // ��������

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
    if GStateMgrInstance = nil then
        GStateMgrInstance := TStateMgr.Create;
    Result := GStateMgrInstance;
end;

procedure TStateMgr.ChangeState(const State: TBaseFormState);
begin
    if FState <> State then
    begin
        FState := State;

        // ��������� ��� �������� �����, ������������� �� TBaseForm
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

// ����� - ��������� �������� ������ ��� ������ ������ Instance

finalization

GStateMgrInstance.Free;
GStateMgrInstance := nil; // �� ������ ������

end.
