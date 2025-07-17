//
//  TagLibWrapper.mm
//  Audio Tag
//
//  Created by Dawson Pham on 7/11/25.
//

// TagLibWrapper.mm

#import "TagLibWrapper.h"
#import <mpegfile.h>
#import <id3v2tag.h>
#import <attachedpictureframe.h>
#import <textidentificationframe.h>

using namespace TagLib;

static char * copyCString(const String &s) {
    auto utf8 = s.to8Bit(true);
    return strdup(utf8.data());
}

BOOL TLTagMP3(
    const char *filePath,
    const char *title,
    const char *artist,
    const char *album,
    const char *albumArtist,
    int         track,
    const char *genre,
    int         year,
    const char *comment,
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
    if (albumArtist) {
        // Remove and re-add TPE2 (Album Artist)
        tag->removeFrames("TPE2");
        auto *frame = new ID3v2::TextIdentificationFrame("TPE2", String::UTF8);
        frame->setText(String(albumArtist, String::UTF8));
        tag->addFrame(frame);
    }
    if (track > 0)   tag->setTrack(track);
    if (genre)       tag->setGenre(String(genre, String::UTF8));
    if (year > 0)    tag->setYear(year);
    if (comment) tag->setComment(String(comment, String::UTF8));

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

const char * TLReadTitle(const char *path) {
    MPEG::File file(path);
    if (!file.isValid()) return strdup("");
    auto *tag = file.tag();
    if (!tag) return strdup("");
    return copyCString(tag->title());
}

const char * TLReadArtist(const char *path) {
    MPEG::File file(path);
    if (!file.isValid()) return strdup("");
    auto *tag = file.tag();
    if (!tag) return strdup("");
    return copyCString(tag->artist());
}

const char * TLReadAlbum(const char *path) {
    MPEG::File file(path);
    if (!file.isValid()) return strdup("");
    auto *tag = file.tag();
    if (!tag) return strdup("");
    return copyCString(tag->album());
}

const char * TLReadAlbumArtist(const char *path) {
    MPEG::File file(path);
    if (!file.isValid()) return strdup("");
    auto *tag = file.ID3v2Tag(false);
    if (!tag) return strdup("");
    auto list = tag->frameListMap()["TPE2"];
    if (!list.isEmpty()) {
        auto *f = static_cast<ID3v2::TextIdentificationFrame *>(list.front());
        return copyCString(f->toString());
    }
    return strdup("");
}

int TLReadTrack(const char *path) {
    MPEG::File file(path);
    if (!file.isValid()) return 0;
    auto *tag = file.tag();
    if (!tag) return 0;
    return tag->track();
}

const char * TLReadGenre(const char *path) {
    MPEG::File file(path);
    if (!file.isValid()) return strdup("");
    auto *tag = file.tag();
    if (!tag) return strdup("");
    return copyCString(tag->genre());
}

int TLReadYear(const char *path) {
    MPEG::File file(path);
    if (!file.isValid()) return 0;
    auto *tag = file.tag();
    if (!tag) return 0;
    return tag->year();
}

const char * TLReadComment(const char *path) {
    MPEG::File file(path);
    if (!file.isValid()) return strdup("");
    auto *tag = file.tag();
    if (!tag) return strdup("");
    return copyCString(tag->comment());
}
