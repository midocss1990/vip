#pragma newdecls required

#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#include <vip_core>

public Plugin myinfo =
{
	name = "[VIP] Dissolve Body",
	author = "KOROVKA, R1KO",
	version = "1.2.2"
};

ConVar g_hCvarDelay, g_hCvarType, g_hCvarTypeFire;

float g_fDelay;
int g_Type;
int g_TypeFire;

int g_ClientTypeFire[MAXPLAYERS+1];
int g_RagdollRef[MAXPLAYERS+1];

#define VIP_DB		"DissolveBody"

public void VIP_OnVIPLoaded()
{
	VIP_RegisterFeature(VIP_DB, BOOL); 
}

public void OnPluginStart() 
{ 
	HookEvent("player_death", Event_PlayerDeath);
  
	g_hCvarDelay = CreateConVar("sm_vip_dissolve_body_delay", "1.5", "Время до растворения тела.");
	HookConVarChange(g_hCvarDelay, OnSettingChanged);
	
	g_hCvarType = CreateConVar("sm_vip_dissolve_body_type", "0", "Режим растворения тела. (0 - Рандомный режим растворения, 1 - Растворение на земле, 2 - Растворение в воздухе)");
	HookConVarChange(g_hCvarType, OnSettingChanged);
	
	g_hCvarTypeFire = CreateConVar("sm_vip_dissolve_body_type_fire", "1", "Режим поджигания тела. (0 - Выкл, 1 - Рандомный режим поджигания, 2 - Поджигать при растворение, 3 - Поджигать до растворения, а потом тушить)");
	HookConVarChange(g_hCvarTypeFire, OnSettingChanged);
	
	AutoExecConfig(true, "DissolveBody", "vip");
	
	if(VIP_IsVIPLoaded())
		VIP_OnVIPLoaded();
}

public void OnPluginEnd() 
{
	VIP_UnregisterFeature(VIP_DB);
}

public void OnConfigsExecuted()
{
	g_fDelay = GetConVarFloat(g_hCvarDelay); 
	g_Type = GetConVarInt(g_hCvarType);
	g_TypeFire = GetConVarInt(g_hCvarTypeFire);
}

public void OnSettingChanged(ConVar convar, char[] oldValue, char[] newValue)
{
	if(g_hCvarDelay == convar) g_fDelay = StringToFloat(newValue);
	else if(g_hCvarType == convar) g_Type = StringToInt(newValue);
	else if(g_hCvarTypeFire == convar) g_TypeFire = StringToInt(newValue);
}

public void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int userid = GetEventInt(event, "userid");
	int client = GetClientOfUserId(userid);

	if(client > 0 && VIP_IsClientVIP(client) && VIP_IsClientFeatureUse(client, VIP_DB))
	{
		int ragdoll = GetEntPropEnt(client, Prop_Send, "m_hRagdoll");
		if(ragdoll > 0)
		{
			g_RagdollRef[client] = EntIndexToEntRef(ragdoll);

			g_ClientTypeFire[client] = g_TypeFire;
			if(g_ClientTypeFire[client] == 1) g_ClientTypeFire[client] = GetRandomInt(2, 3);
			if(g_ClientTypeFire[client] == 3) IgniteEntity(ragdoll, g_fDelay);
			
			CreateTimer(g_fDelay, TimerDissolve, userid, TIMER_FLAG_NO_MAPCHANGE); 
		}
	}
}

public Action TimerDissolve(Handle timer, any client)
{
	if((client = GetClientOfUserId(client)) == 0) return;
	
	int ragdoll = EntRefToEntIndex(g_RagdollRef[client]);
	if(ragdoll > 0)
	{ 
		int entity = CreateEntityByName("env_entity_dissolver");
		if(entity > 0)
		{
			char sName[10]; FormatEx(sName, 10, "%d", ragdoll);
			DispatchKeyValue(ragdoll, "targetname", sName);
			DispatchKeyValue(entity, "target", sName);
			
			if(g_Type == 0) DispatchKeyValue(entity, "dissolvetype", GetRandomInt(0, 1) ? "0":"1");
			else if(g_Type == 1) DispatchKeyValue(entity, "dissolvetype", "1");
			else if(g_Type == 2) DispatchKeyValue(entity, "dissolvetype", "0");
			
			DispatchKeyValue(entity, "magnitude", "15.0");
			AcceptEntityInput(entity, "Dissolve");
			AcceptEntityInput(entity, "Kill");
		}
		
		if(g_ClientTypeFire[client] == 2) IgniteEntity(ragdoll, 4.0);
	}
}