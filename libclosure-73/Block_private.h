/*
 * Block_private.h
 *
 * SPI for Blocks
 *
 * Copyright (c) 2008-2010 Apple Inc. All rights reserved.
 *
 * @APPLE_LLVM_LICENSE_HEADER@
 *
 */

#ifndef _BLOCK_PRIVATE_H_
#define _BLOCK_PRIVATE_H_

#include <Availability.h>
#include <AvailabilityMacros.h>
#include <TargetConditionals.h>

#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>

#include <Block.h>

#if __has_include(<ptrauth.h>)
#include <ptrauth.h>
#endif

#if __has_feature(ptrauth_calls) &&  __cplusplus < 201103L

// C ptrauth or old C++ ptrauth

#define _Block_set_function_pointer(field, value)                       \
    ((value)                                                            \
     ? ((field) =                                                       \
        (__typeof__(field))                                             \
        ptrauth_auth_and_resign((void*)(value),                         \
                                ptrauth_key_function_pointer, 0,        \
                                ptrauth_key_block_function, &(field)))  \
     : ((field) = 0))

#define _Block_get_function_pointer(field)                              \
    ((field)                                                            \
     ? (__typeof__(field))                                              \
       ptrauth_auth_function((void*)(field),                            \
                             ptrauth_key_block_function, &(field))      \
     : (__typeof__(field))0)

#else

// C++11 ptrauth or no ptrauth

#define _Block_set_function_pointer(field, value)       \
    (field) = (value)

#define _Block_get_function_pointer(field)      \
    (field)

#endif


#if __has_feature(ptrauth_calls)  &&  __cplusplus >= 201103L

// StorageSignedFunctionPointer<Key, Fn> stores a function pointer of type
// Fn but signed with the given ptrauth key and with the address of its
// storage as extra data.
// Function pointers inside block objects are signed this way.
template <typename Fn, ptrauth_key Key>
class StorageSignedFunctionPointer {
    uintptr_t bits;

 public:

    // Authenticate function pointer fn as a C function pointer.
    // Re-sign it with our key and the storage address as extra data.
    // DOES NOT actually write to our storage.
    uintptr_t prepareWrite(Fn fn) const
    {
        if (fn == nullptr) {
            return 0;
        } else {
            return (uintptr_t)
                ptrauth_auth_and_resign(fn, ptrauth_key_function_pointer, 0,
                                        Key, &bits);
        }
    }

    // Authenticate otherBits at otherStorage.
    // Re-sign it with our storage address.
    // DOES NOT actually write to our storage.
    uintptr_t prepareWrite(const StorageSignedFunctionPointer& other) const
    {
        if (other.bits == 0) {
            return 0;
        } else {
            return (uintptr_t)
                ptrauth_auth_and_resign((void*)other.bits, Key, &other.bits,
                                        Key, &bits);
        }
    }

    // Authenticate ptr as if it were stored at our storage address.
    // Re-sign it as a C function pointer.
    // DOES NOT actually read from our storage.
    Fn completeReadFn(uintptr_t ptr) const
    {
        if (ptr == 0) {
            return nullptr;
        } else {
            return ptrauth_auth_function((Fn)ptr, Key, &bits);
        }
    }

    // Authenticate ptr as if it were at our storage address.
    // Return it as a dereferenceable pointer.
    // DOES NOT actually read from our storage.
    void* completeReadRaw(uintptr_t ptr) const
    {
        if (ptr == 0) {
            return nullptr;
        } else {
            return ptrauth_auth_data((void*)ptr, Key, &bits);
        }
    }

    StorageSignedFunctionPointer() { }

    StorageSignedFunctionPointer(Fn value)
        : bits(prepareWrite(value)) { }

    StorageSignedFunctionPointer(const StorageSignedFunctionPointer& value)
        : bits(prepareWrite(value)) { }

    StorageSignedFunctionPointer&
    operator = (Fn rhs) {
        bits = prepareWrite(rhs);
        return *this;
    }

    StorageSignedFunctionPointer&
    operator = (const StorageSignedFunctionPointer& rhs) {
        bits = prepareWrite(rhs);
        return *this;
    }

    operator Fn () const {
        return completeReadFn(bits);
    }

    explicit operator void* () const {
        return completeReadRaw(bits);
    }

    explicit operator bool () const {
        return completeReadRaw(bits) != nullptr;
    }
};

using BlockCopyFunction = StorageSignedFunctionPointer
    <void(*)(void *, const void *),
     ptrauth_key_block_function>;

using BlockDisposeFunction = StorageSignedFunctionPointer
    <void(*)(const void *),
     ptrauth_key_block_function>;

using BlockInvokeFunction = StorageSignedFunctionPointer
    <void(*)(void *, ...),
     ptrauth_key_block_function>;

using BlockByrefKeepFunction = StorageSignedFunctionPointer
    <void(*)(struct Block_byref *, struct Block_byref *),
     ptrauth_key_block_function>;

using BlockByrefDestroyFunction = StorageSignedFunctionPointer
    <void(*)(struct Block_byref *),
     ptrauth_key_block_function>;

// c++11 and ptrauth_calls
#elif !__has_feature(ptrauth_calls)
// not ptrauth_calls

typedef void(*BlockCopyFunction)(void *, const void *);
typedef void(*BlockDisposeFunction)(const void *);
typedef void(*BlockInvokeFunction)(void *, ...);
typedef void(*BlockByrefKeepFunction)(struct Block_byref*, struct Block_byref*);
typedef void(*BlockByrefDestroyFunction)(struct Block_byref *);

#else
// ptrauth_calls but not c++11

typedef uintptr_t BlockCopyFunction;
typedef uintptr_t BlockDisposeFunction;
typedef uintptr_t BlockInvokeFunction;
typedef uintptr_t BlockByrefKeepFunction;
typedef uintptr_t BlockByrefDestroyFunction;

#endif


// Values for Block_layout->flags to describe block objects
/**
  *  @brief  一般情况下，一个 block 的 flags 成员默认设置为 0。如果当 block 需要 Block_copy() 和 Block_release 这类拷贝辅助函数，则会设置成 1 << 25 ，也就是 BLOCK_HAS_COPY_DISPOSE 类型。可以搜索到大量讲述 Block_copy 方法的博文，其中涉及到了 BLOCK_HAS_COPY_DISPOSE 。
   */
enum {
    // 释放标记。一般常用 BLOCK_NEEDS_FREE 做按位与操作，一同传入 Flags ，告知该 block 可释放。
    BLOCK_DEALLOCATING =      (0x0001),  // runtime
    
    // 一般参与判断引用计数，是一个可选用参数
    BLOCK_REFCOUNT_MASK =     (0xfffe),  // runtime
    
    // 通过设置该枚举值来告知该 block 可释放。也在说明 block 是 heap block ，即我们常说的 _NSConcreteMallocBlock
    BLOCK_NEEDS_FREE =        (1 << 24), // runtime
    
    // 是否拥有拷贝辅助函数（a copy helper function）
    BLOCK_HAS_COPY_DISPOSE =  (1 << 25), // compiler
    
    // 是否拥有 block 析构函数（dispose function）
    BLOCK_HAS_CTOR =          (1 << 26), // compiler: helpers have C++ code
    
    // 是否启用 GC 机制（Garbage Collection）
    BLOCK_IS_GC =             (1 << 27), // runtime
    
    BLOCK_IS_GLOBAL =         (1 << 28), // compiler
    BLOCK_USE_STRET =         (1 << 29), // compiler: undefined if !BLOCK_HAS_SIGNATURE
    
    // 与 BLOCK_USE_STRET 相对，判断是否当前 block 拥有一个签名。用于 runtime 时动态调用
    BLOCK_HAS_SIGNATURE  =    (1 << 30), // compiler
    
    BLOCK_HAS_EXTENDED_LAYOUT=(1 << 31)  // compiler
};

#define BLOCK_DESCRIPTOR_1 1
struct Block_descriptor_1 {
    uintptr_t reserved;
    uintptr_t size;
};

#define BLOCK_DESCRIPTOR_2 1
struct Block_descriptor_2 {
    // requires BLOCK_HAS_COPY_DISPOSE
    BlockCopyFunction copy;
    BlockDisposeFunction dispose;
};

#define BLOCK_DESCRIPTOR_3 1
struct Block_descriptor_3 {
    // requires BLOCK_HAS_SIGNATURE
    const char *signature;
    const char *layout;     // contents depend on BLOCK_HAS_EXTENDED_LAYOUT
};

struct Block_layout {
    void *isa;
    volatile int32_t flags; // contains ref count
    int32_t reserved;
    BlockInvokeFunction invoke;
    struct Block_descriptor_1 *descriptor;
    // imported variables
};


// Values for Block_byref->flags to describe __block variables
enum {
    // Byref refcount must use the same bits as Block_layout's refcount.
    // BLOCK_DEALLOCATING =      (0x0001),  // runtime
    // BLOCK_REFCOUNT_MASK =     (0xfffe),  // runtime

    BLOCK_BYREF_LAYOUT_MASK =       (0xf << 28), // compiler
    BLOCK_BYREF_LAYOUT_EXTENDED =   (  1 << 28), // compiler
    BLOCK_BYREF_LAYOUT_NON_OBJECT = (  2 << 28), // compiler
    BLOCK_BYREF_LAYOUT_STRONG =     (  3 << 28), // compiler
    BLOCK_BYREF_LAYOUT_WEAK =       (  4 << 28), // compiler
    BLOCK_BYREF_LAYOUT_UNRETAINED = (  5 << 28), // compiler

    BLOCK_BYREF_IS_GC =             (  1 << 27), // runtime

    BLOCK_BYREF_HAS_COPY_DISPOSE =  (  1 << 25), // compiler
    BLOCK_BYREF_NEEDS_FREE =        (  1 << 24), // runtime
};

struct Block_byref {
    void *isa;
    struct Block_byref *forwarding;
    volatile int32_t flags; // contains ref count
    uint32_t size;
};

struct Block_byref_2 {
    // requires BLOCK_BYREF_HAS_COPY_DISPOSE
    BlockByrefKeepFunction byref_keep;
    BlockByrefDestroyFunction byref_destroy;
};

struct Block_byref_3 {
    // requires BLOCK_BYREF_LAYOUT_EXTENDED
    const char *layout;
};


// Extended layout encoding.

// Values for Block_descriptor_3->layout with BLOCK_HAS_EXTENDED_LAYOUT
// and for Block_byref_3->layout with BLOCK_BYREF_LAYOUT_EXTENDED

// If the layout field is less than 0x1000, then it is a compact encoding 
// of the form 0xXYZ: X strong pointers, then Y byref pointers, 
// then Z weak pointers.

// If the layout field is 0x1000 or greater, it points to a 
// string of layout bytes. Each byte is of the form 0xPN.
// Operator P is from the list below. Value N is a parameter for the operator.
// Byte 0x00 terminates the layout; remaining block data is non-pointer bytes.

enum {
    BLOCK_LAYOUT_ESCAPE = 0, // N=0 halt, rest is non-pointer. N!=0 reserved.
    BLOCK_LAYOUT_NON_OBJECT_BYTES = 1,    // N bytes non-objects
    BLOCK_LAYOUT_NON_OBJECT_WORDS = 2,    // N words non-objects
    BLOCK_LAYOUT_STRONG           = 3,    // N words strong pointers
    BLOCK_LAYOUT_BYREF            = 4,    // N words byref pointers
    BLOCK_LAYOUT_WEAK             = 5,    // N words weak pointers
    BLOCK_LAYOUT_UNRETAINED       = 6,    // N words unretained pointers
    BLOCK_LAYOUT_UNKNOWN_WORDS_7  = 7,    // N words, reserved
    BLOCK_LAYOUT_UNKNOWN_WORDS_8  = 8,    // N words, reserved
    BLOCK_LAYOUT_UNKNOWN_WORDS_9  = 9,    // N words, reserved
    BLOCK_LAYOUT_UNKNOWN_WORDS_A  = 0xA,  // N words, reserved
    BLOCK_LAYOUT_UNUSED_B         = 0xB,  // unspecified, reserved
    BLOCK_LAYOUT_UNUSED_C         = 0xC,  // unspecified, reserved
    BLOCK_LAYOUT_UNUSED_D         = 0xD,  // unspecified, reserved
    BLOCK_LAYOUT_UNUSED_E         = 0xE,  // unspecified, reserved
    BLOCK_LAYOUT_UNUSED_F         = 0xF,  // unspecified, reserved
};


// Runtime support functions used by compiler when generating copy/dispose helpers

// Values for _Block_object_assign() and _Block_object_dispose() parameters
enum {
    // see function implementation for a more complete description of these fields and combinations
    
    // OC对象类型
    BLOCK_FIELD_IS_OBJECT   =  3,  // id, NSObject, __attribute__((NSObject)), block, ...
    
    // 是一个 block
    BLOCK_FIELD_IS_BLOCK    =  7,  // a block variable
    
    // 在栈上被 __block 修饰的变量
    BLOCK_FIELD_IS_BYREF    =  8,  // the on stack structure holding the __block variable
    
    // 被 __weak 修饰的变量，只在 Block_byref 管理内部对象内存时使用
    BLOCK_FIELD_IS_WEAK     = 16,  // declared __weak, only used in byref copy helpers
    
    // 处理 Block_byref 内部对象内存的时候会加的一个额外标记（告诉内部实现不要进行 retain 或者 copy）
    BLOCK_BYREF_CALLER      = 128, // called from __block (byref) copy/dispose support routines.
};

enum {
    BLOCK_ALL_COPY_DISPOSE_FLAGS = 
        BLOCK_FIELD_IS_OBJECT | BLOCK_FIELD_IS_BLOCK | BLOCK_FIELD_IS_BYREF |
        BLOCK_FIELD_IS_WEAK | BLOCK_BYREF_CALLER
};


// Function pointer accessors

static inline __typeof__(void (*)(void *, ...))
_Block_get_invoke_fn(struct Block_layout *block)
{
    return (void (*)(void *, ...))_Block_get_function_pointer(block->invoke);
}

static inline void 
_Block_set_invoke_fn(struct Block_layout *block, void (*fn)(void *, ...))
{
    _Block_set_function_pointer(block->invoke, fn);
}


static inline __typeof__(void (*)(void *, const void *))
_Block_get_copy_fn(struct Block_descriptor_2 *desc)
{
    return (void (*)(void *, const void *))_Block_get_function_pointer(desc->copy);
}

static inline void 
_Block_set_copy_fn(struct Block_descriptor_2 *desc,
                   void (*fn)(void *, const void *))
{
    _Block_set_function_pointer(desc->copy, fn);
}


static inline __typeof__(void (*)(const void *))
_Block_get_dispose_fn(struct Block_descriptor_2 *desc)
{
    return (void (*)(const void *))_Block_get_function_pointer(desc->dispose);
}

static inline void 
_Block_set_dispose_fn(struct Block_descriptor_2 *desc,
                      void (*fn)(const void *))
{
    _Block_set_function_pointer(desc->dispose, fn);
}


// Other support functions


// runtime entry to get total size of a closure
BLOCK_EXPORT size_t Block_size(void *aBlock);

// indicates whether block was compiled with compiler that sets the ABI related metadata bits
BLOCK_EXPORT bool _Block_has_signature(void *aBlock)
    __OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_4_3);

// returns TRUE if return value of block is on the stack, FALSE otherwise
BLOCK_EXPORT bool _Block_use_stret(void *aBlock)
    __OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_4_3);

// Returns a string describing the block's parameter and return types.
// The encoding scheme is the same as Objective-C @encode.
// Returns NULL for blocks compiled with some compilers.
BLOCK_EXPORT const char * _Block_signature(void *aBlock)
    __OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_4_3);

// Returns a string describing the block's GC layout.
// This uses the GC skip/scan encoding.
// May return NULL.
BLOCK_EXPORT const char * _Block_layout(void *aBlock)
    __OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_4_3);

// Returns a string describing the block's layout.
// This uses the "extended layout" form described above.
// May return NULL.
BLOCK_EXPORT const char * _Block_extended_layout(void *aBlock)
    __OSX_AVAILABLE_STARTING(__MAC_10_8, __IPHONE_7_0);

// Callable only from the ARR weak subsystem while in exclusion zone
BLOCK_EXPORT bool _Block_tryRetain(const void *aBlock)
    __OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_4_3);

// Callable only from the ARR weak subsystem while in exclusion zone
BLOCK_EXPORT bool _Block_isDeallocating(const void *aBlock)
    __OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_4_3);


// the raw data space for runtime classes for blocks
// class+meta used for stack, malloc, and collectable based blocks
BLOCK_EXPORT void * _NSConcreteMallocBlock[32]
    __OSX_AVAILABLE_STARTING(__MAC_10_6, __IPHONE_3_2);
BLOCK_EXPORT void * _NSConcreteAutoBlock[32]
    __OSX_AVAILABLE_STARTING(__MAC_10_6, __IPHONE_3_2);
BLOCK_EXPORT void * _NSConcreteFinalizingBlock[32]
    __OSX_AVAILABLE_STARTING(__MAC_10_6, __IPHONE_3_2);
BLOCK_EXPORT void * _NSConcreteWeakBlockVariable[32]
    __OSX_AVAILABLE_STARTING(__MAC_10_6, __IPHONE_3_2);
// declared in Block.h
// BLOCK_EXPORT void * _NSConcreteGlobalBlock[32];
// BLOCK_EXPORT void * _NSConcreteStackBlock[32];


struct Block_callbacks_RR {
    size_t  size;                   // size == sizeof(struct Block_callbacks_RR)
    void  (*retain)(const void *);
    void  (*release)(const void *);
    void  (*destructInstance)(const void *);
};
typedef struct Block_callbacks_RR Block_callbacks_RR;

BLOCK_EXPORT void _Block_use_RR2(const Block_callbacks_RR *callbacks);


#endif
