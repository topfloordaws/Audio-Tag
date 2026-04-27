/*
 * Copyright (c) 2021 Taner Sener
 *
 * This file is part of FFmpegKit.
 *
 * FFmpegKit is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * FFmpegKit is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General License for more details.
 *
 *  You should have received a copy of the GNU Lesser General License
 *  along with FFmpegKit.  If not, see <http://www.gnu.org/licenses/>.
 */

#ifndef FFMPEG_KIT_LEVEL_H
#define FFMPEG_KIT_LEVEL_H

/**
 * <p>Enumeration type for log levels.
 */
typedef enum {
    LevelAVLogStdErr = -16,
    LevelAVLogQuiet = -8,
    LevelAVLogPanic = 0,
    LevelAVLogFatal = 8,
    LevelAVLogError = 16,
    LevelAVLogWarning = 24,
    LevelAVLogInfo = 32,
    LevelAVLogVerbose = 40,
    LevelAVLogDebug = 48,
    LevelAVLogTrace = 56
} Level;

#endif // FFMPEG_KIT_LEVEL_H
