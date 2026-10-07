import React, { useEffect, useMemo, useRef, useState } from 'react';
import { Think } from '@ant-design/x';
import { XMarkdown } from '@ant-design/x-markdown';
import { Button, Space, message } from 'antd';
import { LikeOutlined, DislikeOutlined, LikeFilled, DislikeFilled } from '@ant-design/icons';
import MedicalCard from './MedicalCard';
import { notifyConsultationEnd } from '../utils/jsbridge';
import gsap from 'gsap';
import { AI_WATERMARK_TEXT } from '../utils/aiWatermark';

interface MessageRenderProps {
  content: string;
  reasoning?: string;
  status?: string;
  role?: string;
  saveState?: 'idle' | 'saving' | 'saved';
  onCardAction?: (name: string, cardData: any) => void;
  safety?: { action?: string; riskLevel?: string; phase?: string };
  notice?: string;
}

interface MedicalCardData {
  summary?: string;
  analysis?: string;
  recommended_department?: string;
  hospital_suggestion?: string;
}

interface QuestionOptionsData {
  options: string[];
}

interface CardPayload {
  type: string;
  data: MedicalCardData | QuestionOptionsData;
}

const CARD_OPEN_TAG = '[CARD]';
const CARD_CLOSE_TAG = '[/CARD]';

const normalizeReasoning = (reasoning: string) =>
  reasoning.replace(/<\/?think>/gi, '').replace(/\n{3,}/g, '\n\n').trim();

const normalizeTextBlock = (value: string) =>
  value.replace(/\n{3,}/g, '\n\n').trim();

const isRecord = (value: unknown): value is Record<string, unknown> =>
  typeof value === 'object' && value !== null && !Array.isArray(value);

const toOptionalText = (value: unknown) => {
  if (typeof value !== 'string') {
    return undefined;
  }

  const normalizedValue = normalizeTextBlock(value);
  return normalizedValue || undefined;
};

const extractFirstJsonObject = (value: string) => {
  const startIndex = value.indexOf('{');

  if (startIndex < 0) {
    return null;
  }

  let depth = 0;
  let inString = false;
  let isEscaped = false;

  for (let index = startIndex; index < value.length; index += 1) {
    const char = value[index];

    if (inString) {
      if (isEscaped) {
        isEscaped = false;
        continue;
      }

      if (char === '\\') {
        isEscaped = true;
        continue;
      }

      if (char === '"') {
        inString = false;
      }

      continue;
    }

    if (char === '"') {
      inString = true;
      continue;
    }

    if (char === '{') {
      depth += 1;
      continue;
    }

    if (char === '}') {
      depth -= 1;
      if (depth === 0) {
        return value.slice(startIndex, index + 1);
      }
    }
  }

  return null;
};

const parseJsonPayload = (value: string) => {
  const normalizedValue = value
    .replace(/^```json\s*/i, '')
    .replace(/^```\s*/i, '')
    .replace(/\s*```$/i, '')
    .trim();

  if (!normalizedValue) {
    return null;
  }

  try {
    return JSON.parse(normalizedValue);
  } catch {
    const jsonCandidate = extractFirstJsonObject(normalizedValue);

    if (!jsonCandidate) {
      return null;
    }

    try {
      return JSON.parse(jsonCandidate);
    } catch {
      return null;
    }
  }
};

const normalizeCardPayload = (value: unknown, fallbackSummary: string): CardPayload | null => {
  if (!isRecord(value)) {
    return null;
  }

  const type = toOptionalText(value.type) ?? 'medical_result';
  const source = isRecord(value.data) ? value.data : value;

  if (type === 'question_options') {
    const options = Array.isArray(source.options) ? source.options.filter(opt => typeof opt === 'string') : [];
    if (options.length === 0) return null;
    return {
      type,
      data: { options },
    };
  }

  const summary = toOptionalText(source.summary) ?? toOptionalText(fallbackSummary);
  const analysis = toOptionalText(source.analysis);
  const recommendedDepartment = toOptionalText(source.recommended_department);
  const hospitalSuggestion = toOptionalText(source.hospital_suggestion);

  if (!summary && !analysis && !recommendedDepartment && !hospitalSuggestion) {
    return null;
  }

  return {
    type: 'medical_result',
    data: {
      summary,
      analysis,
      recommended_department: recommendedDepartment,
      hospital_suggestion: hospitalSuggestion,
    },
  };
};

const extractCardContent = (content: string) => {
  const openIndex = content.indexOf(CARD_OPEN_TAG);

  if (openIndex < 0) {
    // Fallback: check if the model output a JSON code block or plain JSON at the end without [CARD] tags
    const jsonMatch = content.match(/```json\s*(\{[\s\S]*?"type"\s*:\s*"(?:question_options|medical_result)"[\s\S]*?\})\s*```/i);
    if (jsonMatch) {
      console.log('Found fallback jsonMatch:', jsonMatch[1]);
      const rawPayload = jsonMatch[1];
      const textContent = normalizeTextBlock(content.replace(jsonMatch[0], '').trim());
      return {
        textContent,
        cardPayload: normalizeCardPayload(parseJsonPayload(rawPayload), textContent),
      };
    }

    const plainJsonMatch = content.match(/(\{[\s\S]*?"type"\s*:\s*"(?:question_options|medical_result)"[\s\S]*?\})\s*$/i);
    if (plainJsonMatch) {
      console.log('Found fallback plainJsonMatch:', plainJsonMatch[1]);
      const rawPayload = plainJsonMatch[1];
      const textContent = normalizeTextBlock(content.replace(plainJsonMatch[0], '').trim());
      return {
        textContent,
        cardPayload: normalizeCardPayload(parseJsonPayload(rawPayload), textContent),
      };
    }

    return {
      textContent: normalizeTextBlock(content),
      cardPayload: null as CardPayload | null,
    };
  }

  const closeIndex = content.indexOf(CARD_CLOSE_TAG, openIndex + CARD_OPEN_TAG.length);
  const beforeCard = content.slice(0, openIndex);
  const afterCard = closeIndex >= 0 ? content.slice(closeIndex + CARD_CLOSE_TAG.length) : '';
  const rawPayload = content.slice(
    openIndex + CARD_OPEN_TAG.length,
    closeIndex >= 0 ? closeIndex : content.length,
  );
  const textContent = normalizeTextBlock([beforeCard, afterCard].filter(Boolean).join('\n\n'));

  return {
    textContent,
    cardPayload: normalizeCardPayload(parseJsonPayload(rawPayload), textContent),
  };
};

const MessageRender: React.FC<MessageRenderProps> = ({
  content,
  reasoning,
  role,
  status,
  saveState = 'idle',
  onCardAction,
  safety,
  notice,
}) => {
  const [feedback, setFeedback] = useState<'like' | 'dislike' | null>(null);
  const reasoningRef = useRef<HTMLDivElement>(null);
  const isThinking = role === 'ai' && (status === 'loading' || status === 'updating');
  const normalizedReasoning = normalizeReasoning(reasoning ?? '');
  const hasReasoning = normalizedReasoning.length > 0;
  const [isExpanded, setIsExpanded] = useState(false);
  const { textContent, cardPayload } = useMemo(() => extractCardContent(content), [content]);

  const handleFeedback = (type: 'like' | 'dislike') => {
    if (feedback === type) {
      setFeedback(null);
    } else {
      setFeedback(type);
      message.success(type === 'like' ? '感谢您的评价！' : '感谢反馈，我们将持续改进。');
    }
  };

  const renderFeedback = () => {
    if (role !== 'ai') return null;
    return (
      <div className="mt-2 flex items-center justify-between gap-2 border-t border-border/50 pt-2 opacity-80">
        <span className="text-[11px] text-muted-foreground/80">{AI_WATERMARK_TEXT}</span>
        <Space size="small">
          <Button
            type="text"
            size="small"
            icon={feedback === 'like' ? <LikeFilled className="text-primary" /> : <LikeOutlined />}
            onClick={() => handleFeedback('like')}
          />
          <Button
            type="text"
            size="small"
            icon={feedback === 'dislike' ? <DislikeFilled className="text-primary" /> : <DislikeOutlined />}
            onClick={() => handleFeedback('dislike')}
          />
        </Space>
      </div>
    );
  };

  useEffect(() => {
    if (!reasoningRef.current || !hasReasoning) {
      return;
    }

    const reduceMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
    gsap.fromTo(
      reasoningRef.current,
      { opacity: 0, y: reduceMotion ? 0 : 8 },
      { opacity: 1, y: 0, duration: reduceMotion ? 0.1 : 0.3, ease: 'power4.out' },
    );
  }, [hasReasoning]);

  const renderReasoning = () => {
    if (!hasReasoning) {
      return null;
    }

    return (
      <div ref={reasoningRef} className="rounded-2xl border border-border/70 bg-muted/60 p-3 sm:p-4">
        <Think
          title={isThinking ? 'AI 正在思考' : '思考过程'}
          loading={isThinking}
          blink={isThinking}
          expanded={isExpanded}
          onExpand={setIsExpanded}
          className="bg-transparent"
          classNames={{
            status: 'rounded-xl bg-background/80 px-3 py-2 text-sm font-medium text-foreground shadow-sm',
            content: 'pt-3',
          }}
        >
          <div className="rounded-xl border border-border/60 bg-background/80 px-4 py-3 shadow-sm">
            <XMarkdown content={normalizedReasoning} />
          </div>
        </Think>
      </div>
    );
  };

  const cardDataStr = cardPayload?.type === 'medical_result' && cardPayload.data ? JSON.stringify(cardPayload.data) : '';

  React.useEffect(() => {
    if (cardDataStr) {
      try {
        notifyConsultationEnd(JSON.parse(cardDataStr));
      } catch (error) {
        console.error('Failed to notify consultation end:', error);
      }
    }
  }, [cardDataStr]);

  if (cardPayload) {
    return (
      <div className="flex flex-col gap-4">
        {renderReasoning()}
        {textContent && <XMarkdown content={textContent} />}

        {cardPayload.type === 'medical_result' && (
          <MedicalCard
            {...(cardPayload.data as MedicalCardData)}
            saveAction={{ event: { name: 'save_consultation_record' } }}
            finishAction={{ event: { name: 'finish_consultation' } }}
            saveState={saveState}
            onAction={(name, cardData) => {
              if (!cardData) {
                return;
              }
              onCardAction?.(name, cardData);
            }}
          />
        )}

        {cardPayload.type === 'question_options' && (
          <div className="flex flex-wrap gap-2 mt-2">
            {(cardPayload.data as QuestionOptionsData).options.map((option, idx) => (
              <Button
                key={idx}
                type="default"
                shape="round"
                className="border-indigo-200 text-indigo-600 hover:bg-indigo-50 hover:border-indigo-300 transition-colors"
                onClick={() => onCardAction?.('fill_input', { optionText: option })}
              >
                {option}
              </Button>
            ))}
          </div>
        )}

        {renderFeedback()}
      </div>
    );
  }

  return (
    <div className="flex flex-col gap-2">
      {safety && <div className="rounded-xl border border-amber-200 bg-amber-50 px-3 py-2 text-xs text-amber-800">安全提示：此问题涉及受限医疗内容，请咨询医生获取专业建议。</div>}
      {renderReasoning()}
      <XMarkdown content={textContent || content} />
      {notice && <div className="text-xs text-amber-600">{notice}</div>}
      {renderFeedback()}
    </div>
  );
};

export default MessageRender;
