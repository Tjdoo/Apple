//
//  main.m
//  test
//
//  Created by H on 2019/1/26.
//  libmalloc


#import <Foundation/Foundation.h>
#import "TestAlloc.h"
#import "TestWeak.h"
#import "TestAssociate.h"
#import "TestAutoreleasePool.h"
#import "TestTaggedPointer.h"


int sum(int a, int b) {
    return a + b;
}

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        
        /*  扩展知识
         
                     ①、OC 代码调用函数的实质是在发送消息，核心方法时 objc_msgSend
                     ②、汇编函数中 b 指令表示跳转不回来，bl 指令表示跳转后还要返回，然后继续向下执行，ret 指令相当于 return。不同的指令集不同，例如：call、callq 与 b、bl 作用相同；
                     ③、尾调函数，编译器优化。
                 */
        
        //        int a = 1;  // 0x100000ebb <+27>: movl   $0x1, -0x14(%rbp)
        //        int b = 2;  // 0x100000ec2 <+34>: movl   $0x2, -0x18(%rbp)
        
        // 0x100000e8b <+27>: movl   $0x1, %edi
        // 0x100000e90 <+32>: movl   $0x2, %esi
        // 0x100000e99 <+41>: callq  0x100000e50               ; sum at main.m:11
        //        int a = sum(1, 2);
        //        NSLog(@"%d", a);
        
        // 经过编译器优化后（设置 build setting -》optimization level -》fastest smallest）0x100000ea9 <+21>: movl   $0x3, %esi，没有了 sum 函数的调用，直接将 0x3 计算出来
        
        
        
        
        
        
//        [TestAlloc test];
//        [TestWeak test];
//        [[TestAssociate alloc] test];
//        [TestAutoreleasepool test];
//        [TestTaggedPointer test];
    }
    return 0;
}
