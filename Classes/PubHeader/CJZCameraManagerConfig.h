//
//  CJZCameraManagerConfig.h
//  CJZCameraKit
//
//  Created by Liang Hao on 2021/8/17.
//

#ifndef CJZCameraManagerConfig_h
#define CJZCameraManagerConfig_h

#import <AVFoundation/AVFoundation.h>

typedef enum : NSUInteger {
    CJZCameraManagerPixelTypeBGRA,
    CJZCameraManagerPixelTypeNV12,
} CJZCameraManagerPixelType;

typedef enum : NSUInteger {
    CJZCameraManagerRecordStatusIdle = 0,
    CJZCameraManagerRecordStatusPreparingToRecord,
    CJZCameraManagerRecordStatusRecording,
    CJZCameraManagerRecordStatusFinishingRecordingPart1, // waiting for inflight buffers to be appended
    CJZCameraManagerRecordStatusFinishingRecordingPart2, // calling finish writing on the asset writer
    CJZCameraManagerRecordStatusFinished,                // terminal state
    CJZCameraManagerRecordStatusFailed                   // terminal state
} CJZCameraManagerRecordStatus;

typedef enum : NSUInteger {
    CJZCameraManagerErrorNoPermission,
    CJZCameraManagerErrorNoAvailableDevice,
    CJZCameraManagerErrorNoSessionPreset,
} CJZCameraManagerErrorType;

typedef enum : NSUInteger {
    CJZCameraReaderManagerErrorNoFilePath,
    CJZCameraReaderManagerErrorNoReader,
    CJZCameraReaderManagerErrorNoTracks,
} CJZCameraVideoManagerErrorType;

#endif /* CJZCameraManagerConfig_h */
