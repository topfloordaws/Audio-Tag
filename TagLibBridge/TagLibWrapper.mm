//
//  TagLibWrapper.mm
//  Audio Tag
//
//  Created by Dawson Pham on 7/11/25.
//

#import "TagLibWrapper.h"
#import <taglib/mpegfile.h>
#import <taglib/id3v2tag.h>
#import <taglib/id3v2attachedpictureframe.h>

using namespace TagLib;

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
) {
    MPEG::File file(filePath);
    if (!file.isValid()) return NO;

    ID3v2::Tag *tag = file.ID3v2Tag(true);

    if (title)       tag->setTitle(String(title, String::UTF8));
    if (artist)      tag->setArtist(String(artist, String::UTF8));
    if (album)       tag->setAlbum(String(album, String::UTF8));
    if (albumArtist) tag->setAlbumArtist(String(albumArtist, String::UTF8));
    if (track > 0)   tag->setTrack(track);
    if (genre)       tag->setGenre(String(genre, String::UTF8));
    if (year > 0)    tag->setYear(year);

    if (coverData && coverDataSize > 0 && coverMimeType) {
        auto *pic = new ID3v2::AttachedPictureFrame();
        pic->setMimeType(String(coverMimeType, String::UTF8));
        pic->setType(ID3v2::AttachedPictureFrame::FrontCover);
        pic->setPicture(ByteVector((const char *)coverData, coverDataSize));
        tag->removeFrames("APIC");
        tag->addFrame(pic);
    }

    return file.save();
}
