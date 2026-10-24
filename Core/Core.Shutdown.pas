unit Core.Shutdown;

interface

uses
    WindowHelper
    ;

procedure RegisterShutdownWindowHelper(AHelper: TWindowHelper);

implementation

uses
    System.SysUtils
    ;

var
    GWindowHelper: TWindowHelper;

procedure RegisterShutdownWindowHelper(AHelper: TWindowHelper);
begin
    GWindowHelper := AHelper;
end;

initialization

finalization
    FreeAndNil(GWindowHelper);

end.
