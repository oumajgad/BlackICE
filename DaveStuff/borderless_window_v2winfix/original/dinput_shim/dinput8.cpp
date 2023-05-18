// ganked from dsfix
#include <Windows.h>
#include "dinput8.h"

tDirectInput8Create oDirectInput8Create;

HRESULT WINAPI DirectInput8Create(HINSTANCE inst_handle, DWORD version, const IID& r_iid, LPVOID* out_wrapper, LPUNKNOWN p_unk) {
	return oDirectInput8Create(inst_handle, version, r_iid, out_wrapper, p_unk);
}
