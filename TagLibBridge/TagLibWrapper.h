// TagLibWrapper.h

#ifdef __cplusplus
extern "C" {
#endif

#include <stdbool.h>

BOOL TLTagMP3(
    const char *filePath,
    const char *title,
    const char *artist,
    const char *album,
    const char *albumArtist,
    int         track,
    const char *genre,
    int         year,
    const void *coverData,
    int         coverDataSize,
    const char *coverMimeType
);

#ifdef __cplusplus
}
#endif
