/*
 * da-veto: refuse Disk Arbitration mounts of one disk while the PSBBN
 * installer runs.
 *
 * Disk Arbitration re-probes a disk after every whole-disk write closes and
 * mounts its volumes under /Volumes again. A mounted volume makes the next
 * whole-disk open fail with EBUSY, and a freshly mounted volume cannot even
 * be unmounted for a few seconds. This approval client dissents from every
 * mount of the selected disk, except while the allow file exists, which is
 * how the installer's own mounts announce themselves.
 *
 *   da-veto diskN ALLOW-FILE KEEPER-PID
 *
 * Exits when the keeper process is gone. Runs as the user; no root needed.
 *
 * Build: clang -O2 -Wall -framework CoreFoundation -framework DiskArbitration \
 *              -o da-veto da-veto.c
 */
#include <CoreFoundation/CoreFoundation.h>
#include <DiskArbitration/DiskArbitration.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

static const char *g_disk;
static const char *g_allow;
static pid_t g_keeper;

static int is_ours(const char *bsd)
{
    size_t n = strlen(g_disk);
    if (strncmp(bsd, g_disk, n) != 0)
        return 0;
    return bsd[n] == '\0' || bsd[n] == 's';
}

static DADissenterRef approve(DADiskRef disk, void *context)
{
    (void)context;
    const char *bsd = DADiskGetBSDName(disk);
    if (bsd == NULL || !is_ours(bsd))
        return NULL;
    if (access(g_allow, F_OK) == 0) {
        fprintf(stderr, "da-veto: allowing mount of %s (installer asked)\n", bsd);
        return NULL;
    }
    fprintf(stderr, "da-veto: refusing mount of %s\n", bsd);
    /* Disk Arbitration releases the dissenter. */
    return DADissenterCreate(kCFAllocatorDefault, kDAReturnNotPermitted,
                             CFSTR("The PSBBN installer is using this disk."));
}

static void tick(CFRunLoopTimerRef timer, void *info)
{
    (void)timer;
    (void)info;
    if (kill(g_keeper, 0) != 0) {
        fprintf(stderr, "da-veto: installer (pid %d) is gone, exiting\n", (int)g_keeper);
        exit(0);
    }
}

int main(int argc, char **argv)
{
    if (argc != 4) {
        fprintf(stderr, "usage: da-veto diskN ALLOW-FILE KEEPER-PID\n");
        return 2;
    }
    g_disk = argv[1];
    g_allow = argv[2];
    g_keeper = (pid_t)atoi(argv[3]);
    if (strncmp(g_disk, "disk", 4) != 0 || strchr(g_disk + 4, 's') != NULL || g_keeper <= 0) {
        fprintf(stderr, "da-veto: expected a whole disk such as disk4 and a live pid\n");
        return 2;
    }
    if (strcmp(g_disk, "disk0") == 0) {
        fprintf(stderr, "da-veto: refusing to manage disk0\n");
        return 2;
    }
    DASessionRef session = DASessionCreate(kCFAllocatorDefault);
    if (session == NULL) {
        fprintf(stderr, "da-veto: DASessionCreate failed\n");
        return 1;
    }
    DARegisterDiskMountApprovalCallback(session, NULL, approve, NULL);
    DASessionScheduleWithRunLoop(session, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode);
    CFRunLoopTimerRef timer = CFRunLoopTimerCreate(kCFAllocatorDefault,
        CFAbsoluteTimeGetCurrent() + 1.0, 1.0, 0, 0, tick, NULL);
    CFRunLoopAddTimer(CFRunLoopGetCurrent(), timer, kCFRunLoopDefaultMode);
    printf("ready %s\n", g_disk);
    fflush(stdout);
    CFRunLoopRun();
    return 0;
}
