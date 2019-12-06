//
//  TestWeak.m
//  test
//
//  Created by CYKJ on 2019/11/18.
//

#import "TestWeak.h"

@implementation TestWeak

+ (void)test
{
    NSObject * objc = [[NSObject alloc] init];
    NSLog(@"%@  %p", objc, objc);
    
    id __weak objc2 = objc; // 底层调用 objc_initWeak()
    NSLog(@"%@  %p", objc2, objc2);
    
    id __strong objc3 = objc; // 底层调用 objc_storeStrong()
    NSLog(@"%@  %p", objc3, objc3);
}

@end  
