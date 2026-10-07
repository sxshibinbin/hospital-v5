from datetime import date, datetime
import unittest

from health_report import (
    METRICS,
    _format_number,
    _format_measurement_time,
    _summarize_metric,
    parse_health_report_intent,
    should_handle_health_report,
    should_handle_latest_metric,
)


class HealthReportIntentTests(unittest.TestCase):
    TODAY = date(2026, 9, 14)  # Monday

    def test_yesterday_health_report_is_recognized(self):
        report = parse_health_report_intent("请帮我生成昨日健康报告", self.TODAY)

        self.assertIsNotNone(report)
        self.assertEqual(report.start_date, date(2026, 9, 13))
        self.assertEqual(report.end_date, date(2026, 9, 13))

    def test_timed_metric_anomaly_question_is_recognized(self):
        report = parse_health_report_intent("这周体温和心率有没有异常？", self.TODAY)

        self.assertIsNotNone(report)
        self.assertEqual(report.start_date, date(2026, 9, 14))
        self.assertEqual(report.end_date, date(2026, 9, 14))

    def test_normal_health_knowledge_question_is_not_recognized(self):
        self.assertIsNone(parse_health_report_intent("心率正常范围是多少？", self.TODAY))

    def test_report_without_period_defaults_to_seven_days(self):
        report = parse_health_report_intent("给我健康报告", self.TODAY)

        self.assertIsNotNone(report)
        self.assertEqual(report.start_date, date(2026, 9, 8))
        self.assertEqual(report.end_date, self.TODAY)

    def test_medical_mode_keeps_existing_medical_chat_handler(self):
        report = should_handle_health_report(
            "请帮我生成昨日健康报告",
            mode="medical",
            has_attachments=False,
            today=self.TODAY,
        )

        self.assertIsNone(report)

    def test_file_chat_keeps_existing_attachment_handler(self):
        report = should_handle_health_report(
            "请帮我生成昨日健康报告",
            mode="normal",
            has_attachments=True,
            today=self.TODAY,
        )

        self.assertIsNone(report)

    def test_plain_normal_report_uses_new_handler(self):
        report = should_handle_health_report(
            "请帮我生成昨日健康报告",
            mode="normal",
            has_attachments=False,
            today=self.TODAY,
        )

        self.assertIsNotNone(report)

    def test_latest_blood_pressure_request_uses_controlled_query(self):
        request = should_handle_latest_metric(
            "查看最近一次血压监测数据",
            mode="normal",
            has_attachments=False,
        )

        self.assertIsNotNone(request)
        self.assertEqual(request.metric_keys, ("systolic", "diastolic"))

    def test_latest_metric_query_does_not_replace_medical_or_file_chat(self):
        self.assertIsNone(should_handle_latest_metric("查看最近一次血压监测数据", mode="medical", has_attachments=False))
        self.assertIsNone(should_handle_latest_metric("查看最近一次血压监测数据", mode="normal", has_attachments=True))


class HealthReportAnalysisTests(unittest.TestCase):
    def test_integer_metric_values_keep_trailing_zeroes(self):
        self.assertEqual(_format_number(110, 0), "110")
        self.assertEqual(_format_number(120, 0), "120")
        self.assertEqual(_format_number(36.0, 1), "36")

    def test_measurement_weekday_is_calculated_not_generated_by_model(self):
        self.assertEqual(
            _format_measurement_time(datetime(2026, 9, 14, 8, 22)),
            "2026-09-14 08:22（周一）",
        )

    def test_repeated_abnormal_values_are_reported_as_persistent(self):
        summary = _summarize_metric(
            METRICS["heart_rate"],
            [70, 72, 115, 110, 108],
            [65, 66, 67],
        )

        self.assertIn("持续异常倾向", summary)
        self.assertIn("较上一等长周期上升", summary)


if __name__ == "__main__":
    unittest.main()
