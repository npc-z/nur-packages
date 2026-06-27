# Mousedroid — Nix 包使用指南

将 Android 手机变为电脑的无线鼠标和键盘。本包提供桌面端服务器程序。

## 快速运行

```sh
nix run github:npc-z/nur-packages#mousedroid
```

## 集成到 Nix Flake

### 1. 作为系统包安装

```nix
# flake.nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nur-npc-z = {
      url = "github:npc-z/nur-packages";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, nur-npc-z, ... }@inputs: {
    nixosConfigurations.default = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ({ pkgs, ... }: {
          environment.systemPackages = [
            nur-npc-z.packages.${pkgs.system}.mousedroid
          ];
        })
      ];
    };
  };
}
```

然后 `sudo nixos-rebuild switch`，即可在应用菜单中找到 Mousedroid。

### 2. 在 Home Manager 中安装

```nix
# flake.nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nur-npc-z = {
      url = "github:npc-z/nur-packages";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, nur-npc-z, ... }@inputs: {
    homeConfigurations.youruser = home-manager.lib.homeManagerConfiguration {
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
      modules = [
        ({ pkgs, ... }: {
          home.packages = [
            nur-npc-z.packages.${pkgs.system}.mousedroid
          ];
        })
      ];
    };
  };
}
```

## Linux 权限配置

Mousedroid 通过 `/dev/uinput` 模拟键盘鼠标输入，需要相应权限。

### 方法一：udev 规则（推荐）

将以下内容添加到 NixOS 配置中：

```nix
# 在 NixOS module 中添加
services.udev.extraRules = ''
  KERNEL=="uinput", TAG+="uaccess"
'';
```

重建后重新插拔设备或重启即可生效。

### 方法二：将用户加入 input 组

```nix
users.users.youruser.extraGroups = [ "input" ];
```

之后需要重新登录。

### 方法三：手动加载 uinput 模块

如果 `/dev/uinput` 不存在，加载内核模块：

```sh
sudo modprobe uinput
```

可以在 NixOS 中设为自动加载：

```nix
boot.kernelModules = [ "uinput" ];
```

## 连接方式

| 方式 | 说明 |
|------|------|
| **Wi-Fi** | 手机和电脑在同一局域网，在 App 中输入电脑 IP 即可 |
| **蓝牙** | 通过系统蓝牙设置配对手机和电脑 |
| **USB** | 手机开启 USB 调试，用数据线连接；本包已内置 adb |

## 故障排查

- **鼠标无法移动**：检查 uinput 权限是否配置正确（`ls -l /dev/uinput`）
- **USB 连接失败**：确认手机已开启 USB 调试，运行 `adb devices` 确认设备识别
- **Wi-Fi 无法连接**：检查路由器是否开启了 AP 隔离，防火墙是否放行 6969 端口
- **Wayland 下托盘图标不显示**：切换到 Xorg 可解决（上游已知问题）

## 手机端

从 [GitHub Releases](https://github.com/darusc/Mousedroid/releases) 下载 APK 安装到 Android 手机上。
