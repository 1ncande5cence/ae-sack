FROM ubuntu:20.04
ENV TZ=America/New_York
# for binutils & llvm-12 dependencies
RUN apt update && \
    DEBIAN_FRONTEND=noninteractive TZ=America/New_York \
    apt install git gcc g++ make cmake wget tzdata \
        libgmp-dev libmpfr-dev texinfo bison python3 python3-pip -y && \
    pip3 install wllvm && \
    ln -sf /usr/share/zoneinfo/$TZ /etc/localtime && \
    echo $TZ > /etc/timezone

# build clang-12 with gold plugin
RUN apt install -y lsb-release wget software-properties-common

RUN wget https://apt.llvm.org/llvm.sh && chmod +x llvm.sh && ./llvm.sh 12 all && \
    cp /usr/lib/llvm-12/lib/LLVMgold.so /usr/lib/bfd-plugins/ && \
    cp /usr/lib/llvm-12/lib/libLTO.so /usr/lib/bfd-plugins/

RUN update-alternatives \
      --install /usr/lib/llvm              llvm             /usr/lib/llvm-12  100 \
      --slave   /usr/bin/llvm-config       llvm-config      /usr/bin/llvm-config-12  \
        --slave   /usr/bin/llvm-ar           llvm-ar          /usr/bin/llvm-ar-12 \
        --slave   /usr/bin/llvm-as           llvm-as          /usr/bin/llvm-as-12 \
        --slave   /usr/bin/llvm-bcanalyzer   llvm-bcanalyzer  /usr/bin/llvm-bcanalyzer-12 \
        --slave   /usr/bin/llvm-c-test       llvm-c-test      /usr/bin/llvm-c-test-12 \
        --slave   /usr/bin/llvm-cov          llvm-cov         /usr/bin/llvm-cov-12 \
        --slave   /usr/bin/llvm-diff         llvm-diff        /usr/bin/llvm-diff-12 \
        --slave   /usr/bin/llvm-dis          llvm-dis         /usr/bin/llvm-dis-12 \
        --slave   /usr/bin/llvm-dwarfdump    llvm-dwarfdump   /usr/bin/llvm-dwarfdump-12 \
        --slave   /usr/bin/llvm-extract      llvm-extract     /usr/bin/llvm-extract-12 \
        --slave   /usr/bin/llvm-link         llvm-link        /usr/bin/llvm-link-12 \
        --slave   /usr/bin/llvm-mc           llvm-mc          /usr/bin/llvm-mc-12 \
        --slave   /usr/bin/llvm-nm           llvm-nm          /usr/bin/llvm-nm-12 \
        --slave   /usr/bin/llvm-objdump      llvm-objdump     /usr/bin/llvm-objdump-12 \
        --slave   /usr/bin/llvm-ranlib       llvm-ranlib      /usr/bin/llvm-ranlib-12 \
        --slave   /usr/bin/llvm-readobj      llvm-readobj     /usr/bin/llvm-readobj-12 \
        --slave   /usr/bin/llvm-rtdyld       llvm-rtdyld      /usr/bin/llvm-rtdyld-12 \
        --slave   /usr/bin/llvm-size         llvm-size        /usr/bin/llvm-size-12 \
        --slave   /usr/bin/llvm-stress       llvm-stress      /usr/bin/llvm-stress-12 \
        --slave   /usr/bin/llvm-symbolizer   llvm-symbolizer  /usr/bin/llvm-symbolizer-12 \
        --slave   /usr/bin/llvm-tblgen       llvm-tblgen      /usr/bin/llvm-tblgen-12 \
        --slave   /usr/bin/llc               llc              /usr/bin/llc-12 \
        --slave   /usr/bin/opt               opt              /usr/bin/opt-12 && \
    update-alternatives \
      --install /usr/bin/clang                 clang                  /usr/bin/clang-12     100 \
      --slave   /usr/bin/clang++               clang++                /usr/bin/clang++-12 \
      --slave   /usr/bin/clang-cpp             clang-cpp              /usr/bin/clang-cpp-12

# put the /usr/bin of the highest priority, to make sure clang-12 is called before clang-15, which is in /usr/local/bin
ENV PATH="/usr/bin:${PATH}"

# Create a sack directory and setup everything there.
RUN mkdir /ae-sack
WORKDIR /ae-sack

# setup wllvm
COPY wllvm/ ./wllvm
RUN ls -al ./wllvm && \
    python3 /ae-sack/wllvm/replace_extraction.py


# copy and install dependencies
# build AFL
COPY AFL ./AFL
RUN apt-get install libjansson-dev libjsoncpp-dev -y
RUN cd ./AFL/ && \
    CFLAGS="" CXXFLAGS="" CC=gcc CXX=g++ AFL_NO_X86=1 make && \
    CFLAGS="" CXXFLAGS="" make -C llvm_mode_indirect_flip

# build oracle constructor
COPY oracle-generation ./oracle-generation

# utility
COPY scripts ./scripts
COPY subgt ./subgt
COPY target-collector ./target-collector
COPY tools ./tools 


# Reset the working directory to top-level directory.
WORKDIR /


