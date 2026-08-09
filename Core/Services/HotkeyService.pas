unit HotkeyService;

interface

uses
    Core.Interfaces,
    System.Actions,
    System.Classes,
    System.Generics.Collections,
    System.SysUtils,
    Vcl.ActnList,
    Vcl.Menus
    ;

type
    THotkeyService = class(TInterfacedObject, IHotkeyService)
    private
        // Реестр всех действий в приложении
        FRegistry: TDictionary<string, TActionHotkeyInfo>;

        procedure InitDefaultRegistry;
        procedure RegisterAction(const Name, DisplayName, Category: string; Default: string);
    public
        constructor Create;
        destructor Destroy; override;

        function GetAllActions: TArray<TActionHotkeyInfo>;
        function GetActionShortCut(const ActionName: string): TShortCut;
        procedure SetActionShortCut(const ActionName: string; NewShortCut: TShortCut);

        function IsShortCutInUse(const ActionID: string; ShortCut: TShortCut; out ConflictingActionName: string): Boolean;

        procedure ApplySettingsToForm(const Form: TComponent);
        procedure LoadFromSettings(const CustomShortCuts: TArray<TCustomShortCut>);
        function SaveToSettings: TArray<TCustomShortCut>;
    end;

implementation

uses
    Winapi.Windows
    ;

constructor THotkeyService.Create;
begin
    inherited Create;
    FRegistry := TDictionary<string, TActionHotkeyInfo>.Create;
    InitDefaultRegistry;
end;

destructor THotkeyService.Destroy;
begin
    FRegistry.Free;
    inherited;
end;

procedure THotkeyService.InitDefaultRegistry;
begin
    // ID строго равен: "ИмяКлассаФормы.ИмяЭкшена"
    //
    // ID в коде (1 параметр) - КлассФормы.act...: 'TMainForm.act...'
    // Путь к тексту (2 параметр) включает группу: 'MainForm.Actions.Data.AddSnippet'
    // Путь к категории (3 параметр) указывает на Caption группы: 'MainForm.Actions.Data.Caption'
    //
    // TMainForm
    //
    // --- БЛОК ДАННЫХ (Сниппеты, Категории, Теги) ---
    RegisterAction('TMainForm.actAddSnippet',    'Actions.MainForm.Data.AddSnippet',    'Actions.MainForm.Data.Caption', 'Ctrl+Alt+A');
    RegisterAction('TMainForm.actDeleteSnippet', 'Actions.MainForm.Data.DeleteSnippet', 'Actions.MainForm.Data.Caption', 'Ctrl+Alt+D');
    RegisterAction('TMainForm.actEditSnippet',   'Actions.MainForm.Data.EditSnippet',   'Actions.MainForm.Data.Caption', 'Ctrl+Alt+E');

    RegisterAction('TMainForm.actAddCategory',    'Actions.MainForm.Data.AddCategory',    'Actions.MainForm.Data.Caption', 'Alt+A');
    RegisterAction('TMainForm.actDeleteCategory', 'Actions.MainForm.Data.DeleteCategory', 'Actions.MainForm.Data.Caption', 'Alt+D');
    RegisterAction('TMainForm.actEditCategory',   'Actions.MainForm.Data.EditCategory',   'Actions.MainForm.Data.Caption', 'Alt+E');

    RegisterAction('TMainForm.actAddTag',    'Actions.MainForm.Data.AddTag',    'Actions.MainForm.Data.Caption', 'Ctrl+Shift+A');
    RegisterAction('TMainForm.actDeleteTag', 'Actions.MainForm.Data.DeleteTag', 'Actions.MainForm.Data.Caption', 'Ctrl+Shift+D');
    RegisterAction('TMainForm.actEditTag',   'Actions.MainForm.Data.EditTag',   'Actions.MainForm.Data.Caption', 'Ctrl+Shift+E');

    // --- БЛОК БАЗЫ ДАННЫХ ---
    RegisterAction('TMainForm.actCreateDatabase', 'Actions.MainForm.Database.CreateDatabase', 'Actions.MainForm.Database.Caption', 'Ctrl+N');
    RegisterAction('TMainForm.actOpenDatabase',   'Actions.MainForm.Database.OpenDatabase',   'Actions.MainForm.Database.Caption', 'Ctrl+O');
    RegisterAction('TMainForm.actCloseDatabase',  'Actions.MainForm.Database.CloseDatabase',  'Actions.MainForm.Database.Caption', 'Ctrl+Q');
    RegisterAction('TMainForm.actSyncDatabase',  'Actions.MainForm.Database.actSyncDatabase',  'Actions.MainForm.Database.Caption', 'Ctrl+Alt+Shift+E');

    // --- БЛОК УТИЛИТ ---
    RegisterAction('TMainForm.actSearch',            'Actions.MainForm.Tools.Search',            'Actions.MainForm.Tools.Caption', 'Ctrl+Shift+S');
    RegisterAction('TMainForm.actPasswordGenerator', 'Actions.MainForm.Tools.PasswordGenerator', 'Actions.MainForm.Tools.Caption', 'Ctrl+Shift+G');
    RegisterAction('TMainForm.actCronGenerator',     'Actions.MainForm.Tools.CronGenerator',     'Actions.MainForm.Tools.Caption', 'Ctrl+Shift+C');
    RegisterAction('TMainForm.actEpochConverter',    'Actions.MainForm.Tools.EpochConverter',    'Actions.MainForm.Tools.Caption', 'Ctrl+Shift+T');
    RegisterAction('TMainForm.actNetworkCalculator', 'Actions.MainForm.Tools.NetworkCalculator', 'Actions.MainForm.Tools.Caption', 'Ctrl+Shift+I');
    RegisterAction('TMainForm.actChmodCalculator',   'Actions.MainForm.Tools.ChmodCalculator',   'Actions.MainForm.Tools.Caption', 'Ctrl+Shift+M');
    RegisterAction('TMainForm.actArchiveBuilder',    'Actions.MainForm.Tools.ArchiveBuilder',    'Actions.MainForm.Tools.Caption', 'Ctrl+Shift+Z');

    // --- ПРОЧЕЕ ---
    RegisterAction('TMainForm.actSettings', 'Actions.MainForm.Other.Settings', 'Actions.MainForm.Other.Caption', 'Ctrl+Alt+P');
    //
    // TAddEditSnippetForm
    //
    RegisterAction('TAddEditSnippetForm.actShowAIForm',  'Actions.AddEditSnippetForm.actShowAIForm',  'Actions.AddEditSnippetForm.Caption', 'Ctrl+I');
    RegisterAction('TAddEditSnippetForm.actConfigureAI', 'Actions.AddEditSnippetForm.actConfigureAI', 'Actions.AddEditSnippetForm.Caption', 'Ctrl+Alt+P');
    //
    // TAISettingsForm
    //
    RegisterAction('TAISettingsForm.actSave',           'Actions.AISettingsForm.actSave',           'Actions.AISettingsForm.Caption', 'Ctrl+S');
    RegisterAction('TAISettingsForm.actCreateProvider', 'Actions.AISettingsForm.actCreateProvider', 'Actions.AISettingsForm.Caption', 'Ctrl+N');
    RegisterAction('TAISettingsForm.actDeleteProvider', 'Actions.AISettingsForm.actDeleteProvider', 'Actions.AISettingsForm.Caption', 'Ctrl+D');
    RegisterAction('TAISettingsForm.actEditProvider',   'Actions.AISettingsForm.actEditProvider',   'Actions.AISettingsForm.Caption', 'Ctrl+E');
    RegisterAction('TAISettingsForm.actCreateModel',    'Actions.AISettingsForm.actCreateModel',    'Actions.AISettingsForm.Caption', 'Ctrl+Shift+N');
    RegisterAction('TAISettingsForm.actDeleteModel',    'Actions.AISettingsForm.actDeleteModel',    'Actions.AISettingsForm.Caption', 'Ctrl+Shift+D');
    RegisterAction('TAISettingsForm.actEditModel',      'Actions.AISettingsForm.actEditModel',      'Actions.AISettingsForm.Caption', 'Ctrl+Shift+E');
    //
    // TTagEditor
    //
    RegisterAction('TTagEditor.actAddTag',    'Actions.TagEditor.actAddTag',    'Actions.TagEditor.Caption', 'Ctrl+A');
    RegisterAction('TTagEditor.actDeleteTag', 'Actions.TagEditor.actDeleteTag', 'Actions.TagEditor.Caption', 'Ctrl+D');
    RegisterAction('TTagEditor.actEditTag',   'Actions.TagEditor.actEditTag',   'Actions.TagEditor.Caption', 'Ctrl+E');
    //
    // TWorkspaceManagerForm
    //
    RegisterAction('TWorkspaceManagerForm.actAddWorkspace',    'Actions.WorkspaceManagerForm.actAddWorkspace',    'Actions.WorkspaceManagerForm.Caption', 'Ctrl+A');
    RegisterAction('TWorkspaceManagerForm.actDeleteWorkspace', 'Actions.WorkspaceManagerForm.actDeleteWorkspace', 'Actions.WorkspaceManagerForm.Caption', 'Ctrl+D');
    RegisterAction('TWorkspaceManagerForm.actEditWorkspace',   'Actions.WorkspaceManagerForm.actEditWorkspace',   'Actions.WorkspaceManagerForm.Caption', 'Ctrl+E');

end;

procedure THotkeyService.RegisterAction(const Name, DisplayName, Category: string; Default: string);
var
    Info: TActionHotkeyInfo;
begin
    Info.ActionName := Name;
    Info.DisplayName := DisplayName;
    Info.Category := Category;
    Info.DefaultShortCut := TextToShortCut(Default);
    Info.CurrentShortCut := Info.DefaultShortCut; // Изначально текущий равен дефолтному

    FRegistry.Add(Name, Info);
end;

function THotkeyService.GetAllActions: TArray<TActionHotkeyInfo>;
begin
    Result := FRegistry.Values.ToArray;
end;

function THotkeyService.GetActionShortCut(const ActionName: string): TShortCut;
var
    Info: TActionHotkeyInfo;
begin
    if FRegistry.TryGetValue(ActionName, Info) then
        Result := Info.CurrentShortCut
    else
        Result := 0;
end;

procedure THotkeyService.SetActionShortCut(const ActionName: string; NewShortCut: TShortCut);
var
    Info: TActionHotkeyInfo;
begin
    if FRegistry.TryGetValue(ActionName, Info) then
    begin
        Info.CurrentShortCut := NewShortCut;
        FRegistry.Items[ActionName] := Info; // Обновляем в словаре
    end;
end;

function THotkeyService.IsShortCutInUse(const ActionID: string; ShortCut: TShortCut; out ConflictingActionName: string): Boolean;
var
    Info: TActionHotkeyInfo;
    TargetFormClass: string;
    CurrentFormClass: string;
begin
    Result := False;
    ConflictingActionName := '';
    if ShortCut = 0 then
        Exit;

    // Извлекаем имя формы из проверяемого ID (например, из 'TMainForm.actAdd' достаем 'TMainForm')
    TargetFormClass := ActionID.Split(['.'])[0];

    for Info in FRegistry.Values do
    begin
        // Если хоткей совпадает
        if Info.CurrentShortCut = ShortCut then
        begin
            // Извлекаем имя формы из ID текущего элемента в цикле
            CurrentFormClass := Info.ActionName.Split(['.'])[0];

            // Сравниваем: если они лежат на ОДНОЙ И ТОЙ ЖЕ ФОРМЕ, значит это конфликт!
            if SameText(TargetFormClass, CurrentFormClass) then
            begin
                ConflictingActionName := Info.DisplayName;
                Exit(True);
            end;
        end;
    end;
end;

// Загрузка настроек из JSON (накатываем поверх дефолтов)
procedure THotkeyService.LoadFromSettings(const CustomShortCuts: TArray<TCustomShortCut>);
var
    CustomSC: TCustomShortCut;
    Info: TActionHotkeyInfo;
begin
    for CustomSC in CustomShortCuts do
    begin
        if FRegistry.TryGetValue(CustomSC.ActionName, Info) then
        begin
            Info.CurrentShortCut := TShortCut(CustomSC.ShortCutValue);
            FRegistry.Items[CustomSC.ActionName] := Info;
        end;
    end;
end;

// Выгрузка только тех хоткеев, которые отличаются от дефолтных
function THotkeyService.SaveToSettings: TArray<TCustomShortCut>;
var
    Info: TActionHotkeyInfo;
    CustomList: TList<TCustomShortCut>;
    Item: TCustomShortCut;
begin
    CustomList := TList<TCustomShortCut>.Create;
    try
        for Info in FRegistry.Values do
        begin
            if Info.CurrentShortCut <> Info.DefaultShortCut then
            begin
                Item.ActionName := Info.ActionName;
                Item.ShortCutValue := Info.CurrentShortCut;
                CustomList.Add(Item);
            end;
        end;
        Result := CustomList.ToArray;
    finally
        CustomList.Free;
    end;
end;

procedure THotkeyService.ApplySettingsToForm(const Form: TComponent);
var
    I, J: Integer;
    Comp: TComponent;
    ActList: TActionList;
    Action: TCustomAction;
    GeneratedActionID: string;
    Info: TActionHotkeyInfo;
begin
    // 1. Перебираем все компоненты, брошенные на форму
    for I := 0 to Form.ComponentCount - 1 do
    begin
        Comp := Form.Components[I];

        // 2. Если нашли TActionList...
        if Comp is TActionList then
        begin
            ActList := TActionList(Comp);

            // 3. Перебираем все экшены внутри этого списка
            for J := 0 to ActList.ActionCount - 1 do
            begin
                if ActList.Actions[J] is TCustomAction then
                begin
                    Action := TCustomAction(ActList.Actions[J]);

                    // 4. Генерируем уникальный ID для текущего экшена
                    // Результат будет: "TMainForm.actAddSnippet"
                    GeneratedActionID := Form.ClassName + '.' + Action.Name;

                    // 5. Ищем этот ID в нашем реестре. Если нашли - применяем хоткей
                    if FRegistry.TryGetValue(GeneratedActionID, Info) then
                    begin
                        Action.ShortCut := Info.CurrentShortCut;
                    end
                    {$IFDEF DEBUG}
                    else
                        raise Exception.Create('Could not find action named"' + GeneratedActionID + '"');
                    {$ENDIF}
                end;
            end;
        end;
    end;
end;

end.

