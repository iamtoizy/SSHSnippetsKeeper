unit HotkeyService;

interface

uses
    Core.Interfaces.Settings, Core.Interfaces.Services,
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
{$IFDEF DEBUG}
        procedure ValidateDefaultRegistry;
        procedure ValidateLocalizationKeys;
        procedure ValidateCurrentShortCuts;
{$ENDIF}
    public
        constructor Create;
        destructor Destroy; override;

        function GetAllActions: TArray<TActionHotkeyInfo>;
        function GetActionShortCut(const ActionName: string): TShortCut;
        procedure SetActionShortCut(const ActionName: string; NewShortCut: TShortCut);

        function IsShortCutInUse(const ActionID: string; ShortCut: TShortCut; out ConflictingActionName: string): Boolean;

        class function ShortCutInUseIn(const ActionID: string; ShortCut: TShortCut; const Actions: TArray<TActionHotkeyInfo>; out ConflictingActionName: string): Boolean; static;

        procedure ApplySettingsToForm(const Form: TComponent);
        procedure LoadFromSettings(const CustomShortCuts: TArray<TCustomShortCut>);
        function SaveToSettings: TArray<TCustomShortCut>;
    end;

implementation

uses
    Winapi.Windows
{$IFDEF DEBUG}
    , Common.Localization
{$ENDIF}
    ;

constructor THotkeyService.Create;
begin
    inherited Create;
    FRegistry := TDictionary<string, TActionHotkeyInfo>.Create;
    InitDefaultRegistry;
{$IFDEF DEBUG}
    ValidateDefaultRegistry;
{$ENDIF}
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
    RegisterAction('TMainForm.actSyncDatabase',  'Actions.MainForm.Database.SyncDatabase',  'Actions.MainForm.Database.Caption', 'Ctrl+Alt+Shift+E');

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

    // --- БЛОК ИЗБРАННОГО ---
    RegisterAction('TMainForm.actToggleFavorite', 'Actions.MainForm.Favorites.Toggle',   'Actions.MainForm.Favorites.Caption', 'Ctrl+Alt+F');
    RegisterAction('TMainForm.actFavMoveTop',     'Actions.MainForm.Favorites.MoveTop',  'Actions.MainForm.Favorites.Caption', 'Ctrl+Alt+Home');
    RegisterAction('TMainForm.actFavMoveUp',      'Actions.MainForm.Favorites.MoveUp',   'Actions.MainForm.Favorites.Caption', 'Ctrl+Alt+Up');
    RegisterAction('TMainForm.actFavMoveDown',    'Actions.MainForm.Favorites.MoveDown', 'Actions.MainForm.Favorites.Caption', 'Ctrl+Alt+Down');
    RegisterAction('TMainForm.actFavMoveEnd',     'Actions.MainForm.Favorites.MoveEnd',  'Actions.MainForm.Favorites.Caption', 'Ctrl+Alt+End');
    RegisterAction('TMainForm.actFavSlot1', 'Actions.MainForm.Favorites.Slot1', 'Actions.MainForm.Favorites.Caption', 'Alt+1');
    RegisterAction('TMainForm.actFavSlot2', 'Actions.MainForm.Favorites.Slot2', 'Actions.MainForm.Favorites.Caption', 'Alt+2');
    RegisterAction('TMainForm.actFavSlot3', 'Actions.MainForm.Favorites.Slot3', 'Actions.MainForm.Favorites.Caption', 'Alt+3');
    RegisterAction('TMainForm.actFavSlot4', 'Actions.MainForm.Favorites.Slot4', 'Actions.MainForm.Favorites.Caption', 'Alt+4');
    RegisterAction('TMainForm.actFavSlot5', 'Actions.MainForm.Favorites.Slot5', 'Actions.MainForm.Favorites.Caption', 'Alt+5');
    RegisterAction('TMainForm.actFavSlot6', 'Actions.MainForm.Favorites.Slot6', 'Actions.MainForm.Favorites.Caption', 'Alt+6');
    RegisterAction('TMainForm.actFavSlot7', 'Actions.MainForm.Favorites.Slot7', 'Actions.MainForm.Favorites.Caption', 'Alt+7');
    RegisterAction('TMainForm.actFavSlot8', 'Actions.MainForm.Favorites.Slot8', 'Actions.MainForm.Favorites.Caption', 'Alt+8');
    RegisterAction('TMainForm.actFavSlot9', 'Actions.MainForm.Favorites.Slot9', 'Actions.MainForm.Favorites.Caption', 'Alt+9');
    RegisterAction('TMainForm.actFavSlot0', 'Actions.MainForm.Favorites.Slot0', 'Actions.MainForm.Favorites.Caption', 'Alt+0');

    // --- БЛОК МЕНЮ СНИППЕТА (Контекстное меню списка сниппетов) ---
    RegisterAction('TMainForm.actRunSnippet',            'Actions.MainForm.SnippetMenu.RunSnippet',            'Actions.MainForm.SnippetMenu.Caption', 'Ctrl+R');
    RegisterAction('TMainForm.actDryRunSnippet',         'Actions.MainForm.SnippetMenu.DryRunSnippet',         'Actions.MainForm.SnippetMenu.Caption', 'Ctrl+P');
    RegisterAction('TMainForm.actRunSequence',           'Actions.MainForm.SnippetMenu.RunSequence',           'Actions.MainForm.SnippetMenu.Caption', 'Ctrl+Shift+R');
    RegisterAction('TMainForm.actChainCreateFromSnippet','Actions.MainForm.SnippetMenu.ChainCreateFromSnippet','Actions.MainForm.SnippetMenu.Caption', 'Ctrl+Alt+C');
    RegisterAction('TMainForm.actSnippetHistory',        'Actions.MainForm.SnippetMenu.SnippetHistory',        'Actions.MainForm.SnippetMenu.Caption', 'Ctrl+H');
    RegisterAction('TMainForm.actAddTagToSnippets',      'Actions.MainForm.SnippetMenu.AddTagToSnippets',      'Actions.MainForm.SnippetMenu.Caption', 'Ctrl+Alt+T');
    RegisterAction('TMainForm.actRemoveTagFromSnippets', 'Actions.MainForm.SnippetMenu.RemoveTagFromSnippets', 'Actions.MainForm.SnippetMenu.Caption', 'Ctrl+Alt+R');
    RegisterAction('TMainForm.actMoveToCategory',        'Actions.MainForm.SnippetMenu.MoveToCategory',        'Actions.MainForm.SnippetMenu.Caption', 'Ctrl+Alt+M');
    RegisterAction('TMainForm.actExportSnippets',        'Actions.MainForm.SnippetMenu.ExportSnippets',        'Actions.MainForm.SnippetMenu.Caption', 'Ctrl+E');
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
    RegisterAction('TTagEditorForm.actAddTag',    'Actions.TagEditor.actAddTag',    'Actions.TagEditor.Caption', 'Ctrl+A');
    RegisterAction('TTagEditorForm.actDeleteTag', 'Actions.TagEditor.actDeleteTag', 'Actions.TagEditor.Caption', 'Ctrl+D');
    RegisterAction('TTagEditorForm.actEditTag',   'Actions.TagEditor.actEditTag',   'Actions.TagEditor.Caption', 'Ctrl+E');
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
{$IFDEF DEBUG}
    ValidateLocalizationKeys;
{$ENDIF}
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

{$IFDEF DEBUG}
    ValidateCurrentShortCuts;
{$ENDIF}
end;

class function THotkeyService.ShortCutInUseIn(const ActionID: string; ShortCut: TShortCut; const Actions: TArray<TActionHotkeyInfo>; out ConflictingActionName: string): Boolean;
var
    Info: TActionHotkeyInfo;
    TargetFormClass: string;
    CurrentFormClass: string;
begin
    Result := False;
    ConflictingActionName := '';
    if ShortCut = 0 then
        Exit;

    TargetFormClass := ActionID.Split(['.'])[0];

    for Info in Actions do
    begin
        if Info.CurrentShortCut = ShortCut then
        begin
            CurrentFormClass := Info.ActionName.Split(['.'])[0];

            if SameText(TargetFormClass, CurrentFormClass) then
            begin
                ConflictingActionName := Info.DisplayName;
                Exit(True);
            end;
        end;
    end;
end;

function THotkeyService.IsShortCutInUse(const ActionID: string; ShortCut: TShortCut; out ConflictingActionName: string): Boolean;
begin
    Result := ShortCutInUseIn(ActionID, ShortCut, FRegistry.Values.ToArray, ConflictingActionName);
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

{$IFDEF DEBUG}
    ValidateCurrentShortCuts;
{$ENDIF}
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
                    end;
                end;
            end;
        end;
    end;
end;

{$IFDEF DEBUG}
procedure THotkeyService.ValidateDefaultRegistry;
var
    Info: TActionHotkeyInfo;
    Parts: TArray<string>;
    ComboOwners: TDictionary<string, string>;
    Combo: string;
begin
    ComboOwners := TDictionary<string, string>.Create;
    try
        for Info in FRegistry.Values do
        begin
            Parts := Info.ActionName.Split(['.']);
            if (Length(Parts) < 2) or (not Parts[0].StartsWith('T')) then
                raise Exception.Create('THotkeyService: invalid action ID "' + Info.ActionName + '" (expected "TFormClass.actName")');
            if Info.DefaultShortCut = 0 then
                raise Exception.Create('THotkeyService: DefaultShortCut parse failed for "' + Info.ActionName + '"');
            if Info.DisplayName.IsEmpty or Info.Category.IsEmpty then
                raise Exception.Create('THotkeyService: empty DisplayName/Category for "' + Info.ActionName + '"');
            Combo := Parts[0] + '|' + IntToStr(Ord(Info.DefaultShortCut));
            if ComboOwners.ContainsKey(Combo) then
                raise Exception.Create('THotkeyService: duplicate default shortcut in ' + Parts[0] + ': "' + ComboOwners[Combo] + '" and "' + Info.ActionName + '"');
            ComboOwners.Add(Combo, Info.ActionName);
        end;
    finally
        ComboOwners.Free;
    end;
end;

procedure THotkeyService.ValidateLocalizationKeys;
var
    Info: TActionHotkeyInfo;
begin
    for Info in FRegistry.Values do
    begin
        if TUIStateLoader.GetMessage(Info.DisplayName).StartsWith('[') then
            raise Exception.Create('THotkeyService: missing localization key "' + Info.DisplayName + '" for "' + Info.ActionName + '"');
        if TUIStateLoader.GetMessage(Info.Category).StartsWith('[') then
            raise Exception.Create('THotkeyService: missing localization key "' + Info.Category + '" for "' + Info.ActionName + '"');
    end;
end;

// Валидация реестра после мутаций (LoadFromSettings/SetActionShortCut):
// битовый состав TShortCut и уникальность хоткеев в рамках одной формы
procedure THotkeyService.ValidateCurrentShortCuts;
const
    SC_KEY_MASK = $00FF;
    SC_FLAG_MASK = SC_KEY_MASK or scShift or scCtrl or scAlt; // $E0FF: Key + scShift($2000)/scCtrl($4000)/scAlt($8000)
var
    Info: TActionHotkeyInfo;
    Parts: TArray<string>;
    ComboOwners: TDictionary<string, string>;
    Combo: string;
    SC: Word;
begin
    ComboOwners := TDictionary<string, string>.Create;
    try
        for Info in FRegistry.Values do
        begin
            SC := Info.CurrentShortCut;
            if SC = 0 then
                Continue;
            if (SC and SC_KEY_MASK) = 0 then
                raise Exception.Create('THotkeyService: shortcut without key for "' + Info.ActionName + '"');
            if (SC and (not SC_FLAG_MASK)) <> 0 then
                raise Exception.Create('THotkeyService: unknown flag bits in shortcut for "' + Info.ActionName + '"');
            Parts := Info.ActionName.Split(['.']);
            if Length(Parts) = 0 then
                raise Exception.Create('THotkeyService: invalid action ID "' + Info.ActionName + '"');
            Combo := Parts[0] + '|' + IntToStr(SC);
            if ComboOwners.ContainsKey(Combo) then
                raise Exception.Create('THotkeyService: duplicate shortcut in ' + Parts[0] + ': "' + ComboOwners[Combo] + '" and "' + Info.ActionName + '"');
            ComboOwners.Add(Combo, Info.ActionName);
        end;
    finally
        ComboOwners.Free;
    end;
end;
{$ENDIF}

end.

