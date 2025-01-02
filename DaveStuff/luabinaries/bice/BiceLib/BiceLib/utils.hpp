#include <wtypes.h>
#include <cstdio>

#ifdef BICE_LIB_DEBUG
#define DEBUG_OUT(x) {printf("[DEBUG] [%s:%d] ", __func__, __LINE__) ; x;}
#else 
#define DEBUG_OUT(x)
#endif
#ifdef BICE_LIB_DEBUG_TRACE
#define TRACE_OUT(x) {printf("[TRACE] [%s:%d] ", __func__, __LINE__) ; x;}
#else 
#define TRACE_OUT(x)
#endif
#define INFO_OUT(x) {printf("[INFO] ") ; x;}
#define WARNING_OUT(x) {printf("[WARNING] ") ; x;}
#define ERROR_OUT(x) {printf("[ERROR] ") ; x;}

namespace utils {
	char* getCString(DWORD* addr);
}