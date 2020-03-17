static LootCrateConfig g_LootCratesDefault;

methodmap LootPrefabsConfig < ArrayList
{
	public LootPrefabsConfig()
	{
		return view_as<LootPrefabsConfig>(new ArrayList(sizeof(LootCrateConfig)));
	}
	
	public void ReadConfig(KeyValues kv)
	{
		//Read through every prefabs
		if (kv.GotoFirstSubKey(false))
		{
			do
			{
				LootCrateConfig lootCrate;
				lootCrate = g_LootCratesDefault;
				
				//Must have a name for prefab
				kv.GetString("name", lootCrate.namePrefab, sizeof(lootCrate.namePrefab));
				if (lootCrate.namePrefab[0] == '\0')
				{
					LogError("Found prefab with missing 'name' key");
					continue;
				}
				
				lootCrate.ReadConfig(kv);
				this.PushArray(lootCrate);
			}
			while (kv.GotoNextKey(false));
			kv.GoBack();
		}
	}
	
	public int FindPrefab(const char[] name, LootCrateConfig lootBuffer)
	{
		int length = this.Length;
		for (int i = 0; i < length; i++)
		{
			LootCrateConfig lootCrate;
			this.GetArray(i, lootCrate);
			
			if (StrEqual(lootCrate.namePrefab, name))
			{
				lootBuffer = lootCrate;
				return i;
			}
		}
		
		return -1;
	}
}

static LootPrefabsConfig g_LootPrefabs;

methodmap LootCratesConfig < ArrayList
{
	public LootCratesConfig()
	{
		return view_as<LootCratesConfig>(new ArrayList(sizeof(LootCrateConfig)));
	}
	
	public void ReadConfig(KeyValues kv)
	{
		//Read through every crates
		if (kv.GotoFirstSubKey(false))
		{
			do
			{
				LootCrateConfig lootCrate;
				
				//Attempt use prefab, otherwise use default
				kv.GetString("prefab", lootCrate.namePrefab, sizeof(lootCrate.namePrefab));
				if (g_LootPrefabs.FindPrefab(lootCrate.namePrefab, lootCrate) < 0)
					lootCrate = g_LootCratesDefault;
				
				lootCrate.ReadConfig(kv);
				this.PushArray(lootCrate);
			}
			while (kv.GotoNextKey(false));
			kv.GoBack();
		}
		kv.GoBack();
	}
	
	public void SetConfig(KeyValues kv)
	{
		int length = this.Length;
		for (int configIndex = 0; configIndex < length; configIndex++)
		{
			LootCrateConfig lootCrate;
			this.GetArray(configIndex, lootCrate);
			
			if (lootCrate.load)
			{
				kv.JumpToKey("322", true);	//Just so we can create new key without jumping to existing LootCrate
				kv.SetSectionName("LootCrate");
				lootCrate.SetConfig(kv);
				kv.GoBack();
			}
		}
	}
	
	public int CreateDefault(LootCrateConfig lootCrate)
	{
		//Find any empty space to set default, otherwise create new one
		int length = this.Length;
		for (int configIndex = 0; configIndex < length; configIndex++)
		{
			this.GetArray(configIndex, lootCrate);
			if (!lootCrate.load)
			{
				lootCrate = g_LootCratesDefault;
				this.SetArray(configIndex, lootCrate);
				return configIndex;
			}
		}
		
		lootCrate = g_LootCratesDefault;
		this.PushArray(lootCrate);
		return length;
	}
	
	public void Delete(int configIndex)
	{
		//Insead of erase and shifting all arrays down, set index to an empty array with load as false
		LootCrateConfig lootCrate;
		this.SetArray(configIndex, lootCrate);
	}
}

static LootCratesConfig g_LootCrates;

void Config_Init()
{
	g_LootPrefabs = new LootPrefabsConfig();
	g_LootCrates = new LootCratesConfig();
	g_LootTable = new LootTable();
}

void Config_Refresh()
{
	g_LootPrefabs.Clear();
	
	//Load 'global.cfg' for all maps
	char filePath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, filePath, sizeof(filePath), "configs/royale/global.cfg");
	
	KeyValues kv = new KeyValues("MapConfig");
	if (kv.ImportFromFile(filePath))
	{
		if (kv.JumpToKey("BattleBus", false))
		{
			BattleBus_ReadConfig(kv);
			kv.GoBack();
		}
		
		if (kv.JumpToKey("Zone", false))
		{
			Zone_ReadConfig(kv);
			kv.GoBack();
		}
		
		if (kv.JumpToKey("LootDefault", false))
		{
			g_LootCratesDefault.ReadConfig(kv);
			kv.GoBack();
		}
		
		if (kv.JumpToKey("LootPrefabs", false))
		{
			g_LootPrefabs.ReadConfig(kv);
			kv.GoBack();
		}
	}
	
	delete kv;
	
	//Build file path
	BuildPath(Path_SM, filePath, sizeof(filePath), "configs/royale/loot.cfg");
	
	//Finally, read the config
	kv = new KeyValues("LootTable");
	if (kv.ImportFromFile(filePath))
	{
		g_LootTable.ReadConfig(kv);
		kv.GoBack();
	}
	
	delete kv;
	
	//Load map specific configs
	Confg_GetMapFilepath(filePath, sizeof(filePath));
	
	//Finally, read the config
	kv = new KeyValues("MapConfig");
	if (kv.ImportFromFile(filePath))
	{
		if (kv.JumpToKey("BattleBus", false))
		{
			BattleBus_ReadConfig(kv);
			kv.GoBack();
		}
		
		if (kv.JumpToKey("Zone", false))
		{
			Zone_ReadConfig(kv);
			kv.GoBack();
		}
		
		if (kv.JumpToKey("LootDefault", false))
		{
			g_LootCratesDefault.ReadConfig(kv);
			kv.GoBack();
		}
		
		if (kv.JumpToKey("LootPrefabs", false))
		{
			g_LootPrefabs.ReadConfig(kv);
			kv.GoBack();
		}
		
		if (kv.JumpToKey("LootCrates", false))
		{
			g_LootCrates.ReadConfig(kv);
			kv.GoBack();
		}
	}
	else
	{
		LogError("Configuration file for map could not be found at '%s'", filePath);
	}
	
	delete kv;
}

void Config_SaveLootCrates()
{
	char filePath[PLATFORM_MAX_PATH];
	Confg_GetMapFilepath(filePath, sizeof(filePath));
	
	KeyValues kv = new KeyValues("MapConfig");
	if (kv.ImportFromFile(filePath))
	{
		kv.JumpToKey("LootCrates", true);
		
		//Delete all LootCrate in config and create new one
		while (kv.DeleteKey("LootCrate")) {}
		
		g_LootCrates.SetConfig(kv);
		kv.GoBack();
		
		kv.ExportToFile(filePath);
	}
	
	delete kv;
}

void Confg_GetMapFilepath(char[] filePath, int length)
{
	char mapName[PLATFORM_MAX_PATH];
	GetCurrentMap(mapName, sizeof(mapName));
	GetMapDisplayName(mapName, mapName, sizeof(mapName));
	
	//Split map prefix and first part of its name (e.g. pl_hightower)
	char nameParts[2][PLATFORM_MAX_PATH];
	ExplodeString(mapName, "_", nameParts, sizeof(nameParts), sizeof(nameParts[]));
	
	//Stitch name parts together
	char tidyMapName[PLATFORM_MAX_PATH];
	Format(tidyMapName, sizeof(tidyMapName), "%s_%s", nameParts[0], nameParts[1]);
	
	//Build file path
	BuildPath(Path_SM, filePath, length, "configs/royale/maps/%s.cfg", tidyMapName);
}

void Config_GetDefault(LootCrateConfig lootCrate)
{
	lootCrate = g_LootCratesDefault;
}

bool Config_GetLootPrefab(int prefabIndex, LootCrateConfig lootPrefab)
{
	if (prefabIndex < 0 || prefabIndex >= g_LootPrefabs.Length)
		return false;
	
	g_LootPrefabs.GetArray(prefabIndex, lootPrefab);
	return lootPrefab.load;
}

int Config_FindPrefab(const char[] namePrefab, LootCrateConfig lootPrefab)
{
	return g_LootPrefabs.FindPrefab(namePrefab, lootPrefab)
}

bool Config_GetLootCrate(int configIndex, LootCrateConfig lootCrate)
{
	if (configIndex < 0 || configIndex >= g_LootCrates.Length)
		return false;
	
	g_LootCrates.GetArray(configIndex, lootCrate);
	return lootCrate.load;
}

void Config_SetLootCrate(int configIndex, LootCrateConfig lootCrate)
{
	g_LootCrates.SetArray(configIndex, lootCrate);
}

int Config_CreateDefault(LootCrateConfig lootCrate)
{
	return g_LootCrates.CreateDefault(lootCrate);
}

void Config_DeleteCrate(int configIndex)
{
	g_LootCrates.Delete(configIndex);
}