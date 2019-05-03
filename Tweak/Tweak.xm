NSArray *disabledApps;
extern "C" void BKSTerminateApplicationForReasonAndReportWithDescription(NSString *bundleID, int reasonID, bool report, NSString *description);

@interface FBApplicationInfo : NSObject

@property (nonatomic,copy,readonly) NSString* bundleIdentifier;
-(NSDictionary *)environmentVariables;

@end

bool dpkgInvalid = false;

%group UnSub

%hook FBApplicationInfo

-(NSDictionary *)environmentVariables {
    if (![self bundleIdentifier]) return %orig;
    if (!disabledApps) return %orig;

    BOOL found = false;
    NSString *bundleIdentifier = [self bundleIdentifier];
    for (NSString *bundleId in disabledApps) {
        if ([bundleIdentifier isEqualToString: bundleId]) {
            found = true;
            break;
        }
    }

    if (!found) return %orig;

    NSMutableDictionary *ourDictionary = [(%orig ?: @{}) mutableCopy];
    ourDictionary[@"_SafeMode"] = @(1);
    ourDictionary[@"_MSSafeMode"] = @(1);
    return ourDictionary;
}

%end

%end

%group UnSubFail

%hook SpringBoard

-(void)applicationDidFinishLaunching:(id)arg1 {
    %orig;
    if (!dpkgInvalid) return;
    UIAlertController *alertController = [UIAlertController
        alertControllerWithTitle:@"😡😡😡"
        message:@"The build of UnSub you're using comes from an untrusted source. Pirate repositories can distribute malware and you will get subpar user experience using any tweaks from them.\nRemember: UnSub is free. Uninstall this build and install the proper version of UnSub from:\nhttps://repo.nepeta.me/\n(it's free, damnit, why would you pirate that!?)"
        preferredStyle:UIAlertControllerStyleAlert
    ];

    [alertController addAction:[UIAlertAction actionWithTitle:@"Damn!" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        [((UIApplication*)self).keyWindow.rootViewController dismissViewControllerAnimated:YES completion:NULL];
    }]];

    [((UIApplication*)self).keyWindow.rootViewController presentViewController:alertController animated:YES completion:NULL];
}

%end

%end

void updateDisabledApps() {
    NSMutableDictionary *appList = [[NSMutableDictionary alloc] initWithContentsOfFile:@"/var/mobile/Library/Preferences/me.nepeta.unsub.plist"];
    NSMutableArray *_disabledApps = [[NSMutableArray alloc] init];
    for (NSString *key in appList) {
        if ([[appList objectForKey:key] boolValue] && ![key isEqualToString:@"com.apple.Preferences"]) {
            [_disabledApps addObject:key];
        }
    }

    if (disabledApps) {
        for (NSString *bundleId in disabledApps) {
            if (![_disabledApps containsObject:bundleId]) {
                BKSTerminateApplicationForReasonAndReportWithDescription(bundleId, 5, false, @"UnSub - preference change, killed");
            }
        }

        for (NSString *bundleId in _disabledApps) {
            if (![disabledApps containsObject:bundleId]) {
                BKSTerminateApplicationForReasonAndReportWithDescription(bundleId, 5, false, @"UnSub - preference change, killed");
            }
        }
    }

    disabledApps = _disabledApps;
}

%ctor {
    dpkgInvalid = ![[NSFileManager defaultManager] fileExistsAtPath:@"/var/lib/dpkg/info/me.nepeta.unsub.list"];

    if (dpkgInvalid) {
        %init(UnSubFail);
        return;
    }

    %init(UnSub);
    updateDisabledApps();
    CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, (CFNotificationCallback)updateDisabledApps, (CFStringRef)@"me.nepeta.unsub/ReloadPrefs", NULL, (CFNotificationSuspensionBehavior)kNilOptions);
}