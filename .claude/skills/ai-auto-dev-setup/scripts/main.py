#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
AIAutoDevSetup - AI事业部全流程自动化研发安装工具（独立版）
直接从 TFS WinCode/Skill 仓库克隆并安装技能，无需依赖其他技能

性能优化版本：
- 支持并行克隆（最多4个并发）
- 减少超时时间（60秒）
- 凭据验证检查
"""

import os
import sys
import re
import time
import json
import subprocess
import argparse
import platform
import shutil
from datetime import datetime
from pathlib import Path
from typing import Optional, List, Dict, Tuple
from concurrent.futures import ThreadPoolExecutor, as_completed

# 检测 yaml 可用性
_HAS_YAML = False
try:
    import yaml
    _HAS_YAML = True
except ImportError:
    pass

# 默认配置
CACHE_ROOT = Path.home() / ".cache" / "WinCode"
GLOBAL_SKILLS_DIR = Path.home() / ".claude" / "skills"
TFS_BASE_URL = "http://tfs2018-web.winning.com.cn:8080/tfs"
TFS_COLLECTION = "WinCode"
TFS_SKILL_PROJECT = "Skill"
TFS_HOST = "tfs2018-web.winning.com.cn:8080"
TFS_SERVER_URL = "http://tfs2018-web.winning.com.cn:8080/tfs"

CONFIG = {
    "cache_root": CACHE_ROOT,
    "skills_cache": CACHE_ROOT / "skill",
    "registry_path": CACHE_ROOT / "registry.json",
    "skills_dir": GLOBAL_SKILLS_DIR,
}


def _decode_output(data: bytes) -> str:
    """安全解码 subprocess 输出，兼容 Windows GBK 环境"""
    if not data:
        return ''
    for enc in ('utf-8', 'gbk', 'latin-1'):
        try:
            return data.decode(enc)
        except (UnicodeDecodeError, LookupError):
            continue
    return data.decode('latin-1')


def run_cmd(cmd: List[str], cwd: Optional[Path] = None, check: bool = True,
            timeout: int = 60, shell: bool = False) -> subprocess.CompletedProcess:
    """执行命令（bytes 模式，手动解码）"""
    is_curl_cmd = cmd and cmd[0] == 'curl'
    if sys.platform == "win32" and not shell and not is_curl_cmd:
        shell = True
    try:
        result = subprocess.run(
            cmd,
            cwd=cwd,
            capture_output=True,
            check=check,
            shell=shell,
            timeout=timeout,
        )
        result.stdout = _decode_output(result.stdout)
        result.stderr = _decode_output(result.stderr)
        return result
    except subprocess.TimeoutExpired as e:
        print(f"[!] 命令超时({timeout}s): {' '.join(cmd)[:80]}")
        stdout = _decode_output(e.stdout) if e.stdout else ''
        return subprocess.CompletedProcess(cmd, returncode=-1, stdout=stdout, stderr='Timed out')


def get_git_credentials(cli_user: str = "", cli_pass: str = "") -> tuple:
    """获取 TFS 凭据，按优先级尝试多个来源，返回 (username, password)"""
    # 来源 1：CLI 参数
    if cli_user and cli_pass:
        return cli_user, cli_pass

    # 来源 2：环境变量
    env_user = os.environ.get("TFS_CRED_USER", "")
    env_pass = os.environ.get("TFS_CRED_PASS", "")
    if env_user and env_pass:
        return env_user, env_pass

    # 来源 3：git credential fill
    input_data = f"protocol=http\nhost={TFS_HOST}\n\n".encode('utf-8')
    try:
        result = subprocess.run(
            ["git", "credential", "fill"],
            input=input_data,
            capture_output=True,
            timeout=10
        )
        output = _decode_output(result.stdout)
        creds = {}
        for line in output.strip().split('\n'):
            if '=' in line:
                k, v = line.split('=', 1)
                creds[k.strip()] = v.strip()
        username = creds.get('username', '')
        password = creds.get('password', '')
        if username and password:
            return username, password
    except Exception:
        pass

    # 所有来源均失败 → 打印标记
    print("[NEED_CREDENTIALS] TFS API 认证失败，需要域账户凭据")
    print("  提示：请通过 Claude Code AskUserQuestion 提供域用户名和密码")
    print("  或设置环境变量 TFS_CRED_USER / TFS_CRED_PASS")
    return '', ''


def fetch_repos_from_api(cli_user: str = "", cli_pass: str = "") -> List[Dict]:
    """通过 TFS REST API 获取仓库列表（使用 curl --ntlm）"""
    username, password = get_git_credentials(cli_user, cli_pass)
    allow_empty_creds = platform.system() == "Windows" or not (username and password)
    if not allow_empty_creds and (not username or not password):
        return []

    url = f"{TFS_BASE_URL}/{TFS_COLLECTION}/{TFS_SKILL_PROJECT}/_apis/git/repositories?api-version=4.1"

    # Windows SSPI 可免凭据；其他平台需要显式凭据
    sspi_mode = platform.system() == "Windows" and not (username and password)
    user_pass = f"{username}:{password}" if (username and password) else ":"

    try:
        result = run_cmd([
            "curl", "-s", "-w", "\\n%{http_code}",
            "--connect-timeout", "10", "--max-time", "30",
            "--ntlm", "-u",
            user_pass, url
        ], timeout=45, check=False)
        output = result.stdout.strip()
        if "\n" in output:
            body, status_str = output.rsplit("\n", 1)
            status_code = int(status_str.strip())
        else:
            body = output
            status_code = 0

        # Windows SSPI 回退
        if (status_code == 401 or status_code == 403) and not sspi_mode and platform.system() == "Windows":
            print("  [i] 显式凭据认证失败，尝试 Windows SSPI 回退...")
            result = run_cmd([
                "curl", "-s", "-w", "\n%{http_code}",
                "--connect-timeout", "10", "--max-time", "30",
                "--ntlm", "-u", ":", url
            ], timeout=45, check=False)
            output = result.stdout.strip()
            if "\n" in output:
                body, status_str = output.rsplit("\n", 1)
                status_code = int(status_str.strip())
            else:
                body = output
                status_code = 0

        if status_code == 401 or status_code == 403:
            print("[NEED_CREDENTIALS] 需要 TFS 域账户凭据")
            return []

        if status_code >= 400:
            print(f"[!] API 调用失败(HTTP {status_code})")
            return []

        if not body.strip():
            print("[!] API 返回空响应")
            return []

        data = json.loads(body)
        repos = []
        for repo in data.get("value", []):
            repos.append({
                "name": repo["name"],
                "id": repo["id"],
                "clone_url": repo["remoteUrl"],
                "default_branch": repo.get("defaultBranch", "refs/heads/master"),
            })
        print(f"[OK] 获取到 {len(repos)} 个技能仓库")
        return repos
    except json.JSONDecodeError:
        print("[!] API 返回非 JSON 数据")
        return []
    except FileNotFoundError:
        print("[!] curl 未找到")
        return []
    except Exception as e:
        print(f"[!] API 异常: {e}")
        return []


def load_registry() -> Dict:
    """加载本地 registry.json"""
    registry_path = CONFIG["registry_path"]
    if registry_path.exists():
        return json.loads(registry_path.read_text(encoding="utf-8"))
    return {"skills": [], "updated_at": ""}


def save_registry(registry: Dict):
    """保存 registry.json"""
    CONFIG["cache_root"].mkdir(parents=True, exist_ok=True)
    registry_path = CONFIG["registry_path"]
    registry_path.write_text(
        json.dumps(registry, indent=2, ensure_ascii=False),
        encoding="utf-8"
    )


def refresh_registry(cli_user: str = "", cli_pass: str = "") -> bool:
    """刷新 registry（从 API 获取最新仓库列表）"""
    skill_repos = fetch_repos_from_api(cli_user, cli_pass)

    if not skill_repos:
        has_local_cache = CONFIG["registry_path"].exists()
        if has_local_cache:
            print("[!] API 刷新跳过（使用本地缓存）")
            return False
        else:
            print("[X] 无本地缓存且 API 认证失败，请检查凭据和网络")
            return False

    registry = {
        "skills": skill_repos,
        "updated_at": datetime.now().isoformat(),
    }

    # 附加已缓存的 SKILL.md 元数据
    _enrich_registry_with_local_metadata(registry)

    save_registry(registry)
    print(f"[OK] 已更新 registry，共 {len(skill_repos)} 个技能")
    return True


def _enrich_registry_with_local_metadata(registry: Dict):
    """从已缓存的仓库读取 SKILL.md 元数据，填充到 registry"""
    for repo in registry["skills"]:
        local_path = CONFIG["skills_cache"] / repo["name"]
        if local_path.exists():
            skill_md = local_path / "SKILL.md"
            if skill_md.exists():
                content = skill_md.read_text(encoding="utf-8")
                if content.startswith("---"):
                    parts = content.split("---", 2)
                    if len(parts) >= 3:
                        fm = parts[1]
                        desc_match = re.search(r"^description:\s*(.+)$", fm, re.MULTILINE)
                        if desc_match:
                            repo["description"] = desc_match.group(1).strip()


def is_registry_stale(max_age_hours: int = 24) -> bool:
    """检查 registry 是否过期"""
    registry = load_registry()
    updated_at = registry.get("updated_at", "")
    if not updated_at:
        return True
    try:
        last_update = datetime.fromisoformat(updated_at)
        age = datetime.now() - last_update
        return age.total_seconds() > max_age_hours * 3600
    except (ValueError, TypeError):
        return True


def ensure_registry(force_refresh: bool = False, cli_user: str = "", cli_pass: str = "") -> bool:
    """确保 registry 存在且不过期"""
    if not force_refresh and CONFIG["registry_path"].exists() and not is_registry_stale():
        return True
    return refresh_registry(cli_user, cli_pass)


def update_cached_repos() -> List[str]:
    """更新所有已缓存的仓库（git pull）"""
    changed = []
    skills_cache = CONFIG["skills_cache"]
    if not skills_cache.exists():
        return changed

    for item in skills_cache.iterdir():
        if item.is_dir() and (item / ".git").exists():
            print(f"  更新 {item.name}...")
            try:
                result = run_cmd(["git", "pull"], cwd=item)
                if result.stdout.strip() != "Already up to date.":
                    changed.append(item.name)
            except subprocess.CalledProcessError:
                try:
                    shallow_file = item / ".git" / "shallow"
                    if shallow_file.exists():
                        run_cmd(["git", "fetch", "--unshallow"], cwd=item)
                    run_cmd(["git", "pull"], cwd=item)
                    changed.append(item.name)
                except subprocess.CalledProcessError:
                    print(f"    [!] 更新失败")

    print(f"[OK] 已检查缓存仓库")
    return changed


def update_single_skill(skill_name: str, cli_user: str = "", cli_pass: str = "") -> Dict:
    """更新单个技能（重新 clone 以获取最新版本）

    由于技能安装时删除了 .git 目录（只读模式），更新需要删除缓存后重新 clone。
    """
    result = {"name": skill_name, "updated": False, "error": None}

    repo_path = CONFIG["skills_cache"] / skill_name

    if not repo_path.exists():
        result["error"] = "技能未在缓存中找到"
        print(f"[X] {skill_name}: 未在缓存中找到")
        return result

    # 检查是否有 .git 目录（只读模式安装后不会有）
    if (repo_path / ".git").exists():
        # 有 .git 目录，可以尝试 git pull
        print(f"  更新 {skill_name}（git pull）...")
        try:
            proc = run_cmd(["git", "pull"], cwd=repo_path, check=False, timeout=30)
            output = proc.stdout.strip()

            if output == "Already up to date.":
                result["updated"] = False
                print(f"  [i] {skill_name}: 已是最新版本")
            else:
                result["updated"] = True
                print(f"  [OK] {skill_name}: 已更新")
                if output:
                    print(f"      {output[:100]}")
        except subprocess.CalledProcessError:
            try:
                shallow_file = repo_path / ".git" / "shallow"
                if shallow_file.exists():
                    run_cmd(["git", "fetch", "--unshallow"], cwd=repo_path, timeout=60)
                run_cmd(["git", "pull"], cwd=repo_path, timeout=30)
                result["updated"] = True
                print(f"  [OK] {skill_name}: 已更新（unshallow 后）")
            except subprocess.CalledProcessError as e:
                result["error"] = str(e)
                print(f"  [X] {skill_name}: 更新失败")
        except Exception as e:
            result["error"] = str(e)
            print(f"  [X] {skill_name}: 更新异常 - {e}")
    else:
        # 没有 .git 目录（只读模式），需要删除缓存后重新 clone
        print(f"  更新 {skill_name}（重新 clone）...")
        print(f"      [i] 技能以只读模式安装，需要重新获取最新版本")

        # 从 registry 获取 clone_url
        registry = load_registry()
        skill_info = None
        for s in registry.get("skills", []):
            if s["name"].lower() == skill_name.lower():
                skill_info = s
                break

        if not skill_info:
            result["error"] = "未在 registry 中找到技能信息"
            print(f"      [X] 未找到技能信息，请先运行 --update")
            return result

        # 删除旧缓存
        try:
            shutil.rmtree(repo_path)
            print(f"      [i] 已删除旧缓存")
        except Exception as e:
            result["error"] = f"删除旧缓存失败: {e}"
            print(f"      [X] 删除旧缓存失败: {e}")
            return result

        # 重新 clone
        new_path = ensure_repo_cached(
            skill_info["name"],
            skill_info["clone_url"],
            skill_info.get("default_branch", "refs/heads/master"),
            cli_user, cli_pass,
            0, 0,
            remove_git=True  # 保持只读模式
        )

        if new_path:
            result["updated"] = True
            print(f"  [OK] {skill_name}: 已更新到最新版本")
        else:
            result["error"] = "重新 clone 失败"
            print(f"  [X] {skill_name}: 重新 clone 失败")

    return result


def update_workflow_skills(workflow_name: str = "ai-auto-dev", cli_user: str = "", cli_pass: str = "") -> Dict:
    """更新工作流程中的所有技能"""
    workflow = get_workflow(workflow_name)
    if not workflow:
        print(f"[X] 未找到工作流程: {workflow_name}")
        return {"success": False, "updated": [], "unchanged": [], "failed": [], "not_found": []}

    skills = workflow.get("skills", [])
    if not skills:
        print("[X] 工作流程中没有技能")
        return {"success": False, "updated": [], "unchanged": [], "failed": [], "not_found": []}

    print(f"\n{'='*50}")
    print(f"更新工作流程: {workflow.get('name', workflow_name)}")
    print(f"共 {len(skills)} 个技能")
    print(f"{'='*50}\n")

    updated = []
    unchanged = []
    failed = []
    not_found = []

    for i, skill in enumerate(skills, 1):
        skill_name = skill["name"]
        print(f"[{i}/{len(skills)}] {skill_name}")

        result = update_single_skill(skill_name, cli_user, cli_pass)

        if result["error"] == "技能未在缓存中找到":
            not_found.append(skill_name)
        elif result["error"]:
            failed.append(skill_name)
        elif result["updated"]:
            updated.append(skill_name)
        else:
            unchanged.append(skill_name)

    # 打印汇总
    print(f"\n{'='*50}")
    print("更新完成")
    print(f"{'='*50}")
    print(f"  已更新: {len(updated)} 个")
    print(f"  无变化: {len(unchanged)} 个")
    print(f"  更新失败: {len(failed)} 个")
    print(f"  未找到: {len(not_found)} 个")

    if updated:
        print(f"\n已更新技能:")
        for name in updated:
            print(f"  [OK] {name}")

    if failed:
        print(f"\n更新失败:")
        for name in failed:
            print(f"  [X] {name}")

    if not_found:
        print(f"\n未找到（可能未安装）:")
        for name in not_found:
            print(f"  [?] {name}")

    return {
        "success": len(failed) == 0,
        "updated": updated,
        "unchanged": unchanged,
        "failed": failed,
        "not_found": not_found
    }


def create_symlink(source: Path, target: Path) -> bool:
    """创建符号链接（跨平台）"""
    target.parent.mkdir(parents=True, exist_ok=True)

    if target.exists() or target.is_symlink():
        if target.is_symlink() or target.is_dir():
            if platform.system() == "Windows":
                if target.is_dir() and not target.is_symlink():
                    shutil.rmtree(target)
                else:
                    target.unlink()
            else:
                shutil.rmtree(target)
        else:
            target.unlink()

    try:
        if platform.system() == "Windows":
            source_abs = source.resolve()
            target_abs = target.resolve()
            run_cmd(["cmd", "/c", "mklink", "/J", str(target_abs), str(source_abs)],
                    check=False, shell=True)
            if target.exists():
                return True
            target.symlink_to(source_abs)
        else:
            target.symlink_to(source)
        return True
    except Exception as e:
        print(f"[X] 创建链接失败: {e}")
        return False


def remove_git_metadata(repo_path: Path) -> bool:
    """删除 .git 目录，使技能不可提交（只读）"""
    git_dir = repo_path / ".git"
    if git_dir.exists():
        try:
            if platform.system() == "Windows":
                # Windows 下 .git 是隐藏目录，需要特殊处理
                run_cmd(["cmd", "/c", "attrib", "-h", "-s", str(git_dir)], check=False, timeout=10)
                shutil.rmtree(git_dir)
            else:
                shutil.rmtree(git_dir)
            return True
        except Exception as e:
            print(f"      [!] 删除 .git 失败: {e}")
            return False
    return True  # 已经没有 .git 目录


def ensure_repo_cached(name: str, clone_url: str, branch: str = "master",
                        cli_user: str = "", cli_pass: str = "", index: int = 0, total: int = 0,
                        remove_git: bool = True) -> Optional[Path]:
    """确保单个仓库已缓存，不存在则 clone（带进度显示）- 优化版，减少超时

    Args:
        remove_git: 是否删除 .git 目录（默认 True，使技能只读不可提交）
    """
    repo_path = CONFIG["skills_cache"] / name

    # 检查是否已缓存
    if repo_path.exists() and (repo_path / ".git").exists():
        print(f"  [{index}/{total}] {name}: 已在缓存中，跳过克隆")
        # 已缓存但有 .git 目录，需要删除（如果 remove_git=True）
        if remove_git:
            remove_git_metadata(repo_path)
        return repo_path

    # 已缓存但没有 .git 目录（之前已处理过），直接返回
    if repo_path.exists() and not (repo_path / ".git").exists():
        print(f"  [{index}/{total}] {name}: 已在缓存中（只读模式），跳过克隆")
        return repo_path

    CONFIG["skills_cache"].mkdir(parents=True, exist_ok=True)

    # 显示进度
    progress_hint = f"[{index}/{total}] " if total > 0 else ""
    print(f"  {progress_hint}正在克隆 {name}...")

    try:
        branch_ref = branch.replace("refs/heads/", "")

        # 构建带凭据的 clone URL（如果提供了凭据）
        if cli_user and cli_pass:
            # 将凭据嵌入 URL
            # 格式: http://user:pass@host/path
            import urllib.parse
            encoded_user = urllib.parse.quote(cli_user, safe='')
            encoded_pass = urllib.parse.quote(cli_pass, safe='')
            # 解析原始 URL 并注入凭据
            if clone_url.startswith("http://"):
                auth_url = clone_url.replace("http://", f"http://{encoded_user}:{encoded_pass}@")
            else:
                auth_url = clone_url

            # 使用带凭据的 URL，减少超时到60秒
            run_cmd([
                "git", "clone",
                "--branch", branch_ref,
                "--depth", "1",
                "--progress",
                auth_url,
                str(repo_path)
            ], timeout=60)
        else:
            # 无凭据时尝试使用系统凭据
            print(f"      提示: 使用系统凭据/本地缓存")
            run_cmd([
                "git", "clone",
                "--branch", branch_ref,
                "--depth", "1",
                "--progress",
                clone_url,
                str(repo_path)
            ], timeout=60)

        print(f"      [OK] 克隆成功")

        # 删除 .git 目录，使技能只读不可提交
        if remove_git:
            if remove_git_metadata(repo_path):
                print(f"      [i] 已移除 git 元数据（只读模式）")

        return repo_path
    except subprocess.CalledProcessError as e:
        print(f"      [X] 克隆失败: {e.stderr if e.stderr else '未知错误'}")
        return None
    except subprocess.TimeoutExpired:
        print(f"      [X] 克隆超时（超过60秒）")
        return None
    except Exception as e:
        print(f"      [X] 克隆异常: {e}")
        return None


def parallel_clone_skills(skills: List[Dict], cli_user: str = "", cli_pass: str = "",
                          max_workers: int = 4, remove_git: bool = True) -> Dict[str, Optional[Path]]:
    """并行克隆多个技能仓库（性能优化）

    Args:
        remove_git: 是否删除 .git 目录（默认 True，使技能只读不可提交）
    """
    results = {}
    total = len(skills)

    print(f"\n[并行克隆] 开始并行克隆 {total} 个技能（最多 {max_workers} 个并发）...")
    if remove_git:
        print("[i] 技能将以只读模式安装（无法提交修改）")

    # 过滤已缓存的技能
    need_clone = []
    for skill in skills:
        name = skill["name"]
        repo_path = CONFIG["skills_cache"] / name
        if repo_path.exists():
            # 已缓存，检查是否有 .git 目录需要删除
            if (repo_path / ".git").exists() and remove_git:
                print(f"  [{skill.get('_index', 0)}/{total}] {name}: 已在缓存中，移除 git 元数据")
                remove_git_metadata(repo_path)
                results[name] = repo_path
            elif (repo_path / ".git").exists() and not remove_git:
                print(f"  [{skill.get('_index', 0)}/{total}] {name}: 已在缓存中，跳过")
                results[name] = repo_path
            else:
                # 没有 .git 目录，说明之前已处理过
                print(f"  [{skill.get('_index', 0)}/{total}] {name}: 已在缓存中（只读模式），跳过")
                results[name] = repo_path
        else:
            need_clone.append(skill)

    if not need_clone:
        print("[并行克隆] 所有技能已在缓存中")
        return results

    # 并行克隆
    with ThreadPoolExecutor(max_workers=max_workers) as executor:
        futures = {}
        for skill in need_clone:
            name = skill["name"]
            clone_url = skill["clone_url"]
            branch = skill.get("default_branch", "refs/heads/master")
            index = skill.get("_index", 0)

            # 使用 lambda 包装以传递 remove_git 参数
            future = executor.submit(
                lambda n, u, b, cu, cp, i, t, rg: ensure_repo_cached(n, u, b, cu, cp, i, t, rg),
                name, clone_url, branch,
                cli_user, cli_pass,
                index, total,
                remove_git
            )
            futures[future] = name

        for future in as_completed(futures):
            name = futures[future]
            try:
                result = future.result()
                results[name] = result
            except Exception as e:
                print(f"  [X] {name}: 克隆异常 - {e}")
                results[name] = None

    return results


def install_skill(skill_name: str, location: str = "global",
                   cli_user: str = "", cli_pass: str = "",
                   index: int = 0, total: int = 0) -> bool:
    """安装技能（clone + 符号链接）"""
    registry = load_registry()

    # 从 registry 查找
    skill_info = None
    for s in registry.get("skills", []):
        if s["name"].lower() == skill_name.lower():
            skill_info = s
            break

    if not skill_info:
        # 模糊匹配
        for s in registry.get("skills", []):
            if skill_name.lower() in s["name"].lower():
                skill_info = s
                break

    if not skill_info:
        print(f"[X] 未找到技能: {skill_name}")
        return False

    # clone 到缓存（带凭据和进度）
    repo_path = ensure_repo_cached(
        skill_info["name"],
        skill_info["clone_url"],
        skill_info.get("default_branch", "refs/heads/master"),
        cli_user=cli_user,
        cli_pass=cli_pass,
        index=index,
        total=total
    )

    if not repo_path:
        return False

    # 确定目标目录
    target_dir = get_skills_target_dir(location)
    target_path = target_dir / skill_info["name"]

    # 显示安装信息（仅在单独安装时）
    if total == 0:
        print(f"安装: {skill_info['name']}")
        print(f"  源: {repo_path}")
        print(f"  目标: {target_path}")

    if create_symlink(repo_path, target_path):
        if total == 0:
            print(f"[OK] 已安装 {skill_info['name']}")
        return True
    return False


def get_project_root() -> Path:
    """获取当前项目根目录（检测 git 仓库）"""
    current = Path.cwd()
    while current != current.parent:
        if (current / ".git").exists():
            return current
        current = current.parent
    return Path.cwd()


def get_skills_target_dir(location: str) -> Path:
    """获取技能安装目标目录"""
    if location == "global":
        return GLOBAL_SKILLS_DIR
    else:
        return get_project_root() / ".claude" / "skills"


def get_tfs_config_path() -> Path:
    """获取 TFS 配置文件路径"""
    # 先检测项目目录
    project_config = get_project_root() / ".claude" / "skills" / "ai-tfs-integration" / "config" / "tfs-config.json"
    if project_config.exists():
        return project_config
    return GLOBAL_SKILLS_DIR / "ai-tfs-integration" / "config" / "tfs-config.json"


def write_tfs_config(pat: str, collection: str) -> bool:
    """写入 TFS 配置文件"""
    config_path = get_tfs_config_path()
    config_dir = config_path.parent
    config_dir.mkdir(parents=True, exist_ok=True)

    config = {
        "serverUrl": f"{TFS_SERVER_URL}/{collection}",
        "pat": pat,
        "defaultCollection": collection
    }

    with open(config_path, "w", encoding="utf-8") as f:
        json.dump(config, f, indent=2, ensure_ascii=False)

    print(f"[OK] TFS 配置已写入: {config_path}")
    print(f"     集合: {collection}")
    return True


def check_tfs_config_exists() -> bool:
    """检查 TFS 配置文件是否存在且有效"""
    config_path = get_tfs_config_path()
    if not config_path.exists():
        return False
    try:
        config = json.loads(config_path.read_text(encoding="utf-8"))
        return bool(config.get("pat") and config.get("defaultCollection"))
    except (json.JSONDecodeError, KeyError):
        return False


def check_nodejs_version() -> Dict:
    """检查 Node.js 版本是否满足要求（>= 18）"""
    result = {"installed": False, "version": "", "satisfied": False}

    try:
        proc = run_cmd(["node", "--version"], check=False, timeout=10)
        if proc.returncode == 0:
            version_str = proc.stdout.strip()
            # 版本格式: v18.x.x 或 v20.x.x
            match = re.match(r"v(\d+)", version_str)
            if match:
                major_version = int(match.group(1))
                result["installed"] = True
                result["version"] = version_str
                result["satisfied"] = major_version >= 18
                if result["satisfied"]:
                    print(f"[NODEJS_OK] Node.js 版本满足要求: {version_str}")
                else:
                    print(f"[NODEJS_VERSION_LOW] Node.js 版本过低: {version_str}，需要 >= 18")
            else:
                print(f"[NODEJS_VERSION_UNKNOWN] 无法解析 Node.js 版本: {version_str}")
        else:
            print("[NODEJS_MISSING] Node.js 未安装")
    except FileNotFoundError:
        print("[NODEJS_MISSING] Node.js 未安装")
    except Exception as e:
        print(f"[NODEJS_ERROR] Node.js 检查异常: {e}")

    return result


def check_gitnexus_installed() -> Dict:
    """检查 GitNexus 是否已安装"""
    result = {"installed": False, "version": ""}

    try:
        # 检查 npm 全局安装状态
        proc = run_cmd(["npm", "list", "-g", "gitnexus"], check=False, timeout=30)
        output = proc.stdout.strip()

        if "gitnexus@" in output:
            # 解析版本号
            match = re.search(r"gitnexus@(\d+\.\d+\.\d+)", output)
            if match:
                result["installed"] = True
                result["version"] = match.group(1)
                print(f"[GITNEXUS_INSTALLED] GitNexus 已安装: v{result['version']}")
            else:
                result["installed"] = True
                print("[GITNEXUS_INSTALLED] GitNexus 已安装")
        else:
            # 也尝试直接运行 gitnexus --version
            proc2 = run_cmd(["gitnexus", "--version"], check=False, timeout=10)
            if proc2.returncode == 0:
                result["installed"] = True
                result["version"] = proc2.stdout.strip()
                print(f"[GITNEXUS_INSTALLED] GitNexus 已安装: {result['version']}")
            else:
                print("[GITNEXUS_NOT_INSTALLED] GitNexus 未安装")
    except FileNotFoundError:
        print("[GITNEXUS_NOT_INSTALLED] GitNexus 未安装（npm 未找到）")
    except Exception as e:
        print(f"[GITNEXUS_ERROR] GitNexus 检查异常: {e}")

    return result


def check_gitnexus_setup_done() -> Dict:
    """检查 gitnexus setup 是否已执行（检查配置文件是否存在）"""
    result = {"done": False, "config_path": ""}

    # GitNexus 配置文件位置：
    # - Windows: ~/.gitnexus/config.json 或 %APPDATA%/gitnexus/config.json
    # - Linux/Mac: ~/.gitnexus/config.json
    config_locations = [
        Path.home() / ".gitnexus" / "config.json",
        Path.home() / ".config" / "gitnexus" / "config.json",
        Path(os.environ.get("APPDATA", "")) / "gitnexus" / "config.json" if os.environ.get("APPDATA") else None,
    ]

    for config_path in config_locations:
        if config_path and config_path.exists():
            try:
                config = json.loads(config_path.read_text(encoding="utf-8"))
                # 检查是否有有效配置（至少包含一些基本字段）
                if config and len(config) > 0:
                    result["done"] = True
                    result["config_path"] = str(config_path)
                    print(f"[GITNEXUS_SETUP_DONE] GitNexus 已配置: {config_path}")
                    return result
            except (json.JSONDecodeError, Exception):
                continue

    print("[GITNEXUS_SETUP_PENDING] GitNexus setup 未执行")
    return result


def check_gitnexus_analyze_done() -> Dict:
    """检查 gitnexus analyze 是否已执行（检查项目索引状态）"""
    result = {"done": False, "indexed_repos": [], "project_indexed": False}

    project_root = get_project_root()

    # GitNexus 索引数据位置：
    # - ~/.gitnexus/data/ 或 ~/.local/share/gitnexus/
    data_locations = [
        Path.home() / ".gitnexus" / "data",
        Path.home() / ".local" / "share" / "gitnexus",
        Path(os.environ.get("LOCALAPPDATA", "")) / "gitnexus" / "data" if os.environ.get("LOCALAPPDATA") else None,
    ]

    for data_path in data_locations:
        if data_path and data_path.exists():
            # 检查是否有索引数据
            try:
                # 索引文件可能是 .db, .json, 或 repos 目录
                index_files = list(data_path.glob("*.db")) + list(data_path.glob("*.json"))
                if (data_path / "repos").exists():
                    index_files.extend([(data_path / "repos")])

                if index_files:
                    result["done"] = True

                    # 检查当前项目是否已索引
                    # 尝试通过 gitnexus status 命令检查
                    try:
                        proc = run_cmd(["gitnexus", "status"], cwd=project_root, check=False, timeout=30)
                        if proc.returncode == 0:
                            output = proc.stdout.strip()
                            # 检查输出是否包含 "indexed" 或项目路径
                            if "indexed" in output.lower() or str(project_root) in output:
                                result["project_indexed"] = True
                                print(f"[GITNEXUS_ANALYZE_DONE] 项目已索引: {project_root}")
                            else:
                                print(f"[GITNEXUS_ANALYZE_PENDING] 项目未索引，需要执行 gitnexus analyze")
                        else:
                            # status 命令失败，但有索引数据，假设需要重新索引
                            print(f"[GITNEXUS_ANALYZE_PENDING] 项目索引状态未知，建议执行 gitnexus analyze")
                    except Exception:
                        print(f"[GITNEXUS_ANALYZE_PENDING] 无法检查索引状态，建议执行 gitnexus analyze")

                    return result
            except Exception:
                continue

    print("[GITNEXUS_ANALYZE_PENDING] GitNexus analyze 未执行")
    return result


def install_gitnexus() -> bool:
    """安装 GitNexus（npm 全局安装）

    使用 Popen 流式输出，实时显示 npm 下载进度。
    超时 300s，适配 280+ 包的实际耗时。
    """
    import threading

    print("正在安装 GitNexus...")
    print("  预计下载约 280 个包，耗时 2-5 分钟")
    print("  (首次使用需下载嵌入模型，在 gitnexus analyze 时完成)")
    print()

    start_time = time.time()
    last_output_time = [start_time]  # 用列表以便在闭包中修改
    last_line = [""]
    line_count = [0]

    # 进度心跳：npm 无输出超过 30s 时提示
    stop_progress = threading.Event()

    def progress_heartbeat():
        while not stop_progress.is_set():
            stop_progress.wait(30)
            if not stop_progress.is_set():
                elapsed = int(time.time() - start_time)
                silent = int(time.time() - last_output_time[0])
                if silent >= 30:
                    print(f"  ... 仍在安装 (已耗时 {elapsed}s, 已输出 {line_count[0]} 行) ...")

    heartbeat_thread = threading.Thread(target=progress_heartbeat, daemon=True)
    heartbeat_thread.start()

    # 用 Popen 流式读取，实时显示 npm 输出
    npm_cmd = ["npm", "install", "-g", "gitnexus", "--no-audit", "--no-fund"]
    # Windows 下 Popen 也需要 shell=True 来处理路径
    use_shell = sys.platform == "win32"

    try:
        process = subprocess.Popen(
            npm_cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            shell=use_shell,
            bufsize=1,
        )

        returncode = None
        deadline = time.time() + 300

        while returncode is None:
            # 检查超时
            if time.time() > deadline:
                process.kill()
                stop_progress.set()
                heartbeat_thread.join(timeout=1)
                print(f"\n[X] GitNexus 安装超时 (>300s)，请检查网络或手动安装:")
                print("    npm install -g gitnexus --registry https://registry.npmjs.org/")
                return False

            # 读取一行输出（非阻塞轮询）
            line = None
            if process.stdout and hasattr(process.stdout, 'readline'):
                try:
                    line_bytes = process.stdout.readline()
                    if line_bytes:
                        line = _decode_output(line_bytes).rstrip()
                except Exception:
                    pass

            if line:
                last_output_time[0] = time.time()
                line_count[0] += 1
                # npm 输出行：跳过纯空行，缩进显示有意义的内容
                if line.strip():
                    print(f"  {line.strip()}")
                last_line[0] = line
                # 统计包数：npm 会在最后输出 "added N packages"
                if "added" in line and "packages" in line:
                    pass  # 最终汇总行，正常打印
            else:
                returncode = process.poll()
                if returncode is None:
                    time.sleep(0.1)  # 无输出时短暂休眠，避免忙轮询

        stop_progress.set()
        heartbeat_thread.join(timeout=1)

        elapsed = int(time.time() - start_time)
        if returncode == 0:
            print(f"\n[OK] GitNexus 安装成功 (耗时 {elapsed}s, 输出 {line_count[0]} 行)")
            check_result = check_gitnexus_installed()
            return check_result["installed"]
        else:
            print(f"\n[X] GitNexus 安装失败 (耗时 {elapsed}s, 返回码 {returncode})")
            return False

    except FileNotFoundError:
        stop_progress.set()
        print("[X] npm 未找到，请确认 Node.js 已安装")
        return False
    except Exception as e:
        stop_progress.set()
        print(f"[X] GitNexus 安装异常: {e}")
        return False


def run_gitnexus_setup() -> bool:
    """执行 gitnexus setup 配置"""
    print("正在执行 gitnexus setup...")

    try:
        proc = run_cmd(["gitnexus", "setup"], check=False, timeout=60)
        if proc.returncode == 0:
            print("[OK] GitNexus 配置完成")
            return True
        else:
            print(f"[X] gitnexus setup 执行失败: {proc.stderr}")
            return False
    except FileNotFoundError:
        print("[X] gitnexus 命令未找到，请先安装 GitNexus")
        return False
    except Exception as e:
        print(f"[X] gitnexus setup 执行异常: {e}")
        return False


def run_gitnexus_analyze() -> bool:
    """执行 gitnexus analyze 索引项目"""
    print("正在执行 gitnexus analyze...")
    print("提示：首次执行会下载嵌入模型，可能需要几分钟...")

    project_root = get_project_root()

    try:
        # gitnexus analyze 可能需要较长时间（下载模型+分析）
        proc = run_cmd(["gitnexus", "analyze"], cwd=project_root, check=False, timeout=600)
        if proc.returncode == 0:
            print("[OK] GitNexus 项目索引完成")
            return True
        else:
            print(f"[X] gitnexus analyze 执行失败: {proc.stderr}")
            return False
    except FileNotFoundError:
        print("[X] gitnexus 命令未找到，请先安装 GitNexus")
        return False
    except subprocess.TimeoutExpired:
        print("[X] gitnexus analyze 执行超时（超过600秒）")
        return False
    except Exception as e:
        print(f"[X] gitnexus analyze 执行异常: {e}")
        return False


def generate_guide_document(location: str = "global") -> Path:
    """生成自动化研发流程使用指南文档"""
    target_dir = get_skills_target_dir(location)
    guide_path = target_dir / "全自动化研发.md"

    guide_content = '''# AI 自动化研发流程使用指南

本指南帮助你快速上手 AI 事业部多 Agent 编排体系的自动化研发流程。

## 快速开始

### 1. 准备需求

在 Claude Code 中输入需求编号或需求描述：

```
开发需求 12345
```

或：

```
我有一个新功能需求：病人床头卡显示优化
```

系统会自动触发 **ai-auto-dev** 主调度技能，启动完整研发流程。

## 研发流程阶段

整个自动化研发流程包含以下阶段：

| 阶段 | 触发技能 | 输入 | 输出 |
|------|----------|------|------|
| 需求分析 | ai-prd-auto | 自然语言需求 | PRD 文档 |
| 架构设计 | ai-architecture-design | PRD 文档 | 架构设计、数据库模型、API规范 |
| 后端开发 | ai-backend-dev-pro | 架构设计 | Java/Spring Boot 代码 |
| 前端开发 | ai-frontend-dev-pro | 架构设计 | Vue.js 代码 |
| 代码审查 | ai-code-review-agent | 代码 | 审查报告 |
| 自动化测试 | ai-automated-test-agent | 代码 | 测试用例 |
| 代码提交 | ai-git-push | 审查通过的代码 | Git 提交 |
| 分支合并 | ai-git-merge | 功能分支 | 合并到主分支 |

## 单阶段使用

你也可以单独使用某个阶段的技能：

### 需求分析

```
分析需求 12345
```

输出：`DOCS/PRD/需求12345.md`

### 架构设计

```
根据 DOCS/PRD/需求12345.md 进行架构设计
```

输出：`DOCS/ARCH/架构设计.md`

### 后端开发

```
根据架构设计开发后端接口
```

输出：Java/Spring Boot 代码

### 前端开发

```
根据架构设计开发前端页面
```

输出：Vue.js 代码

### 代码审查

```
审查本次代码修改
```

输出：审查报告

### 自动化测试

```
生成测试用例
```

输出：单元测试、接口测试代码

### 代码提交

```
提交代码
```

输出：Git commit + push

### 分支合并

```
合并分支到主分支
```

输出：Git merge

## TFS 工作项操作

### 创建工作项

```
创建需求工作项：病人床头卡优化
```

### 查看工作项

```
查看需求 12345 的详情
```

### 更新工作项状态

```
将需求 12345 状态改为"开发中"
```

## GitNexus 核心命令

GitNexus 是一个代码库智能索引工具，通过嵌入模型为 AI 提供代码语义搜索能力。

### 前置要求

- Node.js 18+ 环境
- npm 全局安装 gitnexus

### 核心命令

| 命令 | 说明 | 使用场景 |
|------|------|----------|
| `gitnexus setup` | 初始化 GitNexus 配置 | 安装后首次执行 |
| `gitnexus analyze` | 索引当前项目代码库 | 分析项目、理解代码结构 |
| `gitnexus search <query>` | 语义搜索代码 | 查找相关代码片段 |
| `gitnexus status` | 查看索引状态 | 检查索引是否完成 |
| `gitnexus update` | 更新项目索引 | 代码变更后更新索引 |

### 使用示例

#### 初始化配置

```bash
# 安装完成后执行
gitnexus setup
```

#### 索引项目

```bash
# 在项目根目录执行
gitnexus analyze
```

首次执行会自动下载嵌入模型，请耐心等待。

#### 语义搜索

```bash
# 搜索病人管理相关代码
gitnexus search "病人管理"

# 搜索医嘱处理逻辑
gitnexus search "医嘱处理流程"
```

#### 查看状态

```bash
# 查看索引状态
gitnexus status
```

### 与 AI 协作

GitNexus 索引完成后，AI 可以：
- 通过语义搜索快速定位相关代码
- 理解代码库结构和模块关系
- 提供更精准的代码建议

建议在开始新需求开发前先执行 `gitnexus analyze` 索引项目。

## 最佳实践

### 1. 需求编号规范

使用 TFS 需求编号触发完整流程：

```
开发需求 <TFS需求编号>
```

### 2. 分阶段确认

在每个阶段完成后检查输出：

- PRD 文档 → 确认需求理解正确
- 架构设计 → 确认技术方案可行
- 代码生成 → 确认符合预期

### 3. 代码审查

提交前必须通过代码审查：

```
审查本次修改后提交代码
```

### 4. 测试覆盖

关键业务逻辑需要测试覆盖：

```
为病人管理模块生成测试用例
```

### 5. GitNexus 索引

大型项目建议定期更新索引：

```bash
# 代码变更后更新索引
gitnexus update
```

## 常用命令速查

| 场景 | 命令示例 |
|------|----------|
| 完整流程 | `开发需求 12345` |
| 需求分析 | `分析需求 12345` |
| 架构设计 | `进行架构设计` |
| 后端开发 | `开发后端接口` |
| 前端开发 | `开发前端页面` |
| 代码审查 | `审查代码` |
| 测试生成 | `生成测试用例` |
| 代码提交 | `提交代码` |
| 分支合并 | `合并分支` |
| GitNexus索引 | `gitnexus analyze` |
| GitNexus搜索 | `gitnexus search <关键词>` |

## 注意事项

1. **需求编号必须准确**：使用真实的 TFS 需求编号
2. **阶段输出检查**：每个阶段完成后确认输出质量
3. **代码审查优先**：提交前必须审查
4. **测试覆盖关键**：业务逻辑需要测试保障
5. **GitNexus 模型下载**：首次 analyze 需下载模型，请耐心等待

## 技能清单

已安装的自动化研发技能：

- `ai-auto-dev` - 主调度
- `ai-prd-auto` - 需求分析
- `ai-architecture-design` - 架构设计
- `ai-backend-dev-pro` - 后端开发
- `ai-frontend-dev-pro` - 前端开发
- `ai-code-review-agent` - 代码审查
- `ai-automated-test-agent` - 自动化测试
- `ai-git-push` - 代码提交
- `ai-git-merge` - 分支合并
- `ai-tfs-integration` - TFS 集成

> 项目知识库（`ICIS-knowledge.md` + 6 个架构规范文件）由 `ai-architecture-design` 步骤 0 自动生成，无需单独技能。

---

*本指南由 ai-auto-dev-setup 自动生成*
'''

    guide_path.parent.mkdir(parents=True, exist_ok=True)
    guide_path.write_text(guide_content, encoding="utf-8")

    print(f"[OK] 使用指南已生成: {guide_path}")
    return guide_path


def load_manifest() -> Dict:
    """加载清单配置文件"""
    script_dir = Path(__file__).resolve().parent
    manifest_path = script_dir.parent / "references" / "manifest.yaml"

    if not manifest_path.exists():
        print(f"[X] 清单文件不存在: {manifest_path}")
        return {}

    if not _HAS_YAML:
        print("[!] 需要安装 PyYAML: pip install pyyaml")
        return {}

    with open(manifest_path, "r", encoding="utf-8") as f:
        return yaml.safe_load(f)


def get_workflow(workflow_name: str) -> Optional[Dict]:
    """获取指定工作流程的配置"""
    manifest = load_manifest()
    if not manifest:
        return None
    workflows = manifest.get("workflows", {})
    return workflows.get(workflow_name)


def install_workflow(workflow_name: str, location: str = "global",
                     cli_user: str = "", cli_pass: str = "") -> Dict:
    """安装整个工作流程（性能优化版：并行克隆）"""
    workflow = get_workflow(workflow_name)
    if not workflow:
        print(f"[X] 未找到工作流程: {workflow_name}")
        return {"success": False, "installed": [], "failed": [], "needs_config": [], "reason": "workflow_not_found"}

    print(f"\n{'='*50}")
    print(f"安装工作流程: {workflow.get('name', workflow_name)}")
    print(f"{'='*50}\n")

    skills = workflow.get("skills", [])
    total_skills = len(skills)

    # 凭据验证检查
    username, password = get_git_credentials(cli_user, cli_pass)
    if not username and not password and platform.system() != "Windows":
        print("[CREDENTIALS_REQUIRED] 需要 TFS 域账户凭据")
        print("  请通过 Claude Code AskUserQuestion 提供:")
        print("  - TFS 域用户名 (如 domain\\username)")
        print("  - TFS 域密码")
        return {"success": False, "installed": [], "failed": [], "needs_config": [], "reason": "missing_credentials"}
    elif not username and not password:
        print("[INFO] 将尝试使用 Windows SSPI 认证")

    # 从 registry 获取技能信息
    registry = load_registry()
    if not registry.get("skills"):
        print("[!] Registry 为空，请先运行 --update")
        return {"success": False, "installed": [], "failed": [], "needs_config": [], "reason": "empty_registry"}

    # 准备克隆任务
    clone_tasks = []
    for i, skill in enumerate(skills, 1):
        skill_name = skill["name"]
        skill_info = None
        for s in registry.get("skills", []):
            if s["name"].lower() == skill_name.lower():
                skill_info = s
                break
        if skill_info:
            skill_info["_index"] = i
            clone_tasks.append(skill_info)

    # 并行克隆（删除 .git 使技能只读）
    clone_results = parallel_clone_skills(clone_tasks, cli_user, cli_pass, max_workers=4, remove_git=True)

    # 创建符号链接并记录结果
    installed = []
    failed = []
    needs_config = []
    target_dir = get_skills_target_dir(location)

    for i, skill in enumerate(skills, 1):
        skill_name = skill["name"]
        skill_needs_config = skill.get("needs_config", False)
        required = skill.get("required", True)

        repo_path = clone_results.get(skill_name)
        if not repo_path:
            failed.append(skill_name)
            if required:
                print(f"  [!] 必需技能 {skill_name} 安装失败")
            continue

        target_path = target_dir / skill_name
        if create_symlink(repo_path, target_path):
            installed.append(skill_name)
            if skill_needs_config:
                needs_config.append(skill_name)
            print(f"  [{i}/{total_skills}] {skill_name}: 已安装")
        else:
            failed.append(skill_name)
            if required:
                print(f"  [!] 必需技能 {skill_name} 符号链接创建失败")

    print(f"\n{'='*50}")
    print(f"安装完成")
    print(f"{'='*50}")
    print(f"  成功: {len(installed)} 个")
    print(f"  失败: {len(failed)} 个")
    print(f"  需配置: {len(needs_config)} 个")

    if failed:
        print(f"\n失败列表:")
        for name in failed:
            print(f"  - {name}")

    if needs_config:
        print(f"\n需配置技能:")
        for name in needs_config:
            print(f"  - {name}")

    # 安装成功后生成引导文档
    if len(failed) == 0:
        print(f"\n{'='*50}")
        print("生成使用指南...")
        print(f"{'='*50}")
        generate_guide_document(location)

        # 安装成功后执行 GitNexus 安装流程
        print(f"\n{'='*50}")
        print("GitNexus 安装与配置...")
        print(f"{'='*50}")

        # 检查 Node.js 环境
        nodejs_result = check_nodejs_version()
        if not nodejs_result["satisfied"]:
            print("[!] Node.js 环境不满足，需要 Node.js 18+")
            print("    请手动安装 Node.js 后再执行 GitNexus 安装")
            return {
                "success": True,
                "installed": installed,
                "failed": failed,
                "needs_config": needs_config,
                "gitnexus_installed": False,
                "gitnexus_reason": "nodejs_not_satisfied"
            }

        # 检查 GitNexus 是否已安装
        gitnexus_result = check_gitnexus_installed()
        if gitnexus_result["installed"]:
            print("[i] GitNexus 已安装，跳过安装步骤")
        else:
            # 安装 GitNexus
            if not install_gitnexus():
                print("[!] GitNexus 安装失败")
                return {
                    "success": True,
                    "installed": installed,
                    "failed": failed,
                    "needs_config": needs_config,
                    "gitnexus_installed": False,
                    "gitnexus_reason": "install_failed"
                }

        # 检查并执行 gitnexus setup（自动判断是否已执行）
        setup_result = check_gitnexus_setup_done()
        if setup_result["done"]:
            print(f"[i] GitNexus setup 已执行，跳过配置步骤")
        else:
            if not run_gitnexus_setup():
                print("[!] gitnexus setup 执行失败")
                return {
                    "success": True,
                    "installed": installed,
                    "failed": failed,
                    "needs_config": needs_config,
                    "gitnexus_installed": True,
                    "gitnexus_setup": False
                }

        # 检查并执行 gitnexus analyze（自动判断项目是否已索引）
        analyze_result = check_gitnexus_analyze_done()
        if analyze_result["project_indexed"]:
            print(f"[i] 项目已索引，跳过 analyze 步骤")
        else:
            print("\n[i] GitNexus 正在索引项目...")
            print("    注意：首次执行会下载嵌入模型，可能需要几分钟")
            if not run_gitnexus_analyze():
                print("[!] gitnexus analyze 执行失败，但不影响技能安装")
                print("    可稍后手动执行: python ~/.claude/skills/ai-auto-dev-setup/scripts/main.py --gitnexus-analyze")
                return {
                    "success": True,
                    "installed": installed,
                    "failed": failed,
                    "needs_config": needs_config,
                    "gitnexus_installed": True,
                    "gitnexus_setup": True,
                    "gitnexus_analyzed": False
                }

        # 输出继续执行标记（告知模型继续执行 SKILL.md 步骤 6）
        print(f"\n{'='*50}")
        print("[SCRIPT_COMPLETE] 脚本执行完毕，安装阶段完成")
        print("[CONTINUE_TO_SKILL_STEP_6] 请继续执行 SKILL.md 步骤 6：安装结果确认")
        print("[SKILL_STEP_SEQUENCE] 步骤 6 → 步骤 7 → 步骤 8 必须按顺序执行")
        print(f"{'='*50}")

    return {
        "success": len(failed) == 0,
        "installed": installed,
        "failed": failed,
        "needs_config": needs_config,
        "gitnexus_installed": True if len(failed) == 0 else False,
        "gitnexus_setup": True if len(failed) == 0 else False,
        "gitnexus_analyzed": True if len(failed) == 0 else False
    }


def list_workflow(workflow_name: str = None):
    """列出工作流程及其内容"""
    manifest = load_manifest()
    if not manifest:
        return

    workflows = manifest.get("workflows", {})

    if workflow_name:
        workflow = workflows.get(workflow_name)
        if workflow:
            print(f"\n工作流程: {workflow.get('name', workflow_name)}")
            if workflow.get("description"):
                print(f"  {workflow['description']}\n")

            print("技能列表:")
            for i, skill in enumerate(workflow.get("skills", []), 1):
                status = "必需" if skill.get("required", True) else "可选"
                config_status = "需配置" if skill.get("needs_config", False) else ""
                print(f"  {i}. {skill['name']} [{status}] {config_status}")
                if skill.get("description"):
                    print(f"     {skill['description']}")
        else:
            print(f"[X] 未找到工作流程: {workflow_name}")
    else:
        print("\n可用工作流程:")
        for name, workflow in workflows.items():
            print(f"  - {name}: {workflow.get('name', name)}")
            skills_count = len(workflow.get("skills", []))
            print(f"    ({skills_count} 技能)")


def list_skills():
    """列出所有可用技能"""
    registry = load_registry()
    skills = registry.get("skills", [])
    if not skills:
        print("没有找到技能，请先运行 --update 更新缓存")
        return
    print(f"\n共 {len(skills)} 个技能:\n")
    for i, skill in enumerate(skills, 1):
        desc = skill.get('description', '')
        if desc:
            print(f"  {i}. {skill['name']} - {desc}")
        else:
            print(f"  {i}. {skill['name']}")


def main():
    parser = argparse.ArgumentParser(description="AIAutoDevSetup - AI事业部技能安装工具")

    # 工作流程操作
    parser.add_argument("--workflow", "-w", metavar="NAME", help="安装指定工作流程")
    parser.add_argument("--list-workflow", "-lw", action="store_true", help="列出可用工作流程")
    parser.add_argument("--location", "-l", choices=["global", "project"], default="global",
                        help="安装位置: global(全局) 或 project(项目级)")

    # 单独安装
    parser.add_argument("--skill", "-s", metavar="NAME", help="单独安装技能")
    parser.add_argument("--list", action="store_true", help="列出所有可用技能")

    # 缓存更新
    parser.add_argument("--update", "-u", action="store_true", help="更新 registry 和缓存")

    # 凭据参数
    parser.add_argument("--cred-user", metavar="USER", help="TFS 域用户名")
    parser.add_argument("--cred-pass", metavar="PASS", help="TFS 域密码")

    # TFS 配置
    parser.add_argument("--write-tfs-config", action="store_true", help="写入 TFS 配置")
    parser.add_argument("--pat", metavar="TOKEN", help="TFS 个人访问令牌")
    parser.add_argument("--collection", metavar="COLL", help="TFS 集合名称")
    parser.add_argument("--check-tfs-config", action="store_true", help="检查 TFS 配置是否存在")

    # GitNexus 相关
    parser.add_argument("--check-nodejs", action="store_true", help="检查 Node.js 版本是否满足要求")
    parser.add_argument("--check-gitnexus", action="store_true", help="检查 GitNexus 是否已安装")
    parser.add_argument("--check-gitnexus-setup", action="store_true", help="检查 gitnexus setup 是否已执行")
    parser.add_argument("--check-gitnexus-analyze", action="store_true", help="检查项目是否已索引")
    parser.add_argument("--install-gitnexus", action="store_true", help="安装 GitNexus（npm 全局安装）")
    parser.add_argument("--gitnexus-setup", action="store_true", help="执行 gitnexus setup 配置")
    parser.add_argument("--gitnexus-analyze", action="store_true", help="执行 gitnexus analyze 索引项目")

    # 技能更新相关
    parser.add_argument("--update-skills", "-us", action="store_true",
                        help="更新工作流程中的所有技能（git pull）")
    parser.add_argument("--update-workflow", metavar="NAME", default="ai-auto-dev",
                        help="指定要更新的工作流程名称（默认 ai-auto-dev）")
    parser.add_argument("--update-skill", metavar="NAME",
                        help="更新单个技能（git pull）")

    args = parser.parse_args()

    cli_user = getattr(args, "cred_user", "") or ""
    cli_pass = getattr(args, "cred_pass", "") or ""

    # 更新缓存
    if args.update:
        refresh_registry(cli_user, cli_pass)
        print("\n正在更新已缓存的仓库...")
        update_cached_repos()
        return 0

    # 列出技能
    if args.list:
        list_skills()
        return 0

    # 列出工作流程
    if args.list_workflow:
        list_workflow()
        return 0

    # 写入 TFS 配置
    if args.write_tfs_config:
        if not args.pat or not args.collection:
            print("[X] 需要提供 --pat 和 --collection 参数")
            return 1
        success = write_tfs_config(args.pat, args.collection)
        return 0 if success else 1

    # 检查 TFS 配置
    if args.check_tfs_config:
        exists = check_tfs_config_exists()
        print(f"TFS 配置状态: {'已配置' if exists else '未配置'}")
        return 0 if exists else 1

    # 检查 Node.js
    if args.check_nodejs:
        result = check_nodejs_version()
        return 0 if result["satisfied"] else 1

    # 检查 GitNexus
    if args.check_gitnexus:
        result = check_gitnexus_installed()
        return 0 if result["installed"] else 1

    # 检查 GitNexus setup 状态
    if args.check_gitnexus_setup:
        result = check_gitnexus_setup_done()
        return 0 if result["done"] else 1

    # 检查 GitNexus analyze 状态
    if args.check_gitnexus_analyze:
        result = check_gitnexus_analyze_done()
        return 0 if result["project_indexed"] else 1

    # 安装 GitNexus
    if args.install_gitnexus:
        success = install_gitnexus()
        return 0 if success else 1

    # 执行 gitnexus setup
    if args.gitnexus_setup:
        success = run_gitnexus_setup()
        return 0 if success else 1

    # 执行 gitnexus analyze
    if args.gitnexus_analyze:
        success = run_gitnexus_analyze()
        return 0 if success else 1

    # 更新工作流程中的所有技能
    if args.update_skills:
        result = update_workflow_skills(args.update_workflow, cli_user, cli_pass)
        return 0 if result["success"] else 1

    # 更新单个技能
    if args.update_skill:
        result = update_single_skill(args.update_skill, cli_user, cli_pass)
        if result.get("updated"):
            print(f"[OK] {args.update_skill} 已更新")
            return 0
        elif result.get("error"):
            print(f"[X] {args.update_skill} 更新失败: {result['error']}")
            return 1
        else:
            print(f"[i] {args.update_skill} 已是最新版本")
            return 0

    # 安装工作流程
    if args.workflow:
        ensure_registry(cli_user=cli_user, cli_pass=cli_pass)
        result = install_workflow(args.workflow, args.location,
                                   cli_user=cli_user, cli_pass=cli_pass)
        if result["needs_config"]:
            print("\n[!] 需要配置 TFS 权限，请提供 PAT 和 Collection")
        return 0 if result["success"] else 1

    # 单独安装技能
    if args.skill:
        ensure_registry(cli_user=cli_user, cli_pass=cli_pass)
        success = install_skill(args.skill, args.location,
                                 cli_user=cli_user, cli_pass=cli_pass)
        return 0 if success else 1

    # 无参数时显示帮助
    parser.print_help()
    return 0


if __name__ == "__main__":
    sys.exit(main())