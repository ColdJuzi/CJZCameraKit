//
//  CJZCameraManagerDelegate.h
//  CJZCameraKit
//
//  Created by Liang Hao on 2021/8/17.
//

#ifndef CJZCameraManagerDelegate_h
#define CJZCameraManagerDelegate_h

#import "CJZCameraManagerConfig.h"

@protocol CJZCameraManagerDelegate <NSObject>

@optional
- (void)cjzCameraCaptureOutput:(AVCaptureOutput *)captureOutput
             videoSampleBuffer:(CMSampleBufferRef)sampleBuffer
                    connection:(AVCaptureConnection *)connection;

//- (void)cjzCameraCaptureOutput:(AVCaptureOutput *)captureOutput
//             videoSampleBuffer:(CMSampleBufferRef)sampleBuffer
//                    connection:(AVCaptureConnection *)connection
//                            EV:(float)evValue;

- (void)cjzCameraCaptureOutput:(AVCaptureOutput *)captureOutput
             audioSampleBuffer:(CMSampleBufferRef)sampleBuffer
                    connection:(AVCaptureConnection *)connection;

- (void)cjzCameraCaptureOutput:(AVCaptureOutput *)captureOutput
                         error:(CJZCameraManagerErrorType)error;

- (void)cjzCameraRecordFinishWithVideoPath:(NSString *)videoFilePathStr;
@end

#endif /* CJZCameraManagerDelegate_h */
