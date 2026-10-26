unit Tests.MacroCardController;

interface

uses
    DUnitX.TestFramework,
    MacroCardController,
    MacroEngine,
    MacroInputTypes,
    SynEditTypes,
    System.Classes
    ;

type
    [TestFixture]
    TMacroCardControllerTests = class(TObject)
    private
        function MakeLines(const AText: string): TStringList;
        class function ApplyMoveText(const AText: string; const AMove: TMacroCardMove): string;
    public
        [Test]
        procedure Rescan_MultiLine_OffsetsAndBufferPos;
        [Test]
        procedure TokenAtOffset_HitAndMiss;
        [Test]
        procedure TokenAtBufferPos_MapsCaret;
        [Test]
        procedure Navigate_WrapsAround;
        [Test]
        procedure Navigate_NoBase_SelectsEdgeCards;
        [Test]
        procedure NavigateLine_Vertical_NearestByColumn;
        [Test]
        procedure NavigateLine_WrapsAcrossLines;
        [Test]
        procedure NavigateLine_SameLine_Excluded;
        [Test]
        procedure Navigate_EmptyText_ReturnsMinusOne;
        [Test]
        procedure InvalidCards_FindsUnknown;
        [Test]
        procedure InvalidCards_FindsBadArgs;
        [Test]
        procedure Rescan_UpdatesAfterTextChange;
        [Test]
        procedure PrepareCardMove_Forward_AcrossCard;
        [Test]
        procedure PrepareCardMove_Backward_ToStart;
        [Test]
        procedure PrepareCardMove_DropOnSelf_Noop;
        [Test]
        procedure PrepareCardMove_InsideOtherCard_Forbidden;
        [Test]
        procedure SnapOffsetFromBufferPos_ClampsToLineEnd;
        [Test]
        procedure BufferPos_LFLineBreaks_NoShift;
        [Test]
        procedure BufferPos_LFLineBreaks_ScreenshotCards;
    end;

implementation

uses
    System.SysUtils
    ;

function TMacroCardControllerTests.MakeLines(const AText: string): TStringList;
begin
    Result := TStringList.Create;
    Result.Text := AText;
end;

class function TMacroCardControllerTests.ApplyMoveText(const AText: string;
    const AMove: TMacroCardMove): string;
var
    Cut: string;
begin
    Cut := Copy(AText, 1, AMove.SrcOffset) +
        Copy(AText, AMove.SrcOffset + AMove.TokenLen + 1, Length(AText));
    Result := Copy(Cut, 1, AMove.InsertOffset) + AMove.TokenText +
        Copy(Cut, AMove.InsertOffset + 1, Length(Cut));
end;

procedure TMacroCardControllerTests.Rescan_MultiLine_OffsetsAndBufferPos;
var
    Lines: TStringList;
    Controller: TMacroCardController;
    EnterToken, SleepToken: TMacroToken;
begin
    Lines := MakeLines('ab{ENTER}' + sLineBreak + 'c{SLEEP 100}');
    Controller := TMacroCardController.Create(Lines);
    try
        Assert.AreEqual(2, Controller.CardCount);

        EnterToken := Controller.CardToken(0);
        Assert.AreEqual(tkEnter, EnterToken.Kind);
        Assert.AreEqual(3, EnterToken.StartOffset);
        Assert.AreEqual(7, EnterToken.Length);

        SleepToken := Controller.CardToken(1);
        Assert.AreEqual(tkSleep, SleepToken.Kind);
        Assert.AreEqual(13, SleepToken.StartOffset);
        Assert.AreEqual(11, SleepToken.Length);

        Assert.AreEqual(BufferCoord(1, 2), Controller.BufferPosFromOffset(11));
        Assert.AreEqual(BufferCoord(11, 2), Controller.BufferPosFromOffset(21));
        Assert.AreEqual(21, Controller.OffsetFromBufferPos(BufferCoord(11, 2)));
        Assert.AreEqual(0, Controller.OffsetFromBufferPos(BufferCoord(1, 1)));
    finally
        Controller.Free;
        Lines.Free;
    end;
end;

procedure TMacroCardControllerTests.TokenAtOffset_HitAndMiss;
var
    Lines: TStringList;
    Controller: TMacroCardController;
begin
    Lines := MakeLines('ab{ENTER}cd');
    Controller := TMacroCardController.Create(Lines);
    try
        Assert.AreEqual(-1, Controller.TokenAtOffset(0));
        Assert.AreEqual(-1, Controller.TokenAtOffset(1));
        Assert.AreEqual(0, Controller.TokenAtOffset(2));
        Assert.AreEqual(0, Controller.TokenAtOffset(8));
        Assert.AreEqual(-1, Controller.TokenAtOffset(9));
        Assert.AreEqual(-1, Controller.TokenAtOffset(999));
    finally
        Controller.Free;
        Lines.Free;
    end;
end;

procedure TMacroCardControllerTests.TokenAtBufferPos_MapsCaret;
var
    Lines: TStringList;
    Controller: TMacroCardController;
begin
    Lines := MakeLines('ab{ENTER}' + sLineBreak + '{SLEEP 100}x');
    Controller := TMacroCardController.Create(Lines);
    try
        Assert.AreEqual(-1, Controller.TokenAtBufferPos(BufferCoord(1, 1)));
        Assert.AreEqual(0, Controller.TokenAtBufferPos(BufferCoord(3, 1)));
        Assert.AreEqual(0, Controller.TokenAtBufferPos(BufferCoord(9, 1)));
        Assert.AreEqual(1, Controller.TokenAtBufferPos(BufferCoord(1, 2)));
        Assert.AreEqual(1, Controller.TokenAtBufferPos(BufferCoord(11, 2)));
        Assert.AreEqual(-1, Controller.TokenAtBufferPos(BufferCoord(12, 2)));
    finally
        Controller.Free;
        Lines.Free;
    end;
end;

procedure TMacroCardControllerTests.Navigate_WrapsAround;
var
    Lines: TStringList;
    Controller: TMacroCardController;
begin
    Lines := MakeLines('{ENTER}{SLEEP 5}{CLEAR_LINE}{DATETIME}');
    Controller := TMacroCardController.Create(Lines);
    try
        Assert.AreEqual(4, Controller.CardCount);
        Assert.AreEqual(1, Controller.Navigate(0, 1));
        Assert.AreEqual(0, Controller.Navigate(3, 1));
        Assert.AreEqual(3, Controller.Navigate(0, -1));
        Assert.AreEqual(2, Controller.Navigate(3, -1));
    finally
        Controller.Free;
        Lines.Free;
    end;
end;

procedure TMacroCardControllerTests.Navigate_NoBase_SelectsEdgeCards;
var
    Lines: TStringList;
    Controller: TMacroCardController;
begin
    Lines := MakeLines('{ENTER}{SLEEP 5}{CLEAR_LINE}{DATETIME}');
    Controller := TMacroCardController.Create(Lines);
    try
        Assert.AreEqual(4, Controller.CardCount);
        Assert.AreEqual(0, Controller.Navigate(-1, 1));
        Assert.AreEqual(3, Controller.Navigate(-1, -1));
        Assert.AreEqual(0, Controller.Navigate(-1, 3));
        Assert.AreEqual(3, Controller.Navigate(-1, -4));
    finally
        Controller.Free;
        Lines.Free;
    end;
end;

procedure TMacroCardControllerTests.NavigateLine_Vertical_NearestByColumn;
var
    Lines: TStringList;
    Controller: TMacroCardController;
begin
    Lines := MakeLines('{SLEEP 5}x{ENTER}' + sLineBreak +
        '{CLEAR_LINE}a{DATETIME}' + sLineBreak +
        'plain' + sLineBreak +
        '{KEYDELAY 9}');
    Controller := TMacroCardController.Create(Lines);
    try
        Assert.AreEqual(5, Controller.CardCount);
        Assert.AreEqual(2, Controller.NavigateLine(0, 1));
        Assert.AreEqual(3, Controller.NavigateLine(1, 1));
        Assert.AreEqual(4, Controller.NavigateLine(2, 1));
        Assert.AreEqual(1, Controller.NavigateLine(3, -1));
        Assert.AreEqual(2, Controller.NavigateLine(4, -1));
        Assert.AreEqual(0, Controller.NavigateLine(4, 1));
        Assert.AreEqual(4, Controller.NavigateLine(0, -1));
    finally
        Controller.Free;
        Lines.Free;
    end;
end;

procedure TMacroCardControllerTests.NavigateLine_WrapsAcrossLines;
var
    Lines: TStringList;
    Controller: TMacroCardController;
begin
    Lines := MakeLines('{ENTER}' + sLineBreak +
        'plain' + sLineBreak +
        'plain' + sLineBreak +
        'plain' + sLineBreak +
        '{SLEEP 1}' + sLineBreak +
        'plain' + sLineBreak +
        'plain' + sLineBreak +
        'plain' + sLineBreak +
        '{CLEAR_LINE}');
    Controller := TMacroCardController.Create(Lines);
    try
        Assert.AreEqual(3, Controller.CardCount);
        Assert.AreEqual(0, Controller.NavigateLine(2, 1));
        Assert.AreEqual(2, Controller.NavigateLine(0, -1));
        Assert.AreEqual(2, Controller.NavigateLine(1, 1));
        Assert.AreEqual(0, Controller.NavigateLine(1, -1));
    finally
        Controller.Free;
        Lines.Free;
    end;
end;

procedure TMacroCardControllerTests.NavigateLine_SameLine_Excluded;
var
    Lines: TStringList;
    Controller: TMacroCardController;
begin
    Lines := MakeLines('{ENTER}{SLEEP 5}');
    Controller := TMacroCardController.Create(Lines);
    try
        Assert.AreEqual(2, Controller.CardCount);
        Assert.AreEqual(-1, Controller.NavigateLine(0, 1));
        Assert.AreEqual(-1, Controller.NavigateLine(0, -1));
        Assert.AreEqual(-1, Controller.NavigateLine(1, 1));
        Assert.AreEqual(-1, Controller.NavigateLine(1, -1));
    finally
        Controller.Free;
        Lines.Free;
    end;
end;

procedure TMacroCardControllerTests.Navigate_EmptyText_ReturnsMinusOne;
var
    Lines: TStringList;
    Controller: TMacroCardController;
begin
    Lines := MakeLines('plain text only');
    Controller := TMacroCardController.Create(Lines);
    try
        Assert.AreEqual(0, Controller.CardCount);
        Assert.AreEqual(-1, Controller.Navigate(0, 1));
        Assert.AreEqual(-1, Controller.Navigate(0, -1));
    finally
        Controller.Free;
        Lines.Free;
    end;
end;

procedure TMacroCardControllerTests.InvalidCards_FindsUnknown;
var
    Lines: TStringList;
    Controller: TMacroCardController;
    Invalid: TArray<Integer>;
begin
    Lines := MakeLines('a{UNKNOWN_CMD}b{ENTER}c{KEYDELAY -5}');
    Controller := TMacroCardController.Create(Lines);
    try
        Invalid := Controller.InvalidCards;
        Assert.AreEqual(2, Integer(Length(Invalid)));
        Assert.AreEqual(0, Invalid[0]);
        Assert.AreEqual(2, Invalid[1]);
    finally
        Controller.Free;
        Lines.Free;
    end;
end;

procedure TMacroCardControllerTests.InvalidCards_FindsBadArgs;
var
    Lines: TStringList;
    Controller: TMacroCardController;
    Invalid: TArray<Integer>;
begin
    Lines := MakeLines('{SLEEP abc}{ENTER}{INPUT[DATE:2026-13-01] D}');
    Controller := TMacroCardController.Create(Lines);
    try
        Invalid := Controller.InvalidCards;
        Assert.AreEqual(2, Integer(Length(Invalid)));
        Assert.AreEqual(0, Invalid[0]);
        Assert.AreEqual(2, Invalid[1]);
    finally
        Controller.Free;
        Lines.Free;
    end;
end;

procedure TMacroCardControllerTests.Rescan_UpdatesAfterTextChange;
var
    Lines: TStringList;
    Controller: TMacroCardController;
begin
    Lines := MakeLines('before');
    Controller := TMacroCardController.Create(Lines);
    try
        Assert.AreEqual(0, Controller.CardCount);

        Lines.Text := 'x{ENTER}y';
        Assert.AreEqual(1, Controller.CardCount);
        Assert.AreEqual(0, Controller.TokenAtOffset(1));

        Lines.Text := '';
        Assert.AreEqual(0, Controller.CardCount);
        Assert.AreEqual(BufferCoord(1, 1), Controller.BufferPosFromOffset(5));
    finally
        Controller.Free;
        Lines.Free;
    end;
end;

procedure TMacroCardControllerTests.PrepareCardMove_Forward_AcrossCard;
var
    Lines: TStringList;
    Controller: TMacroCardController;
    Move: TMacroCardMove;
    SourceText, MovedText: string;
begin
    SourceText := 'a{ENTER}b{SLEEP 5}c';
    Lines := MakeLines(SourceText);
    Controller := TMacroCardController.Create(Lines);
    try
        Move := Controller.PrepareCardMove(0, 18);
        Assert.IsTrue(Move.Valid);
        Assert.AreEqual(1, Move.SrcOffset);
        Assert.AreEqual(7, Move.TokenLen);
        Assert.AreEqual(11, Move.InsertOffset);
        Assert.AreEqual('{ENTER}', Move.TokenText);

        MovedText := ApplyMoveText(SourceText, Move);
        Assert.AreEqual('ab{SLEEP 5}{ENTER}c', MovedText);

        Lines.Text := MovedText;
        Assert.AreEqual(2, Controller.CardCount);
        Assert.AreEqual(tkSleep, Controller.CardToken(0).Kind);
        Assert.AreEqual(1, Controller.TokenAtOffset(11));
    finally
        Controller.Free;
        Lines.Free;
    end;
end;

procedure TMacroCardControllerTests.PrepareCardMove_Backward_ToStart;
var
    Lines: TStringList;
    Controller: TMacroCardController;
    Move: TMacroCardMove;
    SourceText, MovedText: string;
begin
    SourceText := 'a{ENTER}b{SLEEP 5}c';
    Lines := MakeLines(SourceText);
    Controller := TMacroCardController.Create(Lines);
    try
        Move := Controller.PrepareCardMove(1, 0);
        Assert.IsTrue(Move.Valid);
        Assert.AreEqual(9, Move.SrcOffset);
        Assert.AreEqual(9, Move.TokenLen);
        Assert.AreEqual(0, Move.InsertOffset);
        Assert.AreEqual('{SLEEP 5}', Move.TokenText);

        MovedText := ApplyMoveText(SourceText, Move);
        Assert.AreEqual('{SLEEP 5}a{ENTER}bc', MovedText);

        Lines.Text := MovedText;
        Assert.AreEqual(0, Controller.TokenAtOffset(0));
    finally
        Controller.Free;
        Lines.Free;
    end;
end;

procedure TMacroCardControllerTests.PrepareCardMove_DropOnSelf_Noop;
var
    Lines: TStringList;
    Controller: TMacroCardController;
    Move: TMacroCardMove;
begin
    Lines := MakeLines('a{ENTER}b{SLEEP 5}c');
    Controller := TMacroCardController.Create(Lines);
    try
        Move := Controller.PrepareCardMove(0, 1);
        Assert.IsFalse(Move.Valid);
        Move := Controller.PrepareCardMove(0, 3);
        Assert.IsFalse(Move.Valid);
        Move := Controller.PrepareCardMove(0, 8);
        Assert.IsFalse(Move.Valid);
    finally
        Controller.Free;
        Lines.Free;
    end;
end;

procedure TMacroCardControllerTests.PrepareCardMove_InsideOtherCard_Forbidden;
var
    Lines: TStringList;
    Controller: TMacroCardController;
    Move: TMacroCardMove;
begin
    Lines := MakeLines('a{ENTER}b{SLEEP 5}c');
    Controller := TMacroCardController.Create(Lines);
    try
        Move := Controller.PrepareCardMove(0, 12);
        Assert.IsFalse(Move.Valid);
        Assert.IsFalse(Controller.CardMoveDropValid(0, 12));
        Assert.IsTrue(Controller.CardMoveDropValid(0, 18));

        Move := Controller.PrepareCardMove(-1, 0);
        Assert.IsFalse(Move.Valid);
    finally
        Controller.Free;
        Lines.Free;
    end;
end;

procedure TMacroCardControllerTests.SnapOffsetFromBufferPos_ClampsToLineEnd;
var
    Lines: TStringList;
    Controller: TMacroCardController;
begin
    Lines := MakeLines('ab{ENTER}');
    Controller := TMacroCardController.Create(Lines);
    try
        Assert.AreEqual(0, Controller.SnapOffsetFromBufferPos(BufferCoord(1, 1)));
        Assert.AreEqual(8, Controller.SnapOffsetFromBufferPos(BufferCoord(9, 1)));
        Assert.AreEqual(9, Controller.SnapOffsetFromBufferPos(BufferCoord(15, 1)));
        Assert.AreEqual(2, Controller.SnapOffsetFromBufferPos(BufferCoord(3, 5)));
    finally
        Controller.Free;
        Lines.Free;
    end;
end;

procedure TMacroCardControllerTests.BufferPos_LFLineBreaks_NoShift;
var
    Lines: TStringList;
    Controller: TMacroCardController;
begin
    Lines := TStringList.Create;
    try
        Lines.LineBreak := #10;
        Lines.Text := 'ab{ENTER}' + #10 + '{SLEEP 5}x';
        Controller := TMacroCardController.Create(Lines);
        try
            Assert.AreEqual(2, Controller.CardCount);
            Assert.AreEqual(BufferCoord(3, 1), Controller.BufferPosFromOffset(2));
            Assert.AreEqual(BufferCoord(1, 2), Controller.BufferPosFromOffset(10));
            Assert.AreEqual(BufferCoord(10, 2), Controller.BufferPosFromOffset(19));
            Assert.AreEqual(10, Controller.OffsetFromBufferPos(BufferCoord(1, 2)));
        finally
            Controller.Free;
        end;
    finally
        Lines.Free;
    end;
end;

procedure TMacroCardControllerTests.BufferPos_LFLineBreaks_ScreenshotCards;
var
    Lines: TStringList;
    Controller: TMacroCardController;
    DelayToken, DateTimeToken: TMacroToken;
begin
    Lines := TStringList.Create;
    try
        Lines.LineBreak := #10;
        Lines.Text := '{CLEAR_LINE}{CLEAR_LINE}' + #10 +
            '{KEYDELAY 10}' + #10 +
            '{DATETIME:YYYY-MM-DD hh-mm-ss}';
        Controller := TMacroCardController.Create(Lines);
        try
            Assert.AreEqual(4, Controller.CardCount);

            DelayToken := Controller.CardToken(2);
            Assert.AreEqual(26, DelayToken.StartOffset);
            Assert.AreEqual(13, DelayToken.Length);
            Assert.AreEqual(BufferCoord(1, 2),
                Controller.BufferPosFromOffset(DelayToken.StartOffset - 1));
            Assert.AreEqual(BufferCoord(14, 2),
                Controller.BufferPosFromOffset(DelayToken.StartOffset - 1 + DelayToken.Length));

            DateTimeToken := Controller.CardToken(3);
            Assert.AreEqual(40, DateTimeToken.StartOffset);
            Assert.AreEqual(30, DateTimeToken.Length);
            Assert.AreEqual(BufferCoord(1, 3),
                Controller.BufferPosFromOffset(DateTimeToken.StartOffset - 1));
            Assert.AreEqual(BufferCoord(31, 3),
                Controller.BufferPosFromOffset(DateTimeToken.StartOffset - 1 + DateTimeToken.Length));
        finally
            Controller.Free;
        end;
    finally
        Lines.Free;
    end;
end;

end.
