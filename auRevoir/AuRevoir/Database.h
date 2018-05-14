//
//  Database.h
//  auRevoir
//
//  Created by Patrick Wardle on 5/10/18.
//  Copyright © 2018 Objective-See. All rights reserved.
//

#import <sqlite3.h>
#import <Foundation/Foundation.h>

@interface Database : NSObject

@property sqlite3 *database;

/* METHODS */

//open db
-(BOOL)open;

//close db
-(void)close;

//get all (Signal) msgs
-(NSMutableArray*)getMessages:(BOOL)all;

//remove all (Signal) msgs
-(NSUInteger)removeMessages:(BOOL)all;

//dump all notification records
-(NSMutableArray*)dumpRecords;

@end
