#!/usr/bin/env python3
"""
自动化测试报告生成脚本
读取测试执行结果（JUnit XML / 自定义格式），生成结构化 Markdown 报告
"""

import os
import sys
import xml.etree.ElementTree as ET
from datetime import datetime
from pathlib import Path

def parse_junit_xml(xml_path: str) -> dict:
    """解析 JUnit XML 格式的测试结果"""
    tree = ET.parse(xml_path)
    root = tree.getroot()

    # JUnit XML 结构: <testsuite tests="..." failures="..." errors="..." time="...">
    suite = root.find('testsuite') or root
    total = int(suite.get('tests', 0))
    failures = int(suite.get('failures', 0))
    errors = int(suite.get('errors', 0))
    skipped = int(suite.get('skipped', 0))
    passed = total - failures - errors - skipped

    testcases = []
    for tc in suite.findall('testcase'):
        case = {
            'name': tc.get('name', ''),
            'classname': tc.get('classname', ''),
            'time': tc.get('time', '0'),
            'status': 'passed',
            'error': None,
            'failure': None,
        }
        failure = tc.find('failure')
        if failure is not None:
            case['status'] = 'failed'
            case['failure'] = failure.text or str(failure.attrib)
        error = tc.find('error')
        if error is not None:
            case['status'] = 'error'
            case['error'] = error.text or str(error.attrib)
        if tc.find('skipped') is not None:
            case['status'] = 'skipped'
        testcases.append(case)

    return {
        'total': total,
        'passed': passed,
        'failed': failures + errors,
        'skipped': skipped,
        'pass_rate': round(passed / total * 100, 2) if total > 0 else 0,
        'testcases': testcases,
    }

def classify_bugs(testcases: list) -> dict:
    """根据测试用例名称和错误信息，对 bug 进行分级"""
    bugs = {'P0': [], 'P1': [], 'P2': [], 'P3': []}

    for tc in testcases:
        if tc['status'] == 'passed' or tc['status'] == 'skipped':
            continue

        error_msg = (tc.get('failure') or tc.get('error') or '').lower()
        name = tc['name'].lower()

        # P0: 核心业务功能失败、权限绕过、数据泄露
        if any(kw in name or kw in error_msg for kw in [
            '权限', 'auth', 'permission', 'sql注入', 'xss', '数据泄露',
            '事务', 'transaction', '处方', 'prescription', '患者删除'
        ]):
            bugs['P0'].append(tc)
        # P1: 正常场景失败
        elif '正常场景' in name or 'happy path' in name:
            bugs['P1'].append(tc)
        # P2: 边界值/异常场景失败
        elif any(kw in name for kw in ['边界值', '异常', 'boundary', 'exception']):
            bugs['P2'].append(tc)
        # P3: 其他
        else:
            bugs['P3'].append(tc)

    return bugs

def generate_report(result: dict, output_path: str, project_name: str = "Unknown"):
    """生成 Markdown 格式测试报告"""
    now = datetime.now().strftime('%Y-%m-%d %H:%M:%S')

    lines = [
        f"# 自动化测试报告",
        f"",
        f"- **项目名称**: {project_name}",
        f"- **生成时间**: {now}",
        f"- **测试框架**: JUnit 5 + Mockito / NUnit + Moq",
        f"",
        f"---",
        f"",
        f"## 测试概要",
        f"",
        f"| 指标 | 数值 |",
        f"|------|------|",
        f"| 总用例数 | {result['total']} |",
        f"| 通过 | {result['passed']} |",
        f"| 失败 | {result['failed']} |",
        f"| 跳过 | {result['skipped']} |",
        f"| **通过率** | **{result['pass_rate']}%** |",
        f"",
        f"---",
        f"",
    ]

    # Bug 分级
    bugs = classify_bugs(result['testcases'])
    total_bugs = sum(len(v) for v in bugs.values())

    if total_bugs > 0:
        lines.append("## Bug 及风险点清单")
        lines.append("")
        lines.append("| 严重级别 | 数量 | 描述 |")
        lines.append("|---------|------|------|")
        lines.append(f"| **P0（致命）** | {len(bugs['P0'])} | 核心业务失败、权限绕过、数据安全风险 |")
        lines.append(f"| **P1（严重）** | {len(bugs['P1'])} | 正常场景（Happy Path）失败 |")
        lines.append(f"| **P2（一般）** | {len(bugs['P2'])} | 边界值/异常场景失败 |")
        lines.append(f"| **P3（轻微）** | {len(bugs['P3'])} | 其他失败场景 |")
        lines.append("")
        lines.append("---")
        lines.append("")

        for level, label in [('P0', '🔴 P0 致命'), ('P1', '🟠 P1 严重'), ('P2', '🟡 P2 一般'), ('P3', '🟢 P3 轻微')]:
            if bugs[level]:
                lines.append(f"### {label}")
                lines.append("")
                lines.append("| 用例名称 | 类名 | 耗时 | 错误信息 |")
                lines.append("|---------|------|------|---------|")
                for tc in bugs[level]:
                    err = (tc.get('failure') or tc.get('error') or '')[:200]
                    lines.append(f"| {tc['name']} | {tc['classname']} | {tc['time']}s | {err} |")
                lines.append("")

    # 失败用例详情
    failed_cases = [tc for tc in result['testcases'] if tc['status'] != 'passed' and tc['status'] != 'skipped']
    if failed_cases:
        lines.append("---")
        lines.append("")
        lines.append("## 失败用例详情")
        lines.append("")
        for tc in failed_cases:
            lines.append(f"### ❌ {tc['name']}")
            lines.append(f"- **类名**: `{tc['classname']}`")
            lines.append(f"- **耗时**: {tc['time']}s")
            if tc.get('failure'):
                lines.append(f"- **失败原因**:")
                lines.append(f"```")
                lines.append(tc['failure'])
                lines.append(f"```")
            if tc.get('error'):
                lines.append(f"- **错误详情**:")
                lines.append(f"```")
                lines.append(tc['error'])
                lines.append(f"```")
            lines.append("")

    # 通过用例清单
    passed_cases = [tc for tc in result['testcases'] if tc['status'] == 'passed']
    if passed_cases:
        lines.append("---")
        lines.append("")
        lines.append("## 通过用例清单")
        lines.append("")
        lines.append("| 用例名称 | 类名 | 耗时 |")
        lines.append("|---------|------|------|")
        for tc in passed_cases:
            lines.append(f"| ✅ {tc['name']} | {tc['classname']} | {tc['time']}s |")
        lines.append("")

    # 医疗业务合规检查
    lines.append("---")
    lines.append("")
    lines.append("## 医疗业务合规检查")
    lines.append("")
    lines.append("| 检查项 | 状态 | 说明 |")
    lines.append("|--------|------|------|")
    lines.append("| 患者身份信息加密存储 | ⚠️ 待人工确认 | 需验证数据库字段加密 |")
    lines.append("| 处方剂量范围校验 | ⚠️ 待人工确认 | 成人/儿童差异化校验 |")
    lines.append("| 药物相互作用检测 | ⚠️ 待人工确认 | 触发逻辑验证 |")
    lines.append("| 护理操作记录不可篡改 | ⚠️ 待人工确认 | 审计日志完整性 |")
    lines.append("| 角色权限隔离 | ⚠️ 待人工确认 | 医生/护士/管理员 |")
    lines.append("| 敏感数据操作日志 | ⚠️ 待人工确认 | 操作记录完整性 |")
    lines.append("| 事务回滚一致性 | ⚠️ 待人工确认 | 异常时数据不残留 |")
    lines.append("| 接口幂等性 | ⚠️ 待人工确认 | 重复提交处理 |")
    lines.append("")

    # 改进建议
    lines.append("---")
    lines.append("")
    lines.append("## 改进建议")
    lines.append("")
    if result['pass_rate'] < 80:
        lines.append("⚠️ **通过率低于 80%，建议优先修复 P0/P1 级别缺陷**")
    elif result['pass_rate'] < 95:
        lines.append("⚠️ **通过率低于 95%，建议完善边界值和异常场景测试**")
    else:
        lines.append("✅ **通过率良好，建议持续完善测试用例覆盖**")
    lines.append("")
    lines.append("1. 补充遗漏的边界值测试用例")
    lines.append("2. 增加并发/性能测试场景")
    lines.append("3. 完善医疗业务规则校验测试")
    lines.append("4. 定期回归测试，确保核心功能稳定")
    lines.append("")
    lines.append("---")
    lines.append("")
    lines.append("*本报告由 WorkBuddy Automated Test Agent 自动生成*")

    report_content = "\n".join(lines)

    with open(output_path, 'w', encoding='utf-8') as f:
        f.write(report_content)

    print(f"✅ 测试报告已生成: {output_path}")
    return report_content

def main():
    if len(sys.argv) < 2:
        print("用法: python3 generate_test_report.py <junit-xml-path> [output-md-path] [project-name]")
        print("示例: python3 generate_test_report.py target/surefire-reports/TEST-*.xml report.md MyProject")
        sys.exit(1)

    xml_path = sys.argv[1]
    output_path = sys.argv[2] if len(sys.argv) > 2 else "test-report.md"
    project_name = sys.argv[3] if len(sys.argv) > 3 else "Unknown"

    if not os.path.exists(xml_path):
        print(f"❌ 文件不存在: {xml_path}")
        sys.exit(1)

    result = parse_junit_xml(xml_path)
    generate_report(result, output_path, project_name)

if __name__ == "__main__":
    main()
