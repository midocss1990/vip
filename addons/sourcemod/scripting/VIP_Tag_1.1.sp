#pragma semicolon 1
#include <sourcemod>
#include <cstrike>
#include <vip_core>
#include <clientprefs>

public Plugin:myinfo =
{
	name = "[VIP] Tag",
	author = "R1KO",
	version = "1.1"
};

static const String:g_sFeature[][] = {"Tag", "Tag_Menu"},
			String:g_sCUSTOM[] = "custom",
			String:g_sLIST[] = "list";

new Handle:g_hCookie;
new Handle:g_hKeyValues;

new bool:g_bWaitChat[MAXPLAYERS+1];

public OnPluginStart() 
{
	g_hCookie = RegClientCookie("VIP_Tag", "VIP_Tag", CookieAccess_Private);

	LoadTranslations("vip_modules.phrases");
	LoadTranslations("vip_tag.phrases");

	if(VIP_IsVIPLoaded())
	{
		VIP_OnVIPLoaded();
	}
}

public OnPluginEnd()
{
	if(CanTestFeatures() && GetFeatureStatus(FeatureType_Native, "VIP_UnregisterFeature") == FeatureStatus_Available)
	{
		VIP_UnregisterFeature(g_sFeature[0]);
		VIP_UnregisterFeature(g_sFeature[1]);
	}
}

public VIP_OnVIPLoaded()
{
	VIP_RegisterFeature(g_sFeature[0], STRING, _, OnToggleItem, OnItemDisplay);
	VIP_RegisterFeature(g_sFeature[1], _, SELECTABLE, OnItemSelect, OnItemDisplay2, OnItemDraw);
}

public OnMapStart()
{
	decl String:sBuffer[256];

	if(g_hKeyValues != INVALID_HANDLE)
	{
		CloseHandle(g_hKeyValues);
	}

	g_hKeyValues = CreateKeyValues("Tag");
	BuildPath(Path_SM, sBuffer, 256, "data/vip/modules/tag_config.ini");

	if (FileToKeyValues(g_hKeyValues, sBuffer) == false)
	{
		CloseHandle(g_hKeyValues);
		SetFailState("Не удалось открыть файл \"%s\"", sBuffer);
	}
}

public bool:OnItemSelect(iClient, const String:sFeatureName[])
{
	decl String:sTag[64];
	VIP_GetClientFeatureString(iClient, g_sFeature[0], sTag, sizeof(sTag));
	
	if(strncmp(sTag, g_sLIST, 4) == 0)
	{
		DisplayListMenu(iClient);
		return false;
	}
	
	if(strcmp(sTag, g_sCUSTOM) == 0)
	{
		DisplayWaitChatMenu(iClient);
		return false;
	}

	VIP_SetClientFeatureStatus(iClient, g_sFeature[0], VIP_GetClientFeatureStatus(iClient,g_sFeature[0]) == ENABLED ? DISABLED:ENABLED);

	return true;
}

public Action:OnToggleItem(iClient, const String:sFeatureName[], VIP_ToggleState:OldStatus, &VIP_ToggleState:NewStatus)
{
	if(NewStatus == ENABLED)
	{
		SetVipTag(iClient);
	}
	else
	{
		CS_SetClientClanTag(iClient, "");
	}

	return Plugin_Continue;
}

public bool:OnItemDisplay(iClient, const String:sFeatureName[], String:sDisplay[], iMaxLen)
{
	if(VIP_IsClientFeatureUse(iClient, g_sFeature[0]))
	{
		decl String:sTag[64];
		VIP_GetClientFeatureString(iClient, g_sFeature[0], sTag, sizeof(sTag));

		if(strncmp(sTag, g_sLIST, 4) != 0 && strcmp(sTag, g_sCUSTOM) != 0)
		{
			SetGlobalTransTarget(iClient);
			FormatEx(sDisplay, iMaxLen, "%t [%s]", g_sFeature[0], sTag);
			return true;
		}
	}

	return false;
}

public bool:OnItemDisplay2(iClient, const String:sFeatureName[], String:sDisplay[], iMaxLen)
{
	if(VIP_IsClientFeatureUse(iClient, g_sFeature[0]))
	{
		decl String:sTag[64];
		VIP_GetClientFeatureString(iClient, g_sFeature[0], sTag, sizeof(sTag));

		if(strncmp(sTag, g_sLIST, 4) == 0 || strcmp(sTag, g_sCUSTOM) == 0)
		{
			SetGlobalTransTarget(iClient);
			sTag[0] = 0;
			GetTrieString(VIP_GetVIPClientTrie(iClient), "Tag->Tag", sTag, sizeof(sTag));
			if(!sTag[0])
			{
				FormatEx(sTag, sizeof(sTag), "%t [%t]", sFeatureName, "NotChosen");
			}

			FormatEx(sDisplay, iMaxLen, "%t [%s]", sFeatureName, sTag);
			return true;
		}
	}

	return false;
}

public OnItemDraw(iClient, const String:sFeatureName[], iStyle)
{
	decl String:sTag[8];
	VIP_GetClientFeatureString(iClient, g_sFeature[0], sTag, sizeof(sTag));

	if(strncmp(sTag, g_sLIST, 4) == 0 || strcmp(sTag, g_sCUSTOM) == 0)
	{
		switch(VIP_GetClientFeatureStatus(iClient, g_sFeature[0]))
		{
			case ENABLED: return ITEMDRAW_DEFAULT;
			case DISABLED: return ITEMDRAW_DISABLED;
			case NO_ACCESS: return ITEMDRAW_RAWLINE;
		}
	}
	else
	{
		return ITEMDRAW_RAWLINE;
	}

	return iStyle;
}

public VIP_OnPlayerSpawn(iClient, iTeam, bool:bIsVIP)
{
	if(bIsVIP && VIP_IsClientFeatureUse(iClient, g_sFeature[0]))
	{
		SetVipTag(iClient);
	}
}

SetVipTag(iClient)
{
	decl String:sTag[64];
	GetTrieString(VIP_GetVIPClientTrie(iClient), "Tag->Tag", sTag, sizeof(sTag));
	CS_SetClientClanTag(iClient, sTag);
}

public VIP_OnVIPClientLoaded(iClient)
{
	if(VIP_GetClientFeatureStatus(iClient, g_sFeature[0]) != NO_ACCESS)
	{
		decl String:sTag[64], String:sClientTag[64];
		GetClientCookie(iClient, g_hCookie, sClientTag, sizeof(sClientTag));
		VIP_GetClientFeatureString(iClient, g_sFeature[0], sTag, sizeof(sTag));

		if(!sClientTag[0])
		{
			if(strncmp(sTag, g_sLIST, 4) == 0)
			{
				KvRewind(g_hKeyValues);
				if(strlen(sTag) > 4)
				{
					strcopy(sClientTag, sizeof(sClientTag), sTag[5]);
				}
				else
				{
					strcopy(sClientTag, sizeof(sClientTag), "default");
				}
	
				if(KvJumpToKey(g_hKeyValues, sClientTag) && KvGotoFirstSubKey(g_hKeyValues, false))
				{
					KvGetString(g_hKeyValues, NULL_STRING, sClientTag, sizeof(sClientTag));
				}
				else
				{
					strcopy(sClientTag, sizeof(sClientTag), "VIP");
				}
			}
			else if(strcmp(sTag, g_sCUSTOM) == 0)
			{
				strcopy(sClientTag, sizeof(sClientTag), "VIP");
			}
			else
			{
				strcopy(sClientTag, sizeof(sClientTag), sTag);
			}
		}
		else
		{
			if(strncmp(sTag, g_sLIST, 4) != 0 && strcmp(sTag, g_sCUSTOM) != 0)
			{
				strcopy(sClientTag, sizeof(sClientTag), sTag);
			}
		}

		SetTrieString(VIP_GetVIPClientTrie(iClient), "Tag->Tag", sClientTag);

		SetVipTag(iClient);
	}
}

DisplayListMenu(iClient)
{
	SetGlobalTransTarget(iClient);
	decl String:sBuffer[64], String:sClientTag[64], Handle:hMenu;
	hMenu = CreateMenu(TagListMenu_Handler);
	SetMenuExitBackButton(hMenu, true);
	SetMenuTitle(hMenu, "%t:\n ", g_sFeature[1]);

	VIP_GetClientFeatureString(iClient, g_sFeature[0], sClientTag, sizeof(sClientTag));
	
	if(strlen(sClientTag) > 4)
	{
		strcopy(sBuffer, sizeof(sBuffer), sClientTag[5]);
	}
	else
	{
		strcopy(sBuffer, sizeof(sBuffer), "default");
	}

	KvRewind(g_hKeyValues);
	if(KvJumpToKey(g_hKeyValues, sBuffer) && KvGotoFirstSubKey(g_hKeyValues, false))
	{
		GetClientCookie(iClient, g_hCookie, sClientTag, sizeof(sClientTag));
		do
		{
			KvGetString(g_hKeyValues, NULL_STRING, sBuffer, sizeof(sBuffer));
			if(sClientTag[0] && strcmp(sBuffer, sClientTag) == 0)
			{
				Format(sBuffer, sizeof(sBuffer), "%s [X]", sBuffer);
				AddMenuItem(hMenu, "", sBuffer, ITEMDRAW_DISABLED);
				continue;
			}

			AddMenuItem(hMenu, "", sBuffer);
		}
		while (KvGotoNextKey(g_hKeyValues, false));
	}
	else
	{
		FormatEx(sBuffer, sizeof(sBuffer), "");
		AddMenuItem(hMenu, "", "TagsNotFound", ITEMDRAW_DISABLED);
	}

	DisplayMenu(hMenu, iClient, MENU_TIME_FOREVER);
}

public TagListMenu_Handler(Handle:hMenu, MenuAction:action, iClient, Item)
{
	switch(action)
	{
		case MenuAction_End: CloseHandle(hMenu);
		case MenuAction_Cancel:
		{
			if(Item == MenuCancel_ExitBack) VIP_SendClientVIPMenu(iClient);
		}
		case MenuAction_Select:
		{
			decl String:sTag[64];
			GetMenuItem(hMenu, Item, "", 0, _, sTag, sizeof(sTag));

			SetTrieString(VIP_GetVIPClientTrie(iClient), "Tag->Tag", sTag);
			
			VIP_PrintToChatClient(iClient, "\x03%t \x04%s", "SetTag", sTag);
			
			SetClientCookie(iClient, g_hCookie, sTag);
			
			SetVipTag(iClient);

			DisplayListMenu(iClient);
		}
	}
}

DisplayWaitChatMenu(iClient, const String:sValue[] = "")
{
	if(!sValue[0])
	{
		g_bWaitChat[iClient] = true;
	}

	decl Handle:hMenu, String:sBuffer[128];
	
	hMenu = CreateMenu(WaitChatMenu_Handler);

	SetGlobalTransTarget(iClient);

	if(sValue[0])
	{
		SetMenuTitle(hMenu, "%t \"%t\"\n%t: %s\n ", "EnterValueInChat", "Confirm", "Value", sValue);
	}
	else
	{
		SetMenuTitle(hMenu, "%t \"%t\"\n ", "EnterValueInChat", "Confirm");
	}

	FormatEx(sBuffer, sizeof(sBuffer), "%t", "Confirm");
	AddMenuItem(hMenu, sValue, sBuffer, sValue[0] ? ITEMDRAW_DEFAULT:ITEMDRAW_DISABLED);

	FormatEx(sBuffer, sizeof(sBuffer), "%t\n ", "Cancel");
	AddMenuItem(hMenu, "", sBuffer);

	AddMenuItem(hMenu, "", "", ITEMDRAW_NOTEXT);
	AddMenuItem(hMenu, "", "", ITEMDRAW_NOTEXT);
	AddMenuItem(hMenu, "", "", ITEMDRAW_NOTEXT);
	AddMenuItem(hMenu, "", "", ITEMDRAW_NOTEXT);

	DisplayMenu(hMenu, iClient, MENU_TIME_FOREVER);
}

public WaitChatMenu_Handler(Handle:hMenu, MenuAction:action, iClient, Item)
{
	switch(action)
	{
		case MenuAction_End: CloseHandle(hMenu);
		case MenuAction_Cancel:
		{
			g_bWaitChat[iClient] = false;
			if(Item == MenuCancel_ExitBack)
			{
				VIP_SendClientVIPMenu(iClient);
			}
		}
		case MenuAction_Select:
		{
			g_bWaitChat[iClient] = false;

			if(Item == 0)
			{
				decl String:sTag[64];
				GetMenuItem(hMenu, Item, sTag, sizeof(sTag));
				SetTrieString(VIP_GetVIPClientTrie(iClient), "Tag->Tag", sTag);
				SetClientCookie(iClient, g_hCookie, sTag);
			
				VIP_PrintToChatClient(iClient, "\x03Вы установили тег \x04%s", sTag);
				
				SetVipTag(iClient);
			}
			
			VIP_SendClientVIPMenu(iClient);
		}
	}
}

public Action:OnClientSayCommand(iClient, const String:sCommand[], const String:sArgs[])
{
	if(iClient > 0 && iClient <= MaxClients && sArgs[0])
	{
		if(g_bWaitChat[iClient])
		{
			decl String:sText[64];
			strcopy(sText, sizeof(sText), sArgs);
			TrimString(sText);
			StripQuotes(sText);
			
			if(sText[0])
			{
				DisplayWaitChatMenu(iClient, sText);
			}

			return Plugin_Handled;
		}
	}

	return Plugin_Continue;
}