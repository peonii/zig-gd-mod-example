const std = @import("std");
const mh = @cImport(@cInclude("MinHook.h"));
const win = std.os.windows;

const DWORD = win.DWORD;

const DLL_PROCESS_ATTACH: DWORD = 1;
const DLL_THREAD_ATTACH: DWORD = 2;
const DLL_THREAD_DETACH: DWORD = 3;
const DLL_PROCESS_DETACH: DWORD = 0;

// In Zig, this is (as of now) the only way to interact with winapi functions.
// Thankfully std provides most WINAPI types, so this isn't that much of a hassle.
extern "user32" fn MessageBoxA(hWnd: ?win.HWND, lpText: win.LPCSTR, lpCaption: win.LPCSTR, uType: win.UINT) callconv(win.WINAPI) i32;
extern "kernel32" fn GetModuleHandleA(lpModuleName: ?win.LPCSTR) callconv(win.WINAPI) win.HMODULE;
extern "kernel32" fn CreateThread(lpThreadAttributes: ?*win.SECURITY_ATTRIBUTES, dwStackSize: win.SIZE_T, lpStartAddress: win.LPTHREAD_START_ROUTINE, lpParameter: ?*anyopaque, dwCreationFlags: win.DWORD, lpThreadId: ?*win.DWORD) callconv(win.WINAPI) win.HANDLE;
extern "kernel32" fn CloseHandle(hObject: win.HANDLE) callconv(win.WINAPI) win.BOOL;

const OrigResetLevel = fn (self: *anyopaque) callconv(.C) void;

// Zig does not allow declaring undefined variables.
// Setting an optional to null will cause an access violation.
//
// To workaround that we declare a function that has the exact signature
// of `PlayLayer::resetLevel()` but doesn't do anything.
// We can assign that function to a variable (to keep type safety and not cause access violations) and then
// let that variable be reassigned by MinHook.
pub fn fake_reset_level(self: *anyopaque) callconv(.C) void {
    _ = self;
}

var orig_reset_level: ?*OrigResetLevel = @constCast(&fake_reset_level);

// Hooks work the exact same way as C/C++.
pub fn hook_reset_level(self: *anyopaque) callconv(.C) void {
    @setRuntimeSafety(false);
    _ = MessageBoxA(null, "Restarted the level.", "woohoo", 0);

    return (orig_reset_level orelse return)(self);
}

pub export fn thread_func(hModule: win.HMODULE) callconv(win.WINAPI) win.DWORD {
    _ = hModule;

    _ = mh.MH_Initialize();
    const base = GetModuleHandleA(null);

    _ = mh.MH_CreateHook(
        @ptrFromInt(@intFromPtr(base) + 0x3958b0),
        @as(*anyopaque, @constCast(&hook_reset_level)),
        @ptrCast(@constCast(&orig_reset_level)),
    );

    _ = mh.MH_EnableHook(mh.MH_ALL_HOOKS);

    return 0;
}

pub export fn DllMain(hDll: win.HINSTANCE, fdwReason: win.DWORD, lpReserved: win.LPVOID) callconv(win.WINAPI) win.BOOL {
    _ = lpReserved;

    switch (fdwReason) {
        DLL_PROCESS_ATTACH => {
            const h = CreateThread(null, 0, @ptrCast(&thread_func), hDll, 0, null);
            if (@intFromPtr(h) != 0) {
                _ = CloseHandle(h);
            } else {
                return 0;
            }
        },
        else => {},
    }

    return 1;
}
