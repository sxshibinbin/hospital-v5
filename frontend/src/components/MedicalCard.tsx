import React, { useEffect, useRef } from 'react';
import { Card, Typography, Divider, Space, Button } from 'antd';
import { MedicineBoxOutlined, InfoCircleOutlined, EnvironmentOutlined, SaveOutlined, CheckCircleOutlined } from '@ant-design/icons';
import gsap from 'gsap';
import { AI_WATERMARK_TEXT } from '../utils/aiWatermark';

const { Title, Paragraph, Text } = Typography;

interface CardActionConfig {
  event?: {
    name?: string;
    context?: Record<string, unknown>;
  };
}

interface MedicalCardProps {
  summary?: string;
  analysis?: string;
  recommended_department?: string;
  hospital_suggestion?: string;
  saveAction?: CardActionConfig;
  finishAction?: CardActionConfig;
  onAction?: (name: string, context?: Record<string, unknown>) => void;
  saveState?: 'idle' | 'saving' | 'saved';
}

const MedicalCard: React.FC<MedicalCardProps> = ({
  summary,
  analysis,
  recommended_department,
  hospital_suggestion,
  saveAction,
  finishAction,
  onAction,
  saveState = 'idle',
}) => {
  const cardRef = useRef<HTMLDivElement>(null);
  const cardData = {
    summary,
    analysis,
    recommended_department,
    hospital_suggestion,
  };

  useEffect(() => {
    if (cardRef.current) {
      const reduceMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
      gsap.fromTo(
        cardRef.current,
        { opacity: 0, scale: 0.95 },
        { opacity: 1, scale: 1, duration: reduceMotion ? 0.1 : 0.5, ease: 'power4.out' }
      );
    }
  }, [summary, analysis, recommended_department, hospital_suggestion]);

  if (!summary && !analysis && !recommended_department && !hospital_suggestion) return null;

  return (
    <div ref={cardRef} className="my-4">
      <Card
        className="w-full overflow-hidden rounded-[28px] border border-white/70 bg-[linear-gradient(180deg,rgba(255,255,255,0.98),rgba(244,246,255,0.94))] shadow-[0_20px_50px_rgba(129,140,248,0.16)] backdrop-blur"
        title={
          <div className="flex items-center gap-3 text-foreground">
            <div className="flex h-10 w-10 items-center justify-center rounded-2xl bg-[linear-gradient(135deg,rgba(99,102,241,0.95),rgba(168,85,247,0.78))] text-lg text-white shadow-[0_12px_24px_rgba(129,140,248,0.28)]">
              <MedicineBoxOutlined />
            </div>
            <div>
              <div className="text-base font-semibold tracking-tight">AI 问诊结果卡片</div>
              <div className="text-xs text-muted-foreground">基于本轮问诊信息生成的结构化建议</div>
            </div>
          </div>
        }
      >
        <Space direction="vertical" size="middle" className="w-full">
          <div>
            <Title level={5} className="mb-2 flex items-center gap-2 text-foreground">
              <InfoCircleOutlined className="text-primary" />
              患者概览
            </Title>
            <Paragraph className="rounded-2xl border border-border/70 bg-background/85 p-4 text-sm leading-7 text-foreground shadow-sm">
              {summary || '暂无概览信息'}
            </Paragraph>
          </div>

          <div>
            <Title level={5} className="mb-2 flex items-center gap-2 text-foreground">
              <EnvironmentOutlined className="text-emerald-500" />
              病情分析
            </Title>
            <Paragraph className="rounded-2xl border border-emerald-100 bg-emerald-50/75 p-4 text-sm leading-7 text-foreground shadow-sm">
              {analysis || '暂无分析信息'}
            </Paragraph>
          </div>

          <Divider className="my-2" />

          <div className="flex items-start justify-between rounded-[22px] border border-primary/10 bg-primary/5 p-4">
            <div className="flex flex-col">
              <Text type="secondary" className="mb-1 text-xs uppercase tracking-wider">推荐就诊科室</Text>
              <Text strong className="text-lg text-primary">{recommended_department || '全科'}</Text>
            </div>
            <div className="flex flex-col text-right">
              <Text type="secondary" className="mb-1 text-xs uppercase tracking-wider">就医建议</Text>
              <Text className="text-sm text-foreground">{hospital_suggestion || '请尽快就医'}</Text>
            </div>
          </div>

          <div className="grid grid-cols-1 gap-3 sm:grid-cols-2">
            <Button
              type="primary"
              icon={<SaveOutlined />}
              block
              size="large"
              className="mt-2 rounded-2xl"
              loading={saveState === 'saving'}
              disabled={saveState === 'saved'}
              onClick={() => {
                if (saveState === 'saving' || saveState === 'saved') {
                  return;
                }

                if (saveAction?.event?.name) {
                  onAction?.(saveAction.event.name, cardData);
                }
              }}
            >
              {saveState === 'saved' ? '已保存到个人记录' : '保存到个人记录'}
            </Button>
            <Button
              icon={<CheckCircleOutlined />}
              block
              size="large"
              className="mt-2 rounded-2xl border-border bg-background text-foreground shadow-none"
              onClick={() => {
                if (finishAction?.event?.name) {
                  onAction?.(finishAction.event.name, cardData);
                }
              }}
            >
              完成本次问诊
            </Button>
          </div>

          <div className="mt-2 text-center text-[11px] text-muted-foreground/80">
            {AI_WATERMARK_TEXT}
          </div>
        </Space>
      </Card>
    </div>
  );
};

export default MedicalCard;
