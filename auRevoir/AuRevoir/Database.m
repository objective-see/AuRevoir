//
//  Database.m
//  auRevoir
//
//  Created by Patrick Wardle on 5/10/18.
//  Copyright © 2018 Objective-See. All rights reserved.
//

#import "Database.h"

//tables in notification db
NSString * const TABLES[] = {@"delivered", @"displayed", @"record", @"requests", @"snoozed"};

@implementation Database

@synthesize database;

//open db
-(BOOL)open
{
    //flag
    BOOL opened = NO;
    
    //path
    NSString* path = nil;
    
    //init path
    path = [NSString stringWithFormat:@"%@/0/com.apple.notificationcenter/db2/db", [NSTemporaryDirectory() stringByDeletingLastPathComponent]];
    
    //dbg msg
    NSLog(@"opening %@", path);
    
    //sanity check
    if(YES != [[NSFileManager defaultManager] fileExistsAtPath:path])
    {
        //err msg
        NSLog(@"ERROR: 'notification' database is missing...");
        
        //bail
        goto bail;
    }
    
    //open db
    if(sqlite3_open(path.UTF8String, &database) != SQLITE_OK)
    {
        //bail
        goto bail;
    }
    
    //happy
    opened = YES;
    
bail:
    
    return opened;
}

//close db
-(void)close
{
    //close db
    if(nil != self.database)
    {
        //close
        sqlite3_close(self.database);
        
        //unset
        self.database = nil;
    }
    
    return;
}

//get app id of Signal
-(NSInteger)getSignalID
{
    //id
    NSInteger signalID = -1;

    //statement
    sqlite3_stmt * statement = NULL;
    
    //prep statement
    if(SQLITE_OK != sqlite3_prepare_v2(database, "select * from app where identifier = 'org.whispersystems.signal-desktop'", -1, &statement, nil))
    {
        //bail
        goto bail;
    }
    
    //extract 'Signal' app id
    while(sqlite3_step(statement) == SQLITE_ROW)
    {
        //extract
        signalID = sqlite3_column_int(statement, 0);
        
        break;
    }
    
bail:
    
    //finalize statement
    if(NULL != statement)
    {
        //finalize
        sqlite3_finalize(statement);
        
        //unset
        statement = NULL;
    }

    return signalID;
}

//get all msgs
-(NSMutableArray*)getMessages:(BOOL)all
{
    //msg
    NSMutableArray* messages = nil;
    
    //id
    NSInteger signalID = -1;
    
    //sql statement
    sqlite3_stmt* statement = NULL;
    
    //plist
    NSDictionary* plist = nil;
    
    //all?
    if(YES == all)
    {
        //dbg msg
        NSLog(@"extracting all notifications");
        
        //prep statement
        if(SQLITE_OK != sqlite3_prepare_v2(database, "SELECT data FROM record", -1, &statement, nil))
        {
            //bail
            goto bail;
        }
    }
    //just Signal
    else
    {
        //get signal ID
        signalID = [self getSignalID];
        if(-1 == signalID)
        {
            //bail
            goto bail;
        }
        
        //dbg msg
        NSLog(@"extracting all Signal notifications ('app_id' is %lu)", signalID);
        
        //prep statement
        if(SQLITE_OK != sqlite3_prepare_v2(database, [[NSString stringWithFormat:@"SELECT data FROM record WHERE app_id == %lu", (long)signalID] UTF8String], -1, &statement, nil))
        {
            //bail
            goto bail;
        }
    }

    //alloc messages
    messages = [NSMutableArray array];
    
    //iterate over all
    // just grab/covert binary data
    while(SQLITE_ROW == sqlite3_step(statement))
    {
        //try
        @try
        {
            //grab
            plist = [NSPropertyListSerialization propertyListWithData:[NSData dataWithBytes:sqlite3_column_blob(statement, 0) length:sqlite3_column_bytes(statement, 0)] options:NSPropertyListMutableContainers format:nil error:nil];
        }
        //catch
        @catch(NSException *exception)
        {
            //skip
            continue;
        }
        
        //skip error
        if(nil == plist)
        {
            continue;
        }
        
        //save
        [messages addObject:plist];
    }
    
bail:
    
    //finalize statement
    if(NULL != statement)
    {
        //finalize
        sqlite3_finalize(statement);
        
        //unset
        statement = NULL;
    }
    
    return messages;
}

//remove notifcations (msgs)
-(NSUInteger)removeMessages:(BOOL)all
{
    //rows removed
    NSUInteger removedMessages = 0;
    
    //id
    NSInteger signalID = -1;
    
    //remove all notifications?
    if(YES == all)
    {
        //dbg msg
        NSLog(@"removing all notifications");
        
        //delete for each table
        for(NSUInteger i=0; i < sizeof(TABLES)/sizeof(TABLES[0]); i++)
        {
            //delete
            if(SQLITE_OK != sqlite3_exec(database, [[NSString stringWithFormat:@"DELETE FROM %@", TABLES[i]] UTF8String], NULL, NULL, NULL))
            {
                //err msg
                NSLog(@"ERROR: failed to remove rows from %@", TABLES[i]);
                
                //skip
                continue;
            }
            
            //save for 'record'
            if(YES == [TABLES[i] isEqualToString:@"record"])
            {
                //get results
                removedMessages = sqlite3_changes(database);
            }
            
            //dbg msg
            NSLog(@"removed all rows table '%@'", TABLES[i]);
        }
    }
    //remove just Signal notifications?
    else
    {
        //get signal ID
        signalID = [self getSignalID];
        if(-1 == signalID)
        {
            //bail
            goto bail;
        }
        
        //dbg msg
        NSLog(@"removing all Signal notifications ('app_id' is %lu)", signalID);
        
        //delete for each table
        for(NSUInteger i=0; i < sizeof(TABLES)/sizeof(TABLES[0]); i++)
        {
            //delete
            if(SQLITE_OK != sqlite3_exec(database, [[NSString stringWithFormat:@"DELETE FROM %@ WHERE app_id == %lu", TABLES[i], (long)signalID] UTF8String], NULL, NULL, NULL))
            {
                //err msg
                NSLog(@"ERROR: failed to remove rows from %@", TABLES[i]);
                
                //skip
                continue;
            }
            
            //save for 'record'
            if(YES == [TABLES[i] isEqualToString:@"record"])
            {
                //get results
                removedMessages = sqlite3_changes(database);
            }
            
            //dbg msg
            NSLog(@"removed all rows table '%@'", TABLES[i]);
        }
    }
    
bail:
    
    return removedMessages;
}

//dump all notification records
-(NSMutableArray*)dumpRecords
{
    //records
    NSMutableArray* records = nil;
    
    //plist
    NSDictionary* plist = nil;
    
    //alloc
    records = [NSMutableArray array];
    
    //sql statement
    sqlite3_stmt * statement = NULL;
    
    //prep statment
    if(SQLITE_OK != sqlite3_prepare_v2(database, "SELECT data FROM record", -1, &statement, nil))
    {
        //bail
        goto bail;
    }
    
    //execute/step
    while(sqlite3_step(statement) == SQLITE_ROW)
    {
        //convert
        plist =  [NSPropertyListSerialization propertyListWithData:[NSData dataWithBytes:sqlite3_column_blob(statement, 0) length:sqlite3_column_bytes(statement, 0)] options:NSPropertyListMutableContainers format:nil error:nil];
        
        //skip errors
        if(nil == plist)
        {
            continue;
        }
        
        //save
        [records addObject:plist];
    }
    
bail:
    
    //finalize statement
    if(NULL != statement)
    {
        //finalize
        sqlite3_finalize(statement);
        
        //unset
        statement = NULL;
    }
    
    return records;
}

@end
