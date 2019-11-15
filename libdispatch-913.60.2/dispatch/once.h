/*
 * Copyright (c) 2008-2010 Apple Inc. All rights reserved.
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

#ifndef __DISPATCH_ONCE__
#define __DISPATCH_ONCE__

#ifndef __DISPATCH_INDIRECT__
#error "Please #include <dispatch/dispatch.h> instead of this file directly."
#include <dispatch/base.h> // for HeaderDoc
#endif

DISPATCH_ASSUME_NONNULL_BEGIN

__BEGIN_DECLS

/*!
 * @typedef dispatch_once_t
 *
 * @abstract
 * A predicate for use with dispatch_once(). It must be initialized to zero.
 * Note: static and global variables default to zero.
 */
DISPATCH_SWIFT3_UNAVAILABLE("Use lazily initialized globals instead")
typedef long dispatch_once_t;

#if defined(__x86_64__) || defined(__i386__) || defined(__s390x__)
#define DISPATCH_ONCE_INLINE_FASTPATH 1
#elif defined(__APPLE__)
#define DISPATCH_ONCE_INLINE_FASTPATH 1
#else
#define DISPATCH_ONCE_INLINE_FASTPATH 0
#endif

/*!
 * @function dispatch_once
 *
 * @abstract
 * Execute a block once and only once.
 *
 * @param predicate
 * A pointer to a dispatch_once_t that is used to test whether the block has
 * completed or not.
 *
 * @param block
 * The block to execute once.
 *
 * @discussion
 * Always call dispatch_once() before using or testing any variables that are
 * initialized by the block.
 */
#ifdef __BLOCKS__
API_AVAILABLE(macos(10.6), ios(4.0))
DISPATCH_EXPORT DISPATCH_NONNULL_ALL DISPATCH_NOTHROW
DISPATCH_SWIFT3_UNAVAILABLE("Use lazily initialized globals instead")
void
dispatch_once(dispatch_once_t *predicate,
		DISPATCH_NOESCAPE dispatch_block_t block);

#if DISPATCH_ONCE_INLINE_FASTPATH
DISPATCH_INLINE DISPATCH_ALWAYS_INLINE DISPATCH_NONNULL_ALL DISPATCH_NOTHROW
DISPATCH_SWIFT3_UNAVAILABLE("Use lazily initialized globals instead")
/**
 *  @brief   当单例方法执行完毕，GCD 会将 onceToken 置为 ~0。如果再次调用单例方法，GCD 会发现 onceToken 已经使用过，就直接返回了。但是仍有一种可能，就是在 onceToken 被设置为 ~0 之前，其他线程再次进入了 _dispatch_once 方法，这就会导致 dispatch_once 被多次调用。
  */
void
_dispatch_once(dispatch_once_t *predicate,
		DISPATCH_NOESCAPE dispatch_block_t block)
{
	// 如果是第一次进入，走这里。或者在设置 *predicate = ~0l 之前，其他线程再调用 _dispatch_once，还会走这里
	if (DISPATCH_EXPECT(*predicate, ~0l) != ~0l) {
		// 这里执行完毕之前，如果 _dispatch_once 再次由其他线程调用，仍会进入这里
		dispatch_once(predicate, block);
	}
	else {
		dispatch_compiler_barrier();
	}
	// 设置 *predicate == ~0l，防止在进入
	DISPATCH_COMPILER_CAN_ASSUME(*predicate == ~0l);
}
#undef dispatch_once
#define dispatch_once _dispatch_once
#endif
#endif // DISPATCH_ONCE_INLINE_FASTPATH

API_AVAILABLE(macos(10.6), ios(4.0))
DISPATCH_EXPORT DISPATCH_NONNULL1 DISPATCH_NONNULL3 DISPATCH_NOTHROW
DISPATCH_SWIFT3_UNAVAILABLE("Use lazily initialized globals instead")
void
dispatch_once_f(dispatch_once_t *predicate, void *_Nullable context,
		dispatch_function_t function);

#if DISPATCH_ONCE_INLINE_FASTPATH
DISPATCH_INLINE DISPATCH_ALWAYS_INLINE DISPATCH_NONNULL1 DISPATCH_NONNULL3
DISPATCH_NOTHROW
DISPATCH_SWIFT3_UNAVAILABLE("Use lazily initialized globals instead")
void
_dispatch_once_f(dispatch_once_t *predicate, void *_Nullable context,
		dispatch_function_t function)
{
	if (DISPATCH_EXPECT(*predicate, ~0l) != ~0l) {
		dispatch_once_f(predicate, context, function);
	} else {
		dispatch_compiler_barrier();
	}
	DISPATCH_COMPILER_CAN_ASSUME(*predicate == ~0l);
}
#undef dispatch_once_f
#define dispatch_once_f _dispatch_once_f
#endif // DISPATCH_ONCE_INLINE_FASTPATH

__END_DECLS

DISPATCH_ASSUME_NONNULL_END

#endif
