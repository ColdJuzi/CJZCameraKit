//
//  CJZCameraRecordManager.h
//  CJZCameraKit
//
//  Created by Liang Hao on 2021/8/17.
//

#import <Foundation/Foundation.h>
#import "CJZCameraRecordManagerDelegate.h"
#import "CJZCameraManagerConfig.h"

NS_ASSUME_NONNULL_BEGIN

@interface CJZCameraRecordManager : NSObject

@property (nonatomic, assign) CJZCameraManagerRecordStatus status;

- (instancetype)initWithFilePath:(NSString *)URLStr;

- (void)addVideoTrackWithSourceFormatDescription:(CMFormatDescriptionRef)formatDescription transform:(CGAffineTransform)transform;
- (void)addAudioTrackWithSourceFormatDescription:(CMFormatDescriptionRef)formatDescription;

- (void)setDelegate:(id<CJZCameraRecordManagerDelegate>)delegate; // delegate is weak referenced

- (void)prepareToRecord; // Asynchronous, might take several hundred milliseconds. When finished the delegate's recorderDidFinishPreparing: or recorder:didFailWithError: method will be called.

- (void)appendVideoSampleBuffer:(CMSampleBufferRef)sampleBuffer;
- (void)appendAudioSampleBuffer:(CMSampleBufferRef)sampleBuffer;

- (void)finishRecording; // Asynchronous, might take several hundred milliseconds. When finished the delegate's recorderDidFinishRecording: or recorder:didFailWithError: method will be called.

- (void)stopRecording;

@end

NS_ASSUME_NONNULL_END
