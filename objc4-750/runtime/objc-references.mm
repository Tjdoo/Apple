/*
 * Copyright (c) 2004-2007 Apple Inc. All rights reserved.
 *
 * @APPLE_LICENSE_HEADER_START@
 * 
 * This file contains Original Code and/or Modifications of Original Code
 * as defined in and that are subject to the Apple Public Source License
 * Version 2.0 (the 'License'). You may not use this file except in
 * compliance with the License. Please obtain a copy of the License at
 * http://www.opensource.apple.com/apsl/ and read it before using this
 * file.
 * 
 * The Original Code and all software distributed under the License are
 * distributed on an 'AS IS' basis, WITHOUT WARRANTY OF ANY KIND, EITHER
 * EXPRESS OR IMPLIED, AND APPLE HEREBY DISCLAIMS ALL SUCH WARRANTIES,
 * INCLUDING WITHOUT LIMITATION, ANY WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE, QUIET ENJOYMENT OR NON-INFRINGEMENT.
 * Please see the License for the specific language governing rights and
 * limitations under the License.
 * 
 * @APPLE_LICENSE_HEADER_END@
 */
/*
  Implementation of the weak / associative references for non-GC mode.
*/


#include "objc-private.h"
#include <objc/message.h>
#include <map>

#if _LIBCPP_VERSION
#   include <unordered_map>
#else
#   include <tr1/unordered_map>
    using namespace tr1;
#endif


// wrap all the murky C++ details in a namespace to get them out of the way.

namespace objc_references_support {
    struct DisguisedPointerEqual {
        bool operator()(uintptr_t p1, uintptr_t p2) const {
            return p1 == p2;
        }
    };
    
    struct DisguisedPointerHash {
        uintptr_t operator()(uintptr_t k) const {
            // borrowed from CFSet.c
#if __LP64__
            uintptr_t a = 0x4368726973746F70ULL;
            uintptr_t b = 0x686572204B616E65ULL;
#else
            uintptr_t a = 0x4B616E65UL;
            uintptr_t b = 0x4B616E65UL; 
#endif
            uintptr_t c = 1;
            a += k;
#if __LP64__
            a -= b; a -= c; a ^= (c >> 43);
            b -= c; b -= a; b ^= (a << 9);
            c -= a; c -= b; c ^= (b >> 8);
            a -= b; a -= c; a ^= (c >> 38);
            b -= c; b -= a; b ^= (a << 23);
            c -= a; c -= b; c ^= (b >> 5);
            a -= b; a -= c; a ^= (c >> 35);
            b -= c; b -= a; b ^= (a << 49);
            c -= a; c -= b; c ^= (b >> 11);
            a -= b; a -= c; a ^= (c >> 12);
            b -= c; b -= a; b ^= (a << 18);
            c -= a; c -= b; c ^= (b >> 22);
#else
            a -= b; a -= c; a ^= (c >> 13);
            b -= c; b -= a; b ^= (a << 8);
            c -= a; c -= b; c ^= (b >> 13);
            a -= b; a -= c; a ^= (c >> 12);
            b -= c; b -= a; b ^= (a << 16);
            c -= a; c -= b; c ^= (b >> 5);
            a -= b; a -= c; a ^= (c >> 3);
            b -= c; b -= a; b ^= (a << 10);
            c -= a; c -= b; c ^= (b >> 15);
#endif
            return c;
        }
    };
    
    struct ObjectPointerLess {
        bool operator()(const void *p1, const void *p2) const {
            return p1 < p2;
        }
    };
    
    struct ObjcPointerHash {
        uintptr_t operator()(void *p) const {
            return DisguisedPointerHash()(uintptr_t(p));
        }
    };

    // STL allocator that uses the runtime's internal allocator.
    
    template <typename T> struct ObjcAllocator {
        typedef T                 value_type;
        typedef value_type*       pointer;
        typedef const value_type *const_pointer;
        typedef value_type&       reference;
        typedef const value_type& const_reference;
        typedef size_t            size_type;
        typedef ptrdiff_t         difference_type;

        template <typename U> struct rebind { typedef ObjcAllocator<U> other; };

        template <typename U> ObjcAllocator(const ObjcAllocator<U>&) {}
        ObjcAllocator() {}
        ObjcAllocator(const ObjcAllocator&) {}
        ~ObjcAllocator() {}

        pointer address(reference x) const { return &x; }
        const_pointer address(const_reference x) const { 
            return x;
        }

        pointer allocate(size_type n, const_pointer = 0) {
            return static_cast<pointer>(::malloc(n * sizeof(T)));
        }

        void deallocate(pointer p, size_type) { ::free(p); }

        size_type max_size() const { 
            return static_cast<size_type>(-1) / sizeof(T);
        }

        void construct(pointer p, const value_type& x) { 
            new(p) value_type(x); 
        }

        void destroy(pointer p) { p->~value_type(); }

        void operator=(const ObjcAllocator&);

    };

    template<> struct ObjcAllocator<void> {
        typedef void        value_type;
        typedef void*       pointer;
        typedef const void *const_pointer;
        template <typename U> struct rebind { typedef ObjcAllocator<U> other; };
    };
  
    typedef uintptr_t disguised_ptr_t;
    // DISGUISE 函数其实仅仅对 value 做了位运算
    inline disguised_ptr_t DISGUISE(id value) { return ~uintptr_t(value); }
    // 恢复
    inline id UNDISGUISE(disguised_ptr_t dptr) { return id(~dptr); }
  
    /**  存储关联对象的 value 和 policy  */
    class ObjcAssociation {
        uintptr_t _policy;  // 策略
        id _value;  // 值
    public:
        ObjcAssociation(uintptr_t policy, id value) : _policy(policy), _value(value) {}
        ObjcAssociation() : _policy(0), _value(nil) {}

        // 返回存储的值
        uintptr_t policy() const { return _policy; }
        id value() const { return _value; }
        
        // 判断是否有值
        bool hasValue() { return _value != nil; }
    };

#if TARGET_OS_WIN32
    typedef hash_map<void *, ObjcAssociation> ObjectAssociationMap;
    typedef hash_map<disguised_ptr_t, ObjectAssociationMap *> AssociationsHashMap;
#else
    typedef ObjcAllocator<std::pair<void * const, ObjcAssociation> > ObjectAssociationMapAllocator;
    
    // 继承自 map
    // 从 map 源码中可以看出，前两个参数 _Key 和 _Tp 对应着 map 中的 key_type 和 mapped_type，，而 key_type 和 mapped_type 是键值对的 key 和 value
    // ObjectAssociationMap 中同样以 key、value 的方式存储着 ObjcAssociation。
    // key 为传的 @"name"、@"age" 等
    class ObjectAssociationMap : public std::map<void *, ObjcAssociation, ObjectPointerLess, ObjectAssociationMapAllocator> {
    public:
        void *operator new(size_t n) { return ::malloc(n); }
        void operator delete(void *ptr) { ::free(ptr); }
    };
    typedef ObjcAllocator<std::pair<const disguised_ptr_t, ObjectAssociationMap*> > AssociationsHashMapAllocator;
    
    // 继承自 unordered_map
    // 从 unordered_map 源码中可以看出：前两个参数 _Key 和 _Tp 对应着 unordered_map 中的 key_type 和 mapped_type，而 key_type 和 mapped_type 是键值对的 key 和 value
    // 在这里 _Key 中传入的是 disguised_ptr_t，_Tp 中传入的值则为 ObjectAssociationMap *。
    // disguised_ptr_t 由受关联的对象指针进行位运算得到，如：传入 `self`
    class AssociationsHashMap : public unordered_map<disguised_ptr_t, ObjectAssociationMap *, DisguisedPointerHash, DisguisedPointerEqual, AssociationsHashMapAllocator> {
    public:
        void *operator new(size_t n) { return ::malloc(n); }
        void operator delete(void *ptr) { ::free(ptr); }
    };
#endif
}

using namespace objc_references_support;

// class AssociationsManager manages a lock / hash table singleton pair.
// Allocating an instance acquires the lock, and calling its assocations()
// method lazily allocates the hash table.

spinlock_t AssociationsManagerLock;

/**
  *  @brief   关联对象管理者
  */
class AssociationsManager {
    // associative references: object pointer -> PtrPtrHashMap.
    static AssociationsHashMap *_map;
public:
    AssociationsManager()   { AssociationsManagerLock.lock(); }
    ~AssociationsManager()  { AssociationsManagerLock.unlock(); }
    
    AssociationsHashMap &associations() {
        // 静态变量为 null 时初始化
        if (_map == NULL)
            _map = new AssociationsHashMap();
        return *_map;
    }
};

AssociationsHashMap *AssociationsManager::_map = NULL;

// expanded policy bits.

enum { 
    OBJC_ASSOCIATION_SETTER_ASSIGN      = 0,
    OBJC_ASSOCIATION_SETTER_RETAIN      = 1,
    OBJC_ASSOCIATION_SETTER_COPY        = 3,            // NOTE:  both bits are set, so we can simply test 1 bit in releaseValue below.
    OBJC_ASSOCIATION_GETTER_READ        = (0 << 8), 
    OBJC_ASSOCIATION_GETTER_RETAIN      = (1 << 8), 
    OBJC_ASSOCIATION_GETTER_AUTORELEASE = (2 << 8)
}; 

/**
  *  @brief   获取 object 指定 key 对应的关联对象
  */
id _object_get_associative_reference(id object, void *key) {
    id value = nil;
    uintptr_t policy = OBJC_ASSOCIATION_ASSIGN;
    {
        // 获取全局的管理者
        AssociationsManager manager;
        // 拿到管理者内部的 AssociationsHashMap，即 associations。
        AssociationsHashMap &associations(manager.associations());
        // object -》位运算 -》disguised_ptr_t
        disguised_ptr_t disguised_object = DISGUISE(object);
        
        AssociationsHashMap::iterator i = associations.find(disguised_object);
        
        // object 有关联对象
        if (i != associations.end()) {
            ObjectAssociationMap *refs = i->second;
            ObjectAssociationMap::iterator j = refs->find(key);
            
            // 对应 key 值有 value
            if (j != refs->end()) {
                ObjcAssociation &entry = j->second;
                // 获取 value 和 policy
                value  = entry.value();
                policy = entry.policy();
                if (policy & OBJC_ASSOCIATION_GETTER_RETAIN) {
                    objc_retain(value);
                }
            }
        }
    }
    if (value && (policy & OBJC_ASSOCIATION_GETTER_AUTORELEASE)) {
        objc_autorelease(value);
    }
    return value;
}

/**
  *  @brief   value 执行 retain 或 copy 操作
  */
static id acquireValue(id value, uintptr_t policy) {
    // OBJC_ASSOCIATION_SETTER_RETAIN | OBJC_ASSOCIATION_SETTER_COPY 都是定义的八进制数据
    // OBJC_ASSOCIATION_SETTER_RETAIN = 1401 -》转成二进制是 1100000001 -》十进制 669
    // OBJC_ASSOCIATION_SETTER_RETAIN = 1403 -》转成二进制是 1100000011 -》十进制 771
    switch (policy & 0xFF) {
    case OBJC_ASSOCIATION_SETTER_RETAIN:
        // 最终执行 ((id(*)(objc_object *, SEL))objc_msgSend)(this, SEL_retain);
        return objc_retain(value);
    case OBJC_ASSOCIATION_SETTER_COPY:
        // 调用 copy 方法
        return ((id(*)(id, SEL))objc_msgSend)(value, SEL_copy);
    }
    return value;
}

/**
  *  @brief   只对 value 关联的策略是 retain 的进行 release 调用
  */
static void releaseValue(id value, uintptr_t policy) {
    if (policy & OBJC_ASSOCIATION_SETTER_RETAIN) {
        return objc_release(value);
    }
}

/**
  *  @brief   对 value 调用 release 方法
  */
struct ReleaseValue {
    void operator() (ObjcAssociation &association) {
        releaseValue(association.value(), association.policy());
    }
};

/**
  *  @brief   向 object 添加关联对象
  */
void _object_set_associative_reference(id object, void *key, id value, uintptr_t policy)
{
    // retain the new value (if any) outside the lock.
    // 新建 ObjcAssociation 对象：policy = 0（OBJC_ASSOCIATION_ASSIGN），value = nil
    ObjcAssociation old_association(0, nil);
    
    // value 根据策略执行 retain 或 copy 操作，并返回新对象
    id new_value = value ? acquireValue(value, policy) : nil;
    {
        // 获取管理者
        AssociationsManager manager;
        // 拿到管理者内部的 AssociationsHashMap，即 associations。
        AssociationsHashMap &associations(manager.associations());
        // 传入的 object 经过 DISGUISE 函数被转化为了 disguised_ptr_t 类型的 disguised_object
        disguised_ptr_t disguised_object = DISGUISE(object);
        
        if (new_value) {
            // break any existing association.  查找 hashMap 中是否已经有了 disguised_object 这个 key，即受关联的对象是否已经有了关联
            AssociationsHashMap::iterator i = associations.find(disguised_object);
            
            // 受关联对象已经有过关联
            if (i != associations.end()) {
                // secondary table exists   Map 已经存在
                ObjectAssociationMap *refs = i->second;
                ObjectAssociationMap::iterator j = refs->find(key);
                // object 相同的 key 有过关联对象
                if (j != refs->end()) {
                    old_association = j->second;
                    // 保存
                    j->second = ObjcAssociation(policy, new_value);
                }
                else {
                    // 新建一个 key-value 键值对，value 是 ObjcAssociation 对象
                    (*refs)[key] = ObjcAssociation(policy, new_value);
                }
            }
            else {
                // create the new association (first time).   新建一个 ObjectAssociationMap
                ObjectAssociationMap *refs = new ObjectAssociationMap;
                // 存储到 AssociationsHashMap 中
                associations[disguised_object] = refs;
                // 新建 ObjcAssociation 对象，并存储到 ObjectAssociationMap 对象
                (*refs)[key] = ObjcAssociation(policy, new_value);
                object->setHasAssociatedObjects();
            }
        }
        else {
            // setting the association to nil breaks the association.
            AssociationsHashMap::iterator i = associations.find(disguised_object);
            if (i !=  associations.end()) {
                ObjectAssociationMap *refs = i->second;
                ObjectAssociationMap::iterator j = refs->find(key);
                if (j != refs->end()) {
                    old_association = j->second;
                    refs->erase(j);
                }
            }
        }
    }
    // release the old value (outside of the lock).
    if (old_association.hasValue()) ReleaseValue()(old_association);
}

/**
  *  @brief    移除 object 的所有关联对象
  */
void _object_remove_assocations(id object) {
    vector< ObjcAssociation,ObjcAllocator<ObjcAssociation> > elements;
    {
        // 获取管理者
        AssociationsManager manager;
        // 拿到管理者内部的 AssociationsHashMap，即 associations。
        AssociationsHashMap &associations(manager.associations());
        
        if (associations.size() == 0) return;
        
        disguised_ptr_t disguised_object = DISGUISE(object);
        AssociationsHashMap::iterator i = associations.find(disguised_object);
        
        // 当前对象有关联对象
        if (i != associations.end()) {
            // copy all of the associations that need to be removed.
            ObjectAssociationMap *refs = i->second;
            for (ObjectAssociationMap::iterator j = refs->begin(), end = refs->end(); j != end; ++j) {
                // 移除
                elements.push_back(j->second);
            }
            // remove the secondary table.
            // delete 内部调用 free 释放内存
            delete refs;
            associations.erase(i);
        }
    }
    // the calls to releaseValue() happen outside of the lock.
    for_each(elements.begin(), elements.end(), ReleaseValue());
}
