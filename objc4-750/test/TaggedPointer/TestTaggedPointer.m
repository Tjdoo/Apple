//
//  TaggedPointer.m
//  test
//
//  Created by CYKJ on 2019/12/3.


#import "TestTaggedPointer.h"
#import <objc/runtime.h>

extern uintptr_t objc_debug_taggedpointer_obfuscator;


@implementation TestTaggedPointer

/**
  *  @brief   与系统的解码方法只是名称不同，内容一致
  *  @see   objc-internal.h   _objc_decodeTaggedPointeraa() 方法
  */
uintptr_t _objc_decodeTaggedPointer_(const void * _Nullable  ptr) {
    return (uintptr_t)ptr ^ objc_debug_taggedpointer_obfuscator;
}


+ (void)test
{
    NSString * string = [NSString stringWithFormat:@"abc"];
    NSLog(@"%@", string);
    
    int     num1 = 15;
    float   num2 = 11;
    double  num3 = 10;
    long    num4 = 8;
    
    NSNumber * number1 = @(num1);
    NSNumber * number2 = @(num2);
    NSNumber * number3 = @(num3);
    NSNumber * number4 = @(num4);
    
    NSLog(@"number1 = %@ - %p - 0x%lx", object_getClass(number1), &number1, _objc_decodeTaggedPointer_((__bridge const void * _Nullable)(number1)));
    NSLog(@"number2 = %@ - %p - 0x%lx", object_getClass(number2), &number2, _objc_decodeTaggedPointer_((__bridge const void * _Nullable)(number2)));
    NSLog(@"number3 = %@ - %p - 0x%lx", object_getClass(number3), &number3, _objc_decodeTaggedPointer_((__bridge const void * _Nullable)(number3)));
    NSLog(@"number4 = %@ - %p - 0x%lx", object_getClass(number4), &number4, _objc_decodeTaggedPointer_((__bridge const void * _Nullable)(number4)));

    // number1 = __NSCFNumber - 0x7ffeefbff598 - 0xf27
    // number2 = __NSCFNumber - 0x7ffeefbff590 - 0xb47
    // number3 = __NSCFNumber - 0x7ffeefbff588 - 0xa57
    // number4 = __NSCFNumber - 0x7ffeefbff580 - 0x837
    
    NSNumber * number5 = [[NSNumber alloc] initWithInt:9];
    NSLog(@"number5 = %@ - %p - %p - 0x%lx", object_getClass(number5), &number5, number5, _objc_decodeTaggedPointer_((__bridge const void * _Nullable)(number5)));
    // number5 = __NSCFNumber - 0x7ffeefbff578 - 0x927
    
    //0xf27、0xb47、0xa57 这些是真实的地址
}

@end
