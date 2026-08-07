unit AISettingsFormUI;

interface

uses
    BaseFormUI,
    Core.Interfaces,
    System.Classes,
    Vcl.ComCtrls,
    Vcl.Controls,
    Vcl.ExtCtrls,
    Vcl.Forms,
    Vcl.Menus,
    Vcl.StdCtrls,
    Winapi.Windows, System.Actions, Vcl.ActnList
    ;

type
    // Указатели типов для хранения в свойстве Data узлов TreeView
    TNodeType = (ntHub, ntModel);

    PNodeData = ^TNodeData;

    TNodeData = record
        NodeType: TNodeType;
        HubIndex: Integer;
        ModelIndex: Integer; // Равен -1, если это сам Хаб
    end;

    TAISettingsForm = class(TBaseForm)
        pnlLeft: TPanel;
        spLeft: TSplitter;
        pnlClient: TPanel;
        tvAIStructure: TTreeView;
        MainMenu: TMainMenu;
        nProvider: TMenuItem;
        nProviderCreate: TMenuItem;
        nProviderDelete: TMenuItem;
        nProviderEdit: TMenuItem;
        nModel: TMenuItem;
        nModelCreate: TMenuItem;
        nModelDelete: TMenuItem;
        nModelEdit: TMenuItem;
        pcDetails: TPageControl;
        tsHub: TTabSheet;
        tsModel: TTabSheet;
        ebHubName: TEdit;
        lbHubName: TLabel;
        ebHubURL: TEdit;
        lbHubURL: TLabel;
        mHubComment: TMemo;
        lbHubComment: TLabel;
        ebModelName: TEdit;
        ebAPIKey: TEdit;
        ebFolderID: TEdit;
        ebAgentID: TEdit;
        ebTemperature: TEdit;
        ebMaxTokens: TEdit;
        mSystemPrompt: TMemo;
        lbModelName: TLabel;
        lbAPIKey: TLabel;
        lbFolderID: TLabel;
        lbAgentID: TLabel;
        lbTemperature: TLabel;
        lbMaxTokens: TLabel;
        lbSystemPrompt: TLabel;
        nFile: TMenuItem;
        nSave: TMenuItem;
        ebModelPath: TEdit;
        lbModelPath: TLabel;
    ActionList: TActionList;
    actSave: TAction;
    actCreateProvider: TAction;
    actDeleteProvider: TAction;
    actEditProvider: TAction;
    actCreateModel: TAction;
    actDeleteModel: TAction;
    actEditModel: TAction;
        procedure actCreateModelExecute(Sender: TObject);
        procedure actCreateProviderExecute(Sender: TObject);
        procedure actDeleteModelExecute(Sender: TObject);
        procedure actDeleteProviderExecute(Sender: TObject);
        procedure actEditModelExecute(Sender: TObject);
        procedure actEditProviderExecute(Sender: TObject);
        procedure actSaveExecute(Sender: TObject);
        procedure FormDestroy(Sender: TObject);
        procedure tvAIStructureChange(Sender: TObject; Node: TTreeNode);
    private
        FLocalSettings: TAppSettings; // Локальная копия для работы без порчи основного конфига до сохранения
        procedure LoadStructureToTree;
        procedure ClearTreeData;
        procedure SaveCurrentEditorData;
        function CreateNodeData(AType: TNodeType; AHub, AModel: Integer): PNodeData;
    public
        procedure DoInitialize; override;
    end;

var
    AISettingsForm: TAISettingsForm;

implementation

uses
    System.SysUtils,
    UI.StateLoader
    ;

{$R *.dfm}

procedure TAISettingsForm.actCreateModelExecute(Sender: TObject);
var
    ActiveNode: TTreeNode;
    Data: PNodeData;
    NewModel: TAIItem;
    HubIdx: Integer;
    NewNode: TTreeNode;
begin
    ActiveNode := tvAIStructure.Selected;
    if ActiveNode = nil then Exit;

    SaveCurrentEditorData;
    Data := PNodeData(ActiveNode.Data);

    // Модель всегда добавляется в хаб (независимо от того, стоим мы на хабе или на соседней модели)
    HubIdx := Data^.HubIndex;

    NewModel := Default(TAIItem);
    NewModel.Name := TUIStateLoader.GetMessage('AISettingsForm.AddModelPrompt');
    NewModel.Params.Temperature := 0.3;
    NewModel.Params.MaxOutputTokens := 1024;

    FLocalSettings.AISettings[HubIdx].Items.Add(NewModel);

    LoadStructureToTree;

    // Находим хаб и фокусируемся на только что созданной модели внутри него
    NewNode := tvAIStructure.Items[0]; // Безопасный фоллбэк
    if HubIdx < tvAIStructure.Items.Count then
    begin
        var HubNode := tvAIStructure.Items[HubIdx];
        if HubNode.Count > 0 then
            NewNode := HubNode.Item[HubNode.Count - 1]; // Последний ребенок
    end;

    NewNode.Selected := True;
    ebModelName.SetFocus;
end;

procedure TAISettingsForm.actCreateProviderExecute(Sender: TObject);
var
    NewHub: TAIHub;
begin
    SaveCurrentEditorData; // Сохраняем то, что открыто сейчас

    NewHub := Default(TAIHub);
    NewHub.Name := TUIStateLoader.GetMessage('AISettingsForm.AddHubPrompt');
    FLocalSettings.AISettings.Add(NewHub);

    LoadStructureToTree;
    // Фокусируемся на последнем созданном хабе (корневой узел)
    tvAIStructure.Items[tvAIStructure.Items.Count - 1].Selected := True;
    ebHubName.SetFocus; // Сразу ставим фокус для переименования
end;

procedure TAISettingsForm.actDeleteModelExecute(Sender: TObject);
var
    ActiveNode: TTreeNode;
    Data: PNodeData;
begin
    ActiveNode := tvAIStructure.Selected;
    if (ActiveNode = nil) or (ActiveNode.Data = nil) then Exit;

    Data := PNodeData(ActiveNode.Data);

    // Защита: удаляем только если это Модель
    if Data^.NodeType = ntModel then
    begin
        if MessagesHandler.AskConfirmation(
            // Не забудьте добавить 'AISettingsForm.DeleteModelConfirm' в JSON!
            TUIStateLoader.GetMessage('AISettingsForm.DeleteModelConfirm'),
            TUIStateLoader.GetMessage('Common.Confirmation'),
            MB_YESNO or MB_ICONWARNING) then
        begin
            FLocalSettings.AISettings[Data^.HubIndex].Items.Delete(Data^.ModelIndex);
            LoadStructureToTree;
        end;
    end;
end;

procedure TAISettingsForm.actDeleteProviderExecute(Sender: TObject);
var
    ActiveNode: TTreeNode;
    Data: PNodeData;
begin
    ActiveNode := tvAIStructure.Selected;
    if (ActiveNode = nil) or (ActiveNode.Data = nil) then Exit;

    Data := PNodeData(ActiveNode.Data);

    // Защита: удаляем только если это Хаб
    if Data^.NodeType = ntHub then
    begin
        if MessagesHandler.AskConfirmation(
            TUIStateLoader.GetMessage('AISettingsForm.DeleteHubConfirm'),
            TUIStateLoader.GetMessage('Common.Confirmation'),
            MB_YESNO or MB_ICONWARNING) then
        begin
            FLocalSettings.AISettings.Delete(Data^.HubIndex);
            LoadStructureToTree;
        end;
    end;
end;

procedure TAISettingsForm.actEditModelExecute(Sender: TObject);
var
    Data: PNodeData;
begin
    if tvAIStructure.Selected = nil then Exit;
    Data := PNodeData(tvAIStructure.Selected.Data);

    if Data^.NodeType = ntModel then
        ebModelName.SetFocus;
end;

procedure TAISettingsForm.actEditProviderExecute(Sender: TObject);
var
    Data: PNodeData;
begin
    if tvAIStructure.Selected = nil then Exit;
    Data := PNodeData(tvAIStructure.Selected.Data);

    // Действие "Редактировать" просто переводит курсор в поле имени
    if Data^.NodeType = ntHub then
        ebHubName.SetFocus;
end;

procedure TAISettingsForm.actSaveExecute(Sender: TObject);
begin
    SaveCurrentEditorData; // Сохраняем то, что открыто в редакторе прямо сейчас

    // Переносим изменения из локальной структуры в глобальную
    AppContext.SettingsManager.Data := FLocalSettings;

    // Записываем обновленный JSON на диск
    AppContext.SettingsManager.Save;

    ModalResult := mrOk;
end;

procedure TAISettingsForm.FormDestroy(Sender: TObject);
begin
    ClearTreeData;
end;

{ TAISettingsForm }

procedure TAISettingsForm.ClearTreeData;
var
    I: Integer;
begin
    for I := 0 to tvAIStructure.Items.Count - 1 do
    begin
        if tvAIStructure.Items[I].Data <> nil then
        begin
            Dispose(PNodeData(tvAIStructure.Items[I].Data));
            tvAIStructure.Items[I].Data := nil;
        end;
    end;
end;

function TAISettingsForm.CreateNodeData(AType: TNodeType; AHub, AModel: Integer): PNodeData;
begin
    New(Result);
    Result^.NodeType := AType;
    Result^.HubIndex := AHub;
    Result^.ModelIndex := AModel;
end;

procedure TAISettingsForm.DoInitialize;
begin
    FLocalSettings := AppContext.SettingsManager.Data;
end;

procedure TAISettingsForm.LoadStructureToTree;
var
    I, J: Integer;
    HubNode, ModelNode: TTreeNode;
begin
    tvAIStructure.Items.BeginUpdate;
    try
        ClearTreeData;
        tvAIStructure.Items.Clear;

        for I := 0 to FLocalSettings.AISettings.Count - 1 do
        begin
            HubNode := tvAIStructure.Items.Add(nil, FLocalSettings.AISettings[I].Name);
            HubNode.Data := CreateNodeData(ntHub, I, -1);

            for J := 0 to FLocalSettings.AISettings[I].Items.Count - 1 do
            begin
                ModelNode := tvAIStructure.Items.AddChild(HubNode, FLocalSettings.AISettings[I].Items[J].Name);
                ModelNode.Data := CreateNodeData(ntModel, I, J);
            end;
        end;

        tvAIStructure.FullExpand; // Раскрываем все ветки, чтобы было красиво

        if tvAIStructure.Items.Count > 0 then
            tvAIStructure.Items[0].Selected := True; // Выделяем первый элемент
    finally
        tvAIStructure.Items.EndUpdate;
    end;
end;

procedure TAISettingsForm.SaveCurrentEditorData;
var
    ActiveNode: TTreeNode;
    Data: PNodeData;
    AIHub: TAIHub;
    AIItem: TAIItem;
begin
    ActiveNode := tvAIStructure.Selected;
    if (ActiveNode = nil) or (ActiveNode.Data = nil) then Exit;

    Data := PNodeData(ActiveNode.Data);

    if Data^.NodeType = ntHub then
    begin
        // КРИТИЧЕСКОЕ ИСПРАВЛЕНИЕ: Сначала копируем Хаб, чтобы не потерять его Items!
        AIHub := FLocalSettings.AISettings[Data^.HubIndex];

        AIHub.Name :=  ebHubName.Text;
        AIHub.URL :=  ebHubURL.Text;
        AIHub.Comment :=  mHubComment.Text;

        FLocalSettings.AISettings[Data^.HubIndex] := AIHub;
        ActiveNode.Text := ebHubName.Text; // Синхронизируем имя в дереве
    end
    else
    begin
        var HubIdx := Data^.HubIndex;
        var ModIdx := Data^.ModelIndex;

        // КРИТИЧЕСКОЕ ИСПРАВЛЕНИЕ: Сначала копируем Модель!
        AIItem := FLocalSettings.AISettings[HubIdx].Items[ModIdx];

        AIItem.Name := ebModelName.Text;
        AIItem.APIKey := ebAPIKey.Text;
        AIItem.Folder := ebFolderID.Text;
        AIItem.Model := ebModelPath.Text;
        AIItem.Agent := ebAgentID.Text;

        AIItem.Params.Temperature := StrToFloatDef(StringReplace(ebTemperature.Text, '.', FormatSettings.DecimalSeparator, []), 0.3);
        AIItem.Params.MaxOutputTokens := StrToIntDef(ebMaxTokens.Text, 1024);
        AIItem.Params.Content := mSystemPrompt.Text;

        FLocalSettings.AISettings[HubIdx].Items[ModIdx] := AIItem;
        ActiveNode.Text := ebModelName.Text;
    end;
end;

procedure TAISettingsForm.tvAIStructureChange(Sender: TObject; Node: TTreeNode);
var
    Data: PNodeData;
begin
    if (Node = nil) or (Node.Data = nil) then Exit;

    Data := PNodeData(Node.Data);

    if Data^.NodeType = ntHub then
    begin
        pcDetails.ActivePage := tsHub;
        ebHubName.Text := FLocalSettings.AISettings[Data^.HubIndex].Name;
        ebHubURL.Text := FLocalSettings.AISettings[Data^.HubIndex].URL;
        mHubComment.Text := FLocalSettings.AISettings[Data^.HubIndex].Comment;
    end
    else
    begin
        pcDetails.ActivePage := tsModel;
        var ModelItem := FLocalSettings.AISettings[Data^.HubIndex].Items[Data^.ModelIndex];

        ebModelName.Text := ModelItem.Name;
        ebAPIKey.Text := ModelItem.APIKey;
        ebFolderID.Text := ModelItem.Folder;
        ebModelPath.Text := ModelItem.Model;
        ebAgentID.Text := ModelItem.Agent;

        ebTemperature.Text := FloatToStr(ModelItem.Params.Temperature).Replace(FormatSettings.DecimalSeparator, '.');
        ebMaxTokens.Text := IntToStr(ModelItem.Params.MaxOutputTokens);
        mSystemPrompt.Text := ModelItem.Params.Content;
    end;
end;

end.

