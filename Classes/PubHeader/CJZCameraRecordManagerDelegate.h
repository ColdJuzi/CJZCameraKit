//
//  CJZCameraRecordManagerDelegate.h
//  CJZCameraKit
//
//  Created by Liang Hao on 2021/8/17.
//

#ifndef CJZCameraRecordManagerDelegate_h
#define CJZCameraRecordManagerDelegate_h

#import "CJZCameraManagerConfig.h"

@class CJZCameraRecordManager;

@protocol CJZCameraRecordManagerDelegate <NSObject>

@required
- (void)cjzCameraRecordDidFinishPreparing:(CJZCameraRecordManager *)recorder;
- (void)cjzCameraRecord:(CJZCameraRecordManager *)recorder didFailWithError:(NSError *)error;
- (void)cjzCameraRecordDidFinishRecording:(CJZCameraRecordManager *)recorder;
@end

#endif /* CJZCameraRecordManagerDelegate_h */
