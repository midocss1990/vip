//------------------------------------------------------------------------------
// GPL LICENSE (short)
//------------------------------------------------------------------------------
/*
 * Copyright (c) 2020 R1KO, vadrozh

 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.

 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.

 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 
 * ChangeLog:
		1.0.0 -	Релиз
		1.0.1 -	Обновлено для совместимости с версией ядра 1.0.1 R
		1.0.2 -	Обновлено для совместимости с версией ядра 1.1.0 R
				Исправлена пропажа прав при перезагрузке кеша админов
		1.1.0 - Новый синтаксис, поддержка [VIP] Core 3.0 и выше
				Плагин теперь корректно выгружается из памяти и удаляет права/возвращает их в состояние до загрузки плагина
		1.1.1 - Фиксы
		1.1.2 - Фикс ошибки "Игрок не подключен"
		1.1.3 - Фикс значений кваров на инициализации
*/
#pragma semicolon 1

#include <sourcemod>
#include <vip_core>

#pragma newdecls required

public Plugin myinfo =
{
	name = "[VIP] Admin Privileges",
	author = "R1KO, vadrozh, CrazyHackGUT aka Kruzya",
	description = "Выдача группы/флагов SM по группе VIP",
	version = "1.1.3",
	url = "https://hlmod.ru"
};

Handle 	g_hTimer = INVALID_HANDLE;
float 	g_fSetAdminPrivilegesDelay, g_fSetAdminPrivilegesRepeat;

bool 	g_bUsingPlugin[MAXPLAYERS+1], g_bWasAdmin[MAXPLAYERS+1], g_bIsBackedUp[MAXPLAYERS+1];
AdminId g_aidAdminDump[MAXPLAYERS+1];
int		g_iAdminDumpFlags[MAXPLAYERS+1];

#define VIP_IMMUNITY					"SetImmunity"
#define VIP_ADMIN_FLAGS					"SetAdminFlags"
#define VIP_ADMIN_GROUP					"SetAdminGroup"

public void OnPluginStart()
{
	Handle hCvar;

	HookConVarChange((hCvar = CreateConVar("sm_vip_set_admin_privileges_delay", "5.0", "Через сколько секунд после входа VIP-игрока давать ему админские привилегии (0 - Отключить)")), OnSetAdminPrivilegesDelayChange);
	g_fSetAdminPrivilegesDelay = GetConVarFloat(hCvar);

	HookConVarChange((hCvar = CreateConVar("sm_vip_set_admin_privileges_repeat", "120.0", "Через сколько секунд повторно давать VIP-игрокам админские привилегии (0 - Отключить)")), OnSetAdminPrivilegesRepeatChange);
	g_fSetAdminPrivilegesRepeat = GetConVarFloat(hCvar);
	
	AutoExecConfig(true, "admin_privileges", "vip");
	
	if(VIP_IsVIPLoaded())
		VIP_OnVIPLoaded();
}

public void OnPluginEnd()
{
	for(int i = 1; i < MaxClients; i++)
		if(IsClientInGame(i) && !IsFakeClient(i) && VIP_IsClientVIP(i) && g_bUsingPlugin[i])
			restoreRights(i);
	VIP_UnregisterMe();
}

public void OnMapStart()
{
	if(g_fSetAdminPrivilegesRepeat)
		g_hTimer = CreateTimer(g_fSetAdminPrivilegesRepeat, Timer_Repeat, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
}

public void OnSetAdminPrivilegesDelayChange(Handle hCvar, const char[] oldValue, const char[] newValue) { g_fSetAdminPrivilegesDelay = GetConVarFloat(hCvar); }

public void OnSetAdminPrivilegesRepeatChange(Handle hCvar, const char[] oldValue, const char[] newValue)
{
	g_fSetAdminPrivilegesRepeat = GetConVarFloat(hCvar);
	KillTimerEx(g_hTimer);
}

public void OnRebuildAdminCache(AdminCachePart part) { reloadRights(); }

public void OnClientPostAdminCheck(int iClient) { OnClientDisconnect(iClient); }

public void OnClientDisconnect(int iClient)
{
	if(g_bIsBackedUp[iClient])
		RemoveAdmin(g_aidAdminDump[iClient]);
	g_bWasAdmin[iClient] = g_bUsingPlugin[iClient] = g_bIsBackedUp[iClient] = false;
	g_iAdminDumpFlags[iClient] = 0;
}

public void VIP_OnVIPLoaded()
{
	VIP_RegisterFeature(VIP_IMMUNITY, INT, HIDE);
	VIP_RegisterFeature(VIP_ADMIN_FLAGS, STRING, HIDE);
	VIP_RegisterFeature(VIP_ADMIN_GROUP, STRING, HIDE);
}

public Action Timer_Repeat(Handle hTimer)
{
	reloadRights();
	return Plugin_Continue;
}

public void VIP_OnVIPClientLoaded(int iClient)
{
	if(VIP_IsClientFeatureUse(iClient, VIP_IMMUNITY) || VIP_IsClientFeatureUse(iClient, VIP_ADMIN_FLAGS) || VIP_IsClientFeatureUse(iClient, VIP_ADMIN_GROUP))
		if(g_fSetAdminPrivilegesRepeat)
			CreateTimer(g_fSetAdminPrivilegesDelay, Timer_Delay, iClient, TIMER_FLAG_NO_MAPCHANGE);
		else
			Timer_Delay(INVALID_HANDLE, iClient);
}

public void VIP_OnVIPClientRemoved(int iClient, const char[] szReason, int iAdmin) { if(g_bUsingPlugin[iClient]) restoreRights(iClient); }

public Action Timer_Delay(Handle hTimer, int iClient)
{
	if (iClient && IsClientInGame(iClient) && VIP_IsClientVIP(iClient))
	{
		if(VIP_IsClientFeatureUse(iClient, VIP_IMMUNITY))
		{
			int iImmunity = VIP_GetClientFeatureInt(iClient, VIP_IMMUNITY);
			if(iImmunity)
			{
				AdminId iAdmin = VIP_CreateAdmin(iClient);
				if(iImmunity > GetAdminImmunityLevel(iAdmin))
					SetAdminImmunityLevel(iAdmin, iImmunity);
				g_bUsingPlugin[iClient] = true;
				backupRights(iClient);
			} else
				LogError("Неверное значение: \"%s\"", VIP_IMMUNITY);
		}
		
		if(VIP_IsClientFeatureUse(iClient, VIP_ADMIN_FLAGS))
		{
			char sBuffer[64];
			VIP_GetClientFeatureString(iClient, VIP_ADMIN_FLAGS, sBuffer, sizeof(sBuffer));
			for(int i = 0, len = strlen(sBuffer); i < len; i++)
				sBuffer[i] = CharToLower(sBuffer[i]);
			int iFlags = ReadFlagString(sBuffer);
			if(iFlags)
			{
				int iUserFlagBits = GetUserFlagBits(iClient);
				iFlags |= iUserFlagBits;
				SetUserFlagBits(iClient, iFlags);
				g_bUsingPlugin[iClient] = true;
				backupRights(iClient);
			} else
				LogError("Неверное значение: \"%s\"", VIP_ADMIN_FLAGS);
		}
		
		if(VIP_IsClientFeatureUse(iClient, VIP_ADMIN_GROUP))
		{
			char sBuffer[64];
			VIP_GetClientFeatureString(iClient, VIP_ADMIN_GROUP, sBuffer, sizeof(sBuffer));
			GroupId AdminGroup = FindAdmGroup(sBuffer);
			if(AdminGroup != INVALID_GROUP_ID)
			{
				AdminInheritGroup(VIP_CreateAdmin(iClient), AdminGroup);
				g_bUsingPlugin[iClient] = true;
				backupRights(iClient);
			} else
				LogError("Неверное значение: \"%s\"", VIP_ADMIN_GROUP);
		}
	}

	return Plugin_Stop;
}

void reloadRights()
{
	for(int i = 1; i < MaxClients; ++i)
		if(IsClientInGame(i) && !IsFakeClient(i) && VIP_IsVIPLoaded() && VIP_IsClientVIP(i))
			VIP_OnVIPClientLoaded(i);
}

void backupRights(int iClient)
{
	if(!g_bIsBackedUp[iClient] && g_bWasAdmin[iClient])
	{
		AdminId ClientAdminId = GetUserAdmin(iClient);
		if(ClientAdminId != INVALID_ADMIN_ID)
		{
			AdminId backupAdminId = CreateAdmin();
			g_iAdminDumpFlags[iClient] = GetUserFlagBits(iClient);
			
			int iGroupCount = GetAdminGroupCount(ClientAdminId);
			if(iGroupCount)
			{
				char sBuffer[256];
				for(int i = 1; i < iGroupCount; i++)
					AdminInheritGroup(backupAdminId, GetAdminGroup(ClientAdminId, i, sBuffer, sizeof(sBuffer)));
			}
			
			SetAdminImmunityLevel(backupAdminId, GetAdminImmunityLevel(ClientAdminId));
		}
		g_bIsBackedUp[iClient] = true;
	}
}

void restoreRights(int iClient)
{
	AdminId ClientAdminId = GetUserAdmin(iClient);
	if(ClientAdminId != INVALID_ADMIN_ID)
		RemoveAdmin(ClientAdminId);
	if(g_bWasAdmin[iClient] && g_bIsBackedUp[iClient] && (ClientAdminId != INVALID_ADMIN_ID))
	{
		SetUserAdmin(iClient, g_aidAdminDump[iClient], true);
		SetUserFlagBits(iClient, g_iAdminDumpFlags[iClient]);
	}
}

AdminId VIP_CreateAdmin(int iClient)
{
	AdminId ClientAdminId = GetUserAdmin(iClient);

	if(ClientAdminId == INVALID_ADMIN_ID)
	{
		ClientAdminId = CreateAdmin();
		SetUserAdmin(iClient, ClientAdminId, true);
		g_bWasAdmin[iClient] = false;
	} else
		g_bWasAdmin[iClient] = true;

	return ClientAdminId;
}

void KillTimerEx(Handle &hTimer)
{
	if(hTimer)
	{
		KillTimer(hTimer);
		hTimer = INVALID_HANDLE;
	}
}