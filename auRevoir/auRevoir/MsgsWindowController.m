//
//  MsgsWindowController.m
//  auRevoir
//
//  Created by Patrick Wardle on 5/10/18.
//  Copyright © 2018 Objective-See. All rights reserved.
//

#import "Database.h"
#import "MsgsWindowController.h"

@implementation MsgsWindowController

@synthesize all;


//window load
-(void)windowDidLoad
{
    //super
    [super windowDidLoad];
    
    //start spinner
    [self.spinner startAnimation:nil];
    
    //set inset
    self.messages.textContainerInset = NSMakeSize(20, 20);
    
    //set footer
    // for all msg?
    if(YES == self.all)
    {
        //set
        self.footer.stringValue = @"All Notifications";
    }
    //set footer
    // for just Signal?
    else
    {
        //set
        self.footer.stringValue = @"Signal Notifications";
    }
    
    //in background
    // load all notification (msgs) from database
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0),
    ^{
          //load msgs
          [self loadMessages];
    });

    return;
}

//load msgs
-(void)loadMessages
{
    //database
    Database* database = nil;
    
    //messages
    NSMutableArray* messages = nil;
    
    //init
    database = [[Database alloc] init];
    
    //open
    if(YES == [database open])
    {
        //get msgs
        messages = [database getMessages:all];
        
        //show messages
        dispatch_async(dispatch_get_main_queue(),
        ^{
            //show
            [self displayMessages:messages];
        });
    }
    
    //error
    else
    {
        //show err msg
        dispatch_async(dispatch_get_main_queue(),
        ^{
            //stop spinner
            [self.spinner stopAnimation:nil];
            
            //hide msg
            self.label.hidden = YES;
            
            //set font
            self.messages.font = [NSFont fontWithName:@"Menlo-Bold" size:13];
            
            //error
            self.messages.string = @"ERROR: failed to open database.";
        
        });
    }
    
bail:
    
    //close db
    if(nil != database)
    {
        //close
        [database close];
    }
    
    return;
}

//display message in UI
// format some stuff like data/date, etc...
-(void)displayMessages:(NSMutableArray*)storedMessages
{
    //formatted messages
    NSMutableString* formattedMessages = nil;
    
    //formatted data
    NSMutableString* formattedData = nil;
    
    //data
    const void* data = nil;
    
    //alloc
    formattedMessages = [NSMutableString string];
    
    //stop spinner
    [self.spinner stopAnimation:nil];
    
    //hide msg
    self.label.hidden = YES;
    
    //no msgs?
    if(0 == storedMessages.count)
    {
        //set font
        self.messages.font = [NSFont fontWithName:@"Menlo-Bold" size:13];
        
        //all?
        if(YES == self.all)
        {
            //set msg
            self.messages.string = @"no notifications found 🤗";
        }
        //just 'Signal'
        else
        {
            //set msg
            self.messages.string = @"no (Signal) notifications found 🤗";
        }
        
        //bail
        goto bail;
    }
    
    //set font
    self.messages.font = [NSFont fontWithName:@"Menlo" size:11];
    
    //parse/format all messages
    for(NSMutableDictionary* message in storedMessages)
    {
        //add
        [formattedMessages appendString:@"SAVED MESSAGE 💬\n"];
        
        //format data?
        data = [[message[@"req"][@"atta"] firstObject][@"data"] bytes];
        if(NULL != data)
        {
            //format
            formattedData = [NSMutableString stringWithFormat:@"%c%c%c%c...", ((char*)data)[0], ((char*)data)[1], ((char*)data)[2],((char*)data)[3]];
            
            //remove
            [message[@"req"][@"atta"] removeObjectAtIndex:0];
            
            //insert
            [message[@"req"][@"atta"] insertObject:@{@"data":formattedData} atIndex:0];

        }
        
        //format date?
        if(nil != message[@"date"])
        {
            //format/replace
            message[@"date"] = [[NSDate alloc] initWithTimeIntervalSinceReferenceDate:[message[@"date"] floatValue]];
        }
        
        //add msg
        [formattedMessages appendString:message.description];
        
        //add extra space
        [formattedMessages appendString:@"\n\n"];
    }
    
    //add formatted msgs to UI
    self.messages.string = formattedMessages;
    
    //update footer
    // for all msg?
    if(YES == self.all)
    {
        //set
        self.footer.stringValue = [NSString stringWithFormat:@"All Notifications (count: %lu)", (unsigned long)storedMessages.count];
    }
    //update footer
    // for just Signal?
    else
    {
        //set
        self.footer.stringValue = [NSString stringWithFormat:@"Signal Notifications (count: %lu)", (unsigned long)storedMessages.count];
    }
    
bail:
    
    return;
}

//close
// end sheet
-(IBAction)close:(id)sender
{
    //end sheet
    [self.window.sheetParent endSheet:self.window returnCode:NSModalResponseOK];
    
    return;
}

@end
