//
//  OCFunc.m
//  testProj
//
//  Created by CYKJ on 2019/11/12.


#import "OCFunc.h"

@implementation OCFunc

+ (void)test
{
	dispatch_async(dispatch_get_main_queue(), ^{
		
	});
	
	dispatch_sync(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
		
	});
	
	dispatch_queue_t queue = dispatch_queue_create("queue", 0);
	dispatch_async(queue, ^{
		NSLog(@"Dispatch Async");
		dispatch_sync(queue, ^{
			NSLog(@"Serial Queue sync");
		});
		NSLog(@"End");
	});
	
	// 串行队列死锁 crash 的例子（在同个线程的串行队列任务执行过程中，再次发送 dispatch_sync 任务到串行队列，会 crash）
	//==============================
	dispatch_queue_t sQ = dispatch_queue_create("st0", 0);
	dispatch_async(sQ, ^{
		NSLog(@"Enter");
		dispatch_sync(sQ, ^{   //  这里会crash
			NSLog(@"sync task");
		});
	});
	
	// 串行死锁的例子（这里不会 crash，在线程 A 执行串行任务 task1 的过程中，又在线程 B 中投递了一个 task2 到串行队列同时使用 dispatch_sync 等待，死锁，但 GCD 不会测出）
	//==============================
	dispatch_queue_t sQ1 = dispatch_queue_create("st01", 0);
	dispatch_async(sQ1, ^{
		NSLog(@"Enter");
		dispatch_sync(dispatch_get_main_queue(), ^{
			dispatch_sync(sQ1, ^{
				NSArray * a = [NSArray new];
				NSLog(@"Enter again %@", a);
			});
		});
		NSLog(@"Done");
	});
	
	// 串行队列等待的例子 1
	//==============================
	dispatch_queue_t sQ2 = dispatch_queue_create("st02", 0);
	dispatch_async(sQ2, ^{
		NSLog(@"Enter");
		sleep(5);
		NSLog(@"Done");
	});
	
	dispatch_sync(sQ2, ^{
		NSLog(@"It is my turn");
	});
	
	
	// dispatch_once 的死锁问题。
	// dispatch_once 将后进入的线程阻塞。这本是为了防止多线程并发的问题，但是也留下了一个死锁的隐患。如果在 dispatch_once 仍在执行时，同一线程再次调用 dispatch_once 方法，则会死锁。其实这本是一个递归循环调用的问题，但是由于线程阻塞的存在，就不会递归，而成了死锁
	[self once];
	
	
	dispatch_group_t group = dispatch_group_create();
	dispatch_queue_t myQueue = dispatch_queue_create("com.example.MyQueue", DISPATCH_QUEUE_CONCURRENT);
	dispatch_queue_t finishQueue = dispatch_queue_create("com.example.finishQueue", NULL);
	
	dispatch_group_async(group, myQueue, ^{NSLog(@"Task 1");});
	dispatch_group_async(group, myQueue, ^{NSLog(@"Task 2");});
	dispatch_group_async(group, myQueue, ^{NSLog(@"Task 3");});
	
	dispatch_group_notify(group, finishQueue, ^{
		NSLog(@"All Done!");
	});
	
	
	/*  Dispatch Source 是 BSD 系统内核惯有功能 kqueue 的包装，kqueue 是在 XNU 内核中发生各种事件时，在应用程序编程方执行处理的技术。它的 CPU 负荷非常小，尽量不占用资源。当事件发生时，Dispatch Source 会在指定的 Dispatch Queue 中执行事件的处理。
	 */
	dispatch_source_t source = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_main_queue());
	dispatch_source_set_timer(source, dispatch_time(DISPATCH_TIME_NOW, 0), 3 * NSEC_PER_SEC, 0);
	dispatch_source_set_event_handler(source, ^{
		//定时器触发时执行
		NSLog(@"timer响应了");
	});
	//启动timer
	dispatch_resume(source);
}

+ (void)once
{
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		[self otherOnce];
	});
	NSLog(@"once function");
}

+ (void)otherOnce
{
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		[self once];
	});
	NSLog(@"other once function");
}

@end
