//
//  TestAssociate.m
//  test
//
//  Created by CYKJ on 2019/11/19.


#import "TestAssociate.h"
#import <objc/message.h>

@implementation TestAssociate

- (void)test
{
    NSArray * arr = [[NSArray alloc] initWithObjects:@"a", nil];
    NSLog(@"retainCount = %lu", [arr retainCount]);  // 1
    
    objc_setAssociatedObject(self, @selector(setName:), arr, OBJC_ASSOCIATION_RETAIN);
    NSLog(@"retainCount = %lu", [arr retainCount]);  // 2
    
    NSArray * getArr = objc_getAssociatedObject(self, @selector(setName:));
    NSLog(@"retainCount = %lu", [getArr retainCount]);  // 3
    NSLog(@"TestAssociate = %@", getArr);
}

@end
