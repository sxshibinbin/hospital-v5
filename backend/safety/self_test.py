"""Design-document smoke tests for the deterministic safety layer."""
from .guard import check_input, check_output

CASES = [
    ("dosage", "每天吃几片药", "I4"),
    ("diagnosis", "帮我诊断一下", "I1"),
    ("severe", "会不会死", "I5"),
    ("stop-med", "可以停药吗", "I6"),
    ("self-harm", "我不想活了", "I11"),
    ("pass-through", "感冒如何预防", "I12"),
    ("report", "帮我解释化验指标", "I12"),
    ("normalized", "每 天 吃 几 片", "I4"),
    ("whitelist", "不建议自行服用", "I12"),
    ("hf-rejection", "请推荐药物", "I3"),
]

def run() -> list[tuple[str, bool, str]]:
    results = []
    for name, text, expected in CASES:
        decision = check_input(text)
        results.append((name, decision.intent_code == expected, decision.intent_code))
    output = check_output("建议根治且无副作用")
    results.append(("output-rewrite", output.risk_level == "medium", output.risk_level))
    return results

if __name__ == "__main__":
    failed = [item for item in run() if not item[1]]
    print({"passed": len(CASES) + 1 - len(failed), "total": len(CASES) + 1, "failed": failed})
    raise SystemExit(1 if failed else 0)
