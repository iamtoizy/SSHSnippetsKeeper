unit Common.Consts;

interface

const
    // Уникальная строка-идентификатор для главного окна приложения
    UNIQUE_APP_STR = 'SSHSnippetsKeeper_D05F695B-8CCE-4889-A4BA-7D29CC6A8C7D';

    MAX_TAG_NAME_LENGTH = 64;
    MAX_SNIPPET_TAGS = 32;

    // Ограничения длины полей сниппета: импорт из файлов UI не проходит,
    // поэтому срезаем длину при разборе
    MAX_SNIPPET_TITLE_LENGTH = 255;
    MAX_SNIPPET_COMMENT_LENGTH = 2000;

    // Язык подсветки по умолчанию (v11, snippets.language)
    DEFAULT_SNIPPET_LANGUAGE = 'bash';

implementation

end.
