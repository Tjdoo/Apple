//
//  main.c
//  Test
//
//  Created by CYKJ on 2019/11/25.
//  Copyright (c) 2019年 ___ORGANIZATIONNAME___. All rights reserved.


#include <stdio.h>

int main (int argc, const char * argv[])
{
    // insert code here...
    
    void(^ block)(void) = ^ {
        printf("Hello, World!\n");
    };
    block();
    
	return 0;
}

