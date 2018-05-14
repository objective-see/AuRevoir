//
//  AppDelegate.m
//  auRevoir
//
//  Created by Patrick Wardle on 5/10/18.
//  Copyright © 2018 Objective-See. All rights reserved.
//

#import "Database.h"
#import "AppDelegate.h"

#import <signal.h>
#import <unistd.h>
#import <libproc.h>
#import <sys/stat.h>
#import <arpa/inet.h>
#import <sys/socket.h>
#import <sys/sysctl.h>
#import <Security/Security.h>
#import <Foundation/Foundation.h>
#import <CommonCrypto/CommonDigest.h>
#import <SystemConfiguration/SystemConfiguration.h>

@implementation AppDelegate

@synthesize box;
@synthesize window;
@synthesize message;
@synthesize supportWindowController;

//init UI
-(void)awakeFromNib
{
    //when supported
    // indicate title bar is transparent (too)
    if(YES == [self.window respondsToSelector:@selector(titlebarAppearsTransparent)])
    {
        //set transparency
        self.window.titlebarAppearsTransparent = YES;
    }
    
    //center
    [self.window center];
    
    //make white
    [self.window setBackgroundColor: NSColor.whiteColor];
    
    //enable message layer
    self.message.wantsLayer = YES;
    
    //set label color
    message.layer.backgroundColor = [[NSColor clearColor] CGColor];
    
    //no label bezel
    message.bezeled = NO;
    
    //enable box layer
    self.box.wantsLayer = YES;
    
    //set box mask
    self.box.layer.masksToBounds = YES;
    
    //set box corners corners
    self.box.layer.cornerRadius = 10.0;

    return;
}

//finish launched
// finalize some UI stuffz
-(void)applicationDidFinishLaunching:(NSNotification *)notification
{
    //enable box layer
    self.box.wantsLayer = YES;
    
    //set box mask
    self.box.layer.masksToBounds = YES;
    
    //set box corners corners
    self.box.layer.cornerRadius = 10.0;
    
    //make it key window
    [self.window makeKeyAndOrderFront:self];
    
    //make window front
    [NSApp activateIgnoringOtherApps:YES];
    
    return;
}

//button handler
// remove messages
-(IBAction)buttonHandler:(id)sender
{
    //flag
    BOOL all = NO;
    
    //unset msg
    self.status.stringValue = @"";
    
    //show msgs button
    if(sender == self.viewMsgs)
    {
        //alloc sheet
        self.msgsWindowController = [[MsgsWindowController alloc] initWithWindowNibName:@"MsgsWindow"];
        
        //set 'all' flag
        self.msgsWindowController.all = (BOOL)self.viewAll.state;
        
        //show message sheet
        [self.window beginSheet:self.msgsWindowController.window completionHandler:^(NSModalResponse returnCode) {
            
            //unset window controller
            self.msgsWindowController = nil;
            
        }];
    }
    
    //remove msgs button
    else if(sender == self.removeMsgs)
    {
        //disable view msgs button
        self.viewMsgs.enabled = NO;
        
        //disable remove msgs button
        self.removeMsgs.enabled = NO;
        
        //confirm
        // bail if user user cancels
        if(NSAlertFirstButtonReturn != [self showAlert])
        {
            //(re)enable button
            self.viewMsgs.enabled = YES;
            
            //(re)enable button
            self.removeMsgs.enabled = YES;
            
            //bail
            goto bail;
        }
        
        //show spinnger
        [self.spinner startAnimation:nil];
        
        //set label
        self.status.stringValue = @"removing messages...";
        
        //get button state (while on main thread)
        all = self.removeAll.state;
        
        //invoke logic to install/uninstall
        // do in background so UI doesn't block
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0),
        ^{
            //nap a second to allow msg to show
            [NSThread sleepForTimeInterval:1.0];
            
            //remove
            [self removeMessages:all];
            
        });
    }
    
    //dump db button
    else if(sender == self.dumpDB)
    {
        //disable view msgs button
        self.viewMsgs.enabled = NO;
        
        //disable remove msgs button
        self.removeMsgs.enabled = NO;
        
        //show spinnger
        [self.spinner startAnimation:nil];
        
        //set label
        self.status.stringValue = @"dumping all records...";
        
        //invoke logic to install/uninstall
        // do in background so UI doesn't block
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0),
        ^{
           //nap a second to allow msg to show
           [NSThread sleepForTimeInterval:1.0];
           
           //remove
           [self dumpRecords];
           
        });
    }
    
bail:
    
    return;
}

//so alert
// returns response
-(NSUInteger)showAlert
{
    //alert
    NSAlert* alert = nil;
    
    //response
    NSUInteger response = 0;
    
    //init alert
    alert = [[NSAlert alloc] init];
    
    //set style
    [alert setAlertStyle:NSAlertStyleCritical];
    
    //set main text
    alert.messageText = @"Warning";
    
    //set informative text
    alert.informativeText = @"This will modify the system 'notification database'";
    
    //button: 'ok'
    [alert addButtonWithTitle:@"OK"];
    
    //button: 'cancel;
    [alert addButtonWithTitle:@"Cancel"];
    
    //show it
    response = [alert runModal];
    
    return response;
}

//open dbg and remove all signal msgs
-(void)removeMessages:(BOOL)all
{
    //database
    Database* database = nil;
    
    //pid of usernoted
    pid_t usernoted = 0;
    
    //rows removed
    NSUInteger removedMessages = 0;
    
    //err msg
    NSString* errMsg = nil;
    
    //init 
    database = [[Database alloc] init];
    
    //get pid of user notification daemon
    // then suspend daemon, just to be safe...
    usernoted = [[[self getProcessIDs:@"/usr/sbin/usernoted" user:getuid()] firstObject] intValue];
    if(0 != usernoted)
    {
        //suspend
        if(-1 == kill(usernoted, SIGSTOP))
        {
            //err msg
            NSLog(@"ERROR: failed to suspend 'usernoted' (%d)", usernoted);
        }
    }
    
    //open db
    if(YES != [database open])
    {
        //set msg
        errMsg = @"ERROR: failed to open database.";
        
        //bail
        goto bail;
    }

    //remove msgs
    removedMessages = [database removeMessages:all];
    
    //restart user notification daemon
    // send it a kill, launchd will restart!
    if(0 != usernoted)
    {
        //kill
        kill(usernoted, SIGKILL);
    }
    
bail:
    
    //close db
    if(nil != database)
    {
        //close
        [database close];
    }
    
    //update UI
    dispatch_async(dispatch_get_main_queue(),
    ^{
       //enable view msgs button
       self.viewMsgs.enabled = YES;
       
       //enable remove msgs button
       self.removeMsgs.enabled = YES;
       
       //stop/hide spinnger
       [self.spinner stopAnimation:nil];
       
       //set msg
       if(nil == errMsg)
       {
           //all?
           if(YES == self.removeAll.state)
           {
               //set
               self.status.stringValue = [NSString stringWithFormat:@"removed %lu notifications.", removedMessages];
           }
           //just 'Signal'
           else
           {
               //results
               self.status.stringValue = [NSString stringWithFormat:@"removed %lu Signal notifications.", removedMessages];
           }
       }
        
       //err msg
       else
       {
           //err
           self.status.stringValue = errMsg;
       }
    
    });
    
    return;
}

//dump records
-(void)dumpRecords
{
    //results
    NSMutableArray* records = nil;
    
    //database
    Database* database = nil;
    
    //init
    database = [[Database alloc] init];
    
    //open
    if(YES != [database open])
    {
        //err msg
        NSLog(@"ERROR: failed to open database.");
        
        //bail
        goto bail;
    }
    
    //dump records
    records = [database dumpRecords];

bail:
    
    //close db
    if(nil != database)
    {
        //close
        [database close];
    }
    
    //update UI
    dispatch_async(dispatch_get_main_queue(),
    ^{
        //save
        [self saveResults:records];
   });
    
    return;
}

//save results
-(void)saveResults:(NSMutableArray*)results
{
    //save panel
    NSSavePanel *panel = nil;
    
    //flag
    __block BOOL saved = NO;
    
    //create panel
    panel = [NSSavePanel savePanel];
    
    //suggest file name
    [panel setNameFieldStringValue:@"notifications.txt"];
    
    //show panel
    // completion handler will invoked when user clicks 'ok'
    [panel beginWithCompletionHandler:^(NSInteger result)
    {
         //enable view msgs button
         self.viewMsgs.enabled = YES;
         
         //enable remove msgs button
         self.removeMsgs.enabled = YES;
         
         //stop/hide spinnger
         [self.spinner stopAnimation:nil];
        
         //(un)set msg
         self.status.stringValue = @"";
         
         //only need to handle 'ok'
         if(NSModalResponseOK == result)
         {
             //save
             saved = [results writeToFile:panel.URL.path atomically:NO];
             
             //happy?
             if(YES == saved)
             {
                 //set msg
                 self.status.stringValue = @"all notification records saved!";
             }
             //error
             else
             {
                 //set msg
                 self.status.stringValue = @"ERROR: failed to save notification records.";
             }
             
         }//clicked 'ok' (to save)
        
     }]; //panel callback
    
    return;
}

//given a process path and user
// return array of all matching pids
-(NSMutableArray*) getProcessIDs:(NSString*)processPath user:(int)user
{
    //number of pids
    int numberOfPIDs = -1;
    
    //process IDs
    NSMutableArray* processIDs = nil;
    
    //array of pids
    pid_t* pids = NULL;
    
    //current path
    NSString* currentPath = nil;
    
    //process info struct
    struct kinfo_proc procInfo = {0};
    
    //size of struct
    size_t procInfoSize = sizeof(procInfo);
    
    //mib
    int mib[4] = {CTL_KERN, KERN_PROC, KERN_PROC_PID, -1};
    
    //buffer for process path
    char pathBuffer[PROC_PIDPATHINFO_MAXSIZE] = {0};
    
    //alloc
    processIDs = [NSMutableArray array];
    
    //get # of pids
    numberOfPIDs = proc_listallpids(NULL, 0);
    if(-1 == numberOfPIDs)
    {
        //bail
        goto bail;
    }
    
    //alloc buffer for pids
    pids = calloc(numberOfPIDs, sizeof(pid_t));
    if(nil == pids)
    {
        //bail
        goto bail;
    }
    
    //get list of pids
    numberOfPIDs = proc_listallpids(pids, numberOfPIDs*sizeof(pid_t));
    if(-1 == numberOfPIDs)
    {
        //bail
        goto bail;
    }
    
    //iterate over all pids
    // get name for each process
    for(int i = 0; i < numberOfPIDs; i++)
    {
        //reset buffer
        bzero(pathBuffer, PROC_PIDPATHINFO_MAXSIZE);
        
        //skip blank pids
        if(0 == pids[i])
        {
            //skip
            continue;
        }
        
        //get process path
        if(0 != proc_pidpath(pids[i], pathBuffer, sizeof(pathBuffer)))
        {
            //init task's name
            currentPath = [NSString stringWithUTF8String:pathBuffer];
        }
        
        //skip if path doesn't match
        if(YES != [processPath isEqualToString:currentPath])
        {
            //next
            continue;
        }
        
        //need to also match on user?
        // caller can pass in -1 to skip this check
        if(-1 != user)
        {
            //init mib
            mib[0x3] = pids[i];
            
            //make syscall to get proc info for user
            if( (0 != sysctl(mib, 0x4, &procInfo, &procInfoSize, NULL, 0)) ||
                (0 == procInfoSize) )
            {
                //skip
                continue;
            }
            
            //skip if user id doesn't match
            if(user != (int)procInfo.kp_eproc.e_ucred.cr_uid)
            {
                //skip
                continue;
            }
        }
        
        //got match
        // add to list
        [processIDs addObject:[NSNumber numberWithInt:pids[i]]];
    }
    
bail:
    
    //free buffer
    if(NULL != pids)
    {
        //free
        free(pids);
        
        //reset
        pids = NULL;
    }
    
    return processIDs;
}


//trigger app close when window is closed
-(BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender
{
    return YES;
}

//show support
-(NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender
{
    //reply
    NSApplicationTerminateReply reply = NSTerminateNow;
    
    //alloc/init
    if(nil == self.supportWindowController)
    {
        //alloc
        supportWindowController = [[SupportWindowController alloc] initWithWindowNibName:@"Support"];
        
        //make white
        [self.supportWindowController.window setBackgroundColor: NSColor.whiteColor];
        
        //center window
        [self.supportWindowController.window center];
        
        //show it
        [self.supportWindowController showWindow:self];
        
        //don't exit (yet)
        reply = NSTerminateCancel;
    }
    
    return reply;
}

@end
