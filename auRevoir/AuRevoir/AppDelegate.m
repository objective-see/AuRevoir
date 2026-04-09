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
    //[self.window setBackgroundColor: NSColor.whiteColor];
    
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
    
    //center window
    [self.window center];

    //make it key window
    [self.window makeKeyAndOrderFront:self];

    //make window front
    [NSApp activate];
    
    //FDA check
    [self requestFDA];
    
    return;
}

//request full disk access
-(void)requestFDA
{
    //alert
    __block NSAlert* infoAlert = nil;

    if(!hasFDA()) {
    
        //alloc alert
        infoAlert = [[NSAlert alloc] init];
        
        NSString *settingsName = nil;
        if (@available(macOS 13.0, *))
            settingsName = @"System Settings";
        else
            settingsName = @"System Preferences";

        //set msg
        infoAlert.informativeText = [NSString stringWithFormat:
            NSLocalizedString(@"AuRevoir needs Full Disk Access to scan the Notification Database\n\nClick 'Open' to open %@ and grant access.", nil),
            settingsName];
        
        //ok button
        [infoAlert addButtonWithTitle:NSLocalizedString(@"Open", @"Open")];
        
        //alert button
        [infoAlert addButtonWithTitle:NSLocalizedString(@"Cancel", @"Cancel")];
        
        //show 'alert' and capture user response
        // user clicked 'OK'? -> open System Preferences
        if(NSAlertFirstButtonReturn == [infoAlert runModal])
        {
            //open System Settings / System Preferences
            if (@available(macOS 13.0, *))
            {
                [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_AllFiles"]];
            }
            else
            {
                [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles"]];
            }
        }
        //close
        else
        {
            //close
            [NSApp terminate:nil];
        }
    }
    
    return;
}

//full disk access check
// no API for this, so let's just see if we can read user's TCC.db
BOOL hasFDA(void) {
    
    //tcc path
    NSString* tccPath = [NSHomeDirectory() stringByAppendingPathComponent:@"Library/Application Support/com.apple.TCC/TCC.db"];
    
    //FDA check
    // is 'protected' file readable
    return [NSFileManager.defaultManager isReadableFileAtPath:tccPath];
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
        self.status.stringValue = @"Removing messages...";
        
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
        self.status.stringValue = @"Saving all records...";
        
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
    alert.informativeText = @"This will modify macOS' \"Notification\" database";
    
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

    //rows removed
    NSUInteger removedMessages = 0;

    //err msg
    NSString* errMsg = nil;

    //init
    database = [[Database alloc] init];

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
               self.status.stringValue = [NSString stringWithFormat:@"Removed %lu notifications.", removedMessages];
           }
           //just 'Signal'
           else
           {
               //results
               self.status.stringValue = [NSString stringWithFormat:@"Removed %lu Signal notifications.", removedMessages];
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

//trigger app close when window is closed
-(BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender
{
    return YES;
}

@end
