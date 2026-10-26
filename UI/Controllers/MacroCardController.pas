unit MacroCardController;

interface

uses
    MacroEngine,
    MacroInputTypes,
    SynEditTypes,
    System.Classes,
    System.Math,
    System.SysUtils
    ;

type
    // Перенос карточки: SrcOffset/TokenLen - удаляемый диапазон в ИСХОДНОМ
    // тексте, InsertOffset - позиция вставки в тексте ПОСЛЕ удаления,
    // TokenText - что вставлять. Valid=False - перенос запрещён или бессмыслен.
    TMacroCardMove = record
        Valid: Boolean;
        SrcOffset: Integer;
        TokenLen: Integer;
        InsertOffset: Integer;
        TokenText: string;
    end;

    // Сканер позиций макросов в тексте редактора и навигации по ним.
    // Офсеты - индексы в FLines.Text, нумерация с нуля; строки склеены
    // фактическими разделителями этого текста (#13#10, #10 или #13):
    // TSynEditStringList подбирает разделитель по содержимому, поэтому
    // BuildLineOffsets сканирует текст, а не предполагает sLineBreak.
    // Карточка - токен макроса (все виды, кроме tkText-чанков).
    // TokenAtOffset/TokenAtBufferPos/Navigate/InvalidCards оперируют
    // ПОЗИЦИЯМИ КАРТОЧЕК (0..CardCount-1), Tokens - все сырые токены.
    TMacroCardController = class
    private
        FLines: TStrings;
        FEngine: TMacroEngine;
        FTokens: TArray<TMacroToken>;
        FCardIdx: TArray<Integer>;
        FLineOffsets: TArray<Integer>;
        FLastText: string;
        procedure BuildLineOffsets;
        procedure BuildCardList;
        function EnsureScanned: TArray<TMacroToken>;
        function BufferPosNoScan(Offset: Integer): TBufferCoord;
    public
        constructor Create(ALines: TStrings);
        destructor Destroy; override;

        procedure Rescan;

        function TokenCount: Integer;
        function Tokens: TArray<TMacroToken>;
        function Token(Index: Integer): TMacroToken;

        function CardCount: Integer;
        function CardToken(CardPos: Integer): TMacroToken;
        function InvalidCards: TArray<Integer>;

        function ScannedCardCount: Integer;
        function ScannedCardToken(CardPos: Integer): TMacroToken;

        function OffsetFromBufferPos(const Pos: TBufferCoord): Integer;
        function BufferPosFromOffset(Offset: Integer): TBufferCoord;

        function TokenAtOffset(Offset: Integer): Integer;
        function TokenAtBufferPos(const Pos: TBufferCoord): Integer;

        function Navigate(FromCardPos, Delta: Integer): Integer;
        function NavigateLine(FromCardPos, Delta: Integer): Integer;

        function SnapOffsetFromBufferPos(const Pos: TBufferCoord): Integer;
        function CardMoveDropValid(CardPos, DropOffset: Integer): Boolean;
        function PrepareCardMove(CardPos, DropOffset: Integer): TMacroCardMove;
    end;

implementation

{ TMacroCardController }

constructor TMacroCardController.Create(ALines: TStrings);
begin
    inherited Create;
    FLines := ALines;
    FEngine := TMacroEngine.Create;
end;

destructor TMacroCardController.Destroy;
begin
    FEngine.Free;
    inherited;
end;

procedure TMacroCardController.BuildLineOffsets;
var
    I, P, TextLen: Integer;
begin
    SetLength(FLineOffsets, FLines.Count);
    if FLines.Count = 0 then
        Exit;

    FLineOffsets[0] := 0;
    P := 1;
    TextLen := Length(FLastText);
    for I := 1 to FLines.Count - 1 do
    begin
        while P <= TextLen do
        begin
            if FLastText[P] = #13 then
            begin
                Inc(P);
                if (P <= TextLen) and (FLastText[P] = #10) then
                    Inc(P);
                Break;
            end;
            if FLastText[P] = #10 then
            begin
                Inc(P);
                Break;
            end;
            Inc(P);
        end;
        FLineOffsets[I] := P - 1;
    end;
end;

procedure TMacroCardController.Rescan;
var
    Text: string;
begin
    Text := FLines.Text;
    if Text = FLastText then
        Exit;

    FLastText := Text;
    FTokens := FEngine.GetTokens(Text);
    BuildLineOffsets;
    BuildCardList;
end;

procedure TMacroCardController.BuildCardList;
var
    I: Integer;
begin
    SetLength(FCardIdx, 0);
    for I := 0 to High(FTokens) do
        if FTokens[I].Kind <> tkText then
        begin
            SetLength(FCardIdx, Length(FCardIdx) + 1);
            FCardIdx[High(FCardIdx)] := I;
        end;
end;

function TMacroCardController.EnsureScanned: TArray<TMacroToken>;
begin
    Rescan;
    Result := FTokens;
end;

function TMacroCardController.TokenCount: Integer;
begin
    Result := Length(EnsureScanned);
end;

function TMacroCardController.Tokens: TArray<TMacroToken>;
begin
    Result := EnsureScanned;
end;

function TMacroCardController.Token(Index: Integer): TMacroToken;
begin
    if (Index < 0) or (Index >= TokenCount) then
        raise EArgumentOutOfRangeException.Create('TMacroCardController.Token');
    Result := FTokens[Index];
end;

function TMacroCardController.OffsetFromBufferPos(const Pos: TBufferCoord): Integer;
begin
    if FLines.Count = 0 then
        Exit(0);

    Rescan;
    Result := FLineOffsets[Min(Max(Pos.Line - 1, 0), FLines.Count - 1)] + Pos.Char - 1;
end;

function TMacroCardController.BufferPosNoScan(Offset: Integer): TBufferCoord;
var
    LowB, HighB, Mid, Line: Integer;
begin
    Result := BufferCoord(1, 1);
    if FLines.Count = 0 then
        Exit;

    LowB := 0;
    HighB := FLines.Count - 1;
    Line := 0;
    while LowB <= HighB do
    begin
        Mid := (LowB + HighB) div 2;
        if FLineOffsets[Mid] <= Offset then
        begin
            Line := Mid;
            LowB := Mid + 1;
        end
        else
            HighB := Mid - 1;
    end;

    Result := BufferCoord(Offset - FLineOffsets[Line] + 1, Line + 1);
end;

function TMacroCardController.BufferPosFromOffset(Offset: Integer): TBufferCoord;
begin
    Rescan;
    Result := BufferPosNoScan(Offset);
end;

function TMacroCardController.TokenAtOffset(Offset: Integer): Integer;
var
    CardPos, Idx: Integer;
    TokenArr: TArray<TMacroToken>;
begin
    Result := -1;
    TokenArr := EnsureScanned;
    for CardPos := 0 to High(FCardIdx) do
    begin
        Idx := FCardIdx[CardPos];
        if (Offset >= TokenArr[Idx].StartOffset - 1) and
           (Offset < TokenArr[Idx].StartOffset - 1 + TokenArr[Idx].Length) then
            Exit(CardPos);
    end;
end;

function TMacroCardController.TokenAtBufferPos(const Pos: TBufferCoord): Integer;
begin
    Result := TokenAtOffset(OffsetFromBufferPos(Pos));
end;

function TMacroCardController.Navigate(FromCardPos, Delta: Integer): Integer;
var
    Count: Integer;
begin
    Count := CardCount;
    if Count = 0 then
        Exit(-1);

    if FromCardPos < 0 then
    begin
        if Delta < 0 then
            Exit(Count - 1);
        Exit(0);
    end;

    Result := (FromCardPos + Delta) mod Count;
    if Result < 0 then
        Result := Result + Count;
end;

function TMacroCardController.NavigateLine(FromCardPos, Delta: Integer): Integer;
var
    I, Count, VertDist, BestVert, CharDist, BestCharDist: Integer;
    CurPos, CandPos: TBufferCoord;
begin
    Result := -1;
    EnsureScanned;
    Count := Length(FCardIdx);
    if (Count = 0) or (FromCardPos < 0) or (FromCardPos >= Count) or (Delta = 0) then
        Exit;

    CurPos := BufferPosNoScan(FTokens[FCardIdx[FromCardPos]].StartOffset - 1);
    BestVert := MaxInt;
    BestCharDist := MaxInt;
    for I := 0 to Count - 1 do
    begin
        if I = FromCardPos then
            Continue;
        CandPos := BufferPosNoScan(FTokens[FCardIdx[I]].StartOffset - 1);
        VertDist := (CandPos.Line - CurPos.Line) * Delta;
        if VertDist <= 0 then
            Continue;
        CharDist := Abs(CandPos.Char - CurPos.Char);
        if (VertDist < BestVert) or
           ((VertDist = BestVert) and (CharDist < BestCharDist)) then
        begin
            BestVert := VertDist;
            BestCharDist := CharDist;
            Result := I;
        end;
    end;

    if Result >= 0 then
        Exit;

    BestVert := MaxInt;
    BestCharDist := MaxInt;
    for I := 0 to Count - 1 do
    begin
        if I = FromCardPos then
            Continue;
        CandPos := BufferPosNoScan(FTokens[FCardIdx[I]].StartOffset - 1);
        if (CandPos.Line - CurPos.Line) * Delta >= 0 then
            Continue;
        VertDist := CandPos.Line * Delta;
        CharDist := Abs(CandPos.Char - CurPos.Char);
        if (VertDist < BestVert) or
           ((VertDist = BestVert) and (CharDist < BestCharDist)) then
        begin
            BestVert := VertDist;
            BestCharDist := CharDist;
            Result := I;
        end;
    end;
end;

function TMacroCardController.CardCount: Integer;
begin
    EnsureScanned;
    Result := Length(FCardIdx);
end;

function TMacroCardController.CardToken(CardPos: Integer): TMacroToken;
begin
    EnsureScanned;
    if (CardPos < 0) or (CardPos >= Length(FCardIdx)) then
        raise EArgumentOutOfRangeException.Create('TMacroCardController.CardToken');
    Result := FTokens[FCardIdx[CardPos]];
end;

function TMacroCardController.InvalidCards: TArray<Integer>;
var
    CardPos: Integer;
    TokenArr: TArray<TMacroToken>;
begin
    TokenArr := EnsureScanned;
    SetLength(Result, 0);
    for CardPos := 0 to High(FCardIdx) do
        if (TokenArr[FCardIdx[CardPos]].Kind = tkUnknown) or
           TokenArr[FCardIdx[CardPos]].Invalid then
        begin
            SetLength(Result, Length(Result) + 1);
            Result[High(Result)] := CardPos;
        end;
end;

function TMacroCardController.ScannedCardCount: Integer;
begin
    Result := Length(FCardIdx);
end;

function TMacroCardController.ScannedCardToken(CardPos: Integer): TMacroToken;
begin
    if (CardPos < 0) or (CardPos >= Length(FCardIdx)) then
        raise EArgumentOutOfRangeException.Create('TMacroCardController.ScannedCardToken');
    Result := FTokens[FCardIdx[CardPos]];
end;

function TMacroCardController.SnapOffsetFromBufferPos(const Pos: TBufferCoord): Integer;
var
    Line, Char: Integer;
begin
    if FLines.Count = 0 then
        Exit(0);

    Rescan;
    Line := Min(Max(Pos.Line - 1, 0), FLines.Count - 1);
    Char := Min(Max(Pos.Char, 1), Length(FLines[Line]) + 1);
    Result := FLineOffsets[Line] + Char - 1;
end;

function TMacroCardController.PrepareCardMove(CardPos, DropOffset: Integer): TMacroCardMove;
var
    TokenArr: TArray<TMacroToken>;
    Idx, I, Src0, Len, TextLen, Other0, OtherLen: Integer;
begin
    Result := Default(TMacroCardMove);

    TokenArr := EnsureScanned;
    if (CardPos < 0) or (CardPos >= Length(FCardIdx)) then
        Exit;

    Idx := FCardIdx[CardPos];
    Src0 := TokenArr[Idx].StartOffset - 1;
    Len := TokenArr[Idx].Length;

    TextLen := Length(FLastText);
    if DropOffset < 0 then
        Exit;
    if DropOffset > TextLen then
        DropOffset := TextLen;

    // Сброс на саму карточку или её края - позиция не меняется
    if (DropOffset >= Src0) and (DropOffset <= Src0 + Len) then
        Exit;

    // Запрет сброса строго внутрь другой карточки
    for I := 0 to High(FCardIdx) do
    begin
        if I = CardPos then
            Continue;
        Other0 := TokenArr[FCardIdx[I]].StartOffset - 1;
        OtherLen := TokenArr[FCardIdx[I]].Length;
        if (DropOffset > Other0) and (DropOffset < Other0 + OtherLen) then
            Exit;
    end;

    Result.Valid := True;
    Result.SrcOffset := Src0;
    Result.TokenLen := Len;
    if DropOffset > Src0 then
        Result.InsertOffset := DropOffset - Len
    else
        Result.InsertOffset := DropOffset;
    Result.TokenText := Copy(FLastText, Src0 + 1, Len);
end;

function TMacroCardController.CardMoveDropValid(CardPos, DropOffset: Integer): Boolean;
begin
    Result := PrepareCardMove(CardPos, DropOffset).Valid;
end;

end.
