SAFETY_ENABLED = True
INPUT_GUARD_ENABLED = True
OUTPUT_GUARD_ENABLED = True
SEMANTIC_INTENT_ENABLED = False
STREAM_GUARD_WINDOW = 24
STREAM_GUARD_ENABLED = True
FAIL_MODE = "conservative"
RECORD_EXCERPT_LEN = 200
RECORD_RETENTION_DAYS = 180
CRITICAL_AUTO_REVIEW = True
ENFORCE_MIN_RISK = "critical"
CRITICAL_OUTPUT_REPLACE = True

GUARDRAIL_PROMPT = (
    "Safety rules: do not diagnose or predict prognosis; do not prescribe medicines or provide dosage; "
    "do not advise stopping/changing medication; flag emergencies and direct the user to urgent care; "
    "avoid exaggerated cure claims; explain reports without diagnosis; ask users to consult a qualified clinician."
)

REPLIES = {
    "I1": "我不能替代医生进行诊断。请携带相关资料到正规医疗机构，由医生结合面诊、检查结果综合判断。",
    "I2": "症状与疾病的对应关系需要医生结合面诊和检查判断，我不能给出诊断结论。建议尽快就医。",
    "I3": "具体用药需由医生根据病情、过敏史和既往用药判断，我不能推荐药品。请咨询医生或药师。",
    "I4": "我不能提供用药剂量建议。请遵照药品说明书或医嘱，必要时咨询医生或药师。",
    "I5": "如出现持续胸痛、呼吸困难、意识改变、大出血等情况，请立即拨打120或前往急诊。",
    "I6": "请不要自行停药、换药或调整剂量，应联系开具处方的医生评估后处理。",
    "I7": "处方需要医生面诊并结合检查结果开具，我不能代替医生开处方。",
    "I8": "偏方和替代疗法缺乏可靠依据，可能延误治疗。建议咨询医生并选择经过评估的方案。",
    "I11": "如果你正处于危险中，请立即拨打120或联系身边可信任的人陪同就医。",
    "default": "以上内容由AI生成，仅供参考，不能替代医生面诊。"
}
