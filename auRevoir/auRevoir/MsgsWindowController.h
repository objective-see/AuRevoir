//
//  MsgsWindowController.h
//  auRevoir
//
//  Created by Patrick Wardle on 5/10/18.
//  Copyright © 2018 Objective-See. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface MsgsWindowController : NSWindowController

@property BOOL all;
@property (weak) IBOutlet NSTextField *label;
@property (weak) IBOutlet NSTextField *footer;
@property (weak) IBOutlet NSProgressIndicator *spinner;
@property (unsafe_unretained) IBOutlet NSTextView *messages;

@end
