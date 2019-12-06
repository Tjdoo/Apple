//
//  TestAutoreleasepool.m
//  test
//
//  Created by CYKJ on 2019/11/26.


#import "TestAutoreleasepool.h"

@implementation TestAutoreleasepool

/// clang -rewrite-objc TestAutoreleasepool.m  https://www.jianshu.com/p/b26b6c001f7a
+ (void)test
{
    /*
            static void _I_TestAutoreleasepool_dowork(TestAutoreleasepool * self, SEL _cmd) {
                            { __AtAutoreleasePool __autoreleasepool; }
          */
    // 可以看出 @autoreleasepool{} 会创建一个 __AtAutoreleasePool 类型的局部变量并包含在当前作用域
    @autoreleasepool {
        NSString * s = [NSString stringWithFormat:@"a"];
    }
}

@end
