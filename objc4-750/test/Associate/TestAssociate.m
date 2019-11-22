//
//  TestAssociate.m
//  test
//
//  Created by CYKJ on 2019/11/19.


#import "TestAssociate.h"
#import <objc/message.h>

@implementation TestAssociate

+ (void)dowork
{
    objc_setAssociatedObject(self, @selector(setName:), @"Tom", OBJC_ASSOCIATION_COPY);
    
    NSString * name = objc_getAssociatedObject(self, @selector(setName:));
    NSLog(@"TestAssociate name = %@", name);
}

@end
