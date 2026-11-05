unit Core.Entities.SavedQuery;

interface

const
    // Корневой узел дерева «Умные папки» (виртуальный)
    SAVED_QUERIES_ROOT_NODE_ID = -5;
    // Диапазон Node.Data узлов сохранённых запросов: -(BASE + ID).
    // BASE выше диапазона цепочек (CHAIN_NODE_ID_BASE = 1000000),
    // чтобы декодеры не пересекались
    SAVED_QUERY_NODE_ID_BASE = 2000000;

type
    TSavedQueryDTO = record
        ID: Integer;
        UserID: Integer;
        Name: string;
        // Текст запроса языка поиска (tag:, cat:, title:, comment:, fav, слова)
        QueryText: string;
        CreatedAt: Int64;
    end;

// Кодирование/декодирование Node.Data узлов умных папок
function EncodeSavedQueryNodeID(SavedQueryID: Integer): Integer;
function TryGetSavedQueryID(NodeValue: Integer; out SavedQueryID: Integer): Boolean;
function IsSavedQueriesRootNode(NodeValue: Integer): Boolean;

implementation

function EncodeSavedQueryNodeID(SavedQueryID: Integer): Integer;
begin
    Result := -(SAVED_QUERY_NODE_ID_BASE + SavedQueryID);
end;

function TryGetSavedQueryID(NodeValue: Integer; out SavedQueryID: Integer): Boolean;
begin
    Result := NodeValue <= SAVED_QUERY_NODE_ID_BASE * -1;
    if Result then
        SavedQueryID := (NodeValue * -1) - SAVED_QUERY_NODE_ID_BASE;
end;

function IsSavedQueriesRootNode(NodeValue: Integer): Boolean;
begin
    Result := NodeValue = SAVED_QUERIES_ROOT_NODE_ID;
end;

end.
