unit Core.Entities.Chain;

interface

const
    CHAINS_ROOT_NODE_ID = -4;
    CHAIN_NODE_ID_BASE = 1000000;

type
    TChainDTO = record
        ID: Integer;
        UserID: Integer;
        Name: string;
        CreatedAt: Int64;
    end;

    TChainStepDTO = record
        ID: Integer;
        ChainID: Integer;
        Position: Integer;
        SnippetID: Integer;
        SnippetTitle: string;
        PauseMs: Integer;
    end;

implementation

end.
