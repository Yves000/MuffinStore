#import <Foundation/Foundation.h>
#import <spawn.h>

// POSIX spawn persona management constants
#define POSIX_SPAWN_PERSONA_FLAGS_OVERRIDE 1

// Function declarations for persona management
extern int posix_spawnattr_set_persona_np(const posix_spawnattr_t* __restrict, uid_t, uint32_t);
extern int posix_spawnattr_set_persona_uid_np(const posix_spawnattr_t* __restrict, uid_t);
extern int posix_spawnattr_set_persona_gid_np(const posix_spawnattr_t* __restrict, uid_t);

// Spawn a process as root using persona management
int spawnRoot(NSString* path, NSArray* args, NSString** stdOut, NSString** stdErr);

// Get the root helper path
NSString* rootHelperPath(void);