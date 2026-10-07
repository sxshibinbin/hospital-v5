import os
import io
import base64
from loguru import logger
from safety.constants import GUARDRAIL_PROMPT
import json
import tempfile
from pathlib import Path
from PIL import Image
from typing import List, Dict, Any, AsyncGenerator, Optional, Sequence, Tuple
from dotenv import load_dotenv
from openai import AsyncOpenAI

load_dotenv()

MODEL_NAME = "qwen-plus"
LONG_CONTEXT_MODEL_NAME = "qwen-long"
VISION_MODEL_NAME = "qwen-vl-plus"
CARD_OPEN_TAG = "[CARD]"
CARD_CLOSE_TAG = "[/CARD]"

client = AsyncOpenAI(
    api_key=os.getenv("DASHSCOPE_API_KEY", "dummy"),
    base_url="https://dashscope.aliyuncs.com/compatible-mode/v1",
)

def strip_image_exif(image_bytes: bytes) -> bytes:
    """
    Remove EXIF data from an image for privacy protection.

    Re-encode via PIL without passing an exif parameter: the metadata is
    dropped automatically. Do NOT rebuild the image with getdata()/putdata();
    for a 12MP phone photo that allocates a multi-GB Python list and the
    backend process gets OOM-killed (observed as 502 at the gateway).
    """
    try:
        image = Image.open(io.BytesIO(image_bytes))
        output = io.BytesIO()
        # Preserve original format if possible, default to JPEG
        format = image.format if image.format else 'JPEG'
        image.save(output, format=format)
        return output.getvalue()
    except Exception as e:
        logger.error(f"Error stripping EXIF: {e}")
        return image_bytes

def convert_history(history: List[Dict[str, str]]) -> List[Dict[str, str]]:
    messages: List[Dict[str, str]] = []
    for msg in history:
        role = msg.get("role")
        content = msg.get("content")
        if role in {"user", "assistant"} and content:
            messages.append({"role": role, "content": content})
    return messages


async def upload_files_for_extraction(files: Sequence[Tuple[str, bytes]]) -> List[str]:
    file_ids: List[str] = []

    for file_name, content in files:
        suffix = Path(file_name).suffix
        temp_path: Optional[str] = None

        try:
            with tempfile.NamedTemporaryFile(delete=False, suffix=suffix) as temp_file:
                temp_file.write(content)
                temp_path = temp_file.name

            uploaded_file = await client.files.create(
                file=Path(temp_path),
                purpose="file-extract",
            )
            file_id = getattr(uploaded_file, "id", None)

            if not isinstance(file_id, str) or not file_id:
                raise ValueError(f"文件 {file_name} 上传成功但未返回 file_id")
                
            file_ids.append(file_id)
        finally:
            if temp_path and os.path.exists(temp_path):
                os.remove(temp_path)

    return file_ids


def extract_delta_text(delta: Any, field_names: List[str]) -> str:
    fragments: List[str] = []

    for field_name in field_names:
        value = getattr(delta, field_name, None)
        if value is None and isinstance(delta, dict):
            value = delta.get(field_name)

        if isinstance(value, str):
            fragments.append(value)
            continue

        if isinstance(value, list):
            for item in value:
                text = None
                if isinstance(item, dict):
                    text = item.get("text") or item.get("content")
                else:
                    text = getattr(item, "text", None) or getattr(item, "content", None)

                if text:
                    fragments.append(text)

    return "".join(fragments)


def normalize_text_block(value: str) -> str:
    return "\n\n".join(part.strip() for part in value.split("\n\n") if part.strip()).strip()


def extract_first_json_object(value: str) -> Optional[str]:
    start_index = value.find("{")
    if start_index < 0:
        return None

    depth = 0
    in_string = False
    is_escaped = False

    for index in range(start_index, len(value)):
        char = value[index]

        if in_string:
            if is_escaped:
                is_escaped = False
                continue
            if char == "\\":
                is_escaped = True
                continue
            if char == '"':
                in_string = False
            continue

        if char == '"':
            in_string = True
            continue

        if char == "{":
            depth += 1
            continue

        if char == "}":
            depth -= 1
            if depth == 0:
                return value[start_index:index + 1]

    return None


def parse_json_payload(value: str) -> Optional[Dict[str, Any]]:
    normalized_value = value.strip()
    if normalized_value.startswith("```json"):
        normalized_value = normalized_value[len("```json"):].strip()
    elif normalized_value.startswith("```"):
        normalized_value = normalized_value[len("```"):].strip()

    if normalized_value.endswith("```"):
        normalized_value = normalized_value[:-3].strip()

    if not normalized_value:
        return None

    try:
        parsed = json.loads(normalized_value)
        return parsed if isinstance(parsed, dict) else None
    except json.JSONDecodeError:
        json_candidate = extract_first_json_object(normalized_value)
        if not json_candidate:
            return None
        try:
            parsed = json.loads(json_candidate)
            return parsed if isinstance(parsed, dict) else None
        except json.JSONDecodeError:
            return None


def to_optional_text(value: Any) -> Optional[str]:
    if not isinstance(value, str):
        return None
    normalized_value = normalize_text_block(value)
    return normalized_value or None


def normalize_card_payload(payload: Dict[str, Any], fallback_summary: str) -> Optional[Dict[str, Any]]:
    source = payload.get("data") if isinstance(payload.get("data"), dict) else payload
    if not isinstance(source, dict):
        return None

    card_type = payload.get("type", "medical_result")

    if card_type == "question_options":
        options = source.get("options")
        if not isinstance(options, list):
            return None
        valid_options = [str(opt) for opt in options if opt]
        if not valid_options:
            return None
        return {
            "type": "question_options",
            "data": {
                "options": valid_options
            }
        }

    summary = to_optional_text(source.get("summary")) or to_optional_text(fallback_summary)
    analysis = to_optional_text(source.get("analysis"))
    recommended_department = to_optional_text(source.get("recommended_department"))
    hospital_suggestion = to_optional_text(source.get("hospital_suggestion"))

    if not any([summary, analysis, recommended_department, hospital_suggestion]):
        return None

    return {
        "type": "medical_result",
        "data": {
            "summary": summary or "",
            "analysis": analysis or "",
            "recommended_department": recommended_department or "",
            "hospital_suggestion": hospital_suggestion or "",
        },
    }


def format_medical_card_payload(payload: Dict[str, Any]) -> str:
    normalized_json = json.dumps(payload, ensure_ascii=False, separators=(",", ":"))
    return f"{CARD_OPEN_TAG}\n{normalized_json}\n{CARD_CLOSE_TAG}"


def flush_plain_text(buffer: str) -> tuple[str, str]:
    safe_keep_length = len(CARD_OPEN_TAG) - 1
    if len(buffer) <= safe_keep_length:
        return "", buffer
    return buffer[:-safe_keep_length], buffer[-safe_keep_length:]


def merge_system_prompt(system_prompt: str, user_context: Optional[str]) -> str:
    normalized_prompt = f"{system_prompt.strip()}\n\n{GUARDRAIL_PROMPT}"
    normalized_context = normalize_text_block(user_context or "")

    if not normalized_context:
        return normalized_prompt

    return (
        f"{normalized_prompt}\n\n"
        "以下是当前登录用户已经保存的历史病例与既往问诊记录。"
        "只有在和本轮问题相关时才使用这些信息，不能把历史记录直接当成用户当前仍然存在的症状。"
        "如果历史信息与本轮描述存在冲突或时间不明确，请优先向用户确认。\n"
        f"{normalized_context}"
    )


async def stream_chat(
    system_prompt: str,
    history: List[Dict[str, str]],
    message: str,
    thinking: bool = False,
    file_ids: Optional[List[str]] = None,
    image_data_urls: Optional[List[str]] = None,
) -> AsyncGenerator[Dict[str, str], None]:
    messages = [{"role": "system", "content": system_prompt}]
    if not image_data_urls:
        for file_id in file_ids or []:
            messages.append({"role": "system", "content": f"fileid://{file_id}"})
    messages.extend(convert_history(history))

    if image_data_urls:
        user_content: List[Dict[str, Any]] = [{"type": "text", "text": message}]
        user_content.extend(
            {"type": "image_url", "image_url": {"url": image_data_url}}
            for image_data_url in image_data_urls
        )
        messages.append({"role": "user", "content": user_content})
    else:
        messages.append({"role": "user", "content": message})

    kwargs = {
        "model": VISION_MODEL_NAME if image_data_urls else LONG_CONTEXT_MODEL_NAME if file_ids else MODEL_NAME,
        "messages": messages,
        "stream": True,
    }
    if thinking and not file_ids:
        kwargs["extra_body"] = {"enable_thinking": True}

    stream = await client.chat.completions.create(**kwargs)

    async for chunk in stream:
        if not chunk.choices:
            continue

        delta = chunk.choices[0].delta
        reasoning = extract_delta_text(delta, ["reasoning_content", "reasoning"])
        content = extract_delta_text(delta, ["content"])

        if reasoning:
            yield {"type": "reasoning", "content": reasoning}

        if content:
            yield {"type": "content", "content": content}

async def stream_normal_chat(
    history: List[Dict[str, str]],
    message: str,
    thinking: bool = False,
    file_ids: Optional[List[str]] = None,
    user_context: Optional[str] = None,
    image_data_urls: Optional[List[str]] = None,
) -> AsyncGenerator[Dict[str, str], None]:
    system_prompt = """
你是一个有用的医疗健康助手，名字叫安小记，可以回答用户的日常问题。
如果本轮对话附带了图片或 PDF 文件，你必须优先结合文件内容进行回答，不要声称自己没有收到文件。
当文件是检查报告、化验单或影像资料时，请先提炼关键结论，再解释异常项或重点描述，最后给出就医与复查建议。对于化验单或检查报告中的异常指标，必须使用 Markdown 加粗并使用 🔴 前缀进行明显标注（如 **🔴异常项**）。
在输出任何用药建议前，强制反问三个问题：“1.患者年龄？2.是否有过敏史？3.是否有肝肾功能问题或正在备孕/怀孕/哺乳？”如果用户未回答，应拒绝给出具体建议，只提供通用信息。
在提及药物相互作用时，增加风险等级，使用“通常可以，但建议咨询药师或医生后服用”或“存在已知相互作用风险，不建议自行联用”的严谨措辞。
排除风险时，应一步步引导患者感受，不可盲目直接推断病因。
如果文件信息不足以支撑明确结论，请直接说明不确定性，并指出还需要哪些补充信息。
对于具体的医疗诊断，请提醒用户以线下医生面诊结果为准。
    """
    async for chunk in stream_chat(
        merge_system_prompt(system_prompt, user_context),
        history,
        message,
        thinking=thinking,
        file_ids=file_ids,
        image_data_urls=image_data_urls,
    ):
        yield chunk


async def stream_health_report(
    history: List[Dict[str, str]],
    message: str,
    health_facts: str,
    thinking: bool = False,
) -> AsyncGenerator[Dict[str, str], None]:
    """Generate a concise report using only server-computed monitoring facts."""
    system_prompt = """
你是医疗健康助手。用户正在请求健康监测报告。

下面的“健康监测报告事实摘要”由系统根据用户已授权设备的历史数据计算，是真实且唯一可使用的数据来源。
请仅基于这些事实，写一份简洁、自然的中文文字报告：
1. 先说明统计周期和整体情况；
2. 只点出存在异常、波动、趋势或数据不足的指标；没有问题的指标可合并概述；
3. 不逐条列举原始检测数据，不编造未提供的数值、原因、设备状态或诊断；
4. 不作疾病诊断、用药指导或紧急处置判断；如事实显示持续异常，可用审慎措辞建议复测或咨询医生；
5. 结尾固定附上："本报告基于设备监测数据生成，仅供健康管理参考，不替代医疗诊断。"

""" + health_facts

    async for chunk in stream_chat(
        system_prompt,
        history,
        message,
        thinking=thinking,
    ):
        yield chunk

async def stream_medical_chat(
    history: List[Dict[str, str]],
    message: str,
    thinking: bool = False,
    file_ids: Optional[List[str]] = None,
    user_context: Optional[str] = None,
    image_data_urls: Optional[List[str]] = None,
) -> AsyncGenerator[Dict[str, str], None]:
    system_prompt = """
你是一个专业的在线问诊医生（类似阿里阿福）。
你的任务是通过多轮对话向患者收集病情信息。
你需要收集以下信息：
1. 主要症状及持续时间
2. 是否有伴随症状
3. 既往病史或用药情况

排除风险时，应一步步引导患者感受，不可盲目直接推断病因。
在输出任何用药建议前，强制反问三个问题：“1.患者年龄？2.是否有过敏史？3.是否有肝肾功能问题或正在备孕/怀孕/哺乳？”如果用户未回答，应拒绝给出具体建议，只提供通用信息。
在提及药物相互作用时，增加风险等级，使用“通常可以，但建议咨询药师或医生后服用”或“存在已知相互作用风险，不建议自行联用”的严谨措辞。

如果用户上传了图片、PDF 检查报告或化验结果，请优先结合文件内容进行分析，不要说没有收到文件。
对报告解读场景，请先直接总结关键发现、风险点、建议科室和下一步处理，再判断是否需要补充追问。对于化验单或检查报告中的异常指标，必须使用 Markdown 加粗并使用 🔴 前缀进行明显标注（如 **🔴异常项**）。

【重要交互规则】
1. 每次向用户的提问只能有一个问题。
2. 对于每一个提问，必须生成一个选择 JSON 卡片，提供 2-4 个预设选项供用户选择。
用户可同时勾选多个选项，也可在下方输入框中补充自定义内容，方便灵活回答。
你输出的选项卡片必须只出现一次，必须放在回答最后。
必须使用紧凑 JSON，绝对不要使用 Markdown 代码块（如 ```json）。
选项卡片的格式必须严格按照以下示例，必须用 [CARD] 和 [/CARD] 包裹：
[CARD]{"type": "question_options", "data": {"options": ["选项1", "选项2"]}}[/CARD]

3. 当你认为收集到了足够的信息，能够做出初步判断时，先用1到2句话给出自然语言结论，再紧接着输出一个问诊卡片 JSON（此时不需要再输出选项卡片）。
问诊卡片的格式必须严格按照以下示例，必须用 [CARD] 和 [/CARD] 包裹：
[CARD]{"type": "medical_result", "data": {"summary": "患者概览...", "analysis": "病情分析...", "recommended_department": "推荐科室（如：内科等）", "hospital_suggestion": "进一步的就医建议..."}}[/CARD]

注意：所有的卡片数据必须且只能用 [CARD] 和 [/CARD] 标签包裹，绝对不能包含多余的换行，绝对不能包含 Markdown 代码块标识（不要写 ```json）！
"""

    streamed_text_parts: List[str] = []
    pending_content = ""
    card_buffer = ""
    in_card = False

    async for chunk in stream_chat(
        merge_system_prompt(system_prompt, user_context),
        history,
        message,
        thinking=thinking,
        file_ids=file_ids,
        image_data_urls=image_data_urls,
    ):
        if chunk.get("type") != "content":
            yield chunk
            continue

        pending_content += chunk.get("content", "")

        while pending_content:
            if not in_card:
                open_index = pending_content.find(CARD_OPEN_TAG)
                if open_index < 0:
                    plain_text, pending_content = flush_plain_text(pending_content)
                    if plain_text:
                        streamed_text_parts.append(plain_text)
                        yield {"type": "content", "content": plain_text}
                    break

                plain_text = pending_content[:open_index]
                if plain_text:
                    streamed_text_parts.append(plain_text)
                    yield {"type": "content", "content": plain_text}
                pending_content = pending_content[open_index + len(CARD_OPEN_TAG):]
                in_card = True
                card_buffer = ""

            close_index = pending_content.find(CARD_CLOSE_TAG)
            if close_index < 0:
                card_buffer += pending_content
                pending_content = ""
                break

            card_buffer += pending_content[:close_index]
            pending_content = pending_content[close_index + len(CARD_CLOSE_TAG):]
            
            # Print card buffer for debugging
            logger.debug(f"--- DEBUG: card_buffer parsed ---")
            logger.debug(card_buffer)
            logger.debug(f"---------------------------------")
            
            normalized_payload = normalize_card_payload(
                parse_json_payload(card_buffer) or {},
                normalize_text_block("".join(streamed_text_parts)),
            )
            if normalized_payload:
                yield {"type": "content", "content": format_medical_card_payload(normalized_payload)}
            else:
                raw_card = f"{CARD_OPEN_TAG}{card_buffer}{CARD_CLOSE_TAG}"
                yield {"type": "content", "content": raw_card}
            card_buffer = ""
            in_card = False

    if in_card and card_buffer.strip():
        logger.debug(f"--- DEBUG: card_buffer at end ---")
        logger.debug(card_buffer)
        logger.debug(f"---------------------------------")
        normalized_payload = normalize_card_payload(
            parse_json_payload(card_buffer) or {},
            normalize_text_block("".join(streamed_text_parts)),
        )
        if normalized_payload:
            yield {"type": "content", "content": format_medical_card_payload(normalized_payload)}
        else:
            yield {"type": "content", "content": f"{CARD_OPEN_TAG}{card_buffer}"}
    elif pending_content:
        if "```json" in pending_content and "question_options" in pending_content:
            logger.debug("--- DEBUG: Found JSON without CARD tags in pending_content ---")
        streamed_text_parts.append(pending_content)
        yield {"type": "content", "content": pending_content}


async def polish_medical_query(original_text: str) -> str:
    system_prompt = """你是一个医疗问诊咨询润色助手。你的任务是将用户输入的原始医疗咨询问题，润色为更清晰、专业、结构化的表述，方便医生理解。

润色规则：
1. 保留用户的原始意图和所有关键信息，不要添加用户未提及的症状或信息。
2. 使用专业但通俗易懂的医学术语替换口语化表达。
3. 将问题结构化组织，例如：主要症状 → 持续时间 → 伴随症状 → 用户关注的要点。
4. 如果原始问题中包含年龄、性别、过敏史等关键信息，请在润色后的问题中明确突出。
5. 只输出润色后的问题文本，不要添加任何解释、说明或前缀。

以下为需要润色的原始文本："""

    try:
        response = await client.chat.completions.create(
            model=MODEL_NAME,
            messages=[
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": original_text},
            ],
            stream=False,
        )
        polished = response.choices[0].message.content
        if polished:
            return polished.strip()
        return original_text
    except Exception as e:
        logger.error(f"AI润色失败: {e}")
        raise
