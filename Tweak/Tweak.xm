NSArray *disabledApps;
extern "C" void BKSTerminateApplicationForReasonAndReportWithDescription(NSString *bundleID, int reasonID, bool report, NSString *description);

@interface FBApplicationInfo : NSObject

@property (nonatomic,copy,readonly) NSString* bundleIdentifier;
-(NSDictionary *)environmentVariables;

@end

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
    updateDisabledApps();
    CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, (CFNotificationCallback)updateDisabledApps, (CFStringRef)@"me.nepeta.unsub/ReloadPrefs", NULL, (CFNotificationSuspensionBehavior)kNilOptions);
}