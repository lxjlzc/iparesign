

#import "iPAFine.h"

//
@interface AppDelegate : iPAFine <NSApplicationDelegate, NSTextFieldDelegate,NSComboBoxDelegate,NSComboBoxDataSource,NSComboBoxCellDataSource>
{
	NSUserDefaults *defaults;

	IBOutlet NSTextField *pathField;
	IBOutlet NSTextField *provField;
	IBOutlet NSTextField *dylibField;

    IBOutlet NSTextField *bunndlePrefix;
    IBOutlet NSTextField *appNamePrefix;
    IBOutlet NSTextField *appNums;
    
	IBOutlet NSButton	*browseButton;
	IBOutlet NSButton	*browseProvButton;
	IBOutlet NSButton	*resignButton;
    IBOutlet NSButton *browseDestDir;
    
    IBOutlet NSButton *browseProfile;
	IBOutlet NSProgressIndicator *flurry;
    IBOutlet NSComboBox *certComboBox;
    
    IBOutlet NSTextField *destDirField;
    
    
    IBOutlet NSTextField *statusLabel;
    NSMutableArray *certComboBoxItems;
    NSTask *certTask;
    NSArray *getCertsResult;

}

@property (assign) IBOutlet NSWindow *window;

- (IBAction)resign:(id)sender;

@end
