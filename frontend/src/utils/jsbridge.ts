/**
 * JSBridge for communicating between React Web and Flutter WebView
 */

// Global type declarations
declare global {
  interface Window {
    FlutterBridge?: {
      postMessage: (message: string) => void;
    };
    injectToken?: (token: string) => void;
  }
}

// Initialize JSBridge listener
export const initJSBridge = (onTokenReceived: (token: string) => void) => {
  window.injectToken = (token: string) => {
    console.log('[JSBridge] Token received from Flutter:', token);
    onTokenReceived(token);
  };
};

// Notify Flutter to pop/back
export const notifyFlutterBack = () => {
  if (window.FlutterBridge) {
    window.FlutterBridge.postMessage(JSON.stringify({ action: 'back' }));
  } else {
    console.warn('[JSBridge] FlutterBridge not found. Back action ignored.');
  }
};

// Notify Flutter that consultation ended with card data
export const notifyConsultationEnd = (cardData: Record<string, unknown>) => {
  if (window.FlutterBridge) {
    window.FlutterBridge.postMessage(JSON.stringify({ 
      action: 'consultationEnd', 
      data: cardData 
    }));
  } else {
    console.warn('[JSBridge] FlutterBridge not found. ConsultationEnd ignored.', cardData);
  }
};

// Notify Flutter to save consultation
export const saveConsultation = (cardData: Record<string, unknown>) => {
  if (window.FlutterBridge) {
    window.FlutterBridge.postMessage(JSON.stringify({ 
      action: 'saveConsultation', 
      data: cardData 
    }));
  } else {
    console.warn('[JSBridge] FlutterBridge not found. saveConsultation ignored.', cardData);
  }
};
