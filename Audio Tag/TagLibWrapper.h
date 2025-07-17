//
//  TagLibWrapper.h
//  Audio Tag
//
//  Created by Dawson Pham on 7/11/25.
//

#import <Foundation/Foundation.h>

#ifdef __cplusplus
extern "C" {
#endif

BOOL TLTagMP3(
    const char *path,
    const char *title,
    const char *artist,
    const char *album,
    const char *albumArtist,
    int         track,
    const char *genre,
    int         year,
    const char *comment,         
    const void *coverData,
    int         coverDataLength,
    const char *coverMime
);

// All returned char* are heap-allocated and must be freed with free() by the caller.
const char * TLReadTitle       (const char *path);
const char * TLReadArtist      (const char *path);
const char * TLReadAlbum       (const char *path);
const char * TLReadAlbumArtist (const char *path);
int         TLReadTrack        (const char *path);
const char * TLReadGenre       (const char *path);
int         TLReadYear         (const char *path);
const char * TLReadComment(const char *path);

#ifdef __cplusplus
}
#endif
