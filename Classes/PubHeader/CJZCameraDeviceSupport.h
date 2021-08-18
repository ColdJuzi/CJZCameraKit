//
//  CJZCameraDeviceSupport.h
//  CJZCameraKit
//
//  Created by Liang Hao on 2021/8/17.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface CJZCameraDeviceSupport : NSObject

+ (BOOL)isCameraAvailable;

+ (BOOL)isCameraPermissions;

+ (BOOL)isCameraSessionPreset:(NSString *)sessionPreset;

@end

NS_ASSUME_NONNULL_END
