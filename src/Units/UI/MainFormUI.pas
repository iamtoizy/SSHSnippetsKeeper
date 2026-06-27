unit MainFormUI;

interface

uses
    Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants,
    System.Classes, Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs,
    Vcl.Menus, System.IOUtils, Vcl.ComCtrls, Vcl.ExtCtrls,
    System.DateUtils, System.Math,
    Snippet, System.ImageList, Vcl.ImgList, Vcl.StdCtrls;

type
    TMainForm = class(TForm)
        MainMenu: TMainMenu;
        File1: TMenuItem;
        nOpenDatabase: TMenuItem;
        NCreateDatabase: TMenuItem;
        OpenDialog: TOpenDialog;
        SaveDialog: TSaveDialog;
        pLeft: TPanel;
        splLeft: TSplitter;
        pCenter: TPanel;
        tvCategories: TTreeView;
        lvSnippets: TListView;
        pRight: TPanel;
        splRight: TSplitter;
        ilSnippets: TImageList;
        pBottom: TPanel;
        mSnippet: TMemo;
        pSubLeft: TPanel;
        sSubLeft: TSplitter;
        lbUsername: TLabel;
        lbTags: TLabel;
        lbTitleText: TLabel;
        lvTags: TListView;
        ilTags: TImageList;
        procedure nOpenDatabaseClick(Sender: TObject);
        procedure NCreateDatabaseClick(Sender: TObject);
        procedure tvCategoriesChange(Sender: TObject; Node: TTreeNode);
        procedure lvSnippetsClick(Sender: TObject);
    private
        { Private declarations }
        procedure FillSnippetListView(const Snippets: TArray<TSnippetDTO>);
        function ExtractSnippetByListItem(Item: TListItem): TSnippetDTO;
        procedure FillUserInterfaceFromSnippet(Snippet: PSnippetDTO);
    public
        { Public declarations }
    end;

var
    MainForm: TMainForm;

implementation

{$R *.dfm}

uses
    uDataModule,
    UserRepository,
    User,
    TagRepository,
    Tag
    ;

procedure TMainForm.FillUserInterfaceFromSnippet(Snippet: PSnippetDTO);
var
    User: TUserDTO;
    Tags: TArray<TTagDTO>;
    Tag: TTagDTO;
    item: TListItem;
begin
    if DataModuleCommon.UserRepository.TryGetByID(1, User) then
        lbUsername.Caption := User.Name;

    lbTitleText.Caption := Snippet.Title;
    mSnippet.Text := Snippet.Content;
    lvTags.Clear;
    Tags := DataModuleCommon.TagRepository.GetByID(Snippet.ID);

    Tags := DataModuleCommon.SnippetRepository.GetSnippetTags(Snippet.ID);
    lvTags.Clear;
    for Tag in Tags do
    begin
        Item := lvTags.Items.Add;
        Item.Caption := Tag.Name;
    end;

end;

procedure TMainForm.lvSnippetsClick(Sender: TObject);
var
    Item: TListItem;
    Snippet: TSnippetDTO;
begin
    Item := lvSnippets.Selected;

    if not Assigned(Item) then
        Exit;

    Snippet := ExtractSnippetByListItem(Item);
    FillUserInterfaceFromSnippet(@Snippet);
end;


procedure TMainForm.NCreateDatabaseClick(Sender: TObject);
begin
    SaveDialog.FileName := System.IOUtils.TPath.GetDirectoryName(Application.ExeName) + '\snippets.sqlite';
    if SaveDialog.Execute(Application.Handle) then
        DataModuleCommon.CreateDatabase(SaveDialog.FileName);

    //FSnippetRepo := TSnippetRepository.Create(FDConnection);
    {
    // При нажатии кнопки "Добавить сниппет"
    var Snip := TSnippet.Create;
    try
      Snip.UserID := 1;
      Snip.Title := EditTitle.Text;
      Snip.Content := MemoContent.Text;
      Snip.Category := ComboBoxCategory.Text;

      FSnippetRepo.Add(Snip);
      ShowMessage('Сниппет сохранён с ID = ' + Snip.ID.ToString);
    finally
      Snip.Free;
    end;
    }
end;


procedure TMainForm.nOpenDatabaseClick(Sender: TObject);
begin
    OpenDialog.FileName := System.IOUtils.TPath.GetDirectoryName(Application.ExeName) + '\snippets.sqlite';
    if OpenDialog.Execute(Application.Handle) then
    begin
        DataModuleCommon.OpenDatabase(OpenDialog.FileName);
        DataModuleCommon.BuildTree(tvCategories);
    end;
end;

procedure TMainForm.tvCategoriesChange(Sender: TObject; Node: TTreeNode);
var
    CategoryID: Integer;
    Snippets: TArray<TSnippetDTO>;
begin
    if Node = nil then
        Exit;

    CategoryID := Integer(Node.Data);
    Snippets := DataModuleCommon.SnippetRepository.GetSnippetByCategory(CategoryID);
    FillSnippetListView(Snippets);
end;

procedure TMainForm.FillSnippetListView(const Snippets: TArray<TSnippetDTO>);
var
    Item: TListItem;
    S: TSnippetDTO;
begin
    lvSnippets.Items.BeginUpdate;
    try
        lvSnippets.Items.Clear;

        for S in Snippets do
        begin
            Item := lvSnippets.Items.Add;
            Item.Caption := S.Title;

//            Item.SubItems.Add(S.ExecCount.ToString);
            Item.SubItems.Add(DateTimeToStr(UnixToDateTime(S.CreatedAt)));
            // TODO: Добавить выбор иконок
            Item.StateIndex := 0;
            if (S.UpdatedAt > 0) then
                Item.SubItems.Add(DateTimeToStr(UnixToDateTime(S.UpdatedAt)))
            else
                Item.SubItems.Add('');

            Item.Data := Pointer(S.ID); // snippet_id для кликов
        end;
    finally
        lvSnippets.Items.EndUpdate;
    end;
end;

function TMainForm.ExtractSnippetByListItem(Item: TListItem): TSnippetDTO;
begin
    if not Assigned(Item) then
        Exit;

    Result := DataModuleCommon.SnippetRepository.GetById(Integer(Item.Data));
end;

end.

