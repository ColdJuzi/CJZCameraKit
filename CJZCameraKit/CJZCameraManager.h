//
//  CJZCameraManager.h
//  CJZCameraKit
//
//  Created by Liang Hao on 2021/8/17.
//

#import <Foundation/Foundation.h>
#import "CJZCameraManagerConfig.h"
#import "CJZCameraManagerDelegate.h"

NS_ASSUME_NONNULL_BEGIN

@interface CJZCameraManager : NSObject <CJZCameraManagerDelegate>

@property (nonatomic, weak) id <CJZCameraManagerDelegate> delegate;

/**
 初始化照相机管理器

 @param sessionPreset 配置照相机分辨率，请参照`AVCaptureSessionPreset`
 @param videoOrientation 配置照相机预览方向
 @param devicePosition 配置照相机设备（前置\后置）
 @param pixelType 配置照相机的输出类型。一般情况下使用BGRA的格式
 @param isRecordVideo 是否进行视频录制。该管理器中内置了一个照相机视频录制。录制内容为原始数据。如果需要对pixelbuffer进行处理后录制，请使用"CJZCameraRecordManager"手动处理
 @param isRecordAudio 是否进行音频录制（录制音频必须同时选中视频录制）
 @return 初始化对象
 */
- (instancetype)initCameraManagerWithSessionPreset:(NSString *)sessionPreset
                                  videoOrientation:(AVCaptureVideoOrientation)videoOrientation
                                    devicePosition:(AVCaptureDevicePosition)devicePosition
                                       bufferPixel:(CJZCameraManagerPixelType)pixelType
                                       videoRecord:(BOOL)isRecordVideo
                                       audioRecord:(BOOL)isRecordAudio;

/**
 开启照相机
 */
- (void)startRunning;

/**
 关闭照相机
 */
- (void)stopRunning;

/**
 开始录像
 */
- (void)startRecording;

/**
 停止录像
 */
- (void)stopRceording;

/**
 重置录像，丢弃之前已录制文件
 */
- (void)resetRceording;

/**
 尝试进行一次对焦
 @param focus 焦点位置
 */
- (void)resetFocusingWithFocus:(CGPoint)focus;

/**
 切换摄像头。切换摄像头后，补光灯自动关闭。需要需要补光，请重新开启。
 */
- (void)switchCamera;

/**
 切换指定摄像头。如果指定的设备和当前活跃设置一致，不进行操作
 @param devicePosition 指定摄像头设备
 */
- (void)switchCameraDevicePosition:(AVCaptureDevicePosition)devicePosition;

/**
 画面缩放
 @param expandV 缩放倍数
 */
- (void)zoomWithExpand:(float)expandV;

/**
 补光灯
 @param isOpen 是否开启
 */
- (void)torchLight:(BOOL)isOpen;

/**
 自定义录像视频文件名称
 
 @param nameStr 视频文件名称
 */
- (void)cameraVideoRecordName:(NSString *)nameStr;

/**
 自定义录像视频帧率。该参数为近似值，录制的视频帧率可能和设置的FPS有差异。
 
 @param FPS 视频帧率，阈值范围[0, 33]，其中0表示使用默认帧率。
 */
- (void)cameraVideoRecordFPS:(NSUInteger)FPS;

/**
 自定义录制配置-是否手动添加Buffer数据，默认为NO，不手动添加
 如果配置该参数为YES，需要主动调用`-cameraVideoRecordWithSampleBuffer:connection:`接口传入sambuffer数据，SDK不在进行摄像头数据同步录制操作。
 
 @param isManualInput 是否手动添加
 */
- (void)cameraVideoRecordManualInput:(BOOL)isManualInput;

/**
 录制视频过程中手动添加Buffer数据。手动添加数据不再按照期望FPS进行保存
 
 @param sampleBuffer Buffer数据
 @param connection 连接器信息
 */
- (void)cameraVideoRecordWithSampleBuffer:(CMSampleBufferRef)sampleBuffer
                               connection:(AVCaptureConnection *)connection;

/**
 版本信息
 */
+ (NSString *)getSDKVersion;

@end

NS_ASSUME_NONNULL_END
