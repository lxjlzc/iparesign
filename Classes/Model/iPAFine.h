

#import <Cocoa/Cocoa.h>

//
@interface iPAFine : NSObject
{
@private
	NSString *_error;
}

@property(nonatomic,strong)NSString *appPath;

- (NSString *)doTask:(NSString *)path arguments:(NSArray *)arguments;

- (NSString *)refine:(NSString *)ipaPath dylibPath:(NSString *)dylibPath certName:(NSString *)certName provPath:(NSString *)provPath;

@end
