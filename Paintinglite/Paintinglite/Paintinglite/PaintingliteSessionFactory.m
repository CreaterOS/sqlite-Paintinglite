//
//  PaintingliteSessionFactory.m
//  Paintinglite
//
//  Created by Bryant Reyn on 2020/5/26.
//  Copyright © 2020 Bryant Reyn. All rights reserved.
//

#import "PaintingliteSessionFactory.h"
#import "PaintingliteLog.h"

@interface PaintingliteSessionFactory()
@property (nonatomic)sqlite3_stmt *stmt;
@property (nonatomic,strong)PaintingliteLog *log; //日志
@end

@implementation PaintingliteSessionFactory

#pragma mark - 懒加载
- (PaintingliteLog *)log{
    if (!_log) {
        _log = [PaintingliteLog sharePaintingliteLog];
    }
    
    return _log;
}

#pragma mark - 单例模式
static PaintingliteSessionFactory *_instance = nil;
+ (instancetype)sharePaintingliteSessionFactory{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _instance = [[self alloc] init];
    });
    
    return _instance;
}

#pragma mark - 执行查询
- (void)execQuery:(sqlite3 *)ppDb sql:(NSString *)sql{
    NSMutableArray<NSString *> *tables = [NSMutableArray array];
    
    if (sqlite3_prepare(ppDb, [sql UTF8String], -1, &_stmt, nil) == SQLITE_OK){
        //查询成功
        while (sqlite3_step(_stmt) == SQLITE_ROW) {
            //获得数据库中含有的表名
            char *name = (char *)sqlite3_column_text(_stmt, 0);
            [tables addObject:[NSString stringWithFormat:@"%s",name]];
        }
    }else{
        //写入日志文件
        [self.log writeLogFileOptions:@"Select The Database Have Tables " status:PaintingliteLogError completeHandler:^(NSString * _Nonnull logFilePath) {
            ;
        }];
    }
    
    //写入JSON快照
    [self writeTablesSnapJSON:tables];
    
    //写入日志文件
    [self.log writeLogFileOptions:sql status:PaintingliteLogSuccess completeHandler:^(NSString * _Nonnull logFilePath) {
        ;
    }];
}

#pragma mark - 写入JSON快照
- (void)writeTablesSnapJSON:(NSMutableArray *)tables{
    NSDictionary *tablesSnapDict = @{@"TablesSnap":tables};
    //写入JSON文件
    @synchronized (self) {
        if ([NSJSONSerialization isValidJSONObject:tablesSnapDict]) {
            NSError *error = nil;
            NSData *data = [NSJSONSerialization dataWithJSONObject:tablesSnapDict options:NSJSONWritingPrettyPrinted error:&error];
            
            NSString *TablesSnapJsonPath = [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject] stringByAppendingPathComponent:@"Tables_Snap.json"];
            NSFileManager *fileManager = [NSFileManager defaultManager];
            
            if ([fileManager fileExistsAtPath:TablesSnapJsonPath]) {
                [fileManager removeItemAtPath:TablesSnapJsonPath error:&error];
            }
            
            //判断是否存则这个文件
            [data writeToFile:TablesSnapJsonPath atomically:YES];
        }
        [tables removeAllObjects];
        tables = nil;
        tablesSnapDict = nil;
    }
}

@end
