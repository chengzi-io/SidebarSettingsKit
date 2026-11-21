// CoreGraphics' virtual display classes, which no public header declares. The classes exist in
// CoreGraphics at runtime (open-source tools such as sammcj/force-hidpi and Stengo/DeskPad call
// them the same way); the tool is linked with `-undefined dynamic_lookup`, so the linker keeps
// these names for dyld to resolve from the loaded framework.
#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

@class CGVirtualDisplay;

@interface CGVirtualDisplayDescriptor : NSObject
@property (nonatomic, copy) NSString *name;
@property (nonatomic) uint32_t serialNum;
@property (nonatomic) uint32_t productID;
@property (nonatomic) uint32_t vendorID;
@property (nonatomic) uint32_t maxPixelsWide;
@property (nonatomic) uint32_t maxPixelsHigh;
@property (nonatomic) CGSize sizeInMillimeters;
@property (nonatomic) dispatch_queue_t queue;
@property (nonatomic, copy) void (^terminationHandler)(CGVirtualDisplay *display);
@end

@interface CGVirtualDisplayMode : NSObject
@property (nonatomic) uint32_t width;
@property (nonatomic) uint32_t height;
@property (nonatomic) double refreshRate;
- (instancetype)initWithWidth:(uint32_t)width
                       height:(uint32_t)height
                  refreshRate:(double)refreshRate;
@end

@interface CGVirtualDisplaySettings : NSObject
@property (nonatomic) uint32_t hiDPI;
@property (nonatomic, copy) NSArray<CGVirtualDisplayMode *> *modes;
@end

@interface CGVirtualDisplay : NSObject
@property (nonatomic, readonly) CGDirectDisplayID displayID;
- (instancetype)initWithDescriptor:(CGVirtualDisplayDescriptor *)descriptor;
- (BOOL)applySettings:(CGVirtualDisplaySettings *)settings;
@end
