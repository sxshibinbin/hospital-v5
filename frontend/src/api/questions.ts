export interface HighFreqQuestion {
  id: number;
  question: string;
  answer_template: string;
  category?: string;
  is_top: boolean;
  status: 'draft' | 'published' | 'disabled';
  sort_weight: number;
  click_count: number;
  created_at: string;
  updated_at: string;
}

export async function fetchPublishedQuestions(): Promise<HighFreqQuestion[]> {
  const finalUrl = import.meta.env.VITE_API_URL ? import.meta.env.VITE_API_URL.replace('/chat', '/public/questions') : '/api/public/questions';
  
  const response = await fetch(finalUrl, {
    method: 'GET',
    headers: {
      'Content-Type': 'application/json',
    },
  });

  if (!response.ok) {
    throw new Error('获取高频问题失败');
  }

  return response.json();
}
