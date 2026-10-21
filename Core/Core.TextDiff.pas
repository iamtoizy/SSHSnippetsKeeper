unit Core.TextDiff;

interface

type
    TDiffLineKind = (dlEqual, dlDelete, dlInsert);

    TDiffLine = record
        Kind: TDiffLineKind;
        Text: string;
        OldNo: Integer;
        NewNo: Integer;
    end;

    TTextDiff = class
    private const
        MAX_DP_CELLS = 10000000;
    public
        class function SplitLines(const Text: string): TArray<string>; static;
        class function Compute(const OldText, NewText: string): TArray<TDiffLine>; static;
        class function ToUnified(const OldText, NewText: string; ContextLines: Integer = 3): TArray<TDiffLine>; static;
    end;

implementation

uses
    System.Generics.Collections,
    System.Math,
    System.SysUtils
    ;

{ TTextDiff }

class function TTextDiff.SplitLines(const Text: string): TArray<string>;
var
    List: TList<string>;
    Normalized: string;
    Start, I: Integer;
begin
    List := TList<string>.Create;
    try
        Normalized := StringReplace(Text, #13#10, #10, [rfReplaceAll]);
        Normalized := StringReplace(Normalized, #13, #10, [rfReplaceAll]);

        Start := 1;
        for I := 1 to Length(Normalized) do
            if Normalized[I] = #10 then
            begin
                List.Add(Copy(Normalized, Start, I - Start));
                Start := I + 1;
            end;

        if Start <= Length(Normalized) then
            List.Add(Copy(Normalized, Start, Length(Normalized) - Start + 1));

        Result := List.ToArray;
    finally
        List.Free;
    end;
end;

class function TTextDiff.Compute(const OldText, NewText: string): TArray<TDiffLine>;
var
    A, B: TArray<string>;
    N, M, I, J, Stride: Integer;
    L: TArray<Integer>;
    List: TList<TDiffLine>;
    Line: TDiffLine;
begin
    A := SplitLines(OldText);
    B := SplitLines(NewText);
    N := Length(A);
    M := Length(B);

    List := TList<TDiffLine>.Create;
    try
        if ((Int64(N) + 1) * (Int64(M) + 1)) > MAX_DP_CELLS then
        begin
            for I := 0 to N - 1 do
            begin
                Line.Kind := dlDelete;
                Line.Text := A[I];
                Line.OldNo := I + 1;
                Line.NewNo := 0;
                List.Add(Line);
            end;
            for J := 0 to M - 1 do
            begin
                Line.Kind := dlInsert;
                Line.Text := B[J];
                Line.OldNo := 0;
                Line.NewNo := J + 1;
                List.Add(Line);
            end;
        end
        else
        begin
            Stride := M + 1;
            SetLength(L, (N + 1) * Stride);
            for I := N - 1 downto 0 do
                for J := M - 1 downto 0 do
                    if A[I] = B[J] then
                        L[I * Stride + J] := L[(I + 1) * Stride + J + 1] + 1
                    else
                        L[I * Stride + J] := Max(L[(I + 1) * Stride + J], L[I * Stride + J + 1]);

            I := 0;
            J := 0;
            while (I < N) or (J < M) do
            begin
                Line.OldNo := 0;
                Line.NewNo := 0;

                if (I < N) and (J < M) and (A[I] = B[J]) then
                begin
                    Line.Kind := dlEqual;
                    Line.Text := A[I];
                    Line.OldNo := I + 1;
                    Line.NewNo := J + 1;
                    Inc(I);
                    Inc(J);
                end
                else if (J = M) or ((I < N) and (L[(I + 1) * Stride + J] >= L[I * Stride + J + 1])) then
                begin
                    Line.Kind := dlDelete;
                    Line.Text := A[I];
                    Line.OldNo := I + 1;
                    Inc(I);
                end
                else
                begin
                    Line.Kind := dlInsert;
                    Line.Text := B[J];
                    Line.NewNo := J + 1;
                    Inc(J);
                end;

                List.Add(Line);
            end;
        end;

        Result := List.ToArray;
    finally
        List.Free;
    end;
end;

class function TTextDiff.ToUnified(const OldText, NewText: string;
    ContextLines: Integer): TArray<TDiffLine>;
var
    Full: TArray<TDiffLine>;
    Keep: TArray<Boolean>;
    I, J, Lo, Hi: Integer;
    List: TList<TDiffLine>;
begin
    if ContextLines < 0 then
        ContextLines := 0;

    Full := Compute(OldText, NewText);
    List := TList<TDiffLine>.Create;
    try
        if Length(Full) > 0 then
        begin
            SetLength(Keep, Length(Full));
            for I := 0 to High(Full) do
                if Full[I].Kind <> dlEqual then
                begin
                    Lo := Max(0, I - ContextLines);
                    Hi := Min(High(Full), I + ContextLines);
                    for J := Lo to Hi do
                        Keep[J] := True;
                end;

            for I := 0 to High(Full) do
                if Keep[I] then
                    List.Add(Full[I]);
        end;

        Result := List.ToArray;
    finally
        List.Free;
    end;
end;

end.
