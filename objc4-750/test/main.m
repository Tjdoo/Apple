//
//  main.m
//  test
//
//  Created by H on 2019/1/26.
//  libmalloc

#import <Foundation/Foundation.h>
#import "Person.h"

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
        
        /*
                         菜单栏 -》Debug -》Debug Workflow -》Always show Disassembly 开启汇编调试。
         
                            ①、在 Person * p1 = [Person alloc];  下断点；
                            ②、运行工程，进入汇编模式。分号 ‘;’ 代表注释；
                            ③、在第一个 symbol stub for: objc_msgSend 处下断点，继续运行，触发断点，LLDB 执行 register read 就可以查看当前寄存器中存放的数据；
                             ④、添加一个 Symbolic Breakpoint "alloc"，单步执行，将会进入 libobjc.A.dylib`::_objc_rootAlloc(Class):
                    */  
        
//        Person * p1 = [Person alloc];  // alloc 出来的对象是一个完整的对象
//        p1.age = 10;
//        NSLog(@"age = %d", p1.age);  // 10
//
//        Person * p2 = [p1 init];  // init 没有做任何事
//        NSLog(@"age = %d", p2.age);  // 10
        
        
        
        
        
//        int a = 1;  // 0x100000ebb <+27>: movl   $0x1, -0x14(%rbp)
//        int b = 2;  // 0x100000ec2 <+34>: movl   $0x2, -0x18(%rbp)
        
        // 0x100000e8b <+27>: movl   $0x1, %edi
        // 0x100000e90 <+32>: movl   $0x2, %esi
        // 0x100000e99 <+41>: callq  0x100000e50               ; sum at main.m:11
//        int a = sum(1, 2);
//        NSLog(@"%d", a);
        
        // 经过编译器优化后（设置 build setting -》optimization level -》fastest smallest）0x100000ea9 <+21>: movl   $0x3, %esi，没有了 sum 函数的调用，直接将 0x3 计算出来
        
        
        
        
        
        Person * p = [Person alloc];
        
        /*  下断点 -》LLDB：po p -》LLDB：memory read 0x102438f90（Person 对象的地址）
         
                         (lldb) memory read 0x102438f90
                         0x102438f90: c1 11 00 00 01 80 1d 00 00 00 00 00 00 00 00 00  ................
                         0x102438fa0: b1 61 97 8e ff ff 1d 00 8c 07 00 00 03 00 00 00  .a..............
                         (lldb) memory read 0x102438f90
                         0x102438f90: c1 11 00 00 01 80 1d 00 ff ff ff ff 00 00 00 00  ................
                         0x102438fa0: b1 61 97 8e ff ff 1d 00 8c 07 00 00 03 00 00 00  .a..............
         
                        其中 c1 11 00 00 01 80 1d 00 是 isa，isa 占 8 个字节。
                                ff ff ff ff 是存入 age 数据，int 占 4 个字节
                    */
        p.age = 0xffffffff;
//        NSLog(@"age：%d", p.age);  // 对象就是一种数据结构
        
        p.height = 1.86;
//        NSLog(@"height：%f", p.height);
        
        p.age1 = 0xcccccccc;
    }
    return 0;
}
