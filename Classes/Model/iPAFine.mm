

#import "AppDelegate.h"
#include <mach-o/loader.h>
#include <mach-o/fat.h>

@implementation iPAFine

//
- (NSString *)doTask:(NSString *)path arguments:(NSArray *)arguments currentDirectory:(NSString *)currentDirectory
{
	NSTask *task = [[NSTask alloc] init];
	task.launchPath = path;
	task.arguments = arguments;
	if (currentDirectory) task.currentDirectoryPath = currentDirectory;

	NSPipe *pipe = [NSPipe pipe];
	task.standardOutput = pipe;
	task.standardError = pipe;

	NSFileHandle *file = [pipe fileHandleForReading];

	[task launch];

	NSData *data = [file readDataToEndOfFile];
	NSString *result = data.length ? [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] : nil;

	NSLog(@"CMD:\n%@\n%@ARG\n\n%@\n\n", path, arguments, (result ? result : @""));
	return result;
}


//
- (NSString *)doTask:(NSString *)path arguments:(NSArray *)arguments
{
	return [self doTask:path arguments:arguments currentDirectory:nil];
}

//
- (NSString *)unzipIPA:(NSString *)ipaPath workPath:(NSString *)workPath index:(int)idx
{
	NSString *result = [self doTask:@"/usr/bin/unzip" arguments:[NSArray arrayWithObjects:@"-q", ipaPath, @"-d", workPath, nil]];
	NSString *payloadPath = [workPath stringByAppendingPathComponent:@"Payload"];
	if ([[NSFileManager defaultManager] fileExistsAtPath:payloadPath])
	{
		NSArray *dirs = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:payloadPath error:nil];
		for (NSString *dir in dirs)
		{
			if ([dir.pathExtension.lowercaseString isEqualToString:@"app"])
			{
                
                NSString* appPath = [payloadPath stringByAppendingPathComponent:dir];
                //删除Watch和PlugIns两个目录
                NSString* watchPath = [appPath stringByAppendingPathComponent:@"Watch"];
                NSString* plugInsPath = [appPath stringByAppendingPathComponent:@"PlugIns"];
                
                [self doTask:@"/bin/rm" arguments:[NSArray arrayWithObjects:@"-rf", watchPath, nil]];
                [self doTask:@"/bin/rm" arguments:[NSArray arrayWithObjects:@"-rf", plugInsPath, nil]];
                
                //拷贝资源文件
                  NSString  *bundlePath = [[ NSBundle   mainBundle ]. resourcePath   stringByAppendingPathComponent : @"GCDWebUploader.bundle" ];
                [self doTask:@"/bin/cp" arguments:[NSArray arrayWithObjects:@"-rf",bundlePath, appPath, nil]];
                
                //拷贝沙盒和配置文件到工程目录下
                //NSString  *settingFilePath = [[ NSBundle   mainBundle ]. resourcePath   stringByAppendingPathComponent : @"setting.prop" ];
               // [self doTask:@"/bin/cp" arguments:[NSArray arrayWithObjects:@"-rf",settingFilePath, appPath, nil]];
                //NSString  *documentsPath = [[ NSBundle   mainBundle ]. resourcePath   stringByAppendingPathComponent : @"Documents.zip" ];
                //[self doTask:@"/bin/cp" arguments:[NSArray arrayWithObjects:@"-rf",documentsPath, appPath, nil]];
                
                
				return appPath;
			}
		}
		_error = @"Invalid app";
		return nil;
	}
	_error = [@"Unzip failed:" stringByAppendingString:result ? result : @""];
	return nil;
}

//
- (NSString *)renameApp:(NSString *)appPath ipaPath:(NSString *)ipaPath index:(int)idx
{
	// 获取显示名称
    NSString *appNamePrefix,*appName,*bunndleIdPrefix,*bunndleId=nil;
    if (idx == 0) {
        appNamePrefix = [[NSUserDefaults standardUserDefaults] valueForKey:@"APPNAME_PREFIX"];
        appName = appNamePrefix;
        
        bunndleIdPrefix = [[NSUserDefaults standardUserDefaults] valueForKey:@"BUNNDLE_PREFIX"];
        bunndleId = bunndleIdPrefix;
        bunndleId = [NSString stringWithFormat:@"%@%@",bunndleIdPrefix,@".luck"];

    }
    else
    {
        appNamePrefix = [[NSUserDefaults standardUserDefaults] valueForKey:@"APPNAME_PREFIX"];
        appName = [NSString stringWithFormat:@"%@%i",appNamePrefix,idx];
        
        bunndleIdPrefix = [[NSUserDefaults standardUserDefaults] valueForKey:@"BUNNDLE_PREFIX"];
        bunndleId = [NSString stringWithFormat:@"%@%@%i",bunndleIdPrefix,@".",idx];
    }
    
	//
	NSString *infoPath = [appPath stringByAppendingPathComponent:@"Info.plist"];
	NSMutableDictionary *info = [NSMutableDictionary dictionaryWithContentsOfFile:infoPath];

	// 修改显示名称
	[info setObject:appName forKey:@"CFBundleDisplayName"];
    [info setObject:bunndleId forKey:@"CFBundleIdentifier"];
    [info setObject:@"YES" forKey:@"UIFileSharingEnabled"];
    
    //添加定位，可以让后台持续运行
    NSMutableArray*  backgroundArr = [info objectForKey:@"UIBackgroundModes"];
    [backgroundArr addObject:@"location"];
    [info setObject:@"\"微信\"想访问您的活动和体能训练记录" forKey:@"NSLocationWhenInUseUsageDescription"];
    [info setObject:@"\"微信\"想访问您的活动和体能训练记录" forKey:@"NSLocationAlwaysUsageDescription"];
    
	[info writeToFile:infoPath atomically:YES];

	static const NSString *langs[] = {@"zh-Hans", @"zh_Hans", @"zh_CN", @"zh-CN", @"zh"};
	for (NSUInteger i = 0; i < sizeof(langs) / sizeof(langs[0]); i++)
	{
		NSString *localizePath = [appPath stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.lproj/InfoPlist.strings", langs[i]]];
		if ([[NSFileManager defaultManager] fileExistsAtPath:localizePath])
		{
			NSMutableDictionary *localize = [NSMutableDictionary dictionaryWithContentsOfFile:localizePath];
			[localize removeObjectForKey:@"CFBundleDisplayName"];
			[localize writeToFile:localizePath atomically:YES];
		}
	}

	return [NSString stringWithFormat:@"%@.ipa", appName];
}


//
- (void)injectApp:(NSString *)appPath dylibPath:(NSString *)dylibPath
{
	if (dylibPath.length)
	{
        NSString *targetPath,*result= nil;
		if ([[NSFileManager defaultManager] fileExistsAtPath:dylibPath])
		{
			targetPath = [appPath stringByAppendingPathComponent:[dylibPath lastPathComponent]];
			if ([[NSFileManager defaultManager] fileExistsAtPath:targetPath])
			{
				[[NSFileManager defaultManager] removeItemAtPath:targetPath error:nil];
			}

			result = [self doTask:@"/bin/cp" arguments:[NSArray arrayWithObjects:dylibPath, targetPath, nil]];
			if (![[NSFileManager defaultManager] fileExistsAtPath:targetPath])
			{
				_error = [@"Failed to copy dylib file: " stringByAppendingString:result ? result : @""];
			}
		}

		// Find executable
		NSString *infoPath = [appPath stringByAppendingPathComponent:@"Info.plist"];
		NSMutableDictionary *info = [NSMutableDictionary dictionaryWithContentsOfFile:infoPath];
		NSString *exeName = [info objectForKey:@"CFBundleExecutable"];
		if (exeName == nil)
		{
			_error = [NSString stringWithFormat:@"Inject failed: No CFBundleExecutable on %@", infoPath];
			return;
		}
		NSString *exePath = [appPath stringByAppendingPathComponent:exeName];
        NSString *dylibName=[[dylibPath componentsSeparatedByString:@"/"] lastObject];
        [[NSUserDefaults standardUserDefaults] setObject:targetPath forKey:@"DYLIB_TARGET_PATH"];
        //动态库注入到可执行文件中
         result = [self doTask:@"/usr/bin/cd" arguments:@[appPath]];
        result = [self doTask:@"/usr/bin/yololib" arguments:@[exePath,dylibName]];
	}
}

//
- (void)provApp:(NSString *)appPath provPath:(NSString *)provPath
{
	NSString *targetPath = [appPath stringByAppendingPathComponent:@"embedded.mobileprovision"];
	if ([[NSFileManager defaultManager] fileExistsAtPath:targetPath])
	{
		NSLog(@"Found embedded.mobileprovision, deleting.");
		[[NSFileManager defaultManager] removeItemAtPath:targetPath error:nil];
	}

	if (provPath.length)
	{
		NSString *result = [self doTask:@"/bin/cp" arguments:[NSArray arrayWithObjects:provPath, targetPath, nil]];
		if (![[NSFileManager defaultManager] fileExistsAtPath:targetPath])
		{
			_error = [@"Failed to copy provisioning file: " stringByAppendingString:result ?: @""];
		}
	}
}

//
- (void)signApp:(NSString *)appPath certName:(NSString *)certName
{
	if (certName.length)
	{
		BOOL isDir;
		if ([[NSFileManager defaultManager] fileExistsAtPath:appPath isDirectory:&isDir] && isDir)
		{
            
            //签名动态库
            NSString* dylibPath = [[NSUserDefaults standardUserDefaults] valueForKey:@"DYLIB_TARGET_PATH"];
            [self doTask:@"/usr/bin/codesign" arguments:[NSArray arrayWithObjects:@"-fs", certName, dylibPath, nil]];
            //签名ENTITLEMENTS
            NSString *entitlementsPath = [[NSUserDefaults standardUserDefaults] valueForKey:@"ENTITLEMENTS_PATH"];
            [self doTask:@"/usr/bin/codesign" arguments:[NSArray arrayWithObjects:@"-fs", certName, (entitlementsPath ? @"--entitlements" : nil), entitlementsPath, appPath,nil]];
			
		}
	}
}

- (void)zipIPA:(NSString *)workPath outPath:(NSString *)outPath
{
    //xcrun -sdk iphoneos PackageApplication -v WeChat.app -o /Users/liaozc/Desktop/WeChat60/WeChat.ipa
    NSString* destDir = [[NSUserDefaults standardUserDefaults] valueForKey:@"DEST_DIR"];
    NSString* refineIpaPath = [NSString stringWithFormat:@"%@%@%@",destDir,@"/",outPath];
	[self doTask:@"/usr/bin/xcrun" arguments:@[@"-sdk",@"iphoneos",@"PackageApplication",@"-v",_appPath,@"-o",refineIpaPath]];
    //[self doTask:@"/usr/bin/zip" arguments:@[@"-qry",refineIpaPath,_appPath]];
    
    //生成完成后删除解压的目录
     [self doTask:@"/bin/rm" arguments:[NSArray arrayWithObjects:@"-rf", workPath, nil]];
}

//
- (void)refineIPA:(NSString *)ipaPath dylibPath:(NSString *)dylibPath certName:(NSString *)certName provPath:(NSString *)provPath index:(int)idx
{
	//
	NSString *workPath = ipaPath.stringByDeletingPathExtension;

	[[NSFileManager defaultManager] removeItemAtPath:workPath error:nil];
	[[NSFileManager defaultManager] createDirectoryAtPath:workPath withIntermediateDirectories:TRUE attributes:nil error:nil];
    

        for(int i = 0; i <= idx; i++)
        {
            // 解压ipa
            _error = nil;
            _appPath = [self unzipIPA:ipaPath workPath:workPath index:i];
            
            if (_error) return;
            
            // 命名ipa
            NSString *outPath = [self renameApp:_appPath ipaPath:ipaPath index:i];
            
            // 注入和拷贝dylib
            [self injectApp:_appPath dylibPath:dylibPath];
            if (_error) return;
            
            // 拷贝embedded.mobileprovision
            [self provApp:_appPath provPath:provPath];
            if (_error) return;
            // 签名
            [self signApp:_appPath certName:certName];
            if (_error) return;
            
            // 打包成ipa
            [self zipIPA:workPath outPath:outPath];
        }
    


	
}

//
- (NSString *)refine:(NSString *)ipaPath dylibPath:(NSString *)dylibPath certName:(NSString *)certName provPath:(NSString *)provPath
{
	_error = nil;
    
	if ([[NSFileManager defaultManager] fileExistsAtPath:ipaPath])
	{
		 if ([ipaPath.pathExtension.lowercaseString isEqualToString:@"ipa"])
		{
            int appNums = [[[NSUserDefaults standardUserDefaults] valueForKey:@"APP_NUMS"] intValue];
            [self refineIPA:ipaPath dylibPath:dylibPath certName:certName provPath:provPath index:appNums];
		}
    }
	else
	{
		_error = @"Path not found";
	}
	return _error;
}

@end
