param([string]$LuaDll = 'C:\Program Files\obs-studio\bin\64bit\lua51.dll')
$ErrorActionPreference = 'Stop'
if (-not (Test-Path -LiteralPath $LuaDll)) { throw 'Supply -LuaDll pointing to a Lua 5.1 compatible DLL, or run lua Tests/run.lua.' }
$escaped = $LuaDll.Replace('\','\\')
Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public static class NexusLua {
 [DllImport("$escaped", CallingConvention=CallingConvention.Cdecl)] public static extern IntPtr luaL_newstate();
 [DllImport("$escaped", CallingConvention=CallingConvention.Cdecl)] public static extern void luaL_openlibs(IntPtr L);
 [DllImport("$escaped", CallingConvention=CallingConvention.Cdecl)] public static extern int luaL_loadstring(IntPtr L, [MarshalAs(UnmanagedType.LPUTF8Str)] string s);
 [DllImport("$escaped", CallingConvention=CallingConvention.Cdecl)] public static extern int lua_pcall(IntPtr L,int a,int b,int c);
 [DllImport("$escaped", CallingConvention=CallingConvention.Cdecl)] public static extern IntPtr lua_tolstring(IntPtr L,int i,IntPtr size);
 [DllImport("$escaped", CallingConvention=CallingConvention.Cdecl)] public static extern void lua_close(IntPtr L);
}
"@
$state = [NexusLua]::luaL_newstate()
try {
 [NexusLua]::luaL_openlibs($state)
 $root = $PSScriptRoot.Replace('\','/')
 $code = "dofile('$root/run.lua')"
 $status = [NexusLua]::luaL_loadstring($state,$code)
 if ($status -eq 0) { $status = [NexusLua]::lua_pcall($state,0,0,0) }
 if ($status -ne 0) { throw [Runtime.InteropServices.Marshal]::PtrToStringUTF8([NexusLua]::lua_tolstring($state,-1,[IntPtr]::Zero)) }
} finally { [NexusLua]::lua_close($state) }
