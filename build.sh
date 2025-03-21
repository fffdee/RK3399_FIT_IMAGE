#!/bin/bash

set -e
# 初始化配置文件路径
INIT_CONFIG_FILE="./init_config.defconfig"
# 默认值
DEFAULT_INIT_STATUS=n
TOOLCHAIN_STATUS=n

PROJERCT_PATH=$(pwd)
# 检查初始化状态
check_init_status() {
    local init_status
    if [ -f "$INIT_CONFIG_FILE" ]; then
        # 读取初始化状态
        init_status=$(grep "CONFIG_INIT_STATUS" "$INIT_CONFIG_FILE" | awk -F '=' '{print $2}' | tr -d ' ')
    else
        # 如果配置文件不存在，初始化状态为默认值
        init_status=$DEFAULT_INIT_STATUS
    fi
    echo "$init_status"
}

# 检查工具链状态
check_toolchain_status() {
    local toolchain_status
    if [ -f "$INIT_CONFIG_FILE" ]; then
        # 读取工具链状态
        toolchain_status=$(grep "TOOLCHAIN_STATUS" "$INIT_CONFIG_FILE" | awk -F '=' '{print $2}' | tr -d ' ')
    else
        # 如果配置文件不存在，工具链状态为默认值
        toolchain_status=$DEFAULT_INIT_STATUS
    fi
    echo "$toolchain_status"
}

# 下载并解压工具链
download_and_extract_toolchain() {
    # 下载工具链
    wget -P ./download https://armkeil.blob.core.windows.net/developer/Files/downloads/gnu/14.2.rel1/binrel/arm-gnu-toolchain-14.2.rel1-x86_64-aarch64-none-linux-gnu.tar.xz

    # 解压工具链到 /usr/
    sudo tar -xJvf ./download/arm-gnu-toolchain-14.2.rel1-x86_64-aarch64-none-linux-gnu.tar.xz -C /usr/

    # 将工具链路径写入 /etc/profile
    sudo sh -c 'echo "export PATH=\$PATH:/usr/arm-gnu-toolchain-14.2.rel1-x86_64-aarch64-none-linux-gnu/bin" >> /etc/profile'

    # 查看 /etc/profile 的内容
    cat /etc/profile

    # 刷新环境变量
    source /etc/profile

    aarch64-none-linux-gnu-gcc -v

    # 更新工具链状态
    update_toolchain_status
}

# 解压 tar 文件
extract_tar() {

    wget -P ./download https://ftp.denx.de/pub/u-boot/u-boot-2023.04.tar.bz2
    tar -jvxf ./download/u-boot-2023.04.tar.bz2 -C  ./ 
}

# 更新初始化状态为已完成
update_init_status() {
    echo "CONFIG_INIT_STATUS=y" > "$INIT_CONFIG_FILE"
}

# 更新工具链状态为已完成
update_toolchain_status() {
    echo "TOOLCHAIN_STATUS=y" >> "$INIT_CONFIG_FILE"
}

# 复制文件
copy_files() {
    cd $PROJERCT_PATH
    cp ./modify/make_fit_atf.py ./u-boot-2023.04/arch/arm/mach-rockchip/make_fit_atf.py
    chmod +x ./u-boot-2023.04/arch/arm/mach-rockchip/make_fit_atf.py 

    cp ./modify/sw799_defconfig ./u-boot-2023.04/configs/
    
    cp ./modify/rk3399_bl31_v1.36.elf ./u-boot-2023.04/bl31.elf
    cp ./modify/rk3399_bl31_v1.36.elf ./u-boot-2023.04/atf-bl31

}

# 配置函数
config() {
    echo "执行配置任务..."
    # 在这里添加配置相关的命令
    if [ "$init_status" = "y" ]; then
                echo "已经执行过解压，跳过解压步骤。"
    else
        echo "开始解压..."
        extract_tar
        update_init_status
        echo "初始化完成，已更新配置文件。"
    fi

    if [ "$toolchain_status" = "y" ]; then
                echo "工具链已下载，跳过下载步骤。"
    else
        echo "Download toolchain..."
        download_and_extract_toolchain
        echo "Download finished。"
    fi

    echo "开始复制文件..."
    copy_files
    echo "文件复制完成。"
}

# 编译 U-Boot 函数
make_uboot() {
    echo "开始编译 U-Boot..."
    cd $PROJERCT_PATH/u-boot-2023.04
    make sw799_defconfig
    make 
    tools/mkimage -n rk3399 -T rksd -d tpl/u-boot-tpl.bin idbloader.img
    cat spl/u-boot-spl.bin >> idbloader.img
    cp atf-bl31 ./arch/arm/mach-rockchip/bl31.elf
    cp /usr/lib/python3/dist-packages/elftools/ ./arch/arm/mach-rockchip/ -r 

    make u-boot.itb 
    # 在这里添加编译 U-Boot 的命令
}

# 编译内核函数
make_kernel() {
    echo "开始编译内核..."
    # 在这里添加编译内核的命令
}

# 清理 U-Boot 函数
clean_uboot() {
    echo "清理 U-Boot..."
    cd $PROJERCT_PATH/u-boot-2023.04
    make clean
    make distclean
    # 在这里添加清理 U-Boot 的命令
}

# 清理内核函数
clean_kernel() {
    echo "清理内核..."
    # 在这里添加清理内核的命令
}

# 清理所有函数
clean_all() {
    clean_uboot
    clean_kernel
    echo "清理完成。"
}

to_git() {
    echo "Get env to git..."
    cd $PROJERCT_PATH
    sudo rm -r  u-boot-2023.04
    sudo rm -r ./download/* 
   
}

all_in_one() {
    
   config
   make_uboot
   make_kernel
}
# 主函数
main() {
    local init_status=$(check_init_status)
    local toolchain_status=$(check_toolchain_status)

    case "$1" in
        config)
            config
            ;;
        make_uboot)
            make_uboot
            ;;
        make_kernel)
            make_kernel
            ;;
        clean_uboot)
            clean_uboot
            ;;
        clean_kernel)
            clean_kernel
            ;;
        clean_all)
            clean_all
            ;;
        to_git)
            to_git
            ;;
        "")


            all_in_one
            ;;
        *)
            echo "无效的参数: $1"
            echo "可用的参数: config, make_uboot, make_kernel, clean_uboot, clean_kernel, clean_all"
            exit 1
            ;;
    esac
}

# 执行主函数
main "$@"