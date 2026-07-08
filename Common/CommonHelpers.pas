unit CommonHelpers;

interface

procedure ShowSimpleToast(const Title, Text: string);

implementation

uses
    Vcl.Forms,
    System.Notification
    ;

var
    NotificationCenter: TNotificationCenter;

procedure ShowSimpleToast(const Title, Text: string);
var
    Notification: TNotification;
begin
    if NotificationCenter.Supported then
    begin
        Notification := NotificationCenter.CreateNotification;
        try
            Notification.Name := 'SnippetNotification';
            Notification.Title := Title;
            Notification.AlertBody := Text;
            NotificationCenter.PresentNotification(Notification);
        finally
            Notification.Free;
        end;
    end;
end;

initialization
    NotificationCenter := TNotificationCenter.Create(nil);

finalization
    NotificationCenter.Free;

end.
