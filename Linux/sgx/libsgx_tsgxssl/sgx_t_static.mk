#
# Copyright (C) 2011-2017 Intel Corporation. All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
#
#   * Redistributions of source code must retain the above copyright
#     notice, this list of conditions and the following disclaimer.
#   * Redistributions in binary form must reproduce the above copyright
#     notice, this list of conditions and the following disclaimer in
#     the documentation and/or other materials provided with the
#     distribution.
#   * Neither the name of Intel Corporation nor the names of its
#     contributors may be used to endorse or promote products derived
#     from this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
# "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
# LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
# A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
# OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
# SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
# LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
# DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
# THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#
#


######## SGX SDK Settings ########
SGX_MODE ?= HW
SGX_ARCH ?= x64

ifeq ($(shell getconf LONG_BIT), 32)
	SGX_ARCH := x86
else ifeq ($(findstring -m32, $(CXXFLAGS)), -m32)
	SGX_ARCH := x86
endif

ifeq ($(SGX_ARCH), x86)
	$(error x86 build is not supported, only x64!!)
else
	SGX_COMMON_CFLAGS := -m64 -Wall
	ifeq ($(LINUX_SGX_BUILD), 1)
		include ../../../../../buildenv.mk
		SGX_EDGER8R := $(BUILD_DIR)/sgx_edger8r
		SGX_SDK_INC := $(COMMON_DIR)/inc
		STL_PORT_INC := $(LINUX_SDK_DIR)/tlibstdcxx
	else
		SGX_EDGER8R := $(SGX_SDK)/bin/x64/sgx_edger8r
		SGX_SDK_INC := $(SGX_SDK)/include
		STL_PORT_INC := $(SGX_SDK_INC)
	endif
endif

ifdef DEBUG
ifeq ($(SGX_PRERELEASE), 1)
$(error Cannot set DEBUG and SGX_PRERELEASE at the same time!!)
endif
endif

ifdef DEBUG
        SGX_COMMON_CFLAGS += -O0 -g
else
        SGX_COMMON_CFLAGS += -O2 -D_FORTIFY_SOURCE=2
endif


ifeq ($(SGX_MODE), HW)
ifndef DEBUG
ifneq ($(SGX_PRERELEASE), 1)
Build_Mode = HW_RELEASE
endif
endif
endif

SgxSSL_Package_Include := ../../package/include
SGX_EDL_FILE := $(SgxSSL_Package_Include)/sgx_tsgxssl.edl

Sgx_tssl_Cpp_Files := $(wildcard *.cpp)
Sgx_tssl_C_Files := $(wildcard *.c)
Sgx_tssl_S_Files := $(wildcard *.S)

Sgx_tssl_Cpp_Objects := $(Sgx_tssl_Cpp_Files:.cpp=.o)
Sgx_tssl_C_Objects := $(Sgx_tssl_C_Files:.c=.o)
Sgx_tssl_S_Objects := $(Sgx_tssl_S_Files:.S=.o)

Sgx_tssl_Include_Paths := -I. -I$(SgxSSL_Package_Include) -I$(SGX_SDK_INC) -I$(SGX_SDK_INC)/tlibc -I$(STL_PORT_INC)/stlport

Common_C_Cpp_Flags := -DOS_ID=$(OS_ID) $(SGX_COMMON_CFLAGS) -nostdinc -fdata-sections -ffunction-sections -Os -fvisibility=hidden -fpie -fpic -fstack-protector -fno-builtin-printf -Wformat -Wformat-security $(Sgx_tssl_Include_Paths)
Sgx_tssl_C_Flags := $(Common_C_Cpp_Flags) -Wno-implicit-function-declaration -std=c11
Sgx_tssl_Cpp_Flags := $(Common_C_Cpp_Flags) -std=c++11 -nostdinc++

.PHONY: all run

all: libsgx_tsgxssl.a

######## sgx_tsgxssl Objects ########
sgx_tsgxssl_t.c: $(SGX_EDGER8R) $(SGX_EDL_FILE)
	$(SGX_EDGER8R) --header-only --trusted $(SGX_EDL_FILE) --search-path $(SGX_SDK_INC)
	@echo "GEN  =>  $@"

sgx_tsgxssl_t.o: sgx_tsgxssl_t.c
	@$(CC) $(Sgx_tssl_C_Flags) -c $< -o $@
	@echo "CC   <=  $<"

%.o: %.cpp
	@$(CXX) $(Sgx_tssl_Cpp_Flags) -c $< -o $@
	@echo "CXX  <=  $<"

%.o: %.c
	@$(CC) $(Sgx_tssl_C_Flags) -c $< -o $@
	@echo "CC  <=  $<"

%.o: %.S
	@$(CC) $(Common_C_Cpp_Flags) -c $< -o $@
	@echo "CC  <=  $<"

libsgx_tsgxssl.a: sgx_tsgxssl_t.c $(Sgx_tssl_Cpp_Objects) $(Sgx_tssl_C_Objects) $(Sgx_tssl_S_Objects)
	ar rcs libsgx_tsgxssl.a $(Sgx_tssl_Cpp_Objects) $(Sgx_tssl_C_Objects) $(Sgx_tssl_S_Objects) 
	@echo "LINK =>  $@"

clean:
	@rm -f libsgx_tsgxssl.* sgx_tsgxssl_t.* $(Sgx_tssl_Cpp_Objects) $(Sgx_tssl_C_Objects) $(Sgx_tssl_S_Objects)
	
