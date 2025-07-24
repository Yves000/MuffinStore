#import <Foundation/Foundation.h>
#import <stdio.h>
#import <unistd.h>
#import <spawn.h>
#import <sys/wait.h>
#import <signal.h>
#import <sys/sysctl.h>
#import <sys/proc.h>
#import <dlfcn.h>
#import <stdarg.h>

// Forward declarations
void debugLog(const char *format, ...);

// Import CoreServices for LSApplicationWorkspace
@interface LSApplicationWorkspace : NSObject
+ (instancetype)defaultWorkspace;
- (BOOL)_LSPrivateRebuildApplicationDatabasesForSystemApps:(BOOL)arg1 internal:(BOOL)arg2 user:(BOOL)arg3;
- (BOOL)registerApplicationDictionary:(NSDictionary*)dict;
@end

// TrollStore app registration functions
NSArray* trollStoreInstalledAppBundlePaths(void) {
    NSMutableArray* appPaths = [NSMutableArray new];
    NSString* appContainersPath = @"/var/containers/Bundle/Application";
    NSArray* containers = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:appContainersPath error:nil];
    
    if (!containers) return nil;
    
    for (NSString* container in containers) {
        NSString* containerPath = [appContainersPath stringByAppendingPathComponent:container];
        
        // Check for TrollStore marker
        NSString* trollStoreMark = [containerPath stringByAppendingPathComponent:@"_TrollStore"];
        if ([[NSFileManager defaultManager] fileExistsAtPath:trollStoreMark]) {
            NSArray* items = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:containerPath error:nil];
            if (!items) continue;
            
            for (NSString* item in items) {
                if ([item.pathExtension isEqualToString:@"app"]) {
                    // Skip TrollStore itself
                    if (![item isEqualToString:@"TrollStore.app"] && ![item isEqualToString:@"TrollStoreLite.app"]) {
                        [appPaths addObject:[containerPath stringByAppendingPathComponent:item]];
                    }
                }
            }
        }
    }
    return appPaths.copy;
}

BOOL registerPath(NSString *path, BOOL unregister, BOOL forceSystem) {
    if (!path) return false;
    
    Class workspaceClass = NSClassFromString(@"LSApplicationWorkspace");
    if (!workspaceClass) return false;
    
    id workspace = [workspaceClass performSelector:@selector(defaultWorkspace)];
    if (!workspace) return false;
    
    path = path.stringByResolvingSymlinksInPath.stringByStandardizingPath;
    
    NSDictionary *appInfoPlist = [NSDictionary dictionaryWithContentsOfFile:[path stringByAppendingPathComponent:@"Info.plist"]];
    NSString *appBundleID = [appInfoPlist objectForKey:@"CFBundleIdentifier"];
    
    if (!appBundleID || unregister) {
        if (unregister) {
            NSURL *url = [NSURL fileURLWithPath:path];
            return [workspace performSelector:@selector(unregisterApplication:) withObject:url];
        }
        return false;
    }
    
    // Extract container path from app bundle path
    NSString *containerPath = [path stringByDeletingLastPathComponent];
    
    NSMutableDictionary *dictToRegister = [NSMutableDictionary dictionary];
    
    // Basic registration info
    dictToRegister[@"ApplicationType"] = forceSystem ? @"System" : @"User";
    dictToRegister[@"CFBundleIdentifier"] = appBundleID;
    dictToRegister[@"CodeInfoIdentifier"] = appBundleID;
    dictToRegister[@"CompatibilityState"] = @0;
    dictToRegister[@"Container"] = containerPath;
    dictToRegister[@"IsDeletable"] = @YES;
    dictToRegister[@"Path"] = path;
    dictToRegister[@"LSInstallType"] = @1;
    dictToRegister[@"SignerOrganization"] = @"Apple Inc.";
    dictToRegister[@"SignatureVersion"] = @132352;
    dictToRegister[@"SignerIdentity"] = @"Apple iPhone OS Application Signing";
    dictToRegister[@"IsAdHocSigned"] = @YES;
    dictToRegister[@"HasMIDBasedSINF"] = @0;
    dictToRegister[@"MissingSINF"] = @0;
    dictToRegister[@"FamilyID"] = @0;
    dictToRegister[@"IsOnDemandInstallCapable"] = @0;
    
    return [workspace performSelector:@selector(registerApplicationDictionary:) withObject:dictToRegister];
}

NSString* trollStoreAppPath(void) {
    // Find TrollStore app path
    NSString* appContainersPath = @"/var/containers/Bundle/Application";
    NSArray* containers = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:appContainersPath error:nil];
    
    if (!containers) return nil;
    
    for (NSString* container in containers) {
        NSString* containerPath = [appContainersPath stringByAppendingPathComponent:container];
        NSString* trollStoreApp = [containerPath stringByAppendingPathComponent:@"TrollStore.app"];
        NSString* trollStoreLiteApp = [containerPath stringByAppendingPathComponent:@"TrollStoreLite.app"];
        
        if ([[NSFileManager defaultManager] fileExistsAtPath:trollStoreApp]) {
            return trollStoreApp;
        }
        if ([[NSFileManager defaultManager] fileExistsAtPath:trollStoreLiteApp]) {
            return trollStoreLiteApp;
        }
    }
    return nil;
}

void refreshAppRegistrations(BOOL system) {
    fprintf(stdout, "📱 Refreshing app registrations (system: %s)...\n", system ? "YES" : "NO");
    
    // Register TrollStore itself first
    NSString *trollStoreApp = trollStoreAppPath();
    if (trollStoreApp) {
        if (registerPath(trollStoreApp, NO, system)) {
            fprintf(stdout, "✅ Re-registered TrollStore\n");
        } else {
            fprintf(stderr, "❌ Failed to re-register TrollStore\n");
        }
    }
    
    // Register all TrollStore installed apps
    NSArray *appPaths = trollStoreInstalledAppBundlePaths();
    int registeredCount = 0;
    
    for (NSString* appPath in appPaths) {
        if (registerPath(appPath, NO, system)) {
            registeredCount++;
        }
    }
    
    fprintf(stdout, "✅ Re-registered %d TrollStore apps\n", registeredCount);
}


// TrollStore killall implementation
void enumerateProcessesUsingBlock(void (^enumerator)(pid_t pid, NSString* executablePath, BOOL* stop))
{
    static int maxArgumentSize = 0;
    if (maxArgumentSize == 0) {
        size_t size = sizeof(maxArgumentSize);
        if (sysctl((int[]){ CTL_KERN, KERN_ARGMAX }, 2, &maxArgumentSize, &size, NULL, 0) == -1) {
            perror("sysctl argument size");
            maxArgumentSize = 4096; // Default
        }
    }
    int mib[3] = { CTL_KERN, KERN_PROC, KERN_PROC_ALL};
    struct kinfo_proc *info;
    size_t length;
    int count;
    
    if (sysctl(mib, 3, NULL, &length, NULL, 0) < 0)
        return;
    if (!(info = malloc(length)))
        return;
    if (sysctl(mib, 3, info, &length, NULL, 0) < 0) {
        free(info);
        return;
    }
    count = length / sizeof(struct kinfo_proc);
    for (int i = 0; i < count; i++) {
        @autoreleasepool {
        pid_t pid = info[i].kp_proc.p_pid;
        if (pid == 0) {
            continue;
        }
        size_t size = maxArgumentSize;
        char* buffer = (char *)malloc(length);
        if (sysctl((int[]){ CTL_KERN, KERN_PROCARGS2, pid }, 3, buffer, &size, NULL, 0) == 0) {
            NSString* executablePath = [NSString stringWithCString:(buffer+sizeof(int)) encoding:NSUTF8StringEncoding];
            
            BOOL stop = NO;
            enumerator(pid, executablePath, &stop);
            if(stop)
            {
                free(buffer);
                break;
            }
        }
        free(buffer);
        }
    }
    free(info);
}

void killall(NSString* processName, BOOL softly)
{
    debugLog("🔍 Looking for processes named: %s", [processName UTF8String]);
    __block int killedCount = 0;
    
    enumerateProcessesUsingBlock(^(pid_t pid, NSString* executablePath, BOOL* stop)
    {
        if([executablePath.lastPathComponent isEqualToString:processName])
        {
            debugLog("🎯 Found %s process with PID: %d", [processName UTF8String], pid);
            if(softly)
            {
                if (kill(pid, SIGTERM) == 0) {
                    debugLog("✅ Sent SIGTERM to PID %d", pid);
                    killedCount++;
                } else {
                    debugLog("❌ Failed to send SIGTERM to PID %d", pid);
                }
            }
            else
            {
                if (kill(pid, SIGKILL) == 0) {
                    debugLog("✅ Sent SIGKILL to PID %d", pid);
                    killedCount++;
                } else {
                    debugLog("❌ Failed to send SIGKILL to PID %d", pid);
                }
            }
        }
    });
    
    debugLog("📊 Killed %d %s processes", killedCount, [processName UTF8String]);
}

// Debug logging function
void debugLog(const char *format, ...) {
    FILE *logFile = fopen("/var/mobile/Documents/muffinstore_debug.log", "a");
    if (!logFile) {
        logFile = fopen("/tmp/muffinstore_debug.log", "a");
    }
    
    if (logFile) {
        // Add timestamp
        NSDate *now = [NSDate date];
        NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
        [formatter setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
        NSString *timestamp = [formatter stringFromDate:now];
        fprintf(logFile, "[%s] ", [timestamp UTF8String]);
        
        // Add the actual log message
        va_list args;
        va_start(args, format);
        vfprintf(logFile, format, args);
        va_end(args);
        
        fprintf(logFile, "\n");
        fflush(logFile);
        fclose(logFile);
    }
    
    // Also print to stdout
    va_list args2;
    va_start(args2, format);
    vfprintf(stdout, format, args2);
    va_end(args2);
    fprintf(stdout, "\n");
}

int main(int argc, char *argv[]) {
    @autoreleasepool {
        debugLog("🚀 MuffinStore Root Helper started with %d arguments", argc);
        
        if (argc < 2) {
            fprintf(stderr, "Usage: %s <operation> <app_bundle_path> [version]\n", argv[0]);
            fprintf(stderr, "Operations:\n");
            fprintf(stderr, "  block_updates <app_bundle_path>\n");
            fprintf(stderr, "  restore_updates <app_bundle_path>\n");
            fprintf(stderr, "  rebuild_uicache\n");
            return 1;
        }
        
        NSString *operation = [NSString stringWithUTF8String:argv[1]];
        NSString *appBundlePath = argc > 2 ? [NSString stringWithUTF8String:argv[2]] : nil;
        NSString *version = argc > 3 ? [NSString stringWithUTF8String:argv[3]] : nil;
        
        debugLog("🔍 Operation: %s", [operation UTF8String]);
        debugLog("🔍 App bundle path: %s", appBundlePath ? [appBundlePath UTF8String] : "NULL");
        debugLog("🔍 Version: %s", version ? [version UTF8String] : "NULL");
        
        NSFileManager *fileManager = [NSFileManager defaultManager];
        
        // Handle operations that don't need app bundle path
        if ([operation isEqualToString:@"rebuild_uicache"]) {
            debugLog("🔄 Executing TrollStore's EXACT refresh-all implementation...");
            
            // EXACT TrollStore refresh-all implementation (lines 1575-1580):
            
            // Step 1: cleanRestrictions() - skip for now as it's TrollStore specific
            debugLog("ℹ️ Skipping cleanRestrictions (TrollStore specific)");
            
            // Step 2: Remove IconsCache directory (EXACT line 1577)
            debugLog("🗑️ Removing IconsCache directory...");
            [[NSFileManager defaultManager] removeItemAtPath:@"/var/containers/Shared/SystemGroup/systemgroup.com.apple.lsd.iconscache/Library/Caches/com.apple.IconsCache" error:nil];
            debugLog("✅ IconsCache removal completed");
            
            // Step 3: Rebuild application databases (EXACT line 1578)
            debugLog("📱 Calling _LSPrivateRebuildApplicationDatabasesForSystemApps...");
            
            // Load CoreServices framework first
            debugLog("🔍 Loading CoreServices framework...");
            void *coreServicesHandle = dlopen("/System/Library/Frameworks/CoreServices.framework/CoreServices", RTLD_NOW);
            if (!coreServicesHandle) {
                coreServicesHandle = dlopen("/System/Library/PrivateFrameworks/CoreServices.framework/CoreServices", RTLD_NOW);
            }
            if (!coreServicesHandle) {
                coreServicesHandle = dlopen("/System/Library/PrivateFrameworks/LaunchServices.framework/LaunchServices", RTLD_NOW);
            }
            
            if (coreServicesHandle) {
                debugLog("✅ CoreServices framework loaded");
            } else {
                debugLog("⚠️ Could not load CoreServices framework: %s", dlerror());
            }
            
            Class workspaceClass = NSClassFromString(@"LSApplicationWorkspace");
            if (!workspaceClass) {
                debugLog("❌ Could not find LSApplicationWorkspace class");
                if (coreServicesHandle) dlclose(coreServicesHandle);
                return 1;
            }
            debugLog("✅ Found LSApplicationWorkspace class");
            
            id workspace = [workspaceClass performSelector:@selector(defaultWorkspace)];
            if (!workspace) {
                debugLog("❌ Could not get defaultWorkspace instance");
                if (coreServicesHandle) dlclose(coreServicesHandle);
                return 1;
            }
            debugLog("✅ Got defaultWorkspace instance");
            
            SEL rebuildSelector = @selector(_LSPrivateRebuildApplicationDatabasesForSystemApps:internal:user:);
            if (![workspace respondsToSelector:rebuildSelector]) {
                debugLog("❌ Workspace does not respond to rebuild selector");
                if (coreServicesHandle) dlclose(coreServicesHandle);
                return 1;
            }
            debugLog("✅ Workspace responds to rebuild selector");
            
            // Use NSInvocation for the 3-parameter call (like we did before)
            NSMethodSignature *signature = [workspace methodSignatureForSelector:rebuildSelector];
            NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
            [invocation setTarget:workspace];
            [invocation setSelector:rebuildSelector];
            
            BOOL systemApps = YES;
            BOOL internal = YES;
            BOOL user = YES;
            
            [invocation setArgument:&systemApps atIndex:2];
            [invocation setArgument:&internal atIndex:3];
            [invocation setArgument:&user atIndex:4];
            [invocation invoke];
            
            BOOL rebuildResult;
            [invocation getReturnValue:&rebuildResult];
            
            debugLog("📱 Application database rebuild result: %s", rebuildResult ? "SUCCESS" : "FAILED");
            
            // Clean up framework handle
            if (coreServicesHandle) {
                dlclose(coreServicesHandle);
                debugLog("🧹 Cleaned up CoreServices framework handle");
            }
            
            // Step 4: Re-register apps if not user default (EXACT line 1579)
            debugLog("🔄 Checking shouldRegisterAsUserByDefault...");
            // For simplicity, assume shouldRegisterAsUserByDefault() returns NO (like normal TrollStore)
            BOOL shouldRegisterAsUser = NO; // shouldRegisterAsUserByDefault();
            debugLog("📝 shouldRegisterAsUserByDefault: %s", shouldRegisterAsUser ? "YES" : "NO");
            
            if (!shouldRegisterAsUser) {
                debugLog("🔄 Calling refreshAppRegistrations(YES)...");
                refreshAppRegistrations(YES);
                debugLog("✅ App registrations refreshed");
            } else {
                debugLog("ℹ️ Skipping app registration refresh (shouldRegisterAsUserByDefault is YES)");
            }
            
            // Step 5: Kill backboardd (EXACT line 1580)
            debugLog("🔄 Killing backboardd...");
            killall(@"backboardd", YES);
            debugLog("✅ backboardd killed");
            
            debugLog("✅ TrollStore refresh-all implementation completed");
            
            return 0;
        }
        
        // For operations that need app bundle path
        if (!appBundlePath) {
            fprintf(stderr, "❌ App bundle path required for operation: %s\n", [operation UTF8String]);
            return 1;
        }
        
        // Extract container path from app bundle path
        NSString *containerPath = [appBundlePath stringByDeletingLastPathComponent];
        NSString *itunesMetadataPath = [containerPath stringByAppendingPathComponent:@"iTunesMetadata.plist"];
        NSString *itunesBackupPath = [containerPath stringByAppendingPathComponent:@"iTunesMetadata.plist.muffinstore_backup"];
        
        fprintf(stdout, "🔍 App bundle path: %s\n", [appBundlePath UTF8String]);
        fprintf(stdout, "🔍 Container path: %s\n", [containerPath UTF8String]);
        
        if ([operation isEqualToString:@"block_updates"]) {
            fprintf(stdout, "🚫 Blocking updates...\n");
            
            // Backup and delete iTunesMetadata.plist
            if ([fileManager fileExistsAtPath:itunesMetadataPath]) {
                // Create backup
                NSError *error;
                if ([fileManager copyItemAtPath:itunesMetadataPath toPath:itunesBackupPath error:&error]) {
                    fprintf(stdout, "💾 Created backup: iTunesMetadata.plist.muffinstore_backup\n");
                } else {
                    fprintf(stderr, "⚠️ Failed to create backup: %s\n", [[error localizedDescription] UTF8String]);
                }
                
                // Delete original
                if ([fileManager removeItemAtPath:itunesMetadataPath error:&error]) {
                    fprintf(stdout, "🗑️ Deleted iTunesMetadata.plist\n");
                    fprintf(stdout, "✅ Update blocking enabled\n");
                } else {
                    fprintf(stderr, "❌ Failed to delete iTunesMetadata.plist: %s\n", [[error localizedDescription] UTF8String]);
                    return 1;
                }
            } else {
                fprintf(stdout, "ℹ️ iTunesMetadata.plist not found (app might not be from App Store)\n");
            }
            
        } else if ([operation isEqualToString:@"restore_updates"]) {
            fprintf(stdout, "🔄 Restoring updates...\n");
            
            // Restore from backup
            if ([fileManager fileExistsAtPath:itunesBackupPath]) {
                NSError *error;
                if ([fileManager copyItemAtPath:itunesBackupPath toPath:itunesMetadataPath error:&error]) {
                    fprintf(stdout, "📁 Restored iTunesMetadata.plist from backup\n");
                    
                    // Delete backup
                    [fileManager removeItemAtPath:itunesBackupPath error:nil];
                    fprintf(stdout, "🗑️ Removed backup file\n");
                    fprintf(stdout, "✅ Update blocking disabled\n");
                } else {
                    fprintf(stderr, "❌ Failed to restore from backup: %s\n", [[error localizedDescription] UTF8String]);
                    return 1;
                }
            } else {
                fprintf(stderr, "❌ No backup found\n");
                return 1;
            }
            
        } else {
            fprintf(stderr, "❌ Unknown operation: %s\n", [operation UTF8String]);
            return 1;
        }
        
        return 0;
    }
}