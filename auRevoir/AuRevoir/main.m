//
//  main.m
//  auRevoir
//
//  Created by Patrick Wardle on 5/10/18.
//  Copyright © 2018 Objective-See. All rights reserved.
//

#import <Cocoa/Cocoa.h>

int main(int argc, const char * argv[])
{
    //status
    int status = -1;
    
    //os version
    NSOperatingSystemVersion osVersion = {0,0,0};
    
    //alert
    NSAlert* alert = nil;
    
    //get os version
    osVersion = [[NSProcessInfo processInfo] operatingSystemVersion];
    
    //only support h sierra
    if(osVersion.minorVersion != 13)
    {
        //init alert
        alert = [[NSAlert alloc] init];
        
        //set main text
        alert.messageText = @"Unsupported OS";
        
        //set informative text
        alert.informativeText = [NSString stringWithFormat:@"macOS %@\nis not supported.", [[NSProcessInfo processInfo] operatingSystemVersionString]];
        
        //button: 'ok'
        [alert addButtonWithTitle:@"OK"];
        
        //show
        [alert runModal];
    
        //bail
        goto bail;
    }
    
    //app main
    status = NSApplicationMain(argc, argv);
    
bail:
    
    return status;
}
