#import <sys/types.h>
#import <sys/stat.h>
#import <stdio.h>
#import <unistd.h>
#import <dlfcn.h>
#import <mach-o/dyld.h>

NSArray *disabledApps;
NSArray *bypassedApps;

extern "C" void BKSTerminateApplicationForReasonAndReportWithDescription(NSString *bundleID, int reasonID, bool report, NSString *description);

@interface FBApplicationInfo : NSObject

@property (nonatomic,copy,readonly) NSString* bundleIdentifier;
-(NSDictionary *)environmentVariables;

@end

NSArray *jailbreakFiles = @[
    @"/bin/bash",
    @"/bin/sh",
    @"/Applications/Cydia.app",
    @"/Applications/Sileo.app",
    @"/usr/sbin/sshd",
    @"/usr/bin/ssh",
    @"/private/var/lib/apt",
    @"/var/lib/cydia",
    @"/Library/MobileSubstrate",
    @"/System/Library/LaunchDaemons/com.saurik.Cydia.Startup.plist",
    @"/private/var/mobile/Library/SB",
    @"/etc/apt",
    @"/private/var/stash",
    @"/private/var/lib/apt",
    @"/private/var/lib/cydia",
    @"/private/var/lib/sileo",
    @"/private/var/tmp/cydia",
    @"/private/var/tmp/sileo",
    @"/var/log/syslog",
    @"/usr/libexec/ssh",
    @"/Applications"
];

BOOL isJailbreakFileAtPath(NSString *path) {
    if (![path containsString:@"containers"] && ![path containsString:@"Containers"]) NSLog(@"[UnSub] isjb - %@", path);
    for (NSString *file in jailbreakFiles) {
        if ([path hasPrefix:file]) return true;
    }
    return false;
}

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

%group UnSubBypass

%hookf(FILE *, fopen, const char *path, const char *mode) {
    if (isJailbreakFileAtPath([NSString stringWithUTF8String:path])) return NULL;
    return %orig;
}

%hookf(pid_t, fork) {
    return -1;
}

%hookf(int, stat, const char *path, struct stat *buf) {
    if (isJailbreakFileAtPath([NSString stringWithUTF8String:path])) return -1;
    return %orig;
}

%hookf(int, lstat, const char *path, struct stat *buf) {
    if (isJailbreakFileAtPath([NSString stringWithUTF8String:path])) return -1;
    return %orig;
}

%hookf(FILE *, popen, const char *command, const char *type) {
    return NULL;
}

%hookf(int, system, const char *command) {
    NSLog(@"[UnSub] system - %@", [NSString stringWithUTF8String:command]);
    return 0;
}

NSMutableArray *dyldArray = [NSMutableArray new];
BOOL bypassDyldArray = NO;

%hookf(uint32_t, _dyld_image_count) {
    uint32_t count = %orig;
    [dyldArray removeAllObjects];
    bypassDyldArray = YES;
    for (int i = 0; i < count; i++) {
        const char *charName = _dyld_get_image_name(i);
        if (!charName) continue;
        NSString *name = [NSString stringWithUTF8String:charName];
        if ([name containsString:@"TweakInject"] ||
        [name containsString:@"Cephei"] ||
        [name containsString:@"Substrate"] ||
        [name containsString:@"substitute"] ||
        [name containsString:@"applist"] ||
        [name containsString:@"rocketbootstrap"] ||
        [name containsString:@"colorpicker"]) continue;
        [dyldArray addObject:name];
    }
    bypassDyldArray = NO;
    return [dyldArray count];
}

%hookf(const char *, _dyld_get_image_name, uint32_t image_index) {
    if (bypassDyldArray) return %orig;
    if (image_index >= [dyldArray count]) return NULL;
    return [dyldArray[image_index] UTF8String];
}

%hook UIApplication

-(bool)canOpenURL:(NSString *)url {
    //temporary
    return NO;
}

%end

%hook NSFileManager

- (bool)isDeletableFileAtPath:(NSString *)path {
    if (isJailbreakFileAtPath(path)) return false;
    return %orig;
}

- (bool)isExecutableFileAtPath:(NSString *)path {
    if (isJailbreakFileAtPath(path)) return false;
    return %orig;
}

- (bool)isReadableFileAtPath:(NSString *)path {
    if (isJailbreakFileAtPath(path)) return false;
    return %orig;
}

- (bool)isUbiquitousItemAtURL:(NSString *)path {
    if (isJailbreakFileAtPath(path)) return false;
    return %orig;
}

- (bool)isWritableFileAtPath:(NSString *)path {
    if (isJailbreakFileAtPath(path)) return false;
    return %orig;
}

- (BOOL)fileExistsAtPath:(NSString *)path {
    if (isJailbreakFileAtPath(path)) return false;
    return %orig;
}

- (BOOL)fileExistsAtPath:(NSString *)path isDirectory:(BOOL *)isDirectory {
    if (isJailbreakFileAtPath(path)) return false;
    return %orig;
}

%end

%hook NSData

- (BOOL)writeToFile:(NSString *)path atomically:(BOOL)useAuxiliaryFile {
    if ([path hasPrefix:@"/private"]) {
        return NO;
    }
    return %orig;
}

%end

%hook NSString

- (BOOL)writeToFile:(NSString *)path atomically:(BOOL)useAuxiliaryFile encoding:(NSStringEncoding)enc error:(NSError * _Nullable *)error {
    if ([path hasPrefix:@"/private"]) {
        *error = [NSError errorWithDomain:@"damn" code:69 userInfo:nil];
        return NO;
    }
    return %orig;
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

    appList = [[NSMutableDictionary alloc] initWithContentsOfFile:@"/var/mobile/Library/Preferences/me.nepeta.unsub-detection.plist"];
    NSMutableArray *_bypassedApps = [[NSMutableArray alloc] init];
    for (NSString *key in appList) {
        if ([[appList objectForKey:key] boolValue] && ![key isEqualToString:@"com.apple.Preferences"]) {
            [_bypassedApps addObject:key];
        }
    }

    if (bypassedApps) {
        for (NSString *bundleId in bypassedApps) {
            if (![_bypassedApps containsObject:bundleId]) {
                BKSTerminateApplicationForReasonAndReportWithDescription(bundleId, 5, false, @"UnSub - preference change, killed; bypass");
            }
        }

        for (NSString *bundleId in _bypassedApps) {
            if (![bypassedApps containsObject:bundleId]) {
                BKSTerminateApplicationForReasonAndReportWithDescription(bundleId, 5, false, @"UnSub - preference change, killed; bypass");
            }
        }
    }

    bypassedApps = _bypassedApps;
}

%ctor {
    dpkgInvalid = ![[NSFileManager defaultManager] fileExistsAtPath:@"/var/lib/dpkg/info/me.nepeta.unsub.list"];

    bool shouldLoad = NO;

    NSString *processName = [NSProcessInfo processInfo].processName;
    NSArray *args = [[NSClassFromString(@"NSProcessInfo") processInfo] arguments];
    NSUInteger count = args.count;
    if (count != 0) {
        NSString *executablePath = args[0];
        if (executablePath) {
            NSString *processName = [executablePath lastPathComponent];
            BOOL isApplication = [executablePath rangeOfString:@"/Application/"].location != NSNotFound || [executablePath rangeOfString:@"/Applications/"].location != NSNotFound;
            BOOL isFileProvider = [[processName lowercaseString] rangeOfString:@"fileprovider"].location != NSNotFound;
            BOOL skip = [processName isEqualToString:@"AdSheet"]
                        || [processName isEqualToString:@"CoreAuthUI"]
                        || [processName isEqualToString:@"InCallService"]
                        || [processName isEqualToString:@"MessagesNotificationViewService"]
                        || [executablePath rangeOfString:@".appex/"].location != NSNotFound
                        || ![[NSFileManager defaultManager] fileExistsAtPath:@"/var/lib/dpkg/info/me.nepeta.unsub.list"];
            if (!isFileProvider && (isApplication || [processName isEqualToString:@"SpringBoard"]) && !skip && [[NSFileManager defaultManager] fileExistsAtPath:@"/var/lib/dpkg/info/me.nepeta.unsub.list"]) {
                shouldLoad = !dpkgInvalid;
            }
        }
    }

    if (!shouldLoad) return;

    if ([processName isEqualToString:@"SpringBoard"]) {
        if (dpkgInvalid) {
            %init(UnSubFail);
            return;
        }
        %init(UnSub);

        updateDisabledApps();
        CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, (CFNotificationCallback)updateDisabledApps, (CFStringRef)@"me.nepeta.unsub/ReloadPrefs", NULL, (CFNotificationSuspensionBehavior)kNilOptions);
    } else {
        NSString *bundleIdentifier = [[NSBundle mainBundle] bundleIdentifier];
        if (!bundleIdentifier) return;
        if ([bundleIdentifier hasPrefix:@"com.apple."]) return;
        NSMutableDictionary *appList = [[NSMutableDictionary alloc] initWithContentsOfFile:@"/var/mobile/Library/Preferences/me.nepeta.unsub-detection.plist"];
        if (appList && appList[bundleIdentifier] && [appList[bundleIdentifier] boolValue]) {
            %init(UnSubBypass);
        }
    }
}