unit AISettingsFormUI;

interface

uses
    Winapi.Windows,
    Winapi.Messages,
    System.SysUtils,
    System.Variants,
    System.Classes,
    Vcl.Graphics,
    Vcl.Controls,
    Vcl.Forms,
    Vcl.Dialogs,
    Vcl.Menus,
    Vcl.ComCtrls,
    Vcl.ExtCtrls,
    Vcl.StdCtrls,
    Core.Interfaces;

type
    // Указатели типов для хранения в свойстве Data узлов TreeView
    TNodeType = (ntHub, ntModel);

    PNodeData = ^TNodeData;

    TNodeData = record
        NodeType: TNodeType;
        HubIndex: Integer;
        ModelIndex: Integer; // Равен -1, если это сам Хаб
    end;

    TAISettingsForm = class(TForm)
        pnlLeft: TPanel;
        spLeft: TSplitter;
        pnlClient: TPanel;
        tvAIStructure: TTreeView;
        MainMenu: TMainMenu;
        N1: TMenuItem;
        N2: TMenuItem;
        N3: TMenuItem;
        N4: TMenuItem;
        N5: TMenuItem;
        N6: TMenuItem;
        N7: TMenuItem;
        N8: TMenuItem;
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
        N9: TMenuItem;
        N10: TMenuItem;
        ebModelPath: TEdit;
        lbModelPath: TLabel;
        procedure FormDestroy(Sender: TObject);
        procedure N10Click(Sender: TObject);
        procedure N2Click(Sender: TObject);
        procedure N3Click(Sender: TObject);
        procedure N6Click(Sender: TObject);
        procedure tvAIStructureChange(Sender: TObject; Node: TTreeNode);
    private
        FLocalSettings: TAppSettings; // Локальная копия для работы без порчи основного конфига до сохранения
        FSettingsManager: ISettingsManager;
        procedure LoadStructureToTree;
        procedure ClearTreeData;
        procedure SaveCurrentEditorData;
        function CreateNodeData(AType: TNodeType; AHub, AModel: Integer): PNodeData;
    public
        class function Execute(SettingsManager: ISettingsManager): Boolean;
    end;

var
    AISettingsForm: TAISettingsForm;

implementation

uses
    System.IOUtils;

{$R *.dfm}

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

class function TAISettingsForm.Execute(SettingsManager: ISettingsManager): Boolean;
var
    Form: TAISettingsForm;
begin
    Form := TAISettingsForm.Create(Application);
    try
        Form.FSettingsManager := SettingsManager;
        Form.FLocalSettings := SettingsManager.Data;
        Form.pcDetails.ActivePageIndex := 0;
        Form.LoadStructureToTree;
        Result := Form.ShowModal = mrOk;
    finally
        Form.Free;
    end;
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
        if tvAIStructure.Items.Count > 0 then
            tvAIStructure.Items[0].Focused := True;
    finally
        tvAIStructure.Items.EndUpdate;
    end;
end;

procedure TAISettingsForm.N10Click(Sender: TObject);
begin
    SaveCurrentEditorData; // Сохраняем то, что открыто в редакторе прямо сейчас

    // Переносим изменения из локальной структуры в глобальную
    FSettingsManager.Data := FLocalSettings;

    // Записываем обновленный пуленепробиваемый JSON на диск
    FSettingsManager.Save;

    ModalResult := mrOk;
end;

procedure TAISettingsForm.N2Click(Sender: TObject);
var
    NewHub: TAIHub;
begin
    SaveCurrentEditorData; // Сохраняем старое

    NewHub := Default(TAIHub);
    NewHub.Name := 'Новый провайдер ИИ';
    FLocalSettings.AISettings.Add(NewHub);

    LoadStructureToTree;
    // Фокусируемся на последнем созданном хабе
    tvAIStructure.Items[tvAIStructure.Items.Count - 1].Selected := True;
end;

procedure TAISettingsForm.N3Click(Sender: TObject);
var
    ActiveNode: TTreeNode;
    Data: PNodeData;
begin
    ActiveNode := tvAIStructure.Selected;
    if (ActiveNode = nil) or (ActiveNode.Data = nil) then
        Exit;

    Data := PNodeData(ActiveNode.Data);

    if Data^.NodeType = ntHub then
    begin
        if Application.MessageBox('Удалить провайдера и ВСЕ его модели?', 'Внимание', MB_YESNO or MB_ICONWARNING) = IDYES then
            FLocalSettings.AISettings.Delete(Data^.HubIndex);
    end
    else
    begin
        FLocalSettings.AISettings[Data^.HubIndex].Items.Delete(Data^.ModelIndex);
    end;

    LoadStructureToTree;
end;

procedure TAISettingsForm.N6Click(Sender: TObject);
var
    ActiveNode: TTreeNode;
    Data: PNodeData;
    NewModel: TAIItem;
    HubIdx: Integer;
begin
    ActiveNode := tvAIStructure.Selected;
    if ActiveNode = nil then
        Exit;

    SaveCurrentEditorData;
    Data := PNodeData(ActiveNode.Data);
    HubIdx := Data^.HubIndex; // Добавляем модель в хаб, на котором (или внутри которого) стоим

    NewModel := Default(TAIItem);
    NewModel.Name := 'Новая модель/Агент';
    NewModel.Params.Temperature := 0.3;
    NewModel.Params.MaxOutputTokens := 1024;

    FLocalSettings.AISettings[HubIdx].Items.Add(NewModel);

    LoadStructureToTree;
end;

procedure TAISettingsForm.SaveCurrentEditorData;
var
    ActiveNode: TTreeNode;
    Data: PNodeData;
    AIHub: TAIHub;
    AIItem: TAIItem;
    AIParams: TAIParams;
begin
    ActiveNode := tvAIStructure.Selected;
    if (ActiveNode = nil) or (ActiveNode.Data = nil) then
        Exit;

    Data := PNodeData(ActiveNode.Data);

    if Data^.NodeType = ntHub then
    begin
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

        AIItem.Name := ebModelName.Text;
        AIItem.APIKey := ebAPIKey.Text;
        AIItem.Folder := ebFolderID.Text;
        AIItem.Model := ebModelPath.Text;
        AIItem.Agent := ebAgentID.Text;

        FLocalSettings.AISettings[HubIdx].Items[ModIdx] := AIItem;

        AIParams.Temperature := StrToFloatDef(StringReplace(ebTemperature.Text, '.', FormatSettings.DecimalSeparator, []), 0.3);
        AIParams.MaxOutputTokens := StrToIntDef(ebMaxTokens.Text, 1024);
        AIParams.Content := mSystemPrompt.Text;

        ActiveNode.Text := ebModelName.Text;
    end;
end;

procedure TAISettingsForm.tvAIStructureChange(Sender: TObject; Node: TTreeNode);
var
    Data: PNodeData;
begin
    if (Node = nil) or (Node.Data = nil) then
        Exit;

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

