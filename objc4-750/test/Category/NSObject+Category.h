//
//  NSObject+Category.h
//  test
//
//  Created by CYKJ on 2019/12/4.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@protocol MyCategoryPTC <NSObject>
@required

- (void)requiredFunc;

@optional

- (void)optionalFunc;

@end



@interface NSObject (Category) <MyCategoryPTC>

@property (nonatomic, assign) NSInteger age;
@property (nonatomic, copy) NSString * name;
@property (nonatomic, strong) NSArray * arr;

@end

NS_ASSUME_NONNULL_END
