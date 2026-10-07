import { clsx, type ClassValue } from 'clsx';
import { twMerge } from 'tailwind-merge';

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs));
}

/** 手机号脱敏显示：183****8414。非标准长度的号码原样返回。 */
export function maskPhone(phone: string | null | undefined): string {
  if (!phone) return '';
  if (phone.length !== 11) return phone;
  return `${phone.slice(0, 3)}****${phone.slice(-4)}`;
}