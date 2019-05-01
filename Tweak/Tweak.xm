bool enabled;
NSArray *disabledApps;

@interface FBApplicationInfo : NSObject

@property (nonatomic,copy,readonly) NSString* bundleIdentifier;
-(NSDictionary *)environmentVariables;

@end

%hook FBApplicationInfo

-(NSDictionary *)environmentVariables {
    if (![self bundleIdentifier]) return %orig;

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
    return ourDictionary;
}

%end

void updateDisabledApps() {
    NSMutableDictionary *appList = [[NSMutableDictionary alloc] initWithContentsOfFile:@"/var/mobile/Library/Preferences/me.nepeta.unsub.plist"];
    NSMutableArray *_disabledApps = [[NSMutableArray alloc] init];
    for (NSString *key in appList) {
        if ([[appList objectForKey:key] boolValue]) {
            [_disabledApps addObject:key];
        }
    }

    disabledApps = _disabledApps;
}

%ctor {
    updateDisabledApps();
    CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, (CFNotificationCallback)updateDisabledApps, (CFStringRef)@"me.nepeta.unsub/ReloadPrefs", NULL, (CFNotificationSuspensionBehavior)kNilOptions);
}