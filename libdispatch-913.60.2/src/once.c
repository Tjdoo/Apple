/*
 * Copyright (c) 2008-2013 Apple Inc. All rights reserved.
 *
 * @APPLE_APACHE_LICENSE_HEADER_START@
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *
 * @APPLE_APACHE_LICENSE_HEADER_END@
 */

#include "internal.h"

#undef dispatch_once
#undef dispatch_once_f


typedef struct _dispatch_once_waiter_s {
	volatile struct _dispatch_once_waiter_s *volatile dow_next;
	dispatch_thread_event_s dow_event;
	mach_port_t dow_thread;
} *_dispatch_once_waiter_t;

#define DISPATCH_ONCE_DONE ((_dispatch_once_waiter_t)~0l)

#ifdef __BLOCKS__
void
dispatch_once(dispatch_once_t *val, dispatch_block_t block)
{
	dispatch_once_f(val, block, _dispatch_Block_invoke(block));
}
#endif

#if DISPATCH_ONCE_INLINE_FASTPATH
#define DISPATCH_ONCE_SLOW_INLINE inline DISPATCH_ALWAYS_INLINE
#else
#define DISPATCH_ONCE_SLOW_INLINE DISPATCH_NOINLINE
#endif // DISPATCH_ONCE_INLINE_FASTPATH

DISPATCH_ONCE_SLOW_INLINE
static void
dispatch_once_f_slow(dispatch_once_t *val, void *ctxt, dispatch_function_t func)
{
#if DISPATCH_GATE_USE_FOR_DISPATCH_ONCE
	dispatch_once_gate_t l = (dispatch_once_gate_t)val;

	if (_dispatch_once_gate_tryenter(l)) {
		_dispatch_client_callout(ctxt, func);
		_dispatch_once_gate_broadcast(l);
	} else {
		_dispatch_once_gate_wait(l);
	}
#else
	// 明明是一个 long 指针，硬被转换为了 _dispatch_once_waiter_t *，无所谓，都是地址而已
	_dispatch_once_waiter_t volatile *vval = (_dispatch_once_waiter_t*)val;
	struct _dispatch_once_waiter_s dow = { };
	_dispatch_once_waiter_t tail = &dow, next, tmp;
	dispatch_thread_event_t event;

	/* 判断 *vval 是否等于NULL
	
	 1、是，返回 true，并将 *vval 置为 tail
	 2、否，返回 false（第一次进入，*vval == NULL, 之后又其他线程进入，则进入 else 分支） 如果之后在没有其他线程进入，则 val 的值一直会保持 tail
	*/
	if (os_atomic_cmpxchg(vval, NULL, tail, acquire)) {
		// 当前线程的 thread port
		dow.dow_thread = _dispatch_tid_self();
		// 执行 client 代码，也就是我们单例初始化方法。注意，如果在 client 代码中嵌套调用同一个 once token 的 dispatch once 方法时，再次会进入 else 分支，导致当前的 thread 被 _dispatch_thread_event_wait 阻塞，而无法执行下面的 _dispatch_thread_event_signal，导致死锁
		_dispatch_client_callout(ctxt, func);

		// 调用原子操作 atomic_exchange_explicit(val, DLOCK_ONCE_DONE, memory_order_release);  将 val 置为 DLOCK_ONCE_DONE，同时返回 val 的之前值赋值给 next
		next = (_dispatch_once_waiter_t)_dispatch_once_xchg_done(val);
		// 如果 next 不为 tail， 说明 val 的值被别的线程修改了。也就是说同一时间，有其他线程试图执行单例方法，这会导致其他线程做信号量等待，所以下面要 signal 其他线程
		while (next != tail) {
			tmp = (_dispatch_once_waiter_t)_dispatch_wait_until(next->dow_next);
			event = &next->dow_event;
			next = tmp;
			_dispatch_thread_event_signal(event);
		}
	}
	// 其他后进入的线程会走这里（会被阻塞住，直到第一个线程执行完毕，才会被唤醒）
	else {
		_dispatch_thread_event_init(&dow.dow_event);
		// 保留之前的值
		next = *vval;
		for (;;) {
			if (next == DISPATCH_ONCE_DONE) {
				break;
			}
			/* 判断 *vval 是否等于 next
			 
			 1、相等，返回 true，同时设置 *vval = tail。
			 2、不相等，返回 false，同时设置 *vval = next. 所有线程第一次进入这里，应该是相等的
			 */
			if (os_atomic_cmpxchgv(vval, next, tail, &next, release)) {
				// 这里的 dow = *tail = *vval，因此下面两行代码可以理解为：
				// (*vval)->dow_thread = next->dow_thread
				// (*vval)->dow_next = next;
				dow.dow_thread = next->dow_thread;
				dow.dow_next = next;
				if (dow.dow_thread) {
					pthread_priority_t pp = _dispatch_get_priority();
					_dispatch_thread_override_start(dow.dow_thread, pp, val);
				}
				// 线程在这里休眠，直到单例方法执行完毕后，被唤醒
				_dispatch_thread_event_wait(&dow.dow_event);
				if (dow.dow_thread) {
					_dispatch_thread_override_end(dow.dow_thread, val);
				}
				break;
			}
		}
		_dispatch_thread_event_destroy(&dow.dow_event);
	}
#endif
}

DISPATCH_NOINLINE
void
dispatch_once_f(dispatch_once_t *val, void *ctxt, dispatch_function_t func)
{
#if !DISPATCH_ONCE_INLINE_FASTPATH
	// 这里来判断是否已经执行了一次（用原子操作load val的值，如果执行过了 val == ~0）
	if (likely(os_atomic_load(val, acquire) == DLOCK_ONCE_DONE)) {
		return;
	}
#endif // !DISPATCH_ONCE_INLINE_FASTPATH
	return dispatch_once_f_slow(val, ctxt, func);
}
