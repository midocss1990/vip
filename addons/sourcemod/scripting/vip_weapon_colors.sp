#include <sourcemod>
#include <sdkhooks>
#include <cstrike>
#include <vip_core>
#include <clientprefs>

#pragma semicolon 1

public Plugin myinfo = {
    name        = "[VIP] Weapon Colors",
    author      = "Ganter1234", // Не умею писать вип модули, основу кода взял отсюда https://hlmod.ru/threads/vip-aura.53410/
    version     = "1.0"
};

int g_iClientColor[MAXPLAYERS +1][4];
KeyValues g_hKv;

new Handle:g_hCookie,
    Handle:g_hmenu;

#define VIP_WEAPON_COLORS_M  "WEAPON_COLORS_M"
#define VIP_WEAPON_COLORS    "WEAPON_COLORS"

public void OnPluginStart()
{
    g_hCookie = RegClientCookie("VIP_WEAPON_COLOR", "VIP_WEAPON_COLOR", CookieAccess_Public);
}

public void OnMapStart()
{
    char buffer[256];
    if (g_hKv != INVALID_HANDLE) CloseHandle(g_hKv);
    g_hKv = CreateKeyValues("Weapon_colors");
    BuildPath(Path_SM, buffer, 256, "data/vip/modules/Weapon_colors.txt");
    if (!FileToKeyValues(g_hKv, buffer)) SetFailState("Couldn't parse file %s", buffer);
    g_hmenu = CreateMenu(WCMenuHandler);
    SetMenuExitBackButton(g_hmenu, true);
    SetMenuTitle(g_hmenu, "Цвет оружия\n ");
    KvRewind(g_hKv);
    if (KvGotoFirstSubKey(g_hKv))
    {
        do
        {
            if (KvGetSectionName(g_hKv, buffer, 256))
            {
                AddMenuItem(g_hmenu, buffer, buffer);
            }
        }
        while (KvGotoNextKey(g_hKv));
    }
    KvRewind(g_hKv);
}

public void VIP_OnVIPLoaded()
{
    VIP_RegisterFeature(VIP_WEAPON_COLORS_M, _, SELECTABLE, Open_Menu, OnDisplayItem, OnDrawItem);
    VIP_RegisterFeature(VIP_WEAPON_COLORS, BOOL, _, _);
}

void GetRGBAFromString(char[] sBuffer, int iColor[4])
{
    char sBuffers[4][4];
    ExplodeString(sBuffer, " ", sBuffers, sizeof(sBuffers), sizeof(sBuffers[]));
    iColor[0] = StringToInt(sBuffers[0]);
    iColor[1] = StringToInt(sBuffers[1]);
    iColor[2] = StringToInt(sBuffers[2]);
    iColor[3] = StringToInt(sBuffers[3]);
}

public void VIP_OnVIPClientLoaded(int client)
{
    if(VIP_IsClientFeatureUse(client, VIP_WEAPON_COLORS))
    {
        char sInfo[64];
        GetClientCookie(client, g_hCookie, sInfo, 64);
        if(sInfo[0])
        {
            GetRGBAFromString(sInfo, g_iClientColor[client]);
            return;
        }
    }
    for(int i=0; i < 4; i++) g_iClientColor[client][i] = 255;
}

public bool Open_Menu(int iClient, const char[] sFeatureName)
{
    DisplayMenu(g_hmenu, iClient, MENU_TIME_FOREVER);
    return false;
}

public int WCMenuHandler(Handle hMenu, MenuAction action, int iClient, int Item)
{
    switch(action)
    {
        case MenuAction_Cancel:
        {
            if(Item == MenuCancel_ExitBack) VIP_SendClientVIPMenu(iClient);
        }
        case MenuAction_Select:
        {
            char sInfo[64];
            GetMenuItem(hMenu, Item, sInfo, 64);
            KvRewind(g_hKv);
            if (KvJumpToKey(g_hKv, sInfo, false))
            {
                KvGetColor(g_hKv, "color", g_iClientColor[iClient][0],  g_iClientColor[iClient][1],  g_iClientColor[iClient][2],  g_iClientColor[iClient][3]);
                KvRewind(g_hKv);
                PrintToChat(iClient, " \x03Вы изменили цвет оружия на \x04%s", sInfo);
                FormatEx(sInfo, 64, "%i %i %i %i", g_iClientColor[iClient][0],  g_iClientColor[iClient][1],  g_iClientColor[iClient][2],  g_iClientColor[iClient][3]);
                SetClientCookie(iClient, g_hCookie, sInfo);
            }
            else PrintToChat(iClient, "Failed to use \"%s\"!.", sInfo);
            DisplayMenu(g_hmenu, iClient, MENU_TIME_FOREVER);
        }
    }
}

public int OnDrawItem(int iClient, const char[] sMenuOptionName, int style)
{
    return VIP_GetClientFeatureStatus(iClient, VIP_WEAPON_COLORS) != ENABLED ? ITEMDRAW_DISABLED:style;
}

public bool OnDisplayItem(int iClient, const char[] sFeatureName, char[] sDisplay, int maxlen)
{
    strcopy(sDisplay, maxlen, "Выбор цвета оружия");
    return true;
}

public bool OnDisplayItem_f(int iClient, const char[] sFeatureName, char[] sDisplay, int maxlen)
{
    FormatEx(sDisplay, maxlen, "Цвет оружия [%s]", VIP_IsClientFeatureUse(iClient, VIP_WEAPON_COLORS) ? "Включено":"Выключено");
    return true;
}

public OnClientPutInServer(client)
{
    SDKHook(client, SDKHook_WeaponCanUse, WeaponColors_WeaponCanUse);
}

public Action:CS_OnCSWeaponDrop(client, weapon)
{
    SetEntityRenderColor(weapon, 255, 255, 255, 255);
    return Plugin_Continue;
}

public Action:WeaponColors_WeaponCanUse(client, weapon)
{
    new Handle:data = CreateDataPack();
    WritePackCell(data, GetClientUserId(client));
    WritePackCell(data, weapon);
    ResetPack(data);
    
    CreateTimer(0.0, Timer_ColorWeapon, data);

    return Plugin_Continue;
}

public Action:Timer_ColorWeapon(Handle:timer, any:data)
{
    new userid = ReadPackCell(data);
    new weapon = ReadPackCell(data);
    CloseHandle(data);

    new client = GetClientOfUserId(userid);
    
    if(!client || !IsValidEdict(weapon))
        return Plugin_Stop;

    if(VIP_IsClientFeatureUse(client, VIP_WEAPON_COLORS))
    {
        SetEntityRenderMode(weapon, RENDER_TRANSCOLOR);
        SetEntityRenderColor(weapon, g_iClientColor[client][0], g_iClientColor[client][1], g_iClientColor[client][2], g_iClientColor[client][3]);
    }

    return Plugin_Stop;
}