// Flutter WebView との通信レイヤー。
//
// JS -> Dart: window.AppBridge.postMessage(JSON.stringify({id, type, payload}))
// Dart -> JS: window.AppBridgeCallback(JSON.stringify({id, payload}))
//
// window.AppBridge が存在しない環境（Chromeで直接dist/index.htmlを開いた開発時）では
// localStorageベースのフォールバックで同じインターフェースを提供し、広告リクエストは
// 即座に成功として扱う。これにより同一の資産のままブラウザ単体でも動作確認できる。

let nextId = 1;
const pending = new Map();

function hasNativeBridge() {
  return (
    typeof window !== 'undefined' &&
    window.AppBridge &&
    typeof window.AppBridge.postMessage === 'function'
  );
}

function resolvePending(id, payload) {
  const resolve = pending.get(id);
  if (!resolve) return;
  pending.delete(id);
  resolve(payload);
}

function handleFallback(envelope) {
  const { id, type, payload } = envelope;
  switch (type) {
    case 'gameReady':
      return;
    case 'requestInterstitial':
      resolvePending(id, { shown: true });
      return;
    case 'requestRewarded':
      resolvePending(id, { granted: true });
      return;
    case 'saveProgress': {
      try {
        localStorage.setItem('korokoro_save', JSON.stringify(payload));
        resolvePending(id, { ok: true });
      } catch (e) {
        resolvePending(id, { ok: false });
      }
      return;
    }
    case 'requestSave': {
      try {
        const raw = localStorage.getItem('korokoro_save');
        resolvePending(id, raw ? JSON.parse(raw) : null);
      } catch (e) {
        resolvePending(id, null);
      }
      return;
    }
    default:
      resolvePending(id, null);
  }
}

/**
 * @param {string} type
 * @param {unknown} payload
 * @param {{expectsReply?: boolean, timeoutMs?: number, fallback?: unknown}} opts
 */
function send(type, payload, opts = {}) {
  const { expectsReply = false, timeoutMs = 8000, fallback = null } = opts;
  const id = nextId++;
  const envelope = { id, type, payload: payload ?? null };

  if (hasNativeBridge()) {
    window.AppBridge.postMessage(JSON.stringify(envelope));
  } else {
    queueMicrotask(() => handleFallback(envelope));
  }

  if (!expectsReply) return Promise.resolve(fallback);

  return new Promise((resolve) => {
    const timer = setTimeout(() => {
      if (pending.has(id)) {
        pending.delete(id);
        resolve(fallback);
      }
    }, timeoutMs);
    pending.set(id, (value) => {
      clearTimeout(timer);
      resolve(value);
    });
  });
}

window.AppBridgeCallback = function AppBridgeCallback(jsonString) {
  try {
    const { id, payload } = JSON.parse(jsonString);
    resolvePending(id, payload);
  } catch (e) {
    console.error('[bridge] failed to parse callback', e);
  }
};

export const bridge = {
  /** ゲーム初期化完了をネイティブ側に通知する（応答不要）。 */
  ready() {
    return send('gameReady', null);
  },
  /**
   * リトライ時などにインタースティシャル広告を要求する。
   * 広告が出せなくても { shown: false } で解決し、ゲーム進行は止めない。
   * タイムアウトは「広告の読み込み待ち」ではなく「表示〜ユーザーが閉じるまで」を
   * カバーする必要があるため、動画+エンドカード操作を考慮して十分長く取る。
   */
  requestInterstitial(context) {
    return send(
      'requestInterstitial',
      { context },
      { expectsReply: true, timeoutMs: 60000, fallback: { shown: false } },
    );
  },
  /**
   * コンティニューやスキン解放のためのリワード広告を要求する。
   * 視聴完了しなければ { granted: false } で解決する。
   * リワード広告は動画自体が15〜30秒あり、視聴後のエンドカード操作にも時間がかかるため、
   * 短いタイムアウトだと「実際は視聴完了したのにgranted:falseになる」事故が起きる。
   */
  requestRewarded(context) {
    return send(
      'requestRewarded',
      { context },
      { expectsReply: true, timeoutMs: 120000, fallback: { granted: false } },
    );
  },
  /** ベストスコア等の進捗を保存する。 */
  saveProgress(data) {
    return send(
      'saveProgress',
      data,
      { expectsReply: true, timeoutMs: 5000, fallback: { ok: false } },
    );
  },
  /** 保存済みの進捗を読み込む。データが無ければ null。 */
  loadSave() {
    return send('requestSave', null, { expectsReply: true, timeoutMs: 5000, fallback: null });
  },
};
