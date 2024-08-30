#include <cstdio>

#ifdef BICE_LIB_DEBUG
#define DEBUG_OUT(x) {printf("DEBUG: %s:%d ", __func__, __LINE__) ; x;}
#else 
#define DEBUG_OUT(x)
#endif
#define INFO_OUT(x) {printf("INFO: ") ; x;}
