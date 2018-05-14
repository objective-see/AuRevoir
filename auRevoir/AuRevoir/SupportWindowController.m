//
//  Support.m
//  auRevoir
//
//  Created by Patrick Wardle on 5/10/18.
//  Copyright © 2018 Objective-See. All rights reserved.
//

#import "SupportWindowController.h"

//patreon url
#define PATREON_URL @"https://www.patreon.com/bePatron?c=701171"

@implementation SupportWindowController

//handle button click
// yes: open patreon page
//  no: exit application
- (IBAction)buttonHandler:(id)sender
{
    //yes?
    // load patreon url
    if(sender == self.yesButton)
    {
        //open URL
        // ->invokes user's default browser
        [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:PATREON_URL]];
        
        //close
        [self.window close];
    }

    //no?
    // just exit app
    else if(sender == self.noButton)
    {
        //ok, bye
        [NSApp terminate:nil];
    }
    
    return;
}

@end
