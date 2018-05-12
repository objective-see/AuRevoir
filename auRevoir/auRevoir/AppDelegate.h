//
//  AppDelegate.h
//  auRevoir
//
//  Created by Patrick Wardle on 5/10/18.
//  Copyright © 2018 Objective-See. All rights reserved.
//

@import Cocoa;
#import <libproc.h>

#import "MsgsWindowController.h"
#import "SupportWindowController.h"

@interface AppDelegate : NSObject <NSApplicationDelegate>

@property (weak) IBOutlet NSBox *box;
@property (weak) IBOutlet NSButton *dumpDB;
@property (weak) IBOutlet NSWindow *window;
@property (weak) IBOutlet NSButton *viewAll;
@property (weak) IBOutlet NSButton *viewMsgs;
@property (weak) IBOutlet NSButton *removeAll;
@property (weak) IBOutlet NSTextField *status;
@property (weak) IBOutlet NSTextField *message;
@property (weak) IBOutlet NSButton *removeMsgs;
@property (weak) IBOutlet NSProgressIndicator *spinner;

//messages popup controller
@property (strong) MsgsWindowController *msgsWindowController;

//support window controller
@property (nonatomic, retain)SupportWindowController *supportWindowController;

/* METHODS */

//given a process path and user
// return array of all matching pids
-(NSMutableArray*) getProcessIDs:(NSString*)processPath user:(int)user;

@end

