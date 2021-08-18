//
//  CJZCameraManager.m
//  CJZCameraKit
//
//  Created by Liang Hao on 2021/8/17.
//

#import <UIKit/UIKit.h>
#import "CJZCameraManager.h"
#import "CJZCameraDeviceSupport.h"
#import "CJZCameraRecordManager.h"

@interface CJZCameraManager () <AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate, CJZCameraRecordManagerDelegate>
{
    AVCaptureConnection* _audioConnection;
    AVCaptureConnection* _videoConnection;
    NSString* _sessionPresetStr;
    AVCaptureVideoOrientation _videoOrientation;
    AVCaptureDevicePosition _devicePosition;
    
    dispatch_queue_t _cameraQueue;
    AVCaptureDevice* _cameraDevice;
    CJZCameraManagerPixelType _pixelType;
    
    NSUInteger _recordFPSCount;
    NSString* _videoFileNameStr;
    long _startRecordTime;
    
    BOOL _isRecordVideo;
    BOOL _isRecordAudio;
    BOOL _isStartRecord;
    BOOL _isPrepareFinish;
    BOOL _isManualInput;
}

@property (nonatomic, strong, readwrite) AVCaptureVideoPreviewLayer* videoPreview;
@property (nonatomic, strong) AVCaptureSession* cameraSession;
@property (nonatomic, strong) AVCaptureDeviceInput* cameraInput;
@property (nonatomic, strong) AVCaptureVideoDataOutput* cameraOutput;

@property (nonatomic, strong) CJZCameraRecordManager* recordManager;
@property (nonatomic, strong) NSString* recordMovieFilePathStr;
@property (nonatomic, assign) CMFormatDescriptionRef outputAudioFormatDescription;
@property (nonatomic, assign) CMFormatDescriptionRef outputVideoFormatDescription;

@end

@implementation CJZCameraManager

- (instancetype)initCameraManagerWithSessionPreset:(NSString *)sessionPreset
                                  videoOrientation:(AVCaptureVideoOrientation)videoOrientation
                                    devicePosition:(AVCaptureDevicePosition)devicePosition
                                       bufferPixel:(CJZCameraManagerPixelType)pixelType
                                       videoRecord:(BOOL)isRecordVideo
                                       audioRecord:(BOOL)isRecordAudio {
    BOOL isSessionSupport = [CJZCameraDeviceSupport isCameraSessionPreset:sessionPreset];
    if (!isSessionSupport) {
        return nil;
    }
    self = [super init];
    if (self) {
        _sessionPresetStr = sessionPreset;
        _videoOrientation = videoOrientation;
        _devicePosition = devicePosition;
        _pixelType = pixelType;
        _isRecordVideo = isRecordVideo;
        _isRecordAudio = isRecordAudio;
        
        if (_isRecordVideo) {
            _recordFPSCount = 0;
            _videoFileNameStr = @"CJZCamera.mov";
            [self defaultRecordSettings];
        }
        
        _cameraQueue = dispatch_queue_create("com.cjz.camera", NULL);
        NSString* mediaType = AVMediaTypeVideo;
        [AVCaptureDevice requestAccessForMediaType:mediaType
                                 completionHandler:^(BOOL granted) {
                                     if (!granted) {
                                         [self cameraError:CJZCameraManagerErrorNoPermission];
                                     }
                                 }];
    }
    return self;
}

- (AVCaptureVideoPreviewLayer *)videoPreview {
    if (!_videoPreview) {
        _videoPreview = [[AVCaptureVideoPreviewLayer alloc] initWithSession:self.cameraSession];
        [_videoPreview setFrame:CGRectMake(0, 0, [UIScreen mainScreen].bounds.size.width, [UIScreen mainScreen].bounds.size.height)];
        [_videoPreview setVideoGravity:AVLayerVideoGravityResizeAspectFill];
    }
    return _videoPreview;
}

#pragma mark - Session
- (void)initCameraSession {
    if (!_cameraSession) {
        _cameraSession = [[AVCaptureSession alloc] init];
        
        _cameraDevice = [self getCameraDeviceWithPosition:_devicePosition];
        //  input
        NSError* error;
        _cameraInput = [[AVCaptureDeviceInput alloc] initWithDevice:_cameraDevice
                                                              error:&error];
        if (error) {
            [self cameraError:CJZCameraManagerErrorNoAvailableDevice];
            return;
        }
        if ([_cameraSession canAddInput:_cameraInput]) {
            [_cameraSession addInput:_cameraInput];
        }
        
        //  output
        _cameraOutput = [[AVCaptureVideoDataOutput alloc] init];
        [_cameraOutput setSampleBufferDelegate:self queue:_cameraQueue];
        //  kCVPixelFormatType_32BGRA: 32 bit BGRA.
        //  kCVPixelFormatType_420YpCbCr8BiPlanarFullRange YUVNV12
        _cameraOutput.videoSettings = @{(id)kCVPixelBufferPixelFormatTypeKey : _pixelType == CJZCameraManagerPixelTypeBGRA ? @(kCVPixelFormatType_32BGRA) : @(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)};
        _cameraOutput.alwaysDiscardsLateVideoFrames = NO;
        if ([_cameraSession canAddOutput:_cameraOutput]) {
            [_cameraSession addOutput:_cameraOutput];
        }
        
        if (![_cameraSession canSetSessionPreset:_sessionPresetStr]) {
            [self cameraError:CJZCameraManagerErrorNoSessionPreset];
            return;
        }
        [_cameraSession setSessionPreset:_sessionPresetStr];
        
        _videoConnection = [_cameraOutput connectionWithMediaType:AVMediaTypeVideo];
        [_videoConnection setVideoOrientation:_videoOrientation];
        
        //  Record
        if (_isRecordVideo && _isRecordAudio) {
            AVCaptureDevice* audioDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeAudio];
            AVCaptureDeviceInput* audioInput = [[AVCaptureDeviceInput alloc] initWithDevice:audioDevice
                                                                                      error:&error];
            if (error) {
                [self cameraError:CJZCameraManagerErrorNoAvailableDevice];
                return;
            }
            if ([_cameraSession canAddInput:audioInput]) {
                [_cameraSession addInput:audioInput];
            }
            AVCaptureAudioDataOutput* audioOutput = [[AVCaptureAudioDataOutput alloc] init];
            dispatch_queue_t audioQueue = dispatch_queue_create("com.cjz.camera.audio", DISPATCH_QUEUE_SERIAL);
            [audioOutput setSampleBufferDelegate:self
                                           queue:audioQueue];
            if ([_cameraSession canAddOutput:audioOutput]) {
                [_cameraSession addOutput:audioOutput];
            }
            
            _audioConnection = [audioOutput connectionWithMediaType:AVMediaTypeAudio];
            [_cameraOutput setAlwaysDiscardsLateVideoFrames:YES];
        }
    }
}

- (void)initRecordManager {
    if (_videoFileNameStr) {
        NSString* movieFilePathStr = [NSString pathWithComponents:@[NSTemporaryDirectory(), _videoFileNameStr]];
        NSURL* filePathURL = [[NSURL alloc] initFileURLWithPath:movieFilePathStr];
        if (filePathURL && [filePathURL isFileURL]) {
            NSFileManager* fileManager = [NSFileManager defaultManager];
            [fileManager removeItemAtURL:filePathURL error:nil];
        }
        if (!_recordManager) {
            _recordMovieFilePathStr = movieFilePathStr;
            _recordManager = [[CJZCameraRecordManager alloc] initWithFilePath:movieFilePathStr];
            if (_isRecordVideo && self.outputVideoFormatDescription != NULL) {
                CGAffineTransform videoTransform = [self transformFromVideoBufferOrientationToOrientation:(AVCaptureVideoOrientation)UIDeviceOrientationPortrait];
                [self.recordManager addVideoTrackWithSourceFormatDescription:self.outputVideoFormatDescription
                                                                   transform:videoTransform];
            }
            if (_isRecordAudio && self.outputAudioFormatDescription != NULL) {
                [self.recordManager addAudioTrackWithSourceFormatDescription:self.outputAudioFormatDescription];
            }
            [self.recordManager setDelegate:self];
        }
    }
    [self.recordManager prepareToRecord];
}

- (CGAffineTransform)transformFromVideoBufferOrientationToOrientation:(AVCaptureVideoOrientation)videoOrientation {
    CGAffineTransform transform = CGAffineTransformIdentity;
    CGFloat orientationAngleOffset = [self angleOffsetFromPortraitOrientationToOrientation:videoOrientation];
    CGFloat videoOrientationAngleOffset = [self angleOffsetFromPortraitOrientationToOrientation:_videoOrientation];
    
    CGFloat angleOffset = orientationAngleOffset - videoOrientationAngleOffset;
    transform = CGAffineTransformMakeRotation(angleOffset);
    transform = CGAffineTransformRotate(transform, -M_PI);
    transform = CGAffineTransformRotate(transform, M_PI);
    if (_cameraDevice.position == AVCaptureDevicePositionFront) {
        transform = CGAffineTransformScale(transform, -1, 1);
    }
    return transform;
}

- (CGFloat)angleOffsetFromPortraitOrientationToOrientation:(AVCaptureVideoOrientation)orientation {
    CGFloat angle = 0.0;
    switch (orientation) {
        case AVCaptureVideoOrientationPortrait:
            angle = 0.0;
            break;
        case AVCaptureVideoOrientationPortraitUpsideDown:
            angle = M_PI;
            break;
        case AVCaptureVideoOrientationLandscapeRight:
            angle = -M_PI_2;
            break;
        case AVCaptureVideoOrientationLandscapeLeft:
            angle = M_PI_2;
            break;
        default:
            break;
    }
    return angle;
}

- (AVCaptureDevice *)getCameraDeviceWithPosition:(AVCaptureDevicePosition)devciePosition {
    NSArray* devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    for (AVCaptureDevice* cameraDevice in devices) {
        if ([cameraDevice position] == devciePosition) {
            return cameraDevice;
        }
    }
    return nil;
}

#pragma mark - Operation
- (void)startRunning {
    BOOL isPermissions = [CJZCameraDeviceSupport isCameraPermissions];
    if (!isPermissions) {
        [self cameraError:CJZCameraManagerErrorNoPermission];
        return;
    }
    [self initCameraSession];
    if (self.cameraSession.isRunning) {
        return;
    }
    if (self.cameraSession) {
        [self.cameraSession startRunning];
    }
}

- (void)stopRunning {
    if (_isRecordVideo) {
        [self resetRceording];
    }
    if (!self.cameraSession.isRunning) {
        return;
    }
    if (self.cameraSession) {
        [self.cameraSession stopRunning];
    }
}

- (void)startRecording {
    if (!_isRecordVideo) {
        return;
    }
    [self initRecordManager];
    _isStartRecord = YES;
}

- (void)stopRceording {
    _isStartRecord = NO;
    if (self.recordManager && self.recordManager.status == CJZCameraManagerRecordStatusRecording) {
        [self.recordManager finishRecording];
    }
    _isPrepareFinish = NO;
}

- (void)resetRceording {
    [self defaultRecordSettings];
    if (self.recordManager) {
        if (self.recordManager.status == CJZCameraManagerRecordStatusRecording) {
            [self.recordManager finishRecording];
        }
        [self.recordManager stopRecording];
        _recordManager = nil;
    }
}

#pragma mark - DeviceAdjust
- (void)resetFocusingWithFocus:(CGPoint)focus {
    AVCaptureFocusMode focusMode = AVCaptureFocusModeContinuousAutoFocus;
    BOOL isResetFocus = [_cameraDevice isFocusPointOfInterestSupported] && [_cameraDevice isFocusModeSupported:focusMode];
    BOOL isAllowPoint = (focus.x >= 0.0f && focus.y >= 0.0f && focus.x <= 1.0f && focus.y <= 1.0f) ? YES : NO;
    if (isResetFocus && isAllowPoint) {
        NSError* error;
        if ([_cameraDevice lockForConfiguration:&error]) {
            _cameraDevice.focusMode = focusMode;
            _cameraDevice.focusPointOfInterest = focus;
            [_cameraDevice unlockForConfiguration];
        }
    }
}

- (void)switchCamera {
    AVCaptureDevicePosition devicePosition = _devicePosition == AVCaptureDevicePositionBack ? AVCaptureDevicePositionFront : AVCaptureDevicePositionBack;
    [self switchCameraDevicePosition:devicePosition];
}

- (void)switchCameraDevicePosition:(AVCaptureDevicePosition)devicePosition {
    if (devicePosition == _devicePosition) {
        return;
    }
    _devicePosition = devicePosition;
    [self torchLight:NO];
    [self stopRunning];
    if (_cameraSession) {
        _cameraDevice = [self getCameraDeviceWithPosition:_devicePosition];
        NSError* error;
        AVCaptureDeviceInput* deviceInput = [AVCaptureDeviceInput deviceInputWithDevice:_cameraDevice
                                                                                  error:&error];
        if (error || !deviceInput) {
            [self cameraError:CJZCameraManagerErrorNoAvailableDevice];
            return;
        }
        [_cameraSession beginConfiguration];
        [_cameraSession removeInput:_cameraInput];
        _cameraInput = deviceInput;
        if ([_cameraSession canAddInput:_cameraInput]) {
            CATransition* animation = [CATransition animation];
            animation.type = @"oglFlip";
            animation.subtype = kCATransitionFromLeft;
            animation.duration = 0.5;
            [self.videoPreview addAnimation:animation forKey:@"flip"];
            [_cameraSession addInput:_cameraInput];
        }
        [_cameraSession commitConfiguration];
        _videoConnection = [_cameraOutput connectionWithMediaType:AVMediaTypeVideo];
    }
    [self startRunning];
}

- (void)zoomWithExpand:(float)expandV {
    
}

- (void)torchLight:(BOOL)isOpen {
    
}

#pragma mark - Record
- (void)defaultRecordSettings {
    _isStartRecord = NO;
    _isPrepareFinish = NO;
    _startRecordTime = 0;
    _recordMovieFilePathStr = nil;
}

- (void)cameraVideoRecordName:(NSString *)nameStr {
    
}

- (void)cameraVideoRecordFPS:(NSUInteger)FPS {
    
}

- (void)cameraVideoRecordManualInput:(BOOL)isManualInput {
    
}

- (void)cameraVideoRecordWithSampleBuffer:(CMSampleBufferRef)sampleBuffer
                               connection:(AVCaptureConnection *)connection {
    
}

#pragma mark - CJZCameraManagerDelegate

#pragma mark - CJZCameraRecordManagerDelegate
- (void)cjzCameraRecord:(CJZCameraRecordManager *)recorder didFailWithError:(NSError *)error {
    
}

- (void)cjzCameraRecordDidFinishPreparing:(CJZCameraRecordManager *)recorder {
    
}

- (void)cjzCameraRecordDidFinishRecording:(CJZCameraRecordManager *)recorder {
    
}

#pragma mark - Error
- (void)cameraError:(CJZCameraManagerErrorType)errorType {
    if (_delegate && [_delegate respondsToSelector:@selector(cjzCameraCaptureOutput:error:)]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [_delegate cjzCameraCaptureOutput:nil error:errorType];
        });
    }
}

#pragma mark - Version
+ (NSString *)getSDKVersion {
    return @"CJZCameraKit 0.0.1";
}

@end
