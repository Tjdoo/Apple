//
//  TestAlloc.m
//  test
//
//  Created by CYKJ on 2019/11/18.


#import "TestAlloc.h"
#import "Person.h"


@interface TestAlloc ()
{
    NSString * _name;
    int _age;
    
    /**   内存
     
         struct TestAlloc_IMPL {
             struct NSObject_IMPL NSObject_IVARS;
             NSString *_name;
             int _age;
         };
            */
}
@end


@implementation TestAlloc

+ (void)dowork
{    
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
    
//    NSLog(@"%@", NSStringFromClass(p->isa));
    
    if ([p isKindOfClass:[Person class]]) {
        
    }
    
    if ([p isMemberOfClass:[Person class]]) {
        
    }
}

@end
