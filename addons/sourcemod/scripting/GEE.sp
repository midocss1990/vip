#include <sourcemod>
#include <sdktools>
#include <vip_core>

#pragma semicolon 1
#pragma newdecls required

#define MAX_NADES	5

public Plugin myinfo = 
{
	name = "[VIP] Grenade Explode Effects", 
	author = "R1KO, babka68", 
	description = "После детонации гранаты, создается эффект", 
	version = "1.0", 
	url = "https://hlmod.ru/, https://vk.com/zakazserver68"
};
static const char g_sFeature[] = "GEE"; // Уникальное имя ф-и
bool g_bIsCSGO, g_bEnabled[MAX_NADES];
int g_iModelIndex[MAX_NADES], g_iHaloIndex[MAX_NADES], g_iColor[MAX_NADES][4];
float g_fStartRadius[MAX_NADES], g_fEndRadius[MAX_NADES], g_fLifeTime[MAX_NADES], g_fWidth[MAX_NADES], g_fAmplitude[MAX_NADES];

public void OnPluginStart()
{
	g_bIsCSGO = (GetEngineVersion() == Engine_CSGO);
	
	HookEvent("hegrenade_detonate", Event_GEE);
	HookEvent("flashbang_detonate", Event_GEE);
	HookEvent("smokegrenade_detonate", Event_GEE);
	
	if (g_bIsCSGO)
	{
		HookEvent("molotov_detonate", Event_GEE);
		HookEvent("decoy_detonate", Event_GEE);
	}
}

public void VIP_OnVIPLoaded()
{
	VIP_RegisterFeature(g_sFeature, BOOL);
}

public void OnMapStart()
{
	KeyValues hKeyValues = CreateKeyValues("GEE");
	char szBuffer[256];
	
	BuildPath(Path_SM, szBuffer, 256, "configs/gee.ini");
	
	if (!FileToKeyValues(hKeyValues, szBuffer))
	{
		hKeyValues.Close();
		SetFailState("Не удалось открыть файл \"%s\"", szBuffer);
	}
	
	hKeyValues.Rewind();
	
	if (hKeyValues.GotoFirstSubKey())
	{
		int i;
		char szName[16];
		for (i = 0; i < MAX_NADES; ++i)
		{
			g_bEnabled[i] = false;
		}
		
		do
		{
			if (!hKeyValues.GetNum("enabled"))
			{
				continue;
			}
			
			hKeyValues.GetSectionName(szName, sizeof(szName));
			
			if ((i = GetIndexFromName(szName)) == -1)
			{
				continue;
			}
			
			g_bEnabled[i] = true;
			
			hKeyValues.GetString("model", szBuffer, sizeof(szBuffer), "sprites/laserbeam.vmt");
			g_iModelIndex[i] = PrecacheModel(szBuffer, true);
			
			hKeyValues.GetString("model", szBuffer, sizeof(szBuffer), "sprites/glow01.vmt");
			g_iHaloIndex[i] = PrecacheModel(szBuffer, true);
			
			hKeyValues.GetColor("color", g_iColor[i][0], g_iColor[i][1], g_iColor[i][2], g_iColor[i][3]); // Цвет эффекта (RGBA)
			
			g_fStartRadius[i] = hKeyValues.GetFloat("radius_start", 5.0); // Начальный радиус
			g_fEndRadius[i] = hKeyValues.GetFloat("radius_end", 900.0); // Конечный радиус
			g_fLifeTime[i] = hKeyValues.GetFloat("life", 0.3); // Исчезает через 'x' сек
			g_fWidth[i] = hKeyValues.GetFloat("width", 5.0); // Ширина луча
			g_fAmplitude[i] = hKeyValues.GetFloat("amplitude", 25.0); // Амплитуда луча		
		}
		while (hKeyValues.GotoNextKey());
	}
	
	hKeyValues.Close();
}

int GetIndexFromName(const char[] szName)
{
	switch (szName[0])
	{
		case 'h':return 0;
		case 'f':return 1;
		case 's':return 2;
		case 'm':return 3;
		case 'd':return 4;
	}
	
	return -1;
}

public void Event_GEE(Event hEvent, const char[] szEvName, bool bDontBroadcast)
{
	int iClient = GetClientOfUserId(hEvent.GetInt("userid"));
	
	if (iClient && VIP_IsClientVIP(iClient) && VIP_IsClientFeatureUse(iClient, g_sFeature))
	{
		int j, i, iTotalClients;
		int[] iClients = new int[MaxClients];
		float fPos[3];
		
		j = GetIndexFromName(szEvName);
		
		fPos[0] = hEvent.GetFloat("x");
		fPos[1] = hEvent.GetFloat("y");
		fPos[2] = hEvent.GetFloat("z") + 5.0;
		
		i = 1;
		iTotalClients = 0;
		
		while (i <= MaxClients)
		{
			if (IsClientInGame(i) && !IsFakeClient(i))
			{
				iClients[iTotalClients++] = i;
			}
			++i;
		}
		
		TE_SetupBeamRingPoint(fPos, g_fStartRadius[j], g_fEndRadius[j], g_iModelIndex[j], g_iHaloIndex[j], 0, 0, g_fLifeTime[j], g_fWidth[j], g_fAmplitude[j], g_iColor[j], 10, 0);
		TE_Send(iClients, iTotalClients);
	}
} 