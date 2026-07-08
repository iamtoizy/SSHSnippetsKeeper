unit BaseFormUI;

interface

uses
    System.Classes,
    Vcl.Forms
    ;

type
    TBaseFormState = (bfsDBConnected, bfsDBDisconnected);

    TBaseForm = class(TForm)
        procedure UpdateUI(const State: TBaseFormState); virtual;
    end;

implementation

procedure TBaseForm.UpdateUI(const State: TBaseFormState);
begin
    // Ничего не делаем
end;

end.
