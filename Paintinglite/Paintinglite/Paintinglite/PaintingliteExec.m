//
//  PaintingliteExec.m
//  Paintinglite
//
//  Created by Bryant Reyn on 2020/5/28.
//  Copyright © 2020 Bryant Reyn. All rights reserved.
//

#import "PaintingliteExec.h"
#import "PaintingliteSessionFactory.h"
#import "PaintingliteObjRuntimeProperty.h"
#import "PaintingliteDataBaseOptions.h"
#import "PaintingliteSecurity.h"
#import "PaintingliteLog.h"
#import "PaintingliteException.h"
#import <objc/runtime.h>

@interface PaintingliteExec()
@property (nonatomic,strong)PaintingliteSessionFactory *factory; //工厂
@property (nonatomic,strong)PaintingliteLog *log; //日志
@end

@implementation PaintingliteExec

#pragma mark - 懒加载
- (PaintingliteSessionFactory *)factory{
    if (!_factory) {
        _factory = [PaintingliteSessionFactory sharePaintingliteSessionFactory];
    }
    
    return _factory;
}

- (PaintingliteLog *)log{
    if (!_log) {
        _log = [PaintingliteLog sharePaintingliteLog];
    }
    
    return _log;
}

#pragma mark - 执行SQL语句
- (Boolean)sqlite3Exec:(sqlite3 *)ppDb sql:(NSString *)sql{
    NSAssert(sql != NULL, @"SQL Not IS Empty");
    
    Boolean flag = false;
    
    @synchronized (self) {
        flag = sqlite3_exec(ppDb, [sql UTF8String], 0, 0, 0) == SQLITE_OK;
        if (flag) {
            //保存快照
            NSString *masterSQL = @"SELECT name FROM sqlite_master WHERE type='table' ORDER BY name";
            [self.factory execQuery:ppDb sql:masterSQL status:PaintingliteSessionFactoryTableJSON];
            //写入日志
            [self.log writeLogFileOptions:sql status:PaintingliteLogSuccess completeHandler:^(NSString * _Nonnull logFilePath) {
                ;
            }];
        }else{
            [self.log writeLogFileOptions:sql status:PaintingliteLogError completeHandler:^(NSString * _Nonnull logFilePath) {
                ;
            }];
        }
    }
    
    //打印SQL语句
    NSLog(@"%@",sql);
    
    return flag;
}

- (void)sqlite3Exec:(sqlite3 *)ppDb objName:(NSString *)objName{
    @synchronized (self) {
        //保存快照
        NSString *masterSQL = [NSString stringWithFormat:@"PRAGMA table_info(%@)",objName];
        [self.factory execQuery:ppDb sql:masterSQL status:PaintingliteSessionFactoryTableINFOJSON];
        //写入日志
        [self.log writeLogFileOptions:masterSQL status:PaintingliteLogSuccess completeHandler:^(NSString * _Nonnull logFilePath) {
            ;
        }];
    }
}

- (Boolean)sqlite3Exec:(sqlite3 *)ppDb tableName:(NSString *)tableName content:(NSString *)content{
    NSAssert(tableName != NULL, @"TableName Not IS Empty");
    
    //根据表名来创建表语句
    //判断JSON文件中是否与这个表
    Boolean flag = true;
    
    @synchronized (self) {
        if ([[self getCurrentTableNameWithJSON] containsObject:tableName]) {
            //包含了就不能创建了
            flag = false;
            
            [PaintingliteException PaintingliteException:@"表名重复" reason:@"数据库中已经含有此表,请重新设置表的名称"];
        }else{
            //创建数据库
            if (flag) {
                NSString *createSQL = [NSString stringWithFormat:@"CREATE TABLE IF NOT EXISTS %@(\n\t%@\n)",tableName,content];
                NSLog(@"%@",createSQL);
                [self sqlite3Exec:ppDb sql:createSQL];
            }
        }
    }
    
    return flag;
}

- (Boolean)sqlite3Exec:(sqlite3 *)ppDb tableName:(NSString *)tableName{
    NSAssert(tableName != NULL, @"TableName Not IS Empty");
    
    Boolean flag = true;
    
    @synchronized (self) {
        if ([[self getCurrentTableNameWithJSON] containsObject:tableName]) {
            //有表，则删除
            if (flag) {
                NSString *dropSQL = [NSString stringWithFormat:@"DROP TABLE %@",tableName];
                NSLog(@"%@",dropSQL);
                [self sqlite3Exec:ppDb sql:dropSQL];
            }
        }else{
            //不能删除
            flag = false;
            
            [PaintingliteException PaintingliteException:@"表名不存在" reason:@"数据库中未找到表名"];
        }
    }
    
    return flag;
}

- (Boolean)sqlite3Exec:(sqlite3 *)ppDb obj:(id)obj status:(PaintingliteExecStatus)status createStyle:(PaintingliteDataBaseOptionsCreateStyle)createStyle{
    Boolean flag = true;
    
    @synchronized (self) {
        //获得obj的名称作为表的名称
        NSString *objName = NSStringFromClass([obj class]);
        if (status == PaintingliteExecCreate) {
            [self getPaintingliteExecCreate:ppDb objName:objName obj:obj createSytle:createStyle];
        }else if(status == PaintingliteExecDrop){
            [self sqlite3Exec:ppDb tableName:[objName lowercaseString]];
        }else if (status == PaintingliteExecAlterRename){
            [self getPaintingliteExecAlterRename:ppDb obj:obj];
        }else if (status == PaintingliteExecAlterAddColumn){
            [self getPaintingliteExecAlterAddColumn:ppDb obj:obj];
        }else if (status == PaintingliteExecAlterObj){
            [self getPaintingliteExecAlterObj:ppDb objName:objName obj:obj];
        }
    }
    
    return flag;
}

#pragma mark - 基本操作
- (void)getPaintingliteExecCreate:(sqlite3 *)ppDb objName:(NSString *__nonnull)objName obj:(id)obj createSytle:(PaintingliteDataBaseOptionsCreateStyle)createStyle{
    //默认选择UUID作为主键
    //获得obj的成员变量作为表的字段
    NSMutableDictionary *propertyDict = [PaintingliteObjRuntimeProperty getObjPropertyName:obj];
    
    NSMutableString *content = [NSMutableString string];
    
    if (createStyle == PaintingliteDataBaseOptionsUUID) {
        content = [NSMutableString stringWithFormat:@"%@ NOT NULL PRIMARY KEY,",@"UUID"];
    }else if(createStyle == PaintingliteDataBaseOptionsID){
        content = [NSMutableString stringWithFormat:@"%@ NOT NULL PRIMARY KEY,",@"ID"];
    }
    
    for (NSString *ivarName in [propertyDict allKeys]) {
        NSString *ivarType = propertyDict[ivarName];
        [content appendFormat:@"%@ %@,",ivarName,ivarType];
    }
    
    content = (NSMutableString *)[content substringWithRange:NSMakeRange(0, content.length-1)];
    
    [self sqlite3Exec:ppDb tableName:[objName lowercaseString] content:content];
}

- (void)getPaintingliteExecAlterRename:(sqlite3 *)ppDb obj:(id)obj{
    //表存在才可以重命名表
    if ([[self getCurrentTableNameWithJSON] containsObject:(NSString *)obj[0]]) {
        NSString *alterSQL = [NSString stringWithFormat:@"ALTER TABLE %@ RENAME TO %@",obj[0],obj[1]];
        [self sqlite3Exec:ppDb sql:alterSQL];
    }else{
        [PaintingliteException PaintingliteException:@"表名不存在" reason:@"数据库中未找到表名"];
    }
}

- (void)getPaintingliteExecAlterAddColumn:(sqlite3 *)ppDb obj:(id)obj{
    if ([[self getCurrentTableNameWithJSON] containsObject:(NSString *)obj[0]]){
        NSString *alterSQL = [NSString stringWithFormat:@"ALTER TABLE %@ ADD COLUMN %@ %@",obj[0],obj[1],obj[2]];
        [self sqlite3Exec:ppDb sql:alterSQL];
    }else{
        [PaintingliteException PaintingliteException:@"表名不存在" reason:@"数据库中未找到表名"];
    }
}

- (void)getPaintingliteExecAlterObj:(sqlite3 *)ppDb objName:(NSString *)objName obj:(id)obj{
    if ([[self getCurrentTableNameWithJSON] containsObject:[objName lowercaseString]]) {
        NSArray *propertyNameArray = [[PaintingliteObjRuntimeProperty getObjPropertyName:obj] allKeys];
        //检查列表是否有更新
        //查看字段和当前表的字段进行对比操作，如果出现不一样则更新表
        [self sqlite3Exec:ppDb objName:objName];
        //读取JSON文件
        NSError *error = nil;
        
        NSArray *tableInfoArray = [NSJSONSerialization JSONObjectWithData:[PaintingliteSecurity SecurityDecodeBase64:[NSData dataWithContentsOfFile:[[NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) lastObject] stringByAppendingPathComponent:@"TablesInfo_Snap.json"]]] options:NSJSONReadingAllowFragments error:&error][@"TablesInfoSnap"];

        if ([propertyNameArray isEqualToArray:tableInfoArray]) {
            //完全相等，没必要更新操作
            return ;
        }else{
            //找出不一样的增加的那一个，进行更新操作
            //先删除原来那个表，然后重新根据这个表进行创建
            if ([self sqlite3Exec:ppDb obj:obj status:PaintingliteExecDrop createStyle:PaintingliteDataBaseOptionsDefault]) {
                [self sqlite3Exec:ppDb obj:obj status:PaintingliteExecCreate createStyle:PaintingliteDataBaseOptionsUUID];
            }
        }
    }else{
        [PaintingliteException PaintingliteException:@"表名不存在" reason:@"数据库中未找到表名"];
    }
    
}

#pragma mark - 读取JSON文件
- (NSArray *)getCurrentTableNameWithJSON{
    NSError *error = nil;
    
    return [NSJSONSerialization JSONObjectWithData:[PaintingliteSecurity SecurityDecodeBase64:[NSData dataWithContentsOfFile:[[NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) lastObject] stringByAppendingPathComponent:@"Tables_Snap.json"]]] options:NSJSONReadingAllowFragments error:&error][@"TablesSnap"];
}

@end
