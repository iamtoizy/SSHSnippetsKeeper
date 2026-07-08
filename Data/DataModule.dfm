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
    VendorLib = 'libsqlcipher-0.dll'
    Left = 152
    Top = 8
  end
  object FDQuery: TFDQuery
    Connection = FDConnection
    Left = 264
    Top = 8
  end
  object FDManager: TFDManager
    WaitCursor = gcrDefault
    FormatOptions.AssignedValues = [fvMapRules, fvStrsTrim]
    FormatOptions.OwnMapRules = True
    FormatOptions.MapRules = <>
    FormatOptions.StrsTrim = False
    Active = True
    Left = 336
    Top = 8
  end
  object FDGUIxWaitCursor: TFDGUIxWaitCursor
    Provider = 'Console'
    ScreenCursor = gcrDefault
    Left = 432
    Top = 8
  end
end
