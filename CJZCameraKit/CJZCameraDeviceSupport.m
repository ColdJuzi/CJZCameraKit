//
//  CJZCameraDeviceSupport.m
//  CJZCameraKit
//
//  Created by Liang Hao on 2021/8/17.
//

#import "CJZCameraDeviceSupport.h"
#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

@implementation CJZCameraDeviceSupport

+ (BOOL)isCameraAvailable {
    return [UIImagePickerController isCameraDeviceAvailable:UIImagePickerControllerCameraDeviceFront];
}

+ (BOOL)isCameraPermissions {
    AVAuthorizationStatus authStatus = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo];
    return !(authStatus == AVAuthorizationStatusRestricted || authStatus == AVAuthorizationStatusDenied);
}

+ (BOOL)isCameraSessionPreset:(NSString *)sessionPreset {
    if (!sessionPreset || sessionPreset.length == 0) {
        return NO;
    }
    
    NSArray* cameraSupportSessionPresetList = @[AVCaptureSessionPreset352x288,
                                                AVCaptureSessionPreset640x480,
                                                AVCaptureSessionPresetiFrame960x540,
                                                AVCaptureSessionPreset1280x720,
                                                AVCaptureSessionPresetiFrame1280x720,
                                                AVCaptureSessionPreset1920x1080,
                                                AVCaptureSessionPresetInputPriority,
                                                AVCaptureSessionPresetLow,
                                                AVCaptureSessionPresetMedium,
                                                AVCaptureSessionPresetHigh,
                                                AVCaptureSessionPresetPhoto];
    BOOL isSupport = [cameraSupportSessionPresetList containsObject:sessionPreset];
    return isSupport;
}


@end
