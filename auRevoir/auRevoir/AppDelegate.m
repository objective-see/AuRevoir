//
//  AppDelegate.m
//  auRevoir
//
//  Created by Patrick Wardle on 5/10/18.
//  Copyright © 2018 Objective-See. All rights reserved.
//

#import "Database.h"
#import "AppDelegate.h"

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

//delegate
// show 'warnign' alert
-(void)applicationDidFinishLaunching:(NSNotification *)notification
{
    //alert
    NSAlert* alert =  nil;
    
    //init alert
    alert = [[NSAlert alloc] init];
    
    //enable box layer
    self.box.wantsLayer = YES;
    
    //set box mask
    self.box.layer.masksToBounds = YES;
    
    //set box corners corners
    self.box.layer.cornerRadius = 10.0;
    
    //set main text
    alert.messageText = @"Aloha!";
    
    //set informative text
    alert.informativeText = @"This app shouldn't break anything\n\t   ...but, use at your own risk!";
    
    //add button
    [alert addButtonWithTitle:@"Ok"];
    
    //set style
    alert.alertStyle = NSAlertStyleWarning;
    
    //show it
    [alert runModal];
    
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
    return;
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
    
    //open
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
