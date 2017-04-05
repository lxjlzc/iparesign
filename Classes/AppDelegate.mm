

#import "AppDelegate.h"

static NSString *kKeyPrefsBundleIDChange            = @"keyBundleIDChange";

static NSString *kKeyBundleIDPlistApp               = @"CFBundleIdentifier";
static NSString *kKeyBundleIDPlistiTunesArtwork     = @"softwareVersionBundleId";
static NSString *kKeyInfoPlistApplicationProperties = @"ApplicationProperties";
static NSString *kKeyInfoPlistApplicationPath       = @"ApplicationPath";
static NSString *kFrameworksDirName                 = @"Frameworks";
static NSString *kPayloadDirName                    = @"Payload";
static NSString *kProductsDirName                   = @"Products";
static NSString *kInfoPlistFilename                 = @"Info.plist";
static NSString *kiTunesMetadataFileName            = @"iTunesMetadata";


@implementation AppDelegate
@synthesize window;

//
- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender
{
	return YES;
}

//
- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    
    // 获取钥匙串的证书
    certComboBox.delegate = self;
    certComboBox.dataSource = self;
    
    [self getCerts];
    
	[flurry setAlphaValue:0.5];
	defaults = [NSUserDefaults standardUserDefaults];
	
	if ([defaults valueForKey:@"IPA_PATH"])
		[pathField setStringValue:[defaults valueForKey:@"IPA_PATH"]];
	if ([defaults valueForKey:@"DYLIB_PATH"])
		[dylibField setStringValue:[defaults valueForKey:@"DYLIB_PATH"]];
	if ([defaults valueForKey:@"MOBILEPROVISION_PATH"])
		[provField setStringValue:[defaults valueForKey:@"MOBILEPROVISION_PATH"]];
    [defaults setValue:[NSNumber numberWithInteger:[certComboBox indexOfSelectedItem]] forKey:@"CERT_INDEX"];

	if (![[NSFileManager defaultManager] fileExistsAtPath:@"/usr/bin/zip"])
	{
		NSRunAlertPanel(@"Error", 
						@"This app cannot run without the zip utility present at /usr/bin/zip",
						@"OK",nil,nil);
		exit(0);
	}
	if (![[NSFileManager defaultManager] fileExistsAtPath:@"/usr/bin/unzip"])
	{
		NSRunAlertPanel(@"Error", 
						@"This app cannot run without the unzip utility present at /usr/bin/unzip",
						@"OK",nil,nil);
		exit(0);
	}
	if (![[NSFileManager defaultManager] fileExistsAtPath:@"/usr/bin/codesign"])
	{
		NSRunAlertPanel(@"Error", 
						@"This app cannot run without the codesign utility present at /usr/bin/codesign",
						@"OK",nil, nil);
		exit(0);
	}
    
    if (![[NSFileManager defaultManager] fileExistsAtPath:@"/usr/bin/yololib"])
    {
        NSRunAlertPanel(@"Error",
                        @"This app cannot run without the yololib utility present at /usr/bin/yololib",
                        @"OK",nil, nil);
        exit(0);
    }
    
    if (![[NSFileManager defaultManager] fileExistsAtPath:@"/usr/bin/security"])
    {
        NSRunAlertPanel(@"Error",
                        @"This app cannot run without the security utility present at /usr/bin/security",
                        @"OK",nil, nil);
        exit(0);
    }

}

//
- (IBAction)browse:(id)sender
{
    
    NSOpenPanel* openDlg = [NSOpenPanel openPanel];
    
    [openDlg setCanChooseFiles:TRUE];
    [openDlg setCanChooseDirectories:FALSE];
    [openDlg setAllowsMultipleSelection:FALSE];
    [openDlg setAllowsOtherFileTypes:FALSE];
    [openDlg setAllowedFileTypes:@[@"ipa", @"IPA", @"xcarchive"]];
    
    if ([openDlg runModal] == NSOKButton)
    {
        NSString* fileNameOpened = [[[openDlg URLs] objectAtIndex:0] path];
        [pathField setStringValue:fileNameOpened];
    }
}

//
- (IBAction)browseProv:(id)sender
{
    
    NSOpenPanel* openDlg = [NSOpenPanel openPanel];
    
    [openDlg setCanChooseFiles:TRUE];
    [openDlg setCanChooseDirectories:FALSE];
    [openDlg setAllowsMultipleSelection:FALSE];
    [openDlg setAllowsOtherFileTypes:FALSE];
    [openDlg setAllowedFileTypes:@[@"mobileprovision", @"MOBILEPROVISION"]];
    
    if ([openDlg runModal] == NSOKButton)
    {
        NSString* fileNameOpened = [[[openDlg URLs] objectAtIndex:0] path];
        [provField setStringValue:fileNameOpened];
    }
}

//
- (IBAction)browseDylib:(id)sender
{
    
    NSOpenPanel* openDlg = [NSOpenPanel openPanel];
    
    [openDlg setCanChooseFiles:TRUE];
    [openDlg setCanChooseDirectories:FALSE];
    [openDlg setAllowsMultipleSelection:FALSE];
    [openDlg setAllowsOtherFileTypes:FALSE];
    [openDlg setAllowedFileTypes:@[@"dylib", @"DYLIB"]];
    
    if ([openDlg runModal] == NSOKButton)
    {
        NSString* fileNameOpened = [[[openDlg URLs] objectAtIndex:0] path];
        [dylibField setStringValue:fileNameOpened];
    }
}
- (IBAction)destDirBrowse:(id)sender {
    
    NSOpenPanel* openDlg = [NSOpenPanel openPanel];
    
    [openDlg setCanChooseFiles:NO];
    [openDlg setCanChooseDirectories:YES];

    if ([openDlg runModal] == NSOKButton)
    {
        NSString* fileNameOpened = [[[openDlg URLs] objectAtIndex:0] path];
        [destDirField setStringValue:fileNameOpened];
    }

}

//
- (IBAction)showHelp:(id)sender
{
	NSRunAlertPanel(@"How to use iReSign", 
					@"iReSign allows you to re-sign any unencrypted ipa-file with any certificate for which you hold the corresponding private key.\n\n1. Drag your unsigned .ipa file to the top box, or use the browse button.\n\n2. Enter your full certificate name from Keychain Access, for example \"iPhone Developer: Firstname Lastname (XXXXXXXXXX)\" in the bottom box.\n\n3. Click ReSign! and wait. The resigned file will be saved in the same folder as the original file.",
					@"OK",nil, nil);
}

//
- (IBAction)resign:(id)sender
{
     [defaults setValue:[NSNumber numberWithInteger:[certComboBox indexOfSelectedItem]] forKey:@"CERT_INDEX"];
    if (![pathField stringValue].length
        || ![provField stringValue].length
        || ![appNums stringValue].length
        || ![appNamePrefix stringValue].length
        || ![bunndlePrefix stringValue].length
        || ![destDirField stringValue].length
        || ![defaults valueForKey:@"CERT_NAME"]) {
        
        NSRunAlertPanel(@"Error",
                        @"填写不完整，请检查",
                        @"OK",nil, nil);
        return;
        
    }
	[defaults setValue:[pathField stringValue] forKey:@"IPA_PATH"];
	[defaults setValue:[dylibField stringValue] forKey:@"DYLIB_PATH"];
	[defaults setValue:[provField stringValue] forKey:@"MOBILEPROVISION_PATH"];
    [defaults setValue:[appNums stringValue] forKey:@"APP_NUMS"];
    [defaults setValue:[appNamePrefix stringValue] forKey:@"APPNAME_PREFIX"];
    [defaults setValue:[bunndlePrefix stringValue] forKey:@"BUNNDLE_PREFIX"];
    [defaults setValue:[destDirField stringValue] forKey:@"DEST_DIR"];
    [statusLabel setHidden:NO];
   
	[defaults synchronize];
    [self disableControls];
	

    //生成Entitlements.plist文件
    [self generateEntitlementsPlist];
	
	[flurry startAnimation:self];
    
	[self performSelectorInBackground:@selector(resignThread) withObject:nil];
}

#pragma mark -- 解压app


#pragma mark -- 生成Entitlements.plist文件

-(void)generateEntitlementsPlist
{
    //security cms -D -i "embedded.mobileprovision" > Entitlements_full.plist
    ///usr/libexec/PlistBuddy -x -c 'Print:Entitlements' t_entitlements_full.plist > Entitlements.plist
    NSString *workPath = [[pathField stringValue] stringByDeletingLastPathComponent];
    NSString *entitlementsFullPath = [NSString stringWithFormat:@"%@%@",workPath,@"/Entitlements_full.plist"];
    NSString *entitlementsPath = [NSString stringWithFormat:@"%@%@",workPath,@"/Entitlements.plist"];
    [super doTask:@"/usr/bin/security" arguments:@[@"cms",@"-D",@"-i",[provField stringValue],@"-o",entitlementsFullPath]];
    [super doTask:@"/usr/bin/touch" arguments:@[entitlementsPath]];
    NSString* tmpStr = [super doTask:@"/usr/libexec/PlistBuddy" arguments:@[@"-x",@"-c",@"Print:Entitlements",entitlementsFullPath]];
   [tmpStr writeToFile:entitlementsPath atomically:YES encoding:NSUTF8StringEncoding error:nil];
    [defaults setValue:entitlementsPath forKey:@"ENTITLEMENTS_PATH"];
    
    
}

//
- (void)resignThread
{
	@autoreleasepool
	{
        [statusLabel setStringValue:@"重新签名中..."];
		NSString *error = [super refine:pathField.stringValue dylibPath:dylibField.stringValue certName:[defaults valueForKey:@"CERT_NAME"] provPath:provField.stringValue];
		[self performSelectorOnMainThread:@selector(resignDone:) withObject:error waitUntilDone:YES];
	}
}

//
- (void)resignDone:(NSString *)error
{
    [statusLabel setStringValue:@"重新签名完成,可重新开始"];
	[pathField setEnabled:TRUE];
    
    [appNums setEnabled:TRUE];
    [appNamePrefix setEnabled:TRUE];
    [bunndlePrefix setEnabled:TRUE];
    
	[browseButton setEnabled:TRUE];
	[resignButton setEnabled:TRUE];
    [certComboBox setEnabled:TRUE];
    [browseDestDir setEnabled:TRUE];
    [browseProfile setEnabled:TRUE];
    [browseProvButton setEnabled:TRUE];
	
	[flurry stopAnimation:self];
	
}


#pragma mark 获取证书

- (void)getCerts {
    getCertsResult = nil;
    
    NSLog(@"Getting Certificate IDs");
    [statusLabel setStringValue:@"Getting Signing Certificate IDs"];
    
    certTask = [[NSTask alloc] init];
    [certTask setLaunchPath:@"/usr/bin/security"];
    [certTask setArguments:[NSArray arrayWithObjects:@"find-identity", @"-v", @"-p", @"codesigning", nil]];
    
    [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(checkCerts:) userInfo:nil repeats:TRUE];
    
    NSPipe *pipe=[NSPipe pipe];
    [certTask setStandardOutput:pipe];
    [certTask setStandardError:pipe];
    NSFileHandle *handle=[pipe fileHandleForReading];
    
    [certTask launch];
    
    [NSThread detachNewThreadSelector:@selector(watchGetCerts:) toTarget:self withObject:handle];
}

- (void)watchGetCerts:(NSFileHandle*)streamHandle {
    @autoreleasepool {
        
        NSString *securityResult = [[NSString alloc] initWithData:[streamHandle readDataToEndOfFile] encoding:NSASCIIStringEncoding];
        // Verify the security result
        if (securityResult == nil || securityResult.length < 1) {
            // Nothing in the result, return
            return;
        }
        NSArray *rawResult = [securityResult componentsSeparatedByString:@"\""];
        NSMutableArray *tempGetCertsResult = [NSMutableArray arrayWithCapacity:20];
        for (int i = 0; i <= [rawResult count] - 2; i+=2) {
            
            NSLog(@"i:%d", i+1);
            if (rawResult.count - 1 < i + 1) {
                // Invalid array, don't add an object to that position
            } else {
                // Valid object
                [tempGetCertsResult addObject:[rawResult objectAtIndex:i+1]];
            }
        }
        
        certComboBoxItems = [NSMutableArray arrayWithArray:tempGetCertsResult];
        
        [certComboBox reloadData];
        
    }
}

- (void)checkCerts:(NSTimer *)timer {
    if ([certTask isRunning] == 0) {
        [timer invalidate];
        certTask = nil;
        
        if ([certComboBoxItems count] > 0) {
            NSLog(@"Get Certs done");
            [statusLabel setStringValue:@"Signing Certificate IDs extracted"];
            NSLog(@"CERT_INDEX:%@",[defaults valueForKey:@"CERT_INDEX"]);
            if ([defaults valueForKey:@"CERT_INDEX"]) {
                
                NSInteger selectedIndex = [[defaults valueForKey:@"CERT_INDEX"] integerValue];
                if (selectedIndex != -1) {
                    NSString *selectedItem = [self comboBox:certComboBox objectValueForItemAtIndex:selectedIndex];
                    [certComboBox setObjectValue:selectedItem];
                    [certComboBox selectItemAtIndex:selectedIndex];
                }
                
                [self enableControls];
            }
        } else {
            [self showAlertOfKind:NSCriticalAlertStyle WithTitle:@"Error" AndMessage:@"Getting Certificate ID's failed"];
            [self enableControls];
            [statusLabel setStringValue:@"Ready"];
        }
    }
}


-(NSInteger)numberOfItemsInComboBox:(NSComboBox *)aComboBox {
    NSInteger count = 0;
    if ([aComboBox isEqual:certComboBox]) {
        count = [certComboBoxItems count];
    }
    return count;
}

- (id)comboBox:(NSComboBox *)aComboBox objectValueForItemAtIndex:(NSInteger)index {
    id item = nil;
    if ([aComboBox isEqual:certComboBox]) {
        item = [certComboBoxItems objectAtIndex:index];
    }
    [defaults setValue:item forKey:@"CERT_NAME"];
    return item;
}

#pragma mark 提示框
- (void)showAlertOfKind:(NSAlertStyle)style WithTitle:(NSString *)title AndMessage:(NSString *)message {
    NSAlert *alert = [[NSAlert alloc] init];
    [alert addButtonWithTitle:@"OK"];
    [alert setMessageText:title];
    [alert setInformativeText:message];
    [alert setAlertStyle:style];
    [alert runModal];
}

#pragma mark 设置可否编辑

- (void)disableControls {
    
    [pathField setEnabled:FALSE];
    
    [appNums setEnabled:FALSE];
    [appNamePrefix setEnabled:FALSE];
    [bunndlePrefix setEnabled:FALSE];
    
    [browseButton setEnabled:FALSE];
    [resignButton setEnabled:FALSE];
    [browseProvButton setEnabled:FALSE];
    [browseDestDir setEnabled:FALSE];
    [browseProfile setEnabled:FALSE];
    [certComboBox setEnabled:FALSE];
    [flurry startAnimation:self];
    [flurry setAlphaValue:1.0];
}

- (void)enableControls {
    [pathField setEnabled:YES];
    
    [appNums setEnabled:YES];
    [appNamePrefix setEnabled:YES];
    [bunndlePrefix setEnabled:YES];
    
    [browseButton setEnabled:YES];
    [resignButton setEnabled:YES];

    [certComboBox setEnabled:YES];
    
    [flurry stopAnimation:self];
    [flurry setAlphaValue:0.5];
}


@end
