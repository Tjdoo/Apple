//
//  Person.h
//  test
//
//  Created by H on 2019/1/27.
//  8字节对齐!!   真实的空间! 16字节对齐!!

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface Person : NSObject

@property (nonatomic, assign) int age;
@property (nonatomic, assign) double height;
@property (nonatomic, assign) int age1;

@end

NS_ASSUME_NONNULL_END
