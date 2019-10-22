## [Runtime编译环境搭建](https://juejin.im/post/5cc4706b6fb9a0321d73b273)

首先，需要准备的资源：runtime完整源码，这个可以在苹果开放资源网页找到。点进这个页面，接着点击macOS下面的最新版本，在新页面中command+f搜索objc即可找到runtime源码，再点击右边的下载按钮即可得到。
到这里runtime源码已经准备好，除此之外，runtime源码的编译还需要添加一些必要的依赖。点击这里可以直达下载页面。
在这个资源页面找到以下开源代码，下载好合适的版本，然后解压到同一个目录下，目录名可以起名为opensources，留着备用。

- Libc
- dyld
- libauto
- libclosure
- libdispatch
- xnu
- libpthread
- launchd
- libplatform

下面开始正式编译流程

command + b 编译 objc，报错：The i386 architecture is deprecated. You should update your ARCHS build setting to remove the i386 architecture. (in target 'objc')和The i386 architecture is deprecated. You should update your ARCHS build setting to remove the i386 architecture. (in target 'objc-trampolines')，选择objc->TARGETS objc->build settings->architecture，将release和debug模式都改为Standard Architectures。

继续command\+b编译，提示'sys/reason.h' file not found，在项目目录下创建一个文件夹include，用于存放所有需要导入工程的文件，并且把它添加到项目的Header Search Paths中，依次选择objc -\> TARGETS -\> objc -\> Build Settings，搜索框中输入 header search path，然后加入 ``$(SRCROOT\)/include``
接下来需要去已下载好的开源项目中寻找reason.h头文件了，方式有两种：


1. 使用命令行

	进入刚才创建的开源代码目录下 cd ../opensources，这里需要按照自己的实际路径来cd
搜索文件名 find . -name ‘reason.h’
可以看到搜索结果显示在./xnu-4903.221.2/bsd/sys/reason.h中，按照这个路径找到reason.h文件，根据编译错误提示知道，这个reason.h文件在路径sys下，那么在已创建的include文件下创建一个新的sys文件夹，里面放入找到的reason.h文件：


2. 普通搜索

	直接在Opensource中搜索reason.h文件，接下来处理和上述一样。


再次编译，提示'mach-o/dyld\_priv.h' file not found
选择./dyld-551.3/include/mach-o/dyld\_priv.h，和上述同样操作，不再重述。


提示'os/lock\_private.h' file not found
选择./libplatform-177.200.16/private/os/lock\_private.h


提示'os/base\_private.h' file not found
选择./libplatform-177.200.16/private/os/base\_private.h


提示'pthread/tsd\_private.h' file not found
选择./libpthread-330.220.2/private/tsd\_private.h


提示'System/machine/cpu\_capabilities.h' file not found
选择./xnu-4903.221.2/osfmk/machine/cpu\_capabilities.h


提示'os/tsd.h' file not found
选择./xnu-4903.221.2/libsyscall/os/tsd.h


提示'pthread/spinlock\_private.h' file not found
选择./libpthread-330.220.2/private/spinlock\_private.h


提示'System/pthread\_machdep.h' file not found
选择./Libc-825.40.1 2/pthreads/pthread\_machdep.h


提示Typedef redefinition with different types ('int' vs 'volatile OSSpinLock' (aka 'volatile int’))
这种redefinition错误时，在include文件夹下使用grep命令：

```
// 如 重复定义 pthread_lock_t
grep -rne "typedef.*pthread_lock_t” .
// 输出
./pthread/spinlock_private.h:59:typedef volatile OSSpinLock pthread_lock_t __deprecated_msg("Use <os/lock.h> instead”);
./System/pthread_machdep.h:214:typedef int pthread_lock_t;
```

可以看见有两处定义了pthread\_lock\_t，注释掉pthread\_machdep.h文件中的定义即可。

提示Static declaration of '_pthread_getspecific_direct' follows non-static declaration

这里有三个函数定义重复了：

```
		_pthread_has_direct_tsd(void)
		_pthread_getspecific_direct(unsigned long slot)
		_pthread_setspecific_direct(unsigned long slot, void * val)
grep -re "_pthread_has_direct_tsd(void)” .
//输出
./pthread/tsd_private.h:_pthread_has_direct_tsd(void)
./System/pthread_machdep.h:_pthread_has_direct_tsd(void)
 grep -re "_pthread_getspecific_direct(unsigned long slot)” .
//输出
./pthread/tsd_private.h:_pthread_getspecific_direct(unsigned long slot)
./System/pthread_machdep.h:_pthread_getspecific_direct(unsigned long slot)
grep -re "_pthread_setspecific_direct(unsigned long slot, void \* val)” .
//输出
./pthread/tsd_private.h:_pthread_setspecific_direct(unsigned long slot, void * val)
./System/pthread_machdep.h:_pthread_setspecific_direct(unsigned long slot, void * val)
这里选择把pthread_machdep.h文件中的定义注释掉。
```

提示'CrashReporterClient.h' file not found
选择./Libc-825.40.1 2/include/CrashReporterClient.h，放入include文件夹下之后还是报错，需要在Build Settings->Preprocessor Macros中加入：LIBC\_NO\_LIBCRASHREPORTERCLIENT
提示'Block\_private.h' file not found
选择./libdispatch-1008.220.2/src/BlocksRuntime/Block\_private.h
提示'objc-shared-cache.h' file not found
选择./dyld-551.3/include/objc-shared-cache.h
提示Use of undeclared identifier ‘DYLD\_MACOSX\_VERSION\_10\_13
在 dyld\_priv.h 文件顶部加入一下宏：

```
#define DYLD_MACOSX_VERSION_10_11 0x000A0B00
#define DYLD_MACOSX_VERSION_10_12 0x000A0C00
#define DYLD_MACOSX_VERSION_10_13 0x000A0D00
#define DYLD_MACOSX_VERSION_10_14 0x000A0E00
```

提示'\_simple.h' file not found
选择./libplatform-177.200.16/private/\_simple.h


提示'isa.h' file not found
isa.h文件在项目的runtime文件夹中，新加入的一个头文件。
直接把它引入include文件夹中去即可。


提示can't open order file: /Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX10.14.sdk/AppleInternal/OrderFiles/libobjc.order
修改工程配置，将Build Settings->Linking->Order File改为工程根目录下的libobjc.order，即：\$(SRCROOT)/libobjc.order。


提示library not found for -lCrashReporterClient
此时在 Build Settings -> Linking -> Other Linker Flags里删掉"-lCrashReporterClient"（Debug和Release都删了）


提示SDK "macosx.internal" cannot be located.和unable to find utility "clang++", not a developer tool or in PATH
把Target-objc的Build Phases->Run Script(markgc)里的内容macosx.internal改为macosx，这里我猜测macosx.internal为苹果内部的macosx，说的不对，大家指出来。


提示no such public header file: '/tmp/objc.dst/usr/include/objc/ObjectiveC.apinotes’
这里需要把Target-objc的Build Settings->Other Text-Based InstallAPI Flags里的内容设为空!
并且一定记得要把Text-Based InstallAPI Verification Model里的值改为Errors Only

作者：wenYuLiu
链接：https://juejin.im/post/5cc4706b6fb9a0321d73b273
来源：掘金
著作权归作者所有。商业转载请联系作者获得授权，非商业转载请注明出处。