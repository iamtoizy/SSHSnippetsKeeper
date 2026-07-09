object DataModuleCommon: TDataModuleCommon
  OnCreate = DataModuleCreate
  OnDestroy = DataModuleDestroy
  Height = 480
  Width = 640
  object FDQuery: TFDQuery
    Left = 264
    Top = 8
  end
  object FDManager: TFDManager
    WaitCursor = gcrNone
    FormatOptions.AssignedValues = [fvMapRules, fvStrsTrim]
    FormatOptions.OwnMapRules = True
    FormatOptions.MapRules = <>
    FormatOptions.StrsTrim = False
    Active = True
    Left = 336
    Top = 8
  end
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
  object FDGUIxWaitCursor: TFDGUIxWaitCursor
    Provider = 'Forms'
    ScreenCursor = gcrNone
    Left = 416
    Top = 8
  end
  object FDPhysSQLiteDriverLink: TFDPhysSQLiteDriverLink
    VendorLib = 'libsqlcipher-0.dll'
    Left = 144
    Top = 8
  end
end
