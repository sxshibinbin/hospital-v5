# @ant-design/x-card

React card loader for dynamic content loading and management.

## Features

- 🚀 **Dynamic Loading**: Load cards asynchronously with configurable concurrency
- 🔄 **Retry Mechanism**: Automatic retry with exponential backoff
- ⚡ **Performance**: Optimized for large datasets with virtual scrolling support
- 🎨 **Customizable**: Fully customizable card rendering and loading states
- 📱 **Responsive**: Mobile-friendly responsive design
- 🔧 **TypeScript**: Full TypeScript support

## Installation

```bash
npm install @ant-design/x-card
# or
yarn add @ant-design/x-card
# or
pnpm add @ant-design/x-card
```

## Usage

### Basic Usage

```tsx
import React from 'react';
import { CardLoader } from '@ant-design/x-card';

const App = () => {
  const cards = [
    {
      id: '1',
      title: 'Card 1',
      content: 'This is card content',
    },
    {
      id: '2',
      title: 'Card 2',
      content: 'Another card content',
    },
  ];

  return <CardLoader cards={cards} />;
};
```

### Advanced Usage

```tsx
import React from 'react';
import { CardLoader, useCardLoader } from '@ant-design/x-card';

const App = () => {
  const { state, actions } = useCardLoader({
    config: {
      maxConcurrent: 5,
      retryCount: 3,
      timeout: 10000,
    },
    customLoader: async (card) => {
      // Custom loading logic
      const response = await fetch(`/api/cards/${card.id}`);
      const data = await response.json();
      return data.content;
    },
  });

  React.useEffect(() => {
    actions.loadCards([
      { id: '1', title: 'Dynamic Card 1' },
      { id: '2', title: 'Dynamic Card 2' },
    ]);
  }, []);

  return (
    <CardLoader
      cards={state.cards}
      renderLoading={(card) => <div>Loading {card.title}...</div>}
      renderError={(error, card) => <div>Error: {error.message}</div>}
    />
  );
};
```

### Using Hooks

```tsx
import React from 'react';
import { useCardLoader } from '@ant-design/x-card';

const App = () => {
  const { state, actions } = useCardLoader();

  const addNewCard = () => {
    actions.addCard({
      id: Date.now().toString(),
      title: 'New Card',
      content: 'Dynamic content',
    });
  };

  return (
    <div>
      <button onClick={addNewCard}>Add Card</button>
      {state.cards.map((card) => (
        <div key={card.id}>
          <h3>{card.title}</h3>
          <p>{card.content}</p>
        </div>
      ))}
    </div>
  );
};
```

## API

### CardLoader Props

| Property         | Type               | Default | Description                   |
| ---------------- | ------------------ | ------- | ----------------------------- |
| cards            | CardLoaderConfig[] | []      | Array of card configurations  |
| config           | CardLoaderConfig   | -       | Loader configuration          |
| customLoader     | function           | -       | Custom card loading function  |
| renderEmpty      | function           | -       | Custom empty state renderer   |
| renderLoading    | function           | -       | Custom loading state renderer |
| renderError      | function           | -       | Custom error state renderer   |
| onLoadingChange  | function           | -       | Loading state change callback |
| onCardLoad       | function           | -       | Card load success callback    |
| onCardError      | function           | -       | Card load error callback      |
| onAllCardsLoaded | function           | -       | All cards loaded callback     |

### CardLoaderConfig

| Property | Type | Default | Description |
| --- | --- | --- | --- |
| id | string | - | Unique card identifier |
| title | string | - | Card title |
| content | ReactNode | - | Card content |
| type | 'default' \| 'info' \| 'success' \| 'warning' \| 'error' | 'default' | Card type |
| loading | boolean | false | Loading state |
| closable | boolean | false | Whether card can be closed |
| size | 'small' \| 'middle' \| 'large' | 'middle' | Card size |
| disabled | boolean | false | Whether card is disabled |
| className | string | - | Custom CSS class |
| style | CSSProperties | - | Custom inline style |
| extra | ReactNode | - | Extra content in card header |

### useCardLoader Hook

Returns an object with:

- `state`: Current loader state
- `actions`: Available actions
  - `addCard(card)`: Add a new card
  - `removeCard(id)`: Remove a card
  - `updateCard(id, updates)`: Update a card
  - `reloadCard(id)`: Reload a card
  - `clearCards()`: Clear all cards
  - `getCardState(id)`: Get card state
  - `loadCards(cards)`: Load multiple cards

## Development

```bash
# Install dependencies
npm install

# Start development
npm run start

# Run tests
npm test

# Build
npm run compile
```

# A2UI v0.9

## 使用示例
- 使用 XCard 实现 A2UI v0.9 协议的基础示例。演示了如何使用 XAgentCommand_v0_9 命令配合本地 catalog.json 来创建咖啡预订场景的交互卡片。v0.9 版本引入了更简洁的命令结构和 catalog 机制。
```tsx
import { ReloadOutlined } from '@ant-design/icons';
import { Bubble } from '@ant-design/x';
import type { ActionPayload, Catalog, XAgentCommand_v0_9 } from '@ant-design/x-card';
import { registerCatalog, XCard } from '@ant-design/x-card';
import XMarkdown from '@ant-design/x-markdown';
import { Button, DatePicker, Radio, Space, Tag, Typography } from 'antd';
import dayjs, { Dayjs } from 'dayjs';
import React, { useCallback, useEffect, useRef, useState } from 'react';

// Import local catalog schema
import localCatalog from './catalog.json';

// Register local catalog
registerCatalog(localCatalog as unknown as Catalog);

const contentHeader =
  'Hello! Welcome to our online booking service 🎉\n\n Please select your preferred date and time, and we will arrange the best seat for you. We look forward to seeing you!';
const orderConfirmation =
  '✅ Booking confirmed! Your order has been confirmed. We look forward to seeing you!';

type TextNode = { text: string; timestamp: number };
type CardNode = { timestamp: number; id: string };
type ContentType = {
  texts: TextNode[];
  card: CardNode[];
};

const role = {
  assistant: {
    contentRender: (content: ContentType) => {
      const contentList = [...content.texts, ...content.card].sort(
        (a, b) => a.timestamp - b.timestamp,
      );
      return contentList.map((node, index) => {
        if ('text' in node && node.text) {
          return <XMarkdown key={index}>{node.text}</XMarkdown>;
        }

        if ('id' in node && node.id) {
          return <XCard.Card key={index} id={node.id} />;
        }
        return null;
      });
    },
  },
};

// ─── Text Component ────────────────────────────────────────────────────────────────
interface TextProps {
  text?: string;
  variant?: 'h1' | 'h2' | 'h3' | 'body' | string;
  children?: React.ReactNode;
}

const Text: React.FC<TextProps> = ({ text, variant, children }) => {
  const content = text ?? children;
  if (!content) return null;
  const styleMap: Record<string, React.CSSProperties> = {
    h1: { fontSize: 20, fontWeight: 700, margin: '0 0 12px' },
    h2: { fontSize: 17, fontWeight: 600, margin: '0 0 8px' },
    h3: { fontSize: 15, fontWeight: 600, margin: '0 0 6px' },
    body: { fontSize: 14, margin: 0 },
    success: {
      fontSize: 14,
      fontWeight: 600,
      color: '#52c41a',
      margin: '4px 0 0',
      padding: '6px 10px',
      borderRadius: 8,
      background: '#f6ffed',
      border: '1px solid #b7eb8f',
    },
  };
  const style = styleMap[variant ?? 'body'] ?? styleMap.body;
  return <p style={style}>{content}</p>;
};

// ─── DateTimeInput Component ───────────────────────────────────────────────────────
interface DateTimeInputProps {
  action?: {
    event?: {
      name?: string;
      context?: Record<string, any>;
    };
  };
  status?: 'success';
  onAction?: (name: string, context: Record<string, any>) => void;
}

const DateTimeInput: React.FC<DateTimeInputProps> = ({ action, onAction, status }) => {
  const [dateValue, setDateValue] = useState<Dayjs | null>(dayjs());
  const disabled = status === 'success';

  const handleChange = (val: Dayjs | null) => {
    setDateValue(val);
    if (!action?.event?.name || !val) return;

    // Construct context based on action.event.context keys
    const context: Record<string, any> = {};
    if (action.event.context) {
      // The key in context is the data field that the component needs to pass
      // For example, { time: { path: '/booking/res/time' } } contains 'time'
      Object.keys(action.event.context).forEach((key) => {
        context[key] = val.toISOString();
      });
    }

    onAction?.(action.event.name, context);
  };

  return (
    <DatePicker
      value={dateValue}
      disabled={disabled}
      onChange={handleChange}
      format="YYYY-MM-DD"
      placeholder="Select date"
      style={{ width: '100%' }}
    />
  );
};

// ─── BookForm Component ────────────────────────────────────────────────────────────
interface BookFormProps {
  children?: React.ReactNode;
}

const BookForm: React.FC<BookFormProps> = ({ children }) => {
  return (
    <div
      style={{
        borderRadius: 16,
        border: '1.5px solid #e8e8e8',
        padding: '20px 20px 16px',
        background: '#fff',
        boxShadow: '0 2px 12px rgba(0,0,0,0.06)',
        minWidth: 280,
        marginBlock: 16,
        maxWidth: 400,
      }}
    >
      <Space vertical style={{ width: '100%' }} size={12}>
        {children}
      </Space>
    </div>
  );
};

interface ActionButtonProps {
  action?: {
    event?: {
      name?: string;
      context?: Record<string, any>;
    };
  };
  onAction?: (name: string, context: Record<string, any>) => void;
  variant?: string;
  children?: React.ReactNode;
  status?: 'success' | 'error' | 'loading';
  res?: any; // res data bound from dataModel
  [key: string]: any;
}

const ActionButton: React.FC<ActionButtonProps> = ({
  action,
  onAction,
  variant,
  status: currentStatus,
  children,
  res,
  ...rest
}) => {
  const handleClick = () => {
    const eventName = action?.event?.name;
    if (!eventName || !onAction) return;

    // Business logic validation: determine status based on res data
    // res and status are both passed as props after being resolved from dataModel by resolvePropsV09
    const context: Record<string, any> = {};
    if (!res?.time || !res?.coffee) {
      context.status = 'error';
      context.errorMessage = 'Please select date and coffee first';
    } else {
      context.status = 'success';
      context.res = res;
    }

    onAction(eventName, context);
  };

  return (
    <Button
      {...rest}
      disabled={currentStatus === 'success'}
      type={variant === 'primary' ? 'primary' : undefined}
      onClick={handleClick}
    >
      {children}
    </Button>
  );
};

// ─── CoffeeList Component ──────────────────────────────────────────────────────────
interface CoffeeItem {
  id?: string | number;
  name: string;
  description?: string;
  price?: number | string;
  image?: string;
  tag?: string;
}

interface CoffeeListProps {
  list?: CoffeeItem[];
  description?: string;
  /** Currently selected item id (controlled) */
  value?: string | number;
  status?: 'success';
  /** Card internal action trigger */
  onAction?: (name: string, context: Record<string, any>) => void;
  action?: {
    event?: {
      name?: string;
      context?: Record<string, any>;
    };
  };
}

const CoffeeList: React.FC<CoffeeListProps> = ({ list, description, onAction, status, action }) => {
  if (!list || list.length === 0) return null;

  const handleSelect = (itemId: string | number) => {
    if (!action?.event?.name) return;

    const selectedCoffee = list.find((item, index) => (item.id ?? index) === itemId);
    if (!selectedCoffee) return;

    // Construct context based on action.event.context keys
    const context: Record<string, any> = {};
    if (action.event.context) {
      Object.keys(action.event.context).forEach((key) => {
        // The key in context is the data field that the component needs to pass
        // For example, { coffee: { path: '/booking/res/coffee' } } contains 'coffee'
        context[key] = selectedCoffee;
      });
    }

    onAction?.(action.event.name, context);
  };

  return (
    <div
      style={{
        display: 'flex',
        flexDirection: 'column',
        gap: 8,
      }}
    >
      {description && (
        <Typography.Text type="secondary" style={{ fontSize: 13 }}>
          📋 {description}
        </Typography.Text>
      )}
      <Radio.Group
        onChange={(e) => handleSelect(e.target.value)}
        style={{ width: '100%', display: 'flex', flexDirection: 'column', gap: 10 }}
        disabled={status === 'success'}
        options={list.map((item, index) => ({
          value: item.id ?? index,
          label: (
            <div
              style={{
                display: 'flex',
                alignItems: 'center',
                width: 300,
                gap: 12,
                padding: '10px 12px',
                borderRadius: 12,
                background: '#fafafa',
                border: '1px solid #f0f0f0',
                transition: 'background 0.2s',
              }}
            >
              {/* Image / Placeholder icon */}
              <div
                style={{
                  width: 48,
                  height: 48,
                  borderRadius: 10,
                  background: 'linear-gradient(135deg, #6b3520 0%, #c8855a 100%)',
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  flexShrink: 0,
                  overflow: 'hidden',
                }}
              >
                {item.image ? (
                  <img
                    src={item.image}
                    alt={item.name}
                    style={{ width: '100%', height: '100%', objectFit: 'cover' }}
                  />
                ) : (
                  <span style={{ fontSize: 24 }}>☕</span>
                )}
              </div>

              {/* Text information */}
              <div style={{ flex: 1, minWidth: 0 }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: 6, marginBottom: 2 }}>
                  <Typography.Text
                    strong
                    style={{ fontSize: 14, color: '#1a1a1a', lineHeight: '20px' }}
                  >
                    {item.name}
                  </Typography.Text>
                  {item.tag && (
                    <Tag
                      style={{
                        fontSize: 11,
                        padding: '0 6px',
                        lineHeight: '18px',
                        borderRadius: 8,
                        color: '#d46b08',
                        background: '#fff7e6',
                        border: '1px solid #ffd591',
                        margin: 0,
                      }}
                    >
                      {item.tag}
                    </Tag>
                  )}
                </div>
                {item.description && (
                  <Typography.Text
                    type="secondary"
                    style={{ fontSize: 12, lineHeight: '18px', display: 'block' }}
                    ellipsis
                  >
                    {item.description}
                  </Typography.Text>
                )}
              </div>

              {/* Price */}
              {item.price !== undefined && (
                <Typography.Text
                  style={{
                    fontSize: 15,
                    fontWeight: 700,
                    color: '#d46b08',
                    flexShrink: 0,
                    whiteSpace: 'nowrap',
                  }}
                >
                  ¥{item.price}
                </Typography.Text>
              )}
            </div>
          ),
        }))}
      />
    </div>
  );
};

// ─── CoffeeResultCard Component ────────────────────────────────────────────────────
interface CoffeeResultCardProps {
  name?: string;
  description?: string;
  price?: number | string;
  tag?: string;
  image?: string;
  date?: string;
}

const CoffeeResultCard: React.FC<CoffeeResultCardProps> = ({
  name,
  description,
  price,
  tag,
  image,
  date,
}) => {
  const formattedDate = date ? dayjs(date).format('YYYY-MM-DD HH:mm') : '';

  return (
    <div
      style={{
        borderRadius: 20,
        overflow: 'hidden',
        background: 'linear-gradient(145deg, #3d1f0d 0%, #6b3520 50%, #8b5a2b 100%)',
        boxShadow: '0 8px 32px rgba(61,31,13,0.35)',
        minWidth: 280,
        maxWidth: 380,
        position: 'relative',
      }}
    >
      {/* Top decorative glow */}
      <div
        style={{
          position: 'absolute',
          top: -40,
          right: -40,
          width: 160,
          height: 160,
          borderRadius: '50%',
          background: 'rgba(255,255,255,0.06)',
          pointerEvents: 'none',
        }}
      />

      {/* Coffee icon area */}
      <div
        style={{
          display: 'flex',
          justifyContent: 'center',
          alignItems: 'center',
          padding: '28px 24px 16px',
          position: 'relative',
        }}
      >
        <div
          style={{
            width: 80,
            height: 80,
            borderRadius: 20,
            background: 'rgba(255,255,255,0.12)',
            border: '2px solid rgba(255,255,255,0.2)',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            overflow: 'hidden',
            boxShadow: '0 4px 16px rgba(0,0,0,0.3)',
          }}
        >
          {image ? (
            <img
              src={image}
              alt={name}
              style={{ width: '100%', height: '100%', objectFit: 'cover' }}
            />
          ) : (
            <span style={{ fontSize: 40 }}>☕</span>
          )}
        </div>
      </div>

      {/* Content area */}
      <div style={{ padding: '0 24px 24px' }}>
        {/* Title row */}
        <div
          style={{
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            gap: 8,
            marginBottom: 8,
          }}
        >
          <Typography.Text
            style={{
              fontSize: 22,
              fontWeight: 700,
              color: '#fff',
              letterSpacing: 0.5,
            }}
          >
            {name ?? 'Unknown Coffee'}
          </Typography.Text>
          {tag && (
            <Tag
              style={{
                background: 'rgba(255,200,100,0.25)',
                border: '1px solid rgba(255,200,100,0.5)',
                color: '#ffd580',
                fontSize: 11,
                padding: '0 7px',
                lineHeight: '20px',
                borderRadius: 10,
              }}
            >
              {tag}
            </Tag>
          )}
        </div>

        {/* Description */}
        {description && (
          <Typography.Text
            style={{
              display: 'block',
              textAlign: 'center',
              fontSize: 13,
              color: 'rgba(255,255,255,0.65)',
              marginBottom: 16,
            }}
          >
            {description}
          </Typography.Text>
        )}

        {/* Divider */}
        <div
          style={{
            height: 1,
            background: 'rgba(255,255,255,0.12)',
            margin: '0 0 16px',
          }}
        />

        {/* Price & date info */}
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
          {price !== undefined ? (
            <div>
              <Typography.Text
                style={{ fontSize: 11, color: 'rgba(255,255,255,0.5)', display: 'block' }}
              >
                Price
              </Typography.Text>
              <Typography.Text style={{ fontSize: 20, fontWeight: 700, color: '#ffd580' }}>
                ¥{price}
              </Typography.Text>
            </div>
          ) : (
            <div />
          )}

          {formattedDate && (
            <div style={{ textAlign: 'right' }}>
              <Typography.Text
                style={{ fontSize: 11, color: 'rgba(255,255,255,0.5)', display: 'block' }}
              >
                Booking Time
              </Typography.Text>
              <Typography.Text style={{ fontSize: 12, color: 'rgba(255,255,255,0.85)' }}>
                {formattedDate}
              </Typography.Text>
            </div>
          )}
        </div>

        {/* Bottom success tag */}
        <div
          style={{
            marginTop: 16,
            padding: '8px 14px',
            borderRadius: 12,
            background: 'rgba(82,196,26,0.15)',
            border: '1px solid rgba(82,196,26,0.35)',
            display: 'flex',
            alignItems: 'center',
            gap: 6,
          }}
        >
          <span style={{ fontSize: 14 }}>✅</span>
          <Typography.Text style={{ fontSize: 13, color: '#95de64', fontWeight: 500 }}>
            Booking confirmed! We look forward to seeing you!
          </Typography.Text>
        </div>
      </div>
    </div>
  );
};

// ─── Streaming Text Hook ────────────────────────────────────────────────────────────
const useStreamText = (text: string) => {
  const textRef = React.useRef(0);
  const [textIndex, setTextIndex] = React.useState(0);
  const textTimestamp = React.useRef(0);
  const [streamStatus, setStreamStatus] = useState('INIT');
  const timerRef = useRef<NodeJS.Timeout | null>(null);

  const run = useCallback(() => {
    if (timerRef.current) {
      clearInterval(timerRef.current);
    }

    timerRef.current = setInterval(() => {
      if (textRef.current < text.length) {
        if (textTimestamp.current === 0) {
          textTimestamp.current = Date.now();
          setStreamStatus('RUNNING');
        }
        textRef.current = Math.min(textRef.current + 3, text.length);
        setTextIndex(textRef.current);
      } else {
        setStreamStatus('FINISHED');
        if (timerRef.current) {
          clearInterval(timerRef.current);
        }
      }
    }, 100);
  }, [text]);

  const reset = useCallback(() => {
    if (timerRef.current) {
      clearInterval(timerRef.current);
      timerRef.current = null;
    }
    textRef.current = 0;
    textTimestamp.current = 0;
    setTextIndex(0);
    setStreamStatus('INIT');
  }, []);

  return {
    text: text.slice(0, textIndex),
    streamStatus,
    timestamp: textTimestamp.current,
    run,
    reset,
  };
};

// ─── Agent Commands ───────────────────────────────────────────────────────────────
const CreateCard: XAgentCommand_v0_9 = {
  version: 'v0.9',
  createSurface: {
    surfaceId: 'booking',
    catalogId: 'local://coffee_booking_catalog.json',
  },
};

const UpdateCard: XAgentCommand_v0_9 = {
  version: 'v0.9',
  updateComponents: {
    surfaceId: 'booking',
    components: [
      {
        id: 'title',
        component: 'Text',
        text: 'Coffee Shop Order',
        variant: 'h1',
      },
      {
        id: 'datetime',
        component: 'DateTimeInput',
        status: { path: '/booking/status' },
        action: {
          event: {
            name: 'select_date',
            context: {
              time: {
                path: '/booking/res/time',
              },
            },
          },
        },
      },
      {
        id: 'submit-text',
        component: 'Text',
        text: 'Confirm Order',
      },
      {
        component: 'CoffeeList',
        status: { path: '/booking/status' },
        list: { path: '/booking/list/data' },
        description: { path: '/booking/list/description' },
        id: 'coffee_list',
        action: {
          event: {
            name: 'select_coffee',
            context: {
              coffee: {
                path: '/booking/res/coffee',
              },
            },
          },
        },
      },
      {
        id: 'status-text',
        component: 'Text',
        status: { path: '/booking/status' },
        variant: 'success',
      },
      {
        id: 'submit-btn',
        component: 'ActionButton',
        child: 'submit-text',
        variant: 'primary',
        status: { path: '/booking/status' },
        res: { path: '/booking/res' },
        action: {
          event: {
            name: 'confirm_booking',
            context: {
              status: {
                path: '/booking/status',
              },
              res: {
                path: '/booking/res',
              },
            },
          },
        },
      },
      {
        id: 'root',
        component: 'BookForm',
        children: ['title', 'datetime', 'coffee_list', 'status-text', 'submit-btn'],
      },
    ],
  },
};

const UpdateModel: XAgentCommand_v0_9 = {
  version: 'v0.9',
  updateDataModel: {
    surfaceId: 'booking',
    path: '/booking',
    value: {
      res: {
        time: new Date().toISOString(), // Initialize to current date
      },
      list: {
        description: 'Coffee List',
        data: [
          {
            id: 1,
            name: 'Latte',
            description: 'Espresso + Steamed Milk, smooth and silky',
            price: 32,
            tag: 'Hot',
          },
          { id: 2, name: 'Americano', description: 'Pure bitter aroma, refreshing', price: 25 },
          {
            id: 3,
            name: 'Cappuccino',
            description: 'Rich foam, classic Italian style',
            price: 30,
            tag: 'Recommended',
          },
        ],
      },
    },
  },
};

// ─── Result Card Configuration ─────────────────────────────────────────────────────
const CreateResultCard: XAgentCommand_v0_9 = {
  version: 'v0.9',
  createSurface: {
    surfaceId: 'result',
    catalogId: 'local://coffee_booking_catalog.json',
  },
};

const UpdateResultCard = (res: any): XAgentCommand_v0_9 => {
  return {
    version: 'v0.9',
    updateComponents: {
      surfaceId: 'result',
      components: [
        {
          id: 'result-card',
          component: 'CoffeeResultCard',
          name: res?.coffee?.name,
          description: res?.coffee?.description,
          price: res?.coffee?.price,
          tag: res?.coffee?.tag,
          image: res?.coffee?.image,
          date: res?.time,
        },
        {
          id: 'root',
          component: 'BookForm',
          children: ['result-card'],
        },
      ],
    },
  };
};

// ─── App ──────────────────────────────────────────────────────────────────────
const App = () => {
  const [card, setCard] = useState<CardNode[]>([]);
  // Command queue: each time a new command is appended, the entire array reference changes to trigger Box/Card's useEffect
  const [commandQueue, setCommandQueue] = useState<XAgentCommand_v0_9[]>([]);
  const [sessionKey, setSessionKey] = useState(0);

  const onAgentCommand = (command: XAgentCommand_v0_9) => {
    if ('createSurface' in command) {
      const surfaceId = command.createSurface.surfaceId;
      setCard((prev) => {
        if (prev.some((c) => c.id === surfaceId)) return prev;
        return [...prev, { id: surfaceId, timestamp: Date.now() }];
      });
    } else if ('deleteSurface' in command) {
      setCard((prev) => prev.filter((c) => c.id !== command.deleteSurface.surfaceId));
    }
    // Append to end of queue, ensuring each command is processed by Box/Card
    setCommandQueue((prev) => [...prev, command]);
  };

  /** Handle Card internal action events (fully automated) */
  const handleAction = (payload: ActionPayload) => {
    if (payload.name === 'confirm_booking') {
      const { res, status } = payload.context || {};

      // Only show result card on success
      if (status === 'success' && res) {
        // 1. Show confirmation text
        runFooter();

        // 2. Delete booking form card
        onAgentCommand({
          version: 'v0.9',
          deleteSurface: {
            surfaceId: 'booking',
          },
        });

        // 3. Create and update result card
        onAgentCommand(CreateResultCard);
        onAgentCommand(UpdateResultCard(res));
      } else if (status === 'error') {
        console.log('❌ Booking failed:', payload.context?.errorMessage);
      }
    }
  };

  const {
    text: textHeader,
    streamStatus: streamStatusHeader,
    timestamp: timestampHeader,
    run: runHeader,
    reset: resetHeader,
  } = useStreamText(contentHeader);

  const {
    text: textFooter,
    timestamp: timestampFooter,
    run: runFooter,
    reset: resetFooter,
  } = useStreamText(orderConfirmation);

  useEffect(() => {
    runHeader();
  }, [sessionKey, runHeader]);

  useEffect(() => {
    if (streamStatusHeader === 'FINISHED') {
      // Send commands in A2UI v0.9 spec order, command queue ensures sequential processing, no setTimeout needed
      onAgentCommand(CreateCard);
      onAgentCommand(UpdateCard);
      onAgentCommand(UpdateModel);
    }
  }, [streamStatusHeader, sessionKey]);

  // Reload (complete reset)
  const handleReload = useCallback(() => {
    resetHeader();
    resetFooter();

    // Drive Surface cleanup via deleteSurface command
    const deleteCommands: XAgentCommand_v0_9[] = [
      { version: 'v0.9', deleteSurface: { surfaceId: 'booking' } },
      { version: 'v0.9', deleteSurface: { surfaceId: 'result' } },
    ];
    setCommandQueue((prev) => [...prev, ...deleteCommands]);
    setCard([]);

    setTimeout(() => {
      setSessionKey((prev) => prev + 1);
    }, 50);
  }, [resetHeader, resetFooter]);

  const items = [
    {
      content: {
        texts: [
          { text: textHeader, timestamp: timestampHeader },
          { text: textFooter, timestamp: timestampFooter },
        ].filter((item) => item.timestamp !== 0),
        card,
      } as ContentType,
      role: 'assistant',
      key: sessionKey,
    },
  ];

  return (
    <div>
      <div style={{ marginBottom: 16 }}>
        <Button type="primary" icon={<ReloadOutlined />} onClick={handleReload}>
          Reload
        </Button>
      </div>

      <XCard.Box
        key={sessionKey}
        commands={commandQueue}
        onAction={handleAction}
        components={{
          Text,
          DateTimeInput,
          BookForm,
          ActionButton,
          CoffeeList,
          CoffeeResultCard,
        }}
      >
        <Bubble.List items={items} style={{ height: 620 }} role={role} />
      </XCard.Box>
    </div>
  );
};

export default App;
```

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "local://coffee_booking_catalog.json",
  "title": "Coffee Booking Catalog",
  "description": "Custom catalog for coffee booking demo components.",
  "catalogId": "local://coffee_booking_catalog.json",
  "components": {
    "Text": {
      "type": "object",
      "properties": {
        "component": {
          "const": "Text"
        },
        "text": {
          "description": "The text content to display.",
          "oneOf": [
            {
              "type": "string"
            },
            {
              "type": "object",
              "properties": {
                "path": {
                  "type": "string"
                }
              },
              "required": ["path"],
              "additionalProperties": false
            }
          ]
        },
        "variant": {
          "type": "string",
          "description": "A hint for the base text style.",
          "enum": ["h1", "h2", "h3", "body", "success"]
        },
        "status": {
          "description": "The status of the text (for conditional styling).",
          "oneOf": [
            {
              "type": "string"
            },
            {
              "type": "object",
              "properties": {
                "path": {
                  "type": "string"
                }
              },
              "required": ["path"],
              "additionalProperties": false
            }
          ]
        }
      },
      "required": ["component"],
      "additionalProperties": true
    },
    "DateTimeInput": {
      "type": "object",
      "properties": {
        "component": {
          "const": "DateTimeInput"
        },
        "status": {
          "description": "The status of the input (success, error, loading).",
          "oneOf": [
            {
              "type": "string"
            },
            {
              "type": "object",
              "properties": {
                "path": {
                  "type": "string"
                }
              },
              "required": ["path"],
              "additionalProperties": false
            }
          ]
        },
        "action": {
          "type": "object",
          "description": "Action configuration for date selection.",
          "properties": {
            "event": {
              "type": "object",
              "properties": {
                "name": {
                  "type": "string",
                  "description": "Event name"
                },
                "context": {
                  "type": "object",
                  "description": "Event context with path bindings",
                  "additionalProperties": true
                }
              },
              "required": ["name"]
            }
          },
          "required": ["event"]
        }
      },
      "required": ["component"],
      "additionalProperties": true
    },
    "CoffeeList": {
      "type": "object",
      "properties": {
        "component": {
          "const": "CoffeeList"
        },
        "list": {
          "description": "Coffee list data.",
          "oneOf": [
            {
              "type": "array"
            },
            {
              "type": "object",
              "properties": {
                "path": {
                  "type": "string"
                }
              },
              "required": ["path"],
              "additionalProperties": false
            }
          ]
        },
        "description": {
          "description": "Description text for the coffee list.",
          "oneOf": [
            {
              "type": "string"
            },
            {
              "type": "object",
              "properties": {
                "path": {
                  "type": "string"
                }
              },
              "required": ["path"],
              "additionalProperties": false
            }
          ]
        },
        "status": {
          "description": "The status of the list.",
          "oneOf": [
            {
              "type": "string"
            },
            {
              "type": "object",
              "properties": {
                "path": {
                  "type": "string"
                }
              },
              "required": ["path"],
              "additionalProperties": false
            }
          ]
        },
        "action": {
          "type": "object",
          "description": "Action configuration for coffee selection.",
          "properties": {
            "event": {
              "type": "object",
              "properties": {
                "name": {
                  "type": "string",
                  "description": "Event name"
                },
                "context": {
                  "type": "object",
                  "description": "Event context with path bindings",
                  "additionalProperties": true
                }
              },
              "required": ["name"]
            }
          },
          "required": ["event"]
        }
      },
      "required": ["component"],
      "additionalProperties": true
    },
    "ActionButton": {
      "type": "object",
      "properties": {
        "component": {
          "const": "ActionButton"
        },
        "child": {
          "type": "string",
          "description": "The ID of the child component (e.g., text label)."
        },
        "variant": {
          "type": "string",
          "description": "Button style variant.",
          "enum": ["default", "primary"]
        },
        "status": {
          "description": "The status of the button.",
          "oneOf": [
            {
              "type": "string"
            },
            {
              "type": "object",
              "properties": {
                "path": {
                  "type": "string"
                }
              },
              "required": ["path"],
              "additionalProperties": false
            }
          ]
        },
        "res": {
          "description": "Result data from dataModel.",
          "type": "object",
          "properties": {
            "path": {
              "type": "string"
            }
          },
          "required": ["path"],
          "additionalProperties": false
        },
        "action": {
          "type": "object",
          "description": "Action configuration for button click.",
          "properties": {
            "event": {
              "type": "object",
              "properties": {
                "name": {
                  "type": "string",
                  "description": "Event name"
                },
                "context": {
                  "type": "object",
                  "description": "Event context with path bindings or literal values",
                  "additionalProperties": true
                }
              },
              "required": ["name"]
            }
          },
          "required": ["event"]
        }
      },
      "required": ["component", "action"],
      "additionalProperties": true
    },
    "BookForm": {
      "type": "object",
      "description": "A form container component.",
      "properties": {
        "component": {
          "const": "BookForm"
        },
        "children": {
          "type": "array",
          "description": "Child component IDs.",
          "items": {
            "type": "string"
          }
        }
      },
      "required": ["component"],
      "additionalProperties": true
    },
    "CoffeeResultCard": {
      "type": "object",
      "description": "A card to display booking result.",
      "properties": {
        "component": {
          "const": "CoffeeResultCard"
        },
        "name": {
          "type": "string",
          "description": "Coffee name"
        },
        "description": {
          "type": "string",
          "description": "Coffee description"
        },
        "price": {
          "oneOf": [
            {
              "type": "number"
            },
            {
              "type": "string"
            }
          ],
          "description": "Coffee price"
        },
        "tag": {
          "type": "string",
          "description": "Tag label (e.g., '热销')"
        },
        "image": {
          "type": "string",
          "description": "Coffee image URL"
        },
        "date": {
          "type": "string",
          "description": "Booking date"
        }
      },
      "required": ["component"],
      "additionalProperties": true
    },
    "ProductCard": {
      "type": "object",
      "description": "A card to display product information.",
      "properties": {
        "component": {
          "const": "ProductCard"
        },
        "name": {
          "type": "string",
          "description": "Product name"
        },
        "price": {
          "type": "number",
          "description": "Product price"
        },
        "category": {
          "type": "string",
          "description": "Product category"
        },
        "stock": {
          "type": "number",
          "description": "Product stock quantity"
        },
        "tag": {
          "type": "string",
          "description": "Tag label (e.g., '热销')"
        },
        "index": {
          "type": "number",
          "description": "Index for animation delay"
        }
      },
      "required": ["component"],
      "additionalProperties": true
    },
    "ProductContainer": {
      "type": "object",
      "description": "A container for product cards.",
      "properties": {
        "component": {
          "const": "ProductContainer"
        },
        "children": {
          "type": "array",
          "description": "Child component IDs.",
          "items": {
            "type": "string"
          }
        }
      },
      "required": ["component"],
      "additionalProperties": true
    },
    "LoadingIndicator": {
      "type": "object",
      "description": "A loading progress indicator.",
      "properties": {
        "component": {
          "const": "LoadingIndicator"
        },
        "progress": {
          "type": "number",
          "description": "Current progress count"
        },
        "total": {
          "type": "number",
          "description": "Total count"
        },
        "loading": {
          "type": "boolean",
          "description": "Loading status"
        }
      },
      "required": ["component"],
      "additionalProperties": true
    }
  },
  "functions": {},
  "$defs": {
    "DynamicValue": {
      "oneOf": [
        {
          "type": "string"
        },
        {
          "type": "number"
        },
        {
          "type": "boolean"
        },
        {
          "type": "object",
          "properties": {
            "path": {
              "type": "string"
            }
          },
          "required": ["path"],
          "additionalProperties": false
        }
      ]
    }
  }
}

```

- 使用 XCard 实现 A2UI v0.9 协议的流式内容与实时更新示例。演示了 AI 推荐结果的流式展示、组件逐步加载动画和加载进度指示，配合 catalog 机制。
```tsx
import { ReloadOutlined } from '@ant-design/icons';
import { Bubble } from '@ant-design/x';
import type { Catalog, XAgentCommand_v0_9 } from '@ant-design/x-card';
import { registerCatalog, XCard } from '@ant-design/x-card';
import XMarkdown from '@ant-design/x-markdown';
import { Button, Card, List, Progress, Rate, Spin, Tag, Typography } from 'antd';
import React, { useCallback, useEffect, useRef, useState } from 'react';

// Import local catalog schema
import localCatalog from './catalog-streaming.json';

// Register local catalog
registerCatalog(localCatalog as unknown as Catalog);

// ─── Type Definitions ────────────────────────────────────────────────────────────────────
type TextNode = { text: string; timestamp: number };
type CardNode = { timestamp: number; id: string };
type ContentType = {
  texts: TextNode[];
  card: CardNode[];
};

const role = {
  assistant: {
    contentRender: (content: ContentType) => {
      const contentList = [...content.texts, ...content.card].sort(
        (a, b) => a.timestamp - b.timestamp,
      );
      return contentList.map((node, index) => {
        if ('text' in node && node.text) {
          return <XMarkdown key={index}>{node.text}</XMarkdown>;
        }

        if ('id' in node && node.id) {
          return <XCard.Card key={index} id={node.id} />;
        }
        return null;
      });
    },
  },
};

// ─── Restaurant Data ────────────────────────────────────────────────────────────────────
interface RestaurantItem {
  id: string;
  name: string;
  cuisine: string;
  rating: number;
  priceRange: string;
  distance: string;
  tags: string[];
  description: string;
  image?: string;
}

const RESTAURANT_DATA: RestaurantItem[] = [
  {
    id: 'r1',
    name: 'Jiangnan Bistro',
    cuisine: 'Jiangsu-Zhejiang',
    rating: 4.8,
    priceRange: '¥80-150',
    distance: '500m',
    tags: ['Local Cuisine', 'Elegant Ambiance'],
    description:
      'Authentic Jiangsu-Zhejiang flavors with locally sourced ingredients. Signature dishes: Braised Pork, Steamed Sea Bass.',
  },
  {
    id: 'r2',
    name: 'Sichuan House',
    cuisine: 'Sichuan',
    rating: 4.6,
    priceRange: '¥60-120',
    distance: '800m',
    tags: ['Spicy & Flavorful', 'Great Value'],
    description:
      'Authentic Sichuan cuisine, spicy and aromatic. Recommended: Boiled Fish, Mapo Tofu, Twice-cooked Pork.',
  },
  {
    id: 'r3',
    name: 'Sakura Japanese',
    cuisine: 'Japanese',
    rating: 4.9,
    priceRange: '¥150-300',
    distance: '1.2km',
    tags: ['Exquisite Cuisine', 'Perfect for Dates'],
    description:
      'Fresh sashimi, exquisite sushi, fusion of traditional and modern Japanese. Chef from Tokyo Ginza.',
  },
  {
    id: 'r4',
    name: 'Italian Garden',
    cuisine: 'Western',
    rating: 4.5,
    priceRange: '¥120-250',
    distance: '900m',
    tags: ['Romantic Atmosphere', 'Handmade Pasta'],
    description:
      'Authentic Italian flavors, handmade pasta with imported ingredients. Signature: Creamy Mushroom Pasta, Tiramisu.',
  },
];

// ─── Text Component ────────────────────────────────────────────────────────────────
interface TextProps {
  text?: string;
  variant?: 'h1' | 'h2' | 'h3' | 'body' | 'success' | string;
  children?: React.ReactNode;
  status?: string;
}

const Text: React.FC<TextProps> = ({ text, variant, children, status }) => {
  const content = text ?? children;
  if (!content) return null;
  const styleMap: Record<string, React.CSSProperties> = {
    h1: { fontSize: 20, fontWeight: 700, margin: '0 0 12px' },
    h2: { fontSize: 17, fontWeight: 600, margin: '0 0 8px' },
    h3: { fontSize: 15, fontWeight: 600, margin: '0 0 6px' },
    body: { fontSize: 14, margin: 0 },
    success: {
      fontSize: 14,
      fontWeight: 600,
      color: '#52c41a',
      margin: '4px 0 0',
      padding: '6px 10px',
      borderRadius: 8,
      background: '#f6ffed',
      border: '1px solid #b7eb8f',
    },
  };
  const style = styleMap[variant ?? 'body'] ?? styleMap.body;
  const finalStyle = status === 'success' ? styleMap.success : style;

  return <p style={finalStyle}>{content}</p>;
};

// ─── LoadingProgress Component ──────────────────────────────────────────────────────
interface LoadingProgressProps {
  percent?: number;
  status?: 'active' | 'success' | 'normal';
  text?: string;
}

const LoadingProgress: React.FC<LoadingProgressProps> = ({
  percent = 0,
  status = 'active',
  text,
}) => {
  return (
    <div
      style={{
        padding: '16px 20px',
        background: '#fff',
        borderRadius: 12,
        border: '1px solid #f0f0f0',
        marginBottom: 16,
        minWidth: 320,
        maxWidth: 480,
      }}
    >
      <div style={{ marginBottom: 8, display: 'flex', justifyContent: 'space-between' }}>
        <Typography.Text type="secondary" style={{ fontSize: 13 }}>
          {text || 'Loading recommendations...'}
        </Typography.Text>
        <Typography.Text style={{ fontSize: 13, fontWeight: 500 }}>
          {Math.round(percent)}%
        </Typography.Text>
      </div>
      <Progress
        percent={percent}
        status={status}
        showInfo={false}
        strokeColor={{
          '0%': '#108ee9',
          '100%': '#87d068',
        }}
      />
    </div>
  );
};

// ─── RestaurantCard Component ────────────────────────────────────────────────────────
interface RestaurantCardProps {
  restaurant?: RestaurantItem;
  index?: number;
  isLoading?: boolean;
}

const RestaurantCard: React.FC<RestaurantCardProps> = ({ restaurant, index = 0, isLoading }) => {
  const [visible, setVisible] = useState(false);

  useEffect(() => {
    if (!isLoading && restaurant) {
      // Staggered loading animation delay
      const timer = setTimeout(() => {
        setVisible(true);
      }, index * 200);
      return () => clearTimeout(timer);
    }
  }, [isLoading, restaurant, index]);

  if (isLoading) {
    return (
      <Card
        style={{
          width: '100%',
          borderRadius: 12,
          opacity: 0.6,
        }}
      >
        <div style={{ display: 'flex', justifyContent: 'center', padding: 20 }}>
          <Spin tip="Loading..." />
        </div>
      </Card>
    );
  }

  if (!restaurant) return null;

  return (
    <Card
      style={{
        width: '100%',
        borderRadius: 12,
        boxShadow: '0 2px 8px rgba(0,0,0,0.06)',
        opacity: visible ? 1 : 0,
        transform: visible ? 'translateY(0)' : 'translateY(20px)',
        transition: 'all 0.4s ease-out',
        marginBottom: 12,
      }}
      styles={{ body: { padding: '16px 20px' } }}
    >
      <div style={{ display: 'flex', gap: 16 }}>
        {/* Left icon */}
        <div
          style={{
            width: 64,
            height: 64,
            borderRadius: 12,
            background: 'linear-gradient(135deg, #667eea 0%, #764ba2 100%)',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            flexShrink: 0,
            fontSize: 28,
          }}
        >
          🍽️
        </div>

        {/* Right content */}
        <div style={{ flex: 1, minWidth: 0 }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 4 }}>
            <Typography.Text strong style={{ fontSize: 16 }}>
              {restaurant.name}
            </Typography.Text>
            <Tag color="blue" style={{ margin: 0 }}>
              {restaurant.cuisine}
            </Tag>
          </div>

          <div style={{ display: 'flex', alignItems: 'center', gap: 12, marginBottom: 6 }}>
            <Rate disabled defaultValue={restaurant.rating} style={{ fontSize: 12 }} />
            <Typography.Text style={{ fontSize: 13, color: '#faad14' }}>
              {restaurant.rating}
            </Typography.Text>
            <Typography.Text type="secondary" style={{ fontSize: 12 }}>
              | {restaurant.distance}
            </Typography.Text>
            <Typography.Text style={{ fontSize: 13, color: '#52c41a' }}>
              {restaurant.priceRange}
            </Typography.Text>
          </div>

          <Typography.Text
            type="secondary"
            style={{ fontSize: 12, display: 'block', marginBottom: 8 }}
            ellipsis
          >
            {restaurant.description}
          </Typography.Text>

          <div style={{ display: 'flex', gap: 6 }}>
            {restaurant.tags.map((tag, i) => (
              <Tag
                key={i}
                style={{
                  fontSize: 11,
                  borderRadius: 6,
                  background: '#f5f5f5',
                  border: 'none',
                  margin: 0,
                }}
              >
                {tag}
              </Tag>
            ))}
          </div>
        </div>
      </div>
    </Card>
  );
};

// ─── RestaurantList Component ────────────────────────────────────────────────────────
interface RestaurantListProps {
  restaurants?: RestaurantItem[];
  loadingProgress?: number;
  isStreaming?: boolean;
}

const RestaurantList: React.FC<RestaurantListProps> = ({
  restaurants = [],
  loadingProgress = 0,
  isStreaming = false,
}) => {
  const safeRestaurants = Array.isArray(restaurants) ? restaurants : [];
  const visibleRestaurants = isStreaming
    ? safeRestaurants.slice(0, Math.ceil((loadingProgress / 100) * safeRestaurants.length))
    : safeRestaurants;

  return (
    <div
      style={{
        minWidth: 320,
        maxWidth: 480,
      }}
    >
      {/* Progress bar */}
      {isStreaming && loadingProgress < 100 && (
        <LoadingProgress
          percent={loadingProgress}
          text="AI is selecting recommendations for you..."
        />
      )}

      {/* Restaurant list */}
      <List
        dataSource={visibleRestaurants}
        renderItem={(item, index) => (
          <RestaurantCard restaurant={item} index={index} isLoading={false} />
        )}
      />

      {/* Loading complete message */}
      {!isStreaming && safeRestaurants.length > 0 && (
        <div
          style={{
            textAlign: 'center',
            padding: '12px 0',
            opacity: 0.8,
          }}
        >
          <Typography.Text type="secondary" style={{ fontSize: 12 }}>
            ✅ Recommended {safeRestaurants.length} restaurants for you
          </Typography.Text>
        </div>
      )}
    </div>
  );
};

// ─── Container Component ────────────────────────────────────────────────────────────
interface ContainerProps {
  children?: React.ReactNode;
}

const Container: React.FC<ContainerProps> = ({ children }) => {
  return (
    <div
      style={{
        borderRadius: 16,
        border: '1.5px solid #e8e8e8',
        padding: '20px 20px 16px',
        background: '#fff',
        boxShadow: '0 2px 12px rgba(0,0,0,0.06)',
        marginBlock: 16,
        minWidth: 320,
        maxWidth: 520,
      }}
    >
      {children}
    </div>
  );
};

// ─── Streaming Text Hook ────────────────────────────────────────────────────────────
const useStreamText = (text: string) => {
  const textRef = React.useRef(0);
  const [textIndex, setTextIndex] = React.useState(0);
  const textTimestamp = React.useRef(0);
  const [streamStatus, setStreamStatus] = useState('INIT');
  const timerRef = useRef<NodeJS.Timeout | null>(null);

  const run = useCallback(() => {
    if (timerRef.current) clearInterval(timerRef.current);

    timerRef.current = setInterval(() => {
      if (textRef.current < text.length) {
        if (textTimestamp.current === 0) {
          textTimestamp.current = Date.now();
          setStreamStatus('RUNNING');
        }
        textRef.current = Math.min(textRef.current + 3, text.length);
        setTextIndex(textRef.current);
      } else {
        setStreamStatus('FINISHED');
        if (timerRef.current) clearInterval(timerRef.current);
      }
    }, 80);
  }, [text]);

  const reset = useCallback(() => {
    if (timerRef.current) {
      clearInterval(timerRef.current);
      timerRef.current = null;
    }
    textRef.current = 0;
    textTimestamp.current = 0;
    setTextIndex(0);
    setStreamStatus('INIT');
  }, []);

  return {
    text: text.slice(0, textIndex),
    streamStatus,
    timestamp: textTimestamp.current,
    run,
    reset,
  };
};

// ─── Progress Hook ────────────────────────────────────────────────────────────────
const useProgress = () => {
  const [progress, setProgress] = useState(0);
  const [progressStatus, setProgressStatus] = useState<'active' | 'success'>('active');
  const timerRef = useRef<NodeJS.Timeout | null>(null);

  const start = useCallback(() => {
    setProgress(0);
    setProgressStatus('active');

    if (timerRef.current) clearInterval(timerRef.current);

    timerRef.current = setInterval(() => {
      setProgress((prev) => {
        if (prev >= 100) {
          if (timerRef.current) clearInterval(timerRef.current);
          setProgressStatus('success');
          return 100;
        }
        // Simulate real loading: uneven speed
        const increment = Math.random() * 8 + 2;
        return Math.min(prev + increment, 100);
      });
    }, 150);
  }, []);

  const reset = useCallback(() => {
    if (timerRef.current) {
      clearInterval(timerRef.current);
      timerRef.current = null;
    }
    setProgress(0);
    setProgressStatus('active');
  }, []);

  return { progress, progressStatus, start, reset };
};

// ═══════════════════════════════════════════════════════════════════════════════
// Streaming Recommendation Text Content
// ═══════════════════════════════════════════════════════════════════════════════

const INTRO_TEXT = `Hello! I'm your food recommendation assistant 🍽️

Based on your location and preferences, I'm selecting the best restaurants nearby for you...

Here are my recommendation criteria:

1. **Distance First**: Prioritizing restaurants within 15 minutes walking distance
2. **Quality Guaranteed**: Selecting only restaurants with ratings above 4.5
3. **Diverse Cuisines**: Covering Chinese, Japanese, Western, and more

Generating personalized recommendations for you...`;

// ═══════════════════════════════════════════════════════════════════════════════
// v0.9 Agent Command Definitions
// ═══════════════════════════════════════════════════════════════════════════════

// Create Surface Command
const CreateSurfaceCommand: XAgentCommand_v0_9 = {
  version: 'v0.9',
  createSurface: {
    surfaceId: 'recommendation',
    catalogId: 'local://restaurant_streaming_catalog.json',
  },
};

// Update Components Command
const UpdateComponentsCommand: XAgentCommand_v0_9 = {
  version: 'v0.9',
  updateComponents: {
    surfaceId: 'recommendation',
    components: [
      {
        id: 'title',
        component: 'Text',
        text: 'AI Food Recommendations',
        variant: 'h1',
      },
      {
        id: 'progress',
        component: 'LoadingProgress',
        percent: { path: '/progress' },
        status: { path: '/progressStatus' },
      },
      {
        id: 'restaurant-list',
        component: 'RestaurantList',
        restaurants: { path: '/restaurants' },
        loadingProgress: { path: '/progress' },
        isStreaming: { path: '/isStreaming' },
      },
      {
        id: 'root',
        component: 'Container',
        children: ['title', 'progress', 'restaurant-list'],
      },
    ],
  },
};

// Create progress update command
const createProgressUpdateCommand = (percent: number): XAgentCommand_v0_9 => ({
  version: 'v0.9',
  updateDataModel: {
    surfaceId: 'recommendation',
    path: '/progress',
    value: percent,
  },
});

// Create restaurant list update command (incremental update)
const createRestaurantUpdateCommand = (restaurants: RestaurantItem[]): XAgentCommand_v0_9 => ({
  version: 'v0.9',
  updateDataModel: {
    surfaceId: 'recommendation',
    path: '/restaurants',
    value: restaurants,
  },
});

// Create streaming status update command
const createStreamingStatusCommand = (isStreaming: boolean): XAgentCommand_v0_9 => ({
  version: 'v0.9',
  updateDataModel: {
    surfaceId: 'recommendation',
    path: '/isStreaming',
    value: isStreaming,
  },
});

// Create progress status update command
const createProgressStatusCommand = (status: 'active' | 'success'): XAgentCommand_v0_9 => ({
  version: 'v0.9',
  updateDataModel: {
    surfaceId: 'recommendation',
    path: '/progressStatus',
    value: status,
  },
});

// ─── App ────────────────────────────────────────────────────────────────────────
const App = () => {
  const [card, setCard] = useState<CardNode[]>([]);
  const [commandQueue, setCommandQueue] = useState<XAgentCommand_v0_9[]>([]);
  const [sessionKey, setSessionKey] = useState(0);

  // Streaming text state
  const {
    text: streamText,
    streamStatus,
    timestamp: textTimestamp,
    run: runStream,
    reset: resetStream,
  } = useStreamText(INTRO_TEXT);

  // Progress state
  const { progress, progressStatus, start: startProgress, reset: resetProgress } = useProgress();

  // Loaded restaurants
  const [loadedRestaurants, setLoadedRestaurants] = useState<RestaurantItem[]>([]);

  const onAgentCommand = (command: XAgentCommand_v0_9) => {
    if ('createSurface' in command) {
      const surfaceId = command.createSurface.surfaceId;
      setCard((prev) => {
        if (prev.some((c) => c.id === surfaceId)) return prev;
        return [...prev, { id: surfaceId, timestamp: Date.now() }];
      });
    } else if ('deleteSurface' in command) {
      setCard((prev) => prev.filter((c) => c.id !== command.deleteSurface.surfaceId));
    }
    setCommandQueue((prev) => [...prev, command]);
  };

  // Reset the entire process
  const handleReload = useCallback(() => {
    resetStream();
    resetProgress();
    setLoadedRestaurants([]);

    const deleteCommands: XAgentCommand_v0_9[] = [
      { version: 'v0.9', deleteSurface: { surfaceId: 'recommendation' } },
    ];
    setCommandQueue((prev) => [...prev, ...deleteCommands]);
    setCard([]);

    setTimeout(() => {
      setSessionKey((prev) => prev + 1);
    }, 50);
  }, [resetStream, resetProgress]);

  // Start streaming text
  useEffect(() => {
    runStream();
  }, [sessionKey, runStream]);

  // After streaming text completes, start loading components
  useEffect(() => {
    if (streamStatus === 'FINISHED') {
      // Send commands in A2UI v0.9 spec order
      // 1. Create Surface
      onAgentCommand(CreateSurfaceCommand);

      // 2. Update components configuration
      onAgentCommand(UpdateComponentsCommand);

      // 3. Initialize data model
      onAgentCommand(createStreamingStatusCommand(true));
      onAgentCommand(createRestaurantUpdateCommand([]));
      onAgentCommand(createProgressStatusCommand('active'));

      // 4. Start progress animation
      startProgress();
    }
  }, [streamStatus, sessionKey, startProgress]);

  // When progress updates, incrementally add restaurant cards
  useEffect(() => {
    if (progress > 0 && progressStatus === 'active') {
      // Update progress
      onAgentCommand(createProgressUpdateCommand(progress));

      // Calculate how many restaurants to show based on progress
      const visibleCount = Math.ceil((progress / 100) * RESTAURANT_DATA.length);
      const newRestaurants = RESTAURANT_DATA.slice(0, visibleCount);

      // Incrementally update restaurant list
      if (newRestaurants.length !== loadedRestaurants.length) {
        setLoadedRestaurants(newRestaurants);
        onAgentCommand(createRestaurantUpdateCommand(newRestaurants));
      }
    }
  }, [progress, progressStatus]);

  // Progress complete
  useEffect(() => {
    if (progressStatus === 'success' && loadedRestaurants.length === RESTAURANT_DATA.length) {
      // Set isStreaming to false, progress status to success
      onAgentCommand(createStreamingStatusCommand(false));
      onAgentCommand(createProgressStatusCommand('success'));
    }
  }, [progressStatus, loadedRestaurants.length]);

  const items = [
    {
      content: {
        texts: [{ text: streamText, timestamp: textTimestamp }].filter(
          (item) => item.timestamp !== 0,
        ),
        card,
      } as ContentType,
      role: 'assistant',
      key: sessionKey,
    },
  ];

  return (
    <div>
      <div style={{ marginBottom: 16 }}>
        <Button type="primary" icon={<ReloadOutlined />} onClick={handleReload}>
          Recommend Again
        </Button>
      </div>

      <XCard.Box
        key={sessionKey}
        commands={commandQueue}
        components={{
          Text,
          LoadingProgress,
          RestaurantCard,
          RestaurantList,
          Container,
        }}
      >
        <Bubble.List items={items} style={{ height: 800 }} role={role} />
      </XCard.Box>
    </div>
  );
};

export default App;
```

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "local://restaurant_streaming_catalog.json",
  "title": "Restaurant Streaming Catalog",
  "description": "Custom catalog for restaurant streaming demo components.",
  "catalogId": "local://restaurant_streaming_catalog.json",
  "components": {
    "Text": {
      "type": "object",
      "properties": {
        "component": {
          "const": "Text"
        },
        "text": {
          "description": "The text content to display.",
          "oneOf": [
            {
              "type": "string"
            },
            {
              "type": "object",
              "properties": {
                "path": {
                  "type": "string"
                }
              },
              "required": ["path"],
              "additionalProperties": false
            }
          ]
        },
        "variant": {
          "type": "string",
          "description": "A hint for the base text style.",
          "enum": ["h1", "h2", "h3", "body", "success"]
        },
        "status": {
          "description": "The status of the text (for conditional styling).",
          "oneOf": [
            {
              "type": "string"
            },
            {
              "type": "object",
              "properties": {
                "path": {
                  "type": "string"
                }
              },
              "required": ["path"],
              "additionalProperties": false
            }
          ]
        }
      },
      "required": ["component"],
      "additionalProperties": true
    },
    "LoadingProgress": {
      "type": "object",
      "description": "A loading progress indicator with progress bar.",
      "properties": {
        "component": {
          "const": "LoadingProgress"
        },
        "percent": {
          "description": "Current progress percentage (0-100).",
          "oneOf": [
            {
              "type": "number"
            },
            {
              "type": "object",
              "properties": {
                "path": {
                  "type": "string"
                }
              },
              "required": ["path"],
              "additionalProperties": false
            }
          ]
        },
        "status": {
          "type": "string",
          "description": "Progress bar status.",
          "enum": ["active", "success", "normal"]
        },
        "text": {
          "type": "string",
          "description": "Optional text to display above the progress bar."
        }
      },
      "required": ["component"],
      "additionalProperties": true
    },
    "RestaurantCard": {
      "type": "object",
      "description": "A card to display restaurant information.",
      "properties": {
        "component": {
          "const": "RestaurantCard"
        },
        "restaurant": {
          "type": "object",
          "description": "Restaurant data object.",
          "properties": {
            "id": {
              "type": "string"
            },
            "name": {
              "type": "string"
            },
            "cuisine": {
              "type": "string"
            },
            "rating": {
              "type": "number"
            },
            "priceRange": {
              "type": "string"
            },
            "distance": {
              "type": "string"
            },
            "tags": {
              "type": "array",
              "items": {
                "type": "string"
              }
            },
            "description": {
              "type": "string"
            }
          }
        },
        "index": {
          "type": "number",
          "description": "Index for animation delay."
        },
        "isLoading": {
          "type": "boolean",
          "description": "Whether the card is in loading state."
        }
      },
      "required": ["component"],
      "additionalProperties": true
    },
    "RestaurantList": {
      "type": "object",
      "description": "A list container for restaurant cards with streaming support.",
      "properties": {
        "component": {
          "const": "RestaurantList"
        },
        "restaurants": {
          "description": "Array of restaurant items.",
          "oneOf": [
            {
              "type": "array",
              "items": {
                "type": "object"
              }
            },
            {
              "type": "object",
              "properties": {
                "path": {
                  "type": "string"
                }
              },
              "required": ["path"],
              "additionalProperties": false
            }
          ]
        },
        "loadingProgress": {
          "description": "Current loading progress (0-100).",
          "oneOf": [
            {
              "type": "number"
            },
            {
              "type": "object",
              "properties": {
                "path": {
                  "type": "string"
                }
              },
              "required": ["path"],
              "additionalProperties": false
            }
          ]
        },
        "isStreaming": {
          "description": "Whether currently in streaming mode.",
          "oneOf": [
            {
              "type": "boolean"
            },
            {
              "type": "object",
              "properties": {
                "path": {
                  "type": "string"
                }
              },
              "required": ["path"],
              "additionalProperties": false
            }
          ]
        }
      },
      "required": ["component"],
      "additionalProperties": true
    },
    "Container": {
      "type": "object",
      "description": "A container component for layout.",
      "properties": {
        "component": {
          "const": "Container"
        },
        "children": {
          "type": "array",
          "description": "Child component IDs.",
          "items": {
            "type": "string"
          }
        }
      },
      "required": ["component"],
      "additionalProperties": true
    }
  },
  "functions": {},
  "$defs": {
    "DynamicValue": {
      "oneOf": [
        {
          "type": "string"
        },
        {
          "type": "number"
        },
        {
          "type": "boolean"
        },
        {
          "type": "object",
          "properties": {
            "path": {
              "type": "string"
            }
          },
          "required": ["path"],
          "additionalProperties": false
        }
      ]
    }
  }
}

```


- 使用 XCard 实现 A2UI v0.9 协议的表单验证与错误处理示例。演示了如何使用 antd Form 组件配合 catalog 机制实现实时验证、错误状态管理和多步骤表单流程。
```tsx
import { ReloadOutlined } from '@ant-design/icons';
import { Bubble } from '@ant-design/x';
import type { ActionPayload, Catalog, XAgentCommand_v0_9 } from '@ant-design/x-card';
import { registerCatalog, XCard } from '@ant-design/x-card';
import XMarkdown from '@ant-design/x-markdown';
import { Button, Form, Input, message, Select, Space, Steps, Typography } from 'antd';
import React, { useCallback, useEffect, useRef, useState } from 'react';

// Import local catalog schema
import localCatalog from './catalog-form.json';

// Register local catalog
registerCatalog(localCatalog as unknown as Catalog);

const { Title, Text } = Typography;
const { Option } = Select;

const contentHeader =
  'Welcome to register! 🎉\n\nPlease fill in your information to create an account. We will verify your information step by step.';

// ─── Type Definitions ────────────────────────────────────────────────────────────────
type TextNode = { text: string; timestamp: number };
type CardNode = { timestamp: number; id: string };
type ContentType = {
  texts: TextNode[];
  card: CardNode[];
};

// ─── Role Configuration ────────────────────────────────────────────────────────────────
const role = {
  assistant: {
    contentRender: (content: ContentType) => {
      const contentList = [...content.texts, ...content.card].sort(
        (a, b) => a.timestamp - b.timestamp,
      );
      return contentList.map((node, index) => {
        if ('text' in node && node.text) {
          return <XMarkdown key={index}>{node.text}</XMarkdown>;
        }

        if ('id' in node && node.id) {
          return <XCard.Card key={index} id={node.id} />;
        }
        return null;
      });
    },
  },
};

// ─── RegistrationForm Component ─────────────────────────────────────────────────────
interface RegistrationFormProps {
  step?: number;
  status?: 'error' | 'success' | 'loading';
  errorMessage?: string;
  onAction?: (name: string, context: Record<string, any>) => void;
  action?: {
    event?: {
      name?: string;
      context?: Record<string, any>;
    };
  };
}

const RegistrationForm: React.FC<RegistrationFormProps> = ({
  step = 0,
  status,
  errorMessage,
  onAction,
  action,
}) => {
  const [form] = Form.useForm();
  const [currentStep, setCurrentStep] = useState(step);
  const [formStatus, setFormStatus] = useState<'error' | 'success' | 'loading' | null>(null);

  useEffect(() => {
    setCurrentStep(step);
  }, [step]);

  useEffect(() => {
    setFormStatus(status ?? null);
  }, [status]);

  const handleNext = async () => {
    try {
      const fieldsToValidate =
        currentStep === 0 ? ['username', 'email'] : ['password', 'confirmPassword'];

      await form.validateFields(fieldsToValidate);
      const values = form.getFieldsValue();

      if (action?.event?.name) {
        const context: Record<string, any> = {};
        if (action.event.context) {
          Object.keys(action.event.context).forEach((key) => {
            context[key] = {
              step: currentStep + 1,
              values,
            };
          });
        }
        onAction?.(action.event.name, context);
      }

      if (currentStep === 1) {
        handleSubmit(values);
      } else {
        setCurrentStep(currentStep + 1);
      }
    } catch (error) {
      console.log('Validation failed:', error);
    }
  };

  const handlePrev = () => {
    setCurrentStep(currentStep - 1);
  };

  const handleSubmit = (values: any) => {
    if (action?.event?.name) {
      const context: Record<string, any> = {};
      if (action.event.context) {
        Object.keys(action.event.context).forEach((key) => {
          context[key] = {
            step: 2,
            values,
            submit: true,
          };
        });
      }
      onAction?.(action.event.name, context);
    }
  };

  const steps = [
    {
      title: 'Basic Info',
      description: 'Username & Email',
    },
    {
      title: 'Security',
      description: 'Password',
    },
    {
      title: 'Complete',
      description: 'Account Created',
    },
  ];

  return (
    <div
      style={{
        borderRadius: 16,
        border: '1.5px solid #e8e8e8',
        padding: '24px',
        background: '#fff',
        boxShadow: '0 2px 12px rgba(0,0,0,0.06)',
        minWidth: 480,
        maxWidth: 600,
      }}
    >
      <Steps current={currentStep} items={steps} style={{ marginBottom: 24 }} />

      {formStatus === 'error' && errorMessage && (
        <div
          style={{
            padding: '12px 16px',
            marginBottom: 16,
            borderRadius: 8,
            background: '#fff2f0',
            border: '1px solid #ffccc7',
          }}
        >
          <Text type="danger">{errorMessage}</Text>
        </div>
      )}

      <Form
        form={form}
        layout="vertical"
        initialValues={{ username: '', email: '', password: '', confirmPassword: '' }}
      >
        {/* Step 0: Basic Info */}
        <div style={{ display: currentStep === 0 ? 'block' : 'none' }}>
          <Form.Item
            label="Username"
            name="username"
            rules={[
              { required: true, message: 'Please input your username!' },
              { min: 3, message: 'Username must be at least 3 characters!' },
              { pattern: /^[a-zA-Z0-9_]+$/, message: 'Only letters, numbers and underscores!' },
            ]}
            validateTrigger="onBlur"
          >
            <Input placeholder="Enter username" size="large" />
          </Form.Item>

          <Form.Item
            label="Email"
            name="email"
            rules={[
              { required: true, message: 'Please input your email!' },
              { type: 'email', message: 'Please enter a valid email!' },
            ]}
            validateTrigger="onBlur"
          >
            <Input placeholder="Enter email" size="large" />
          </Form.Item>
        </div>

        {/* Step 1: Security */}
        <div style={{ display: currentStep === 1 ? 'block' : 'none' }}>
          <Form.Item
            label="Password"
            name="password"
            rules={[
              { required: true, message: 'Please input your password!' },
              { min: 8, message: 'Password must be at least 8 characters!' },
              {
                pattern: /^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)/,
                message: 'Must contain uppercase, lowercase and number!',
              },
            ]}
            validateTrigger="onBlur"
          >
            <Input.Password placeholder="Enter password" size="large" />
          </Form.Item>

          <Form.Item
            label="Confirm Password"
            name="confirmPassword"
            dependencies={['password']}
            rules={[
              { required: true, message: 'Please confirm your password!' },
              ({ getFieldValue }) => ({
                validator(_, value) {
                  if (!value || getFieldValue('password') === value) {
                    return Promise.resolve();
                  }
                  return Promise.reject(new Error('Passwords do not match!'));
                },
              }),
            ]}
            validateTrigger="onBlur"
          >
            <Input.Password placeholder="Confirm password" size="large" />
          </Form.Item>

          <Form.Item
            label="Account Type"
            name="accountType"
            rules={[{ required: true, message: 'Please select account type!' }]}
            initialValue="personal"
          >
            <Select size="large">
              <Option value="personal">Personal</Option>
              <Option value="business">Business</Option>
              <Option value="developer">Developer</Option>
            </Select>
          </Form.Item>
        </div>

        {/* Step 2: Complete */}
        {currentStep === 2 && (
          <div
            style={{
              textAlign: 'center',
              padding: '40px 20px',
              background: '#f6ffed',
              borderRadius: 12,
              border: '1px solid #b7eb8f',
            }}
          >
            <div style={{ fontSize: 48, marginBottom: 16 }}>✅</div>
            <Title level={3} style={{ marginBottom: 8, color: '#52c41a' }}>
              Registration Successful!
            </Title>
            <Text type="secondary">Your account has been created successfully.</Text>
          </div>
        )}
      </Form>

      {/* Action Buttons */}
      {currentStep < 2 && (
        <Space style={{ width: '100%', justifyContent: 'space-between', marginTop: 24 }}>
          <Button size="large" disabled={currentStep === 0} onClick={handlePrev}>
            Previous
          </Button>
          <Button
            type="primary"
            size="large"
            onClick={handleNext}
            loading={formStatus === 'loading'}
          >
            {currentStep === 1 ? 'Submit' : 'Next'}
          </Button>
        </Space>
      )}
    </div>
  );
};

// ─── SuccessCard Component ──────────────────────────────────────────────────────────
interface SuccessCardProps {
  username?: string;
  email?: string;
  accountType?: string;
}

const SuccessCard: React.FC<SuccessCardProps> = ({ username, email, accountType }) => {
  return (
    <div
      style={{
        borderRadius: 16,
        border: '1.5px solid #52c41a',
        padding: '24px',
        background: 'linear-gradient(135deg, #f6ffed 0%, #fff 100%)',
        boxShadow: '0 2px 12px rgba(82,196,26,0.15)',
        minWidth: 400,
        maxWidth: 500,
      }}
    >
      <div style={{ textAlign: 'center', marginBottom: 24 }}>
        <div style={{ fontSize: 56, marginBottom: 16 }}>🎉</div>
        <Title level={2} style={{ marginBottom: 8, color: '#52c41a' }}>
          Welcome, {username}!
        </Title>
        <Text type="secondary">Your account has been created successfully.</Text>
      </div>

      <div
        style={{
          background: '#fff',
          borderRadius: 12,
          padding: '16px 20px',
          marginBottom: 16,
        }}
      >
        <Space direction="vertical" style={{ width: '100%' }} size={12}>
          <div style={{ display: 'flex', justifyContent: 'space-between' }}>
            <Text type="secondary">Email:</Text>
            <Text strong>{email}</Text>
          </div>
          <div style={{ display: 'flex', justifyContent: 'space-between' }}>
            <Text type="secondary">Account Type:</Text>
            <Text strong style={{ textTransform: 'capitalize' }}>
              {accountType}
            </Text>
          </div>
        </Space>
      </div>

      <Button type="primary" size="large" block>
        Start Exploring
      </Button>
    </div>
  );
};

// ─── Streaming Text Hook ────────────────────────────────────────────────────────────
const useStreamText = (text: string) => {
  const textRef = React.useRef(0);
  const [textIndex, setTextIndex] = React.useState(0);
  const textTimestamp = React.useRef(0);
  const [streamStatus, setStreamStatus] = useState('INIT');
  const timerRef = useRef<NodeJS.Timeout | null>(null);

  const run = useCallback(() => {
    if (timerRef.current) {
      clearInterval(timerRef.current);
    }

    timerRef.current = setInterval(() => {
      if (textRef.current < text.length) {
        if (textTimestamp.current === 0) {
          textTimestamp.current = Date.now();
          setStreamStatus('RUNNING');
        }
        textRef.current = Math.min(textRef.current + 3, text.length);
        setTextIndex(textRef.current);
      } else {
        setStreamStatus('FINISHED');
        if (timerRef.current) {
          clearInterval(timerRef.current);
        }
      }
    }, 100);
  }, [text]);

  const reset = useCallback(() => {
    if (timerRef.current) {
      clearInterval(timerRef.current);
      timerRef.current = null;
    }
    textRef.current = 0;
    textTimestamp.current = 0;
    setTextIndex(0);
    setStreamStatus('INIT');
  }, []);

  return {
    text: text.slice(0, textIndex),
    streamStatus,
    timestamp: textTimestamp.current,
    run,
    reset,
  };
};

// ─── Agent Commands ───────────────────────────────────────────────────────────────
const CreateCard: XAgentCommand_v0_9 = {
  version: 'v0.9',
  createSurface: {
    surfaceId: 'registration',
    catalogId: 'local://form_validation_catalog.json',
  },
};

const UpdateCard: XAgentCommand_v0_9 = {
  version: 'v0.9',
  updateComponents: {
    surfaceId: 'registration',
    components: [
      {
        id: 'root',
        component: 'RegistrationForm',
        step: 0,
        status: { path: '/registration/status' },
        errorMessage: { path: '/registration/errorMessage' },
        action: {
          event: {
            name: 'submit_step',
            context: {
              formData: {
                path: '/registration/formData',
              },
            },
          },
        },
      },
    ],
  },
};

const UpdateModel: XAgentCommand_v0_9 = {
  version: 'v0.9',
  updateDataModel: {
    surfaceId: 'registration',
    path: '/registration',
    value: {
      status: '',
      errorMessage: '',
    },
  },
};

// ─── Result Card Configuration ─────────────────────────────────────────────────────
const CreateResultCard: XAgentCommand_v0_9 = {
  version: 'v0.9',
  createSurface: {
    surfaceId: 'result',
    catalogId: 'local://form_validation_catalog.json',
  },
};

const UpdateResultCard = (formData: any): XAgentCommand_v0_9 => {
  return {
    version: 'v0.9',
    updateComponents: {
      surfaceId: 'result',
      components: [
        {
          id: 'root',
          component: 'SuccessCard',
          username: formData?.username,
          email: formData?.email,
          accountType: formData?.accountType ?? 'personal',
        },
      ],
    },
  };
};

// ─── App ──────────────────────────────────────────────────────────────────────
const App = () => {
  const [card, setCard] = useState<CardNode[]>([]);
  const [commandQueue, setCommandQueue] = useState<XAgentCommand_v0_9[]>([]);
  const [sessionKey, setSessionKey] = useState(0);

  const onAgentCommand = (command: XAgentCommand_v0_9) => {
    if ('createSurface' in command) {
      const surfaceId = command.createSurface.surfaceId;
      setCard((prev) => {
        if (prev.some((c) => c.id === surfaceId)) return prev;
        return [...prev, { id: surfaceId, timestamp: Date.now() }];
      });
    } else if ('deleteSurface' in command) {
      setCard((prev) => prev.filter((c) => c.id !== command.deleteSurface.surfaceId));
    }
    setCommandQueue((prev) => [...prev, command]);
  };

  /** Handle Card internal action events */
  const handleAction = (payload: ActionPayload) => {
    if (payload.name === 'submit_step') {
      const { formData } = payload.context || {};

      if (formData?.submit) {
        message.success('Registration successful!');

        onAgentCommand({
          version: 'v0.9',
          deleteSurface: {
            surfaceId: 'registration',
          },
        });

        setTimeout(() => {
          onAgentCommand(CreateResultCard);
          onAgentCommand(UpdateResultCard(formData.values));
        }, 300);
      } else {
        message.info(`Step ${formData.step} completed`);
      }
    }
  };

  const {
    text: textHeader,
    streamStatus: streamStatusHeader,
    run: runHeader,
    reset: resetHeader,
  } = useStreamText(contentHeader);

  useEffect(() => {
    runHeader();
  }, [sessionKey, runHeader]);

  useEffect(() => {
    if (streamStatusHeader === 'FINISHED') {
      onAgentCommand(CreateCard);
      onAgentCommand(UpdateCard);
      onAgentCommand(UpdateModel);
    }
  }, [streamStatusHeader, sessionKey]);

  const handleReload = useCallback(() => {
    resetHeader();
    const deleteCommands: XAgentCommand_v0_9[] = [
      { version: 'v0.9', deleteSurface: { surfaceId: 'registration' } },
      { version: 'v0.9', deleteSurface: { surfaceId: 'result' } },
    ];
    setCommandQueue((prev) => [...prev, ...deleteCommands]);
    setCard([]);
    setTimeout(() => {
      setSessionKey((prev) => prev + 1);
    }, 50);
  }, [resetHeader]);

  const items = [
    {
      content: {
        texts: [
          { text: textHeader, timestamp: streamStatusHeader === 'RUNNING' ? Date.now() : 0 },
        ].filter((item) => item.timestamp !== 0),
        card,
      } as ContentType,
      role: 'assistant',
      key: sessionKey,
    },
  ];

  return (
    <div>
      <div style={{ marginBottom: 16 }}>
        <Button type="primary" icon={<ReloadOutlined />} onClick={handleReload}>
          Reload
        </Button>
      </div>

      <XCard.Box
        key={sessionKey}
        commands={commandQueue}
        onAction={handleAction}
        components={{
          RegistrationForm,
          SuccessCard,
        }}
      >
        <Bubble.List items={items} style={{ height: 620 }} role={role} />
      </XCard.Box>
    </div>
  );
};

export default App;
```

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "local://form_validation_catalog.json",
  "title": "Form Validation Catalog",
  "description": "Custom catalog for form validation demo components.",
  "catalogId": "local://form_validation_catalog.json",
  "components": {
    "RegistrationForm": {
      "type": "object",
      "properties": {
        "component": {
          "const": "RegistrationForm"
        },
        "step": {
          "description": "Current step of the form.",
          "type": "integer"
        },
        "status": {
          "description": "Form status.",
          "type": "string",
          "enum": ["error", "success", "loading", ""]
        },
        "errorMessage": {
          "description": "Error message to display.",
          "type": "string"
        },
        "action": {
          "type": "object",
          "properties": {
            "event": {
              "type": "object",
              "properties": {
                "name": {
                  "type": "string"
                },
                "context": {
                  "type": "object"
                }
              }
            }
          }
        }
      }
    },
    "SuccessCard": {
      "type": "object",
      "properties": {
        "component": {
          "const": "SuccessCard"
        },
        "username": {
          "description": "Registered username.",
          "type": "string"
        },
        "email": {
          "description": "Registered email.",
          "type": "string"
        },
        "accountType": {
          "description": "Account type.",
          "type": "string"
        }
      }
    }
  }
}

```