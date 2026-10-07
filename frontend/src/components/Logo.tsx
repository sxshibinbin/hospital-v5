import React from 'react';
import cn from '@/utils/cn';

const LogoIcon: React.FC = () => <img className="w-7/10 h-7/10"  src="/favicon.webp" alt="logo" />;
const LogoContainer: React.FC<{ className?: string }> = (props) =>
<div className={cn('mx-auto mb-4 flex h-14 w-14 flex items-center justify-center rounded-2xl bg-white text-gray-800 shadow-lg', props.className)}>
  <LogoIcon />
</div>

// export default  MedicineBoxOutlined
export default LogoContainer;
