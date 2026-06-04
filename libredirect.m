#import <Foundation/Foundation.h>
#include <pwd.h>
#include <unistd.h>
#include <string.h>
#include <stdio.h>
#include <stdlib.h>

// Forward declare original functions
extern NSString *NSHomeDirectory(void);
extern NSArray *NSSearchPathForDirectoriesInDomains(NSSearchPathDirectory directory, NSSearchPathDomainMask domainMask, BOOL expandTilde);

// Define replacement functions
NSString *new_NSHomeDirectory(void) {
    char *custom_home = getenv("CUSTOM_HOME");
    if (custom_home) {
        return [NSString stringWithUTF8String:custom_home];
    }
    return NSHomeDirectory();
}

NSArray *new_NSSearchPathForDirectoriesInDomains(NSSearchPathDirectory directory, NSSearchPathDomainMask domainMask, BOOL expandTilde) {
    char *custom_home = getenv("CUSTOM_HOME");
    if (custom_home) {
        if (directory == NSApplicationSupportDirectory) {
            NSString *path = [NSString stringWithFormat:@"%s/Library/Application Support", custom_home];
            [[NSFileManager defaultManager] createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:nil];
            return @[path];
        } else if (directory == NSLibraryDirectory) {
            NSString *path = [NSString stringWithFormat:@"%s/Library", custom_home];
            [[NSFileManager defaultManager] createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:nil];
            return @[path];
        } else if (directory == NSCachesDirectory) {
            NSString *path = [NSString stringWithFormat:@"%s/Library/Caches", custom_home];
            [[NSFileManager defaultManager] createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:nil];
            return @[path];
        }
    }
    return NSSearchPathForDirectoriesInDomains(directory, domainMask, expandTilde);
}

struct passwd *new_getpwuid(uid_t uid) {
    struct passwd *pwd = getpwuid(uid);
    char *custom_home = getenv("CUSTOM_HOME");
    if (pwd && custom_home) {
        static char custom_dir[1024];
        strncpy(custom_dir, custom_home, sizeof(custom_dir) - 1);
        custom_dir[sizeof(custom_dir) - 1] = '\0';
        pwd->pw_dir = custom_dir;
    }
    return pwd;
}

int new_getpwuid_r(uid_t uid, struct passwd *pwd, char *buffer, size_t bufsize, struct passwd **result) {
    int res = getpwuid_r(uid, pwd, buffer, bufsize, result);
    char *custom_home = getenv("CUSTOM_HOME");
    if (res == 0 && *result && pwd && custom_home) {
        static char custom_dir[1024];
        strncpy(custom_dir, custom_home, sizeof(custom_dir) - 1);
        custom_dir[sizeof(custom_dir) - 1] = '\0';
        pwd->pw_dir = custom_dir;
    }
    return res;
}

// Interpose table
typedef struct interpose_s {
    void *new_func;
    void *orig_func;
} interpose_t;

__attribute__((used)) static const interpose_t interposition[]
__attribute__((section("__DATA,__interpose"))) = {
    { (void *)new_NSHomeDirectory, (void *)NSHomeDirectory },
    { (void *)new_NSSearchPathForDirectoriesInDomains, (void *)NSSearchPathForDirectoriesInDomains },
    { (void *)new_getpwuid, (void *)getpwuid },
    { (void *)new_getpwuid_r, (void *)getpwuid_r }
};
