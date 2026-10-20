unit AISettingsFormUI;

interface

uses
    BaseFormUI,
    Core.Interfaces.App,
    Core.Interfaces.Settings,
    Core.Interfaces.UI,
    System.Actions,
    System.Classes,
    Vcl.ActnList,
    Vcl.ComCtrls,
    Vcl.Controls,
    Vcl.ExtCtrls,
    Vcl.Forms,
    Vcl.Menus,
    Vcl.StdCtrls,
    Winapi.Windows
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
        function FindHubNode(HubIdx: Integer): TTreeNode;
    public
            procedure DoInitialize; override;
        end;

var
    AISettingsForm: TAISettingsForm;

implementation

uses
    Common.Localization,
    Common.Settings,
    System.SysUtils
    ;

{$R *.dfm}

const
    SECRET_MASK = '********';

procedure TAISettingsForm.actCreateModelExecute(Sender: TObject);
var
    ActiveNode: TTreeNode;
    Data: PNodeData;
    NewModel: TAIItem;
    HubIdx: Integer;
    NewNode: TTreeNode;
    HubNode: TTreeNode;
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
    HubNode := FindHubNode(HubIdx);
    if (HubNode <> nil) and (HubNode.Count > 0) then
            NewNode := HubNode.Item[HubNode.Count - 1]; // Последний ребёнок

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

function TAISettingsForm.FindHubNode(HubIdx: Integer): TTreeNode;
var
    Node: TTreeNode;
    NodeData: PNodeData;
begin
    Result := nil;
    Node := tvAIStructure.Items.GetFirstNode;
    while Node <> nil do
    begin
        if Node.Data <> nil then
        begin
            NodeData := PNodeData(Node.Data);
            if (NodeData^.NodeType = ntHub) and (NodeData^.HubIndex = HubIdx) then
                Exit(Node);
        end;
        Node := Node.GetNextSibling;
    end;
end;

procedure TAISettingsForm.DoInitialize;
var
    I, J: Integer;
begin
    FLocalSettings := AppContext.SettingsManager.Data;

    SetLength(FLocalSettings.AISettings.Items, Length(AppContext.SettingsManager.Data.AISettings.Items));
    for I := 0 to High(AppContext.SettingsManager.Data.AISettings.Items) do
    begin
        FLocalSettings.AISettings.Items[I] := AppContext.SettingsManager.Data.AISettings.Items[I];
        SetLength(FLocalSettings.AISettings.Items[I].Items.Items, Length(AppContext.SettingsManager.Data.AISettings.Items[I].Items.Items));
        for J := 0 to High(AppContext.SettingsManager.Data.AISettings.Items[I].Items.Items) do
            FLocalSettings.AISettings.Items[I].Items.Items[J] := AppContext.SettingsManager.Data.AISettings.Items[I].Items.Items[J];
    end;

    LoadStructureToTree;
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
        // Сначала копируем Хаб, чтобы не потерять его Items
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

        // Сначала копируем Модель
        AIItem := FLocalSettings.AISettings[HubIdx].Items[ModIdx];

        AIItem.Name := ebModelName.Text;
        if ebAPIKey.Text <> SECRET_MASK then
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
        if IsProtectedSecret(ModelItem.APIKey) then
            ebAPIKey.Text := SECRET_MASK
        else
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

