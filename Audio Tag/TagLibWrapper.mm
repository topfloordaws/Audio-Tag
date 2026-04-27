//
//  TagLibWrapper.mm
//  Audio Tag
//
//  Enforces ID3v2-only for MP3, supports clearing fields,
//  and uses TagLib APIs that compile on typical mac builds.
//
//  Semantics when calling TLTagMP3():
//   - title/artist/album/albumArtist/genre/comment:
//       * NULL  -> leave unchanged
//       * ""    -> clear field
//   - track:
//       * < 0   -> leave unchanged
//       * == 0  -> clear
//       * > 0   -> set to that number
//   - artwork:
//       * coverData && coverDataSize > 0 && coverMimeType -> replace artwork
//       * (all NULL/0) -> leave artwork unchanged
//

#import "TagLibWrapper.h"

#import <mpegfile.h>
#import <id3v2tag.h>

// ID3v2 frame headers
#import <attachedpictureframe.h>
#import <textidentificationframe.h>
#import <commentsframe.h>

using namespace TagLib;

@implementation AudioTags
@end

// --- helpers ---

static char * copyCString(const String &s) {
    // TagLib::String::to8Bit(true) -> std::string in recent TagLib
    std::string u = s.to8Bit(true);
    return strdup(u.c_str());
}

static void removeFrames(ID3v2::Tag *tag, const char *fid) {
    if (!tag || !fid) return;
    ID3v2::FrameList list = tag->frameList(fid);
    // Remove until empty to be safe (frameList returns a snapshot)
    while (!list.isEmpty()) {
        ID3v2::Frame *f = list.front();
        tag->removeFrame(f);
        list = tag->frameList(fid);
    }
}

static void setTextFrame(ID3v2::Tag *tag, const char *fid, const String &value) {
    if (!tag || !fid) return;
    removeFrames(tag, fid);
    ID3v2::TextIdentificationFrame *frame =
        new ID3v2::TextIdentificationFrame(fid, String::UTF8);
    frame->setText(value);
    tag->addFrame(frame);
}

// --- PUBLIC API ---

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

    ID3v2::Tag *v2 = file.ID3v2Tag(true);

    // Title (TIT2)
    if (title) {
        if (title[0] == '\0') {
            v2->setTitle(String());
            removeFrames(v2, "TIT2");
        } else {
            v2->setTitle(String(title, String::UTF8));
            setTextFrame(v2, "TIT2", String(title, String::UTF8));
        }
    }

    // Artist (TPE1)
    if (artist) {
        if (artist[0] == '\0') {
            v2->setArtist(String());
            removeFrames(v2, "TPE1");
        } else {
            v2->setArtist(String(artist, String::UTF8));
            setTextFrame(v2, "TPE1", String(artist, String::UTF8));
        }
    }

    // Album (TALB)
    if (album) {
        if (album[0] == '\0') {
            v2->setAlbum(String());
            removeFrames(v2, "TALB");
        } else {
            v2->setAlbum(String(album, String::UTF8));
            setTextFrame(v2, "TALB", String(album, String::UTF8));
        }
    }

    // Album Artist (TPE2)
    if (albumArtist) {
        if (albumArtist[0] == '\0') {
            removeFrames(v2, "TPE2");
        } else {
            setTextFrame(v2, "TPE2", String(albumArtist, String::UTF8));
        }
    }

    // Track (TRCK)
    if (track >= 0) {
        removeFrames(v2, "TRCK");
        if (track == 0) {
            v2->setTrack(0);
        } else {
            v2->setTrack(track);
            setTextFrame(v2, "TRCK", String::number(track));
        }
    }

    // Genre (TCON)
    if (genre) {
        if (genre[0] == '\0') {
            v2->setGenre(String());
            removeFrames(v2, "TCON");
        } else {
            v2->setGenre(String(genre, String::UTF8));
            setTextFrame(v2, "TCON", String(genre, String::UTF8));
        }
    }

    // Year / Date (TDRC + TYER for compatibility)
    if (year >= 0) {
        if (year == 0) {
            v2->setYear(0);
            removeFrames(v2, "TDRC");
            removeFrames(v2, "TYER");
        } else {
            v2->setYear(year);
            setTextFrame(v2, "TDRC", String::number(year));
            setTextFrame(v2, "TYER", String::number(year));
        }
    }

    // Comment (COMM) — default ENG / empty description
    if (comment) {
        removeFrames(v2, "COMM");
        if (comment[0] != '\0') {
            ID3v2::CommentsFrame *cf = new ID3v2::CommentsFrame(String::UTF8);
            cf->setLanguage("eng");
            cf->setDescription(String());
            cf->setText(String(comment, String::UTF8));
            v2->addFrame(cf);
        }
        // (if empty, we already removed all COMM frames)
    }

    // Artwork (APIC)
    if (coverData && coverDataSize > 0 && coverMimeType) {
        removeFrames(v2, "APIC");
        ID3v2::AttachedPictureFrame *pic = new ID3v2::AttachedPictureFrame();
        pic->setMimeType(String(coverMimeType, String::UTF8));
        pic->setType(ID3v2::AttachedPictureFrame::FrontCover);
        pic->setPicture(ByteVector(static_cast<const char *>(coverData), coverDataSize));
        v2->addFrame(pic);
    }

    // Enforce: strip ID3v1 + APE so the file is ID3v2-only.
    file.strip(MPEG::File::ID3v1 | MPEG::File::APE);

    // Use the no-arg save and let the prior strip enforce v2-only.
    // Force ID3v2.3: Parameter 1 (ID3v2 tags), Parameter 2 (StripTags enum), Parameter 3 (ID3v2::Version enum)
    if (!file.save(MPEG::File::ID3v2, MPEG::File::StripNone, ID3v2::v3)) {
        return NO;
    }
    return YES;
}

// ---------- READERS (prefer ID3v2 only) ----------

AudioTags *TLReadAllTags(const char *path) {
    AudioTags *tags = [[AudioTags alloc] init];
    tags.title = @"";
    tags.artist = @"";
    tags.album = @"";
    tags.albumArtist = @"";
    tags.track = 0;
    tags.genre = @"";
    tags.year = 0;
    tags.comment = @"";

    MPEG::File file(path);
    if (!file.isValid()) return tags;

    ID3v2::Tag *tag = file.ID3v2Tag(false);
    if (!tag) return tags;

    tags.title = [NSString stringWithUTF8String:tag->title().to8Bit(true).c_str()] ?: @"";
    tags.artist = [NSString stringWithUTF8String:tag->artist().to8Bit(true).c_str()] ?: @"";
    tags.album = [NSString stringWithUTF8String:tag->album().to8Bit(true).c_str()] ?: @"";

    ID3v2::FrameList tpe2 = tag->frameList("TPE2");
    if (!tpe2.isEmpty()) {
        tags.albumArtist = [NSString stringWithUTF8String:tpe2.front()->toString().to8Bit(true).c_str()] ?: @"";
    }

    tags.track = tag->track();
    tags.genre = [NSString stringWithUTF8String:tag->genre().to8Bit(true).c_str()] ?: @"";
    tags.year = tag->year();

    ID3v2::FrameList comm = tag->frameList("COMM");
    if (!comm.isEmpty()) {
        ID3v2::CommentsFrame *cf = static_cast<ID3v2::CommentsFrame *>(comm.front());
        tags.comment = [NSString stringWithUTF8String:cf->toString().to8Bit(true).c_str()] ?: @"";
    }

    return tags;
}

// need to force id3v2.3f
