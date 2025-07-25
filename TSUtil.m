#import "TSUtil.h"
#import <spawn.h>
#import <sys/wait.h>

NSString* rootHelperPath(void) {
    return [[NSBundle mainBundle].bundlePath stringByAppendingPathComponent:@"muffinhelper"];
}

int spawnRoot(NSString* path, NSArray* args, NSString** stdOut, NSString** stdErr) {
    NSMutableArray* argsM = args.mutableCopy ?: [NSMutableArray new];
    [argsM insertObject:path atIndex:0];
    
    NSUInteger argCount = [argsM count];
    char **argsC = (char **)malloc((argCount + 1) * sizeof(char*));
    
    for (NSUInteger i = 0; i < argCount; i++) {
        argsC[i] = strdup([[argsM objectAtIndex:i] UTF8String]);
    }
    argsC[argCount] = NULL;
    
    posix_spawnattr_t attr;
    posix_spawnattr_init(&attr);
    
    // Set persona to spawn as root
    posix_spawnattr_set_persona_np(&attr, 99, POSIX_SPAWN_PERSONA_FLAGS_OVERRIDE);
    posix_spawnattr_set_persona_uid_np(&attr, 0);
    posix_spawnattr_set_persona_gid_np(&attr, 0);
    
    posix_spawn_file_actions_t action;
    posix_spawn_file_actions_init(&action);
    
    int outErr[2];
    if(stdErr) {
        pipe(outErr);
        posix_spawn_file_actions_adddup2(&action, outErr[1], STDERR_FILENO);
        posix_spawn_file_actions_addclose(&action, outErr[0]);
    }
    
    int out[2];
    if(stdOut) {
        pipe(out);
        posix_spawn_file_actions_adddup2(&action, out[1], STDOUT_FILENO);
        posix_spawn_file_actions_addclose(&action, out[0]);
    }
    
    pid_t task_pid;
    int status = -200;
    int spawnError = posix_spawn(&task_pid, [path UTF8String], &action, &attr, (char* const*)argsC, NULL);
    posix_spawnattr_destroy(&attr);
    
    for (NSUInteger i = 0; i < argCount; i++) {
        free(argsC[i]);
    }
    free(argsC);
    
    if(spawnError != 0) {
        NSLog(@"posix_spawn error %d", spawnError);
        return spawnError;
    }
    
    // Read output
    NSMutableString* outString = [NSMutableString new];
    NSMutableString* errString = [NSMutableString new];
    
    if (stdOut) {
        close(out[1]);
        char buffer[4096];
        ssize_t bytesRead;
        while ((bytesRead = read(out[0], buffer, sizeof(buffer))) > 0) {
            NSString *chunk = [[NSString alloc] initWithBytes:buffer length:bytesRead encoding:NSUTF8StringEncoding];
            if (chunk) [outString appendString:chunk];
        }
        close(out[0]);
    }
    
    if (stdErr) {
        close(outErr[1]);
        char buffer[4096];
        ssize_t bytesRead;
        while ((bytesRead = read(outErr[0], buffer, sizeof(buffer))) > 0) {
            NSString *chunk = [[NSString alloc] initWithBytes:buffer length:bytesRead encoding:NSUTF8StringEncoding];
            if (chunk) [errString appendString:chunk];
        }
        close(outErr[0]);
    }
    
    // Wait for process to complete
    do {
        if (waitpid(task_pid, &status, 0) != -1) {
            NSLog(@"Child status %d", WEXITSTATUS(status));
        } else {
            perror("waitpid");
            return -222;
        }
    } while (!WIFEXITED(status) && !WIFSIGNALED(status));
    
    if (stdOut) {
        *stdOut = outString.copy;
    }
    if (stdErr) {
        *stdErr = errString.copy;
    }
    
    return WEXITSTATUS(status);
}