// Qt's qyieldcpu.h calls __yield() on Apple Silicon without declaring it, and
// recent Apple clang treats that as an error. Declaring it first, through the
// header the compiler itself suggests, lets Qt's headers build.
#pragma once
#if defined(__aarch64__) || defined(__arm64__)
#include <arm_acle.h>
#endif
