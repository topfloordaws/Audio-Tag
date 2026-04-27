//
//  TagLibWrapper.h
//  Audio Tag
//
//  Created by Dawson Pham on 7/11/25.
//

#import <Foundation/Foundation.h>

// Unified payload to bridge C++ memory safely into Swift
@interface AudioTags : NSObject
@property (nonatomic, copy) NSString * _Nonnull title;
@property (nonatomic, copy) NSString * _Nonnull artist;
@property (nonatomic, copy) NSString * _Nonnull album;
@property (nonatomic, copy) NSString * _Nonnull albumArtist;
@property (nonatomic, assign) NSInteger track;
@property (nonatomic, copy) NSString * _Nonnull genre;
@property (nonatomic, assign) NSInteger year;
@property (nonatomic, copy) NSString * _Nonnull comment;
@end

#ifdef __cplusplus
extern "C" {
#endif

BOOL TLTagMP3(
    const char * _Nonnull path,
    const char * _Nullable title,
    const char * _Nullable artist,
    const char * _Nullable album,
    const char * _Nullable albumArtist,
    int         track,
    const char * _Nullable genre,
    int         year,
    const char * _Nullable comment,
    const void * _Nullable coverData,
    int         coverDataLength,
    const char * _Nullable coverMime
);

// Single O(1) pass to read all metadata
AudioTags * _Nonnull TLReadAllTags(const char * _Nonnull path);

#ifdef __cplusplus
}
#endif
