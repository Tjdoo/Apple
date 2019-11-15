//
//  main.m
//  testProj
//
//  Created by CYKJ on 2019/11/12.


#import <Foundation/Foundation.h>
#import "OCFunc.h"


int main(int argc, const char * argv[]) {
    @autoreleasepool {
		NSLog(@"%d", argc);
		NSLog(@"%s", *argv);
		
		[OCFunc test];
 	}
    return 0;
}

