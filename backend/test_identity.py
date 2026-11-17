"""身份类问题识别与固定回答的单测。"""

import unittest

from identity import (
    ASSISTANT_IDENTITY_PROMPT,
    ASSISTANT_NAME,
    IDENTITY_ANSWER,
    build_identity_answer,
    is_identity_question,
)


class IdentityQuestionTests(unittest.TestCase):
    def test_developer_questions_are_recognized(self):
        questions = [
            "谁开发了你",
            "是谁开发了你？",
            "你是谁创造的",
            "你是谁研发的",
            "哪家公司开发了你",
            "什么团队做了你",
            "你的开发团队是谁",
            "研发方是哪家",
            "安小记是谁开发的",
            "安小记是谁",
            "你是谁",
            "你叫什么名字",
            "你是什么ai",
            "介绍一下你自己",
            "简单介绍下你自己",
            "自我介绍",
            "你是真人吗",
            "你是哪家公司",
            "你属于什么团队",
            "你们公司是哪家",
        ]
        for question in questions:
            with self.subTest(question=question):
                self.assertTrue(is_identity_question(question))

    def test_medical_questions_are_not_identity(self):
        questions = [
            "我头疼三天了怎么办",
            "这个症状是什么病",
            "吃什么药",
            "我是谁",
            "医生说我是什么病",
            "帮我看看这份化验单",
            "心率正常范围是多少",
            "这个药谁开发的我都不关心，我只想知道能不能吃",
        ]
        for question in questions:
            with self.subTest(question=question):
                self.assertFalse(is_identity_question(question))

    def test_long_text_is_not_treated_as_identity_question(self):
        self.assertFalse(
            is_identity_question("你是谁" * 40)
        )

    def test_build_identity_answer_returns_fixed_text(self):
        self.assertEqual(build_identity_answer("谁开发了你"), IDENTITY_ANSWER)
        self.assertIsNone(build_identity_answer("我头疼怎么办"))

    def test_answer_contains_three_parties_and_name(self):
        for keyword in (
            "上海交通大学医学院附属仁济医院",
            "三十天科技（山西）股份有限公司",
            "福芯高照（上海）科技有限公司",
            "医学大脑",
            "技术引擎",
            "产品心脏",
        ):
            self.assertIn(keyword, IDENTITY_ANSWER)
        self.assertIn(f"「{ASSISTANT_NAME}」", IDENTITY_ANSWER)
        self.assertIn(ASSISTANT_NAME, ASSISTANT_IDENTITY_PROMPT)


if __name__ == "__main__":
    unittest.main()
