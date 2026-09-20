[English](README.md) · [简体中文](README.zh-CN.md)

# npc-z 的 Nix 个人仓库

**我的个人 [NUR 仓库](https://github.com/npc-z/nur-packages)**

![Build and populate cache](https://github.com/npc-z/nur-packages/workflows/Build%20and%20populate%20cache/badge.svg)
[![Cachix Cache](https://img.shields.io/badge/cachix-npc--z-blue.svg)](https://npc-z.cachix.org)

## 如何使用

> **注意**：使用前需要先安装 [Nix](https://nixos.org/nix/)，并启用 `flakes` 与 `new-commands`。

直接从本仓库运行软件包（带缓存）：

```sh
nix run github:npc-z/nur-packages#some-package
```

在 `flake.nix` 中引用本仓库：

```nix
# flake.nix
{
  # 这里的 nixConfig 只影响本 flake 自身，不影响系统配置！
  # 更多说明见：
  #     https://nixos-and-flakes.thiscute.world/nixos-with-flakes/add-custom-cache-servers
  nixConfig = {
    # 拉取软件包时，substituters 会被追加到默认 substituters 之后
    extra-substituters = [ "https://npc-z.cachix.org" ];
    extra-trusted-public-keys = [ "npc-z.cachix.org-1:k0E/cLF09sxkG6MNGt9r3ZJCsEMM9/k4UL9O4zXvQ/k=" ];
  };

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nur-npc-z = {
      url = "github:npc-z/nur-packages";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, nur-npc-z, ... }@inputs: {
    nixosConfigurations.default = nixpkgs.lib.nixosSystem rec {
      system = "x86_64-linux";
      modules = [
        ({ pkgs, ... }: {
          environment.systemPackages = with pkgs; [
            # 把本仓库的软件包加进来
            nur-npc-z.packages.${system}.some-package
          ];
        })
      ];
    };
  };
}
```

## 软件包

<!-- Add your packages list here -->

| 软件包                                                | 说明                            |
| -------------------------------------------------- | ----------------------------- |
| [microneo](https://github.com/sollawen/microNeo)   | 终端 Markdown 编辑器，渲染与编辑在同一窗口完成  |
| [mousedroid](https://github.com/darusc/Mousedroid) | 把 Android 手机变成跨平台的鼠标与键盘       |
| [dbx-desktop](https://github.com/t8y2/dbx)         | 支持 70+ 数据库的轻量数据库管理工具（Tauri 2） |

## 自动更新

[`update-packages.yml`](.github/workflows/update-packages.yml) 每周一运行：逐个软件包检查上游是否有新版本、验证能否构建，并在 `auto/update-<package>` 分支上开启（或刷新）一个 PR。目前它维护 `dbx-desktop`、`microneo` 与 `mousedroid`；新软件包只要遵循下面的约定就能自动接入。

### 约定

1. **`pkgs/<name>/hashes.json`** 保存所有与版本相关的值。它必须包含 `"version"`，其余键是表达式用到的固定输出（fixed-output）哈希：`srcHash`、`pnpmDepsHash`、`cargoDepsHash`、`npmDepsHash`、`vendorHash` 等。
2. **`pkgs/<name>/default.nix` 保持与版本无关** —— 只读取这些值，绝不写死：

   ```nix
   let
     versionData = lib.importJSON ./hashes.json;
   in
   stdenv.mkDerivation (finalAttrs: {
     version = versionData.version;
     # src.hash = versionData.srcHash; 等等
   })
   ```

3. **`pkgs/<name>/update.sh`** 直接复制现成的一份即可（包名由脚本自身路径推导）；只有当上游 tag 不是纯 `vX.Y.Z` 时，才需要调整其中的 `version_regex` —— 例如 `mousedroid` 的 tag 是两段式，用的是 `^v([0-9]+\.[0-9]+)$`。

更新器（`nix-update`）因此只会改写 `hashes.json`，机器人开的 PR 只动数据，永不碰打包代码。

### 为什么构建要钉住版本，以及哈希漂移

[`build.yml`](.github/workflows/build.yml) 用三个 nixpkgs 通道**评估**包集合（作为兼容性信号），但**构建时使用 `flake.lock` 中钉住的 nixpkgs revision** —— 也就是更新器用来计算哈希的那个 revision。

这一点很关键：有些固定输出哈希是 nixpkgs 工具链的函数，而不只是上游源码的函数。`fetchPnpmDeps` 的产物会随 pnpm 版本变化（unstable 上 `pkgs.pnpm` 已从 11.x 升到 12.x），所以同一个哈希永远无法匹配*滚动*的通道。同理，软件包必须显式传入自己的工具链（例如 `pnpm = pnpm_11`），而不能依赖 nixpkgs 可能改变指向的默认值。

当工具链确实变化时（例如一次 `flake.lock` 升级），每个包的依赖哈希都会被自动重新推导：每周的工作流先升级 `flake.lock`，再尝试常规更新；如果版本已经是最新，就用 `UPDATE_DEPS_ONLY=1` 再跑一次 `update.sh`，只刷新哈希。

正因为如此，**`flake.lock` 由机器人负责升级**，而不是 dependabot：锁升级与它导致失效的哈希会出现在同一个 PR 里，因此不可能出现“只升锁、哈希却是旧的”这种落地。手动运行时可用 `flake: false` 只更新软件包而不动 nixpkgs。

### `UPDATE_TOKEN` secret

由 `github-actions[bot]` 创建的 PR，其 CI 运行会被 GitHub 挂起，直到有写权限的用户批准 —— 这样可以避免自动生成的代码静默运行那些能接触密钥的工作流（见 [变更说明](https://github.blog/changelog/2026-06-11-bot-created-pull-requests-can-run-workflows-if-approved/)）。因此本工作流用一个 fine-grained PAT（存为 `UPDATE_TOKEN` secret）来创建 PR，使 PR 的作者成为真实用户，其 `build.yml` 检查便会自行开始。若该 secret 不存在，则回退使用 `GITHUB_TOKEN`：PR 仍会照常创建，只是检查需要人工点一下批准。

Token 权限（fine-grained，仅限本仓库）：`Contents: Read and write`、`Pull requests: Read and write`。使用 [`scripts/setup-update-token.sh`](scripts/setup-update-token.sh) 创建并写入 secret —— 它会引导你打开 token 页面并保存。

### 手动更新

```sh
# 更新到最新稳定版
nix shell --inputs-from . nixpkgs#nix-update -c ./pkgs/dbx-desktop/update.sh

# 或指定精确版本
UPDATE_VERSION=0.6.16 nix shell --inputs-from . nixpkgs#nix-update -c ./pkgs/dbx-desktop/update.sh

# 或只针对当前钉住的 nixpkgs 重新推导依赖哈希
UPDATE_DEPS_ONLY=1 nix shell --inputs-from . nixpkgs#nix-update -c ./pkgs/dbx-desktop/update.sh
```

然后用 `nix build .#dbx-desktop` 验证。
