//
//  ViewController.m
//  Paintinglite
//
//  Created by Bryant Reyn on 2020/5/26.
//  Copyright © 2020 Bryant Reyn. All rights reserved.
//

#import "ViewController.h"
#import "Paintinglite/PaintingliteSessionManager.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
//    NSString *filePath = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES)firstObject];
//    NSString *fileName = [filePath stringByAppendingPathComponent:@"sqlite.db"];
    
    PaintingliteSessionManager *sessionManager = [PaintingliteSessionManager sharePaintingliteSessionManager];
//    Boolean flag = [sessionManager openSqlite:@"sqlite.db"];
    
//    NSLog(@"%hhu",flag);
    
    [sessionManager openSqlite:@"sqlite.db" completeHandler:^(NSString * _Nonnull filePath, PaintingliteSessionError * _Nonnull error, Boolean success) {
        if (success) {
            NSLog(@"%@",filePath);
            NSLog(@"连接数据库成功...");
        }else{
            NSLog(@"%@",[error localizedDescription]);
        }
    }];
    
   
//    NSLog(@"%hhu",[sessionManager releaseSqlite]);
//
//    [sessionManager releaseSqliteCompleteHandler:^(PaintingliteSessionError * _Nonnull error, Boolean success) {
//        if (success) {
//            NSLog(@"关闭数据库成功...");
//        }
//    }];
//
//    NSLog(@"%hhu",[sessionManager releaseSqlite]);
}


@end
