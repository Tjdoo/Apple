//
//  TestWeak.m
//  test
//
//  Created by CYKJ on 2019/11/18.
//

#import "TestWeak.h"

@implementation TestWeak

+ (void)dowork
{
    NSObject * objc = [[NSObject alloc] init];
    id __weak objc2 = objc; // 底层调用 objc_initWeak()
    id __strong objc3 = objc;
    
}

@end  
