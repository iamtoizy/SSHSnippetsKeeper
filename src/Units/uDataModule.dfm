object DataModuleCommon: TDataModuleCommon
  OnCreate = DataModuleCreate
  OnDestroy = DataModuleDestroy
  Height = 480
  Width = 640
  object FDConnection: TFDConnection
    Params.Strings = (
      
        'Database=C:\Users\toizy\Documents\Embarcadero\Studio\Projects\Ta' +
        'bbySnippersKeeper\output\Win64\Debug\snippets.db'
      'DriverID=SQLite'
      'LockingMode=Normal'
      'SQLite3_SecurityLevel=None')
    LoginPrompt = False
    Left = 32
    Top = 8
  end
  object TFDPhysSQLiteDriverLink: TFDPhysSQLiteDriverLink
    Left = 152
    Top = 8
  end
  object FDQuery: TFDQuery
    Connection = FDConnection
    Left = 264
    Top = 8
  end
end
