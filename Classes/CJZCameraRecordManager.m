//
//  CJZCameraRecordManager.m
//  CJZCameraKit
//
//  Created by Liang Hao on 2021/8/17.
//

#import "CJZCameraRecordManager.h"
#include <objc/runtime.h>

@interface CJZCameraRecordManager ()
{
    dispatch_queue_t _delegateCallbackQueue;
    dispatch_queue_t _writingQueue;
    BOOL _haveStartedSession;
//    id <CJZCameraRecordManagerDelegate> _delegate;
    
    CMFormatDescriptionRef _audioTrackSourceFormatDescription;
    CMFormatDescriptionRef _videoTrackSourceFormatDescription;
    CGAffineTransform _videoTrackTransform;
}

@property (nonatomic, strong) id <CJZCameraRecordManagerDelegate> delegate;
@property (nonatomic, strong) AVAssetWriterInput* videoInput;
@property (nonatomic, strong) AVAssetWriterInput* audioInput;
@property (nonatomic, copy) NSString* urlStr;
@property (nonatomic, strong) AVAssetWriter* assetWriter;

@end

@implementation CJZCameraRecordManager

#pragma mark - Dealloc
- (void)dealloc {
    [self teardownAssetWriterAndInputs];
}

- (void)teardownAssetWriterAndInputs {
    _audioInput = nil;
    _videoInput = nil;
    _assetWriter = nil;
    _haveStartedSession = NO;
}

#pragma mark - Init
- (instancetype)initWithFilePath:(NSString *)URLStr {
    if (!URLStr || URLStr.length == 0) {
        return nil;
    }
    self = [super init];
    if (self) {
        _writingQueue = dispatch_queue_create("com.apple.sample.movierecorder.faceidwriting", DISPATCH_QUEUE_SERIAL);
        _videoTrackTransform = CGAffineTransformIdentity;
        _urlStr = URLStr;
    }
    return self;
}

- (void)addVideoTrackWithSourceFormatDescription:(CMFormatDescriptionRef)formatDescription transform:(CGAffineTransform)transform {
    if (formatDescription == NULL) {
        @throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"Add Video Track Failed with NULL format description." userInfo:nil];
        return;
    }
    @synchronized (self) {
        if (CJZCameraManagerRecordStatusIdle != _status) {
            @throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"Add Video Track Failed with cannot add tracks while not idle." userInfo:nil];
            return;
        }
        if (_videoTrackSourceFormatDescription) {
            @throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"Add Video Track Failed with cannot add more than one video track." userInfo:nil];
            return;
        }

        _videoTrackSourceFormatDescription = (CMFormatDescriptionRef)CFRetain(formatDescription);
        _videoTrackTransform = transform;
    }
}

- (void)addAudioTrackWithSourceFormatDescription:(CMFormatDescriptionRef)formatDescription {
    if (formatDescription == NULL) {
        @throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"Add Audio Track Failed with NULL format description." userInfo:nil];
        return;
    }
    @synchronized (self) {
        if (CJZCameraManagerRecordStatusIdle != _status) {
            @throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"Add Audio Track Failed with cannot add tracks while not idle." userInfo:nil];
            return;
        }
        if (_audioTrackSourceFormatDescription) {
            @throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"Add Audio Track Failed with cannot add more than one audio track." userInfo:nil];
            return;
        }

        _audioTrackSourceFormatDescription = (CMFormatDescriptionRef)CFRetain(formatDescription);
    }
}

- (void)setDelegate:(id<CJZCameraRecordManagerDelegate>)delegate {
    if (!delegate) {
        @throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"Set Delegate Failed with Caller must provide a delegateCallbackQueue" userInfo:nil];
    }
    @synchronized (self) {
        dispatch_queue_t callBackQueue = dispatch_queue_create("com.megvii.record.callback", DISPATCH_QUEUE_SERIAL);
        _delegateCallbackQueue = callBackQueue;
        _delegate = delegate;
    }
}

- (void)prepareToRecord {
    @synchronized (self) {
        if (CJZCameraManagerRecordStatusIdle != _status) {
            @throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"Prepare Failed with Already prepared, cannot prepare again." userInfo:nil];
            return;
        }
        [self transitionToStatus:CJZCameraManagerRecordStatusPreparingToRecord error:nil];
    }
    //    DISPATCH_QUEUE_PRIORITY_LOW
    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        @autoreleasepool {
            NSError* error = nil;
            NSURL* writerURL = [NSURL fileURLWithPath:weakSelf.urlStr];
            weakSelf.assetWriter = [[AVAssetWriter alloc] initWithURL:writerURL
                                                     fileType:AVFileTypeQuickTimeMovie
                                                        error:&error];

            if (!error && self->_videoTrackSourceFormatDescription) {
                [weakSelf setupAssetWriterVideoInputWithSourceFormatDescription:self->_videoTrackSourceFormatDescription
                                                                      transform:self->_videoTrackTransform
                                                                          error:&error];
            }
            if (!error && self->_audioTrackSourceFormatDescription) {
                [weakSelf setupAssetWriterAudioInputWithSourceFormatDescription:self->_audioTrackSourceFormatDescription
                                                                          error:&error];
            }
            if (!error) {
                BOOL isSuccess = [weakSelf.assetWriter startWriting];
                if (isSuccess == NO) {
                    error = weakSelf.assetWriter.error;
                }
            }
            @synchronized (self) {
                if (error) {
                    [weakSelf transitionToStatus:CJZCameraManagerRecordStatusFailed error:error];
                } else {
                    [weakSelf transitionToStatus:CJZCameraManagerRecordStatusRecording error:nil];
                }
            }
        }
    });
}

- (void)transitionToStatus:(CJZCameraManagerRecordStatus)newStatus error:(NSError *)error {
    BOOL isShouldNotifyDelegate = NO;
    __weak typeof(self) weakSelf = self;
    if (_status != newStatus) {
        if (newStatus == CJZCameraManagerRecordStatusFinished || newStatus == CJZCameraManagerRecordStatusFailed) {
            isShouldNotifyDelegate = YES;
            dispatch_async(_writingQueue, ^{
                [self teardownAssetWriterAndInputs];
                if (newStatus == CJZCameraManagerRecordStatusFailed) {
                    NSURL* movieURL = [NSURL fileURLWithPath:weakSelf.urlStr];
                    [[NSFileManager defaultManager] removeItemAtURL:movieURL error:nil];
                }
            });
        } else if (newStatus == CJZCameraManagerRecordStatusRecording) {
            isShouldNotifyDelegate = YES;
        }
        _status = newStatus;
    }

    if (isShouldNotifyDelegate && self.delegate) {
        dispatch_async(_delegateCallbackQueue, ^{
            @autoreleasepool {
                switch (newStatus) {
                    case CJZCameraManagerRecordStatusRecording:
                        [self.delegate cjzCameraRecordDidFinishPreparing:self];
                        break;
                    case CJZCameraManagerRecordStatusFinished: {
                        [self teardownAssetWriterAndInputs];
                        self->_status = CJZCameraManagerRecordStatusIdle;
                        [self.delegate cjzCameraRecordDidFinishRecording:self];
                    }
                        break;
                    case CJZCameraManagerRecordStatusFailed:
                        [self.delegate cjzCameraRecord:self didFailWithError:error];
                        break;
                    default:
                        break;
                }
            }
        });
    }
}

- (BOOL)setupAssetWriterVideoInputWithSourceFormatDescription:(CMFormatDescriptionRef)videoFormatDescription transform:(CGAffineTransform)transform error:(NSError **)error {
    float bitsPerPixel;
    CMVideoDimensions dimensions = CMVideoFormatDescriptionGetDimensions(videoFormatDescription);
    int numberPixel = dimensions.width * dimensions.height;
    int bitsPersecond;

    if (numberPixel < 640 * 480) {
        bitsPerPixel = 4.05;
    } else {
        bitsPerPixel = 10.1;
    }
    bitsPersecond = numberPixel * bitsPerPixel;
    NSDictionary* compressionProperties = @{AVVideoAverageBitRateKey : @(bitsPersecond),
                                            AVVideoExpectedSourceFrameRateKey : @(30),
                                            AVVideoMaxKeyFrameIntervalKey : @(30),
                                            AVVideoAverageNonDroppableFrameRateKey : @(30),
                                            AVVideoMaxKeyFrameIntervalDurationKey : @(1),
                                            AVVideoProfileLevelKey : AVVideoProfileLevelH264BaselineAutoLevel,
                                            AVVideoAllowFrameReorderingKey : @(1),
                                            };
    NSDictionary* videoDefaultSettings = @{AVVideoCodecKey : AVVideoCodecH264,
                                           AVVideoWidthKey : @(dimensions.width),
                                           AVVideoHeightKey : @(dimensions.height),
                                           AVVideoCompressionPropertiesKey : compressionProperties};
    if ([_assetWriter canApplyOutputSettings:videoDefaultSettings
                                forMediaType:AVMediaTypeVideo]) {
        _videoInput = [[AVAssetWriterInput alloc] initWithMediaType:AVMediaTypeVideo
                                                     outputSettings:videoDefaultSettings
                                                   sourceFormatHint:videoFormatDescription];
        _videoInput.expectsMediaDataInRealTime = YES;
        _videoInput.transform = transform;
        if ([_assetWriter canAddInput:_videoInput]) {
            [_assetWriter addInput:_videoInput];
        } else {
            if (error) {
                *error = [[self class] cannotSetupInputError];
            }
            return NO;
        }
    } else {
        if (error) {
            *error = [[self class] cannotSetupInputError];
        }
        return NO;
    }
    return YES;
}

- (BOOL)setupAssetWriterAudioInputWithSourceFormatDescription:(CMFormatDescriptionRef)audioFormatDescription error:(NSError **)error {
    NSDictionary* audioDefaultSettings = @{AVFormatIDKey : @(kAudioFormatMPEG4AAC)};
    if ([_assetWriter canApplyOutputSettings:audioDefaultSettings
                                forMediaType:AVMediaTypeAudio]) {
        _audioInput = [[AVAssetWriterInput alloc] initWithMediaType:AVMediaTypeAudio
                                                     outputSettings:audioDefaultSettings
                                                   sourceFormatHint:audioFormatDescription];
        _audioInput.expectsMediaDataInRealTime = YES;
        if ([_assetWriter canAddInput:_audioInput]) {
            [_assetWriter addInput:_audioInput];
        } else {
            if (error) {
                *error = [[self class] cannotSetupInputError];
            }
            return NO;
        }
    } else {
        if (error) {
            *error = [[self class] cannotSetupInputError];
        }
        return NO;
    }
    return YES;
}

+ (NSError *)cannotSetupInputError {
    NSString* localizedDescription = @"Recording cannot be started";
    NSString* localizedFailureReason = @"Cannot setup asset writer input.";
    NSDictionary* errorDict = @{NSLocalizedDescriptionKey : localizedDescription,
                                NSLocalizedFailureReasonErrorKey : localizedFailureReason};
    return [NSError errorWithDomain:@"com.apple.dts.samplecode" code:0 userInfo:errorDict];
}

- (void)appendVideoSampleBuffer:(CMSampleBufferRef)sampleBuffer {
    [self appendSampleBuffer:sampleBuffer mediaType:AVMediaTypeVideo];
}

- (void)appendAudioSampleBuffer:(CMSampleBufferRef)sampleBuffer {
    [self appendSampleBuffer:sampleBuffer mediaType:AVMediaTypeAudio];
}

- (void)appendSampleBuffer:(CMSampleBufferRef)sampleBuffer mediaType:(NSString *)mediaType {
    if (sampleBuffer == NULL) {
        @throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"AppendSample Failed with NULL sample buffer" userInfo:nil];
        return;
    }
    @synchronized (self) {
        if (_status < CJZCameraManagerRecordStatusRecording) {
            @throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"AppendSample Failed with not ready to record yet." userInfo:nil];
            return;
        }
    }
    CFRetain(sampleBuffer);
    __weak typeof(self) weakSelf = self;
    dispatch_async(_writingQueue, ^{
        @autoreleasepool {
            @synchronized (self) {
                if (weakSelf.status > CJZCameraManagerRecordStatusFinishingRecordingPart1) {
                    return;
                }
            }
            if (!self->_haveStartedSession) {
                [weakSelf.assetWriter startSessionAtSourceTime:CMSampleBufferGetPresentationTimeStamp(sampleBuffer)];
                self->_haveStartedSession = YES;
            }

            AVAssetWriterInput* input = (mediaType == AVMediaTypeVideo) ? weakSelf.videoInput : weakSelf.audioInput;
            if (input.readyForMoreMediaData) {
                BOOL isSuccess = [input appendSampleBuffer:sampleBuffer];
                if (!isSuccess) {
                    NSError* error = weakSelf.assetWriter.error;
                    @synchronized (self) {
                        [self transitionToStatus:CJZCameraManagerRecordStatusFailed error:error];
                    }
                }
            }
            CFRelease(sampleBuffer);
        }
    });
}

- (void)finishRecording {
    @synchronized (self) {
        BOOL isFinishRecording = NO;
        switch (_status) {
            case CJZCameraManagerRecordStatusIdle:
            case CJZCameraManagerRecordStatusPreparingToRecord:
            case CJZCameraManagerRecordStatusFinishingRecordingPart1:
            case CJZCameraManagerRecordStatusFinishingRecordingPart2:
            case CJZCameraManagerRecordStatusFinished:
                @throw [NSException exceptionWithName:NSInternalInconsistencyException reason:@"Recording Failed with Not recording." userInfo:nil];
                break;
            case CJZCameraManagerRecordStatusFailed:
                break;
            case CJZCameraManagerRecordStatusRecording:
                isFinishRecording = YES;
            default:
                break;
        }
        if (isFinishRecording == NO) {
            return;
        }
        [self transitionToStatus:CJZCameraManagerRecordStatusFinishingRecordingPart1 error:nil];
    }
    __weak typeof(self) weakSelf = self;
    dispatch_async(_writingQueue, ^{
        @autoreleasepool {
            @synchronized (self) {
                if (weakSelf.status != CJZCameraManagerRecordStatusFinishingRecordingPart1) {
                    return;
                }
                [self transitionToStatus:CJZCameraManagerRecordStatusFinishingRecordingPart2 error:nil];
            }
            [weakSelf.assetWriter finishWritingWithCompletionHandler:^{
                @synchronized (self) {
                    NSError* error = weakSelf.assetWriter.error;
                    if (error) {
                        [self transitionToStatus:CJZCameraManagerRecordStatusFailed error:error];
                    } else {
                        [self transitionToStatus:CJZCameraManagerRecordStatusFinished error:nil];
                    }
                }
            }];
        }
    });
}

- (void)stopRecording {
    _delegate = nil;
}


@end
