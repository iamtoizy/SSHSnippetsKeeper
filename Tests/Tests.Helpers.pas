unit Tests.Helpers;

interface

uses
    DUnitX.TestFramework
    ;

type
    [TestFixture]
    THelpersShortenDbPathTests = class(TObject)
    public
        [Test]
        procedure ShortPath_ReturnedAsIs;

        [Test]
        procedure LongPath_DriveEllipsisAndLastTwoDirs;

        [Test]
        procedure LongPath_FileNameDropped;

        [Test]
        procedure RootFile_ReturnsRoot;

        [Test]
        procedure UNCPath_DriveKeptIntact;

        [Test]
        procedure SingleDir_Long_ReturnsThatDir;
    end;

implementation

uses
    System.SysUtils,
    Common.Helpers
    ;

procedure THelpersShortenDbPathTests.ShortPath_ReturnedAsIs;
var
    Dir: string;
begin
    Dir := 'C:\Work\db\snippets';
    // Возвращается каталоговая часть без имени файла
    Assert.AreEqual(Dir, ShortenDbPath(Dir + '\snippets.sqlite'));
end;

procedure THelpersShortenDbPathTests.LongPath_DriveEllipsisAndLastTwoDirs;
var
    LongDir, Short: string;
begin
    LongDir := 'C:\one\two\three\four\five_dir\sixth_directory_level\yet_another_long_dir_name\';
    Short := ShortenDbPath(LongDir + 'snippets.sqlite');
    Assert.AreEqual('C:\...\sixth_directory_level\yet_another_long_dir_name', Short);
end;

procedure THelpersShortenDbPathTests.LongPath_FileNameDropped;
var
    Short: string;
begin
    Short := ShortenDbPath('C:\one\two\three\four\five_dir\sixth_directory_level\yet_another_long_dir_name\snippets.sqlite');
    Assert.IsFalse(Short.Contains('snippets.sqlite'), 'File name must not appear: ' + Short);
    Assert.IsFalse(Short.Contains('\one\'), 'Dropped directories must not appear: ' + Short);
end;

procedure THelpersShortenDbPathTests.RootFile_ReturnsRoot;
begin
    // Файл в корне диска: каталоговой части нет, остаётся 'C:\'
    Assert.AreEqual('C:\', ShortenDbPath('C:\' + StringOfChar('x', 80) + '.sqlite'));
end;

procedure THelpersShortenDbPathTests.UNCPath_DriveKeptIntact;
var
    Short: string;
begin
    Short := ShortenDbPath('\\server\share\one\two\three\four\deeply_nested_dirs_here\dbs\snippets.sqlite');
    Assert.AreEqual('\\server\share\...\deeply_nested_dirs_here\dbs', Short);
end;

procedure THelpersShortenDbPathTests.SingleDir_Long_ReturnsThatDir;
var
    Dir: string;
begin
    Dir := 'C:\' + StringOfChar('d', 80);
    Assert.AreEqual(Dir, ShortenDbPath(Dir + '\snippets.sqlite'));
end;

end.
