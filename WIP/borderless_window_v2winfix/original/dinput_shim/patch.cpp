#include <Windows.h>
#include <stdio.h>
#include "SafeWrite.h"
#include "patch.h"
#include <ShlObj.h>
#include <Shlwapi.h>
#pragma comment(lib, "shlwapi")

#include <string>
#include <vector>
#include <map>

using namespace std;

// forward dec
void __stdcall doGetCursorPos(HWND hwnd, int isFullscreen, POINT* pt);
void modifiedGetCursorPos();

//typedef unsigned char byte;

// ASLR stuff
bool g_haveBase = false;
UInt32 g_base = 0;
const UInt32 defaultBase = 0x0;
UInt32 rebase(UInt32 address)
{
	if (!g_haveBase)
	{
		g_haveBase = true;
		g_base = (UInt32)GetModuleHandle(NULL);
	}
	return (address - defaultBase) + g_base;
}

// why
enum When {
	Always,
	Borderless
};

struct replacement
{
	When when;
	UInt32 address;
	vector<byte> value;
	vector<byte> compare;

	enum {
		Normal,
		Jmp,
		Call,
	} type = Normal;

	template<typename T>
	static vector<byte> to_vec(const T& value)
	{
		vector<byte> ary(sizeof(T));
		for (size_t i = 0; i < sizeof(T); i++)
		{
			ary[i] = (byte)((value >> (i * 8)) & 0xFF);
		}
		return ary;
	}

	template<>
	static vector<byte> to_vec(const vector<byte>& value)
	{
		return value;
	}

	static UInt32 to_uint(const vector<byte>& value)
	{
		if (value.size() != 4)
			return 0;
		return (value[0] << 0) | (value[1] << 8) | (value[2] << 16) | (value[3] << 24);
	}
	
	template<typename T>
	replacement(When when, UInt32 address, const T& value)
		: when(when), address(address), value(to_vec(value)) {};

	template<typename T, typename U>
	replacement(When when, UInt32 address, const T& value, const U& compare)
		: when(when), address(address), value(to_vec(value)), compare(to_vec(compare)) {};
	
	// assumes func pointer, casts to uint
	template<typename T>
	replacement(When when, UInt32 address, decltype(type) type, T func)
		: when(when), address(address), type(type), value(to_vec((UInt32)func)) {};

	template<typename T, typename U>
	replacement(When when, UInt32 address, decltype(type) type, T func, const U& compare)
		: when(when), address(address), type(type), value(to_vec((UInt32)func)), compare(to_vec(compare)) {}

	bool replace()
	{
		auto addr = rebase(address);
		if (compare.size() > 0)
		{
			if (memcmp((void*)addr, &compare[0], compare.size()))
				return false;
		}
		switch (type)
		{
		case Normal:
			SafeWriteBuf(addr, &value[0], (UInt32)value.size());
			break;
		case Jmp:
			WriteRelJump(addr, to_uint(value));
			break;
		case Call:
			WriteRelCall(addr, to_uint(value));
			break;
		}
		
		return true;
	}
};

// same for v2 and hoi3 and mote, except addr obv
// mouse pos stuff
/*
push ebp
mov ebp, esp
sub esp, 18h
push esi
lea eax, [ebp-8]
push eax
mov esi, ecx
;call ...
*/
// this shit could fuck up real bad assuming the following bytes are found at one of the following addresses
// but whata are the chances of thAT happening/???????????????????? NOT GOOD ffffffffuuuuuuuuuucccccckkkkkkkk yyyyyyoooooouuuuuu
const vector<byte> PREV_GETMOUSEPOS{ 0x55, 0x8B, 0xEC, 0x83, 0xEC, 0x18, 0x56, 0x8D, 0x45, 0xF8, 0x50, 0x8B, 0xF1 };

/*
Rome slightly diff
sub esp, 18h
push esi
lea eax, [esp+4]
push eax
mov esi, ecx
;call ...
*/
const vector<byte> ROME_PREV_GETMOUSEPOS{ 0x83, 0xEC, 0x18, 0x56, 0x8D, 0x44, 0x24, 0x04, 0x50, 0x8B, 0xF1 };

const DWORD NEW_STYLE = WS_POPUP;

map<wstring, vector<replacement>> replacements{
	{ L"v2game.exe", {
		{ Always, 0x677950, replacement::Jmp, modifiedGetCursorPos, PREV_GETMOUSEPOS },
		// window styles:
		// + 1 as 1 byte ins, 4 byte operand
		{ Borderless, 0x005DD419 + 1, WS_POPUP, WS_OVERLAPPEDWINDOW },  // add, AdjustWindowRect -- necessary??
		{ Borderless, 0x005DD248 + 1, WS_POPUP, WS_OVERLAPPEDWINDOW }, // push, AdjustWindowRect
		{ Borderless, 0x00592195 + 1, WS_POPUP, WS_OVERLAPPEDWINDOW }, // push, AdjustWindowRect -- necessary??
		//{ 0x005B5BFC+1, WS_POPUP, WS_OVERLAPPEDWINDOW }, // push, CreateWindowEx
		{ Borderless, 0x005DD297 + 1, WS_POPUP, WS_OVERLAPPEDWINDOW }, // push, CreateWindowEx

		// dealing with the 30 px offset:

		// nop out
		{ Borderless, 0x005DD22C, vector<byte>{ 0x90, 0x90, 0x90 }, vector<byte>{ 0x83, 0xC1, 0x1E } }, // add ecx, 0x1e
		{ Borderless, 0x005DD230, vector<byte>{ 0x90, 0x90, 0x90 }, vector<byte>{ 0x83, 0xC2, 0x1E } }, // add edx, 0x1e

		// change from push 0x1E to push 0x00 (twice):
		{ Borderless, 0x005DD234, vector<byte>{ 0x6a, 0x00, 0x6a, 0x00 }, vector<byte>{ 0x6a, 0x1E, 0x6a, 0x1E } },
	} },

	// hoi3 3.05
	{ L"hoi3game.exe", {
		{ Always, 0x684320, replacement::Jmp, modifiedGetCursorPos, PREV_GETMOUSEPOS },

		// window styles (see above)
		{ Borderless, 0x005D3F91 + 1, WS_POPUP, WS_OVERLAPPEDWINDOW },
		{ Borderless, 0x005E74A5 + 2, WS_POPUP, WS_OVERLAPPEDWINDOW },
		{ Borderless, 0x005E806E + 1, WS_POPUP, WS_OVERLAPPEDWINDOW },
		{ Borderless, 0x005E80A3 + 1, WS_POPUP, WS_OVERLAPPEDWINDOW },
		// 005EE235

		{ Borderless, 0x005E8056, vector<byte>{ 0x90, 0x90, 0x90 }, vector<byte>{ 0x83, 0xC3, 0x1E } }, // add ebx, 0x1e
		{ Borderless, 0x005E805A, vector<byte>{ 0x90, 0x90, 0x90 }, vector<byte>{ 0x83, 0xC0, 0x1E } }, // add eax, 0x1e
		{ Borderless, 0x005E805E, vector<byte>{ 0x6a, 0x00, 0x6a, 0x00 }, vector<byte>{ 0x6a, 0x1E, 0x6a, 0x1E } } // double push 1e to 00
	} },

	// Hoi3 4 (tfh)
	{ L"hoi3_tfh.exe", {
		{ Always, 0x74EF60, replacement::Jmp, modifiedGetCursorPos, PREV_GETMOUSEPOS },

		{ Borderless, 0x0066E0D5 + 1, WS_POPUP, WS_OVERLAPPEDWINDOW },
		{ Borderless, 0x00691729 + 1, WS_POPUP, WS_OVERLAPPEDWINDOW },
		{ Borderless, 0x00691558 + 1, WS_POPUP, WS_OVERLAPPEDWINDOW },
		{ Borderless, 0x006915A7 + 1, WS_POPUP, WS_OVERLAPPEDWINDOW },

		{ Borderless, 0x0069153C, vector<byte>{ 0x90, 0x90, 0x90 }, vector<byte>{ 0x83, 0xC1, 0x1E } }, // add ecx, 0x1e
		{ Borderless, 0x00691540, vector<byte>{ 0x90, 0x90, 0x90 }, vector<byte>{ 0x83, 0xC2, 0x1E } }, // add edx, 0x1e
		{ Borderless, 0x00691544, vector<byte>{ 0x6a, 0x00, 0x6a, 0x00 }, vector<byte>{ 0x6a, 0x1E, 0x6a, 0x1E } } // double push 1e to 00
	} },

	// MotE
	{ L"mote.exe", {
		{ Always, 0x1086E0, replacement::Jmp, modifiedGetCursorPos, PREV_GETMOUSEPOS },

		{ Borderless, 0x00022351 + 1, WS_POPUP, WS_OVERLAPPEDWINDOW },
		{ Borderless, 0x00069AF8 + 1, WS_POPUP, WS_OVERLAPPEDWINDOW },
		{ Borderless, 0x00069B47 + 1, WS_POPUP, WS_OVERLAPPEDWINDOW },
		{ Borderless, 0x00069CA9 + 1, WS_POPUP, WS_OVERLAPPEDWINDOW },
		
		{ Borderless, 0x00069ADC, vector<byte>{ 0x90, 0x90, 0x90 }, vector<byte>{ 0x83, 0xC1, 0x1E } }, // add ecx, 0x1e
		{ Borderless, 0x00069AE0, vector<byte>{ 0x90, 0x90, 0x90 }, vector<byte>{ 0x83, 0xC2, 0x1E } }, // add edx, 0x1e
		{ Borderless, 0x00069AE4, vector<byte>{ 0x6a, 0x00, 0x6a, 0x00 }, vector<byte>{ 0x6a, 0x1E, 0x6a, 0x1E } } // double push 1e to 00
	} },

	// Sengoku
	{ L"SengokuGame.exe", {
		{ Always, 0x397FB0, replacement::Jmp, modifiedGetCursorPos, PREV_GETMOUSEPOS },

		{ Borderless, 0x002E8F1B + 1, WS_POPUP, WS_OVERLAPPEDWINDOW },
		{ Borderless, 0x0032167D + 2, WS_POPUP, WS_OVERLAPPEDWINDOW },
		{ Borderless, 0x0032225F + 1, WS_POPUP, WS_OVERLAPPEDWINDOW },
		{ Borderless, 0x00322294 + 1, WS_POPUP, WS_OVERLAPPEDWINDOW },

		{ Borderless, 0x00322247, vector<byte>{ 0x90, 0x90, 0x90 }, vector<byte>{ 0x83, 0xC3, 0x1E } }, // add ebx, 0x1e
		{ Borderless, 0x0032224B, vector<byte>{ 0x90, 0x90, 0x90 }, vector<byte>{ 0x83, 0xC0, 0x1E } }, // add eax, 0x1e
		{ Borderless, 0x0032224F, vector<byte>{ 0x6a, 0x00, 0x6a, 0x00 }, vector<byte>{ 0x6a, 0x1E, 0x6a, 0x1E } } // double push 1e to 00
	} },

	// EU3
	{ L"eu3game.exe", {
		{ Always, 0x100D30, replacement::Jmp, modifiedGetCursorPos, PREV_GETMOUSEPOS },

		{ Borderless, 0x00036D31 + 1, WS_POPUP, WS_OVERLAPPEDWINDOW },
		{ Borderless, 0x0004BD88 + 1, WS_POPUP, WS_OVERLAPPEDWINDOW },
		{ Borderless, 0x0004BF39 + 1, WS_POPUP, WS_OVERLAPPEDWINDOW },
		{ Borderless, 0x0004BDD7 + 1, WS_POPUP, WS_OVERLAPPEDWINDOW },

		{ Borderless, 0x0004BD6C, vector<byte>{ 0x90, 0x90, 0x90 }, vector<byte>{ 0x83, 0xC1, 0x1E } }, // add ecx, 0x1e
		{ Borderless, 0x0004BD70, vector<byte>{ 0x90, 0x90, 0x90 }, vector<byte>{ 0x83, 0xC2, 0x1E } }, // add edx, 0x1e
		{ Borderless, 0x0004BD74, vector<byte>{ 0x6a, 0x00, 0x6a, 0x00 }, vector<byte>{ 0x6a, 0x1E, 0x6a, 0x1E } } // double push 1e to 00
	} },
};

map<wstring, vector<replacement>> post_hook_replacements{
	// EU: Rome
	{ L"RomeGame.exe", {
		{ Always, 0x4FB5B0, replacement::Jmp, modifiedGetCursorPos, ROME_PREV_GETMOUSEPOS },

		//{ Borderless, 0x004654CA + 1, WS_POPUP, WS_OVERLAPPEDWINDOW },
		{ Borderless, 0x0046632B + 1, WS_POPUP, WS_OVERLAPPEDWINDOW },
		{ Borderless, 0x00466365 + 1, WS_POPUP, WS_OVERLAPPEDWINDOW },
		{ Borderless, 0x004654CA + 1, WS_POPUP, WS_OVERLAPPEDWINDOW },

		{ Borderless, 0x00466312, vector<byte>{ 0x90, 0x90, 0x90 }, vector<byte>{ 0x83, 0xC6, 0x1E } }, // add esi, 0x1e
		{ Borderless, 0x00466316, vector<byte>{ 0x90, 0x90, 0x90 }, vector<byte>{ 0x83, 0xC1, 0x1E } }, // add ecx, 0x1e
		{ Borderless, 0x0046631A, vector<byte>{ 0x6a, 0x00, 0x6a, 0x00 }, vector<byte>{ 0x6a, 0x1E, 0x6a, 0x1E } } // double push 1e to 00
	} },
};

/*
void thiscall GetCursorPos(POINT*)
-- could be POINT* GCP(POINT*) as eax is left as the first argument
this is passed as ecx, HWND is ecx+0xcc, fullscreen(?) is ecx+0xD0,

orig version is equiv to:

someclass::GetMousePos(POINT * pt)
{
::GetCursorPos(pt);
RECT win;
::GetWindowRect(this->hwnd, &win)

if (!this->fullscreen) {
int yv = GetSystemMetrics(SM_CYCAPTION) + GetSystemMetrics(SM_CYFIXEDFRAME);
win.top += yv;
win.left += 4; //!!<-- fixed as + 4 (correct for windows classic, maybe XP, not for the thick ass borders of vista and later)
}

pt->x = pt->x - win.left;
pt->y = pt->y - win.top;
}

basically an incorrect (depending, would be correct depending on your theme i guess) reimplementation of ScreenToClient
and I know I tried the same thing before I learned about ScreenToClient too

reimplement as:
*/
void __stdcall doGetCursorPos(HWND hwnd, int isFullscreen, POINT* pt)
{
	GetCursorPos(pt);
	ScreenToClient(hwnd, pt);
}

/*
also, kinda important, but GetCursorPos is referenced in another function that runs in the game loop,
dont know what the fuck it does, but it doesnt seem to give too much of a shit about window stuff
and i decided to try this and hey it worked. maybe somethings inconsistent though?
*/

// boy howdy im dumb
__declspec(naked) void modifiedGetCursorPos() // void(?) thiscall somewindowclass::GetMousePos(POINT * ptOut)
{
__asm {
	mov eax, [ecx + 0xCC] // hwnd
	mov edx, [ecx + 0xD0] // is fullscreen
	mov ecx, [esp + 4] // what we wanna modify (POINT*)
	push ecx
	push edx
	push eax
	call doGetCursorPos // stdcall
	mov eax, [esp + 4] // don't know if this is ever checked, likely void type
	ret 4
}
}

// settings
BOOL g_borderless = FALSE;

void readSettings()
{
	wchar_t settings_path[MAX_PATH];
	SHGetFolderPathW(NULL, CSIDL_PERSONAL | CSIDL_FLAG_CREATE, NULL, 0, settings_path);
	PathAppendW(settings_path, L"Paradox Interactive");
	PathAppendW(settings_path, L"v2winfix.ini");
	if (!PathFileExistsW(settings_path))
	{
		WritePrivateProfileStringW(L"v2winfix", L"borderless", L"1", settings_path);
	}
	g_borderless = GetPrivateProfileIntW(L"v2winfix", L"borderless", 0, settings_path);
}

template<size_t N>
void getExeName(wchar_t(&dest)[N])
{
	wchar_t buf[MAX_PATH];
	GetModuleFileNameW(GetModuleHandle(NULL), buf, ARRAYSIZE(buf));
	PathStripPathW(buf);
	wcscpy_s(dest, buf);
}

void do_replacement(replacement& r)
{
	if (!r.replace())
	{
		char msgbuf[8192];
		sprintf(msgbuf, "Replacement failed for %08x", r.address);
		MessageBoxA(NULL, msgbuf, "v2winfix error", MB_OK | MB_ICONERROR);
	}
}

void do_replacements(vector<replacement>& r)
{
	for (auto i = r.begin(); i != r.end(); i++)
	{
		switch (i->when)
		{
		case Always:
			do_replacement(*i);
			break;
		case Borderless:
			if (g_borderless)
				do_replacement(*i);
			break;
		}
	}
}

// HAMMER IT HOME UGLY AS SIN, SIMILAR SOUNDING FUNCTION NAMES EVERYWHERE
vector<replacement> * g_delayed = nullptr;
UInt32 g_oldAddr = 0;
byte g_oldBytes[5];

void __stdcall doPatch()
{
	do_replacements(*g_delayed);
	// restore old function
	SafeWriteBuf(g_oldAddr, g_oldBytes, ARRAYSIZE(g_oldBytes));
	FlushInstructionCache(GetCurrentProcess(), NULL, 0);
}

__declspec(naked) void hookedFunction()
{
__asm {
	call doPatch
	jmp g_oldAddr
}
}

void doApiPatch(vector<replacement>& r)
{
	// replace first 5 bytes with a jump to our hook (which will restore, and then call back into it)
	g_delayed = &r;
	g_oldAddr = (UInt32)GetProcAddress(GetModuleHandle(L"user32.dll"), "FindWindowExA");
	memcpy(g_oldBytes, (void*)g_oldAddr, ARRAYSIZE(g_oldBytes));
	WriteRelJump(g_oldAddr, (UInt32)hookedFunction);
	FlushInstructionCache(GetCurrentProcess(), NULL, 0);
}

void applyPatch(bool verbose)
{
	bool found = false;
	wchar_t exeName[MAX_PATH];
	getExeName(exeName);

	for (auto i = replacements.begin(); i != replacements.end(); i++)
	{
		if (!wcsicmp(i->first.c_str(), exeName))
		{
			found = true;
			if (verbose)
				MessageBoxA(NULL, "Found executable", "v2winfix", MB_OK | MB_ICONASTERISK);
			do_replacements(i->second);
			break;
		}
	}

	if (!found)
	{
		for (auto i = post_hook_replacements.begin(); i != post_hook_replacements.end(); i++)
		{
			if (!wcsicmp(i->first.c_str(), exeName))
			{
				found = true;
				if (verbose)
					MessageBoxA(NULL, "Found executable", "v2winfix", MB_OK | MB_ICONASTERISK);
				doApiPatch(i->second);
				break;
			}
		}
	}
	
	if (!found)
	{
		MessageBoxA(NULL, "Couldn't find cursor function (only compatible with Victoria 2, Hearts of Iron 3, March of the Eagles, Sengoku, Europa Universalis 3, and Europa Universalis: Rome.)"
			"The game will function normally (that is, broke ass cursor).", "v2winfix error", MB_OK | MB_ICONERROR);
	}
}