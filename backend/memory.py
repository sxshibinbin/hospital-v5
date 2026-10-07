"""
LangChain 记忆管理系统

提供基于 PostgreSQL 的对话历史管理，集成 LangChain BaseChatMessageHistory 接口。
支持异步操作、滑动窗口裁剪和会话级记忆持久化。
"""
import json
from typing import List, Dict, Optional, Callable, Any

from langchain_core.chat_history import BaseChatMessageHistory
from langchain_core.messages import HumanMessage, AIMessage, BaseMessage
from sqlalchemy import select, update
from sqlalchemy.ext.asyncio import AsyncSession

from models import ChatSession, get_beijing_time


class PostgresChatMessageHistory(BaseChatMessageHistory):
    """基于 ChatSession 的 LangChain 消息历史实现。

    从 chat_sessions.messages_json 字段读写对话历史，
    每条消息格式: {"role": "user"|"assistant", "content": "..."}
    """

    def __init__(self, session_id: int, user_id: int, db_session_factory: Callable[[], Any]):
        self.session_id = session_id
        self.user_id = user_id
        self._factory = db_session_factory
        self._messages: List[BaseMessage] = []

    async def aget_messages(self) -> List[BaseMessage]:
        """从数据库加载历史消息。"""
        async with self._factory() as db:
            result = await db.execute(
                select(ChatSession).where(
                    ChatSession.id == self.session_id,
                    ChatSession.user_id == self.user_id,
                )
            )
            session = result.scalars().first()
            if not session:
                return []

            raw_messages = json.loads(session.messages_json or "[]")
            msgs: List[BaseMessage] = []
            for m in raw_messages:
                role = m.get("role")
                content = m.get("content", "")
                if role == "user":
                    msgs.append(HumanMessage(content=content))
                elif role == "assistant":
                    msgs.append(AIMessage(content=content))

            self._messages = msgs
            return msgs

    async def aadd_message(self, message: BaseMessage) -> None:
        """追加单条消息到数据库。"""
        self._messages.append(message)

        role = "user" if isinstance(message, HumanMessage) else "assistant"
        content = message.content
        if isinstance(content, list):
            # 多模态消息：取第一个 text 块
            text_parts = [b.get("text", "") for b in content if isinstance(b, dict) and b.get("type") == "text"]
            content = " ".join(text_parts)

        async with self._factory() as db:
            result = await db.execute(
                select(ChatSession).where(
                    ChatSession.id == self.session_id,
                    ChatSession.user_id == self.user_id,
                )
            )
            session = result.scalars().first()
            if session:
                existing = json.loads(session.messages_json or "[]")
                existing.append({"role": role, "content": content})
                session.messages_json = json.dumps(existing, ensure_ascii=False)
                session.updated_at = get_beijing_time()
                await db.commit()

    async def aclear(self) -> None:
        """清空会话历史。"""
        self._messages = []
        async with self._factory() as db:
            result = await db.execute(
                select(ChatSession).where(
                    ChatSession.id == self.session_id,
                    ChatSession.user_id == self.user_id,
                )
            )
            session = result.scalars().first()
            if session:
                session.messages_json = "[]"
                session.updated_at = get_beijing_time()
                await db.commit()


class ConversationMemoryManager:
    """对话记忆管理器。

    封装 PostgresChatMessageHistory，提供：
    - 滑动窗口裁剪（最近 MAX_WINDOW 条消息）
    - 适配 agents.py 的 dict 格式输出
    - 一轮对话的批量记录
    """

    MAX_WINDOW = 20  # 最多保留最近 20 条消息（10 轮对话）

    def __init__(self, db_session_factory: Callable[[], Any]):
        self._factory = db_session_factory

    async def get_history(self, session_id: int, user_id: int) -> List[Dict[str, str]]:
        """获取会话历史（最近 MAX_WINDOW 条），返回 agents.py 兼容的 dict 格式。"""
        history = PostgresChatMessageHistory(session_id, user_id, self._factory)
        messages = await history.aget_messages()
        recent = messages[-self.MAX_WINDOW:]

        return [
            {
                "role": "user" if isinstance(m, HumanMessage) else "assistant",
                "content": m.content if isinstance(m.content, str) else str(m.content),
            }
            for m in recent
        ]

    async def get_full_history(self, session_id: int, user_id: int) -> List[Dict[str, str]]:
        """获取完整会话历史（不限窗口）。"""
        history = PostgresChatMessageHistory(session_id, user_id, self._factory)
        messages = await history.aget_messages()

        return [
            {
                "role": "user" if isinstance(m, HumanMessage) else "assistant",
                "content": m.content if isinstance(m.content, str) else str(m.content),
            }
            for m in messages
        ]

    async def add_turn(
        self, session_id: int, user_id: int, user_msg: str, assistant_msg: str
    ) -> None:
        """记录一轮完整的对话（用户消息 + AI 回复）。"""
        history = PostgresChatMessageHistory(session_id, user_id, self._factory)
        await history.aadd_message(HumanMessage(content=user_msg))
        await history.aadd_message(AIMessage(content=assistant_msg))

    async def add_system_summary(self, session_id: int, user_id: int, summary: str) -> None:
        """添加系统摘要消息（用于长期记忆压缩）。"""
        history = PostgresChatMessageHistory(session_id, user_id, self._factory)
        await history.aadd_message(AIMessage(content=f"[系统摘要] {summary}"))


# 全局记忆管理器实例（惰性初始化）
_memory_manager: Optional[ConversationMemoryManager] = None


def get_memory_manager(db_session_factory: Callable[[], Any]) -> ConversationMemoryManager:
    """获取或创建记忆管理器实例。"""
    global _memory_manager
    if _memory_manager is None:
        _memory_manager = ConversationMemoryManager(db_session_factory)
    return _memory_manager
